enum {
    NMSSHChannelExecutionError,
    NMSSHChannelExecutionResponseError,
    NMSSHChannelRequestPtyError,
    NMSSHChannelExecutionTimeout,
    NMSSHChannelAllocationError
};

typedef enum {
    NMSSHChannelPtyTerminalVanilla,
    NMSSHChannelPtyTerminalVT100,
    NMSSHChannelPtyTerminalVT102,
    NMSSHChannelPtyTerminalVT220,
    NMSSHChannelPtyTerminalAnsi
} NMSSHChannelPtyTerminal;

/**
 * NMSSHChannel provides functionality to work with SSH shells and SCP.
 */
@interface NMSSHChannel : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/// ----------------------------------------------------------------------------
/// @name Initializer
/// ----------------------------------------------------------------------------

/**
 * Create a new NMSSHChannel instance.
 *
 * @param session A valid, connected, NMSSHSession instance
 * @returns New NMSSHChannel instance
 */
- (id)initWithSession:(NMSSHSession *)session;

/// ----------------------------------------------------------------------------
/// @name Shell command execution
/// ----------------------------------------------------------------------------

/** The last response from a shell command execution */
@property (nonatomic, readonly) NSString *lastResponse;

/** Request a pseudo terminal before executing a command */
@property (nonatomic, assign) BOOL requestPty;

/** Terminal emulation mode if a PTY is requested, defaults to vanilla */
@property (nonatomic, assign) NMSSHChannelPtyTerminal ptyTerminalType;

/**
 * Execute a shell command on the server.
 *
 * If an error occurs, it will return nil and populate the error object.
 * If requestPty is enabled request a pseude terminal before running the
 * command.
 *
 * @param command Any shell script that is available on the server
 * @param error Error handler
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error;

/**
 * Execute a shell command on the server with a given timeout.
 *
 * If an error occurs or the connection timed out, it will return nil and populate the error object.
 *
 * @param command Any shell script that is available on the server
 * @param error Error handler
 * @param timeout The time to wait (in seconds) before giving up on the request
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error timeout:(NSNumber *)timeout;

/// ----------------------------------------------------------------------------
/// @name SCP file transfer
/// ----------------------------------------------------------------------------

/**
 * Upload a local file to a remote server.
 *
 * If to: specifies a directory, the file name from the original file will be
 * used.
 *
 * @param localPath Path to a file on the local computer
 * @param remotePath Path to save the file to
 * @returns SCP upload success
 */
- (BOOL)uploadFile:(NSString *)localPath to:(NSString *)remotePath;

/**
 * Download a remote file to local the filesystem.
 *
 * If to: specifies a directory, the file name from the original file will be
 * used.
 *
 * @param remotePath Path to a file on the remote server
 * @param localPath Path to save the file to
 * @returns SCP download success
 */
- (BOOL)downloadFile:(NSString *)remotePath to:(NSString *)localPath;

@end
