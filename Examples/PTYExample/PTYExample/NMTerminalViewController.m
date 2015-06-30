#import "NMTerminalViewController.h"
#import <NMSSH/NMSSH.h>

@interface NMTerminalViewController () <NMSSHSessionDelegate, NMSSHChannelDelegate>

@property (nonatomic, strong) dispatch_queue_t sshQueue;
@property (nonatomic, strong) NMSSHSession *session;
@property (nonatomic, assign) dispatch_once_t onceToken;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSMutableString *lastCommand;
@property (nonatomic, assign) BOOL keyboardInteractive;

@end

@implementation NMTerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.keyboardInteractive = self.password == nil;

    self.textView.editable = NO;
    self.textView.selectable = NO;
    self.lastCommand = [[NSMutableString alloc] init];

    self.sshQueue = dispatch_queue_create("NMSSH.queue", DISPATCH_QUEUE_SERIAL);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    dispatch_once(&_onceToken, ^{
        [self connect:self];
    });
}

- (IBAction)connect:(id)sender {
    dispatch_async(self.sshQueue, ^{
        self.session = [NMSSHSession connectToHost:self.host withUsername:self.username];
        self.session.delegate = self;

        if (!self.session.connected) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendToTextView:@"Connection error"];
            });

            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendToTextView:[NSString stringWithFormat:@"ssh %@@%@\n", self.session.username, self.host]];
        });

        if (self.keyboardInteractive) {
            [self.session authenticateByKeyboardInteractive];
        }
        else {
            [self.session authenticateByPassword:self.password];
        }

        if (!self.session.authorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendToTextView:@"Authentication error\n"];
                self.textView.editable = NO;
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.textView.editable = YES;
            });

            self.session.channel.delegate = self;
            self.session.channel.requestPty = YES;

            NSError *error;
            [self.session.channel startShell:&error];

            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self appendToTextView:error.localizedDescription];
                    self.textView.editable = NO;
                });
            }
        }
    });

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.textView resignFirstResponder];
}

- (IBAction)disconnect:(id)sender {
    dispatch_async(self.sshQueue, ^{
        [self.session disconnect];
    });
}

- (void)appendToTextView:(NSString *)text {
    self.textView.text = [NSString stringWithFormat:@"%@%@", self.textView.text, text];
    [self.textView scrollRangeToVisible:NSMakeRange([self.textView.text length] - 1, 1)];
}

- (void)performCommand {
    if (self.semaphore) {
        self.password = [self.lastCommand substringToIndex:MAX(0, self.lastCommand.length - 1)];
        dispatch_semaphore_signal(self.semaphore);
    }
    else {
        NSString *command = [self.lastCommand copy];
        dispatch_async(self.sshQueue, ^{
            [[self.session channel] write:command error:nil timeout:@10];
        });
    }

    [self.lastCommand setString:@""];
}

- (void)channel:(NMSSHChannel *)channel didReadData:(NSString *)message {
    NSString *msg = [message copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendToTextView:msg];
    });
}

- (void)channel:(NMSSHChannel *)channel didReadError:(NSString *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendToTextView:[NSString stringWithFormat:@"[ERROR] %@", error]];
    });
}

- (void)channelShellDidClose:(NMSSHChannel *)channel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendToTextView:@"\nShell closed\n"];
        self.textView.editable = NO;
    });
}

- (NSString *)session:(NMSSHSession *)session keyboardInteractiveRequest:(NSString *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendToTextView:request];
        self.textView.editable = YES;
    });

    self.semaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    self.semaphore = nil;

    return self.password;
}

- (void)session:(NMSSHSession *)session didDisconnectWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendToTextView:[NSString stringWithFormat:@"\nDisconnected with error: %@", error.localizedDescription]];

        self.textView.editable = NO;
    });
}

- (void)textViewDidChange:(UITextView *)textView {
    [textView scrollRangeToVisible:NSMakeRange([textView.text length] - 1, 1)];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    if (textView.selectedRange.location < textView.text.length - self.lastCommand.length - 1) {
        textView.selectedRange = NSMakeRange([textView.text length], 0);
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (text.length == 0) {

        if ([self.lastCommand length] > 0) {
            [self.lastCommand replaceCharactersInRange:NSMakeRange(self.lastCommand.length-1, 1) withString:@""];
            return YES;
        }
        else {
            return NO;
        }
    }

    [self.lastCommand appendString:text];
    
    if ([text isEqualToString:@"\n"]) {
        [self performCommand];
    }

    return YES;
}

- (void)keyboardWillShow:(NSNotification *)notification {
	NSDictionary *userInfo = [notification userInfo];
	CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];

	CGRect ownFrame = [[[[UIApplication sharedApplication] delegate] window] convertRect:self.textView.frame fromView:self.textView.superview];

	CGRect coveredFrame = CGRectIntersection(ownFrame, keyboardFrame);
	coveredFrame = [[[[UIApplication sharedApplication] delegate] window] convertRect:coveredFrame toView:self.textView.superview];

	self.textView.contentInset = UIEdgeInsetsMake(self.textView.contentInset.top, 0, coveredFrame.size.height, 0);
	self.textView.scrollIndicatorInsets = self.textView.contentInset;
}

- (void)keyboardWillHide:(NSNotification *)notification {
	self.textView.contentInset = UIEdgeInsetsMake(self.textView.contentInset.top, 0, 0, 0);
	self.textView.scrollIndicatorInsets = self.textView.contentInset;
}

@end
