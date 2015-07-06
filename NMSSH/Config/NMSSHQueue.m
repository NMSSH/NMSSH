#import "NMSSHQueue.h"

@interface NMSSHQueue ()
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong, readwrite) dispatch_queue_t SSHQueue;
@property (nonatomic, strong) dispatch_queue_t signatureQueue;
#else
@property (nonatomic, assign, readwrite) dispatch_queue_t SSHQueue;
@property (nonatomic, assign) dispatch_queue_t signatureQueue;
#endif
@property (nonatomic, strong) NSMutableArray *signatureBlocks;
@end

static const void *const kNMSSHQueueIdentifier = &kNMSSHQueueIdentifier;

@implementation NMSSHQueue

- (instancetype)init {
    self = [super init];

    if (self) {
        self.signatureBlocks = [[NSMutableArray alloc] init];
        self.signatureQueue = dispatch_queue_create("NMSSH.signatureQueue", DISPATCH_QUEUE_SERIAL);
        self.SSHQueue = dispatch_queue_create("NMSSH.SSHQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.SSHQueue, kNMSSHQueueIdentifier, (void *)kNMSSHQueueIdentifier, NULL);
    }

    return self;
}

#if !OS_OBJECT_USE_OBJC
- (void)dealloc {
    dispatch_release(_SSHQueue);
    dispatch_release(_signatureQueue);
}
#endif

- (BOOL)isCurrentQueue {
    return dispatch_queue_get_specific(self.SSHQueue, kNMSSHQueueIdentifier) != NULL;
}

- (void)scheduleBlock:(dispatch_block_t)block synchronously:(BOOL)synchronously {
    if (synchronously) {
        if ([self isCurrentQueue]) {
            block();
        } else {
            dispatch_sync(self.SSHQueue, block);
        }
    }
    else {
        dispatch_async(self.SSHQueue, block);
    }
}

- (void)scheduleUniqueBlock:(dispatch_block_t)block withSignature:(NSString *)signature synchronously:(BOOL)synchronously {
    if (![self addSignature:signature]) {
        return ;
    }

    [self scheduleBlock:^{
        block();
        [self removeSignature:signature];
    } synchronously:synchronously];
}

- (BOOL)addSignature:(NSString *)signature {
    __block BOOL queued;
    dispatch_sync(self.signatureQueue, ^{
        queued = ![self.signatureBlocks containsObject:signature];
        if (queued) {
            [self.signatureBlocks addObject:signature];
        }
    });

    return queued;
}

- (void)removeSignature:(NSString *)signature {
    dispatch_sync(self.signatureQueue, ^{
        [self.signatureBlocks removeObject:signature];
    });
}

@end
