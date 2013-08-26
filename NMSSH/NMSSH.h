#import "libssh2.h"
#import "libssh2_sftp.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

#define kNMSSHBufferSize (5*1024*1024)

@class NMSSHSession, NMSSHChannel, NMSFTP;

#import "NMSSHSession.h"
#import "NMSSHChannel.h"
#import "NMSFTP.h"