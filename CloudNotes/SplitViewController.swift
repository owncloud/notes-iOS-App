//
//  SplitViewController.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 2/9/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class SplitViewController: NSSplitViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewItems[0].minimumThickness = 200.0
        splitViewItems[0].maximumThickness = 400.0
        splitViewItems[0].collapseBehavior = .useConstraints
        splitViewItems[0].isCollapsed = false
        splitViewItems[1].minimumThickness = 300.0
        splitViewItems[1].maximumThickness = 600.0
        splitViewItems[1].collapseBehavior = .useConstraints
        splitViewItems[1].isCollapsed = false
        splitViewItems[2].minimumThickness = 300.0
        splitViewItems[2].collapseBehavior = .useConstraints
        splitViewItems[2].isCollapsed = false
    }

    override func viewDidAppear() {
        if KeychainHelper.server.isEmpty {
            if let windowController = self.view.window?.windowController as? WindowController {
                windowController.onPreferences(sender: nil)
            }
        }
    }
    
    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }

}
