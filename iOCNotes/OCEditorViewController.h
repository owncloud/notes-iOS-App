//
//  OCViewController.h
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MEDynamicTransition.h"
#import "OCNote.h"

@interface OCEditorViewController : UIViewController <UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UITextView *noteContentView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *menuButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *activityButton;
@property (strong, nonatomic) OCNote *ocNote;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomLayoutConstraint;
@property (strong, nonatomic) MEDynamicTransition *dynamicTransition;

- (IBAction)doShowDrawer:(id)sender;
- (IBAction)doActivities:(id)sender;

@end
