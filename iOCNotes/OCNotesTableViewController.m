//
//  OCNotesTableViewController.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCNotesTableViewController.h"
#import "OCEditorViewController.h"
#import "OCAPIClient.h"
#import "OCNotesHelper.h"
#import "OCLoginController.h"
#import "TSMessage.h"
#import "UIViewController+ECSlidingViewController.h"
#import <float.h>
#import "OCNote.h"

@interface OCNotesTableViewController () {
    BOOL networkHasBeenUnreachable;
}

@property (nonatomic, copy) NSArray *ocNotes;

@end

@implementation OCNotesTableViewController

@synthesize notesRefreshControl;
@synthesize editorViewController;
@synthesize menuActionSheet;

- (UIRefreshControl *)notesRefreshControl {
    if (!notesRefreshControl) {
        notesRefreshControl = [[UIRefreshControl alloc] init];
        notesRefreshControl.tintColor = [UIColor colorWithRed:0.13 green:0.145 blue:0.16 alpha:1.0];
        [notesRefreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    }
    return notesRefreshControl;
}

- (UIActionSheet*)menuActionSheet {
    if (!menuActionSheet) {
        menuActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Settings", @"Add Note", nil];
    }
    return menuActionSheet;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    networkHasBeenUnreachable = NO;
    self.refreshControl = self.notesRefreshControl;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:AFNetworkingReachabilityDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkSuccess:)
                                                 name:@"NetworkSuccess"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkError:)
                                                 name:@"NetworkError"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadNotes:)
                                               name:FCModelAnyChangeNotification
                                             object:OCNote.class];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteAdded:)
                                               name:FCModelInsertNotification
                                             object:OCNote.class];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteDeleted:)
                                               name:FCModelDeleteNotification
                                             object:OCNote.class];
  
    [OCNotesHelper sharedHelper];
    [self reloadNotes:nil];
    
    //remove bottom line/shadow
    for (UIView *view in self.navigationController.navigationBar.subviews) {
        for (UIView *view2 in view.subviews) {
            if ([view2 isKindOfClass:[UIImageView class]]) {
                if (![view2.superview isKindOfClass:[UIButton class]]) {
                    [view2 removeFromSuperview];
                }
            }
        }
    }
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.toolbar.translucent = YES;
    self.navigationController.toolbar.clipsToBounds = YES;
    self.navigationItem.titleView = self.titleButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbar.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self didBecomeActive:nil];
    [self.editorViewController.noteContentView resignFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.toolbar.hidden = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadNotes:(NSNotification *)notification
{
    self.ocNotes = [OCNote instancesOrderedBy:@"modified DESC"];
    NSLog(@"Reloading with %lu notes", (unsigned long) self.ocNotes.count);
    [self.tableView reloadData];
}

- (void)noteAdded:(NSNotification *)notification
{
    NSLog(@"Note added: %@", [notification userInfo]);
    NSSet *noteSet = [[notification userInfo] objectForKey:FCModelInstanceSetKey];
    OCNote *newNote = [noteSet anyObject];
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        [self.slidingViewController resetTopViewAnimated:YES];
    } else {
        if ([self.navigationController.topViewController isEqual:self]) {
            [self performSegueWithIdentifier:@"noteSelected" sender:self];
        }
    }
    self.editorViewController.ocNote = newNote;
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
}

- (void)noteDeleted:(NSNotification *)notification
{
    NSInteger newIndex = 0;
    NSLog(@"Note added: %@", [notification userInfo]);
    NSSet *noteSet = [[notification userInfo] objectForKey:FCModelInstanceSetKey];
    OCNote *newNote = [noteSet anyObject];
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        //[self.slidingViewController resetTopViewAnimated:YES];
    } else {
        if ([self.navigationController.topViewController isEqual:self.editorViewController]) {
            newIndex = [self.ocNotes indexOfObject:newNote] + 1;
            if (newIndex >= self.ocNotes.count) {
                --newIndex;
                --newIndex;
            }
            if (newIndex >= 0) {
                newNote = [self.ocNotes objectAtIndex:newIndex];
                self.editorViewController.ocNote = newNote;
                [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:newIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
    }
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self name:FCModelAnyChangeNotification object:OCNote.class];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //return [self.notesFetchedResultsController fetchedObjects].count;
    return self.ocNotes.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static UILabel* labelTitle;
    if (!labelTitle) {
        labelTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, FLT_MAX, FLT_MAX)];
        labelTitle.text = @"test";
    }
    labelTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [labelTitle sizeToFit];
    CGFloat height1 = labelTitle.frame.size.height;
    
    static UILabel* labelSubTitle;
    if (!labelSubTitle) {
        labelSubTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, FLT_MAX, FLT_MAX)];
        labelSubTitle.text = @"test";
    }
    labelSubTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    [labelSubTitle sizeToFit];
    CGFloat height2 = labelSubTitle.frame.size.height;

    return (height1 + height2) * 1.7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    UIView * selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    [selectedBackgroundView setBackgroundColor:[UIColor colorWithRed:0.87f green:0.87f blue:0.87f alpha:1.0f]]; // set color here
    [cell setSelectedBackgroundView:selectedBackgroundView];
    cell.tag = indexPath.row;
    OCNote *note = [self.ocNotes objectAtIndex:indexPath.row];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.textLabel.text = note.title;
    cell.backgroundColor = [UIColor clearColor];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:note.modified];
    if (date) {
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        dateFormat.dateStyle = NSDateFormatterShortStyle;
        dateFormat.timeStyle = NSDateFormatterNoStyle;
        dateFormat.doesRelativeDateFormatting = YES;
        cell.detailTextLabel.text = [dateFormat stringFromDate:date];
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    }
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OCNote *note = [self.ocNotes objectAtIndex:indexPath.row];
        if ([note isEqual:self.editorViewController.ocNote]) {
            self.editorViewController.ocNote = nil;
        }
        [[OCNotesHelper sharedHelper] deleteNote:note];
    }
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}


#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"noteSelected"]) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            self.editorViewController = (OCEditorViewController*)segue.destinationViewController;
        } else {
            UINavigationController *navController = (UINavigationController*)segue.destinationViewController;
            self.editorViewController = (OCEditorViewController*)navController.topViewController;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        //[self showRenameForIndex:indexPath.row];
    } else {
        OCNote *note = [self.ocNotes objectAtIndex:indexPath.row];
        [[OCNotesHelper sharedHelper] getNote:note];
        self.editorViewController.ocNote = note;
        if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
            [self.slidingViewController resetTopViewAnimated:YES];
        }
    }
}

- (IBAction)doRefresh:(id)sender {
    [[OCNotesHelper sharedHelper] sync];
}

- (IBAction)doMenu:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.menuActionSheet showFromBarButtonItem:sender animated:YES];
    } else {
        [self.menuActionSheet showInView:self.view];
    }
}

- (IBAction)doAdd:(id)sender {
    [[OCNotesHelper sharedHelper] addNote:@""];
}

- (IBAction)onTitleButton:(id)sender {
    [[UIApplication sharedApplication] openURL:[[OCAPIClient sharedClient] baseURL]];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([actionSheet isEqual:self.menuActionSheet]) {
        switch (buttonIndex) {
            case 0:
                [self doSettings:self.menuActionSheet];
                break;
            case 1:
                [[OCNotesHelper sharedHelper] addNote:@""];
                break;
            default:
                break;
        }
    }
}

- (IBAction)doSettings:(id)sender {
    UIStoryboard *storyboard;
    UINavigationController *nav;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        storyboard = [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    }
    if ([sender isEqual:self.menuActionSheet] || [sender isEqual:self.settingsBarButton]) {
        nav = [storyboard instantiateViewControllerWithIdentifier:@"login"];
    } else {
        OCLoginController *lc = [storyboard instantiateViewControllerWithIdentifier:@"server"];
        nav = [[UINavigationController alloc] initWithRootViewController:lc];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)reachabilityChanged:(NSNotification *)n {
    NSNumber *s = n.userInfo[AFNetworkingReachabilityNotificationStatusItem];
    AFNetworkReachabilityStatus status = [s integerValue];
    
    if (status == AFNetworkReachabilityStatusNotReachable) {
        networkHasBeenUnreachable = YES;
        [TSMessage showNotificationInViewController:self.parentViewController title:@"Unable to Reach Server" subtitle:@"Please check network connection and login." type:TSMessageNotificationTypeWarning];
    }
    if (status > AFNetworkReachabilityStatusNotReachable) {
        if (networkHasBeenUnreachable) {
            [TSMessage showNotificationInViewController:self.parentViewController title:@"Server Reachable" subtitle:@"The network connection is working properly." type:TSMessageNotificationTypeSuccess];
            networkHasBeenUnreachable = NO;
        }
    }
}

- (void) didBecomeActive:(NSNotification *)n {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"Server"].length == 0) {
        [self doSettings:nil];
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SyncOnStart"]) {
            [[OCNotesHelper sharedHelper] performSelector:@selector(sync) withObject:nil afterDelay:1.0f];
        }
    }
}

- (void) networkSuccess:(NSNotification *)n {
    [self.refreshControl endRefreshing];
}

- (void)networkError:(NSNotification *)n {
    [self.refreshControl endRefreshing];
    [TSMessage showNotificationInViewController:self
                                          title:[n.userInfo objectForKey:@"Title"]
                                       subtitle:[n.userInfo objectForKey:@"Message"]
                                          image:nil
                                           type:TSMessageNotificationTypeError
                                       duration:TSMessageNotificationDurationAutomatic
                                       callback:nil
                                    buttonTitle:nil
                                 buttonCallback:nil
                                     atPosition:TSMessageNotificationPositionTop
                           canBeDismissedByUser:YES];
}

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    [self.tableView reloadData];
}

@end
