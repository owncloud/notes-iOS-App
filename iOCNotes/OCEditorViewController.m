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
#import "UIViewController+MMDrawerController.h"
#import "TTOpenInAppActivity.h"
#import "TransparentToolbar.h"

@interface OCEditorViewController () <UIGestureRecognizerDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate> {
    NSTimer *editingTimer;
    UIPopoverController *_activityPopover;
}

@property (strong, nonatomic) UIPanGestureRecognizer *dynamicTransitionPanGesture;

- (void)updateText:(NSTimer*)timer;
- (void)noteUpdated:(NSNotification*)notification;

@end

@implementation OCEditorViewController

@synthesize ocNote = _ocNote;
@synthesize modifiedLabel;
@synthesize addingNote;

- (void)setOcNote:(OCNote *)ocNote {
    if (![ocNote isEqual:_ocNote]) {
        _ocNote = ocNote;
        self.noteContentView.text = _ocNote.content;
        [self noteUpdated:nil];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        CALayer *border = [CALayer layer];
        border.backgroundColor = [UIColor lightGrayColor].CGColor;
        border.frame = CGRectMake(0, 0, 1, 1024);
        [self.mm_drawerController.centerViewController.view.layer addSublayer:border];

        self.navigationItem.rightBarButtonItems = @[self.addButton, self.fixedSpace, self.activityButton, self.fixedSpace, self.deleteButton];
    }
    
    if (self.ocNote) {
        self.noteContentView.text = self.ocNote.content;
        self.noteContentView.editable = YES;
        self.noteContentView.selectable = YES;
        self.activityButton.enabled = (self.noteContentView.text.length > 0);
        self.addButton.enabled = (self.noteContentView.text.length > 0);
        self.deleteButton.enabled = YES;
    } else {
        self.noteContentView.editable = NO;
        self.noteContentView.selectable = NO;
        self.noteContentView.text = @"";
        self.modifiedLabel.text = @"Select or create a note.";
        self.navigationItem.title = @"";
        self.activityButton.enabled = NO;
        self.addButton.enabled = YES;
        self.deleteButton.enabled = NO;
    }
    
    self.noteContentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.noteContentView.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);
    [self.noteContentView addSubview:self.modifiedLabel];
    
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.delegate = self;
    
    self.addingNote = NO;
    
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
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteUpdated:)
                                               name:FCModelInsertNotification
                                             object:OCNote.class];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteUpdated:)
                                               name:FCModelUpdateNotification
                                             object:OCNote.class];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(noteUpdated:)
                                               name:FCModelDeleteNotification
                                             object:OCNote.class];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [self willRotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation duration:0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.ocNote) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.ocNote.modified];
        if (date) {
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            dateFormat.dateStyle = NSDateFormatterShortStyle;
            dateFormat.timeStyle = NSDateFormatterShortStyle;
            dateFormat.doesRelativeDateFormatting = NO;
            self.modifiedLabel.text = [dateFormat stringFromDate:date];
            self.modifiedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //[self.noteContentView becomeFirstResponder];
    //[self.noteContentView resignFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //self.navigationController.toolbar.hidden = YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
        
        int width;
        int height;
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            width = CGRectGetHeight([UIScreen mainScreen].applicationFrame);
            //self.modifiedLabel.frame = CGRectMake(0, kModifiedLabelOffset, width, 15);
            if (width > 500) { //4" screen
                //
            } else {
                //
            }
            
        } else {
            height = CGRectGetHeight([UIScreen mainScreen].applicationFrame);

            width = CGRectGetWidth([UIScreen mainScreen].applicationFrame);
            //self.modifiedLabel.frame = CGRectMake(0, kModifiedLabelOffset, width, 15);
            if (height > 500) {
                //
            } else {
                //
            }
        }
         
    } else { //iPad
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 178, 20, 178);
            self.modifiedLabel.frame = CGRectMake(183, -18, 500, 15);
        } else {
            self.noteContentView.textContainerInset = UIEdgeInsetsMake(20, 50, 20, 50);
            self.modifiedLabel.frame = CGRectMake(55, -18, 500, 15);
        }
    }
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willEnterForeground:(NSNotification*)notification {
    if (!self.ocNote) {
        [self doShowDrawer:self];
    }
}

- (IBAction)doShowDrawer:(id)sender {
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideLeft animated:YES completion:^(BOOL finished) {
        //
    }];
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
    fileUrl = [fileUrl URLByAppendingPathComponent:self.ocNote.title];
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

- (IBAction)onDelete:(id)sender {
    [[OCNotesHelper sharedHelper] deleteNote:self.ocNote];
}

- (IBAction)onAdd:(id)sender {
    self.addingNote = YES;
    [[OCNotesHelper sharedHelper] addNote:@""];
}

- (IBAction)onUndo:(id)sender {
    if ([self.noteContentView.undoManager canUndo]) {
        [self.noteContentView.undoManager undo];
    }
}

- (IBAction)onRedo:(id)sender {
    if ([self.noteContentView.undoManager canRedo]) {
        [self.noteContentView.undoManager redo];
    }
}

- (IBAction)onDone:(id)sender {
    [self.noteContentView resignFirstResponder];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	_activityPopover = nil;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.activityButton.enabled = (textView.text.length > 0);
    self.addButton.enabled = (textView.text.length > 0);
    self.deleteButton.enabled = YES;
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
    self.ocNote.content = self.noteContentView.text;
    [self.ocNote save];
    [[OCNotesHelper sharedHelper] updateNote:self.ocNote];
}

- (void)noteUpdated:(NSNotification *)notification {
    NSLog(@"Informed about note update");
    if (self.ocNote) {
        self.noteContentView.editable = YES;
        self.noteContentView.selectable = YES;
        self.activityButton.enabled = (self.noteContentView.text.length > 0);
        self.addButton.enabled = (self.noteContentView.text.length > 0);
        self.deleteButton.enabled = YES;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.ocNote.modified];
        if (date) {
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            dateFormat.dateStyle = NSDateFormatterShortStyle;
            dateFormat.timeStyle = NSDateFormatterShortStyle;
            dateFormat.doesRelativeDateFormatting = NO;
            self.modifiedLabel.text = [dateFormat stringFromDate:date];
            self.modifiedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        }
    } else {
        self.noteContentView.editable = NO;
        self.noteContentView.selectable = NO;
        self.modifiedLabel.text = @"Select or create a note.";
        self.navigationItem.title = @"";
    }
    if ([notification.name isEqualToString:FCModelInsertNotification]) {
        if (self.addingNote) {
            [self.view bringSubviewToFront:self.noteContentView];
            [self.noteContentView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.3];
            self.addingNote = NO;
        }
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        //if (self.mm_drawerController.currentTopViewPosition != ECSlidingViewControllerTopViewPositionCentered) {
        //    return;
        //}
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItems = @[self.doneButton, self.fixedSpace, self.redoButton, self.fixedSpace, self.undoButton];
    }
    NSDictionary* d = [notification userInfo];
    CGRect r = [d[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    r = [self.view convertRect:r fromView:nil];
    
    NSDictionary *info = [notification userInfo];
    //NSValue *kbFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 2;
    //CGRect keyboardFrame = [kbFrame CGRectValue];
    
    //CGRect finalKeyboardFrame = [self.view convertRect:keyboardFrame fromView:self.view.window];
    //CGRect myFrame = self.inputView.frame;
    int kbHeight = r.size.height;
    
    int height = kbHeight + self.bottomLayoutConstraint.constant;
    
    self.bottomLayoutConstraint.constant = height - 44;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItems = @[];
    }

    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 0.5;
    
    self.bottomLayoutConstraint.constant = -44;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)noteAdded:(NSNotification*)notification {
    [self noteUpdated:notification];
}

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    self.noteContentView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.modifiedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

- (UILabel*)modifiedLabel {
    if (!modifiedLabel) {
        modifiedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, -18, 320, 15)];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            modifiedLabel.textAlignment = NSTextAlignmentLeft;
        }else {
            modifiedLabel.textAlignment = NSTextAlignmentCenter;
        }
        modifiedLabel.textColor = [UIColor lightGrayColor];
        modifiedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        modifiedLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        modifiedLabel.text = @"Select or create a note";
    }
    return modifiedLabel;
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isEqual:self]) {
        BOOL showKeyboard = NO;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            if (self.ocNote && (self.ocNote.id == 0)) {
                showKeyboard = YES;
            }
        }
        if (showKeyboard) {
            [self.view bringSubviewToFront:self.noteContentView];
            [self.noteContentView becomeFirstResponder];
        }
    }
}

@end
