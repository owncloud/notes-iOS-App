//
//  AppKitEntryPoint.swift
//  AppKitGlue
//
//  Created by Peter Hedlund on 12/24/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Cocoa
import AppKitInterface

public class AppKitEntryPoint: NSObject, AppKitInterfaceProtocol, NSApplicationDelegate {

    public required override init() {
        super.init()
        let macApp = NSApplication.shared
        macApp.delegate = self // Doesn't work
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    public func sceneDidActivate(identifier: String) {
        for window in NSApp.windows {
            print(window.title)
            switch window.title {
            case "Categories" where identifier == "Categories":
                window.setContentSize(NSSize(width: 200, height: 200))
            case "Preferences" where identifier == "Preferences":
                window.setContentSize(NSSize(width: 200, height: 200))
            default:
                break
            }
            
        }
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}
