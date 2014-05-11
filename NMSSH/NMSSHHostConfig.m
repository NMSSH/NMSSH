#import "NMSSHHostConfig.h"

@implementation NMSSHHostConfig

- (id)init {
    if ((self = [super init])) {
        [self setHostPatterns:@[ ]];
        [self setIdentityFiles:@[ ]];
    }
    return self;
}

@end

