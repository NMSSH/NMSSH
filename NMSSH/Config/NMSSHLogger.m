#import "NMSSHLogger.h"

typedef NS_OPTIONS(NSUInteger, NMSSHLogFlag) {
    NMSSHLogFlagVerbose = (1 << 0),
    NMSSHLogFlagInfo    = (1 << 1),
    NMSSHLogFlagWarn    = (1 << 2),
    NMSSHLogFlagError   = (1 << 3)
};

@interface NMSSHLogger ()
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t loggerQueue;
#else
@property (nonatomic, assign) dispatch_queue_t loggerQueue;
#endif
@end

@implementation NMSSHLogger

// -----------------------------------------------------------------------------
#pragma mark - INITIALIZE THE LOGGER INSTANCE
// -----------------------------------------------------------------------------

+ (NMSSHLogger *)logger {
    static NMSSHLogger *logger;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[NMSSHLogger alloc] init];
    });

    return logger;
}

- (id)init {
    if ((self = [super init])) {
        [self setEnabled:YES];
        [self setLogLevel:NMSSHLogLevelVerbose];
        [self setLogBlock:^(NMSSHLogLevel level, NSString *format) {
            NSLog(@"%@", format);
        }];
        [self setLoggerQueue:dispatch_queue_create("NMSSH.loggerQueue", DISPATCH_QUEUE_SERIAL)];
    }

    return self;
}

#if !(OS_OBJECT_USE_OBJC)
- (void)dealloc {
    dispatch_release(self.loggerQueue);
}
#endif

// -----------------------------------------------------------------------------
#pragma mark - LOGGING
// -----------------------------------------------------------------------------

- (void)log:(NSString *)format level:(NMSSHLogLevel)level flag:(NMSSHLogFlag)flag {
    if (flag & self.logLevel && self.enabled) {
        dispatch_async(self.loggerQueue, ^{
            self.logBlock(level, format);
        });
    }
}

- (void)logVerbose:(NSString *)format {
    [self log:format level:NMSSHLogLevelVerbose flag:NMSSHLogFlagVerbose];
}

- (void)logInfo:(NSString *)format{
    [self log:format level:NMSSHLogLevelInfo flag:NMSSHLogFlagInfo];
}

- (void)logWarn:(NSString *)format{
    [self log:format level:NMSSHLogLevelWarn flag:NMSSHLogFlagWarn];
}

- (void)logError:(NSString *)format{
    [self log:format level:NMSSHLogLevelError flag:NMSSHLogFlagError];
}

@end
