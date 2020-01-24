//
//  FeedTreeNode.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/14/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Cocoa

@objc protocol NoteTreeNode: class {
    
    var isLeaf: Bool { get }
    var childCount: Int { get }
    var children: [NoteTreeNode] { get }
    
    var title: String { get }
    var content: String? { get }
    var modified: String? { get }

    var sortId: Int { get }
}

class AllNotesNode: NSObject, NoteTreeNode {

    var sortId: Int {
        return 0
    }
    
    var isLeaf: Bool {
        return false
    }
    
    var childCount: Int {
        var count = 0
        if let notes = CDNote.all() {
            count = notes.count
        }
        return count
    }
    
    var children: [NoteTreeNode] {
        var result = [NoteTreeNode]()
        if let notes = CDNote.all() {
            for note in notes {
                result.append(NoteNode(note: note))
            }
        }
        return result
    }
    
    var title: String {
        return "All Notes"
    }
    
    var content: String? {
        return nil
    }
    
    var modified: String? {
        return nil
    }
    
}

class StarredNotesNode: NSObject, NoteTreeNode {

    var sortId: Int {
        return 1
    }

    var isLeaf: Bool {
        return false
    }
    
    var childCount: Int {
        return 0
    }
    
    var children: [NoteTreeNode] {
        return []
    }
    
    var title: String {
        get {
            return "Starred Notes"
        }
    }
    
    var content: String? {
        return nil
    }
    
    var modified: String? {
        return nil
    }
    
}

class CategoryNode: NSObject, NoteTreeNode {

    var sortId: Int {
        return 2
    }

    let category: String
    
    init(category: String) {
        self.category = category
    }
    
    var isLeaf: Bool {
        return false
    }
    
    var childCount: Int {
        var count = 0
        if let notes = CDNote.notes(category: self.category) {
            count = notes.count
        }
        return count
    }
    
    var children: [NoteTreeNode] {
        get {
            var result = [NoteTreeNode]()
            if let notes = CDNote.notes(category: self.category) {
                for note in notes {
                    result.append(NoteNode(note: note))
                }
            }
            return result
        }
    }
    
    var title: String {
        return self.category
    }
    
    var content: String? {
        return nil
    }
    
    var modified: String? {
        return nil
    }
    
}

class NoteNode: NSObject, NoteTreeNode {

    var sortId: Int {
        return Int(self.note.id) + 1000
    }

    let note: CDNote
    
    init(note: CDNote){
        self.note = note
    }
    
    var isLeaf: Bool {
        return true
    }
    
    var childCount: Int {
        return 0
    }
    
    var children: [NoteTreeNode] {
        return []
    }
    
    var title: String {
        return self.note.title
    }
    
    var content: String? {
        return self.note.content
    }
    
    var modified: String? {
        return "\(self.note.modified)"
    }
    
}
