//
//  OCNotesTableViewController.h
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "OCEditorViewController.h"

@interface OCNotesTableViewController : UITableViewController <NSFetchedResultsControllerDelegate, UIActionSheetDelegate>

@property (nonatomic, strong, readonly) UIRefreshControl *notesRefreshControl;
@property (nonatomic, strong) OCEditorViewController *editorViewController;
@property (strong, nonatomic) UIActionSheet *menuActionSheet;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsBarButton;
@property (strong, nonatomic) IBOutlet UIButton *titleButton;

- (IBAction) doRefresh:(id)sender;
- (IBAction) doMenu:(id)sender;
- (IBAction)doAdd:(id)sender;
- (IBAction)onTitleButton:(id)sender;

@end
