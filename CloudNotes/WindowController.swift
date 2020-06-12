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
    private var prefsWindowController: PrefsWindowController?

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        window?.tabbingMode = .disallowed
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.toolbar = NSToolbar()
        window?.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
        NSApp.mainMenu?.delegate = self

        if let splitviewController = window?.contentViewController as? SplitViewController {
            sourceListController = splitviewController.splitViewItems[0].viewController as? SourceListController
            notesViewController = splitviewController.splitViewItems[1].viewController as? NotesViewController
            editorViewController = splitviewController.splitViewItems[2].viewController as? EditorViewController
            sourceListController?.notesViewController = notesViewController
            notesViewController?.editorViewController = editorViewController
        }
    }

    @IBAction func onPreferences(sender: Any?) {
        let mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
        prefsWindowController = mainStoryboard.instantiateController(withIdentifier: "PrefsWindowController") as? PrefsWindowController
        prefsWindowController?.showWindow(self)
    }

    @IBAction func onAdd(sender: Any?) {
        NoteSessionManager.shared.add(content: "", category: "", completion: { [weak self] note in
            if note != nil {
                self?.sourceListController?.notesOutlineView.selectRowIndexes([3], byExtendingSelection: false)
                self?.notesViewController?.notesView.selectRowIndexes([0], byExtendingSelection: false)
                self?.editorViewController?.isNewNote = true
                self?.window?.makeFirstResponder(self?.editorViewController?.noteView)
            }
        })
    }

    @IBAction func onOffline(sender: Any?) {
        KeychainHelper.offlineMode.toggle()
    }

    @IBAction func onSync(sender: Any?) {
        self.sourceListController?.onRefresh(sender: sender)
    }

    @IBAction func onDelete(sender: Any?) {
        if let currentNote = notesViewController?.selectedNote {
            NoteSessionManager.shared.delete(note: currentNote) { [weak self] in
                self?.sourceListController?.notesOutlineView.reloadData()
                self?.notesViewController?.notesView.reloadData()
                self?.editorViewController?.note = nil
            }
        }
    }
    
    @IBAction func onFavorite(sender: Any?) {
        editorViewController?.onFavorite(self)
    }

    @IBAction func onCategories(sender: Any?) {
        notesViewController?.performSegue(withIdentifier: "CategorySegue", sender: self)
    }

}

extension WindowController: NSWindowDelegate {

    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }

}

extension WindowController: NSMenuDelegate, NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        print("Validating \(menuItem.identifier?.rawValue ?? "")")
        switch menuItem.identifier?.rawValue {
        case "offlineMenuItem":
            menuItem.state = KeychainHelper.offlineMode ? .on : .off
            return true
        case "deleteMenuItem":
            return notesViewController?.selectedNote != nil
        case "favoriteMenuItem":
            if let note = notesViewController?.selectedNote {
                if note.favorite {
                    menuItem.state = .on
                } else {
                    menuItem.state = .off
                }
                return true
            }
            return false
        case "categoryMenuItem":
            return notesViewController?.selectedNote != nil
        default:
            return true
        }
    }
}

class PrefsWindowController: NSWindowController {

}
