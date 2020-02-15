//
//  WindowController.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    private var sourceListController: SourceListController?
    private var notesViewController: NotesViewController?
    private var editorViewController: EditorViewController?

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.tabbingMode = .disallowed
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)

        if let splitviewController = window?.contentViewController as? SplitViewController {
            sourceListController = splitviewController.splitViewItems[0].viewController as? SourceListController
            notesViewController = splitviewController.splitViewItems[1].viewController as? NotesViewController
            editorViewController = splitviewController.splitViewItems[2].viewController as? EditorViewController
            sourceListController?.notesViewController = notesViewController
            notesViewController?.editorViewController = editorViewController
        }
    }

    @IBAction func onAdd(sender: Any?) {
        NotesManager.shared.add(content: "", category: "", completion: { [weak self] note in
            if note != nil {
                self?.sourceListController?.notesOutlineView.selectRowIndexes([3], byExtendingSelection: false)
                self?.notesViewController?.notesView.selectRowIndexes([0], byExtendingSelection: false)
                self?.window?.makeFirstResponder(self?.editorViewController?.noteView)
            }
        })
    }

    @IBAction func onSync(sender: Any?) {
        self.sourceListController?.onRefresh(sender: sender)
    }

}

class PrefsWindowController: NSWindowController {

}
