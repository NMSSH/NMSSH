//
//  YAMLSerialization.h
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//	Released under MIT License
//
//  Copyright 2010 Mirek Rusin
//	Copyright 2010 Stanislav Yudin
//

#import <Foundation/Foundation.h>
#import "yaml.h"

// Mimics NSPropertyListMutabilityOptions
typedef enum {
  kYAMLReadOptionImmutable                  = 0x0000000000000001,
  kYAMLReadOptionMutableContainers          = 0x0000000000000010,
  kYAMLReadOptionMutableContainersAndLeaves = 0x0000000000000110,
  kYAMLReadOptionStringScalars              = 0x0000000000001000
} YAMLReadOptions;

typedef enum {
  kYAMLErrorNoErrors,
  kYAMLErrorCodeParserInitializationFailed,
  kYAMLErrorCodeParseError,
  kYAMLErrorCodeEmitterError,
  kYAMLErrorInvalidOptions,
  kYAMLErrorCodeOutOfMemory,
  kYAMLErrorInvalidYamlObject,
} YAMLErrorCode;

typedef enum {
  kYAMLWriteOptionSingleDocument    = 0x0000000000000001,
  kYAMLWriteOptionMultipleDocuments = 0x0000000000000010,
} YAMLWriteOptions;

extern NSString *const YAMLErrorDomain;

@interface YAMLSerialization : NSObject {
}

+ (void) writeYAML: (id) yaml
		  toStream: (NSOutputStream *) stream
		   options: (YAMLWriteOptions) opt
			 error: (NSError **) error;

+ (NSData *) dataFromYAML: (id) yaml
                  options: (YAMLWriteOptions) opt
                    error: (NSError **) error;

+ (NSMutableArray *) YAMLWithStream: (NSInputStream *) stream 
                            options: (YAMLReadOptions) opt
                              error: (NSError **) error;

+ (NSMutableArray *) YAMLWithData: (NSData *) data
                          options: (YAMLReadOptions) opt
                            error: (NSError **) error;

@end
