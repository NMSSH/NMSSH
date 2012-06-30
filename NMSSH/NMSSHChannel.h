#import <Foundation/Foundation.h>

@class NMSSHSession;

enum {
    NMSSHChannelExecutionError,
    NMSSHChannelExecutionResponseError
};

/**
 * NMSSHChannel provides functionality to work with SSH shells and SCP.
 */
@interface NMSSHChannel : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** The last response from a shell command execution */
@property (nonatomic, readonly) NSString *lastResponse;

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
 *
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error;

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
