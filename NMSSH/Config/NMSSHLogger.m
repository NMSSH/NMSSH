#import "NMSSHLogger.h"

typedef NS_OPTIONS(NSUInteger, NMSSHLogFlag) {
    NMSSHLogFlagVerbose = (1 << 0),
    NMSSHLogFlagInfo    = (1 << 1),
    NMSSHLogFlagWarn    = (1 << 2),
    NMSSHLogFlagError   = (1 << 3)
};

@interface NMSSHLogger ()
@property (nonatomic, copy) void (^logBlockBackup)(NMSSHLogLevel level, NSString *format);
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
    }

    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - LOGGER SETTINGS
// -----------------------------------------------------------------------------

- (void)setEnabled:(BOOL)enabled {
    if (enabled == _enabled) {
        return;
    }

    _enabled = enabled;

    if (enabled) {
        [self setLogBlock:self.logBlockBackup];
    } else {
        [self setLogBlock:^(NMSSHLogLevel level, NSString *format) {}];
    }
}

// -----------------------------------------------------------------------------
#pragma mark - LOGGING
// -----------------------------------------------------------------------------

- (void)log:(NSString *)format level:(NMSSHLogLevel)level flag:(NMSSHLogFlag)flag {
    if (flag & self.logLevel) {
        self.logBlock(level, format);
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
