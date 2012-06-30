#import "ConfigHelper.h"
#import <YAML/YAMLSerialization.h>

@implementation ConfigHelper

+ (id)valueForKey:(NSString *)key {
    static id yaml;

    if (!yaml) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:@"config" ofType:@"yml"];

        NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath:path];
        yaml = [YAMLSerialization YAMLWithStream:stream
                                         options:kYAMLReadOptionStringScalars
                                           error:nil];
    }

    id data = [yaml objectAtIndex:0];
    NSArray *keyList = [key componentsSeparatedByString:@"."];
    for (NSString *keyPart in keyList) {
        data = [data objectForKey:keyPart];
    }

    return data;
}

@end
