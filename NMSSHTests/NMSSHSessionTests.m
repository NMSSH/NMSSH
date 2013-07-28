#import "NMSSHSessionTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSSHSessionTests () {
    NSDictionary *validPasswordProtectedServer;
    NSDictionary *validPublicKeyProtectedServer;
    NSDictionary *validAgentServer;
    NSDictionary *invalidServer;

    NMSSHSession *session;
}
@end

@implementation NMSSHSessionTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    validPasswordProtectedServer = [ConfigHelper valueForKey:
                                    @"valid_password_protected_server"];
    validPublicKeyProtectedServer = [ConfigHelper valueForKey:
                                     @"valid_public_key_protected_server"];
    invalidServer = [ConfigHelper valueForKey:@"invalid_server"];
    validAgentServer = [ConfigHelper valueForKey:@"valid_agent_server"];
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
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];

    STAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a valid server does not throw exception");

    STAssertTrue([session isConnected],
                 @"Connection to valid server should work");
}

- (void)testConnectionToInvalidServerFails {
    NSString *host = [invalidServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];

    STAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a invalid server does not throw exception");

    STAssertFalse([session isConnected],
                 @"Connection to invalid server should not work");
}

// -----------------------------------------------------------------------------
// AUTHENTICATION TESTS
// -----------------------------------------------------------------------------

- (void)testPasswordAuthenticationWithValidPasswordWorks {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];
    NSString *password = [validPasswordProtectedServer
                               objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with valid password doesn't throw"
                    @"exception");

    STAssertTrue([session isAuthorized],
                 @"Authentication with valid password should work");
}

- (void)testPasswordAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid password doesn't throw"
                    @"exception");

    STAssertFalse([session isAuthorized],
                 @"Authentication with invalid password should not work");
}

- (void)testPasswordAuthenticationWithInvalidUserFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid username/password doesn't"
                    @"throw exception");

    STAssertFalse([session isAuthorized],
                  @"Authentication with invalid username/password should not"
                  @"work");
}

- (void)testPublicKeyAuthenticationWithValidKeyWorks {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];
    NSString *password = [validPublicKeyProtectedServer
                          objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Authentication with valid public key doesn't throw"
                    @"exception");

    STAssertTrue([session isAuthorized],
                  @"Authentication with valid public key should work");
}

- (void)testPublicKeyAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Public key authentication with invalid password doesn't"
                    @"throw exception");

    STAssertFalse([session isAuthorized],
                 @"Public key authentication with invalid password should not"
                 @"work");
}


- (void)testPublicKeyAuthenticationWithInvalidKeyFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"invalid_public_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Authentication with invalid public key doesn't throw"
                    @"exception");

    STAssertFalse([session isAuthorized],
                 @"Authentication with invalid public key should not work");
}

- (void)testPublicKeyAuthenticationWithInvalidUserFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];
    NSString *password = [validPublicKeyProtectedServer
                          objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Public key authentication with invalid user doesn't"
                    @"throw exception");

    STAssertFalse([session isAuthorized],
                  @"Public key authentication with invalid user should not work");
}

- (void)testValidConnectionToAgent {
    NSString *host = [validAgentServer objectForKey:@"host"];
    NSString *username = [validAgentServer objectForKey:@"user"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session connectToAgent],
                    @"Valid connection to agent doesn't throw exception");

    STAssertTrue([session isAuthorized],
                 @"Agent authentication with valid username should work");
}

- (void)testInvalidConnectionToAgent {
    NSString *host = [validAgentServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    STAssertNoThrow([session connectToAgent],
                    @"Invalid connection to agent doesn't throw exception");

    STAssertFalse([session isAuthorized],
                  @"Agent authentication with invalid username should not"
                  @"work");
}

@end
