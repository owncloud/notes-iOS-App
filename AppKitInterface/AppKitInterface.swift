//
//  AppKitInterface.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/24/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation

public protocol AppKitInterfaceProtocol: NSObject {
    init() 
    func sceneDidActivate(identifier: String)
}
