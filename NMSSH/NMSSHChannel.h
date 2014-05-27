#import "NMSSH.h"

FOUNDATION_EXPORT NSString *const NMSSHChannelErrorDomain;

typedef NS_ENUM(NSInteger, NMSSHChannelError) {
    NMSSHChannelExecutionError,
    NMSSHChannelExecutionResponseError,
    NMSSHChannelPtyError,
    NMSSHChannelSCPError,
    NMSSHChannelExecutionTimeout,
    NMSSHChannelAllocationError,
    NMSSHChannelShellError,
    NMSSHChannelWriteError,
    NMSSHChannelReadError
};

typedef NS_ENUM(NSInteger, NMSSHChannelPtyTerminal) {
    NMSSHChannelPtyTerminalVanilla,
    NMSSHChannelPtyTerminalVT100,
    NMSSHChannelPtyTerminalVT102,
    NMSSHChannelPtyTerminalVT220,
    NMSSHChannelPtyTerminalAnsi,
    NMSSHChannelPtyTerminalXterm
};

typedef NS_ENUM(NSInteger, NMSSHChannelType)  {
    NMSSHChannelTypeClosed, // Channel = NULL
    NMSSHChannelTypeExec,
    NMSSHChannelTypeShell,
    NMSSHChannelTypeSCP,
    NMSSHChannelTypeSubsystem // Not supported by NMSSH framework
};

/**
 NMSSHChannel provides functionality to work with SSH shells and SCP.
 */
@interface NMSSHChannel : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** Size of the buffers used by the channel, defaults to 0x4000 */
@property (nonatomic, assign) NSUInteger bufferSize;

/// ----------------------------------------------------------------------------
/// @name Setting the Delegate
/// ----------------------------------------------------------------------------

/**
 The receiver’s `delegate`.

 You can use the `delegate` to receive asynchronous read from a shell.
 */
@property (nonatomic, weak) id<NMSSHChannelDelegate> delegate;

/// ----------------------------------------------------------------------------
/// @name Initializer
/// ----------------------------------------------------------------------------

/** Current channel type or `NMSSHChannelTypeClosed` if the channel is closed */
@property (nonatomic, readonly) NMSSHChannelType type;

/**
 Create a new NMSSHChannel instance.

 @param session A valid, connected, NMSSHSession instance
 @returns New NMSSHChannel instance
 */
- (instancetype)initWithSession:(NMSSHSession *)session;

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
 Execute a shell command on the server.

 If an error occurs, it will return `nil` and populate the error object.
 If requestPty is enabled request a pseudo terminal before running the
 command.

 @param command Any shell script that is available on the server
 @param success A block to be executed when the command is executed successfully. This block has no return value and takes a single argument: the response from the server.
 @param failure A block to be executed when the command is executed unsuccessfully. This block has no return value and takes two arguments: the response from the server, if any, and the error that occurred.
 @returns Shell command response
 */
- (void)execute:(NSString *)command
        success:(void (^)(NSString *response))success
        failure:(void (^)(NSString *response, NSError *error))failure;

/**
 Execute a shell command on the server with a given timeout.

 If an error occurs or the connection timed out, it will return `nil` and populate the error object.
 If requestPty is enabled request a pseudo terminal before running the
 command.

 @param command Any shell script that is available on the server
 @param timeout The time to wait (in seconds) before giving up on the request
 @param success A block to be executed when the command is executed successfully. This block has no return value and takes a single argument: the response from the server.
 @param failure A block to be executed when the command is executed unsuccessfully. This block has no return value and takes two arguments: the response from the server, if any, and the error that occurred.
 @returns Shell command response
 */
- (void)execute:(NSString *)command
        timeout:(NSNumber *)timeout
        success:(void (^)(NSString *response))success
        failure:(void (^)(NSString *response, NSError *error))failure;

/// ----------------------------------------------------------------------------
/// @name Remote shell session
/// ----------------------------------------------------------------------------

/** User-defined environment variables for the session, defaults to `nil` */
@property (nonatomic, strong) NSDictionary *environmentVariables;

/**
 Request a remote shell on the channel.

 If an error occurs, it will return NO and populate the error object.
 If requestPty is enabled request a pseudo terminal before running the
 command.

 @param success A block to be executed when the shell is started successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the shell is started unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns Shell initialization success
 */
- (void)startShell:(void (^)())success
           failure:(void (^)(NSError *error))failure;

/**
 Close a remote shell on an active channel.
 
 @param complete A block to be executed when shell is closed. This block has no return value and takes no arguments.
 */
- (void)closeShell:(void (^)())complete;

/**
 Write a command on the remote shell.

 If an error occurs or the connection timed out, it will return NO and populate the error object.

 @param command Any command that is available on the server
 @param success A block to be executed when the command is writed on the shell successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the command is writed on the shell unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns Shell write success
 */
- (void)writeCommand:(NSString *)command
             success:(void (^)())success
             failure:(void (^)(NSError *error))failure;

/**
 Write a command on the remote shell with a given timeout.

 If an error occurs or the connection timed out, it will return NO and populate the error object.

 @param command Any command that is available on the server
 @param timeout The time to wait (in seconds) before giving up on the request
 @param success A block to be executed when the command is writed on the shell successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the command is writed on the shell unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns Shell write success
 */
- (void)writeCommand:(NSString *)command
             timeout:(NSNumber *)timeout
             success:(void (^)())success
             failure:(void (^)(NSError *error))failure;

/**
 Write data on the remote shell.

 If an error occurs or the connection timed out, it will return NO and populate the error object.

 @param data Any data
 @param success A block to be executed when the data is writed on the shell successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the data is writed on the shell unsuccessfully. This block has no return value and takes one argument: the error that occurred. @returns Shell write success
 */
- (void)writeData:(NSData *)data
          success:(void (^)())success
          failure:(void (^)(NSError *error))failure;

/**
 Write data on the remote shell with a given timeout.

 If an error occurs or the connection timed out, it will return NO and populate the error object.

 @param data Any data
 @param timeout The time to wait (in seconds) before giving up on the request
 @param success A block to be executed when the data is writed on the shell successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the data is writed on the shell unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns Shell write success
 */
- (void)writeData:(NSData *)data
          timeout:(NSNumber *)timeout
          success:(void (^)())success
          failure:(void (^)(NSError *error))failure;

/**
 Request size for the remote pseudo terminal.

 This method should be called only after startShell:

 @param width Width in characters for terminal
 @param height Height in characters for terminal
 @param success A block to be executed when the shell size is requested successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the shell size is requested unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns Size change success
 */
- (void)requestSizeWidth:(NSUInteger)width
                  height:(NSUInteger)height
                 success:(void (^)())success
                 failure:(void (^)(NSError *error))failure;

/// ----------------------------------------------------------------------------
/// @name SCP file transfer
/// ----------------------------------------------------------------------------

/**
 Download a remote file to local the filesystem.

 If to: specifies a directory, the file name from the original file will be
 used.

 @param remotePath Path to a file on the remote server
 @param localPath Path to save the file to
 @param progress A block called periodically with number of bytes downloaded and total file size.
        Returns NO to abort.
 @param success A block to be executed when the file is downloaded successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the file is downloaded unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns SCP download success
 */
- (void)downloadFile:(NSString *)remotePath
                  to:(NSString *)localPath
            progress:(BOOL (^)(NSUInteger, NSUInteger))progress
             success:(void (^)())success
             failure:(void (^)(NSError *error))failure;

/**
 Upload a local file to a remote server.

 If to: specifies a directory, the file name from the original file will be
 used.

 @param localPath Path to a file on the local computer
 @param remotePath Path to save the file to
 @param progress Method called periodically with number of bytes uploaded. Returns NO to abort.
 @param success A block to be executed when the file is uploaded successfully. This block has no return value and takes no arguments.
 @param failure A block to be executed when the file is uploaded unsuccessfully. This block has no return value and takes one argument: the error that occurred.
 @returns SCP upload success
 */
- (void)uploadFile:(NSString *)localPath
                to:(NSString *)remotePath
          progress:(BOOL (^)(NSUInteger))progress
           success:(void (^)())success
           failure:(void (^)(NSError *error))failure;


@end
