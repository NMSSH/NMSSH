#import <UIKit/UIKit.h>

@interface NMTerminalViewController : UIViewController <UITextViewDelegate>

@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic) IBOutlet UITextView *textView;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
