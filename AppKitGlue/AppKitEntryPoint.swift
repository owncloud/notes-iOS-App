//
//  AppKitEntryPoint.swift
//  AppKitGlue
//
//  Created by Peter Hedlund on 12/24/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Cocoa
import AppKitInterface

public class AppKitEntryPoint: AppKitInterfaceProtocol {

    public required init() {
        let macApp = NSApplication.shared
        print(macApp.description)
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    public func message() -> String {
        return "message"
    }
}
