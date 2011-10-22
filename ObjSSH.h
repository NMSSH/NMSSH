#import <Foundation/Foundation.h>

/**
 * ObjSSH aims to be a full Objective-C wrapper for libssh2, with an API
 * that is easy to understand and fun to work with.
 *
 * To achieve that goal, the library will assume conventions but still
 * make it easy to override them without writing ugly code.
 */
@interface ObjSSH : NSObject {
    NSString *_host;
    NSNumber *_port;
    NSString *_username;
    NSString *_password;
    NSString *_privateKey;
    NSString *_publicKey;
}

/**
 * Connect to a remote host with username and password
 *
 * Unless otherwise specified in the host parameter, the port is assumed to be
 * 22. To change port, append ":{portnr}" to the hostname.
 *
 * Examples:
 *
 *     ObjSSH *ssh = [ObjSSH connectToHost:@"127.0.0.1" withUsername:@"user" password:@"pass" error:&error];
 *     ObjSSH *ssh2 = [ObjSSH connectToHost:@"127.0.0.1:4567" withUsername:@"user" password:@"pass" error:&error];
 */
+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username password:(NSString *)password error:(NSError **)error;

/**
 * Connect to a remote host with username and public/private key pair
 *
 * Unless otherwise specified in the host parameter, the port is assumed to be
 * 22. To change port, append ":{portnr}" to the hostname.
 *
 * Examples:
 *
 *     ObjSSH *ssh = [ObjSSH connectToHost:@"127.0.0.1" withUsername:@"user" publicKey:@"/home/user/.ssh/id_rsa.pub" privateKey:@"/home/user/.ssh/id_rsa" error:&error];
 */
+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey error:(NSError **)error;

/**
 * Initialize ObjSSH and set its instance variables.
 *
 * Examples:
 *
 *     ObjSSH *ssh = [[ObjSSH alloc] initWithHost:@"127.0.0.1" username:@"user" password:@"pass" publicKey:nil privateKey:nil];
 */
- (id)initWithHost:(NSString *)host username:(NSString *)username password:(NSString *)password publicKey:(NSString *)publicKey privateKey:(NSString *)priateKey;

/**
 * Connect to a remote host. The return value is a boolean indicating whether or
 * not the connection succeded.
 *
 * Examples:
 *
 *     NSError *error;
 *     [ssh connect:&error];
 */
- (BOOL)connect:(NSError **)error;

/**
 * Disconnect from a remote host
 *
 * Examples:
 *
 *     [ssh disconnect];
 *     [ssh release];
 */
- (void)disconnect;

/**
 * Execute command in remote shell
 *
 * Examples:
 *
 *     NSString *response = [ssh execute:@"ls -la" error:&error];
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error;

/**
 * Upload a file to the remote server via SCP.
 *
 * Examples:
 *
 *     NSError *error;
 *     BOOL success = [ssh uploadFile:@"/path/to/local.txt" to:@"/path/to/remote.txt" error:&error];
 */
- (BOOL)uploadFile:(NSString *)localPath to:(NSString *)remotePath error:(NSError **)error;

/**
 * Request a file from the remote server via SCP.
 *
 * Examples:
 *
 *     NSError *error;
 *     BOOL success = [ssh downloadFile:@"/path/to/remote.txt" to:@"/path/to/local.txt" error:&error];
 */
- (BOOL)downloadFile:(NSString *)remotePath to:(NSString *)localPath error:(NSError **)error;

@end
