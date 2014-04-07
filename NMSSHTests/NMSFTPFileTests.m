#import <XCTest/XCTest.h>
#import "NMSFTPFile.h"

@interface NMSFTPFileTests : XCTestCase

@end

@implementation NMSFTPFileTests {
    NMSFTPFile *_file;
}

- (void)setUp {
    [super setUp];
    _file = [[NMSFTPFile alloc] initWithFilename:@"test.txt"];
}

/**
 Tests whether the filename attribute is correct after initialization.
 */
- (void)testInitialization {
    XCTAssertEqualObjects(_file.filename, @"test.txt", @"Filename attribut has not been set");
    NMSFTPFile *anotherFile = [NMSFTPFile fileWithName:@"test.txt"];
    XCTAssertEqualObjects(anotherFile.filename, @"test.txt", @"Filename attribut has not been set");
}

/**
 Tests whether the permissions conversion from numeric to symbolic notation is correct
 */
-(void)testPermissionsConversion {
    LIBSSH2_SFTP_ATTRIBUTES attributes;
    attributes.permissions = 33188;
    [_file populateValuesFromSFTPAttributes:attributes];
    XCTAssertEqualObjects(_file.permissions, @"-rw-r--r--", @"The symbolic permissions notation is not correct.");
}

@end
