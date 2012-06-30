#import <Foundation/Foundation.h>

@class NMSSHSession;

enum {
    NMSSHChannelExecutionError,
    NMSSHChannelExecutionResponseError
};

/**
 * NMSSHChannel provides functionality to work with SSH shells and SCP.
 */
@interface NMSSHChannel : NSObject

/** A valid NMSSHSession instance */
@property (nonatomic, readonly) NMSSHSession *session;

/** The last response from a shell command execution */
@property (nonatomic, readonly) NSString *lastResponse;

/**
 * Create a new NMSSHChannel instance and open a channel on the provided
 * session.
 *
 * aSession needs to be a valid, connected, NMSSHSession instance!
 *
 * @returns New NMSSHChannel instance
 */
- (id)initWithSession:(NMSSHSession *)aSession;

/**
 * Close and cleanup the channel
 */
- (void)close;

/**
 * Execute a shell command on the server.
 *
 * If an error occurs, it will return nil and populate the error object.
 *
 * @returns Shell command response
 */
- (NSString *)execute:(NSString *)command error:(NSError **)error;

@end
