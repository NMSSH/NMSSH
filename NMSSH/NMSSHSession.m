#import "NMSSHSession.h"

@interface NMSSHSession ()
@property (nonatomic, assign) LIBSSH2_AGENT *agent;

@property (nonatomic, assign, getter = rawSession) LIBSSH2_SESSION *session;
@property (nonatomic, readwrite) int sock;
@property (nonatomic, readwrite, getter = isConnected) BOOL connected;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *username;

@property (nonatomic, copy) NSString *(^kbAuthenticationBlock)(NSString *);

@property (nonatomic, strong) NMSSHChannel *channel;
@property (nonatomic, strong) NMSFTP *sftp;
@end

@implementation NMSSHSession

// -----------------------------------------------------------------------------
#pragma mark - INITIALIZE A NEW SSH SESSION
// -----------------------------------------------------------------------------

+ (id)connectToHost:(NSString *)host port:(NSInteger)port withUsername:(NSString *)username {
    return [self connectToHost:[NSString stringWithFormat:@"%@:%ld", host, (long)port]
                  withUsername:username];
}

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                   andUsername:username];
    [session connect];

    return session;
}

- (id)initWithHost:(NSString *)host port:(NSInteger)port andUsername:(NSString *)username {
    return [self initWithHost:[NSString stringWithFormat:@"%@:%ld", host, (long)port]
                  andUsername:username];
}

- (id)initWithHost:(NSString *)host andUsername:(NSString *)username {
    if ((self = [super init])) {
        [self setHost:host];
        [self setUsername:username];
        [self setConnected:NO];
    }

    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - CONNECTION SETTINGS
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

- (NSNumber *)timeout {
    if (self.session) {
        return @(libssh2_session_get_timeout(self.session) / 1000);
    }

    return @0;
}

- (void)setTimeout:(NSNumber *)timeout {
    if (self.session) {
        libssh2_session_set_timeout(self.session, [timeout longValue] * 1000);
    }
}

// -----------------------------------------------------------------------------
#pragma mark - OPEN/CLOSE A CONNECTION TO THE SERVER
// -----------------------------------------------------------------------------

- (BOOL)connect {
    return [self connectWithTimeout:[NSNumber numberWithLong:10]];
}

- (BOOL)connectWithTimeout:(NSNumber *)timeout {
    if (self.isConnected) {
        [self disconnect];
    }

    // Try to initialize libssh2
    if (libssh2_init(0) != 0) {
        NMSSHLogError(@"NMSSH: libssh2 initialization failed");
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: libssh2 (v%s) initialized", libssh2_version(0));

    // Try to establish a connection to the server
    [self setSock:socket(AF_INET, SOCK_STREAM, 0)];
    if (self.sock < 0) {
        NMSSHLogError(@"NMSSH: Error creating the socket");
        return NO;
    }

    // Set NOSIGPIPE
    int set = 1;
    setsockopt(_sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));

    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons([self.port intValue]);
    sin.sin_addr.s_addr = inet_addr([self.hostIPAddress UTF8String]);

    // Set non-blocking
    long arg;
    if ((arg = fcntl(self.sock, F_GETFL, NULL)) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_GETFL)");
        return NO;
    }

    arg |= O_NONBLOCK;
    if (fcntl(self.sock, F_SETFL, arg) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_SETFL)");
        return NO;
    }

    // Trying to connect with timeout
    int res = connect(self.sock, (struct sockaddr *)(&sin), sizeof(struct sockaddr_in));
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
                FD_SET(self.sock, &myset);
                res = select(self.sock+1, NULL, &myset, NULL, &tv);

                if (res < 0 && errno != EINTR) {
                    NMSSHLogError(@"NMSSH: Error connecting");
                    return NO;
                }
                else if (res > 0) {
                    // Socket selected for write
                    lon = sizeof(int);
                    if (getsockopt(self.sock, SOL_SOCKET, SO_ERROR, (void *)(&valopt), &lon) < 0) {
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
                }
                else {
                    NMSSHLogError(@"NMSSH: Connection to socket timed out");
                    return NO;
                }
            } while (true);
        }
        else {
            NMSSHLogError(@"NMSSH: Failed connection to socket");
            return NO;
        }
    }

    // Set to blocking mode again...
    if ((arg = fcntl(self.sock, F_GETFL, NULL)) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_GETFL)");
        return NO;
    }

    arg &= (~O_NONBLOCK);
    if (fcntl(self.sock, F_SETFL, arg) < 0) {
        NMSSHLogError(@"NMSSH: Error fcntl(..., F_SETFL)");
        return NO;
    }

    // Create a session instance and start it up.
    [self setSession:libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)(self))];
    if (libssh2_session_handshake(self.session, self.sock)) {
        NMSSHLogError(@"NMSSH: Failure establishing SSH session");
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: SSH session started");

    // Set a callback for disconnection
    libssh2_session_callback_set(self.session, LIBSSH2_CALLBACK_DISCONNECT, &disconnect_callback);

    // We managed to successfully setup a connection
    [self setConnected:YES];

    return self.isConnected;
}

- (void)disconnect {
    if (self.channel) {
        if ([self.channel type] == NMSSHChannelTypeShell) {
            [self.channel closeShell];
        }
        [self setChannel:nil];
    }

    if (self.sftp) {
        if ([self.sftp isConnected]) {
            [self.sftp disconnect];
        }
        [self setSftp:nil];
    }

    if (self.agent) {
        libssh2_agent_disconnect(self.agent);
        libssh2_agent_free(self.agent);
        [self setAgent:NULL];
    }

    if (self.session) {
        libssh2_session_disconnect(self.session, "NMSSH: Disconnect");
        libssh2_session_free(self.session);
        [self setSession:NULL];
    }

    if (self.sock) {
        close(self.sock);
        [self setSock:0];
    }

    libssh2_exit();
    NMSSHLogVerbose(@"NMSSH: Disconnected");
    [self setConnected:NO];
}

// -----------------------------------------------------------------------------
#pragma mark - AUTHENTICATION
// -----------------------------------------------------------------------------

- (BOOL)isAuthorized {
    if (self.session) {
        return libssh2_userauth_authenticated(self.session) == 1;
    }

    return NO;
}

- (BOOL)authenticateByPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"password"]) {
        return NO;
    }

    // Try to authenticate by password
    int error = libssh2_userauth_password(self.session, [self.username UTF8String], [password UTF8String]);
    if (error) {
        NMSSHLogError(@"NMSSH: Password authentication failed");
        return NO;
    }

    return self.isAuthorized;
}

- (BOOL)authenticateByPublicKey:(NSString *)publicKey
                     privateKey:(NSString *)privateKey
                    andPassword:(NSString *)password {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    if (password == nil) {
        password = @"";
    }

    // Get absolute paths for private/public key pair
    const char *pubKey = [[publicKey stringByExpandingTildeInPath] UTF8String] ?: NULL;
    const char *privKey = [[privateKey stringByExpandingTildeInPath] UTF8String] ?: NULL;

    // Try to authenticate with key pair and password
    int error = libssh2_userauth_publickey_fromfile(self.session,
                                                    [self.username UTF8String],
                                                    pubKey,
                                                    privKey,
                                                    [password UTF8String]);

    if (error) {
        NMSSHLogError(@"NMSSH: Public key authentication failed");
        return NO;
    }

    return self.isAuthorized;
}

- (BOOL)authenticateByKeyboardInteractive {
    return [self authenticateByKeyboardInteractiveUsingBlock:nil];
}

- (BOOL)authenticateByKeyboardInteractiveUsingBlock:(NSString *(^)(NSString *request))authenticationBlock {
    if (![self supportsAuthenticationMethod:@"keyboard-interactive"]) {
        return NO;
    }

    libssh2_session_set_blocking(self.session, 1);
    self.kbAuthenticationBlock = authenticationBlock;
    int rc = libssh2_userauth_keyboard_interactive(self.session, [self.username UTF8String], &kb_callback);
    self.kbAuthenticationBlock = nil;

    if (rc != 0) {
        NMSSHLogError(@"NMSSH: Authentication by keyboard-interactive failed!");
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Authentication by keyboard-interactive succeeded.");

    return self.isAuthorized;
}

- (BOOL)connectToAgent {
    if (![self supportsAuthenticationMethod:@"publickey"]) {
        return NO;
    }

    // Try to setup a connection to the SSH-agent
    [self setAgent:libssh2_agent_init(self.session)];
    if (!self.agent) {
        NMSSHLogError(@"NMSSH: Could not start a new agent");
        return NO;
    }

    // Try connecting to the agent
    if (libssh2_agent_connect(self.agent)) {
        NMSSHLogError(@"NMSSH: Failed connection to agent");
        return NO;
    }

    // Try to fetch available SSH identities
    if (libssh2_agent_list_identities(self.agent)) {
        NMSSHLogError(@"NMSSH: Failed to request agent identities");
        return NO;
    }

    // Search for the correct identity and try to authenticate
    struct libssh2_agent_publickey *identity, *prev_identity = NULL;
    while (1) {
        int error = libssh2_agent_get_identity(self.agent, &identity, prev_identity);
        if (error) {
            NMSSHLogError(@"NMSSH: Failed to find a valid identity for the agent");
            return NO;
        }

        error = libssh2_agent_userauth(self.agent, [self.username UTF8String], identity);
        if (!error) {
            return self.isAuthorized;
        }

        prev_identity = identity;
    }

    return NO;
}

- (BOOL)supportsAuthenticationMethod:(NSString *)method {
    char *userauthlist = libssh2_userauth_list(self.session, [self.username UTF8String],
                                               (unsigned int)strlen([self.username UTF8String]));

    if (userauthlist == NULL || strstr(userauthlist, [method UTF8String]) == NULL) {
        NMSSHLogInfo(@"NMSSH: Authentication by %@ not available for %@", method, _host);
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: User auth list: %@", [NSString stringWithCString:userauthlist encoding:NSUTF8StringEncoding]);

    return YES;
}

- (NSString *)keyboardInteractiveRequest:(NSString *)request {
    NMSSHLogVerbose(@"NMSSH: Server request '%@'", request);

    if (self.kbAuthenticationBlock) {
        return self.kbAuthenticationBlock(request);
    }
    else if (self.delegate && [self.delegate respondsToSelector:@selector(session:keyboardInteractiveRequest:)]) {
        return [self.delegate session:self keyboardInteractiveRequest:request];
    }

    NMSSHLogWarn(@"NMSSH: Keyboard interactive requires a delegate that responds to session:keyboardInteractiveRequest: or a block!");

    return @"";
}

void kb_callback(const char *name, int name_len, const char *instr, int instr_len,
                 int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts, LIBSSH2_USERAUTH_KBDINT_RESPONSE *res, void **abstract) {
    int i;

    NMSSHSession *self = (__bridge NMSSHSession *)*abstract;

    for (i = 0; i < num_prompts; i++) {
        NSString *request = [[NSString alloc] initWithBytes:prompts[i].text length:prompts[i].length encoding:NSUTF8StringEncoding];
        NSString *response = [self keyboardInteractiveRequest:request];

        if (!response) {
            response = @"";
        }

        res[i].text = strdup([response UTF8String]);
        res[i].length = (unsigned int)strlen([response UTF8String]);
    }
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

// -----------------------------------------------------------------------------
#pragma mark - QUICK CHANNEL/SFTP ACCESS
// -----------------------------------------------------------------------------

- (NMSSHChannel *)channel {
    if (!_channel) {
        _channel = [[NMSSHChannel alloc] initWithSession:self];
    }

    return _channel;
}

- (NMSFTP *)sftp {
    if (!_sftp) {
        _sftp = [[NMSFTP alloc] initWithSession:self];
    }

    return _sftp;
}

@end
