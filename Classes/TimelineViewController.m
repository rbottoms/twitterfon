#import <QuartzCore/QuartzCore.h>
#import "TimelineViewController.h"
#import "TwitterFonAppDelegate.h"
#import "MessageCell.h"
#import "ColorUtils.h"

#define kAnimationKey @"transitionViewAnimation"

@interface NSObject (TimelineViewControllerDelegate)
- (void)postTweetDidSucceed:(Message*)message;
@end

@implementation TimelineViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		// Initialization code
	}
    
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    tag = [self navigationController].tabBarItem.tag;
	username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    switch (tag) {
        case TAB_FRIENDS:
            self.tableView.separatorColor = [UIColor friendColorBorder];
            break;
            
        case TAB_REPLIES:
            self.tableView.separatorColor =  [UIColor repliesColorBorder];
            self.tableView.backgroundColor = [UIColor repliesColor];
            break;
            
        case TAB_MESSAGES:
            self.tableView.separatorColor =  [UIColor messageColorBorder];
            self.tableView.backgroundColor = [UIColor messageColor];
            [timeline update:MSG_TYPE_MESSAGES];
    }

    [timeline restore:tag];
    [timeline update:tag];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (void)viewDidDisappear:(BOOL)animated 
{
    [self navigationController].tabBarItem.badgeValue = nil;
    for (int i = 0; i < [timeline countMessages]; ++i) {
        Message* m = [timeline messageAtIndex:i];
        m.unread = false;
    }
}

- (void) loadTimeline
{
    [timeline restore:tag];
    if (tag != MSG_TYPE_MESSAGES) {
        [timeline update:tag];
    }
}

- (id)initWithStyle:(UITableViewStyle)style
{
	if (self = [super initWithStyle:style]) {
	}
	return self;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [timeline countMessages];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString* MyIdentifier = @"MessageCell";
	
	MessageCell* cell = (MessageCell*)[tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	Message* m = [timeline messageAtIndex:indexPath.row];
	if (!cell) {
		cell = [[[MessageCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
	}
	cell.message = m;
    cell.image = [imageStore getImage:m.user delegate:self];

    if (tag == TAB_FRIENDS) {
        NSString *str = [NSString stringWithFormat:@"@%@", username];
        NSRange r = [m.text rangeOfString:str];
        if (r.location != NSNotFound) {
            cell.contentView.backgroundColor = [UIColor repliesColor:m.unread];
        }
        else {
            cell.contentView.backgroundColor = [UIColor friendColor:m.unread];
        }
    }
    else if (tag == TAB_REPLIES) {
        cell.contentView.backgroundColor = [UIColor repliesColor:m.unread];
    }
    else if (tag == TAB_MESSAGES) {
        cell.contentView.backgroundColor = [UIColor messageColor:m.unread];
    }
    
	[cell update];
    
	return cell;
}

- (void)dealloc {
	[super dealloc];
}

- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning];
}

- (void) showPostView:(PostViewController*)postView
{
	CATransition *animation = [CATransition animation];
    [animation setDelegate:self];
    [animation setType:kCATransitionMoveIn];
    [animation setSubtype:kCATransitionFromBottom];
	[animation setDuration:0.5];
	[animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[[postView.view layer] addAnimation:animation forKey:kAnimationKey];
}

- (IBAction) post: (id) sender
{
    TwitterFonAppDelegate *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
    PostViewController* postView = appDelegate.postView;

    [[self navigationController].view addSubview:postView.view];
    [postView startEditWithDelegate:self];
    [self showPostView:postView];
}

- (IBAction) reload: (id) sender
{
}


//
// UITableViewDelegate
//
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect bounds;
    CGRect result;
    UILabel *textLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    Message *m = [timeline messageAtIndex:indexPath.row];
    
    textLabel.font = [UIFont systemFontOfSize:13];
    textLabel.numberOfLines = 10;
    
    textLabel.text = m.text;
    bounds = CGRectMake(0, 0, 240, 200);
    result = [textLabel textRectForBounds:bounds limitedToNumberOfLines:10];
    result.size.height += 18;
    if (result.size.height < 48 + 1) result.size.height = 48 + 1;
    [textLabel release];
    return result.size.height;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  	Message* m = [timeline messageAtIndex:indexPath.row];
    
    TwitterFonAppDelegate *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
    PostViewController* postView = appDelegate.postView;
    
    if (postView.view.hidden == false) return;

    NSString *msg;
    if (tag == MSG_TYPE_MESSAGES) {
        msg = [NSString stringWithFormat:@"d %@ ", m.user.screenName];
    }
    else {
        msg = [NSString stringWithFormat:@"@%@ ", m.user.screenName];
    }

    [[self navigationController].view addSubview:postView.view];
    [postView startEditWithString:msg setDelegate:self];

    [self showPostView:postView];

}

- (void)postViewAnimationDidStart
{
    [[self navigationController] setNavigationBarHidden:FALSE animated:YES];
}

- (void)postViewAnimationDidFinish:(BOOL)didPost
{
    if (didPost && tag == TAB_FRIENDS) {
        //
        // Do animation if the controller displays friends timeline.
        //
        NSArray *indexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:0 inSection:0], nil];
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView endUpdates];
    }
}

- (void)postTweetDidSucceed:(Message*)message
{
    if (tag == TAB_FRIENDS) {
        [timeline insertMessage:message];
    }
    else if (tag == TAB_REPLIES) {
        //
        //  If the controller doesn't handle friends timeline, pass the message to app delegate then
        // app delegate passes the message to friends timeline view controller.
        //
        // If the view controller is direct messages, do nothing.
        //
        NSObject *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
        if (appDelegate && [appDelegate respondsToSelector:@selector(postTweetDidSucceed:)]) {
            [appDelegate postTweetDidSucceed:message];
        }
    }
}

//
// UITabBarControllerDelegate
//
- (void)tabBarController:(UITabBarController *)tabBar didSelectViewController:(UIViewController *)viewController
{
}

//
// ImageStoreDelegate
//
- (void)imageStoreDidGetNewImage:(UIImage*)image
{
	[self.tableView reloadData];
}

//
// TimelineDownloaderDelegate
//
- (void)timelineDidReceiveNewMessage:(Timeline*)sender message:(Message*)msg
{
	[imageStore getImage:msg.user delegate:self];
}

- (void)timelineDidUpdate:(Timeline*)sender indexPaths:(NSArray*)indexPaths
{
    [self navigationController].tabBarItem.badgeValue = [NSString stringWithFormat:@"%d", [indexPaths count]];
    if (!self.view.hidden) {
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView endUpdates];    
    }
}
@end
