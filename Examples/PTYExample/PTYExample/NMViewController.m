#import "NMViewController.h"
#import "NMTerminalViewController.h"

@interface NMViewController ()

@end

@implementation NMViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.hostField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"host"];
    self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    self.authenticationControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"auth"];
}

- (IBAction)hostend:(id)sender {
    [self.hostField resignFirstResponder];
}

- (IBAction)usernameend:(id)sender {
    [self.usernameField resignFirstResponder];
}

- (IBAction)passwordend:(id)sender {
    [self.passwordField resignFirstResponder];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.hostField resignFirstResponder];
    [self.usernameField resignFirstResponder];
    [self.passwordField resignFirstResponder];
}

- (IBAction)authentication:(id)sender {
    self.passwordField.enabled = self.authenticationControl.selectedSegmentIndex == 0;
}

- (IBAction)login:(id)sender {
    if (self.hostField.text.length == 0 || self.usernameField.text.length == 0 || (self.authenticationControl.selectedSegmentIndex == 0 && self.passwordField.text.length == 0)) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"All fields are required!"
                                                           delegate:Nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
    else {
        [self performSegueWithIdentifier:@"loginSegue" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"loginSegue"]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.hostField.text forKey:@"host"];
        [[NSUserDefaults standardUserDefaults] setObject:self.usernameField.text forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] setObject:@(self.authenticationControl.selectedSegmentIndex) forKey:@"auth"];

        NMTerminalViewController *terminalController = [segue destinationViewController];

        terminalController.host = self.hostField.text;
        terminalController.username = self.usernameField.text;

        if (self.authenticationControl.selectedSegmentIndex == 0) {
            terminalController.password = self.passwordField.text;
        }
        else {
            terminalController.password = nil;
        }
    }
}

@end
