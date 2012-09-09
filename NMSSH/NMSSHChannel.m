#import "NMSSHChannel.h"
#import "NMSSHSession.h"

#import "libssh2.h"

@interface NMSSHChannel () {
    LIBSSH2_CHANNEL *channel;
}
@end

@implementation NMSSHChannel
@synthesize session, lastResponse;

// -----------------------------------------------------------------------------
// PUBLIC SETUP API
// -----------------------------------------------------------------------------

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
// PUBLIC SHELL EXECUTION API
// -----------------------------------------------------------------------------

- (NSString *)execute:(NSString *)command error:(NSError **)error {
    lastResponse = nil;

    // Open up the channel
    if (!(channel = libssh2_channel_open_session([session rawSession]))) {
        NSLog(@"NMSSH: Unable to open a session");
        return nil;
    }

    // In case of error...
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:command
                                                                       forKey:@"command"];

    // Try executing command
    int rc = libssh2_channel_exec(channel, [command UTF8String]);
    if (rc) {
        if (error) {
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelExecutionError
                                     userInfo:userInfo];
        }

        NSLog(@"NMSSH: Error executing command");
        [self close];
        return nil;
    }

    // Fetch response from output buffer
    for (;;) {
        long rc;
        char buffer[0x4000];
        char errorBuffer[0x4000];

        do {
            rc = libssh2_channel_read(channel, buffer, (ssize_t)sizeof(buffer));

            // Store all errors that might occur
            if (libssh2_channel_get_exit_status(channel)) {
                if (error) {
                    libssh2_channel_read_stderr(channel, errorBuffer,
                                                (ssize_t)sizeof(errorBuffer));

                    NSString *desc = [NSString stringWithUTF8String:errorBuffer];
                    if (!desc) {
                        desc = @"An unspecified error occurred";
                    }

                    [userInfo setObject:desc forKey:@"description"];

                    *error = [NSError errorWithDomain:@"NMSSH"
                                                 code:NMSSHChannelExecutionError
                                             userInfo:userInfo];
                }
            }

            if (rc == 0) {
                lastResponse = [NSString stringWithFormat:@"%s", buffer];
                [self close];
                return lastResponse;
            }
        }
        while (rc > 0);
    }

    // If we've got this far, it means fetching execution response failed
    if (error) {
        *error = [NSError errorWithDomain:@"NMSSH"
                                     code:NMSSHChannelExecutionResponseError
                                 userInfo:userInfo];
    }

    NSLog(@"NMSSH: Error fetching response from command");
    [self close];
    return nil;
}

// -----------------------------------------------------------------------------
// PUBLIC SCP API
// -----------------------------------------------------------------------------

- (BOOL)uploadFile:(NSString *)localPath to:(NSString *)remotePath {
    localPath = [localPath stringByExpandingTildeInPath];

    // Inherit file name if to: contains a directory
    if ([remotePath hasSuffix:@"/"]) {
        remotePath = [remotePath stringByAppendingString:
                     [[localPath componentsSeparatedByString:@"/"] lastObject]];
    }

    // Read local file
    FILE *local = fopen([localPath UTF8String], "rb");
    if (!local) {
        NSLog(@"NMSSH: Can't read local file");
        return NO;
    }

    // Try to send a file via SCP.
    struct stat fileinfo;
    stat([localPath UTF8String], &fileinfo);
    channel = libssh2_scp_send([session rawSession], [remotePath UTF8String],
                               fileinfo.st_mode & 0644,
                               (unsigned long)fileinfo.st_size);

    if (!channel) {
        NSLog(@"NMSSH: Unable to open SCP session");
        return NO;
    }

    // Wait for file transfer to finish
    char mem[1024];
    size_t nread;
    char *ptr;
    do {
        nread = fread(mem, 1, sizeof(mem), local);
        if (nread <= 0) {
            break; // End of file
        }
        ptr = mem;

        do {
            // Write the same data over and over, until error or completion
            long rc = libssh2_channel_write(channel, ptr, nread);

            if (rc < 0) {
                NSLog(@"NMSSH: Failed writing file");
                [self close];
                return NO;
            }
            else {
                // rc indicates how many bytes were written this time
                ptr += rc;
                nread -= rc;
            }
        } while (nread);
    } while (1);

    // Send EOF and clean up
    libssh2_channel_send_eof(channel);
    libssh2_channel_wait_eof(channel);
    libssh2_channel_wait_closed(channel);
    [self close];

    return YES;
}

- (BOOL)downloadFile:(NSString *)remotePath to:(NSString *)localPath {
    localPath = [localPath stringByExpandingTildeInPath];

    // Inherit file name if to: contains a directory
    if ([localPath hasSuffix:@"/"]) {
        localPath = [localPath stringByAppendingString:
                    [[remotePath componentsSeparatedByString:@"/"] lastObject]];
    }

    // Request a file via SCP
    struct stat fileinfo;
    channel = libssh2_scp_recv([session rawSession], [remotePath UTF8String],
                               &fileinfo);

    if (!channel) {
        NSLog(@"NMSSH: Unable to open SCP session");
        return NO;
    }

    // Open local file in order to write to it
    int localFile = open([localPath UTF8String], O_WRONLY|O_CREAT, 0644);

    // Save data to local file
    off_t got = 0;
    while (got < fileinfo.st_size) {
        char mem[1024];
        long long amount = sizeof(mem);

        if ((fileinfo.st_size - got) < amount) {
            amount = fileinfo.st_size - got;
        }

        ssize_t rc = libssh2_channel_read(channel, mem, amount);

        if (rc > 0) {
            write(localFile, mem, rc);
        }
        else if (rc < 0) {
            NSLog(@"NMSSH: Failed to read SCP data");
            close(localFile);
            [self close];
            return NO;
        }

        got += rc;
    }

    close(localFile);
    [self close];
    return YES;
}

// -----------------------------------------------------------------------------
// PRIVATE HELPER METHODS
// -----------------------------------------------------------------------------

- (void)close {
    if (channel) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        channel = nil;
    }
}

@end
