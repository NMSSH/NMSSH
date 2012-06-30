#import "NMSSHChannel.h"
#import "NMSSHSession.h"

#import "libssh2.h"

@interface NMSSHChannel () {
    LIBSSH2_CHANNEL *channel;
}
@end

@implementation NMSSHChannel
@synthesize session, lastResponse;

// -----------------------------------------------------------------------------
// PUBLIC SETUP API
// -----------------------------------------------------------------------------

- (id)initWithSession:(NMSSHSession *)aSession {
    if ((self = [super init])) {
        session = aSession;

        // Make sure we were provided a valid session
        if (![session isKindOfClass:[NMSSHSession class]]) {
            return nil;
        }

        // Open up the channel
        if (!(channel = libssh2_channel_open_session([session rawSession]))) {
            NSLog(@"NMSSH: Unable to open a session");
            return nil;
        }
    }

    return self;
}

- (void)close {
    if (channel) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        channel = nil;
    }
}

// -----------------------------------------------------------------------------
// PUBLIC SHELL EXECUTION API
// -----------------------------------------------------------------------------

- (NSString *)execute:(NSString *)command error:(NSError **)error {
    lastResponse = nil;

    // In case of error...
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:command
                                                         forKey:@"command"];

    // Try executing command
    int rc = libssh2_channel_exec(channel, [command UTF8String]);
    if (rc) {
        *error = [NSError errorWithDomain:@"NMSSH"
                                     code:NMSSHChannelExecutionError
                                 userInfo:userInfo];

        NSLog(@"NMSSH: Error executing command");
        return nil;
    }

    // Fetch response from output buffer
    for (;;) {
        int rc;
        do {
            char buffer[0x4000];
            rc = libssh2_channel_read(channel, buffer, sizeof(buffer));

            if (rc != LIBSSH2_ERROR_EAGAIN) {
                lastResponse = [NSString stringWithCString:buffer
                                                  encoding:NSUTF8StringEncoding];
                return lastResponse;
            }
        }
        while (rc > 0);
    }

    // If we've got this far, it means fetching execution response failed
    *error = [NSError errorWithDomain:@"NMSSH"
                                 code:NMSSHChannelExecutionResponseError
                             userInfo:userInfo];

    NSLog(@"NMSSH: Error fetching response from command");
    return nil;
}

@end
