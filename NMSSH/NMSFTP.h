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
+ (instancetype)connectWithSession:(NMSSHSession *)session complete:(void(^)(NSError *))complete;

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
- (void)connect:(void(^)(NSError *))complete;

/**
 Disconnect SFTP session
 */
- (void)disconnect:(void (^)())complete;

/// ----------------------------------------------------------------------------
/// @name Manipulate file system entries
/// ----------------------------------------------------------------------------

/**
 Refer to moveItemAtPath:toPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param sourcePath Item to move
 @param destPath Destination to move to
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)moveItemAtPath:(NSString *)sourcePath
                toPath:(NSString *)destPath
               success:(void (^)())success
               failure:(void (^)(NSError *error))failure;

/// ----------------------------------------------------------------------------
/// @name Manipulate directories
/// ----------------------------------------------------------------------------

/**
 Refer to directoryExistsAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to check
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)directoryExistsAtPath:(NSString *)path
                      success:(void (^)())success
                      failure:(void (^)(NSError *error))failure;

/**
 Refer to createDirectoryAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to directory
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)createDirectoryAtPath:(NSString *)path
                      success:(void (^)())success
                      failure:(void (^)(NSError *error))failure;

/**
 Refer to removeDirectoryAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Existing directory
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)removeDirectoryAtPath:(NSString *)path
                      success:(void (^)())success
                      failure:(void (^)(NSError *error))failure;

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
 Refer to fileExistsAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to check
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)fileExistsAtPath:(NSString *)path
                 success:(void (^)())success
                 failure:(void (^)(NSError *error))failure;

/**
 Refer to createSymbolicLinkAtPath:withDestinationPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param linkPath Path that will be linked to
 @param destPath Path the link will be created at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)createSymbolicLinkAtPath:(NSString *)linkPath
             withDestinationPath:(NSString *)destPath
                         success:(void (^)())success
                         failure:(void (^)(NSError *error))failure;

/**
 Refer to removeFileAtPath:
 
 This adds the ability to perform the operation asynchronously.
 
 @param path Path to existing file
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)removeFileAtPath:(NSString *)path
                 success:(void (^)())success
                 failure:(void (^)(NSError *error))failure;

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
 Refer to writeContents:toFileAtPath:progress:
 
 This adds the ability to perform the operation asynchronously.
 
 @param contents Bytes to write
 @param path File path to write bytes at
 @param progress Method called periodically with number of bytes sent.
        Returns NO to abort.
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)writeContents:(NSData *)contents
         toFileAtPath:(NSString *)path
             progress:(BOOL (^)(NSUInteger sent))progress
              success:(void (^)())success
              failure:(void (^)(NSError *error))failure;

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
- (void)writeFileAtPath:(NSString *)localPath
           toFileAtPath:(NSString *)path
               progress:(BOOL (^)(NSUInteger sent))progress
                success:(void (^)())success
                failure:(void (^)(NSError *error))failure;

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
- (void)writeStream:(NSInputStream *)inputStream
       toFileAtPath:(NSString *)path
           progress:(BOOL (^)(NSUInteger sent))progress
            success:(void (^)())success
            failure:(void (^)(NSError *error))failure;

/**
 Append contents to the end of a file

 If no file exists, one is created.

 @param contents Bytes to write
 @param path File path to write bytes at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)appendContents:(NSData *)contents
          toFileAtPath:(NSString *)path
               success:(void (^)())success
               failure:(void (^)(NSError *error))failure;

/**
 Append contents to the end of a file

 If no file exists, one is created.

 @param inputStream Stream to write bytes from
 @param path File path to write bytes at
 @param success Method called when the process succeeds
 @param failure Method called when the process fails
 */
- (void)appendStream:(NSInputStream *)inputStream
        toFileAtPath:(NSString *)path
             success:(void (^)())success
             failure:(void (^)(NSError *error))failure;

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
                   success:(void (^)())success
                   failure:(void (^)(NSError *error))failure;

@end
