#import "NMSSH.h"

/**
 Protocol for registering NMSFTP session callbacks.
 */
@protocol NMSFTPDelegate <NSObject>
@optional

- (void)sftp:(NMSFTP *)sftp didMoveItemAtPath:(NSString *)sourcePath
                                       toPath:(NSString *)destPath;

- (void)sftp:(NMSFTP *)sftp didFinishDirectoryExistsAtPath:(NSString *)path
                                                    exists:(BOOL)exists;

- (void)sftp:(NMSFTP *)sftp didCreateDirectoryAtPath:(NSString *)path;

- (void)sftp:(NMSFTP *)sftp didRemoveDirectoryAtPath:(NSString *)path;

- (void)sftp:(NMSFTP *)sftp didListContentsOfDirectoryAtPath:(NSString *)path
                                                    contents:(NSArray *)contents;

- (void)sftp:(NMSFTP *)sftp didGetInfoForFileAtPath:(NSString *)path
                                               file:(NMSFTPFile *)file;

- (void)sftp:(NMSFTP *)sftp didFinishFileExistsAtPath:(NSString *)path
                                               exists:(BOOL)exists;

- (void)sftp:(NMSFTP *)sftp didCreateSymbolicLinkAtPath:(NSString *)linkPath
                                    withDestinationPath:(NSString *)destPath;

- (void)sftp:(NMSFTP *)sftp didRemoveFileAtPath:(NSString *)path;

/**
 Responds after all contents of the remote path have been read.
 
 This method is called when the following methods have finished:
 - writeContents:toFileAtPath:progress:
 - contentsAtPath:
 
 @param path Remote path where contents were retrieved from.
 @param contents Contents of remote path
 */
- (void)sftp:(NMSFTP *)sftp didGetContentsAtPath:(NSString *)path
                                        contents:(NSData *)contents;

/**
 Responds after contents have been written to remote file.
 
 This method is called when the following methods have finished:
 - writeContents:toFileAtPath:
 - writeContents:toFileAtPath:progress:
 - writeFileAtPath:toFileAtPath:
 - writeFileAtPath:toFileAtPath:progress:
 - writeStream:toFileAtPath:
 - writeStream:toFileAtPath:progress:
 - appendContents:toFileAtPath:
 - appendStream:toFileAtPath:
 
 It is done this way because all of these methods eventually call
 writeStream:toFileAtPath:progress:.
 
 @param path Requested path to write contents to.
 */
- (void)sftp:(NMSFTP *)sftp didWriteContentsToFileAtPath:(NSString *)path;

@end
