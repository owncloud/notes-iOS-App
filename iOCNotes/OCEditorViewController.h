//
//  OCViewController.h
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OCNote.h"

@class PBHHeaderTextView;
@interface OCEditorViewController : UIViewController <UITextViewDelegate>

@property (strong, nonatomic) PBHHeaderTextView *noteView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *activityButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *previewButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *undoButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *redoButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *fixedSpace;
@property (strong, nonatomic) OCNote *ocNote;

@property (assign) BOOL addingNote;

- (IBAction)doActivities:(id)sender;
- (IBAction)onDelete:(id)sender;
- (IBAction)onAdd:(id)sender;
- (IBAction)onPreview:(id)sender;
- (IBAction)onUndo:(id)sender;
- (IBAction)onRedo:(id)sender;
- (IBAction)onDone:(id)sender;

@end
