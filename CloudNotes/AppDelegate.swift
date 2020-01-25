//
//  AppDelegate.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/13/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ValueTransformer.setValueTransformer(ModifiedValueTransformer(), forName: .modifiedValueTransformerName)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

