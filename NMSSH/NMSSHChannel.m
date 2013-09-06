#import "NMSSHChannel.h"
#import "socket_helper.h"

@interface NMSSHChannel ()
@property (nonatomic, strong) NMSSHSession *session;
@property (nonatomic, assign) LIBSSH2_CHANNEL *channel;

@property (nonatomic, readwrite) NMSSHChannelType type;
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
        [self setBufferSize:kNMSSHBufferSize];
        [self setRequestPty:NO];
        [self setPtyTerminalType:NMSSHChannelPtyTerminalVanilla];
        [self setType:NMSSHChannelTypeClosed];

        // Make sure we were provided a valid session
        if (![self.session isKindOfClass:[NMSSHSession class]]) {
            @throw @"You have to provide a valid NMSSHSession!";
        }
    }

    return self;
}

- (BOOL)openChannel:(NSError *__autoreleasing *)error {
    if (self.channel != NULL) {
        [self closeChannel];
    }

    // Set non-blocking mode
    libssh2_session_set_blocking(self.session.rawSession, 0);

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

        return NO;
    }

    [self setChannel:channel];

    int rc = 0;

    // Try to set environment variables
    if (self.environmentVariables) {
        for (NSString *key in self.environmentVariables) {
            if ([key isKindOfClass:[NSString class]] && [[self.environmentVariables objectForKey:key] isKindOfClass:[NSString class]]) {
                while ((rc = libssh2_channel_setenv(self.channel, [key UTF8String], [[self.environmentVariables objectForKey:key] UTF8String])) == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(self.session.sock, self.session.rawSession);
                }
            }
        }
    }

    // If requested, try to allocate a pty
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
            [self closeChannel];

            return NO;
        }
    }

    return YES;
}

- (void)closeChannel {
    if (self.channel) {
        int rc;
        if (self.type == NMSSHChannelTypeShell) {
            while ((rc = libssh2_channel_send_eof(self.channel)) == LIBSSH2_ERROR_EAGAIN) {
                waitsocket(self.session.sock, self.session.rawSession);
            }

            if (rc == 0) {
                while (libssh2_channel_wait_eof(self.channel) == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(self.session.sock, self.session.rawSession);
                }
            }
        }

        while ((rc = libssh2_channel_close(self.channel)) == LIBSSH2_ERROR_EAGAIN) {
            waitsocket(self.session.sock, self.session.rawSession);
        }
        
        if (rc == 0) {
            while (libssh2_channel_wait_closed(self.channel) == LIBSSH2_ERROR_EAGAIN) {
                waitsocket(self.session.sock, self.session.rawSession);
            }
        }

        libssh2_channel_free(self.channel);
        [self setType:NMSSHChannelTypeClosed];
        [self setChannel:NULL];
    }
}

- (NSString *)libssh2ErrorDescription:(ssize_t)errorCode {
    if (errorCode > 0) {
        return @"";
    }

    switch (errorCode) {
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

        case LIBSSH2_ERROR_SCP_PROTOCOL:
            return @"scp protocol error";

        case LIBSSH2_ERROR_TIMEOUT:
            return @"timeout";

        case LIBSSH2_ERROR_BAD_USE:
            return @"bad use";

        case LIBSSH2_ERROR_NONE:
        case LIBSSH2_ERROR_EAGAIN:
            return @"";
    }

    return [NSString stringWithFormat:@"unknown error [%zi]", errorCode];
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

    if (![self openChannel:error]) {
        return nil;
    }

    [self setLastResponse:nil];

    int rc = 0;
    [self setType:NMSSHChannelTypeExec];

    // Try executing command
    while ((rc = libssh2_channel_exec(self.channel, [command UTF8String])) == LIBSSH2_ERROR_EAGAIN) {
        waitsocket(self.session.sock, self.session.rawSession);
    }

    if (rc != 0) {
        if (error) {
            [userInfo setObject:[self libssh2ErrorDescription:rc] forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelExecutionError
                                     userInfo:userInfo];
        }

        NMSSHLogError(@"NMSSH: Error executing command");
        [self closeChannel];
        return nil;
    }

    // Set the timeout for blocking session
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent() + [timeout doubleValue];

    // Fetch response from output buffer
    NSMutableString *response = [[NSMutableString alloc] init];
    for (;;) {
        ssize_t rc;
        char buffer[self.bufferSize];
        char errorBuffer[self.bufferSize];

        do {
            rc = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer) - 1);

            if (rc > 0) {
                buffer[rc] = '\0';
                [response appendFormat:@"%s", buffer];
            }

            // Store all errors that might occur
            if (libssh2_channel_get_exit_status(self.channel)) {
                if (error) {
                    ssize_t erc = libssh2_channel_read_stderr(self.channel, errorBuffer, (ssize_t)sizeof(errorBuffer)-1);

                    if (erc > 0) {
                        errorBuffer[erc] = '\0';
                    }

                    NSString *desc = [NSString stringWithUTF8String:errorBuffer];
                    if (!desc) {
                        desc = @"An unspecified error occurred";
                    }

                    [userInfo setObject:desc forKey:NSLocalizedDescriptionKey];
                    [userInfo setObject:[self libssh2ErrorDescription:erc] forKey:NSLocalizedFailureReasonErrorKey];

                    *error = [NSError errorWithDomain:@"NMSSH"
                                                 code:NMSSHChannelExecutionError
                                             userInfo:userInfo];
                }
            }

            if (libssh2_channel_eof(self.channel) == 1 || rc == 0) {
                while ((rc  = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer)-1)) > 0) {
                    buffer[rc] = '\0';
                    [response appendFormat:@"%s", buffer];
                }

                [self setLastResponse:[response copy]];
                [self closeChannel];

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

                while ((rc  = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer)-1)) > 0) {
                    buffer[rc] = '\0';
                    [response appendFormat:@"%s", buffer];
                }

                [self setLastResponse:[response copy]];
                [self closeChannel];

                return self.lastResponse;
            }
        } while (rc > 0);

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
    [self closeChannel];

    return nil;
}

// -----------------------------------------------------------------------------
#pragma mark - REMOTE SHELL SESSION
// -----------------------------------------------------------------------------

- (BOOL)startShell:(NSError *__autoreleasing *)error  {
    NMSSHLogInfo(@"NMSSH: Starting shell");

    if (![self openChannel:error]) {
        return NO;
    }

    int rc = 0;
    [self setType:NMSSHChannelTypeShell];

    // Try opening the shell
    while ((rc = libssh2_channel_shell(self.channel)) == LIBSSH2_ERROR_EAGAIN) {
        waitsocket([self.session sock], [self.session rawSession]);
    }

    if (rc != 0) {
        NMSSHLogError(@"NMSSH: Shell request error");
        if (error) {
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelRequestShellError
                                     userInfo:@{ NSLocalizedDescriptionKey : [self libssh2ErrorDescription:rc] }];
        }

        [self closeChannel];
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Shell allocated");

    [self setLastResponse:nil];

    // Fetch response from output buffer
    dispatch_queue_t channelQueue = dispatch_queue_create("com.NMSSH.channelQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(channelQueue, ^{
        for (;;) {
            ssize_t rc;
            ssize_t erc;
            char buffer[self.bufferSize];
            char errorBuffer[self.bufferSize];

            do {
                rc  = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer)-1);
                erc = libssh2_channel_read_stderr(self.channel, errorBuffer, (ssize_t)sizeof(errorBuffer)-1);

                // A new error has been read
                if (erc > 0) {
                    errorBuffer[erc] = '\0';
                    NSString *error = [NSString stringWithFormat:@"%s", errorBuffer];

                    if (self.delegate) {
                        [self.delegate channel:self didReadError:error];
                    }
                    else {
                        NMSSHLogError(@"NMSSH: Received error from shell '%@'", error);
                    }
                }

                // A new message has been read
                if (rc > 0) {
                    buffer[rc] = '\0';
                    NSMutableString *response = [[NSMutableString alloc] initWithFormat:@"%s", buffer];
                    while ((rc  = libssh2_channel_read(self.channel, buffer, (ssize_t)sizeof(buffer)-1)) > 0) {
                        buffer[rc] = '\0';
                        [response appendFormat:@"%s", buffer];
                    }

                    [self setLastResponse:[response copy]];

                    if (self.delegate) {
                        [self.delegate channel:self didReadData:self.lastResponse];
                    }
                }

                // Check if the channel is closed
                if (rc == LIBSSH2_ERROR_CHANNEL_CLOSED || self.channel == NULL || libssh2_channel_eof(self.channel) == 1) {
                    if (libssh2_channel_eof(self.channel) == 1) {
                        [self closeChannel];
                    }

                    NMSSHLogVerbose(@"NMSSH: Channel closed, stop reading");
                    return ;
                }
            } while (rc > 0);

            if (rc != LIBSSH2_ERROR_EAGAIN) {
                break;
            }

            waitsocket(self.session.sock, self.session.rawSession);
        }
    });

    #if !(OS_OBJECT_USE_OBJC)
    dispatch_release(channelQueue);
    #endif

    return YES;
}

- (void)closeShell {
    [self closeChannel];
}

- (BOOL)write:(NSString *)command error:(NSError *__autoreleasing *)error {
    return [self write:command error:error timeout:@0];
}

- (BOOL)write:(NSString *)command error:(NSError **)error timeout:(NSNumber *)timeout {
    if (self.type != NMSSHChannelTypeShell) {
        NMSSHLogError(@"NMSSH: Shell required");
        return NO;
    }

    NMSSHLogVerbose(@"NMSSH: Writing '%@' on shell", [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
    int rc;

    // Set the timeout
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent() + [timeout doubleValue];

    // Try writing on shell
    while ((rc = libssh2_channel_write(self.channel, [command UTF8String], strlen([command UTF8String]))) == LIBSSH2_ERROR_EAGAIN) {
        // Check if the connection timed out
        if ([timeout longValue] > 0 && time < CFAbsoluteTimeGetCurrent()) {
            if (error) {
                NSString *desc = @"Connection timed out";

                *error = [NSError errorWithDomain:@"NMSSH"
                                             code:NMSSHChannelExecutionTimeout
                                         userInfo:@{ NSLocalizedDescriptionKey : desc }];
            }

            return NO;
        }

        waitsocket(self.session.sock, self.session.rawSession);
    }

    if (rc < 0) {
        NMSSHLogError(@"NMSSH: Error writing on the shell");
        if (error) {
            *error = [NSError errorWithDomain:@"NMSSH"
                                         code:NMSSHChannelWriteError
                                     userInfo:@{ NSLocalizedDescriptionKey : [self libssh2ErrorDescription:rc],
                                                 @"command"                : command }];
        }
    }

    return YES;
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

    if (self.channel == NULL) {
        NMSSHLogError(@"NMSSH: Unable to open SCP session");
        return NO;
    }

    [self setType:NMSSHChannelTypeSCP];

    // Wait for file transfer to finish
    char mem[self.bufferSize];
    size_t nread;
    char *ptr;
    while ((nread = fread(mem, 1, sizeof(mem), local)) > 0) {
        ptr = mem;

        do {
            // Write the same data over and over, until error or completion
            long rc = libssh2_channel_write(self.channel, ptr, nread);

            if (rc < 0) {
                NMSSHLogError(@"NMSSH: Failed writing file");
                [self closeChannel];
                return NO;
            }
            else {
                // rc indicates how many bytes were written this time
                ptr += rc;
                nread -= rc;
            }
        } while (nread);
    };

    [self closeChannel];

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

    if (self.channel == NULL) {
        NMSSHLogError(@"NMSSH: Unable to open SCP session");
        return NO;
    }

    [self setType:NMSSHChannelTypeSCP];

    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        NMSSHLogInfo(@"NMSSH: A file already exists at %@, it will be overwritten.", localPath);
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
    }

    // Open local file in order to write to it
    int localFile = open([localPath UTF8String], O_WRONLY|O_CREAT, 0644);

    // Save data to local file
    off_t got = 0;
    while (got < fileinfo.st_size) {
        char mem[self.bufferSize];
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
            [self closeChannel];

            return NO;
        }

        memset(mem, 0x0, sizeof(mem));
        got += rc;
    }

    close(localFile);
    [self closeChannel];

    return YES;
}

@end
