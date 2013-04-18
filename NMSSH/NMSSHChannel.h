#import <Foundation/Foundation.h>

@class NMSSHSession;

enum {
    NMSSHChannelExecutionError,
    NMSSHChannelExecutionResponseError,
    NMSSHChannelRequestPtyError,
    NMSSHChannelExecutionTimeout
};

enum {
    NMSSHChannelPtyTerminalVanilla,
    NMSSHChannelPtyTerminalVT102,
    NMSSHChannelPtyTerminalAnsi
};

/**
 * NMSSHChannel provides functionality to work with SSH shells and SCP.
 */
@interface NMSSHChannel : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** The last response from a shell command execution */
@property (nonatomic, readonly) NSString *lastResponse;

/** Request a pseudo terminal before executing a command */
@property (nonatomic, assign) BOOL requestPty;

/** Terminal emulation mode if a PTY is requested, defaults to vanilla */
@property (nonatomic, assign) unsigned int ptyTerminalType;

/**
 * Create a new NMSSHChannel instance.
 *
 * aSession needs to be a valid, connected, NMSSHSession instance!
 *
 * @returns New NMSSHChannel instance
 */
- (id)initWithSession:(NMSSHSession *)aSession;

/**
 * Execute a shell command on the server.
 *
 * If an error occurs, it will return nil and populate the error object.
 * If requestPty is enabled request a pseude terminal before running the
 * command.
 *
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error;

/**
 * Execute a shell command on the server with a given timeout.
 *
 * If an error occurs or the connection timed out, it will return nil and populate the error object.
 *
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error timeout:(NSNumber *)timeout;

/**
 * Upload a local file to a remote server.
 *
 * If to: specifies a directory, the file name from the original file will be
 * used.
 *
 * @returns SCP upload success
 */
- (BOOL)uploadFile:(NSString *)localPath to:(NSString *)remotePath;

/**
 * Download a remote file to local the filesystem.
 *
 * If to: specifies a directory, the file name from the original file will be
 * used.
 *
 * @returns SCP download success
 */
- (BOOL)downloadFile:(NSString *)remotePath to:(NSString *)localPath;

@end
