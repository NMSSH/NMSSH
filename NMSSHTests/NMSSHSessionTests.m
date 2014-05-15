#import "NMSSHSessionTests.h"
#import "NMSSHConfig.h"
#import "NMSSHHostConfig.h"
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

    XCTAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a valid server does not throw exception");

    XCTAssertTrue([session isConnected],
                 @"Connection to valid server should work");
}

- (void)testConnectionToInvalidServerFails {
    NSString *host = [invalidServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];

    XCTAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a invalid server does not throw exception");

    XCTAssertFalse([session isConnected],
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

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with valid password doesn't throw"
                    @"exception");

    XCTAssertTrue([session isAuthorized],
                 @"Authentication with valid password should work");
}

- (void)testPasswordAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid password doesn't throw"
                    @"exception");

    XCTAssertFalse([session isAuthorized],
                 @"Authentication with invalid password should not work");
}

- (void)testPasswordAuthenticationWithInvalidUserFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid username/password doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
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

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Authentication with valid public key doesn't throw"
                    @"exception");

    XCTAssertTrue([session isAuthorized],
                  @"Authentication with valid public key should work");
}

- (void)testPublicKeyAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Public key authentication with invalid password doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
                 @"Public key authentication with invalid password should not"
                 @"work");
}


- (void)testPublicKeyAuthenticationWithInvalidKeyFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"invalid_public_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Authentication with invalid public key doesn't throw"
                    @"exception");

    XCTAssertFalse([session isAuthorized],
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

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Public key authentication with invalid user doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
                  @"Public key authentication with invalid user should not work");
}

- (void)testValidConnectionToAgent {
    NSString *host = [validAgentServer objectForKey:@"host"];
    NSString *username = [validAgentServer objectForKey:@"user"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session connectToAgent],
                    @"Valid connection to agent doesn't throw exception");

    XCTAssertTrue([session isAuthorized],
                 @"Agent authentication with valid username should work");
}

- (void)testInvalidConnectionToAgent {
    NSString *host = [validAgentServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session connectToAgent],
                    @"Invalid connection to agent doesn't throw exception");

    XCTAssertFalse([session isAuthorized],
                  @"Agent authentication with invalid username should not"
                  @"work");
}

// -----------------------------------------------------------------------------
// CONFIG TESTS
// -----------------------------------------------------------------------------

// Tests synthesis that uses some defaults, some global, and some local values,
// and merges identity files.
- (void)testConfigSynthesisFromChain {
    NMSSHConfig *globalConfig = [[NMSSHConfig alloc] initWithString:
                                    @"Host host\n"
                                    @"    Hostname globalHostname\n"
                                    @"    Port 9999\n"
                                    @"    IdentityFile idFile1\n"
                                    @"    IdentityFile idFile2"];
    NMSSHConfig *userConfig = [[NMSSHConfig alloc] initWithString:
                                  @"Host host\n"
                                  @"    Hostname localHostname\n"
                                  @"    IdentityFile idFile2\n"
                                  @"    IdentityFile idFile3"];
    NSArray *configChain = @[ userConfig, globalConfig ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"localHostname",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @9999,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"defaultUsername",
                          @"User not properly synthesized");
    NSArray *expected = @[ @"idFile2", @"idFile3", @"idFile1" ];
    XCTAssertEqualObjects(session.hostConfig.identityFiles, expected,
                          @"Identity files not properly synthesized");
}

// Tests that all default values can appear in the synthesized config.
- (void)testConfigSynthesisInheritsDefaults {
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:
                              @"Host nonMatchingHost\n"
                              @"    Hostname badHostname\n"
                              @"    Port 9999\n"
                              @"    User badUser\n"
                              @"    IdentityFile badIdFile\n"];
    NSArray *configChain = @[ config ];
    session = [[NMSSHSession alloc] initWithHost:@"goodHost"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"goodUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"goodHost",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @22,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"goodUsername",
                          @"User not properly synthesized");
    NSArray *expected = @[ ];
    XCTAssertEqualObjects(session.hostConfig.identityFiles, expected,
                          @"Identity files not properly synthesized");
}

// Tests that all values respect the priority hierarchy of the config chain.
- (void)testConfigSynthesisRespectsPriority {
    NMSSHConfig *globalConfig = [[NMSSHConfig alloc] initWithString:
                                    @"Host host\n"
                                    @"    Hostname globalHostname\n"
                                    @"    Port 9999\n"
                                    @"    User globalUser"];
    NMSSHConfig *userConfig = [[NMSSHConfig alloc] initWithString:
                                  @"Host host\n"
                                  @"    Hostname localHostname\n"
                                  @"    Port 8888\n"
                                  @"    User localUser"];
    NSArray *configChain = @[ userConfig, globalConfig ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"localHostname",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @8888,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"localUser",
                          @"User not properly synthesized");
}

// Tests that values from the config are used in creating the session.
- (void)testConfigIsUsed {
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:
                           @"Host host\n"
                           @"    Hostname configHostname\n"
                           @"    Port 9999\n"
                           @"    User configUser\n"];
    NSArray *configChain = @[ config ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.host, @"configHostname",
                          @"Hostname from config not used");
    XCTAssertEqualObjects(session.port, @9999,
                          @"Port from config not used");
    XCTAssertEqualObjects(session.username, @"configUser",
                          @"User from config not used");
}

@end
