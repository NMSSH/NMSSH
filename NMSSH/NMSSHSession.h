#import <Foundation/Foundation.h>
#import "libssh2.h"

@class NMSSHChannel, NMSFTP;

/**
 * NMSSHSession provides functionality to setup a connection to a SSH server.
 */
@interface NMSSHSession : NSObject

/** Raw libssh2 session instance */
@property (readonly, getter=rawSession) LIBSSH2_SESSION *session;

/** Server hostname in the form "{hostname}:{port}" */
@property (readonly) NSString *host;

/** Server username */
@property (readonly) NSString *username;

/** Property that keeps track of connection status to the server */
@property (readonly, getter=isConnected) BOOL connected;

/** Property that keeps track of authentication status */
@property (readonly, getter=isAuthorized) BOOL authorized;

/** Get a channel for this session */
@property (readonly) NMSSHChannel *channel;

/** Get a SFTP instance for this session */
@property (readonly) NMSFTP *sftp;

/**
 * Shorthand method for initializing a NMSSHSession object and calling connect.
 *
 * @returns NMSSHSession instance
 */
+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username;

/**
 * Create and setup a new NMSSH instance.
 *
 * @returns NMSSHSession instance
 */
- (id)initWithHost:(NSString *)aHost andUsername:(NSString *)aUsername;

/**
 * Connect to the server.
 *
 * @returns Connection status
 */
- (BOOL)connect;

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
