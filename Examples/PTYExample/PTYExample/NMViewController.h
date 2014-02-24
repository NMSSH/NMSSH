//
//  NMViewController.h
//  PTYExample
//
//  Created by Tommaso Madonia on 24/02/14.
//  Copyright (c) 2014 Nine Muses. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NMViewController : UIViewController

@property (nonatomic) IBOutlet UITextField *hostField;
@property (nonatomic) IBOutlet UITextField *usernameField;
@property (nonatomic) IBOutlet UITextField *passwordField;
@property (nonatomic) IBOutlet UISegmentedControl *authenticationControl;

- (IBAction)login:(id)sender;
- (IBAction)authentication:(id)sender;

@end
