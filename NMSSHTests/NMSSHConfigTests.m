//
//  NMSSHConfigTests.m
//  NMSSH
//
//  Created by George Nachman on 5/8/14.
//
//

#import <XCTest/XCTest.h>
#import "NMSSHConfig.h"
#import "NMSSHHostConfig.h"

@interface NMSSHConfigTests : XCTestCase

@end

@implementation NMSSHConfigTests

/**
 Tests that an empty config file is ok
 */
- (void)testEmptyConfig {
    NSString *contents = @"";
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 0, @"Wrong number of configs read");
}

/**
 Tests that a config file with all supported keywords is properly read.
 */
- (void)testAllKeywords {
    NSString *contents =
        @"Host pattern\n"
        @"    Hostname hostname\n"
        @"    User user\n"
        @"    Port 1234\n"
        @"    IdentityFile id_file\n";
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.user, @"user", @"Users don't match");
    XCTAssertEqualObjects(hostConfig.port, @1234, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file" ], @"Identity files don't match");
}

/**
 Tests that comments are ignored.
 */
- (void)testCommentsIgnored {
    NSString *contents =
        @"# Comment\n"
        @"Host pattern\n"
        @"# Comment\n"
        @"    Hostname hostname\n"
        @"# Comment\n"
        @"    Port 1234\n"
        @"# Comment\n"
        @"    IdentityFile id_file\n"
        @"# Comment\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @1234, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file" ], @"Identity files don't match");
}

/**
 Tests that empty lines are ignored.
 */
- (void)testEmptyLinesIgnored {
    NSString *contents =
        @"\n"
        @"Host pattern\n"
        @"\n"
        @"    Hostname hostname\n"
        @"\n"
        @"    Port 1234\n"
        @"\n"
        @"    IdentityFile id_file\n"
        @"\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @1234, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file" ], @"Identity files don't match");
}

/**
 Tests that unknown keywords are ignored.
 */
- (void)testIgnoreUnknownKeywords {
    NSString *contents =
        @"Host pattern\n"
        @"    Hostname hostname\n"
        @"    Port 1234\n"
        @"    jfkldsajfdkl fjdkslafjdl fdjkla fjdslkf asdl\n"
        @"    IdentityFile id_file\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @1234, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file" ], @"Identity files don't match");
}

/**
 Tests that a malformed port line doesn't break parsing
 */
- (void)testMalformedPort {
    NSString *contents =
        @"Host pattern\n"
        @"    Hostname hostname\n"
        @"    Port\n"
        @"    IdentityFile id_file\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
    XCTAssertNil(hostConfig.port, @"Port should be nil");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file" ], @"Identity files don't match");
}

/**
 Tests that multiple patterns are parsed properly
 */
- (void)testMultiplePatterns {
    NSString *contents =
        @"Host pattern1 pattern2\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    NSArray *expected = @[ @"pattern1", @"pattern2" ];
    XCTAssertEqualObjects(hostConfig.hostPatterns, expected, @"Patterns don't match");
}

/**
 Tests that quoted patterns are parsed properly
 */
- (void)testQuotedPatterns {
    NSString *contents =
        @"Host pattern1 \"a quoted pattern\" pattern2 \"foo bar\" \"baz\"\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    NSArray *expected = @[ @"pattern1", @"a quoted pattern", @"pattern2", @"foo bar", @"baz" ];
    XCTAssertEqualObjects(hostConfig.hostPatterns, expected, @"Patterns don't match");
}

/**
 Tests that an unterminated quoted patterns are ignored.
 */
- (void)testUnterminatedQuotation {
    NSString *contents =
        @"Host pattern1 \"unterminated quotation\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    NSArray *expected = @[ @"pattern1" ];
    XCTAssertEqualObjects(hostConfig.hostPatterns, expected, @"Patterns don't match");
}

/**
 Tests that multiple identity file commands are respected.
 */
- (void)testMultipleIdentityFile {
    NSString *contents =
        @"Host pattern\n"
        @"    Hostname hostname\n"
        @"    Port 1234\n"
        @"    IdentityFile id_file1\n"
        @"    IdentityFile id_file2\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    NSArray *expected = @[ @"id_file1", @"id_file2" ];
    XCTAssertEqualObjects(hostConfig.identityFiles, expected, @"Identity files don't match");
}

/**
 Tests that trailing and midline spaces are ignored
 */
- (void)testExtraSpaces {
    NSString *contents =
        @"  Host         pattern    \"quoted pattern\"  \"   \"  \n"
        @"    Hostname    hostname      \n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 1, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    NSArray *expected = @[ @"pattern", @"quoted pattern", @"   " ];
    XCTAssertEqualObjects(hostConfig.hostPatterns, expected, @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname", @"Hostnames don't match");
}

/**
 Tests multiple hosts
 */
- (void)testMultipleHosts {
    NSString *contents =
        @"Host pattern1\n"
        @"    Hostname hostname1\n"
        @"    Port 1\n"
        @"    IdentityFile id_file1\n"
        @"Host pattern2\n"
        @"    Hostname hostname2\n"
        @"    Port 2\n"
        @"    IdentityFile id_file2\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NSArray *hostConfigs = config.hostConfigs;
    XCTAssertEqual([hostConfigs count], 2, @"Wrong number of configs read");

    NMSSHHostConfig *hostConfig = hostConfigs[0];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern1" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @1, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file1" ],
                          @"Identity files don't match");

    hostConfig = hostConfigs[1];
    XCTAssertEqualObjects(hostConfig.hostPatterns, @[ @"pattern2" ], @"Patterns don't match");
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname2", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @2, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.identityFiles, @[ @"id_file2" ],
                          @"Identity files don't match");
}

// -----------------------------------------------------------------------------
#pragma mark - TEST MATCHING
// -----------------------------------------------------------------------------

/**
 Test matching a simple pattern
 */
- (void)testSimplestPossiblePattern {
    NSString *contents =
        @"Host pattern1\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");
}

/**
 Test that a simple pattern fails when it ought to.
 */
- (void)testSimplestPossiblePatternNoMatch {
    NSString *contents =
        @"Host pattern1\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a pattern list of simple patterns works.
 */
- (void)testSimplePatternList {
    NSString *contents =
        @"Host pattern1,pattern2\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern3"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a question mark wildcard works
 */
- (void)testSingleCharWildcard {
    NSString *contents =
        @"Host pattern?\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"Xattern3"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a lone star matches everything
 */
- (void)testLoneStarMatchesAll {
    NSString *contents =
        @"Host *\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");
}

/**
 Test that a star suffix matches all suffixes
 */
- (void)testStarSuffix {
    NSString *contents =
        @"Host a*\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"abcdef"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"a"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a midline star works
 */
- (void)testMidlineStar {
    NSString *contents =
        @"Host abc*xyz\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"abcxyz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abc123xyz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abc"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"xyz"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"abxyz"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"abcyz"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"abcabc"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a star prefix works
 */
- (void)testLeadingStar {
    NSString *contents =
        @"Host *xyz\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"xyz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"123xyz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"xyz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abc"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that multiple disjoint stars work.
 */
- (void)testMultipleDisjointStars {
    NSString *contents =
        @"Host a*b*c\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"a12b34c"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abc"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abc1"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that two stars in a row work
 */
- (void)testConsecutiveStars {
    NSString *contents =
        @"Host a**z\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"abcz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"az"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"a"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test that a star followed by a question mark works
 */
- (void)testStarQuestionMark {
    NSString *contents =
        @"Host a*?z\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"abcz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"abz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"az"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"a"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@""];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test a host with multiple pattern lists
 */
- (void)testMultiplePatternLists {
    NSString *contents =
        @"Host pattern1,pattern2 pattern3,pattern4\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern3"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"pattern4"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");
}

/**
 Test negation alone
 */
- (void)testNegationAlone {
    NSString *contents =
        @"Host !pattern1\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"pattern1"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"pattern2"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test negation in combination with a matchable pattern
 */
- (void)testNegationPlusMatchablePattern {
    NSString *contents =
        @"Host !*x* a*\n"
        @"    Hostname hostname1\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"axy"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"abc"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"b"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test two rules where the first negates and the second matches.
 */
- (void)testTwoRulesWhereFirstNegatesAndSecondMatches {
    NSString *contents =
        @"Host !*x* a*\n"
        @"    Hostname hostname1\n"
        @"Host *z\n"
        @"    Hostname hostname2\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];
    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"axy"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");

    hostConfig = [config hostConfigForHost:@"abc"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Match failed");

    hostConfig = [config hostConfigForHost:@"axz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname2", @"Match failed");

    hostConfig = [config hostConfigForHost:@"xz"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname2", @"Match failed");

    hostConfig = [config hostConfigForHost:@"z"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname2", @"Match failed");

    hostConfig = [config hostConfigForHost:@"b"];
    XCTAssertNil(hostConfig, @"Match should have failed but didn't");
}

/**
 Test two rules that both match. They should be merged.
 */
- (void)testMergeTwoMatchingRules {
    NSString *contents =
        @"Host *\n"
        @"    Hostname hostname1\n"
        @"    Port 1\n"
        @"    IdentityFile id_file1\n"
        @"Host *\n"
        @"    Hostname hostname2\n"
        @"    Port 2\n"
        @"    User user\n"
        @"    IdentityFile id_file2\n";

    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:contents];

    NMSSHHostConfig *hostConfig = [config hostConfigForHost:@"hostname"];
    XCTAssertEqualObjects(hostConfig.hostname, @"hostname1", @"Hostnames don't match");
    XCTAssertEqualObjects(hostConfig.port, @1, @"Port doesn't match");
    XCTAssertEqualObjects(hostConfig.user, @"user", @"Users doesn't match");
    NSArray *expected = @[ @"id_file1", @"id_file2" ];
    XCTAssertEqualObjects(hostConfig.identityFiles, expected,
                          @"Identity files don't match");
}

@end
