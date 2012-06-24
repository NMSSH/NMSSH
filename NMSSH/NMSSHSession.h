#import <Foundation/Foundation.h>

/**
 * NMSSH aims to be a full Objective-C wrapper for libssh2, with an API
 * that is easy to understand and fun to work with.
 *
 * To achieve that goal, the library will assume conventions but still
 * make it easy to override them without writing ugly code.
 */
@interface NMSSHSession : NSObject

/** Server hostname in the form "{hostname}:{port}" */
@property (readonly) NSString *host;

/** Server username */
@property (readonly) NSString *username;

/** Property that keeps track of connection status to the server */
@property (readonly, getter=isConnected) BOOL connected;

/** Property that keeps track of authentication status */
@property (readonly, getter=isAuthorized) BOOL authorized;

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

@end
