//
//  EditorViewController.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/26/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class EditorViewController: NSViewController {

    @IBOutlet var topView: NSView!
    @IBOutlet var noteView: NSTextView!

    var note: CDNote? {
        didSet {
            if note != oldValue, let note = note {
                noteView.string = ""
                //                HUD.show(.progress)
                NotesManager.shared.get(note: note, completion: { [weak self] in
                    self?.updateTextView()
                    self?.noteView.string = note.content
                    self?.noteView.undoManager?.removeAllActions()
                    self?.noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                    //                    self?.updateHeaderLabel()
                    //                    HUD.hide()
                })
            } else {
                updateTextView()
            }
        }
    }

    private var editingTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        topView.wantsLayer = true
        let border: CALayer = CALayer()
        border.autoresizingMask = .layerWidthSizable;
        border.frame = CGRect(x: 0,
                              y: 1,
                              width: topView.frame.width,
                              height: 1)
        border.backgroundColor = NSColor.gridColor.cgColor
        topView.layer?.addSublayer(border)
        noteView.delegate = self
        updateTextView()
    }
    
    private func updateTextView() {
        if let note = note {
            noteView.string = note.content;
            noteView.isEditable = true
            noteView.isSelectable = true
//            activityButton.isEnabled = !noteView.text.isEmpty
//            addButton.isEnabled = !noteView.text.isEmpty
//            previewButton.isEnabled = !noteView.text.isEmpty
//            deleteButton.isEnabled = true
        } else {
            noteView.isEditable = false
            noteView.isSelectable = false
            noteView.string = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
//            noteView.headerLabel.text =
//            navigationItem.title = ""
//            activityButton.isEnabled = false
//            addButton.isEnabled = true
//            deleteButton.isEnabled = false
//            previewButton.isEnabled = false
        }
    }

}

extension EditorViewController: NSTextViewDelegate {
    
    fileprivate func updateNoteContent() {
        if let note = self.note, self.noteView.string != note.content {
            note.content = self.noteView.string
            NotesManager.shared.update(note: note) {
                NotificationCenter.default.post(name: .editorUpdatedNote, object: note)
            }
        }
    }

    func textDidChange(_ notification: Notification) {
//        self.activityButton.isEnabled = textView.text.count > 0
//        self.addButton.isEnabled = textView.text.count > 0
//        self.previewButton.isEnabled = textView.text.count > 0
//        self.deleteButton.isEnabled = true
        if editingTimer != nil {
            editingTimer?.invalidate()
            editingTimer = nil
        }
        editingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false, block: { [weak self] _ in
            self?.updateNoteContent()
        })
    }
    
}
