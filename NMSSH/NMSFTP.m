#import "NMSFTP.h"

@interface NMSFTP ()
@property (nonatomic, strong) NMSSHSession *session;
@property (nonatomic, assign) LIBSSH2_SFTP *sftpSession;
@property (nonatomic, readwrite, getter = isConnected) BOOL connected;
@end

@implementation NMSFTP

// -----------------------------------------------------------------------------
#pragma mark - INITIALIZER
// -----------------------------------------------------------------------------

+ (id)connectWithSession:(NMSSHSession *)session {
    NMSFTP *sftp = [[NMSFTP alloc] initWithSession:session];
    [sftp connect];

    return sftp;
}

- (id)initWithSession:(NMSSHSession *)session {
    if ((self = [super init])) {
        [self setSession:session];

        // Make sure we were provided a valid session
        if (![session isKindOfClass:[NMSSHSession class]]) {
            @throw @"You have to provide a valid NMSSHSession!";
        }
    }

    return self;
}

// -----------------------------------------------------------------------------
#pragma mark - CONNECTION
// -----------------------------------------------------------------------------

- (BOOL)connect {
    libssh2_session_set_blocking(self.session.rawSession, 1);
    [self setSftpSession:libssh2_sftp_init(self.session.rawSession)];

    if (!self.sftpSession) {
        NMSSHLogError(@"NMSFTP: Unable to init SFTP session");
        return NO;
    }

    [self setConnected:YES];

    return self.isConnected;
}

- (void)disconnect {
    libssh2_sftp_shutdown(self.sftpSession);
    [self setConnected:NO];
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE FILE SYSTEM ENTRIES
// -----------------------------------------------------------------------------

- (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destPath {
    long rc = libssh2_sftp_rename(self.sftpSession, [sourcePath UTF8String], [destPath UTF8String]);

    return rc == 0;
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE DIRECTORIES
// -----------------------------------------------------------------------------

- (BOOL)directoryExistsAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(self.sftpSession, [path UTF8String],
                                                    LIBSSH2_FXF_READ, 0);
    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;

    if (!handle) {
        return NO;
    }

    long rc = libssh2_sftp_fstat(handle, &fileAttributes);
    libssh2_sftp_close(handle);

    return rc == 0 && LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
}

- (BOOL)createDirectoryAtPath:(NSString *)path {
    int rc = libssh2_sftp_mkdir(self.sftpSession, [path UTF8String],
                            LIBSSH2_SFTP_S_IRWXU|
                            LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IXGRP|
                            LIBSSH2_SFTP_S_IROTH|LIBSSH2_SFTP_S_IXOTH);

    return rc == 0;
}

- (BOOL)removeDirectoryAtPath:(NSString *)path {
    return libssh2_sftp_rmdir(self.sftpSession, [path UTF8String]) == 0;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(self.sftpSession, [path UTF8String]);

    if (!handle) {
        NMSSHLogError(@"NMSFTP: Could not open directory");
        return nil;
    }

    NSArray *ignoredFiles = @[@".", @".."];
    NSMutableArray *contents = [NSMutableArray array];

    int rc;
    do {
        char buffer[512];
        LIBSSH2_SFTP_ATTRIBUTES fileAttributes;

        rc = libssh2_sftp_readdir(handle, buffer, sizeof(buffer), &fileAttributes);
        if (rc <= 0) {
            break;
        }

        NSString *fileName = [NSString stringWithUTF8String:buffer];
        if (![ignoredFiles containsObject:fileName]) {
            // Append a "/" at the end of all directories
            if (LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions)) {
                fileName = [fileName stringByAppendingString:@"/"];
            }

            [contents addObject:fileName];
        }
    } while (1);

    libssh2_sftp_closedir(handle);

    return [contents sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

// -----------------------------------------------------------------------------
#pragma mark - MANIPULATE SYMLINKS AND FILES
// -----------------------------------------------------------------------------

- (BOOL)fileExistsAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(self.sftpSession, [path UTF8String], LIBSSH2_FXF_READ, 0);
    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;

    if (!handle) {
        return NO;
    }

    long rc = libssh2_sftp_fstat(handle, &fileAttributes);
    libssh2_sftp_close(handle);

    return rc == 0 && !LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)linkPath
             withDestinationPath:(NSString *)destPath {
    int rc = libssh2_sftp_symlink(self.sftpSession, [destPath UTF8String], (char *)[linkPath UTF8String]);

    return rc == 0;
}

- (BOOL)removeFileAtPath:(NSString *)path {
    return libssh2_sftp_unlink(self.sftpSession, [path UTF8String]) == 0;
}

- (NSData *)contentsAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(self.sftpSession, [path UTF8String], LIBSSH2_FXF_READ, 0);

    if (!handle) {
        return nil;
    }

    char buffer[kNMSSHBufferSize];
    NSMutableData *data = [[NSMutableData alloc] init];
    ssize_t rc;
    do {
        rc = libssh2_sftp_read(handle, buffer, (ssize_t)sizeof(buffer));

        if (rc > 0) {
            [data appendBytes:buffer length:rc];
        }

    } while (rc > 0 || rc == EAGAIN);
    
    libssh2_sftp_close(handle);

    if (rc < 0) {
        return nil;
    }

    return [data copy];
}

- (BOOL)writeContents:(NSData *)contents toFileAtPath:(NSString *)path {
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open(self.sftpSession, [path UTF8String],
                      LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC,
                      LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|
                      LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH);

    long rc = libssh2_sftp_write(handle, [contents bytes], [contents length]);
    libssh2_sftp_close(handle);

    return rc > 0;
}

- (BOOL)appendContents:(NSData *)contents toFileAtPath:(NSString *)path {
    // The reason for reading, appending and writing instead of using the
    // LIBSSH2_FXF_APPEND flag on libssh2_sftp_open is because the flag doesn't
    // seem to be reliable accross a variety of hosts.
    NSData *originalContents = [self contentsAtPath:path];
    if (!originalContents) {
        return NO;
    }

    NSMutableData *newContents = [originalContents mutableCopy];
    [newContents appendData:contents];

    return [self writeContents:newContents toFileAtPath:path];
}

@end
