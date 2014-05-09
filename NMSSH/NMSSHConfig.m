#import "NMSSHConfig.h"

typedef enum {
    NMSSHConfigMatchPositive,
    NMSSHConfigMatchNegative,
    NMSSHConfigMatchNone
} NMSSHConfigMatch;

// -----------------------------------------------------------------------------
#pragma mark - NMSSHHostConfig
// -----------------------------------------------------------------------------

@interface NMSSHHostConfig ()
@property(nonatomic, strong) NSArray *hostPatterns;
@property(nonatomic, strong) NSString *hostname;
@property(nonatomic, readwrite) NSInteger port;
@property(nonatomic, strong) NSArray *identityFiles;
@end

@implementation NMSSHHostConfig

- (id)init {
    self = [super init];
    if (self != nil) {
        [self setPort:22];
        [self setHostPatterns:@[ ]];
        [self setIdentityFiles:@[ ]];
    }
    return self;
}

@end

// -----------------------------------------------------------------------------
#pragma mark NMSSHConfig
// -----------------------------------------------------------------------------

@interface NMSSHConfig ()
@property(nonatomic, strong) NSArray *hostConfigs;
@end

@implementation NMSSHConfig

+ (instancetype)configFromFile:(NSString *)filename {
  return [[self alloc] initWithFile:filename];
}

- (instancetype)initWithFile:(NSString *)filename {
    NSString *contents = [NSString stringWithContentsOfFile:filename
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL];
    return [self initWithString:contents];
}

- (instancetype)initWithString:(NSString *)contents {
    if (contents == nil) {
        return nil;
    }
    self = [super init];
    if (self != nil) {
        [self setHostConfigs:[self arrayFromString:contents]];
        if (_hostConfigs == nil) {
            return nil;
        }
    }
    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - PARSING
// -----------------------------------------------------------------------------

- (NSArray *)arrayFromString:(NSString *)contents {
    if (contents == nil) {
        return nil;
    }
    contents = [contents stringByReplacingOccurrencesOfString:@"\r\n"
                                                   withString:@"\n"];
    NSArray *lines = [contents componentsSeparatedByString:@"\n"];
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *line in lines) {
        [self parseLine:line intoArray:array];
    }
    return array;
}

- (void)parseLine:(NSString *)line intoArray:(NSMutableArray *)array {
    // Trim spaces
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    NSString *arguments;
    NSRange range = [self rangeOfFirstTokenInString:line suffix:&arguments];
    if (range.location == NSNotFound) {
        return;
    }
    NSString *keyword = [line substringWithRange:range];
    if ([keyword hasPrefix:@"#"] ||
        [keyword length] == 0) {
        return;
    }

    if ([keyword localizedCaseInsensitiveCompare:@"host"] == NSOrderedSame) {
        NMSSHHostConfig *config = [[NMSSHHostConfig alloc] init];
        NSString *next;
        NSRange hostRange = [self rangeOfFirstTokenInString:arguments suffix:&next];
        while (hostRange.location != NSNotFound) {
            if (hostRange.length > 0) {
                NSString *hostPattern = [arguments substringWithRange:hostRange];
                [config setHostPatterns:[config.hostPatterns arrayByAddingObject:hostPattern]];
            }

            arguments = next;
            hostRange = [self rangeOfFirstTokenInString:arguments suffix:&next];
        }
        if ([config.hostPatterns count] > 0) {
            [array addObject:config];
        }
    }
    else if ([keyword localizedCaseInsensitiveCompare:@"hostname"] == NSOrderedSame &&
             [array count]) {
        NMSSHHostConfig *config = [array lastObject];
        NSRange valueRange = [self rangeOfFirstTokenInString:arguments suffix:NULL];
        if (valueRange.location != NSNotFound &&
            valueRange.length > 0) {
            [config setHostname:[arguments substringWithRange:valueRange]];
        }
    }
    else if ([keyword localizedCaseInsensitiveCompare:@"port"] == NSOrderedSame
             && [array count]) {
        NMSSHHostConfig *config = [array lastObject];
        NSRange valueRange = [self rangeOfFirstTokenInString:arguments suffix:NULL];
        if (valueRange.location != NSNotFound &&
            valueRange.length > 0) {
            NSString *portString = [arguments substringWithRange:valueRange];
            NSInteger port = [portString intValue];
            if (port >= 0) {
                [config setPort:(port & 0xffff)];
            }
        }
    }
    else if ([keyword localizedCaseInsensitiveCompare:@"identityfile"] == NSOrderedSame &&
             [array count]) {
        NMSSHHostConfig *config = [array lastObject];
        NSRange valueRange = [self rangeOfFirstTokenInString:arguments suffix:NULL];
        if (valueRange.location != NSNotFound &&
            valueRange.length > 0) {
            NSString *identityFile =
                [[arguments substringWithRange:valueRange] stringByExpandingTildeInPath];
            [config setIdentityFiles:[config.identityFiles arrayByAddingObject:identityFile]];
        }
    }
}

- (NSCharacterSet *)blanksCharacterSet {
    NSMutableCharacterSet *blanksCharacterSet = [[NSMutableCharacterSet alloc] init];
    [blanksCharacterSet addCharactersInRange:NSMakeRange(' ', 1)];
    [blanksCharacterSet addCharactersInRange:NSMakeRange('\t', 1)];
    return blanksCharacterSet;
}

// Returns the range of a quoted substring in line starting with a quote at location. If there is
// no matching close quote then a location of NSNotFound is returned. Otherwise, the range of the
// text inside the quotes (excluding the quotes) is returned.
- (NSRange)rangeOfQuotedSubstringInString:(NSString *)line
                          startingAtIndex:(NSUInteger)location {
    NSUInteger start = location + 1;
    NSRange possiblyQuotedRange = NSMakeRange(start,
                                              [line length] - start);
    NSRange rangeOfCloseQuote = [line rangeOfString:@"\""
                                            options:0
                                              range:possiblyQuotedRange];
    if (rangeOfCloseQuote.location == NSNotFound) {
        return NSMakeRange(NSNotFound, 0);
    }
    else {
        return NSMakeRange(start, rangeOfCloseQuote.location - start);
    }
}

- (NSRange)rangeInString:(NSString *)line fromLocationUntilBlankOrEnd:(NSUInteger)location {
    NSRange tailRange = NSMakeRange(location,
                                    [line length] - location);
    NSRange terminatingBlank = [line rangeOfCharacterFromSet:[self blanksCharacterSet]
                                                     options:0
                                                       range:tailRange];
    if (terminatingBlank.location == NSNotFound) {
        return tailRange;
    }
    else {
        return NSMakeRange(location, NSMaxRange(terminatingBlank) - location - 1);
    }
}

- (NSRange)rangeOfFirstTokenInString:(NSString *)line suffix:(NSString **)suffixPtr {
    NSCharacterSet *blanksCharacterSet = [self blanksCharacterSet];
    NSMutableCharacterSet *nonBlanksCharacterSet = [blanksCharacterSet mutableCopy];
    [nonBlanksCharacterSet invert];

    NSRange rangeOfFirstNonBlank = [line rangeOfCharacterFromSet:nonBlanksCharacterSet];
    if (rangeOfFirstNonBlank.location == NSNotFound) {
        return rangeOfFirstNonBlank;
    }

    if ([line characterAtIndex:rangeOfFirstNonBlank.location] == '"') {
        NSRange range = [self rangeOfQuotedSubstringInString:line
                                             startingAtIndex:rangeOfFirstNonBlank.location];
        if (suffixPtr != NULL && range.location != NSNotFound) {
            *suffixPtr = [line substringFromIndex:NSMaxRange(range) + 1];
        }
        return range;
    }
    else {
        NSRange range =
            [self rangeInString:line fromLocationUntilBlankOrEnd:rangeOfFirstNonBlank.location];
        if (suffixPtr != NULL) {
            *suffixPtr = [line substringFromIndex:NSMaxRange(range)];
        }
        return range;
    }
}

// -----------------------------------------------------------------------------
#pragma mark - MATCHING
// -----------------------------------------------------------------------------

- (NMSSHHostConfig *)hostConfigForHost:(NSString *)host {
    for (NMSSHHostConfig *config in _hostConfigs) {
        NMSSHConfigMatch match = NMSSHConfigMatchNone;
        for (NSString *pattern in config.hostPatterns) {
            switch ([self host:host matchesPatternList:pattern]) {
                case NMSSHConfigMatchPositive:
                    match = NMSSHConfigMatchPositive;
                    break;

                case NMSSHConfigMatchNegative:
                    return nil;

                case NMSSHConfigMatchNone:
                    break;
            }
        }
        if (match == NMSSHConfigMatchPositive) {
            return config;
        }
    }

    return nil;
}

// A pattern list is a comma-delimited sequence of subpatterns. A subpattern is a string with
// wildcards optionally preceded by an !. If the host matches any negated subpattern then it is a
// negative match. Otherwise, if the host matches any non-negated subpattern then it is a positive
// match. If the host matches no patterns then it is a None match.
- (NMSSHConfigMatch)host:(NSString *)host matchesPatternList:(NSString *)patternList {
    NSArray *patterns = [patternList componentsSeparatedByString:@","];
    NMSSHConfigMatch match = NMSSHConfigMatchNone;
    for (NSString *mixedCasePattern in patterns) {
        NSString *pattern = [mixedCasePattern lowercaseString];
        BOOL negated = NO;
        if ([pattern hasPrefix:@"!"]) {
            negated = YES;
            pattern = [pattern substringFromIndex:1];
        }
        if ([self host:host matchesSubpattern:pattern]) {
            if (negated) {
                return NMSSHConfigMatchNegative;
            }
            else {
                match = NMSSHConfigMatchPositive;
            }
        }
    }
    return match;
}

- (BOOL)host:(NSString *)host matchesSubpattern:(NSString *)subPattern {
    if (host == nil || subPattern == nil) {
        return NO;
    }
    NSUInteger patternIndex = 0;
    NSUInteger patternLength = subPattern.length;

    NSUInteger hostIndex = 0;
    NSUInteger hostLength = host.length;
    while (1) {
        if (patternIndex == patternLength) {
            return hostIndex == hostLength;
        }
        unichar patternChar = [subPattern characterAtIndex:patternIndex];
        if (patternChar == '*') {
            ++patternIndex;
            if (patternIndex == patternLength) {
                // If at end of pattenr, accept immediately.
                return YES;
            }

            // If next character in pattern is not a wildcard, optimize.
            unichar patternPeek = [subPattern characterAtIndex:patternIndex];
            if (patternPeek != '?' && patternPeek != '*') {
                // Look for an instance in the host of the next char to match in the pattern.
                for (; hostIndex < hostLength; hostIndex++) {
                    unichar hostChar = [host characterAtIndex:hostIndex];
                    if (hostChar == patternPeek) {
                        NSString *tailHost = [host substringFromIndex:hostIndex + 1];
                        NSString *tailSubpattern = [subPattern substringFromIndex:patternIndex + 1];
                        if ([self host:tailHost matchesSubpattern:tailSubpattern]) {
                            return YES;
                        }
                    }
                }
                // Failed.
                return NO;
            }

            // Move ahead one char at a time and try to match at each position
            for (; hostIndex < hostLength; ++hostIndex) {
                NSString *tailHost = [host substringFromIndex:hostIndex];
                NSString *tailPattern = [subPattern substringFromIndex:patternIndex];
                if ([self host:tailHost matchesSubpattern:tailPattern]) {
                    return YES;
                }
            }

            // Failed
            return NO;
        }

        // There must be at least one more char in the string. If we reached the end, then fail.
        if (hostIndex == hostLength) {
            return NO;
        }

        unichar hostChar = [host characterAtIndex:hostIndex];
        // Check if the next character of the string is acceptable.
        if (patternChar != '?' && patternChar != hostChar) {
            return NO;
        }

        ++hostIndex;
        ++patternIndex;
    }

    // Unreachable code.
    return NO;
}

@end
