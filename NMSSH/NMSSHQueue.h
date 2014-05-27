#import <Foundation/Foundation.h>

@interface NMSSHQueue : NSObject

@property (nonatomic, readonly) dispatch_queue_t SSHQueue;

- (void)scheduleBlock:(dispatch_block_t)block synchronously:(BOOL)synchronously;
- (void)scheduleUniqueBlock:(dispatch_block_t)block withSignature:(NSString *)signature synchronously:(BOOL)synchronously;

@end
