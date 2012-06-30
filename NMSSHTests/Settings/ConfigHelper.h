#import <Foundation/Foundation.h>

@interface ConfigHelper : NSObject

/**
 * Helper method to get a value from the configuration YAML.
 *
 * Assuming the values in the YAML file can be represented as NSDictionary, you
 * can create a chain to get a deep value.
 *
 * Example:
 *
 *     NSString *host = [ConfigHelper valueForKey:
 *                         @"valid_password_protected_server.host"];
 */
+ (id)valueForKey:(NSString *)key;

@end
