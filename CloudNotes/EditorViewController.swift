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
    @IBOutlet var textView: NSTextView!
    
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
    }
    
    override var representedObject: Any? {
        didSet {
            updateTextView()
        }
    }
    
    private func updateTextView() {
        if let note = representedObject as? CDNote {
            textView.string = note.content
        }
    }

}
