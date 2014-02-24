//
//  NMViewController.m
//  PTYExample
//
//  Created by Tommaso Madonia on 24/02/14.
//  Copyright (c) 2014 Nine Muses. All rights reserved.
//

#import "NMViewController.h"
#import "NMTerminalViewController.h"

@interface NMViewController ()

@end

@implementation NMViewController

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
