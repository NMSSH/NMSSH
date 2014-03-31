
extern NSString *const NMSSHErrorDomain;

@interface NSError (NSError_NMSSHAdditions)

/**
 Returns respective error message for a given code.
 
 @param errorCode SFTP error code
 @return Returns localized message
 */
+ (NSString *)NMSFTPErrorMessageWithCode:(unsigned long)errorCode;

/**
 Returns an error for the respective SFTP error code.
 
 @param errorCode SFTP error code -- as returned from libssh2_sftp_last_error()
 @return Returns error w/ respective localized message.
 */
+ (NSError *)NMSFTPErrorWithCode:(unsigned long)errorCode;

@end
