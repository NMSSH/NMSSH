@protocol NMSSHSessionDelegate <NSObject>
@optional
- (NSString *)session:(NMSSHSession *)session keyboardInteractiveRequest:(NSString *)request;
- (void)session:(NMSSHSession *)session didDisconnectWithError:(NSError *)error;
@end

/**
 * NMSSHSession provides functionality to setup a connection to a SSH server.
 */
@interface NMSSHSession : NSObject

/** Session delegate */
@property (nonatomic, weak) id<NMSSHSessionDelegate> delegate;

/// ----------------------------------------------------------------------------
/// @name Initialize a session
/// ----------------------------------------------------------------------------

/**
 * Shorthand method for initializing a NMSSHSession object and calling connect.
 *
 * @returns NMSSHSession instance
 */
+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username;

/**
 * Shorthand method for initializing a NMSSHSession object and calling connect.
 *
 * @returns NMSSHSession instance
 */
+ (id)connectToHost:(NSString *)host port:(NSInteger)port withUsername:(NSString *)username;

/**
 * Create and setup a new NMSSH instance.
 *
 * @returns NMSSHSession instance
 */
- (id)initWithHost:(NSString *)host andUsername:(NSString *)username;

/**
 * Create and setup a new NMSSH instance.
 *
 * @returns NMSSHSession instance
 */
- (id)initWithHost:(NSString *)host port:(NSInteger)port andUsername:(NSString *)username;

/// ----------------------------------------------------------------------------
/// @name Connection
/// ----------------------------------------------------------------------------

/** Raw libssh2 session instance */
@property (nonatomic, readonly, getter = rawSession) LIBSSH2_SESSION *session;

/** Get session socket */
@property (nonatomic, readonly) int sock;

/** Property that keeps track of connection status to the server */
@property (nonatomic, readonly, getter = isConnected) BOOL connected;

/** Server hostname in the form "{hostname}:{port}" */
@property (nonatomic, readonly) NSString *host;

/** Server port */
@property (nonatomic, readonly) NSNumber *port;

/** Server username */
@property (nonatomic, readonly) NSString *username;

/**
 * Connect to the server using the default timeout (10 seconds)
 *
 * @returns Connection status
 */
- (BOOL)connect;

/**
 * Connect to the server.
 *
 * @returns Connection status
 */
- (BOOL)connectWithTimeout:(NSNumber *)timeout;

/**
 * Close the session
 */
- (void)disconnect;

/// ----------------------------------------------------------------------------
/// @name Authentication
/// ----------------------------------------------------------------------------

/** Property that keeps track of authentication status */
@property (nonatomic, readonly, getter = isAuthorized) BOOL authorized;

/**
 * Authenticate by password
 *
 * @returns Authentication success
 */
- (BOOL)authenticateByPassword:(NSString *)password;

/**
 * Authenticate by public key
 *
 * Use password:nil when the key is unencrypted
 *
 * @returns Authentication success
 */
- (BOOL)authenticateByPublicKey:(NSString *)publicKey
                    andPassword:(NSString *)password;

/**
 * Authenticate by keyboard-interactive
 *
 * @returns Authentication success
 */
- (BOOL)authenticateByKeyboardInteractive;

/**
 * Setup and connect to an SSH agent
 *
 * @returns Authentication success
 */
- (BOOL)connectToAgent;

/// ----------------------------------------------------------------------------
/// @name Send and receive data
/// ----------------------------------------------------------------------------

/** Get a channel for this session */
@property (nonatomic, readonly) NMSSHChannel *channel;

/** Get a SFTP instance for this session */
@property (nonatomic, readonly) NMSFTP *sftp;

@end