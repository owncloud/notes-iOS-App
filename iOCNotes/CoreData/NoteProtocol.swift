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
