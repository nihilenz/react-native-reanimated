import type {
  AnimatedStyle,
  StyleProps,
  MeasuredDimensions,
  MapperRegistry,
  ShareableRef,
  ShareableSyncDataHolderRef,
} from './commonTypes';
import type { ReanimatedConsole } from './core';
import type { FrameCallbackRegistryUI } from './frameCallback/FrameCallbackRegistryUI';
import type { ShadowNodeWrapper } from './hook/commonTypes';
import type { NativeReanimated } from './NativeReanimated/NativeReanimated';

declare global {
  const _WORKLET: boolean;
  const _IS_FABRIC: boolean;
  const _frameTimestamp: number | null;
  const _eventTimestamp: number;
  const __reanimatedModuleProxy: NativeReanimated;
  const _setGlobalConsole: (console?: ReanimatedConsole) => void;
  const _log: (s: string) => void;
  const _getCurrentTime: () => number;
  const _getTimestamp: () => number;
  const _stopObservingProgress: (tag: number, flag: boolean) => void;
  const _notifyAboutProgress: (tag: number, value: number) => void;
  const _notifyAboutEnd: (tag: number, finished: boolean) => void;
  const _setGestureState: (handlerTag: number, newState: number) => void;
  const _makeShareableClone: (value: any) => any;
  const _updateDataSynchronously: (
    dataHolder: ShareableSyncDataHolderRef,
    data: ShareableRef
  ) => void;
  const _scheduleOnJS: (fun: ShareableRef, args?: ShareableRef) => void;
  const _updatePropsPaper: (
    tag: number,
    name: string,
    updates: StyleProps | AnimatedStyle
  ) => void;
  const _updatePropsFabric: (
    shadowNodeWrapper: ShadowNodeWrapper,
    props: StyleProps | AnimatedStyle
  ) => void;
  const _removeShadowNodeFromRegistry: (
    shadowNodeWrapper: ShadowNodeWrapper
  ) => void;
  const _measure: (viewTag: number) => MeasuredDimensions;
  const _scrollTo: (
    viewTag: number,
    x: number,
    y: number,
    animated: boolean
  ) => void;
  const _dispatchCommand: (
    shadowNodeWrapper: ShadowNodeWrapper,
    commandName: string,
    args: Array<unknown>
  ) => void;
  const _chronoNow: () => number;
  const performance: { now: () => number };
  const LayoutAnimationRepository: {
    configs: Record<string, unknown>;
    registerConfig(tag: number, config: Record<string, unknown>): void;
    removeConfig(tag: number): void;
    startAnimationForTag(tag: number, type: string, yogaValues: unknown): void;
  };
  const ReanimatedDataMock: {
    now: () => number;
  };
  const _frameCallbackRegistry: FrameCallbackRegistryUI;

  namespace NodeJS {
    interface Global {
      _WORKLET: boolean;
      _IS_FABRIC: boolean;
      _frameTimestamp: number | null;
      _eventTimestamp: number;
      __reanimatedModuleProxy: NativeReanimated;
      _setGlobalConsole: (console?: ReanimatedConsole) => void;
      _log: (s: string) => void;
      _getCurrentTime: () => number;
      _getTimestamp: () => number;
      _stopObservingProgress: (tag: number, flag: boolean) => void;
      _startObservingProgress: (
        tag: number,
        flag: { value: boolean; _value: boolean }
      ) => void;
      _setGestureState: (handlerTag: number, newState: number) => void;
      _makeShareableClone: (value: any) => any;
      _updateDataSynchronously: (
        ShareableSyncDataHolderRef,
        ShareableRef
      ) => void;
      _scheduleOnJS: (fun: ShareableRef, args?: ShareableRef) => void;
      _updatePropsPaper: (
        tag: number,
        name: string,
        updates: StyleProps | AnimatedStyle
      ) => void;
      _updatePropsFabric: (
        shadowNodeWrapper: ShadowNodeWrapper,
        props: StyleProps | AnimatedStyle
      ) => void;
      _removeShadowNodeFromRegistry: (
        shadowNodeWrapper: ShadowNodeWrapper
      ) => void;
      _measure: (viewTag: number) => MeasuredDimensions;
      _scrollTo: (
        viewTag: number,
        x: number,
        y: number,
        animated: boolean
      ) => void;
      _dispatchCommand: (
        shadowNodeWrapper: ShadowNodeWrapper,
        commandName: string,
        args: Array<unknown>
      ) => void;
      _chronoNow: () => number;
      performance: { now: () => number };
      LayoutAnimationRepository: {
        configs: Record<string, unknown>;
        registerConfig(tag: number, config: Record<string, unknown>): void;
        removeConfig(tag: number): void;
        startAnimationForTag(
          tag: number,
          type: string,
          yogaValues: unknown
        ): void;
      };
      ReanimatedDataMock: {
        now: () => number;
      };
      _frameCallbackRegistry: FrameCallbackRegistryUI;
      __workletsCache?: Map<string, (...args: any[]) => any>;
      __handleCache?: WeakMap<any, any>;
      __mapperRegistry?: MapperRegistry;
    }
  }
}
