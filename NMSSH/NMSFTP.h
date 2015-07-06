#import "NMSSH.h"

/**
 NMSFTP provides functionality for working with SFTP servers.
 */
@interface NMSFTP : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** Property that keeps track of connection status to the server */
@property (nonatomic, readonly, getter = isConnected) BOOL connected;

///-----------------------------------------------------------------------------
/// @name Initializer
/// ----------------------------------------------------------------------------

/**
 Create a new NMSFTP instance and connect it.

 @param session A valid, connected, NMSSHSession instance
 @returns Connected NMSFTP instance
 */
+ (instancetype)connectWithSession:(NMSSHSession *)session;

/**
 Create a new NMSFTP instance.

 @param session A valid, connected, NMSSHSession instance
 @returns New NMSFTP instance
 */
- (instancetype)initWithSession:(NMSSHSession *)session;

/// ----------------------------------------------------------------------------
/// @name Connection
/// ----------------------------------------------------------------------------

/**
 Create and connect to a SFTP session

 @returns Connection status
 */
- (BOOL)connect;

/**
 Disconnect SFTP session
 */
- (void)disconnect;

/// ----------------------------------------------------------------------------
/// @name Manipulate file system entries
/// ----------------------------------------------------------------------------

/**
 Move or rename an item.

 @param sourcePath Item to move
 @param destPath Destination to move to
 @returns Move success
 */
- (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath;

/**
 Refer to moveItemAtPath:toPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param sourcePath Item to move
 @param destPath Destination to move to
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath
               success:(void (^)(BOOL success))success
               failure:(void (^)(NSError *error))failure;

/// ----------------------------------------------------------------------------
/// @name Manipulate directories
/// ----------------------------------------------------------------------------

/**
 Test if a directory exists at the specified path.

 Note: Will return NO if a file exists at the path, but not a directory.

 @param path Path to check
 @returns YES if file exists
 */
- (BOOL)directoryExistsAtPath:(NSString *)path;

/**
 Refer to directoryExistsAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to check
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)directoryExistsAtPath:(NSString *)path
                      success:(void (^)(BOOL success))success
                      failure:(void (^)(NSError *error))failure;

/**
 Create a directory at path.

 @param path Path to directory
 @returns Creation success
 */
- (BOOL)createDirectoryAtPath:(NSString *)path;

/**
 Refer to createDirectoryAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to directory
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)createDirectoryAtPath:(NSString *)path
                      success:(void (^)(BOOL success))success
                      failure:(void (^)(NSError *error))failure;

/**
 Remove directory at path.

 @param path Existing directory
 @returns Remove success
 */
- (BOOL)removeDirectoryAtPath:(NSString *)path;

/**
 Refer to removeDirectoryAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Existing directory
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)removeDirectoryAtPath:(NSString *)path
                      success:(void (^)(BOOL success))success
                      failure:(void (^)(NSError *error))failure;

/**
 Get a list of files for a directory path.

 @param path Existing directory to list items from
 @returns List of relative paths
 */
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path;

/**
 Refer to contentsOfDirectoryAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Existing directory
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)contentsOfDirectoryAtPath:(NSString *)path
                          success:(void (^)(NSArray *contents))success
                          failure:(void (^)(NSError *error))failure;

/// ----------------------------------------------------------------------------
/// @name Manipulate symlinks and files
/// ----------------------------------------------------------------------------

/**
 Reads the attributes from a file.

 @param path An existing file path
 @return A NMSFTPFile that contains the fetched file attributes.
 */
- (NMSFTPFile *)infoForFileAtPath:(NSString *)path;

/**
 Refer to infoForFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path An existing file path
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)infoForFileAtPath:(NSString *)path
                  success:(void (^)(NMSFTPFile *file))success
                  failure:(void (^)(NSError *error))failure;

/**
 Test if a file exists at the specified path.

 Note: Will return NO if a directory exists at the path, but not a file.

 @param path Path to check
 @returns YES if file exists
 */
- (BOOL)fileExistsAtPath:(NSString *)path;

/**
 Refer to fileExistsAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to check
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)fileExistsAtPath:(NSString *)path
                 success:(void (^)(BOOL exists))success
                 failure:(void (^)(NSError *error))failure;

/**
 Create a symbolic link.

 @param linkPath Path that will be linked to
 @param destPath Path the link will be created at
 @returns Creation success
 */
- (BOOL)createSymbolicLinkAtPath:(NSString *)linkPath withDestinationPath:(NSString *)destPath;

/**
 Refer to createSymbolicLinkAtPath:withDestinationPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param linkPath Path that will be linked to
 @param destPath Path the link will be created at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)createSymbolicLinkAtPath:(NSString *)linkPath withDestinationPath:(NSString *)destPath
                         success:(void (^)(BOOL success))success
                         failure:(void (^)(NSError *error))failure;

/**
 Remove file at path.

 @param path Path to existing file
 @returns Remove success
 */
- (BOOL)removeFileAtPath:(NSString *)path;

/**
 Refer to removeFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to existing file
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)removeFileAtPath:(NSString *)path
                 success:(void (^)(BOOL success))success
                 failure:(void (^)(NSError *error))failure;

/**
 Read the contents of a file.

 @param path An existing file path
 @returns File contents
 */
- (NSData *)contentsAtPath:(NSString *)path;

/**
 Refer to contentsAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path An existing file path
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)contentsAtPath:(NSString *)path
               success:(void (^)(NSData *contents))success
               failure:(void (^)(NSError *error))failure;

/**
 Refer to contentsAtPath:

 This adds the ability to get periodic updates to bytes received.
 
 @param path An existing file path
 @param progress Method called periodically with number of bytes downloaded and total file size.
        Returns NO to abort.
 @returns File contents
 */
- (NSData *)contentsAtPath:(NSString *)path
                  progress:(BOOL (^)(NSUInteger got, NSUInteger totalBytes))progress;

/**
 Refer to contentsAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path An existing file path
 @param progress Method called periodically with number of bytes downloaded and total file size.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)contentsAtPath:(NSString *)path
              progress:(BOOL (^)(NSUInteger got, NSUInteger totalBytes))progress
               success:(void (^)(NSData *contents))success
               failure:(void (^)(NSError *error))failure;

/**
 Overwrite the contents of a file

 If no file exists, one is created.

 @param contents Bytes to write
 @param path File path to write bytes at
 @returns Write success
 */
- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path;

/**
 Refer to writeContents:toFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param contents Bytes to write
 @param path File path to write bytes at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeContents:(NSString *)contents toFileAtPath:(NSString *)path
              success:(void (^)(BOOL success))success
              failure:(void (^)(NSError *error))failure;

/**
 Refer to writeContents:toFileAtPath:
 
 This adds the ability to get periodic updates to bytes sent.
 
 @param contents Bytes to write
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @returns Write success
 */
- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger sent))progress;

/**
 Refer to writeContents:toFileAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param contents Bytes to write
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeContents:(NSString *)contents toFileAtPath:(NSString *)path
             progress:(BOOL (^)(NSUInteger sent))progress
              success:(void (^)(BOOL success))success
              failure:(void (^)(NSError *error))failure;

/**
 Overwrite the contents of a file

 If no file exists, one is created.

 @param localPath File path to read bytes at
 @param path File path to write bytes at
 @returns Write success
 */
- (BOOL)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path;

/**
 Refer to writeFileAtPath:toFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param localPath File path to read bytes at
 @param path File path to write bytes at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path
                success:(void (^)(BOOL success))success
                failure:(void (^)(NSError *error))failure;

/**
 Refer to writeFileAtPath:toFileAtPath:
 
 This adds the ability to get periodic updates to bytes sent.
 
 @param localPath File path to read bytes at
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @returns Write success
 */
- (BOOL)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path
               progress:(BOOL (^)(NSUInteger sent))progress;

/**
 Refer to writeFileAtPath:toFileAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param localPath File path to read bytes at
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeFileAtPath:(NSString *)localPath toFileAtPath:(NSString *)path
               progress:(BOOL (^)(NSUInteger sent))progress
                success:(void (^)(BOOL success))success
                failure:(void (^)(NSError *error))failure;

/**
 Overwrite the contents of a file

 If no file exists, one is created.

 @param inputStream Stream to read bytes from
 @param path File path to write bytes at
 @returns Write success
 */
- (BOOL)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path;

/**
 Refer to writeStream:toFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param inputStream Stream to read bytes from
 @param path File path to write bytes at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path
                success:(void (^)(BOOL success))success
                failure:(void (^)(NSError *error))failure;

/**
 Refer to writeStream:toFileAtPath:
 
 This adds the ability to get periodic updates to bytes sent.
 
 @param inputStream Stream to read bytes from
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @returns Write success
 */
- (BOOL)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path progress:(BOOL (^)(NSUInteger sent))progress;

/**
 Refer to writeStream:toFileAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param inputStream Stream to read bytes from
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path
           progress:(BOOL (^)(NSUInteger sent))progress
            success:(void (^)(BOOL success))success
            failure:(void (^)(NSError *error))failure;

/**
 Append contents to the end of a file

 If no file exists, one is created.

 @param contents Bytes to write
 @param path File path to write bytes at
 @returns Append success
 */
- (BOOL)appendContents:(NSData *)contents toFileAtPath:(NSString *)path;

/**
 Append contents to the end of a file

 If no file exists, one is created.

 @param inputStream Stream to write bytes from
 @param path File path to write bytes at
 @returns Append success
 */
- (BOOL)appendStream:(NSInputStream *)inputStream toFileAtPath:(NSString *)path;

/**
 Copy a file remotely.
 
 @param fromPath Path to copy from
 @param toPath Path to copy to
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @returns Write success
 */
- (BOOL)copyContentsOfPath:(NSString *)fromPath toFileAtPath:(NSString *)toPath
                  progress:(BOOL (^)(NSUInteger copied, NSUInteger totalBytes))progress;

/**
 Refer to writeStream:toFileAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param fromPath Path to copy from
 @param toPath Path to copy to
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)copyContentsOfPath:(NSString *)fromPath toFileAtPath:(NSString *)toPath
                  progress:(BOOL (^)(NSUInteger copied, NSUInteger totalBytes))progress
                   success:(void (^)(BOOL success))success
                   failure:(void (^)(NSError *error))failure;

@end
