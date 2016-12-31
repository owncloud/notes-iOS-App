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
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsBarButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addBarButton;
@property (strong, nonatomic) IBOutlet UIButton *titleButton;
@property (assign) BOOL addingNote;

- (IBAction) doRefresh:(id)sender;
- (IBAction)doAdd:(id)sender;
- (IBAction)onTitleButton:(id)sender;

@end
