#import "NMSSHSession.h"

@interface NMSSHSession ()
@property (nonatomic, assign) LIBSSH2_AGENT *agent;

@property (nonatomic, assign, getter = rawSession) LIBSSH2_SESSION *session;
@property (nonatomic, readwrite) CFSocketRef socket;
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
    NSString *hostname = [NSString stringWithFormat:@"%@:%ld", host, (long)port];

    // Check if host is IPv6
    if ([[host componentsSeparatedByString:@":"] count] >= 3) {
        hostname = [NSString stringWithFormat:@"[%@]:%ld", host, (long)port];
    }

    return [self connectToHost:hostname withUsername:username];
}

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username {
    NMSSHSession *session = [[NMSSHSession alloc] initWithHost:host
                                                   andUsername:username];
    [session connect];

    return session;
}

- (id)initWithHost:(NSString *)host port:(NSInteger)port andUsername:(NSString *)username {
    NSString *hostname = [NSString stringWithFormat:@"%@:%ld", host, (long)port];

    // Check if host is IPv6
    if ([[host componentsSeparatedByString:@":"] count] >= 3) {
        hostname = [NSString stringWithFormat:@"[%@]:%ld", host, (long)port];
    }

    return [self initWithHost:hostname andUsername:username];
}

- (id)initWithHost:(NSString *)host andUsername:(NSString *)username {
    if ((self = [super init])) {
        [self setHost:host];
        [self setUsername:username];
        [self setConnected:NO];
        [self setFingerprintHash:NMSSHSessionHashMD5];
    }

    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - CONNECTION SETTINGS
// -----------------------------------------------------------------------------

- (NSArray *)hostIPAddresses {
    NSArray *hostComponents = [_host componentsSeparatedByString:@":"];
    NSInteger components = [hostComponents count];
    NSString *address = hostComponents[0];

    // Check if the host is [{IPv6}]:{port}
    if (components >= 4 && [hostComponents[0] hasPrefix:@"["] && [hostComponents[components-2] hasSuffix:@"]"]) {
        address = [_host substringWithRange:NSMakeRange(1, [_host rangeOfString:@"]" options:NSBackwardsSearch].location-1)];
    } // Check if the host is {IPv6}
    else if (components >= 3) {
        address = _host;
    }

    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)address);
    CFStreamError error;
    NSArray *addresses = nil;
    
    if (host) {
        NMSSHLogVerbose(@"NMSSH: Start %@ resolution", address);
        if (CFHostStartInfoResolution(host, kCFHostAddresses, &error)) {
            addresses = (__bridge NSArray *)(CFHostGetAddressing(host, NULL));
        } else {
            NMSSHLogError(@"NMSSH: Unable to resolve host %@", address);
        }
        
        CFRelease(host);
    } else {
        NMSSHLogError(@"NMSSH: Error allocating CFHost for %@", address);
    }
    
    return addresses;
}

- (NSNumber *)port {
    NSArray *hostComponents = [_host componentsSeparatedByString:@":"];
    NSInteger components = [hostComponents count];

    // Check if the host is {hostname}:{port} or {IPv4}:{port}
    if (components == 2) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];

        return [formatter numberFromString:[hostComponents lastObject]];
    } // Check if the host is [{IPv6}]:{port}
    else if (components >= 4 && [hostComponents[0] hasPrefix:@"["] && [hostComponents[components-2] hasSuffix:@"]"]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];

        return [formatter numberFromString:[hostComponents lastObject]];
    }

    // If no port was defined, use 22 by default
    return @22;
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

- (NSError *)lastError {
    char *message;
    int error = libssh2_session_last_error(self.rawSession, &message, NULL, 0);

    return [NSError errorWithDomain:@"libssh2"
                               code:error
                           userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithUTF8String:message] }];
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

    // Try to create the socket
    [self setSocket:CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_IP, kCFSocketNoCallBack, NULL, NULL)];
    if (!self.socket) {
        NMSSHLogError(@"NMSSH: Error creating the socket");
        return NO;
    }

    // Set NOSIGPIPE
    int set = 1;
    if (setsockopt(CFSocketGetNative(self.socket), SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(set)) != 0) {
        NMSSHLogError(@"NMSSH: Error setting socket option");
        [self disconnect];
        return NO;
    }

    // Try to establish a connection to the server
    NSUInteger index = -1;
    NSInteger port = [self.port integerValue];
    NSArray *addresses = [self hostIPAddresses];
    CFSocketError error = 1;
    struct sockaddr_storage *address = NULL;
    
    while (addresses && ++index < [addresses count] && error) {
        NSData *addressData = addresses[index];
        NSString *ipAddress;
        
        // IPv4
        if ([addressData length] == sizeof(struct sockaddr_in)) {
            struct sockaddr_in address4;
            [addressData getBytes:&address4 length:sizeof(address4)];
            address4.sin_port = htons(port);
            
            address = (struct sockaddr_storage *)(&address4);
            address->ss_len = sizeof(address4);
            
            char str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(address4.sin_addr), str, INET_ADDRSTRLEN);
            ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        } // IPv6
        else if([addressData length] == sizeof(struct sockaddr_in6)) {
            struct sockaddr_in6 address6;
            [addressData getBytes:&address6 length:sizeof(address6)];
            address6.sin6_port = htons(port);
            
            address = (struct sockaddr_storage *)(&address6);
            address->ss_len = sizeof(address6);
            
            char str[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &(address6.sin6_addr), str, INET6_ADDRSTRLEN);
            ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        }
        else {
            NMSSHLogVerbose(@"NMSSH: Unknown address, it's not IPv4 or IPv6!");
            continue;
        }
        
        error = CFSocketConnectToAddress(self.socket, (__bridge CFDataRef)[NSData dataWithBytes:address length:address->ss_len], [timeout doubleValue]);
        
        if (error) {
            NMSSHLogVerbose(@"NMSSH: Socket connection to %@ on port %ld failed with reason %li, trying next address...", ipAddress, (long)port, error);
        } else {
            NMSSHLogInfo(@"NMSSH: Socket connection to %@ on port %ld succesful", ipAddress, (long)port);
        }
    }
    
    if (error) {
        NMSSHLogError(@"NMSSH: Failure establishing socket connection");
        [self disconnect];
        return NO;
    }

    // Create a session instance
    [self setSession:libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)(self))];

    // Set a callback for disconnection
    libssh2_session_callback_set(self.session, LIBSSH2_CALLBACK_DISCONNECT, &disconnect_callback);

    // Set blocking mode
    libssh2_session_set_blocking(self.session, 1);

    // Start the session
    if (libssh2_session_handshake(self.session, CFSocketGetNative(self.socket))) {
        NMSSHLogError(@"NMSSH: Failure establishing SSH session");
        [self disconnect];
        return NO;
    }

    // Get the fingerprint of the host
    NSString *fingerprint = [self fingerprint:self.fingerprintHash];
    NMSSHLogInfo(@"NMSSH: The host's fingerprint is %@", fingerprint);

    if (self.delegate && [self.delegate respondsToSelector:@selector(session:shouldConnectToHostWithFingerprint:)] &&
        ![self.delegate session:self shouldConnectToHostWithFingerprint:fingerprint]) {
        NMSSHLogWarn(@"NMSSH: Fingerprint refused, aborting connection...");
        [self disconnect];

        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: SSH session started");

    // We managed to successfully setup a connection
    [self setConnected:YES];

    return self.isConnected;
}

- (void)disconnect {
    if (_channel) {
        [_channel closeShell];
        [self setChannel:nil];
    }

    if (_sftp) {
        if ([_sftp isConnected]) {
            [_sftp disconnect];
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

    if (self.socket) {
        CFSocketInvalidate(self.socket);
        CFRelease(self.socket);
        [self setSocket:NULL];
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
        NMSSHLogError(@"NMSSH: Password authentication failed with reason %i", error);
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Password authentication succeeded.");

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
        NMSSHLogError(@"NMSSH: Public key authentication failed with reason %i", error);
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Public key authentication succeeded.");

    return self.isAuthorized;
}

- (BOOL)authenticateByKeyboardInteractive {
    return [self authenticateByKeyboardInteractiveUsingBlock:nil];
}

- (BOOL)authenticateByKeyboardInteractiveUsingBlock:(NSString *(^)(NSString *request))authenticationBlock {
    if (![self supportsAuthenticationMethod:@"keyboard-interactive"]) {
        return NO;
    }

    self.kbAuthenticationBlock = authenticationBlock;
    int rc = libssh2_userauth_keyboard_interactive(self.session, [self.username UTF8String], &kb_callback);
    self.kbAuthenticationBlock = nil;

    if (rc != 0) {
        NMSSHLogError(@"NMSSH: Keyboard-interactive authentication failed with reason %i", rc);
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Keyboard-interactive authentication succeeded.");

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

- (NSArray *)supportedAuthenticationMethods {
    char *userauthlist = libssh2_userauth_list(self.session, [self.username UTF8String],
                                               (unsigned int)strlen([self.username UTF8String]));
    if (userauthlist == NULL){
        NMSSHLogInfo(@"NMSSH: Failed to get authentication method for host %@", self.host);
        return nil;
    }
    
    NSString *authList = [NSString stringWithCString:userauthlist encoding:NSUTF8StringEncoding];
    NMSSHLogVerbose(@"NMSSH: User auth list: %@", authList);
    
    return [authList componentsSeparatedByString:@","];
}

- (BOOL)supportsAuthenticationMethod:(NSString *)method {
    return [[self supportedAuthenticationMethods] containsObject:method];
}

- (NSString *)fingerprint:(NMSSHSessionHash)hashType {
    if (!self.session) {
        return nil;
    }

    int libssh2_hash, hashLength;
    switch (hashType) {
        case NMSSHSessionHashMD5:  libssh2_hash = LIBSSH2_HOSTKEY_HASH_MD5;  hashLength = 16; break;
        case NMSSHSessionHashSHA1: libssh2_hash = LIBSSH2_HOSTKEY_HASH_SHA1; hashLength = 20; break;
    }

    const char *hash = libssh2_hostkey_hash(self.session, libssh2_hash);
    if (!hash) {
        NMSSHLogWarn(@"NMSSH: Unable to retrive host's fingerprint");
        return nil;
    }

    NSMutableString *fingerprint = [[NSMutableString alloc] initWithFormat:@"%02X", (unsigned char)hash[0]];

    for (int i = 1; i < hashLength; i++) {
        [fingerprint appendFormat:@":%02X", (unsigned char)hash[i]];
    }

    return [fingerprint copy];
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
