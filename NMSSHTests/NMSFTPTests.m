#import "NMSFTPTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSFTPTests () {
    NSDictionary *settings;

    NMSSHSession *session;
    NMSFTP *sftp;
}
@end

@implementation NMSFTPTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    settings = [ConfigHelper valueForKey:@"valid_password_protected_server"];

    session = [NMSSHSession connectToHost:[settings objectForKey:@"host"]
                             withUsername:[settings objectForKey:@"user"]];
    [session authenticateByPassword:[settings objectForKey:@"password"]];
    assert([session isAuthorized]);

    sftp = [NMSFTP connectWithSession:session];
}

- (void)tearDown {
    if (sftp) {
        [sftp disconnect];
        sftp = nil;
    }

    if (session) {
        [session disconnect];
        session = nil;
    }
}

// -----------------------------------------------------------------------------
// CONNECTION TESTS
// -----------------------------------------------------------------------------

- (void)testConnectWithValidSession {
    STAssertTrue([sftp isConnected], @"Test that connection worked");
}

// -----------------------------------------------------------------------------
// TEST MANIPULATING DIRECTORIES
// -----------------------------------------------------------------------------

- (void)testCreateMoveAndDeleteDirectoryAtWritablePathWorks {
    NSString *path = [NSString stringWithFormat:@"%@mkdir_test",
                         [settings objectForKey:@"writable_dir"]];

    NSString *destPath = [NSString stringWithFormat:@"%@mvdir_test",
                             [settings objectForKey:@"writable_dir"]];

    STAssertTrue([sftp createDirectoryAtPath:path],
                 @"Try to create directory at valid path");

    STAssertTrue([sftp directoryExistsAtPath:path],
                  @"Directory exists at path");

    STAssertTrue([sftp moveItemAtPath:path toPath:destPath],
                 @"Try to move a directory");

    STAssertTrue([sftp removeDirectoryAtPath:destPath],
                 @"Try to remove directory");
}

- (void)testCreateDirectoryAtNonWritablePathFails {
    NSString *path = [NSString stringWithFormat:@"%@mkdir_test",
                      [settings objectForKey:@"non_writable_dir"]];

    STAssertFalse([sftp createDirectoryAtPath:path],
                  @"Try to create directory at invalid path");
}

- (void)testListingContentsOfDirectory {
    NSString *baseDir = [NSString stringWithFormat:@"%@listing/",
                         [settings objectForKey:@"writable_dir"]];
    NSArray *dirs = @[@"a", @"b", @"c"];
    NSArray *files = @[@"d.txt", @"e.txt", @"f.txt"];

    // Setup basedir
    [sftp createDirectoryAtPath:baseDir];

    // Setup subdirs
    for (NSString *dir in dirs) {
        [sftp createDirectoryAtPath:[baseDir stringByAppendingString:dir]];
    }

    // Setup files
    NSData *contents = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    for (NSString *file in files) {
        [sftp writeContents:contents
               toFileAtPath:[baseDir stringByAppendingString:file]];
    }

    // Test entry listing
    NSArray *entries = @[@"a/", @"b/", @"c/", @"d.txt", @"e.txt", @"f.txt"];
    STAssertEqualObjects([sftp contentsOfDirectoryAtPath:baseDir], entries,
                         @"Get a list of directory entries");

    // Cleanup subdirs
    for (NSString *dir in dirs) {
        [sftp removeDirectoryAtPath:[baseDir stringByAppendingString:dir]];
    }

    // Cleanup files
    for (NSString *file in files) {
        [sftp removeFileAtPath:[baseDir stringByAppendingString:file]];
    }

    // Cleanup basedir
    [sftp removeDirectoryAtPath:baseDir];
}

// -----------------------------------------------------------------------------
// TEST MANIPULATING FILES AND SYMLINKS
// -----------------------------------------------------------------------------

- (void)testCreateAndDeleteSymlinkAtWritablePath {
    // Set up a new directory to symlink to
    NSString *path = [NSString stringWithFormat:@"%@mkdir_test",
                         [settings objectForKey:@"writable_dir"]];
    [sftp createDirectoryAtPath:path];

    // Create symlink
    NSString *linkPath = [NSString stringWithFormat:@"%@symlink_test",
                             [settings objectForKey:@"writable_dir"]];
    STAssertTrue([sftp createSymbolicLinkAtPath:linkPath
                            withDestinationPath:path], @"Create symbolic link");

    // Remove symlink
    STAssertTrue([sftp removeFileAtPath:linkPath], @"Remove symlink");

    // Cleanup
    [sftp removeDirectoryAtPath:path];
}

- (void)testCreateMoveAndDeleteFileAtWriteablePath {
    NSString *path = [NSString stringWithFormat:@"%@file_test.txt",
                      [settings objectForKey:@"writable_dir"]];
    NSString *destPath = [NSString stringWithFormat:@"%@mvfile_test.txt",
                             [settings objectForKey:@"writable_dir"]];

    NSMutableData *contents = [[@"Hello World" dataUsingEncoding:NSUTF8StringEncoding]
                               mutableCopy];

    STAssertTrue([sftp writeContents:contents toFileAtPath:path],
                 @"Write contents to file");

    STAssertEqualObjects([sftp contentsAtPath:path], contents,
                         @"Read contents at path");

    NSData *moreContents = [@"\nBye!" dataUsingEncoding:NSUTF8StringEncoding];
    STAssertTrue([sftp appendContents:moreContents toFileAtPath:path],
                 @"Append contents to the end of a file");

    [contents appendData:moreContents];
    STAssertEqualObjects([sftp contentsAtPath:path], contents,
                         @"Read appended contents at path");

    STAssertTrue([sftp moveItemAtPath:path toPath:destPath], @"Move a file");

    STAssertTrue([sftp fileExistsAtPath:destPath], @"File exists at path");
    STAssertFalse([sftp fileExistsAtPath:[settings objectForKey:@"writable_dir"]],
                  @"Should return false if a directory is provided");

    STAssertTrue([sftp removeFileAtPath:destPath], @"Remove file");
}

@end