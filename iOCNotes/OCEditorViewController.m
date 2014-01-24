//
//  OCViewController.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCEditorViewController.h"
#import "OCAPIClient.h"
#import <QuartzCore/QuartzCore.h>

@interface OCEditorViewController () {
    NSTimer *editingTimer;
}

- (void)updateText:(NSTimer*)timer;
- (void)noteUpdated:(NSNotification*)notification;

@end

@implementation OCEditorViewController

@synthesize note = _note;
@synthesize dynamicsDrawerViewController;

- (void)setNote:(Note *)note {
    if (![note isEqual:_note]) {
        _note = note;
        self.noteContentView.text = _note.content;
        self.noteContentView.editable = YES;
        self.noteContentView.selectable = YES;
        self.titleLabel.text = _note.title;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.94 blue:0.86 alpha:1];
    self.menuButton.tintColor = [UIColor colorWithRed:0.36 green:0.24 blue:0.14 alpha:1];
    self.titleLabel.textColor = [UIColor colorWithRed:0.36 green:0.24 blue:0.14 alpha:1];
    self.noteContentView.editable = NO;
    self.noteContentView.selectable = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noteUpdated:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [self willRotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation duration:0];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        int width;
        int height;
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            width = CGRectGetHeight([UIScreen mainScreen].applicationFrame);
            if (width > 500) { //4" screen
                //
            } else {
                //
            }
            
        } else {
            height = CGRectGetHeight([UIScreen mainScreen].applicationFrame);
            if (height > 500) {
                //
            } else {
                //
            }
        }
    } else {
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 178, 20, 178);
        } else {
            self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 50, 20, 50);
        }
        
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doShowDrawer:(id)sender {
    [self.dynamicsDrawerViewController setPaneState:MSDynamicsDrawerPaneStateOpen inDirection:MSDynamicsDrawerDirectionLeft animated:YES allowUserInterruption:YES completion:nil];
}

- (void)textViewDidChange:(UITextView *)textView {
    if (editingTimer) {
        [editingTimer invalidate];
        editingTimer = nil;
    }
    editingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateText:) userInfo:nil repeats:NO];
}

- (void)updateText:(NSTimer*)timer {
    NSLog(@"Ready to update text");
    self.note.content = self.noteContentView.text;
    [[OCAPIClient sharedClient] updateNote:self.note];
}

- (void)noteUpdated:(NSNotification *)notification {
    NSLog(@"Informed about note update");
    self.titleLabel.text = self.note.title;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSValue *kbFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 2;
    CGRect keyboardFrame = [kbFrame CGRectValue];
    
    CGRect finalKeyboardFrame = [self.view convertRect:keyboardFrame fromView:self.view.window];
    
    int kbHeight = finalKeyboardFrame.size.height;
    
    int height = kbHeight + self.bottomLayoutConstraint.constant;
    
    self.bottomLayoutConstraint.constant = height;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 0.5;
    
    self.bottomLayoutConstraint.constant = 0;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

@end
