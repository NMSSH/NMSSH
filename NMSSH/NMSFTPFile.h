//
//  NMSFTPFile.h
//  NMSSH
//
//  Created by Sebastian Hunkeler on 16/01/14.
//
//

#import "NMSSH.h"

@interface NMSFTPFile : NSObject

@property (nonatomic, readonly, strong) NSString* filename;
@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly ,strong) NSDate* modificationDate;
@property (nonatomic, readonly ,strong) NSDate* lastAccess;
@property (nonatomic, readonly, strong) NSNumber* fileSize;
@property (nonatomic, readonly) uid_t ownerUserID;
@property (nonatomic, readonly) gid_t ownerGroupID;
@property (nonatomic, readonly, strong) NSString* permissions;
@property (nonatomic, readonly) NSUInteger flags;

- (id)initWithFilename:(NSString*)filename;

/**
 * Populates the file properties with the attributes taken from the LIBSSH2_SFTP_ATTRIBUTES object.
 *
 * @param fileAttributes The LIBSSH2_SFTP_ATTRIBUTES object that contains the attributes that are being extracted.
 **/
- (void)populateValuesFromSFTPAttributes:(LIBSSH2_SFTP_ATTRIBUTES)fileAttributes;

@end
