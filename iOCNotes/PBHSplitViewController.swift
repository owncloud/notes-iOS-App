//
//  PBHSplitViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 10/13/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class PBHSplitViewController: UISplitViewController {

    var editorViewController: EditorViewController?
    var notesTableViewController: NotesTableViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        #if targetEnvironment(macCatalyst)
        primaryBackgroundStyle = .sidebar
        minimumPrimaryColumnWidth = 300
        maximumPrimaryColumnWidth = 1000
        #else
        preferredDisplayMode = .allVisible
        #endif
    }

    #if targetEnvironment(macCatalyst)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppDelegate.shared.sceneDidActivate(identifier: "CloudNotes")
        buildMacToolbar()
    }
    #endif
    
    @IBAction func onFileNew(sender: Any?) {
        notesTableViewController?.onAdd(sender: sender)
    }
    
    @IBAction func onViewSync(sender: Any?) {
        notesTableViewController?.onRefresh(sender: sender)
    }
}

extension PBHSplitViewController: UISplitViewControllerDelegate {

    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        guard svc == self else {
            return
        }
        if displayMode == .allVisible || displayMode == .primaryOverlay {
            self.editorViewController?.noteView.resignFirstResponder()
        }
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
            if displayMode == .allVisible {
                editorViewController?.noteView.updateInsets(size: 50)
            } else {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    editorViewController?.noteView.updateInsets(size: 178)
                } else {
                    editorViewController?.noteView.updateInsets(size: 50)
                }
            }
        } else {
            editorViewController?.noteView.updateInsets(size: 20)
        }
    }
    
    func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode {
        if svc.displayMode == .primaryHidden {
            if svc.traitCollection.horizontalSizeClass == .regular,
            [.landscapeLeft, .landscapeRight].contains(UIDevice.current.orientation) {
                return .allVisible
            }
            return .primaryOverlay
        }
        return .primaryHidden
    }

    override func collapseSecondaryViewController(_ secondaryViewController: UIViewController, for splitViewController: UISplitViewController) {
        self.editorViewController?.note = nil
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    @available(iOS 14.0, *)
    func splitViewController(_ splitViewController: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .primary
    }

    @objc func onAddButtonAction(sender: UIBarButtonItem) {
        editorViewController?.onAdd(sender)
    }

    @objc func onRefreshButtonAction(sender: UIBarButtonItem) {
        notesTableViewController?.onRefresh(sender: sender)
    }

    @objc func onBackButtonAction(sender: UIBarButtonItem) {
        editorViewController?.navigationController?.popViewController(animated: true)
    }

    @objc func onPreviewButtonAction(sender: UIBarButtonItem) {
        editorViewController?.onPreview(sender)
    }
    
    @objc func onShareButtonAction(sender: UIBarButtonItem) {
            editorViewController?.onActivities(sender)
    }
    
    @IBAction func onPreferences(sender: Any) {
    }
    
}

#if targetEnvironment(macCatalyst)
extension PBHSplitViewController {
  
    func buildMacToolbar() {
        guard let windowScene = view.window?.windowScene else {
            return
        }
        
        if let titlebar = windowScene.titlebar {
            let toolbar = NSToolbar(identifier: "NotesToolbar")
            toolbar.allowsUserCustomization = false
            toolbar.delegate = self
            titlebar.toolbar = toolbar
            titlebar.titleVisibility = .hidden
        }
    }
    
}

extension PBHSplitViewController: NSToolbarDelegate {
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .refresh:
            let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(self.onRefreshButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
        case .back:
            let barButtonItem =  UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(self.onBackButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
        case .preview:
            let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "doc.text.magnifyingglass"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(self.onPreviewButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
        case .share:
            let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(self.onShareButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
        case .add:
            let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(self.onAddButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
            
        default:
            break
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .add,
            .refresh,
            .space,
            .back,
            .flexibleSpace,
            .preview,
            .share
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
}
#endif
