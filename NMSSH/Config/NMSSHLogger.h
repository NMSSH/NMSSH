#ifndef NMSSH_DISABLE_LOGGING
    #ifdef LOG_VERBOSE
        #define NMSSH_LOG_CONTEXT 22

        #define NMSSHLogError(frmt, ...)     SYNC_LOG_OBJC_MAYBE(ddLogLevel, LOG_FLAG_ERROR,   NMSSH_LOG_CONTEXT, frmt, ##__VA_ARGS__)
        #define NMSSHLogWarn(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(ddLogLevel, LOG_FLAG_WARN,    NMSSH_LOG_CONTEXT, frmt, ##__VA_ARGS__)
        #define NMSSHLogInfo(frmt, ...)     ASYNC_LOG_OBJC_MAYBE(ddLogLevel, LOG_FLAG_INFO,    NMSSH_LOG_CONTEXT, frmt, ##__VA_ARGS__)
        #define NMSSHLogVerbose(frmt, ...)  ASYNC_LOG_OBJC_MAYBE(ddLogLevel, LOG_FLAG_VERBOSE, NMSSH_LOG_CONTEXT, frmt, ##__VA_ARGS__)
    #else
        #define NMSSHLogError(frmt, ...)    NSLog(frmt, ##__VA_ARGS__)
        #define NMSSHLogWarn(frmt, ...)     NSLog(frmt, ##__VA_ARGS__)
        #define NMSSHLogInfo(frmt, ...)     NSLog(frmt, ##__VA_ARGS__)
        #define NMSSHLogVerbose(frmt, ...)  NSLog(frmt, ##__VA_ARGS__)
    #endif
#else
    #define NMSSHLogError(frmt, ...)
    #define NMSSHLogWarn(frmt, ...)
    #define NMSSHLogInfo(frmt, ...)
    #define NMSSHLogVerbose(frmt, ...)
#endif