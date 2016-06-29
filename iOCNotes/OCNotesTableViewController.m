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
#import "UIViewController+MMDrawerController.h"
#import <float.h>
#import "OCNote.h"
#import "KVNProgress.h"
#import "iOCNotes-Swift.h"

@interface OCNotesTableViewController  () <UISearchResultsUpdating, UISearchBarDelegate> {
    BOOL networkHasBeenUnreachable;
    NSArray *searchResults;
}

@property (strong, nonatomic) UISearchController *searchController;
@property (nonatomic, copy) NSArray *ocNotes;

@end

@implementation OCNotesTableViewController

@synthesize notesRefreshControl;
@synthesize editorViewController;
@synthesize menuActionSheet;
@synthesize addingNote;

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
        menuActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                      delegate:self
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"A menu action")
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:NSLocalizedString(@"Settings", @"A menu action"),
                                                               NSLocalizedString(@"Add Note", @"A menu action"), nil];
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
    self.addingNote = NO;
    
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
                                             selector:@selector(doRefresh:)
                                                 name:@"SyncNotes"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadNotes:)
                                               name:FCModelUpdateNotification
                                             object:OCNote.class];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteAdded:)
                                               name:FCModelInsertNotification
                                             object:OCNote.class];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteDeleted:)
                                               name:@"DeletingNote"
                                             object:nil];

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
    UINavigationController *navController = (UINavigationController*)self.mm_drawerController.centerViewController;
    self.editorViewController = (OCEditorViewController*)navController.topViewController;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    [self.searchController.searchBar sizeToFit];
    self.searchController.searchBar.tintColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.26 alpha:1.0];
    self.searchController.searchBar.barTintColor = [UIColor colorWithRed:0.957 green:0.957 blue:0.957 alpha:0.95];
    self.searchController.searchBar.backgroundImage = [UIImage new];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    [self.tableView setContentOffset:CGPointMake(0, self.searchController.searchBar.frame.size.height + self.tableView.contentOffset.y)];
    self.definesPresentationContext = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbar.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self didBecomeActive:nil];
    [self.editorViewController.noteView resignFirstResponder];
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
    self.ocNotes = [OCNote instancesWhere:@"deleteNeeded = 0 ORDER BY modified DESC"];
//    NSLog(@"Reloading with %lu notes", (unsigned long) self.ocNotes.count);
    NSIndexPath *currentSelection = [self.tableView indexPathForSelectedRow];
    [self.tableView reloadData];
    if (currentSelection && (self.ocNotes.count > 0)) {
        [self.tableView selectRowAtIndexPath:currentSelection animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    if (self.editorViewController) {
        if (self.editorViewController.ocNote) {
            NSInteger currentIndex = [self.ocNotes indexOfObject:self.editorViewController.ocNote];
            if (currentIndex >= 0) {
                [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
}

- (void)noteAdded:(NSNotification *)notification
{
    self.ocNotes = [OCNote instancesWhere:@"deleteNeeded = 0 ORDER BY modified DESC"];
    [self.tableView reloadData];
//    NSLog(@"Note added: %@", [notification userInfo]);
    NSSet *noteSet = [[notification userInfo] objectForKey:FCModelInstanceSetKey];
    OCNote *newNote = [noteSet anyObject];
    if (self.addingNote) {
        if (!self.refreshControl.refreshing) {
            [self.mm_drawerController closeDrawerAnimated:YES completion:^(BOOL finished) {
                //
            }];
        }
    }
    self.addingNote = NO;
    if (!self.editorViewController.noteView.isFirstResponder)
    {
        self.editorViewController.ocNote = newNote;
        if (self.ocNotes.count) {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
        }
    }
}

- (void)noteDeleted:(NSNotification *)notification
{
    if (self.editorViewController) {
        if (self.editorViewController.ocNote) {
            NSInteger currentIndex = [self.ocNotes indexOfObject:self.editorViewController.ocNote];
            if (currentIndex >= 0) {
                [self tableView:self.tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:[NSIndexPath indexPathForRow:currentIndex inSection:0]];
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
    if (self.searchController.active) {
        return searchResults.count;
    } else {
        return self.ocNotes.count;
    }
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
    NSUInteger noteCount;
    if (self.searchController.active) {
        noteCount = searchResults.count;
    } else {
        noteCount = self.ocNotes.count;
    }
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    UIView * selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    [selectedBackgroundView setBackgroundColor:[UIColor colorWithRed:0.87f green:0.87f blue:0.87f alpha:1.0f]]; // set color here
    [cell setSelectedBackgroundView:selectedBackgroundView];
    cell.tag = indexPath.row;
    
    if ((noteCount > 0) && (indexPath.row <= noteCount - 1)) {
        OCNote *note;
        if (self.searchController.active) {
            note = [searchResults objectAtIndex:indexPath.row];
        } else {
            note = [self.ocNotes objectAtIndex:indexPath.row];
        }
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
        [tableView beginUpdates];
        NSInteger currentNoteCount = self.ocNotes.count;
        OCNote *note = nil;
        if (self.searchController.active) {
            if ((indexPath.row >= 0) && (indexPath.row < searchResults.count)) {
                note = [searchResults objectAtIndex:indexPath.row];
            }
        } else {
            if ((indexPath.row >= 0) && (indexPath.row < self.ocNotes.count)) {
                note = [self.ocNotes objectAtIndex:indexPath.row];
            }
        }
        if ([note isEqual:self.editorViewController.ocNote]) {
            self.editorViewController.ocNote = nil;
        }
        if (note) {
            [[OCNotesHelper sharedHelper] deleteNote:note];
        }
        self.ocNotes = [OCNote instancesWhere:@"deleteNeeded = 0 ORDER BY modified DESC"];
        NSInteger newCount = self.ocNotes.count;
        if (newCount + 1 == currentNoteCount) {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        NSInteger newIndex = 0;
        if (indexPath.row >= 0) {
            newIndex = indexPath.row;
        }
        if (newIndex >= self.ocNotes.count) {
            --newIndex;
        }
        [tableView endUpdates];

        if (newIndex >= 0) {
            OCNote *newNote = [self.ocNotes objectAtIndex:newIndex];
            self.editorViewController.ocNote = newNote;
            dispatch_async(dispatch_get_main_queue(), ^{
                [tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:newIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            });
        } else {
            self.editorViewController.ocNote = nil;
        }
        if (self.mm_drawerController.openSide == MMDrawerSideNone) {
            //called while showing editor
            [self.tableView reloadData];
        }
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


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger noteCount;
    if (self.searchController.active) {
        noteCount = searchResults.count;
    } else {
        noteCount = self.ocNotes.count;
    }
    if ((noteCount > 0) && (indexPath.row <= noteCount - 1)) {
        OCNote *note = nil;
        if (self.searchController.active) {
            note = [searchResults objectAtIndex:indexPath.row];
        } else {
            note = [self.ocNotes objectAtIndex:indexPath.row];
        }
        [[OCNotesHelper sharedHelper] getNote:note];
        self.editorViewController.ocNote = note;
        [self.mm_drawerController closeDrawerAnimated:YES completion:nil];
        if ([OCNotesHelper isOnline]) {
            [KVNProgress show];
        }
    }
}

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"TRUEPREDICATE"];;
    if ((searchText) && [searchText length] > 0) {
        resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    searchResults = [self.ocNotes filteredArrayUsingPredicate:resultPredicate];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *searchString = searchController.searchBar.text;
    [self filterContentForSearchText:searchString scope:nil];
    [self.tableView reloadData];
}

- (IBAction)doRefresh:(id)sender {
    if (!self.refreshControl.refreshing) {
        [self.refreshControl beginRefreshing];
        [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y - self.refreshControl.frame.size.height) animated:YES];
    }
    self.addBarButton.enabled = NO;
    self.settingsBarButton.enabled = NO;
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
    self.addingNote = YES;
    self.editorViewController.addingNote = YES;
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
        [TSMessage showNotificationInViewController:self.parentViewController
                                              title:NSLocalizedString( @"Unable to Reach Server", @"A message title")
                                           subtitle:NSLocalizedString(@"Please check network connection and login.", @"A message")
                                               type:TSMessageNotificationTypeWarning];
    }
    if (status > AFNetworkReachabilityStatusNotReachable) {
        if (networkHasBeenUnreachable) {
            [TSMessage showNotificationInViewController:self.parentViewController
                                                  title:NSLocalizedString(@"Server Reachable", @"A message title")
                                               subtitle:NSLocalizedString(@"The network connection is working properly.", @"A message") 
                                                   type:TSMessageNotificationTypeSuccess];
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
    [KVNProgress dismiss];
    [self.refreshControl endRefreshing];
    self.addBarButton.enabled = YES;
    self.settingsBarButton.enabled = YES;
}

- (void)networkError:(NSNotification *)n {
    [KVNProgress dismiss];
    [self.refreshControl endRefreshing];
    self.addBarButton.enabled = YES;
    self.settingsBarButton.enabled = YES;
    [TSMessage showNotificationInViewController:self.navigationController.topViewController
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
