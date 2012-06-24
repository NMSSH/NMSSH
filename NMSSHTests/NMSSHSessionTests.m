#import "NMSSHSessionTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSSHSessionTests () {
    NSString *validHost;
    NSString *validUsername;
    NSString *validPassword;

    NSString *invalidHost;
    NSString *invalidUsername;
    NSString *invalidPassword;

    NMSSHSession *session;
}
@end

@implementation NMSSHSessionTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    validHost = [ConfigHelper valueForKey:
                 @"valid_password_protected_server.host"];
    validUsername = [ConfigHelper valueForKey:
                     @"valid_password_protected_server.user"];
    validPassword = [ConfigHelper valueForKey:
                     @"valid_password_protected_server.password"];

    invalidHost = [ConfigHelper valueForKey:@"invalid_server.host"];
    invalidUsername = [ConfigHelper valueForKey:@"invalid_server.user"];
    invalidPassword = [ConfigHelper valueForKey:@"invalid_server.password"];
}

- (void)tearDown {
    if (session) {
        [session disconnect];
        session = nil;
    }
}

// -----------------------------------------------------------------------------
// CONNECTION TESTS
// -----------------------------------------------------------------------------

- (void)testConnectionToValidServerWorks {
    STAssertNoThrow(session = [NMSSHSession connectToHost:validHost
                                             withUsername:validUsername],
                    @"Connecting to a valid server does not throw exception");

    STAssertTrue([session isConnected],
                 @"Connection to valid server should work");
}

- (void)testConnectionToInvalidServerFails {
    STAssertNoThrow(session = [NMSSHSession connectToHost:invalidHost
                                             withUsername:invalidUsername],
                    @"Connecting to a invalid server does not throw exception");

    STAssertFalse([session isConnected],
                 @"Connection to invalid server should not work");
}

// -----------------------------------------------------------------------------
// AUTHENTICATION TESTS
// -----------------------------------------------------------------------------

- (void)testPasswordAuthenticationWithValidPasswordWorks {
    session = [NMSSHSession connectToHost:validHost withUsername:validUsername];

    STAssertNoThrow([session authenticateByPassword:validPassword],
                    @"Authentication with valid password doesn't throw"
                    @"exception");

    STAssertTrue([session isAuthorized],
                 @"Authentication with valid password should work");
}

- (void)testPasswordAuthenticationWithInvalidPasswordFails {
    session = [NMSSHSession connectToHost:validHost withUsername:validUsername];

    STAssertNoThrow([session authenticateByPassword:invalidPassword],
                    @"Authentication with invalid password doesn't throw"
                    @"exception");

    STAssertFalse([session isAuthorized],
                 @"Authentication with invalid password should not work");
}

- (void)testPasswordAuthenticationWithInvalidUserFails {
    session = [NMSSHSession connectToHost:validHost
                             withUsername:invalidUsername];
    
    STAssertNoThrow([session authenticateByPassword:invalidPassword],
                    @"Authentication with invalid username/password doesn't"
                    @"throw exception");
    
    STAssertFalse([session isAuthorized],
                  @"Authentication with invalid username/password should not"
                  @"work");
}

@end