#import <Foundation/Foundation.h>
#import "libssh2.h"

@class NMSSHChannel;

@protocol NMSSHSessionDelegate;

/**
 * NMSSHSession provides functionality to setup a connection to a SSH server.
 */
@interface NMSSHSession : NSObject

/** Raw libssh2 session instance */
@property (nonatomic, readonly, getter=rawSession) LIBSSH2_SESSION *session;

/** Server hostname in the form "{hostname}:{port}" */
@property (nonatomic, readonly) NSString *host;

/** Server port **/
@property (nonatomic, readonly) NSNumber *port;

/** Server username */
@property (nonatomic, readonly) NSString *username;

/** Property that keeps track of connection status to the server */
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

/** Property that keeps track of authentication status */
@property (nonatomic, readonly, getter=isAuthorized) BOOL authorized;

/** Get a channel for this session */
@property (nonatomic, readonly) NMSSHChannel *channel;

/** Session delegate **/
@property (nonatomic, weak) id<NMSSHSessionDelegate> delegate;

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
 * Setup and connect to an SSH agent
 *
 * @returns Authentication success
 */
- (BOOL)connectToAgent;

@end

@protocol NMSSHSessionDelegate <NSObject>

@optional

- (void)session:(NMSSHSession *)session didDisconnectWithError:(NSError *)error;

@end
