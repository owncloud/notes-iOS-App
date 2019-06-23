//
//  EditorViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class EditorViewController: UIViewController {

    @IBOutlet var activityButton: UIBarButtonItem!
    @IBOutlet var deleteButton: UIBarButtonItem!
    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var previewButton: UIBarButtonItem!
    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var fixedSpace: UIBarButtonItem!
    
    var addingNote = false
    var updatedByEditing = false
    var noteExporter: PBHNoteExporter?
    
    var note: CDNote? {
        didSet {
            if note != oldValue {
                noteView.text = note?.content
                //                    [self noteUpdated:nil];
                noteView.undoManager?.removeAllActions()
                noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            }
        }
    }
   
    var noteView: PBHHeaderTextView {
        let result = PBHHeaderTextView(frame: .zero)
        result.delegate = self
        return result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noteView)

        navigationItem.rightBarButtonItems = [addButton, fixedSpace, activityButton, fixedSpace, deleteButton, fixedSpace, previewButton]
        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        navigationItem.leftItemsSupplementBackButton = true
        
        if let note = note {
            noteView.text = note.content;
            noteView.isEditable = true
            noteView.isSelectable = true
            activityButton.isEnabled = !noteView.text.isEmpty
            addButton.isEnabled = !noteView.text.isEmpty
            previewButton.isEnabled = !noteView.text.isEmpty
            deleteButton.isEnabled = true
        } else {
            noteView.isEditable = false
            noteView.isSelectable = false
            noteView.text = ""
            noteView.headerLabel.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
            navigationItem.title = ""
            activityButton.isEnabled = false
            addButton.isEnabled = true
            deleteButton.isEnabled = false
            previewButton.isEnabled = false
        }

        navigationController?.navigationBar.isTranslucent = true
        navigationController?.delegate = self
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        
        addingNote = false
        updatedByEditing = false
        /*
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
         name:FCModelChangeNotification
         object:OCNote.class];
 */
        view.setNeedsUpdateConstraints()
        if let transitionCoordinator = transitionCoordinator {
            viewWillTransition(to: UIScreen.main.bounds.size, with: transitionCoordinator)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let note = note, let date = note.modified as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = false
            noteView.headerLabel.text = formatter.string(from: date)
            noteView.headerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        //TODO: This works around a Swift/Objective-C interaction issue. Verify that it is still needed.
//        self.noteView.scrollEnabled = NO;
//        self.noteView.scrollEnabled = YES;
//
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if traitCollection.horizontalSizeClass == .regular, traitCollection.userInterfaceIdiom == .pad {
            if size.width > size.height {
                noteView.updateInsets(size: 178)
            } else {
                noteView.updateInsets(size: 50)
            }
        }
    }
    
    override func updateViewConstraints() {
//        if (!self.didSetupConstraints) {
//            self.bottomLayoutConstraint = [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0];
//            [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:0];
//            [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:0];
//            [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:0];
//            self.didSetupConstraints = YES;
//        }
        super.updateViewConstraints()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPreview" {
            if let preview = segue.destination as? PBHPreviewController, let note = note {
                preview.textAsMarkdown = noteView.text
                preview.noteTitle = note.title
            }
        }
    }
    
    // MARK: - Actions

    @IBAction func onActivities(_ sender: Any?) {
        var textToExport: String?
        if let selectedRange = noteView.selectedTextRange, let selectedText = noteView.text(in: selectedRange), !selectedText.isEmpty  {
            textToExport = selectedText
        } else {
            textToExport = noteView.text
        }
        if let text = textToExport {
            noteExporter = PBHNoteExporter(viewController: self, barButtonItem: activityButton, text: text, title: note?.title ?? "Untitled")
            noteExporter?.showMenu()
        }
    }
    
    lazy var deleteAlertController: UIAlertController = {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete Note", comment: "A menu action"), style: .destructive, handler: deleteNote(action:))
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "A menu action"), style: .cancel, handler: { (action) in
            //
        })
        controller.addAction(deleteAction)
        controller.addAction(cancelAction)
        controller.popoverPresentationController?.barButtonItem = deleteButton
        return controller
    }()
    
    func deleteNote(action: UIAlertAction) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"DeletingNote" object:nil];
//
//        __block UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.noteView.frame];
//        imageView.image = [self screenshot];
//        [self.noteView addSubview:imageView];
//        [UIView animateWithDuration:0.3f
//            delay:0.0f
//            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
//            animations:^{
//            CGRect targetFrame = CGRectMake(self.noteView.frame.size.width / 2,
//            self.noteView.frame.size.height /2,
//            0, 0);
//            imageView.frame = targetFrame;
//            imageView.alpha = 0.0f;
//            }
//            completion:^(BOOL finished){
//            [imageView removeFromSuperview];
//            [self.view.layer setNeedsDisplay];
//            [self.view.layer displayIfNeeded];
//            imageView = nil;
//            }];
//
    }
    
    @IBAction func onDelete(_ sender: Any?) {
        present(deleteAlertController, animated: true) {
            //
        }
    }
    
    @IBAction func onAdd(_ sender: Any?) {
        addingNote = true
        //TODO self.ocNote = [[OCNotesHelper sharedHelper] addNote:@""];
    }
    
    @IBAction func onPreview(_ sender: Any?) {
        //
    }
    
    @IBAction func onUndo(_ sender: Any?) {
        if let _ = noteView.undoManager?.canUndo {
            noteView.undoManager?.undo()
        }
    }
    
    @IBAction func onRedo(_ sender: Any?) {
        if let _ = noteView.undoManager?.canRedo {
            noteView.undoManager?.redo()
        }
    }
    
    @IBAction func onDone(_ sender: Any?) {
        noteView.endEditing(true)
    }
    
/*
     - (void)updateText:(NSTimer*)timer {
     //    NSLog(@"Ready to update text");
     if (self.ocNote.existsInDatabase) {
     [self.ocNote save:^{
     self.ocNote.content = self.noteView.text;
     }];
     [[OCNotesHelper sharedHelper] updateNote:self.ocNote];
     }
     }

     
     - (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
     {
     _activityPopover = nil;
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
     //TODO self.noteView.headerLabel.text = [dateFormat stringFromDate:date];
     //TODO self.noteView.headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
     }
     } else {
     self.noteView.editable = NO;
     self.noteView.selectable = NO;
     //TODO self.noteView.headerLabel.text = NSLocalizedString(@"Select or create a note.", @"Placeholder text when no note is selected");
     self.navigationItem.title = @"";
     }
     if (self.addingNote) {
     [self.view bringSubviewToFront:self.noteView];
     [self.noteView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.3];
     if (self.splitViewController.displayMode == UISplitViewControllerDisplayModeAllVisible || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay) {
     [UIView animateWithDuration:0.3 animations:^{
     self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryHidden;
     } completion:^(BOOL finished){
     //
     }];
     }
     self.addingNote = NO;
     }
     if (!self.updatedByEditing) {
     self.noteView.text = self.ocNote.content;
     }
     }
     
     - (void)keyboardWillShow:(NSNotification *)notification {
     if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
     self.navigationItem.rightBarButtonItems = @[self.doneButton, self.fixedSpace, self.redoButton, self.fixedSpace, self.undoButton];
     }
     
     NSDictionary* info = [notification userInfo];
     CGRect r = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
     CGRect ar = [self.view convertRect:r fromView:nil];
     
     NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] * 2;
     int kbHeight = ar.size.height;
     
     UIEdgeInsets textInsets = self.noteView.textContainerInset;
     textInsets.bottom = kbHeight;
     
     [self.bottomLayoutConstraint autoRemove];
     [self updateViewConstraints];
     self.bottomLayoutConstraint = [self.noteView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:kbHeight];
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
     //TODO self.noteView.headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
     }
     
     
     - (UIImage*)screenshot {
     UIGraphicsBeginImageContextWithOptions(self.noteView.frame.size, NO, 0);
     CGContextRef context = UIGraphicsGetCurrentContext();
     [self.noteView.layer renderInContext:context];
     UIImage *capturedScreen = UIGraphicsGetImageFromCurrentImageContext();
     UIGraphicsEndImageContext();
     
     return capturedScreen;
     }
*/
    
    
}

extension EditorViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
//        self.activityButton.enabled = (textView.text.length > 0);
//        self.addButton.enabled = (textView.text.length > 0);
//        self.previewButton.enabled = (textView.text.length > 0);
//        self.deleteButton.enabled = YES;
//        if (editingTimer) {
//            [editingTimer invalidate];
//            editingTimer = nil;
//        }
//        editingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateText:) userInfo:nil repeats:NO];

    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
//        CGRect textRect = [tView.layoutManager usedRectForTextContainer:tView.textContainer];
//        CGFloat sizeAdjustment = tView.font.lineHeight * [UIScreen mainScreen].scale;
//
//        if (textRect.size.height >= tView.frame.size.height - tView.contentInset.bottom - sizeAdjustment) {
//            if ([text isEqualToString:@"\n"]) {
//                [UIView animateWithDuration:0.2 animations:^{
//                    [tView setContentOffset:CGPointMake(tView.contentOffset.x, tView.contentOffset.y + sizeAdjustment)];
//                    }];
//            }
//        }
        
        return true
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        textView.scrollRangeToVisible(textView.selectedRange)
    }
}

extension EditorViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
//        if ([viewController isEqual:self]) {
//            BOOL showKeyboard = NO;
//            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
//                if (self.ocNote && (self.ocNote.id == 0)) {
//                    showKeyboard = YES;
//                }
//            }
//            if (showKeyboard) {
//                [self.view bringSubviewToFront:self.noteView];
//                [self.noteView becomeFirstResponder];
//            }
//        }

    }
    
}
