#import "NMSSH.h"
#import "NSError+Additions.h"

NSString *const NMSSHErrorDomain = @"NMSSH";

@implementation NSError (NSError_NMSSHAdditions)

+ (NSString *)NMSFTPErrorMessageWithCode:(unsigned long)errorCode
{
	NSString *message = nil;
	switch (errorCode)
    {
		case LIBSSH2_FX_OK:
			message = NSLocalizedString(@"OK.", @"");
			break;
		case LIBSSH2_FX_EOF:
			message = NSLocalizedString(@"End of file.", @"");
			break;
		case LIBSSH2_FX_NO_SUCH_FILE:
			message = NSLocalizedString(@"No such file.", @"");
			break;
		case LIBSSH2_FX_PERMISSION_DENIED:
			message = NSLocalizedString(@"Permission denied.", @"");
			break;
		case LIBSSH2_FX_FAILURE:
			message = NSLocalizedString(@"Failure.", @"");
			break;
		case LIBSSH2_FX_BAD_MESSAGE:
			message = NSLocalizedString(@"Bad message.", @"");
			break;
        case LIBSSH2_FX_NO_CONNECTION:
			message = NSLocalizedString(@"No connection.", @"");
			break;
		case LIBSSH2_FX_CONNECTION_LOST:
			message = NSLocalizedString(@"Connection lost.", @"");
			break;
		case LIBSSH2_FX_OP_UNSUPPORTED:
			message = NSLocalizedString(@"Operation unsupported.", @"");
			break;
		case LIBSSH2_FX_INVALID_HANDLE:
			message = NSLocalizedString(@"Invalid handle.", @"");
			break;
		case LIBSSH2_FX_NO_SUCH_PATH:
			message = NSLocalizedString(@"No such path.", @"");
			break;
		case LIBSSH2_FX_FILE_ALREADY_EXISTS:
			message = NSLocalizedString(@"File already exists.", @"");
			break;
		case LIBSSH2_FX_WRITE_PROTECT:
			message = NSLocalizedString(@"Write protect.", @"");
			break;
		case LIBSSH2_FX_NO_MEDIA:
			message = NSLocalizedString(@"No media.", @"");
			break;
		case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM:
			message = NSLocalizedString(@"No space on filesystem.", @"");
			break;
		case LIBSSH2_FX_QUOTA_EXCEEDED:
			message = NSLocalizedString(@"Quota exceeded.", @"");
			break;
		case LIBSSH2_FX_UNKNOWN_PRINCIPAL:
			message = NSLocalizedString(@"Unknown principal.", @"");
			break;
        case LIBSSH2_FX_LOCK_CONFLICT:
			message = NSLocalizedString(@"Lock conflict.", @"");
			break;
		case LIBSSH2_FX_DIR_NOT_EMPTY:
			message = NSLocalizedString(@"Directory not empty.", @"");
			break;
        case LIBSSH2_FX_NOT_A_DIRECTORY:
			message = NSLocalizedString(@"Not a directory.", @"");
			break;
        case LIBSSH2_FX_INVALID_FILENAME:
			message = NSLocalizedString(@"Invalid filename.", @"");
			break;
        case LIBSSH2_FX_LINK_LOOP:
			message = NSLocalizedString(@"Link loop.", @"");
			break;
		default:
            message = NSLocalizedString(@"Unknown error", @"");
			break;
	}
	return message;
}

+ (NSError *)NMSFTPErrorWithCode:(unsigned long)errorCode
{
	return [[NSError alloc] initWithDomain:@"NMSSH" code:errorCode
                                  userInfo:@{NSLocalizedDescriptionKey: [NSError NMSFTPErrorMessageWithCode:errorCode]}];
}

@end
