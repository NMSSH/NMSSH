#ifndef NMSSH_Protected_h
#define NMSSH_Protected_h

#import <CoreFoundation/CoreFoundation.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import "socket_helper.h"
#import "NMSSHQueue.h"

#define kNMSSHBufferSize (0x4000)

#define NMSSHLogDebug(frmt, ...) [[NMSSHLogger logger] logDebug:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogInfo(frmt, ...) [[NMSSHLogger logger] logInfo:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogWarn(frmt, ...) [[NMSSHLogger logger] logWarn:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define NMSSHLogError(frmt, ...) [[NMSSHLogger logger] logError:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]

#define strlen (unsigned int)strlen

#define RUN_BLOCK_ON_MAIN_THREAD(block, ...) block ? dispatch_async(dispatch_get_main_queue(), ^{block(__VA_ARGS__);}) : nil

@interface NMSSHSession ()
@property (nonatomic, strong) NMSSHQueue *queue;
@end

@interface NMSSHChannel ()
- (void)closeShell;
@end

#endif
