//
//  Note+Extension.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/16/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation

extension Note: NoteProtocol {
    var addNeeded: Bool {
        get {
            return self.cdAddNeeded
        }
        set {
            self.cdAddNeeded = newValue
        }
    }
    
    var deleteNeeded: Bool {
        get {
            return self.cdDeleteNeeded
        }
        set {
            self.cdDeleteNeeded = newValue
        }
    }
    
    var favorite: Bool {
        get {
            return self.cdFavorite
        }
        set {
            self.cdFavorite = newValue
        }
    }
    
    var serverId: Int64 {
        get {
            return self.cdServerId
        }
        set {
            self.cdServerId = newValue
        }
    }
    
    var updateNeeded: Bool {
        get {
            return self.cdUpdateNeeded
        }
        set {
            self.cdUpdateNeeded = newValue
        }
    }
    
    var category: String {
        get {
            return self.cdCategory ?? ""
        }
        set {
            self.cdCategory = newValue
        }
    }
    
    var content: String {
        get {
            return self.cdContent ?? ""
        }
        set {
            self.cdContent = newValue
        }
    }
    
    var guid: String {
        get {
            return self.cdGuid ?? UUID().uuidString
        }
        set {
            self.cdGuid = newValue
        }
    }
    
    var modified: TimeInterval {
        get {
            return self.cdModified?.timeIntervalSince1970 ?? 0
        }
        set {
            self.cdModified = NSDate(timeIntervalSince1970: newValue)
        }
    }
    
    var title: String {
        get {
            return self.cdTitle ?? "New Note"
        }
        set {
            self.cdTitle = newValue
        }
    }
    
    func update(from note: NoteProtocol) {
        self.cdAddNeeded = note.addNeeded
        self.cdCategory = note.category
        self.cdContent = note.content
        self.cdDeleteNeeded = note.deleteNeeded
        self.cdFavorite = note.favorite
        self.cdGuid = note.guid
        self.cdModified = Date(timeIntervalSince1970:note.modified) as NSDate
        self.cdServerId = note.serverId
        self.cdTitle = note.title
        self.cdUpdateNeeded = note.updateNeeded
    }
    
}
