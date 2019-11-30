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

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        #if targetEnvironment(macCatalyst)
        primaryBackgroundStyle = .sidebar
        #else
        preferredDisplayMode = .allVisible
        #endif
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

}
