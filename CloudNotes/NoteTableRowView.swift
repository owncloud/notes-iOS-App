//
//  NoteTableRowView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 2/11/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class NoteTableRowView: NSTableRowView {

    override var isEmphasized: Bool {
        set { }
        get {
            return false
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        let borderLayer = CALayer()
        borderLayer.frame = CGRect(x: 0, y: self.frame.height - 1, width: self.frame.width, height: 1)
        borderLayer.backgroundColor = NSColor.gridColor.cgColor
        self.layer?.addSublayer(borderLayer)
    }
}
