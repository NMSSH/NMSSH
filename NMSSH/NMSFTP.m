#import "NMSFTP.h"
#import "NMSSHSession.h"

#import "libssh2.h"
#import "libssh2_sftp.h"

@interface NMSFTP () {
    LIBSSH2_SFTP *sftpSession;
}
@end

@implementation NMSFTP
@synthesize session, connected;

// -----------------------------------------------------------------------------
// PUBLIC SETUP API
// -----------------------------------------------------------------------------

+ (id)connectWithSession:(NMSSHSession *)aSession {
    NMSFTP *sftp = [[NMSFTP alloc] initWithSession:aSession];
    [sftp connect];

    return sftp;
}

- (id)initWithSession:(NMSSHSession *)aSession {
    if ((self = [super init])) {
        session = aSession;

        // Make sure we were provided a valid session
        if (![session isKindOfClass:[NMSSHSession class]]) {
            return nil;
        }
    }

    return self;
}

// -----------------------------------------------------------------------------
// HANDLE CONNECTIONS
// -----------------------------------------------------------------------------

- (BOOL)connect {
    libssh2_session_set_blocking([session rawSession], 1);
    sftpSession = libssh2_sftp_init([session rawSession]);

    if (!sftpSession) {
        NSLog(@"NMSFTP: Unable to init SFTP session");
        return NO;
    }

    connected = YES;
    return [self isConnected];
}

- (void)disconnect {
    libssh2_sftp_shutdown(sftpSession);
    connected = NO;
}

// -----------------------------------------------------------------------------
// MANIPULATE FILE SYSTEM ENTRIES
// -----------------------------------------------------------------------------

- (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath {
    long rc = libssh2_sftp_rename(sftpSession, [sourcePath UTF8String],
                                           [destPath UTF8String]);

    return rc == 0;
}

// -----------------------------------------------------------------------------
// MANIPULATE DIRECTORIES
// -----------------------------------------------------------------------------

- (BOOL)createDirectoryAtPath:(NSString *)path {
    int rc = libssh2_sftp_mkdir(sftpSession, [path UTF8String],
                            LIBSSH2_SFTP_S_IRWXU|
                            LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IXGRP|
                            LIBSSH2_SFTP_S_IROTH|LIBSSH2_SFTP_S_IXOTH);

    return rc == 0;
}

- (BOOL)removeDirectoryAtPath:(NSString *)path {
    return libssh2_sftp_rmdir(sftpSession, [path UTF8String]) == 0;
}

// -----------------------------------------------------------------------------
// CREATE, SYMLINK AND DELETE FILES
// -----------------------------------------------------------------------------

- (BOOL)createSymbolicLinkAtPath:(NSString *)linkPath
             withDestinationPath:(NSString *)destPath {
    int rc = libssh2_sftp_symlink(sftpSession, [destPath UTF8String],
                                  (char *)[linkPath UTF8String]);

    return rc == 0;
}

- (BOOL)removeFileAtPath:(NSString *)path {
    return libssh2_sftp_unlink(sftpSession, [path UTF8String]) == 0;
}

- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(sftpSession, [path UTF8String],
                      LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC,
                      LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|
                      LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH);

    long rc = libssh2_sftp_write(handle, [contents bytes], [contents length]);
    libssh2_sftp_close(handle);

    return rc > 0;
}

@end
