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
#import "Note.h"
#import "TSMessage.h"
#import "UIViewController+ECSlidingViewController.h"

@interface OCNotesTableViewController () {
    BOOL networkHasBeenUnreachable;
}

@end

@implementation OCNotesTableViewController

@synthesize notesFetchedResultsController;
@synthesize notesRefreshControl;
@synthesize editorViewController;
@synthesize menuActionSheet;

- (NSFetchedResultsController *)notesFetchedResultsController {
    if (!notesFetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:[OCNotesHelper sharedHelper].context];
        [fetchRequest setEntity:entity];
        
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:20];
        
        notesFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                            managedObjectContext:[OCNotesHelper sharedHelper].context
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:@"NoteCache"];
        notesFetchedResultsController.delegate = self;
    }
    return notesFetchedResultsController;
}

- (UIRefreshControl *)notesRefreshControl {
    if (!notesRefreshControl) {
        notesRefreshControl = [[UIRefreshControl alloc] init];
        if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
            notesRefreshControl.tintColor = [UIColor whiteColor];
        }
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
    
    self.editorViewController = (OCEditorViewController*)self.slidingViewController.topViewController;
    
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
    
    [self.notesFetchedResultsController performFetch:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self didBecomeActive:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.notesFetchedResultsController fetchedObjects].count;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    //NSIndexPath *indexPathTemp = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    Note *note = [self.notesFetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = note.title;
    cell.backgroundColor = [UIColor clearColor];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[note.modified doubleValue]];
    if (date) {
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        dateFormat.dateStyle = NSDateFormatterMediumStyle;
        dateFormat.timeStyle = NSDateFormatterShortStyle;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Modified on %@", [dateFormat stringFromDate:date]];
    }

    //cell.delegate = self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        UIView * selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
        [selectedBackgroundView setBackgroundColor:[UIColor colorWithRed:0.25f green:0.34f blue:0.52f alpha:1.0f]]; // set color here
        [cell setSelectedBackgroundView:selectedBackgroundView];
    }
    cell.tag = indexPath.row;
    [self configureCell:cell atIndexPath:indexPath];
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
        [[OCNotesHelper sharedHelper] deleteNote:[self.notesFetchedResultsController objectAtIndexPath:indexPath]];
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
        self.editorViewController = (OCEditorViewController*)[segue destinationViewController];
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        //[self showRenameForIndex:indexPath.row];
    } else {
        Note *note = [self.notesFetchedResultsController objectAtIndexPath:indexPath];
        [[OCNotesHelper sharedHelper] getNote:note];
        self.editorViewController.note = note;
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

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([actionSheet isEqual:self.menuActionSheet]) {
        switch (buttonIndex) {
            case 0:
                [self doSettings:self.menuActionSheet];
                break;
            case 1:
                [[OCNotesHelper sharedHelper] addNote];
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
    if ([sender isEqual:self.menuActionSheet]) {
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
    [TSMessage showNotificationInViewController:self.parentViewController
                                          title:[n.userInfo objectForKey:@"Title"]
                                       subtitle:[n.userInfo objectForKey:@"Message"]
                                          image:nil
                                           type:TSMessageNotificationTypeError
                                       duration:TSMessageNotificationDurationEndless
                                       callback:nil
                                    buttonTitle:nil
                                 buttonCallback:nil
                                     atPosition:TSMessageNotificationPositionTop
                            canBeDismisedByUser:YES];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    NSLog(@"Section: %ld; Row: %ld", indexPath.section, indexPath.row);
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(UITableViewCell*)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray
                                               arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray
                                               arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}

@end
