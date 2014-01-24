//
//  OCNotesTableViewController.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCDrawerViewController.h"
#import "OCNotesTableViewController.h"
#import "OCAPIClient.h"
#import "Note.h"

@interface OCNotesTableViewController ()

@end

@implementation OCNotesTableViewController

@synthesize notesFetchedResultsController;
@synthesize notesRefreshControl;
@synthesize editorViewController;
@synthesize menuActionSheet;

- (NSFetchedResultsController *)notesFetchedResultsController {
    if (!notesFetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:[OCAPIClient sharedClient].context];
        [fetchRequest setEntity:entity];
        
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:20];
        
        notesFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                            managedObjectContext:[OCAPIClient sharedClient].context
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:@"NoteCache"];
        notesFetchedResultsController.delegate = self;
    }
    return notesFetchedResultsController;
}

- (UIRefreshControl *)notesRefreshControl {
    if (!notesRefreshControl) {
        notesRefreshControl = [[UIRefreshControl alloc] init];
        notesRefreshControl.tintColor = [UIColor whiteColor];
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
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.refreshControl = self.notesRefreshControl;
    
    UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LaunchImage"]];
    [tempImageView setFrame:self.tableView.frame];
    
    //self.tableView.backgroundView = tempImageView;
    self.tableView.opaque = NO;
    
    [self.notesFetchedResultsController performFetch:nil];
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
    //cell.delegate = self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
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
        [[OCAPIClient sharedClient] deleteNote:[self.notesFetchedResultsController objectAtIndexPath:indexPath]];
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

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        //[self showRenameForIndex:indexPath.row];
    } else {
        Note *note = [self.notesFetchedResultsController objectAtIndexPath:indexPath];
        self.editorViewController.note = note;
        OCDrawerViewController *drawerViewController = (OCDrawerViewController*)self.parentViewController;
        [drawerViewController.dynamicsDrawerViewController setPaneState:MSDynamicsDrawerPaneStateClosed inDirection:MSDynamicsDrawerDirectionLeft animated:YES allowUserInterruption:YES completion:nil];
    }
}

- (IBAction)doRefresh:(id)sender {
    [[OCAPIClient sharedClient] sync];
    [self.notesRefreshControl endRefreshing];
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
                //[self doSettings:self.gearActionSheet];
                break;
            case 1:
                [[OCAPIClient sharedClient] addNote];
                break;
            default:
                break;
        }
    }
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
