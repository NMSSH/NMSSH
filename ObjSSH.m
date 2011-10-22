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

#import "ObjSSH.h"

#import "libssh2.h"
#include <sys/socket.h>
#include <arpa/inet.h>

@implementation ObjSSH

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
    ObjSSH *ssh = [[ObjSSH alloc] initWithHost:host username:username password:password publicKey:nil privateKey:nil];
    return [ssh connect:error] ? ssh : nil;
}

+ (id)connectToHost:(NSString *)host withUsername:(NSString *)username publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey error:(NSError **)error {
    ObjSSH *ssh = [[ObjSSH alloc] initWithHost:host username:username password:nil publicKey:publicKey privateKey:privateKey];
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
    hostaddr = inet_addr([_host cStringUsingEncoding:NSUTF8StringEncoding]);
    sock = socket(AF_INET, SOCK_STREAM, 0);
    soin.sin_family = AF_INET;
    soin.sin_port = htons([_port intValue]);
    soin.sin_addr.s_addr = hostaddr;

    // Connect to socket
    if (connect(sock, (struct sockaddr*)(&soin),sizeof(struct sockaddr_in)) != 0) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to connect" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"ObjSSH" code:100 userInfo:errorDetail];

        return NO;
    }

    // Create a session instance
    session = libssh2_session_init();
    if (!session) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to create a session instance" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"ObjSSH" code:101 userInfo:errorDetail];

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
        *error = [NSError errorWithDomain:@"ObjSSH" code:102 userInfo:errorDetail];

        return NO;
    }

    const char *username = [_username cStringUsingEncoding:NSUTF8StringEncoding];
    const char *password = [_password cStringUsingEncoding:NSUTF8StringEncoding];
    if (strlen(password) > 0) {
        // We could authenticate via password
        while ((rc = libssh2_userauth_password(session, username, password)) == LIBSSH2_ERROR_EAGAIN);
        if (rc) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Authentication by password failed" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"ObjSSH" code:103 userInfo:errorDetail];

            return NO;
        }
    }
    else {
        // Or by public key
        while ((rc = libssh2_userauth_publickey_fromfile(session, username, [_publicKey cStringUsingEncoding:NSUTF8StringEncoding], [_privateKey cStringUsingEncoding:NSUTF8StringEncoding], password)) == LIBSSH2_ERROR_EAGAIN);
        if (rc) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Authentication by public key failed" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"ObjSSH" code:100 userInfo:errorDetail];

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
        *error = [NSError errorWithDomain:@"ObjSSH" code:201 userInfo:errorDetail];
        return nil;
    }

    while ( (rc = libssh2_channel_exec(channel, [command cStringUsingEncoding:NSUTF8StringEncoding])) == LIBSSH2_ERROR_EAGAIN ) {
        waitsocket(sock, session);
    }

    if ( rc != 0 ) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"An error occured while executing command on remote server" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"ObjSSH" code:100 userInfo:errorDetail];
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
