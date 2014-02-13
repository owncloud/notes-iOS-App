//
//  OCViewController.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCEditorViewController.h"
#import "OCNotesHelper.h"
#import <QuartzCore/QuartzCore.h>
#import "UIViewController+ECSlidingViewController.h"
#import "TTOpenInAppActivity.h"

@interface OCEditorViewController () <UIGestureRecognizerDelegate, UIPopoverControllerDelegate> {
    NSTimer *editingTimer;
    UIPopoverController *_activityPopover;
}

@property (strong, nonatomic) UIPanGestureRecognizer *dynamicTransitionPanGesture;
@property (nonatomic, strong) UIToolbar *editingToolbar;

- (void)updateText:(NSTimer*)timer;
- (void)noteUpdated:(NSNotification*)notification;

@end

@implementation OCEditorViewController

@synthesize note = _note;
@synthesize editingToolbar;

- (void)setNote:(Note *)note {
    if (![note isEqual:_note]) {
        _note = note;
        self.navigationItem.title = _note.title;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        self.slidingViewController.anchorRightRevealAmount = 320.0f;
        self.dynamicTransition.slidingViewController = self.slidingViewController;
        self.slidingViewController.delegate = self.dynamicTransition;
        self.slidingViewController.topViewAnchoredGesture = ECSlidingViewControllerAnchoredGestureTapping | ECSlidingViewControllerAnchoredGestureCustom;
        self.slidingViewController.customAnchoredGestures = @[self.dynamicTransitionPanGesture];
        [self.view removeGestureRecognizer:self.slidingViewController.panGesture];
        [self.view addGestureRecognizer:self.dynamicTransitionPanGesture];
    }
    
    if (self.note) {
        self.noteContentView.text = _note.content;
        self.noteContentView.editable = YES;
        self.noteContentView.selectable = YES;
        self.activityButton.enabled = (self.noteContentView.text.length > 0);
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            self.noteContentView.inputAccessoryView = self.editingToolbar;
        }
    } else {
        self.noteContentView.editable = NO;
        self.noteContentView.selectable = NO;
        self.noteContentView.text = @"Select or create a note.";
        self.navigationItem.title = @"Note";
        self.activityButton.enabled = NO;
    }
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [self willRotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation duration:0];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
        /*
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
         */
    } else { //iPad
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
    [self.slidingViewController anchorTopViewToRightAnimated:YES];
}

- (IBAction)doActivities:(id)sender {
    NSString *textToExport;
    UITextRange *selectedRange = [self.noteContentView selectedTextRange];
    NSString *selectedText = [self.noteContentView textInRange:selectedRange];
    if (selectedText.length > 0) {
        textToExport = selectedText;
    } else {
        textToExport = self.noteContentView.text;
    }
    
    NSURL *fileUrl = [[OCNotesHelper sharedHelper] documentsDirectoryURL];
    fileUrl = [fileUrl URLByAppendingPathComponent:@"export" isDirectory:YES];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:fileUrl error:nil];
    }
    [[NSFileManager defaultManager] createDirectoryAtURL:fileUrl withIntermediateDirectories:YES attributes:nil error:nil];
    fileUrl = [fileUrl URLByAppendingPathComponent:self.note.title];
    fileUrl = [fileUrl URLByAppendingPathExtension:@"txt"];
    [textToExport writeToURL:fileUrl atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:self.view andBarButtonItem:(UIBarButtonItem*)sender];
    
    NSArray *activityItems = @[textToExport, fileUrl];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[openInAppActivity]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (![_activityPopover isPopoverVisible]) {
            _activityPopover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            _activityPopover.delegate = self;
            openInAppActivity.superViewController = _activityPopover;
            [_activityPopover presentPopoverFromBarButtonItem:(UIBarButtonItem*)sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
    } else {
        openInAppActivity.superViewController = activityViewController;
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	_activityPopover = nil;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.activityButton.enabled = (textView.text.length > 0);
    if (editingTimer) {
        [editingTimer invalidate];
        editingTimer = nil;
    }
    editingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateText:) userInfo:nil repeats:NO];
}

- (BOOL)textView:(UITextView *)tView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    CGRect textRect = [tView.layoutManager usedRectForTextContainer:tView.textContainer];
    CGFloat sizeAdjustment = tView.font.lineHeight * [UIScreen mainScreen].scale;
    
    if (textRect.size.height >= tView.frame.size.height - tView.contentInset.bottom - sizeAdjustment) {
        if ([text isEqualToString:@"\n"]) {
            [UIView animateWithDuration:0.2 animations:^{
                [tView setContentOffset:CGPointMake(tView.contentOffset.x, tView.contentOffset.y + sizeAdjustment)];
            }];
        }
    }
    
    return YES;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    [textView scrollRangeToVisible:textView.selectedRange];
}

- (void)updateText:(NSTimer*)timer {
    NSLog(@"Ready to update text");
    self.note.content = self.noteContentView.text;
    [[OCNotesHelper sharedHelper] updateNote:self.note];
}

- (void)noteUpdated:(NSNotification *)notification {
    NSLog(@"Informed about note update");
    if (self.note) {
        self.noteContentView.editable = YES;
        self.noteContentView.selectable = YES;
        self.navigationItem.title = self.note.title;
        self.noteContentView.text = self.note.content;
    } else {
        self.noteContentView.editable = NO;
        self.noteContentView.selectable = NO;
        self.noteContentView.text = @"Select or create a note.";
        self.navigationItem.title = @"Note";
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {

    NSDictionary* d = [notification userInfo];
    CGRect r = [d[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    r = [self.view convertRect:r fromView:nil];
    
    NSDictionary *info = [notification userInfo];
    //NSValue *kbFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 2;
    //CGRect keyboardFrame = [kbFrame CGRectValue];
    
    //CGRect finalKeyboardFrame = [self.view convertRect:keyboardFrame fromView:self.view.window];
    
    int kbHeight = r.size.height;
    
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

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    self.noteContentView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (MEDynamicTransition *)dynamicTransition {
    if (!_dynamicTransition) {
        _dynamicTransition = [[MEDynamicTransition alloc] init];
    }
    return _dynamicTransition;
}

- (UIPanGestureRecognizer *)dynamicTransitionPanGesture {
    if (!_dynamicTransitionPanGesture) {
        _dynamicTransitionPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self.dynamicTransition action:@selector(handlePanGesture:)];
        _dynamicTransitionPanGesture.delegate = self;
    }
    return _dynamicTransitionPanGesture;
}

- (UIToolbar*) editingToolbar {
    if (!editingToolbar) {
        editingToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? 320.0f : 400.0f, 44)];
        editingToolbar.barStyle = UIBarStyleDefault;
        editingToolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemUndo target:self action:@selector            (doUndo:)],
                                 [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo target:self action:@selector(doRedo:)],
                               [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                 [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard:)]];
        [editingToolbar sizeToFit];
    }
    return editingToolbar;
}

- (void)doUndo:(id)sender {
    if ([self.noteContentView.undoManager canUndo]) {
        [self.noteContentView.undoManager undo];
    }
}

- (void)doRedo:(id)sender {
    if ([self.noteContentView.undoManager canRedo]) {
        [self.noteContentView.undoManager redo];
    }
}

- (void)dismissKeyboard:(id)sender {
    [self.noteContentView resignFirstResponder];
}

@end
