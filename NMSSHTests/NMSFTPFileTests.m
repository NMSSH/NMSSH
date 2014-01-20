//
//  NMSFTPFileTests.m
//  NMSSH
//
//  Created by Sebastian Hunkeler on 20/01/14.
//
//

#import <SenTestingKit/SenTestingKit.h>

@interface NMSFTPFileTests : SenTestCase

@end

@implementation NMSFTPFileTests
{
    NMSFTPFile* _file;
}

- (void)setUp
{
    [super setUp];
    _file = [[NMSFTPFile alloc] initWithFilename:@"test.txt"];
}

/**
 Tests whether the filename attribute is correct after initialization.
 */
- (void)testInitialization
{
    STAssertEqualObjects(_file.filename, @"test.txt", @"Filename attribut has not been set");
    NMSFTPFile* anotherFile = [NMSFTPFile fileWithName:@"test.txt"];
    STAssertEqualObjects(anotherFile.filename, @"test.txt", @"Filename attribut has not been set");
}

/**
 Tests whether the permissions conversion from numeric to symbolic notation is correct
 */
-(void)testPermissionsConversion
{
    LIBSSH2_SFTP_ATTRIBUTES attributes;
    attributes.permissions = 33188;
    [_file populateValuesFromSFTPAttributes:attributes];
    STAssertEqualObjects(_file.permissions, @"-rw-r--r--", @"The symbolic permissions notation is not correct.");
}

@end
