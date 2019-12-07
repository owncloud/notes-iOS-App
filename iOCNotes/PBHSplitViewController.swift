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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        buildMacToolbar()
    }
    
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

extension NSToolbarItem.Identifier {
    static let add = NSToolbarItem.Identifier(rawValue: "add")
    static let refresh = NSToolbarItem.Identifier(rawValue: "refresh")
    static let back = NSToolbarItem.Identifier(rawValue: "back")
    static let preview = NSToolbarItem.Identifier(rawValue: "preview")
    static let share = NSToolbarItem.Identifier(rawValue: "share")
}

extension PBHSplitViewController {
  func buildMacToolbar() {
    #if targetEnvironment(macCatalyst)
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
    #endif
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
//        if itemIdentifier == Toolbar.colors {
//        let items = AppColors.colorSpace
//          .enumerated()
//          .map { (index, slice) -> NSToolbarItem in
//            let item = NSToolbarItem()
//            item.image = UIImage.swatch(slice.1)
//            item.target = self
//            item.action = #selector(colorSelectionChanged(_:))
//            item.tag = index
//            item.label = slice.0
//            return item
//          }
//        
//        let group = NSToolbarItemGroup(itemIdentifier: Toolbar.colors)
//        group.subitems = items
//        group.selectionMode = .momentary
//        group.label = "Text Background"
//        
//        return group
//      }
//      //4
//      else if itemIdentifier == Toolbar.addImage {
//        let item = NSToolbarItem(itemIdentifier: Toolbar.addImage)
//        item.image = UIImage(systemName: "photo")?.forNSToolbar()
//        item.target = self
//        item.action = #selector(chooseImageAction)
//        item.label = "Add Image"
//        
//        return item
//      }
//      else if itemIdentifier == Toolbar.share {
//        let item = NSToolbarItem(itemIdentifier: Toolbar.share)
//        item.image = UIImage(systemName: "square.and.arrow.up")?.forNSToolbar()
//        item.target = self
//        item.action = #selector(shareAction)
//        item.label = "Share Item"
//        
//        return item
//      }
//      
//      return nil
//    }
    
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
