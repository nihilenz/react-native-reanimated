import NativeReanimatedModule from './NativeReanimated';
import { runOnUI, runOnJS } from './threads';

function callGuard<T extends Array<any>, U>(
  fn: (...args: T) => U,
  ...args: T
): void {
  'worklet';
  try {
    fn(...args);
  } catch (e) {
    if (global.ErrorUtils) {
      global.ErrorUtils.reportFatalError(e);
    } else {
      throw e;
    }
  }
}

function valueUnpacker(objectToUnpack: any, category?: string): any {
  'worklet';
  let workletsCache = global.__workletsCache;
  let handleCache = global.__handleCache;
  if (workletsCache === undefined) {
    // init
    workletsCache = global.__workletsCache = new Map();
    handleCache = global.__handleCache = new WeakMap();
  }
  if (objectToUnpack.__workletHash) {
    let workletFun = workletsCache.get(objectToUnpack.__workletHash);
    if (workletFun === undefined) {
      // eslint-disable-next-line no-eval
      workletFun = evalWithSourceMap(
        '(' + objectToUnpack.asString + '\n)',
        objectToUnpack.__sourceMap,
        objectToUnpack.__location
      ) as (...args: any[]) => any;
      workletsCache.set(objectToUnpack.__workletHash, workletFun);
    }
    const functionInstance = workletFun.bind(objectToUnpack);
    objectToUnpack._recur = functionInstance;
    return functionInstance;
  } else if (objectToUnpack.__init) {
    let value = handleCache!.get(objectToUnpack);
    if (value === undefined) {
      value = objectToUnpack.__init();
      handleCache!.set(objectToUnpack, value);
    }
    return value;
  } else if (category === 'RemoteFunction') {
    const fun = () => {
      throw new Error(`Tried to synchronously call a non-worklet function on the UI thread.

Possible solutions are:
  a) If you want to synchronously execute this method, mark it as a worklet
  b) If you want to execute this function on the JS thread, wrap it using \`runOnJS\``);
    };
    fun.__remoteFunction = objectToUnpack;
    return fun;
  } else {
    throw new Error('data type not recognized by unpack method');
  }
}

function reportFatalErrorOnJS({
  message,
  stack,
}: {
  message: string;
  stack?: string;
}) {
  const error = new Error();
  error.message = message;
  error.stack = stack;
  error.name = 'ReanimatedError';
  error.jsEngine = 'reanimated';
  ErrorUtils.reportFatalError(error);
}

export function initializeUIRuntime() {
  NativeReanimatedModule.installCoreFunctions(callGuard, valueUnpacker);

  const capturableConsole = console;
  runOnUI(() => {
    'worklet';
    // setup error handler
    global.ErrorUtils = {
      reportFatalError: (error: Error) => {
        runOnJS(reportFatalErrorOnJS)({
          message: error.message,
          stack: error.stack,
        });
      },
    };

    // setup console
    const console = {
      debug: runOnJS(capturableConsole.debug),
      log: runOnJS(capturableConsole.log),
      warn: runOnJS(capturableConsole.warn),
      error: runOnJS(capturableConsole.error),
      info: runOnJS(capturableConsole.info),
    };
    _setGlobalConsole(console);
  })();
}