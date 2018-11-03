//
//  NoteProtocol.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/16/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation

protocol NoteProtocol {
    var addNeeded: Bool {get set}
    var category: String {get set}
    var content: String {get set}
    var deleteNeeded: Bool {get set}
    var favorite: Bool {get set}
    var guid: String {get set}
    var modified: TimeInterval {get set}
    var serverId: Int64 {get set}
    var title: String {get set}
    var updateNeeded: Bool {get set}
}

struct NoteKeys {
    static let serverId = "id"
    static let title = "title"
    static let content = "content"
    static let favorite = "favorite"
    static let category = "category"
    static let modified = "modified"
    
    static let exclude = "exclude"
    static let addNeeded = "addNeeded"
    static let updateNeeded = "updateNeeded"
    static let deleteNeeded = "deleteNeeded"
}

struct MessageKeys {
    static let title = "Title"
    static let message = "Message"
}

let NetworkSuccess = Notification.Name(rawValue: "NetworkSuccess")
let NetworkFailure = Notification.Name(rawValue: "NetworkFailure")
