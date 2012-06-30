#import "NMSSHChannelTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSSHChannelTests () {
    NSDictionary *settings;

    NMSSHChannel *channel;
    NMSSHSession *session;
}
@end

@implementation NMSSHChannelTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    settings = [ConfigHelper valueForKey:@"valid_password_protected_server"];

    session = [NMSSHSession connectToHost:[settings objectForKey:@"host"]
                             withUsername:[settings objectForKey:@"user"]];
    [session authenticateByPassword:[settings objectForKey:@"password"]];
    assert([session isAuthorized]);
}

- (void)tearDown {
    if (channel) {
        [channel close];
        channel = nil;
    }

    if (session) {
        [session disconnect];
        session = nil;
    }
}

// -----------------------------------------------------------------------------
// SHELL EXECUTION TESTS
// -----------------------------------------------------------------------------

- (void)testCreatingChannelWorks {
    STAssertNoThrow(channel = [[NMSSHChannel alloc] initWithSession:session],
                    @"Setting up channel does not throw exception");
}

- (void)testExecutingShellCommand {
    channel = [[NMSSHChannel alloc] initWithSession:session];

    NSError *error = nil;
    STAssertNoThrow([channel execute:[settings objectForKey:@"execute_command"]
                               error:&error],
                    @"Execution should not throw an exception");

    STAssertEqualObjects([channel lastResponse],
                         [settings objectForKey:@"execute_expected_response"],
                         @"Execution returns the expected response");
}

@end
