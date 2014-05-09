#import "NMSSHChannelTests.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>

@interface NMSSHChannelTests () {
    NSDictionary *settings;
    NSString *localFilePath;

    NMSSHChannel *channel;
    NMSSHSession *session;
}
@end

@implementation NMSSHChannelTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    settings = [ConfigHelper valueForKey:@"valid_password_protected_server"];

    session = [NMSSHSession connectToHost:[settings objectForKey:@"host"]
                             withUsername:[settings objectForKey:@"user"]];
    [session authenticateByPassword:[settings objectForKey:@"password"]];
    assert([session isAuthorized]);

    // Setup test file for SCP
    localFilePath = [@"~/nmssh-test.txt" stringByExpandingTildeInPath];
    NSData *contents = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:localFilePath
                                            contents:contents
                                          attributes:nil];
}

- (void)tearDown {
    if (channel) {
        channel = nil;
    }

    if (session) {
        [session disconnect];
        session = nil;
    }

    // Cleanup SCP test files
    if ([[NSFileManager defaultManager] fileExistsAtPath:localFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:localFilePath
                                                   error:nil];
    }
}

// -----------------------------------------------------------------------------
// SHELL EXECUTION TESTS
// -----------------------------------------------------------------------------

- (void)testCreatingChannelWorks {
    XCTAssertNoThrow(channel = [[NMSSHChannel alloc] initWithSession:session],
                    @"Setting up channel does not throw exception");
}

- (void)testExecutingShellCommand {
    channel = [[NMSSHChannel alloc] initWithSession:session];

    NSError *error = nil;
    XCTAssertNoThrow([channel execute:[settings objectForKey:@"execute_command"]
                               error:&error],
                    @"Execution should not throw an exception");

    XCTAssertEqualObjects([channel lastResponse],
                         [settings objectForKey:@"execute_expected_response"],
                         @"Execution returns the expected response");
}

// -----------------------------------------------------------------------------
// SCP FILE TRANSFER TESTS
// -----------------------------------------------------------------------------

- (void)testUploadingFileToWritableDirWorks {
    channel = [[NMSSHChannel alloc] initWithSession:session];
    NSString *dir = [settings objectForKey:@"writable_dir"];
    XCTAssertTrue([dir hasSuffix:@"/"], @"Directory must end with a slash");

    BOOL result;
    XCTAssertNoThrow(result = [channel uploadFile:localFilePath to:dir],
                    @"Uploading file to writable dir doesn't throw exception");

    XCTAssertTrue(result, @"Uploading to writable dir should work.");
}

- (void)testUploadingFileToNonWritableDirFails {
    channel = [[NMSSHChannel alloc] initWithSession:session];
    NSString *dir = [settings objectForKey:@"non_writable_dir"];

    BOOL result;
    XCTAssertNoThrow(result = [channel uploadFile:localFilePath to:dir],
                    @"Uploading file to non-writable dir doesn't throw"
                    @"exception");

    XCTAssertFalse(result, @"Uploading to non-writable dir should not work.");
}

- (void)testDownloadingExistingFileWorks {
    channel = [[NMSSHChannel alloc] initWithSession:session];

    [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:nil];
    NSString *remoteFile = [[settings objectForKey:@"writable_dir"] stringByAppendingPathComponent:@"nmssh-test.txt"];

    BOOL result;
    XCTAssertNoThrow(result = [channel downloadFile:remoteFile to:localFilePath],
                    @"Downloading existing file doesn't throw exception");

    XCTAssertTrue(result, @"Downloading existing file should work.");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:localFilePath],
                 @"A file has been created");
}

- (void)testDownloadingNonExistingFileFails {
    channel = [[NMSSHChannel alloc] initWithSession:session];

    [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:nil];
    NSString *remoteFile = [NSString stringWithFormat:@"%@nmssh-test.txt",
                            [settings objectForKey:@"non_writable_dir"]];

    BOOL result;
    XCTAssertNoThrow(result = [channel downloadFile:remoteFile to:localFilePath],
                    @"Downloading non-existing file doesn't throw exception");

    XCTAssertFalse(result, @"Downloading non-existing file should not work.");
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:localFilePath],
                 @"A file has not been created");
}

@end
