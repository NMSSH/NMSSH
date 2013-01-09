#import "NMSSH.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

@interface NMSSHSession () {
    int sock;
    LIBSSH2_AGENT *agent;
}
@end

@implementation NMSSHSession

@synthesize channel = _channel;

// -----------------------------------------------------------------------------
// PUBLIC CONNECTION API
// -----------------------------------------------------------------------------

+ (id)connectToHost:(NSString *)host port:(NSInteger)port withUsername:(NSString *)username {
    return [self connectToHost:[NSString stringWithFormat:@"%@:%i", host, port]
                  withUsername:username];
}

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                   andUsername:username];
    [session connect];

    return session;
}

- (id)initWithHost:(NSString *)host port:(NSInteger)port andUsername:(NSString *)username {
    return [self initWithHost:[NSString stringWithFormat:@"%@:%i", host, port]
                  andUsername:username];
}

- (id)initWithHost:(NSString *)host andUsername:(NSString *)username {
    if ((self = [super init])) {
        _host = host;
        _username = username;
        _connected = NO;
    }

    return self;
}

- (BOOL)connect {
    return [self connectWithTimeout:[NSNumber numberWithLong:10]];
}

- (BOOL)connectWithTimeout:(NSNumber *)timeout {
    if ([self isConnected]) {
        [self disconnect];
    }
    
    // Try to initialize libssh2
    if (libssh2_init(0) != 0) {
        NMSSHLogError(@"NMSSH: libssh2 initialization failed");
        return NO;
    }
    
    NMSSHLogVerbose(@"NMSSH: libssh2 initialized");
    
    // Try to establish a connection to the server
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        NMSSHLogError(@"NMSSH: Error creating the socket");
        return NO;
    }
    
    // Set NOSIGPIPE
    int set = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons([[self port] intValue]);
    sin.sin_addr.s_addr = inet_addr([[self hostIPAddress] UTF8String]);
    
    // Set non-blocking
    long arg;
    if((arg = fcntl(sock, F_GETFL, NULL)) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_GETFL)");
        return NO;
    }
    arg |= O_NONBLOCK;
    if(fcntl(sock, F_SETFL, arg) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_SETFL)");
        return NO;
    }
    
    // Trying to connect with timeout
    int res = connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in));
    if (res < 0) {
        if (errno == EINPROGRESS) {
            NMSSHLogVerbose(@"NMSSH: EINPROGRESS in connect() - selecting");
            struct timeval tv;
            fd_set myset;
            int valopt;
            socklen_t lon;
            do {
                tv.tv_sec = [timeout longValue];
                tv.tv_usec = 0;
                FD_ZERO(&myset);
                FD_SET(sock, &myset);
                res = select(sock+1, NULL, &myset, NULL, &tv);
                if (res < 0 && errno != EINTR) {
                    NMSSHLogError(@"NMSSH: Error connecting");
                    return NO;
                } else if (res > 0) {
                    // Socket selected for write
                    lon = sizeof(int);
                    if (getsockopt(sock, SOL_SOCKET, SO_ERROR, (void *)(&valopt), &lon) < 0) {
                        NMSSHLogError(@"NMSSH: Error in getsockopt()");
                        return NO;
                    }
                    // Check the value returned...
                    if (valopt) {
                        NMSSHLogError(@"NMSSH: Error in delayed connection() %d", valopt);
                        return NO;
                    }
                    NMSSHLogVerbose(@"NMSSH: libssh2 connected");
                    break;
                } else {
                    NMSSHLogError(@"NMSSH: Connection to socket timed out");
                    return NO;
                }
            } while (true);
        } else {
            NMSSHLogError(@"NMSSH: Failed connection to socket");
            return NO;
        }
    }
    
    // Set to blocking mode again...
    if((arg = fcntl(sock, F_GETFL, NULL)) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_GETFL)");
        return NO;
    }
    arg &= (~O_NONBLOCK);
    if(fcntl(sock, F_SETFL, arg) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_SETFL)");
        return NO;
    }
    
    // Create a session instance and start it up.
    _session = libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)(self));
    if (libssh2_session_handshake(_session, sock)) {
        NMSSHLogError(@"NMSSH: Failure establishing SSH session");
        return NO;
    }
    
    NMSSHLogVerbose(@"NMSSH: SSH session started");
    
    // Set a callback for disconnection
    libssh2_session_callback_set(_session, LIBSSH2_CALLBACK_DISCONNECT, &disconnect_callback);
    
    // We managed to successfully setup a connection
    _connected = YES;
    return [self isConnected];
}

- (void)disconnect {
    if (agent) {
        libssh2_agent_disconnect(agent);
        libssh2_agent_free(agent);
        agent = nil;
    }

    if (_session) {
        libssh2_session_disconnect(_session, "NMSSH: Disconnect");
        libssh2_session_free(_session);
        _session = nil;
    }

    if (sock) {
        close(sock);
    }

    libssh2_exit();
    NMSSHLogVerbose(@"NMSSH: Disconnected");
    _connected = NO;
}

// -----------------------------------------------------------------------------
// PUBLIC AUTHENTICATION API
// -----------------------------------------------------------------------------

- (BOOL)isAuthorized {
    if (_session) {
        return libssh2_userauth_authenticated(_session) == 1;
    }
    
    return NO;
}

- (BOOL)authenticateByPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"password"]) {
        return NO;
    }

    // Try to authenticate by password
    int error = libssh2_userauth_password(_session, [_username UTF8String],
                                           [password UTF8String]);
    if (error) {
        NMSSHLogError(@"NMSSH: Password authentication failed");
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
    int error = libssh2_userauth_publickey_fromfile(_session,
                                                    [_username UTF8String],
                                                    [publicKey UTF8String],
                                                    [privateKey UTF8String],
                                                    [password UTF8String]);

    if (error) {
        NMSSHLogError(@"NMSSH: Public key authentication failed");
        return NO;
    }

    return [self isAuthorized];
}

- (BOOL)connectToAgent {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    // Try to setup a connection to the SSH-agent
    agent = libssh2_agent_init(_session);
    if (!agent) {
        NMSSHLogError(@"NMSSH: Could not start a new agent");
        return NO;
    }

    // Try connecting to the agent
    if (libssh2_agent_connect(agent)) {
        NMSSHLogError(@"NMSSH: Failed connection to agent");
        return NO;
    }

    // Try to fetch available SSH identities
    if (libssh2_agent_list_identities(agent)) {
        NMSSHLogError(@"NMSSH: Failed to request agent identities");
        return NO;
    }

    // Search for the correct identity and try to authenticate
    struct libssh2_agent_publickey *identity, *prev_identity = NULL;
    while (1) {
        int error = libssh2_agent_get_identity(agent, &identity, prev_identity);
        if (error) {
            NMSSHLogError(@"NMSSH: Failed to find a valid identity for the agent");
            return NO;
        }

        error = libssh2_agent_userauth(agent, [_username UTF8String], identity);
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
    if (!_channel) {
        _channel = [[NMSSHChannel alloc] initWithSession:self];
    }

    return _channel;
}

// -----------------------------------------------------------------------------
// PRIVATE HOST NAME HELPERS
// -----------------------------------------------------------------------------

- (NSString *)hostIPAddress {
    NSString *addr = [[_host componentsSeparatedByString:@":"] objectAtIndex:0];

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
    NSArray *hostComponents = [_host componentsSeparatedByString:@":"];

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
    char *userauthlist = libssh2_userauth_list(_session, [_username UTF8String],
                                   (unsigned int)strlen([_username UTF8String]));

    if (userauthlist == NULL || strstr(userauthlist, [method UTF8String]) == NULL) {
        NMSSHLogInfo(@"NMSSH: Authentication by %@ not available for %@", method, _host);
        return NO;
    }
    NMSSHLogVerbose(@"NMSSH: User auth list: %@", [NSString stringWithCString:userauthlist encoding:NSUTF8StringEncoding]);
    
    return YES;
}

void disconnect_callback(LIBSSH2_SESSION *session, int reason, const char *message, int message_len, const char *language, int language_len, void **abstract) {
    NMSSHSession *self = (__bridge NMSSHSession *)*abstract;
    
    // Build a raw error to encapsulate the disconnect
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (message) {
        NSString *string = [[NSString alloc] initWithBytes:message length:message_len encoding:NSUTF8StringEncoding];
        [userInfo setObject:string forKey:NSLocalizedDescriptionKey];
    }
    if (language) {
        NSString *string = [[NSString alloc] initWithBytes:language length:language_len encoding:NSUTF8StringEncoding];
        [userInfo setObject:string forKey:@"language"];
    }
    
    NSError *error = [NSError errorWithDomain:@"NMSSH" code:reason userInfo:userInfo];
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:didDisconnectWithError:)]) {
        [self.delegate session:self didDisconnectWithError:error];
    }
    
    [self disconnect];
}

@end
