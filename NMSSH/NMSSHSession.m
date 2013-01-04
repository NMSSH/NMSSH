#import "NMSSHSession.h"
#import "NMSSHChannel.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

@interface NMSSHSession () {
    int sock;
    LIBSSH2_AGENT *agent;
}
@end

@implementation NMSSHSession
@synthesize session, host, username, connected;
@synthesize channel;

// -----------------------------------------------------------------------------
// PUBLIC CONNECTION API
// -----------------------------------------------------------------------------

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                   andUsername:username];
    [session connect];

    return session;
}

- (id)initWithHost:(NSString *)aHost andUsername:(NSString *)aUsername {
    if ((self = [super init])) {
        host = aHost;
        username = aUsername;
        connected = NO;
    }

    return self;
}

- (BOOL)connect {
    // Try to initialize libssh2
    if (libssh2_init(0) != 0) {
        NSLog(@"NMSSH: libssh2 initialization failed");
        return NO;
    }

    // Try to establish a connection to the server
    sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons([[self port] intValue]);
    sin.sin_addr.s_addr = inet_addr([[self hostIPAddress] UTF8String]);
    if (connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0) {
        NSLog(@"NMSSH: Failed connection to socket");
        return NO;
    }

    // Create a session instance and start it up.
    session = libssh2_session_init();
    if (libssh2_session_handshake(session, sock)) {
        NSLog(@"NMSSH: Failure establishing SSH session");
        return NO;
    }

    // We managed to successfully setup a connection
    connected = YES;
    return [self isConnected];
}

- (void)disconnect {
    if (agent) {
        libssh2_agent_disconnect(agent);
        libssh2_agent_free(agent);
        agent = nil;
    }

    if (session) {
        libssh2_session_disconnect(session, "NMSSH: Disconnect");
        libssh2_session_free(session);
        session = nil;
    }

    if (sock) {
        close(sock);
    }

    libssh2_exit();
}

// -----------------------------------------------------------------------------
// PUBLIC AUTHENTICATION API
// -----------------------------------------------------------------------------

- (BOOL)isAuthorized {
    if (session) {
        return libssh2_userauth_authenticated(session) == 1;
    } else {
        return NO;
    }
}

- (BOOL)authenticateByPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"password"]) {
        return NO;
    }

    // Try to authenticate by password
    int error = libssh2_userauth_password(session, [username UTF8String],
                                           [password UTF8String]);
    if (error) {
        NSLog(@"NMSSH: Password authentication failed");
        return NO;
    }

    return [self isAuthorized];
}

- (BOOL)authenticateByPublicKey:(NSString *)publicKey
                    andPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    if (password == nil) {
        password = @"";
    }

    // Get absolute paths for private/public key pair
    publicKey = [publicKey stringByExpandingTildeInPath];
    NSString *privateKey = [publicKey stringByReplacingOccurrencesOfString:@".pub"
                                                                withString:@""];

    // Try to authenticate with key pair and password
    int error = libssh2_userauth_publickey_fromfile(session,
                                                    [username UTF8String],
                                                    [publicKey UTF8String],
                                                    [privateKey UTF8String],
                                                    [password UTF8String]);

    if (error) {
        NSLog(@"NMSSH: Public key authentication failed");
        return NO;
    }

    return [self isAuthorized];
}

- (BOOL)connectToAgent {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    // Try to setup a connection to the SSH-agent
    agent = libssh2_agent_init(session);
    if (!agent) {
        NSLog(@"NMSSH: Could not start a new agent");
        return NO;
    }

    // Try connecting to the agent
    if (libssh2_agent_connect(agent)) {
        NSLog(@"NMSSH: Failed connection to agent");
        return NO;
    }

    // Try to fetch available SSH identities
    if (libssh2_agent_list_identities(agent)) {
        NSLog(@"NMSSH: Failed to request agent identities");
        return NO;
    }

    // Search for the correct identity and try to authenticate
    struct libssh2_agent_publickey *identity, *prev_identity = NULL;
    while (1) {
        int error = libssh2_agent_get_identity(agent, &identity, prev_identity);
        if (error) {
            NSLog(@"NMSSH: Failed to find a valid identity for the agent");
            return NO;
        }

        error = libssh2_agent_userauth(agent, [username UTF8String], identity);
        if (!error) {
            return [self isAuthorized];
        }

        prev_identity = identity;
    }

    return NO;
}

// -----------------------------------------------------------------------------
// PUBLIC INTEGRATION API
// -----------------------------------------------------------------------------

- (NMSSHChannel *)channel {
    if (!channel) {
        channel = [[NMSSHChannel alloc] initWithSession:self];
    }

    return channel;
}

// -----------------------------------------------------------------------------
// PRIVATE HOST NAME HELPERS
// -----------------------------------------------------------------------------

- (NSString *)hostIPAddress {
    NSString *addr = [[host componentsSeparatedByString:@":"] objectAtIndex:0];

    if (![self isIp:addr]) {
        return [self ipFromDomainName:addr];
    }

    return addr;
}

- (BOOL)isIp:(NSString *)address {
    struct in_addr pin;
    int success = inet_aton([address UTF8String], &pin);
    return (success == 1);
}

- (NSString *)ipFromDomainName:(NSString *)address {
    struct hostent *hostEnt = gethostbyname([address UTF8String]);

    if (hostEnt && hostEnt->h_addr_list && hostEnt->h_addr_list[0]) {
        struct in_addr *inAddr = (struct in_addr *)hostEnt->h_addr_list[0];
        return [NSString stringWithFormat:@"%s", inet_ntoa(*inAddr)];
    }

    return @"";
}

- (NSNumber *)port {
    NSArray *hostComponents = [host componentsSeparatedByString:@":"];

    // If no port was defined, use 22 by default
    if ([hostComponents count] == 1) {
        return [NSNumber numberWithInt:22];
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];

    return [formatter numberFromString:[hostComponents objectAtIndex:1]];
}

// -----------------------------------------------------------------------------
// PRIVATE CONNECTION HELPERS
// -----------------------------------------------------------------------------

- (BOOL)supportsAuthenticationMethod:(NSString *)method {
    char *userauthlist = libssh2_userauth_list(session, [username UTF8String],
                                   (unsigned int)strlen([username UTF8String]));

    if (strstr(userauthlist, [method UTF8String]) == NULL) {
        NSLog(@"NMSSH: Authentication by %@ not available for %@", method, host);
        return NO;
    }

    return YES;
}

@end
