/**
 * Protocol for registering to receive messages from an active NMSSHSession.
 */
@protocol NMSSHSessionDelegate <NSObject>
@optional

/**
 * Called when the session is setup to use keyboard interactive authentication,
 * and the server is asking for a password.
 *
 * @param session The session that is asking
 * @param request Server request
 * @returns A valid password for the session's user
 */
- (NSString *)session:(NMSSHSession *)session keyboardInteractiveRequest:(NSString *)request;

/**
 * Called when a session has failed and disconnected.
 *
 * @param session The session that was disconnected
 * @param error A description of the error that caused the disconnect
 */
- (void)session:(NMSSHSession *)session didDisconnectWithError:(NSError *)error;

@end