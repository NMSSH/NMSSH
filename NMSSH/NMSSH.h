#import "libssh2.h"
#import "libssh2_sftp.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

@class NMSSHSession, NMSSHChannel, NMSFTP;

#import "NMSSHSession.h"
#import "NMSSHChannel.h"
#import "NMSFTP.h"