//
//  WindowController.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    private var notesViewController: NotesViewController?
    private var editorViewController: EditorViewController?

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.tabbingMode = .disallowed
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)

        if let splitviewController = window?.contentViewController as? NSSplitViewController {
            notesViewController = splitviewController.splitViewItems[0].viewController as? NotesViewController
            editorViewController = splitviewController.splitViewItems[1].viewController as? EditorViewController
            notesViewController?.editorViewController = editorViewController
        }
    }

}


class PrefsWindowController: NSWindowController {


}
