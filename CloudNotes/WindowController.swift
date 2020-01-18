//
//  WindowController.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.tabbingMode = .disallowed
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
    }

}


class PrefsWindowController: NSWindowController {


}
