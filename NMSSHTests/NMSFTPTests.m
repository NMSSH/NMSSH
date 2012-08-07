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
// TEST CREATE AND DELETE DIRECTORIES
// -----------------------------------------------------------------------------

- (void)testCreateAndDeleteDirectoryAtWritablePathWorks {
    NSString *path = [NSString stringWithFormat:@"%@mkdir_test",
                         [settings objectForKey:@"writable_dir"]];

    STAssertTrue([sftp createDirectoryAtPath:path],
                 @"Try to create directory at valid path");

    STAssertTrue([sftp removeDirectoryAtPath:path], @"Try to remove directory");
}

- (void)testCreateDirectoryAtNonWritablePathFails {
    NSString *path = [NSString stringWithFormat:@"%@mkdir_test",
                      [settings objectForKey:@"non_writable_dir"]];

    STAssertFalse([sftp createDirectoryAtPath:path],
                  @"Try to create directory at invalid path");
}

// -----------------------------------------------------------------------------
// TEST CREATE, SYMLINK AND DELETE FILES
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

@end
