#import <Foundation/Foundation.h>

@class NMSSHSession;

/**
 * NMSFTP provides functionality for working with SFTP servers.
 */
@interface NMSFTP : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** Property that keeps track of connection status to the server */
@property (readonly, getter=isConnected) BOOL connected;

// -----------------------------------------------------------------------------
// PUBLIC SETUP API
// -----------------------------------------------------------------------------

/**
 * Create a new NMSFTP instance and connect it.
 *
 * @returns Connected NMSFTP instance
 */
+ (id)connectWithSession:(NMSSHSession *)aSession;

/**
 * Create a new NMSFTP instance.
 *
 * aSession needs to be a valid, connected, NMSSHSession instance!
 *
 * @returns New NMSFTP instance
 */
- (id)initWithSession:(NMSSHSession *)aSession;

// -----------------------------------------------------------------------------
// HANDLE CONNECTIONS
// -----------------------------------------------------------------------------

/**
 * Create and connect to a SFTP session
 *
 * @returns Connection status
 */
- (BOOL)connect;

/**
 * Disconnect SFTP session
 */
- (void)disconnect;

// -----------------------------------------------------------------------------
// MANIPULATE FILE SYSTEM ENTRIES
// -----------------------------------------------------------------------------

/**
 * Move or rename an item
 *
 * @returns Move success
 */
- (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath;

// -----------------------------------------------------------------------------
// MANIPULATE DIRECTORIES
// -----------------------------------------------------------------------------

/**
 * Test if a directory exists at the specified path.
 *
 * Note: Will return NO if a file exists at the path, but not a directory.
 *
 * @returns YES if file exists
 */
- (BOOL)directoryExistsAtPath:(NSString *)path;

/**
 * Create a directory at path
 *
 * @returns Creation success
 */
- (BOOL)createDirectoryAtPath:(NSString *)path;

/**
 * Remove directory at path
 *
 * @returns Remove success
 */
- (BOOL)removeDirectoryAtPath:(NSString *)path;

/**
 * Get a list of file names for a directory path
 *
 * @returns List of relative paths
 */
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path;

// -----------------------------------------------------------------------------
// MANIPULATE SYMLINKS AND FILES
// -----------------------------------------------------------------------------

/**
 * Test if a file exists at the specified path.
 *
 * Note: Will return NO if a directory exists at the path, but not a file.
 *
 * @returns YES if file exists
 */
- (BOOL)fileExistsAtPath:(NSString *)path;

/**
 * Create a symbolic link
 *
 * @returns Creation success
 */
- (BOOL)createSymbolicLinkAtPath:(NSString *)linkPath
             withDestinationPath:(NSString *)destPath;

/**
 * Remove file at path
 *
 * @returns Remove success
 */
- (BOOL)removeFileAtPath:(NSString *)path;

/**
 * Read the contents of a file
 *
 * @returns File contents
 */
- (NSData *)contentsAtPath:(NSString *)path;

/**
 * Overwrite the contents of a file
 *
 * If no file exists, one is created.
 *
 * @returns Write success
 */
- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path;

/**
 * Append contents to the end of a file
 *
 * If no file exists, one is created.
 *
 * @returns Append success
 */
- (BOOL)appendContents:(NSData *)contents toFileAtPath:(NSString *)path;

@end
