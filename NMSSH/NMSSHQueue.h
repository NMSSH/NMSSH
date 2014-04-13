//
//  NMSSHQueue.h
//  NMSSH-iOS
//
//  Created by Tommaso Madonia on 13/04/14.
//  Copyright (c) 2014 Nine Muses AB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NMSSHQueue : NSObject

@property (nonatomic, readonly) dispatch_queue_t SSHQueue;

- (void)scheduleBlock:(dispatch_block_t)block synchronously:(BOOL)synchronously;
- (void)scheduleUniqueBlock:(dispatch_block_t)block withSignature:(NSString *)signature synchronously:(BOOL)synchronously;

@end
