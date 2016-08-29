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
//#import "UIViewController+MMDrawerController.h"
#import "TTOpenInAppActivity.h"
#import "PureLayout.h"
#import "iOCNotes-Swift.h"

@interface OCEditorViewController () <UIGestureRecognizerDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate> {
    NSTimer *editingTimer;
    UIPopoverController *_activityPopover;
    UIActionSheet *deleteConfirmation;
    PBHNoteExporter *noteExporter;
}

@property (strong, nonatomic) UIPanGestureRecognizer *dynamicTransitionPanGesture;
@property (strong, nonatomic) NSLayoutConstraint *bottomLayoutConstraint;
@property (nonatomic, assign) BOOL didSetupConstraints;
@property (nonatomic, assign) BOOL updatedByEditing;

- (void)updateText:(NSTimer*)timer;
- (void)noteUpdated:(NSNotification*)notification;

@end

@implementation OCEditorViewController

@synthesize ocNote = _ocNote;
@synthesize addingNote;
@synthesize updatedByEditing;
@synthesize noteView;

- (void)setOcNote:(OCNote *)ocNote {
    if (ocNote && [ocNote isKindOfClass:[OCNote class]]) {
        if (![ocNote isEqual:_ocNote]) {
            _ocNote = ocNote;
            self.noteView.text = _ocNote.content;
            [self noteUpdated:nil];
            [self.noteView.undoManager removeAllActions];
            [self.noteView scrollRangeToVisible:NSMakeRange(0, 0)];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
//    CALayer *border = [CALayer layer];
//    border.backgroundColor = [UIColor lightGrayColor].CGColor;
//    border.frame = CGRectMake(0, 0, 1, 1024);
//    [self.mm_drawerController.centerViewController.view.layer addSublayer:border];
    self.noteView = [[PBHHeaderTextView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.noteView.delegate = self;
    [self.view addSubview:self.noteView];
    [self.noteView autoPinEdgesToSuperviewEdges];
    self.navigationItem.rightBarButtonItems = @[self.addButton, self.fixedSpace, self.activityButton, self.fixedSpace, self.deleteButton, self.fixedSpace, self.previewButton];
    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.leftItemsSupplementBackButton = YES;

    if (self.ocNote) {
        self.noteView.text = self.ocNote.content;
        self.noteView.editable = YES;
        self.noteView.selectable = YES;
        self.activityButton.enabled = (self.noteView.text.length > 0);
        self.addButton.enabled = (self.noteView.text.length > 0);
        self.previewButton.enabled = (self.noteView.text.length > 0);
        self.deleteButton.enabled = YES;
    } else {
        self.noteView.editable = NO;
        self.noteView.selectable = NO;
        self.noteView.text = @"";
        self.noteView.headerLabel.text = NSLocalizedString(@"Select or create a note.", @"Placeholder text when no note is selected");
        self.navigationItem.title = @"";
        self.activityButton.enabled = NO;
        self.addButton.enabled = YES;
        self.deleteButton.enabled = NO;
        self.previewButton.enabled = NO;
    }
    
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.delegate = self;
    self.navigationController.toolbar.translucent = YES;
    self.navigationController.toolbar.clipsToBounds = YES;
    
    self.addingNote = NO;
    self.updatedByEditing = NO;
    
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
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(willEnterForeground:)
//                                                 name:UIApplicationDidBecomeActiveNotification
//                                               object:nil];
    
    [self.view setNeedsUpdateConstraints];
    [self viewWillTransitionToSize:[UIScreen mainScreen].bounds.size withTransitionCoordinator:self.transitionCoordinator];
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
            self.noteView.headerLabel.text = [dateFormat stringFromDate:date];
            self.noteView.headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            if (size.width > size.height) {
                [self.noteView updateInsetsToSize:178];
            } else {
                [self.noteView updateInsetsToSize:50];
            }
        }
    }
}

- (void)updateViewConstraints {
    if (!self.didSetupConstraints) {
        NSArray *constraints = [self.noteView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        self.bottomLayoutConstraint = [constraints objectAtIndex:2];
        self.didSetupConstraints = YES;
    }
    [super updateViewConstraints];
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

//- (void)willEnterForeground:(NSNotification*)notification {
//    if (!self.ocNote) {
//        [self doShowDrawer:self];
//    }
//}

//- (IBAction)doShowDrawer:(id)sender {
//    if (self.noteView.isFirstResponder) {
//        [self.noteView resignFirstResponder];
//    }
////    [self.mm_drawerController toggleDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
//}

- (IBAction)doActivities:(id)sender {
    NSString *textToExport;
    UITextRange *selectedRange = [self.noteView selectedTextRange];
    NSString *selectedText = [self.noteView textInRange:selectedRange];
    if (selectedText.length > 0) {
        textToExport = selectedText;
    } else {
        textToExport = self.noteView.text;
    }

    if (!noteExporter) {
        noteExporter = [[PBHNoteExporter alloc] initWithViewController:self barButtonItem:self.activityButton text:textToExport title:self.ocNote.title];
    }
    [noteExporter showMenu];
}

- (IBAction)onDelete:(id)sender {
    if (!deleteConfirmation) {
        deleteConfirmation = [[UIActionSheet alloc] initWithTitle:nil
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Cancel", @"A menu action")
                                           destructiveButtonTitle:NSLocalizedString(@"Delete Note", @"A menu action")
                                                otherButtonTitles:nil, nil];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [deleteConfirmation showFromBarButtonItem:self.deleteButton animated:YES];
    } else {
        [deleteConfirmation showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeletingNote" object:nil];
    
    __block UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.noteView.frame];
    imageView.image = [self screenshot];
    [self.noteView addSubview:imageView];
    [UIView animateWithDuration:0.3f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         CGRect targetFrame = CGRectMake(self.noteView.frame.size.width / 2,
                                                         self.noteView.frame.size.height /2,
                                                         0, 0);
                         imageView.frame = targetFrame;
                         imageView.alpha = 0.0f;
                     }
                     completion:^(BOOL finished){
                         [imageView removeFromSuperview];
                         [self.view.layer setNeedsDisplay];
                         [self.view.layer displayIfNeeded];
                         imageView = nil;
                     }];
}

- (IBAction)onAdd:(id)sender {
    self.addingNote = YES;
    [[OCNotesHelper sharedHelper] addNote:@""];
}

- (IBAction)onPreview:(id)sender {
}

- (IBAction)onUndo:(id)sender {
    if ([self.noteView.undoManager canUndo]) {
        [self.noteView.undoManager undo];
    }
}

- (IBAction)onRedo:(id)sender {
    if ([self.noteView.undoManager canRedo]) {
        [self.noteView.undoManager redo];
    }
}

- (IBAction)onDone:(id)sender {
    [self.noteView endEditing:YES];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	_activityPopover = nil;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.activityButton.enabled = (textView.text.length > 0);
    self.addButton.enabled = (textView.text.length > 0);
    self.previewButton.enabled = (textView.text.length > 0);
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
//    NSLog(@"Ready to update text");
    self.ocNote.content = self.noteView.text;
    if (self.ocNote.existsInDatabase) {
        [self.ocNote save];
        [[OCNotesHelper sharedHelper] updateNote:self.ocNote];
    }
}

- (void)noteUpdated:(NSNotification *)notification {
//    NSLog(@"Informed about note update");
    if (self.ocNote && !self.ocNote.deleteNeeded) {
        self.noteView.editable = YES;
        self.noteView.selectable = YES;
        self.activityButton.enabled = (self.noteView.text.length > 0);
        self.addButton.enabled = (self.noteView.text.length > 0);
        self.previewButton.enabled = (self.noteView.text.length > 0);
        self.deleteButton.enabled = YES;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.ocNote.modified];
        if (date) {
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            dateFormat.dateStyle = NSDateFormatterShortStyle;
            dateFormat.timeStyle = NSDateFormatterShortStyle;
            dateFormat.doesRelativeDateFormatting = NO;
            self.noteView.headerLabel.text = [dateFormat stringFromDate:date];
            self.noteView.headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        }
    } else {
        self.noteView.editable = NO;
        self.noteView.selectable = NO;
        self.noteView.headerLabel.text = NSLocalizedString(@"Select or create a note.", @"Placeholder text when no note is selected");
        self.navigationItem.title = @"";
    }
    if ([notification.name isEqualToString:FCModelInsertNotification]) {
        if (self.addingNote) {
            [self.view bringSubviewToFront:self.noteView];
            [self.noteView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.3];
            self.addingNote = NO;
        }
    }
    if ([notification.name isEqualToString:FCModelUpdateNotification]) {
        if (!self.updatedByEditing) {
            self.noteView.text = self.ocNote.content;
        }
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItems = @[self.doneButton, self.fixedSpace, self.redoButton, self.fixedSpace, self.undoButton];
    }
    
    NSDictionary* d = [notification userInfo];
    CGRect r = [d[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    r = [self.view convertRect:r fromView:nil];
    
    NSDictionary *info = [notification userInfo];
    
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 2;
    int kbHeight = r.size.height;
    int height = kbHeight + self.bottomLayoutConstraint.constant;

    UIEdgeInsets textInsets = self.noteView.textContainerInset;
    textInsets.bottom = height;
    
    [self.bottomLayoutConstraint autoRemove];
    [self updateViewConstraints];
    self.bottomLayoutConstraint = [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:height];
    self.updatedByEditing = YES;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItems = @[self.addButton, self.fixedSpace, self.activityButton, self.fixedSpace, self.deleteButton, self.fixedSpace, self.previewButton];
    }

    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 0.5;
    
    [self.bottomLayoutConstraint autoRemove];
    self.bottomLayoutConstraint = [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [self updateViewConstraints];
    self.updatedByEditing = NO;

    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)noteAdded:(NSNotification*)notification {
    [self noteUpdated:notification];
}

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    self.noteView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.noteView.headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
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
            [self.view bringSubviewToFront:self.noteView];
            [self.noteView becomeFirstResponder];
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier  isEqual: @"showPreview"]) {
        PBHPreviewController *preview = (PBHPreviewController*)segue.destinationViewController;
        preview.textAsMarkdown = self.noteView.text;
        preview.noteTitle = self.ocNote.title;
    }
}

- (UIImage*)screenshot {
    UIGraphicsBeginImageContextWithOptions(self.noteView.frame.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.noteView.layer renderInContext:context];
    UIImage *capturedScreen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return capturedScreen;
}

@end
