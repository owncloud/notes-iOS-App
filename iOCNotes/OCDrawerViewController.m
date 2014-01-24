//
//  OCDrawerViewController.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/19/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCDrawerViewController.h"
#import "OCNotesTableViewController.h"
#import "OCEditorViewController.h"

@interface OCDrawerViewController ()

@end

@implementation OCDrawerViewController

@synthesize dynamicsDrawerViewController;
@synthesize notesTableViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"embed"]) {
        self.notesTableViewController = (OCNotesTableViewController*)segue.destinationViewController;
        self.notesTableViewController.editorViewController = (OCEditorViewController*)self.dynamicsDrawerViewController.paneViewController;
    }
}

- (IBAction)doMenu:(id)sender {
    [self.notesTableViewController doMenu:sender];
}

@end
