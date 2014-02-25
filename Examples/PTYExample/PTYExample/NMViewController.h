#import <UIKit/UIKit.h>

@interface NMViewController : UIViewController

@property (nonatomic) IBOutlet UITextField *hostField;
@property (nonatomic) IBOutlet UITextField *usernameField;
@property (nonatomic) IBOutlet UITextField *passwordField;
@property (nonatomic) IBOutlet UISegmentedControl *authenticationControl;

- (IBAction)login:(id)sender;
- (IBAction)authentication:(id)sender;

@end
