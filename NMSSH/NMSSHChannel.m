#import "NMSSHChannel.h"
#import "socket_helper.h"

@interface NMSSHChannel ()
@property (nonatomic, strong) NMSSHSession *session;
@property (nonatomic, assign) LIBSSH2_CHANNEL *channel;

@property (nonatomic, assign) const char *ptyTerminalName;
@property (nonatomic, strong) NSString *lastResponse;
@end

@implementation NMSSHChannel

// -----------------------------------------------------------------------------
#pragma mark - INITIALIZER
// -----------------------------------------------------------------------------

- (id)initWithSession:(NMSSHSession *)session {
    if ((self = [super init])) {
        [self setSession:session];
        [self setRequestPty:NO];
        [self setPtyTerminalType:NMSSHChannelPtyTerminalVanilla];

        // Make sure we were provided a valid session
        if (![self.session isKindOfClass:[NMSSHSession class]]) {
            @throw @"You have to provide a valid NMSSHSession!";
        }
    }

    return self;
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    // Open up the channel
    LIBSSH2_CHANNEL *channel;
    while ((channel = libssh2_channel_open_session(self.session.rawSession)) == NULL &&
           libssh2_session_last_error(self.session.rawSession, NULL, NULL, 0) ==
           LIBSSH2_ERROR_EAGAIN) {
        waitsocket(self.session.sock, self.session.rawSession);
    }
    
    if (channel == NULL){
        NMSSHLogError(@"NMSSH: Unable to open a session");
        if (error) {
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelAllocationError
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Channel allocation error" }];
        }
        
        return nil;
    }
    
    [self setChannel:channel];
    
    // If requested, try to allocate a pty
    int rc = 0;
    
    if (self.requestPty) {
        while ((rc = libssh2_channel_request_pty(self.channel, self.ptyTerminalName)) == LIBSSH2_ERROR_EAGAIN) {
            waitsocket(self.session.sock, self.session.rawSession);
        }
        
        if (rc != 0) {
            if (error) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error requesting %s pty: %@", self.ptyTerminalName, [self libssh2ErrorDescription:rc]] };
                
                *error = [NSError errorWithDomain:@"NMSSH"
                                             code:NMSSHChannelRequestPtyError
                                         userInfo:userInfo];
            }
            
            NMSSHLogError(@"NMSSH: Error requesting pseudo terminal");
            [self close];
            
            return NO;
        }
    }
    
    return YES;
}

- (void)close {
    if (self.channel) {
        libssh2_channel_close(self.channel);
        libssh2_channel_free(self.channel);
        [self setChannel:nil];
    }
}

- (NSString *)libssh2ErrorDescription:(int)error {
    if (error >= 0) {
        return @"";
    }
    
    switch (error) {
        case LIBSSH2_ERROR_ALLOC:
            return @"internal allocation memory error";
            
        case LIBSSH2_ERROR_SOCKET_SEND:
            return @"unable to send data on socket";
            
        case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
            return @"request denied";
            
        case LIBSSH2_ERROR_CHANNEL_CLOSED:
            return @"channel has been closed";
            
        case LIBSSH2_ERROR_CHANNEL_EOF_SENT:
            return @"channel has been requested to be closed";
            
        case LIBSSH2_ERROR_CHANNEL_FAILURE:
            return @"channel failure";
            
        case LIBSSH2_ERROR_EAGAIN:
            return @"";
    }
    
    return [NSString stringWithFormat:@"unknown error [%i]", error];
}

// -----------------------------------------------------------------------------
#pragma mark - SHELL COMMAND EXECUTION
// -----------------------------------------------------------------------------

- (const char *)ptyTerminalName {
    switch (self.ptyTerminalType) {
        case NMSSHChannelPtyTerminalVanilla:
            return "vanilla";

        case NMSSHChannelPtyTerminalVT100:
            return "vt100";
			
        case NMSSHChannelPtyTerminalVT102:
            return "vt102";
			
        case NMSSHChannelPtyTerminalVT220:
            return "vt220";

        case NMSSHChannelPtyTerminalAnsi:
            return "ansi";
    }

    // catch invalid values
    return "vanilla";
}

- (NSString *)execute:(NSString *)command error:(NSError *__autoreleasing *)error {
    return [self execute:command error:error timeout:@0];
}

- (NSString *)execute:(NSString *)command error:(NSError *__autoreleasing *)error timeout:(NSNumber *)timeout {
    NMSSHLogInfo(@"NMSSH: Exec command %@", command);

    // In case of error...
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:command forKey:@"command"];
    
    if (![self start:error]) {
        return nil;
    }
    
    [self setLastResponse:nil];
    
    int rc = 0;

    // Try executing command
    while ((rc = libssh2_channel_exec(self.channel, [command UTF8String])) == LIBSSH2_ERROR_EAGAIN) {
        waitsocket(self.session.sock, self.session.rawSession);
    }

    libssh2_channel_wait_closed(self.channel);

    if (rc != 0) {
        if (error) {
            [userInfo setObject:[self libssh2ErrorDescription:rc] forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelExecutionError
                                     userInfo:userInfo];
        }

        NMSSHLogError(@"NMSSH: Error executing command");
        [self close];
        return nil;
    }

    // Set the timeout for blocking session
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent() + [timeout doubleValue];
    if ([timeout longValue] >= 0) {
        libssh2_session_set_timeout(self.session.rawSession, [timeout longValue] * 1000);
    }

    // Fetch response from output buffer
    for (;;) {
        long rc;
        char buffer[0x4000];
        char errorBuffer[0x4000];

        do {
            rc = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer));

            // Store all errors that might occur
            if (libssh2_channel_get_exit_status(self.channel)) {
                if (error) {
                    libssh2_channel_read_stderr(self.channel, errorBuffer, (ssize_t)sizeof(errorBuffer));

                    NSString *desc = [NSString stringWithUTF8String:errorBuffer];
                    if (!desc) {
                        desc = @"An unspecified error occurred";
                    }

                    [userInfo setObject:desc forKey:NSLocalizedDescriptionKey];
                    [userInfo setObject:[self libssh2ErrorDescription:rc] forKey:NSLocalizedFailureReasonErrorKey];

                    *error = [NSError errorWithDomain:@"NMSSH"
                                                 code:NMSSHChannelExecutionError
                                             userInfo:userInfo];
                    return nil;
                }
            }

            if (rc == 0) {
                [self setLastResponse:[NSString stringWithFormat:@"%s", buffer]];
                [self close];

                return self.lastResponse;
            }

            // Check if the connection timed out
            if ([timeout longValue] > 0 && time < CFAbsoluteTimeGetCurrent()) {
                if (error) {
                    NSString *desc = @"Connection timed out";

                    [userInfo setObject:desc forKey:NSLocalizedDescriptionKey];

                    *error = [NSError errorWithDomain:@"NMSSH"
                                                 code:NMSSHChannelExecutionTimeout
                                             userInfo:userInfo];
                }

                [self close];
                return nil;
            }
        }
        while (rc > 0);

        // This is due to blocking that would occur otherwise so we loop on this condition
        if (rc != LIBSSH2_ERROR_EAGAIN) {
            break;
        }

        waitsocket(self.session.sock, self.session.rawSession);
    }

    // If we've got this far, it means fetching execution response failed
    if (error) {
        [userInfo setObject:[self libssh2ErrorDescription:rc] forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH"
                                     code:NMSSHChannelExecutionResponseError
                                 userInfo:userInfo];
    }

    NMSSHLogError(@"NMSSH: Error fetching response from command");
    [self close];

    return nil;
}

// -----------------------------------------------------------------------------
#pragma mark - SCP FILE TRANSFER
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
        NMSSHLogError(@"NMSSH: Can't read local file");
        return NO;
    }

    // Try to send a file via SCP.
    struct stat fileinfo;
    stat([localPath UTF8String], &fileinfo);
    [self setChannel:libssh2_scp_send(self.session.rawSession, [remotePath UTF8String],
                                      fileinfo.st_mode & 0644,
                                      (unsigned long)fileinfo.st_size)];

    if (!self.channel) {
        NMSSHLogError(@"NMSSH: Unable to open SCP session");
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
            long rc = libssh2_channel_write(self.channel, ptr, nread);

            if (rc < 0) {
                NMSSHLogError(@"NMSSH: Failed writing file");
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
    libssh2_channel_send_eof(self.channel);
    libssh2_channel_wait_eof(self.channel);
    libssh2_channel_wait_closed(self.channel);
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
    [self setChannel:libssh2_scp_recv(self.session.rawSession, [remotePath UTF8String],
                                      &fileinfo)];

    if (!self.channel) {
        NMSSHLogError(@"NMSSH: Unable to open SCP session");
        return NO;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        NMSSHLogInfo(@"NMSSH: A file already exists at %@, it will be overwritten.", localPath);
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
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

        ssize_t rc = libssh2_channel_read(self.channel, mem, amount);

        if (rc > 0) {
            write(localFile, mem, rc);
        }
        else if (rc < 0) {
            NMSSHLogError(@"NMSSH: Failed to read SCP data");
            close(localFile);
            [self close];

            return NO;
        }

        memset(mem, 0x0, sizeof(mem));
        got += rc;
    }

    close(localFile);
    [self close];

    return YES;
}

@end
