/*
Copyright (c) 2011 Christoffer Lejdborg

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

-------------------------------------------------------------------------------

The project contains modified code from the examples at
http://libssh2.org/examples/ssh2_exec.html
*/

#import "NMSSH.h"
#import "NMHostHelper.h"

#import "libssh2.h"
#include <netdb.h>
#include <sys/socket.h>
#include <arpa/inet.h>

@implementation NMSSH

unsigned long hostaddr;
int sock;
struct sockaddr_in soin;
int rc;

LIBSSH2_SESSION *session;
LIBSSH2_CHANNEL *channel;

static int waitsocket(int socket_fd, LIBSSH2_SESSION *session) {
    struct timeval timeout;
    int rc;
    fd_set fd;
    fd_set *writefd = NULL;
    fd_set *readfd = NULL;
    int dir;

    timeout.tv_sec = 10;
    timeout.tv_usec = 0;

    FD_ZERO(&fd);

    FD_SET(socket_fd, &fd);

    /* now make sure we wait in the correct direction */
    dir = libssh2_session_block_directions(session);

    if(dir & LIBSSH2_SESSION_BLOCK_INBOUND)
        readfd = &fd;

    if(dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        writefd = &fd;

    rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);

    return rc;
}

// -----------------------------------------------------------------------------
// INITIALIZATION
// -----------------------------------------------------------------------------

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username password:(NSString *)password error:(NSError **)error {
    NMSSH *ssh = [[NMSSH alloc] initWithHost:host username:username password:password publicKey:nil privateKey:nil];
    return [ssh connect:error] ? ssh : nil;
}

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey error:(NSError **)error {
    NMSSH *ssh = [[NMSSH alloc] initWithHost:host username:username password:nil publicKey:publicKey privateKey:privateKey];
    return [ssh connect:error] ? ssh : nil;
}

- (id)initWithHost:(NSString *)host username:(NSString *)username password:(NSString *)password publicKey:(NSString *)publicKey privateKey:(NSString *)priateKey {
    self = [super init];

    if (self) {
        // Set defaults from parameters
        _host = host;
        _port = [[NSNumber numberWithInt:22] retain];
        _username = username;
        _password = password;
        _publicKey = publicKey;
        _privateKey = priateKey;

        // Find out the ip address and port number from host
        NSMutableArray *hostParts = (NSMutableArray *)[host componentsSeparatedByString:@":"];
        if ([hostParts count] > 1) {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];

            NSNumber *port = [formatter numberFromString:[hostParts objectAtIndex:1]];
            if (port) {
                [_port release];
                _port = [port retain];
                _host = [hostParts objectAtIndex:0];
            }
        }
    }

    return self;
}

// -----------------------------------------------------------------------------
// HANDLE CONNECTIONS
// -----------------------------------------------------------------------------

- (BOOL)connect:(NSError **)error {
    // Determine host address
    NSString *host = [NMHostHelper isIp:_host] ? _host : [NMHostHelper ipFromDomainName:_host];

    hostaddr = inet_addr([host cStringUsingEncoding:NSUTF8StringEncoding]);
    sock = socket(AF_INET, SOCK_STREAM, 0);
    soin.sin_family = AF_INET;
    soin.sin_port = htons([_port intValue]);
    soin.sin_addr.s_addr = hostaddr;

    // Connect to socket
    if (connect(sock, (struct sockaddr*)(&soin),sizeof(struct sockaddr_in)) != 0) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to connect" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:100 userInfo:errorDetail];

        return NO;
    }

    // Create a session instance
    session = libssh2_session_init();
    if (!session) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to create a session instance" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:101 userInfo:errorDetail];

        return NO;
    }

    // Tell libssh2 we want it all done non-blocking
    libssh2_session_set_blocking(session, 0);

    // Start it up. This will trade welcome banners, exchange keys,
    // and setup crypto, compression, and MAC layers
    while ((rc = libssh2_session_startup(session, sock)) == LIBSSH2_ERROR_EAGAIN);
    if (rc) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:[NSString stringWithFormat:@"Failed establishing SSH session: %d", rc] forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:102 userInfo:errorDetail];

        return NO;
    }

    const char *username = [_username cStringUsingEncoding:NSUTF8StringEncoding];
    const char *password = [_password cStringUsingEncoding:NSUTF8StringEncoding];
    if ([_publicKey length] == 0) {
        // We could authenticate via password
        while ((rc = libssh2_userauth_password(session, username, password)) == LIBSSH2_ERROR_EAGAIN);
        if (rc) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Authentication by password failed" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"NMSSH" code:103 userInfo:errorDetail];

            return NO;
        }
    }
    else {
        // Or by public key
        while ((rc = libssh2_userauth_publickey_fromfile(session, username, [_publicKey cStringUsingEncoding:NSUTF8StringEncoding], [_privateKey cStringUsingEncoding:NSUTF8StringEncoding], password)) == LIBSSH2_ERROR_EAGAIN);
        if (rc) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Authentication by public key failed" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"NMSSH" code:100 userInfo:errorDetail];

            return NO;
        }
    }

    return YES;
}

- (void)disconnect {
    libssh2_session_disconnect(session, "Disconnect");
    libssh2_session_free(session);
    close(sock);
}

// -----------------------------------------------------------------------------
// EXECUTION
// -----------------------------------------------------------------------------

- (NSString *)execute:(NSString *)command error:(NSError **)error {
    NSString *result;

    // Exececute command non-blocking on the remote host
    while ( (channel = libssh2_channel_open_session(session)) == NULL && libssh2_session_last_error(session, NULL, NULL, 0) == LIBSSH2_ERROR_EAGAIN ) {
        waitsocket(sock, session);
    }

    if ( channel == NULL ) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"An error occured while opening a channel on the remote host" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:201 userInfo:errorDetail];
        return nil;
    }

    while ( (rc = libssh2_channel_exec(channel, [command cStringUsingEncoding:NSUTF8StringEncoding])) == LIBSSH2_ERROR_EAGAIN ) {
        waitsocket(sock, session);
    }

    if ( rc != 0 ) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"An error occured while executing command on remote server" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:100 userInfo:errorDetail];

        return nil;
    }

    for ( ;; ) {
        // Loop until we block
        int rc1;
        do {
            char buffer[0x2000];
            rc1 = libssh2_channel_read(channel, buffer, sizeof(buffer));
            if ( rc1 > 0 ) {
                result = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
            }
        }
        while ( rc1 > 0 );

        // This is due to blocking that would occur otherwise so we loop on
        // this condition
        if ( rc1 == LIBSSH2_ERROR_EAGAIN ) {
            waitsocket(sock, session);
        }
        else {
            break;
        }
    }

    while ( (rc = libssh2_channel_close(channel)) == LIBSSH2_ERROR_EAGAIN ) waitsocket(sock, session);

    libssh2_channel_free(channel);
    channel = NULL;

    return result;
}

// -----------------------------------------------------------------------------
// SCP
// -----------------------------------------------------------------------------

- (BOOL)uploadFile:(NSString *)localPath to:(NSString *)remotePath error:(NSError **)error {
    struct stat fileinfo;
    size_t nread;
    char mem[1024*100];
    char *ptr;
    size_t prev;

    // Read local file
    FILE *local = fopen([localPath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    if (!local) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:[NSString stringWithFormat:@"Can't read local file: %@", localPath] forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"NMSSH" code:401 userInfo:errorDetail];

        return NO;
    }

    // If remotePath is a directory, copy filename from localPath
    if ([remotePath hasSuffix:@"/"]) {
        remotePath = [remotePath stringByAppendingString:[[localPath componentsSeparatedByString:@"/"] lastObject]];
    }

    stat([localPath cStringUsingEncoding:NSUTF8StringEncoding], &fileinfo);

    // Send the file via SCP
    do {
        channel = libssh2_scp_send(session, [remotePath cStringUsingEncoding:NSUTF8StringEncoding], fileinfo.st_mode & 0777, (unsigned long)fileinfo.st_size);

        if ((!channel) && (libssh2_session_last_errno(session) != LIBSSH2_ERROR_EAGAIN)) {
            char *err_msg;
            libssh2_session_last_error(session, &err_msg, NULL, 0);

            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:[NSString stringWithCString:err_msg encoding:NSUTF8StringEncoding] forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"NMSSH" code:402 userInfo:errorDetail];

            return NO;
        }
    } while (!channel);

    do {
        nread = fread(mem, 1, sizeof(mem), local);
        if (nread <= 0) {
            // end of file
            break;
        }
        ptr = mem;

        prev = 0;
        do {
            while ((rc = libssh2_channel_write(channel, ptr, nread)) == LIBSSH2_ERROR_EAGAIN) {
                waitsocket(sock, session);
                prev = 0;
            }

            if (rc < 0) {
                break;
            }
            else {
                prev = nread;

                // rc indicates how many bytes were written this time
                nread -= rc;
                ptr += rc;
            }
        } while (nread);
    } while (!nread); // only continue if nread was drained

    // Sending EOF
    while (libssh2_channel_send_eof(channel) == LIBSSH2_ERROR_EAGAIN);

    // Waiting for EOF
    while (libssh2_channel_wait_eof(channel) == LIBSSH2_ERROR_EAGAIN);

    // Waiting for channel to close
    while (libssh2_channel_wait_closed(channel) == LIBSSH2_ERROR_EAGAIN);

    libssh2_channel_free(channel);
    channel = NULL;

    return YES;
}

- (BOOL)downloadFile:(NSString *)remotePath to:(NSString *)localPath error:(NSError **)error {
    int spin = 0;
    struct stat fileinfo;
    off_t got = 0;

    // If localPath is a directory, copy filename from remotePath
    if ([localPath hasSuffix:@"/"]) {
        localPath = [localPath stringByAppendingString:[[remotePath componentsSeparatedByString:@"/"] lastObject]];
    }

    int localFile = open([localPath cStringUsingEncoding:NSUTF8StringEncoding], O_WRONLY|O_CREAT, 0755);

    do {
        channel = libssh2_scp_recv(session, [remotePath cStringUsingEncoding:NSUTF8StringEncoding], &fileinfo);

        if (!channel) {
            if (libssh2_session_last_errno(session) == LIBSSH2_ERROR_EAGAIN) {
                waitsocket(sock, session);
            }
            else {
                char *err_msg;
                libssh2_session_last_error(session, &err_msg, NULL, 0);

                NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                [errorDetail setValue:[NSString stringWithCString:err_msg encoding:NSUTF8StringEncoding] forKey:NSLocalizedDescriptionKey];
                *error = [NSError errorWithDomain:@"NMSSH" code:301 userInfo:errorDetail];

                return NO;
            }
        }
    } while (!channel);

    // libssh2_scp_recv() is done, now receive data
    while (got < fileinfo.st_size) {
        char mem[1024*24];
        int rc;

        do {
            int amount = sizeof(mem);

            if ((fileinfo.st_size -got) < amount) {
                amount = fileinfo.st_size - got;
            }

            // Loop until we block
            rc = libssh2_channel_read(channel, mem, amount);

            if (rc > 0) {
                write(localFile, mem, rc);
                got += rc;
            }
        } while (rc > 0);

        if ((rc == LIBSSH2_ERROR_EAGAIN) && (got < fileinfo.st_size)) {
            // This is due to blocking that would occur otherwise
            // so we loop on this condition

            spin++;
            waitsocket(sock, session);
            continue;
        }

        break;
    }

    libssh2_channel_free(channel);
    channel = NULL;
    close(localFile);

    return YES;
}

// -----------------------------------------------------------------------------
// MEMORY STUFF
// -----------------------------------------------------------------------------

- (void)dealloc {
    [_host release];
    [_port release];
    [_username release];
    [_password release];
    [_privateKey release];
    [_publicKey release];

    [super dealloc];
}

@end
