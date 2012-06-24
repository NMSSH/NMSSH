#import "NMSSHSessionTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSSHSessionTests () {
    NSString *validHost;
    NSString *validUsername;
    NSString *invalidHost;
    NSString *invalidUsername;

    NMSSHSession *session;
}
@end

@implementation NMSSHSessionTests

- (void)setUp {
    validHost = [ConfigHelper valueForKey:
                 @"valid_password_protected_server.host"];
    validUsername = [ConfigHelper valueForKey:
                     @"valid_password_protected_server.user"];

    invalidHost = [ConfigHelper valueForKey:@"invalid_server.host"];
    invalidUsername = [ConfigHelper valueForKey:@"invalid_server.user"];
}

- (void)tearDown {
    if (session) {
        [session disconnect];
        session = nil;
    }
}

- (void)testConnectionToValidServerDoesntThrowException {
    STAssertNoThrow(session = [NMSSHSession connectToHost:validHost
                                             withUsername:validUsername],
                    @"Connecting to a valid server does not throw exception");
}

- (void)testConnectionToInvalidServerDoesntThrowException {
    STAssertNoThrow(session = [NMSSHSession connectToHost:invalidHost
                                             withUsername:invalidUsername],
                    @"Connecting to a valid server does not throw exception");
}

- (void)testConnectionToValidServerWorks {
    session = [NMSSHSession connectToHost:validHost
                                           withUsername:validUsername];
    STAssertTrue([session isConnected],
                 @"Connection to valid server should work");
}

- (void)testConnectionToInvalidServerFails {
    session = [NMSSHSession connectToHost:invalidHost
                                           withUsername:invalidUsername];
    STAssertFalse([session isConnected],
                 @"Connection to invalid server should not work");
}

@end
