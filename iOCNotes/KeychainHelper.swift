//
//  KeychainHelper.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/18/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import KeychainAccess

struct KeychainHelper {
    private static let keychain = Keychain(service: "com.peterandlinda.CloudNotes")

    static var username: String {
        get {
            return keychain["username"] ?? ""
        }
        set {
            keychain["username"] = newValue
        }
    }

    static var password: String {
        get {
            return keychain["password"] ?? ""
        }
        set {
            keychain["password"] = newValue
        }
    }

    static var server: String {
        get {
            return UserDefaults.standard.string(forKey: "Server") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Server")
        }
    }

    static var version: String? {
        get {
            return UserDefaults.standard.string(forKey: "version")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "version")
        }
    }

    static var syncOnStart: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "SyncOnStart")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SyncOnStart")
        }
    }
    
}
