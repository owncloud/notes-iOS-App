//
//  EditorViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import PKHUD

class EditorViewController: UIViewController {

    @IBOutlet var activityButton: UIBarButtonItem!
    @IBOutlet var deleteButton: UIBarButtonItem!
    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var previewButton: UIBarButtonItem!
    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var fixedSpace: UIBarButtonItem!
    
    var updatedByEditing = false
    var noteExporter: PBHNoteExporter?
    var bottomLayoutConstraint: NSLayoutConstraint?
    var editingTimer: Timer?

    var note: CDNote? {
        didSet {
            if note != oldValue, let note = note {
                HUD.show(.progress)
                NoteSessionManager.shared.get(note: note, completion: { [weak self] in
                    self?.noteView.text = note.content
                    self?.noteView.undoManager?.removeAllActions()
                    self?.noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                    self?.updateHeaderLabel()
                    HUD.hide()
                })
            }
        }
    }
   
    var noteView = PBHHeaderTextView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))

    private var observers = [NSObjectProtocol]()

    var screenShot: UIImage {
        var capturedScreen: UIImage?
        UIGraphicsBeginImageContextWithOptions(self.noteView.frame.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            self.noteView.layer.render(in: context)
            capturedScreen = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        return capturedScreen ?? UIImage()
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noteView)
        noteView.translatesAutoresizingMaskIntoConstraints = false
        noteView.delegate = self
        let bottomConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        bottomLayoutConstraint = bottomConstraint
        self.view.backgroundColor = .ph_cellBackgroundColor
        NSLayoutConstraint.activate([
            noteView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            noteView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            noteView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint,
        ])
        navigationItem.rightBarButtonItems = [addButton, fixedSpace, activityButton, fixedSpace, deleteButton, fixedSpace, previewButton]
        #if !targetEnvironment(macCatalyst)
        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        navigationItem.leftItemsSupplementBackButton = true
        #endif
        if let note = note {
            noteView.text = note.content;
            noteView.isEditable = true
            noteView.isSelectable = true
            activityButton.isEnabled = !noteView.text.isEmpty
            addButton.isEnabled = !noteView.text.isEmpty
            previewButton.isEnabled = !noteView.text.isEmpty
            deleteButton.isEnabled = true
            #if targetEnvironment(macCatalyst)
            (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
            #endif
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
            #if targetEnvironment(macCatalyst)
            (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
            #endif
        }
        #if targetEnvironment(macCatalyst)
        navigationController?.navigationBar.isHidden = true
        #else
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.delegate = self
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        #endif
        if let splitVC = splitViewController as? PBHSplitViewController {
            splitVC.editorViewController = self
        }
        updatedByEditing = false
        self.observers.append(NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillShowNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        self?.keyboardWillShow(notification: notification)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillHideNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        self?.keyboardWillHide(notification: notification)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        self?.preferredContentSizeChanged()
        }))

        if let transitionCoordinator = transitionCoordinator {
            viewWillTransition(to: UIScreen.main.bounds.size, with: transitionCoordinator)
        }
    }
    
    fileprivate func updateHeaderLabel() {
        if let note = note, let date = Date(timeIntervalSince1970: note.modified) as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = false
            noteView.headerLabel.text = formatter.string(from: date)
            noteView.headerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeaderLabel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        //TODO: This works around a Swift/Objective-C interaction issue. Verify that it is still needed.
        self.noteView.isScrollEnabled = false
        self.noteView.isScrollEnabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.updateNoteContent()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
            if splitViewController?.displayMode == .allVisible {
                noteView.updateInsets(size: 50)
            } else {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    noteView.updateInsets(size: 178)
                } else {
                    noteView.updateInsets(size: 50)
                }
            }
        }
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
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete Note", comment: "A menu action"),
                                         style: .destructive,
                                         handler: { [weak self] action in
                                            self?.deleteNote(action)
        })
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "A menu action"), style: .cancel, handler: { _ in
            //
        })
        controller.addAction(deleteAction)
        controller.addAction(cancelAction)
        controller.modalPresentationStyle = .popover
        return controller
    }()
    
    @objc
    func deleteNote(_ sender: Any?) {
        NotificationCenter.default.post(name: .deletingNote, object: self)
        let imageView = UIImageView(frame: self.noteView.frame)
        imageView.image = self.screenShot
        self.noteView.addSubview(imageView)
        UIView.animate(withDuration: 0.3,
                       delay: 0.0,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: { [weak self] in
                        let targetFrame = CGRect(x: self?.noteView.frame.size.width ?? 100 / 2, y: self?.noteView.frame.size.height ?? 100 / 2, width: 0, height: 0)
                        imageView.frame = targetFrame
                        imageView.alpha = 0.0
        }) { (_) in
            imageView.removeFromSuperview()
            self.view.layer.setNeedsDisplay()
            self.view.layer.displayIfNeeded()
        }
    }
    
    @IBAction func onDelete(_ sender: Any?) {
        if let popover = deleteAlertController.popoverPresentationController {
            popover.barButtonItem = deleteButton
        }
        present(deleteAlertController, animated: true, completion: nil)
    }
    
    @IBAction func onAdd(_ sender: Any?) {
        NoteSessionManager.shared.add(content: "", category: "", favorite: false) { [weak self] note in
            self?.note = note
        }
    }
    
    @IBAction func onPreview(_ sender: Any?) {
        performSegue(withIdentifier: "showPreview", sender: sender)
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

    func keyboardWillShow(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItems = [self.doneButton, self.fixedSpace, self.redoButton, self.fixedSpace, self.undoButton]
        }
        if let info = notification.userInfo,
            let rect: CGRect = info[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect,
            let ar = self.view?.convert(rect, from: nil),
            let animationDuration: TimeInterval = info[UIWindow.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            let kbHeight = ar.size.height
            var textInsets = self.noteView.textContainerInset
            textInsets.bottom = kbHeight
            self.bottomLayoutConstraint?.isActive = false
            self.bottomLayoutConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -kbHeight)
            self.bottomLayoutConstraint?.isActive = true
            self.updatedByEditing = true
            UIView.animate(withDuration: animationDuration) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    func keyboardWillHide(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItems = [self.addButton, self.fixedSpace, self.activityButton, self.fixedSpace, self.deleteButton, self.fixedSpace, self.previewButton];
        }
        if let info = notification.userInfo,
            let animationDuration: TimeInterval = info[UIWindow.keyboardAnimationDurationUserInfoKey] as? TimeInterval {

            self.bottomLayoutConstraint?.isActive = false
            self.bottomLayoutConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            self.bottomLayoutConstraint?.isActive = true
            self.updateViewConstraints()
            self.updatedByEditing = false
            UIView.animate(withDuration: animationDuration) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    func preferredContentSizeChanged() {
        self.noteView.font = UIFont.preferredFont(forTextStyle: .body)
        self.noteView.headerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }



/*
     - (void)noteAdded:(NSNotification*)notification {
     [self noteUpdated:notification];
     }

*/

}

extension EditorViewController: UITextViewDelegate {
    
    fileprivate func updateNoteContent() {
        if let note = self.note, let text = self.noteView.text, text != note.content {
            note.content = text
            NoteSessionManager.shared.update(note: note, completion: { [weak self] in
                self?.updateHeaderLabel()
            })
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        self.activityButton.isEnabled = textView.text.count > 0
        self.addButton.isEnabled = textView.text.count > 0
        self.previewButton.isEnabled = textView.text.count > 0
        self.deleteButton.isEnabled = true
        #if targetEnvironment(macCatalyst)
        (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
        #endif
        if editingTimer != nil {
            editingTimer?.invalidate()
            editingTimer = nil
        }
        editingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false, block: { [weak self] _ in
            self?.updateNoteContent()
        })
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let textRect = textView.layoutManager.usedRect(for: textView.textContainer)
        let sizeAdjustment = textView.font?.lineHeight ?? 0.0 * UIScreen.main.scale

        if textRect.size.height >= textView.frame.size.height - textView.contentInset.bottom - sizeAdjustment {
            if text == "\n" {
                UIView.animate(withDuration: 0.2) {
                    textView.setContentOffset(CGPoint(x: textView.contentOffset.x, y: textView.contentOffset.y + sizeAdjustment), animated: true)
                }
            }
        }
        return true
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        textView.scrollRangeToVisible(textView.selectedRange)
    }
}

extension EditorViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController == self {
            if self.traitCollection.userInterfaceIdiom == .phone, let note = self.note, note.id == 0 {
                self.view.bringSubviewToFront(self.noteView)
                self.noteView.becomeFirstResponder()
            }
        }
    }
    
}
