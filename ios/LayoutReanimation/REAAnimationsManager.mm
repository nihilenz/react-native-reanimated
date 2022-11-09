#import <RNReanimated/REAAnimationsManager.h>
#import <RNReanimated/REAUIManager.h>
#import <React/RCTComponentData.h>
#import <React/RCTTextView.h>
#import <React/UIView+Private.h>
#import <React/UIView+React.h>

typedef NS_ENUM(NSInteger, FrameConfigType) { EnteringFrame, ExitingFrame };

@implementation REAAnimationsManager {
  RCTUIManager *_uiManager;
  REAUIManager *_reaUiManager;
  NSMutableDictionary<NSNumber *, UIView *> *_exitingViews;
  NSMutableDictionary<NSNumber *, UIView *> *_removedSharedTransitionViews;
  NSMutableDictionary<NSNumber *, NSNumber *> *_exitingSubviewsCountMap;
  NSMutableSet<NSNumber *> *_ancestorsToRemove;
  NSMutableArray<NSString *> *_targetKeys;
  NSMutableArray<NSString *> *_currentKeys;
  REANodesManager *_nodeManager;
  std::weak_ptr<reanimated::LayoutAnimationsProxy> _layoutAnimationsProxy;
  REAAnimationStartingBlock _startAnimationForTag;
  REAHasAnimationBlock _hasAnimationForTag;
  REAAnimationRemovingBlock _clearAnimationConfigForTag;
}

+ (NSArray *)layoutKeys
{
  static NSArray *_array;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _array = @[ @"originX", @"originY", @"width", @"height" ];
  });
  return _array;
}

- (instancetype)initWithUIManager:(RCTUIManager *)uiManager
{
  if (self = [super init]) {
    _uiManager = uiManager;
    _reaUiManager = (REAUIManager *)uiManager;
    _exitingViews = [NSMutableDictionary new];
    _removedSharedTransitionViews = [NSMutableDictionary new];
    _exitingSubviewsCountMap = [NSMutableDictionary new];
    _ancestorsToRemove = [NSMutableSet new];

    _targetKeys = [NSMutableArray new];
    _currentKeys = [NSMutableArray new];
    for (NSString *key in [[self class] layoutKeys]) {
      [_targetKeys addObject:[NSString stringWithFormat:@"target%@", [key capitalizedString]]];
      [_currentKeys addObject:[NSString stringWithFormat:@"current%@", [key capitalizedString]]];
    }
  }
  return self;
}

- (void)invalidate
{
  _startAnimationForTag = nil;
  _hasAnimationForTag = nil;
  _uiManager = nil;
  _exitingViews = nil;
  _removedSharedTransitionViews = nil;
  _targetKeys = nil;
  _currentKeys = nil;
}

- (BOOL)nodeFind:(id<RCTComponent>)view block:(BOOL (^)(id<RCTComponent>))block
{
  if (!view.reactTag) {
    return NO;
  }

  if (block(view)) {
    return YES;
  }

  for (id<RCTComponent> subview in view.reactSubviews) {
    if ([self nodeFind:subview block:block]) {
      return YES;
    }
  }

  return NO;
}

- (void)setRemovedSharedTransitionViews:(NSMutableDictionary<NSNumber *, UIView *> *)removedSharedTransitionViews
{
  _removedSharedTransitionViews = removedSharedTransitionViews;
}

- (void)setAnimationStartingBlock:(REAAnimationStartingBlock)startAnimation
{
  _startAnimationForTag = startAnimation;
}

- (void)setHasAnimationBlock:(REAHasAnimationBlock)hasAnimation
{
  _hasAnimationForTag = hasAnimation;
}

- (void)setAnimationRemovingBlock:(REAAnimationRemovingBlock)clearAnimation
{
  _clearAnimationConfigForTag = clearAnimation;
}

- (UIView *)viewForTag:(NSNumber *)tag
{
  UIView *view = [_reaUiManager viewForReactTag:tag];
  if (view == nil) {
    return [_exitingViews objectForKey:tag];
  }
  return view;
}

- (void)endLayoutAnimnationForTag:(NSNumber *)tag cancelled:(BOOL)cancelled removeView:(BOOL)removeView
{
  UIView *view = [_exitingViews objectForKey:tag];
  if (removeView && view != nil) {
    [self endAnimationsRecursive:view];
  }
  for (NSNumber *tag in _removedSharedTransitionViews) {
    _clearAnimationConfigForTag(tag, true);
  }
}

- (void)endAnimationsRecursive:(UIView *)view
{
  NSNumber *tag = [view reactTag];

  // we'll remove this view anyway when exiting from recursion,
  // no need to remove it in `maybeDropAncestors`
  [_ancestorsToRemove removeObject:tag];

  for (UIView *child in [[view subviews] copy]) {
    [self endAnimationsRecursive:child];
  }

  if ([_exitingViews objectForKey:tag]) {
    [_exitingViews removeObjectForKey:tag];
    [self maybeDropAncestors:view];
  }

  [view removeFromSuperview];
}

- (void)progressLayoutAnimationWithStyle:(NSDictionary *)newStyle forTag:(NSNumber *)tag
{
  NSMutableDictionary *dataComponenetsByName = [_uiManager valueForKey:@"_componentDataByName"];
  RCTComponentData *componentData = dataComponenetsByName[@"RCTView"];
  [self setNewProps:[newStyle mutableCopy] forView:[self viewForTag:tag] withComponentData:componentData];
}

- (void)progressSharedTransitionAnimationWithStyle:(NSDictionary *)newStyle forTag:(NSNumber *)tag
{
  NSMutableDictionary *dataComponenetsByName = [_uiManager valueForKey:@"_componentDataByName"];
  RCTComponentData *componentData = dataComponenetsByName[@"RCTView"];
  UIView *view = [self viewForTag:tag];
  if (view == nil) {
    view = _removedSharedTransitionViews[tag];
  }
  [self setNewPropsForSharedTransition:[newStyle mutableCopy] forView:view withComponentData:componentData];
}

- (double)getDoubleOrZero:(NSNumber *)number
{
  double doubleValue = [number doubleValue];
  if (doubleValue != doubleValue) { // NaN != NaN
    return 0;
  }
  return doubleValue;
}

- (void)setNewProps:(NSMutableDictionary *)newProps
              forView:(UIView *)view
    withComponentData:(RCTComponentData *)componentData
{
  [self setNewPropsForSharedTransition:newProps forView:view withComponentData:componentData convertToAbsolute:NO];
}

- (void)setNewPropsForSharedTransition:(NSMutableDictionary *)newProps
                               forView:(UIView *)view
                     withComponentData:(RCTComponentData *)componentData
{
  [self setNewPropsForSharedTransition:newProps forView:view withComponentData:componentData convertToAbsolute:YES];
}

- (void)setNewPropsForSharedTransition:(NSMutableDictionary *)newProps
                               forView:(UIView *)view
                     withComponentData:(RCTComponentData *)componentData
                     convertToAbsolute:(BOOL)convertToAbsolute
{
  if (newProps[@"height"]) {
    double height = [self getDoubleOrZero:newProps[@"height"]];
    double oldHeight = view.bounds.size.height;
    view.bounds = CGRectMake(0, 0, view.bounds.size.width, height);
    view.center = CGPointMake(view.center.x, view.center.y - oldHeight / 2.0 + view.bounds.size.height / 2.0);
    [newProps removeObjectForKey:@"height"];
  }
  if (newProps[@"width"]) {
    double width = [self getDoubleOrZero:newProps[@"width"]];
    double oldWidth = view.bounds.size.width;
    view.bounds = CGRectMake(0, 0, width, view.bounds.size.height);
    view.center = CGPointMake(view.center.x + view.bounds.size.width / 2.0 - oldWidth / 2.0, view.center.y);
    [newProps removeObjectForKey:@"width"];
  }

  bool updateViewPosition = false;
  double originX = 0, originY = 0;
  if (newProps[@"originX"]) {
    updateViewPosition = true;
    originX = [self getDoubleOrZero:newProps[@"originX"]];
    [newProps removeObjectForKey:@"originX"];
  }
  if (newProps[@"originY"]) {
    updateViewPosition = true;
    originY = [self getDoubleOrZero:newProps[@"originY"]];
    [newProps removeObjectForKey:@"originY"];
  }
  if (updateViewPosition) {
    CGPoint newCenter = CGPointMake(originX + view.bounds.size.width / 2.0, originY + view.bounds.size.height / 2.0);
    UIView *window = UIApplication.sharedApplication.keyWindow;
    if (convertToAbsolute) {
      CGPoint convertedCenter = [window convertPoint:newCenter toView:view.superview];
      view.center = convertedCenter;
    } else {
      view.center = newCenter;
    }
  }

  [componentData setProps:newProps forView:view];
}

- (NSDictionary *)prepareDataForAnimatingWorklet:(NSMutableDictionary *)values frameConfig:(FrameConfigType)frameConfig
{
  UIView *windowView = UIApplication.sharedApplication.keyWindow;
  if (frameConfig == EnteringFrame) {
    NSDictionary *preparedData = @{
      @"targetWidth" : values[@"width"],
      @"targetHeight" : values[@"height"],
      @"targetOriginX" : values[@"originX"],
      @"targetOriginY" : values[@"originY"],
      @"targetGlobalOriginX" : values[@"globalOriginX"],
      @"targetGlobalOriginY" : values[@"globalOriginY"],
      @"windowWidth" : [NSNumber numberWithDouble:windowView.bounds.size.width],
      @"windowHeight" : [NSNumber numberWithDouble:windowView.bounds.size.height]
    };
    return preparedData;
  } else {
    NSDictionary *preparedData = @{
      @"currentWidth" : values[@"width"],
      @"currentHeight" : values[@"height"],
      @"currentOriginX" : values[@"originX"],
      @"currentOriginY" : values[@"originY"],
      @"currentGlobalOriginX" : values[@"globalOriginX"],
      @"currentGlobalOriginY" : values[@"globalOriginY"],
      @"windowWidth" : [NSNumber numberWithDouble:windowView.bounds.size.width],
      @"windowHeight" : [NSNumber numberWithDouble:windowView.bounds.size.height]
    };
    return preparedData;
  }
}

- (NSDictionary<NSString *, NSNumber *> *)prepareDataForLayoutAnimatingWorklet:(NSMutableDictionary *)currentValues
                                                                  targetValues:(NSMutableDictionary *)targetValues
{
  UIView *windowView = UIApplication.sharedApplication.keyWindow;
  NSDictionary *preparedData = @{
    @"currentWidth" : currentValues[@"width"],
    @"currentHeight" : currentValues[@"height"],
    @"currentOriginX" : currentValues[@"originX"],
    @"currentOriginY" : currentValues[@"originY"],
    @"currentGlobalOriginX" : currentValues[@"globalOriginX"],
    @"currentGlobalOriginY" : currentValues[@"globalOriginY"],
    @"targetWidth" : targetValues[@"width"],
    @"targetHeight" : targetValues[@"height"],
    @"targetOriginX" : targetValues[@"originX"],
    @"targetOriginY" : targetValues[@"originY"],
    @"targetGlobalOriginX" : targetValues[@"globalOriginX"],
    @"targetGlobalOriginY" : targetValues[@"globalOriginY"],
    @"windowWidth" : [NSNumber numberWithDouble:windowView.bounds.size.width],
    @"windowHeight" : [NSNumber numberWithDouble:windowView.bounds.size.height]
  };
  return preparedData;
}

- (BOOL)wantsHandleRemovalOfView:(UIView *)view
{
  return [self nodeFind:view
                  block:^(id<RCTComponent> view) {
                    return [self->_exitingSubviewsCountMap objectForKey:view.reactTag] != nil ||
                        self->_hasAnimationForTag(view.reactTag, @"exiting");
                  }];
}

- (void)registerExitingAncestors:(UIView *)child
{
  UIView *parent = child.superview;
  while (parent != nil && ![parent isKindOfClass:[RCTRootView class]]) {
    if (parent.reactTag != nil) {
      _exitingSubviewsCountMap[parent.reactTag] = @([_exitingSubviewsCountMap[parent.reactTag] intValue] + 1);
    }
    parent = parent.superview;
  }
}

- (void)maybeDropAncestors:(UIView *)child
{
  UIView *parent = child.superview;
  while (parent != nil && ![parent isKindOfClass:[RCTRootView class]]) {
    UIView *view = parent;
    parent = view.superview;
    if (view.reactTag == nil) {
      continue;
    }
    int trackingCount = [_exitingSubviewsCountMap[view.reactTag] intValue] - 1;
    if (trackingCount <= 0) {
      if ([_ancestorsToRemove containsObject:view.reactTag]) {
        [view removeFromSuperview];
        [_ancestorsToRemove removeObject:view.reactTag];
      }
      [_exitingSubviewsCountMap removeObjectForKey:view.reactTag];
    } else {
      _exitingSubviewsCountMap[view.reactTag] = @(trackingCount);
    }
  }
}

- (BOOL)removeRecursive:(UIView *)view fromContainer:(UIView *)container withoutAnimation:(BOOL)removeImmediately;
{
  if (!view.reactTag) {
    return NO;
  }
  BOOL hasExitAnimation = _hasAnimationForTag(view.reactTag, @"exiting");
  BOOL wantAnimateExit = hasExitAnimation;

  for (UIView *subview in [view.reactSubviews copy]) {
    if ([self removeRecursive:subview fromContainer:view withoutAnimation:(removeImmediately && !hasExitAnimation)]) {
      wantAnimateExit = YES;
    }
  }

  if (wantAnimateExit) {
    REASnapshot *before;
    if (hasExitAnimation) {
      before = [[REASnapshot alloc] init:view];
    }
    // start exit animation
    UIView *originalSuperview = view.superview;
    NSUInteger originalIndex = [originalSuperview.subviews indexOfObjectIdenticalTo:view];
    [container removeReactSubview:view];
    // we don't want user interaction on exiting views
    view.userInteractionEnabled = NO;
    [originalSuperview insertSubview:view atIndex:originalIndex];
    if (hasExitAnimation) {
      if (![_exitingViews objectForKey:view.reactTag]) {
        NSDictionary *preparedValues = [self prepareDataForAnimatingWorklet:before.values frameConfig:ExitingFrame];
        [_exitingViews setObject:view forKey:view.reactTag];
        [self registerExitingAncestors:view];
        _startAnimationForTag(view.reactTag, @"exiting", preparedValues, @(0));
      }
    } else {
      [_ancestorsToRemove addObject:view.reactTag];
    }
    // NOTE: even though this view is still visible,
    // since it's removed from the React tree, we won't
    // start new animations for it, and might as well remove
    // the layout animation config now
    _clearAnimationConfigForTag(view.reactTag, false);
    return YES;
  } else if (removeImmediately) {
    [container removeReactSubview:view];
    _clearAnimationConfigForTag(view.reactTag, false);
  }

  return NO;
}

- (void)removeChildren:(NSArray<UIView *> *)children fromContainer:(UIView *)container
{
  for (UIView *removedChild in children) {
    if (![self removeRecursive:removedChild fromContainer:container withoutAnimation:true]) {
      [removedChild removeFromSuperview];
    }
  }
}

- (void)onViewCreate:(UIView *)view after:(REASnapshot *)after
{
  NSMutableDictionary *targetValues = after.values;
  NSDictionary *preparedValues = [self prepareDataForAnimatingWorklet:targetValues frameConfig:EnteringFrame];
  _startAnimationForTag(view.reactTag, @"entering", preparedValues, @(0));
}

- (void)onViewUpdate:(UIView *)view before:(REASnapshot *)before after:(REASnapshot *)after
{
  NSMutableDictionary *targetValues = after.values;
  NSMutableDictionary *currentValues = before.values;
  NSDictionary *preparedValues = [self prepareDataForLayoutAnimatingWorklet:currentValues targetValues:targetValues];
  _startAnimationForTag(view.reactTag, @"layout", preparedValues, @(0));
}

- (void)onViewTransition:(UIView *)view before:(REASnapshot *)before after:(REASnapshot *)after
{
  NSMutableDictionary *targetValues = after.values;
  NSMutableDictionary *currentValues = before.values;
  [view.superview bringSubviewToFront:view];
  NSDictionary *preparedValues = [self prepareDataForLayoutAnimatingWorklet:currentValues targetValues:targetValues];
  _startAnimationForTag(view.reactTag, @"sharedElementTransition", preparedValues, @(0));
}

- (void)setNodeManager:(REANodesManager *)nodeManager
{
  _nodeManager = nodeManager;
}

- (REANodesManager *)getNodeManager
{
  return _nodeManager;
}

- (void)stopAnimation:(NSNumber *)tag
{
  if (_layoutAnimationsProxy.lock() != nullptr) {
    _layoutAnimationsProxy.lock()->stopObserving([tag intValue], true, false);
  }
}

- (void)setLayoutAnimationProxy:(std::shared_ptr<reanimated::LayoutAnimationsProxy>)layoutAnimationsProxy
{
  _layoutAnimationsProxy = layoutAnimationsProxy;
}

- (REASnapshot *)prepareSnapshotBeforeMountForView:(UIView *)view
{
  if (_hasAnimationForTag(view.reactTag, @"layout")) {
    return [[REASnapshot alloc] init:view];
  }
  return nil;
}

- (void)viewDidMount:(UIView *)view withBeforeSnapshot:(nonnull REASnapshot *)before
{
  NSString *type = before == nil ? @"entering" : @"layout";
  if (_hasAnimationForTag(view.reactTag, type)) {
    REASnapshot *after = [[REASnapshot alloc] init:view];
    if (before == nil) {
      [self onViewCreate:view after:after];
    } else {
      [self onViewUpdate:view before:before after:after];
    }
  }
}

- (void)removeAnimationsFromSubtree:(UIView *)view
{
  [self nodeFind:view
           block:^(id<RCTComponent> view) {
             self->_clearAnimationConfigForTag(view.reactTag, false);
             return false;
           }];
}

@end