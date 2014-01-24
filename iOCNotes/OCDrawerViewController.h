//
//  OCDrawerViewController.h
//  iOCNotes
//
//  Created by Peter Hedlund on 1/19/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MSDynamicsDrawerViewController.h"
#import "OCNotesTableViewController.h"

@interface OCDrawerViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIBarButtonItem *menuButton;
@property (strong, nonatomic) MSDynamicsDrawerViewController *dynamicsDrawerViewController;
@property (strong, nonatomic) OCNotesTableViewController *notesTableViewController;

- (IBAction)doMenu:(id)sender;

@end
