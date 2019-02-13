//
//  NoteSessionManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/6/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import Alamofire

typealias SyncCompletionBlock = () -> Void

class NoteSessionManager: Alamofire.SessionManager {
    
    static let shared = NoteSessionManager()
    
    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.peterandlinda.CloudNotes.background")
        super.init(configuration: configuration)
    }
    
}

class NotesManager: NSObject {
    
    static let shared = NotesManager()

    func sync() {
        let router = Router.allNotes(exclude: "")
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<[NoteStruct]>) in
            if let notes = response.value {
                CDNote.update(notes: notes)
            }
        }
    }
    
    func add(content: String, category: String?, favorite: Bool? = false) {
        let parameters: Parameters = ["content": content,
                                      "category": category as Any,
                                      "modified": Date().timeIntervalSince1970,
                                      "favorite": favorite ?? false]
        let router = Router.createNote(paramters: parameters)
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
        }
    }
    
    func get(note: NoteProtocol) {
        let router = Router.getNote(id: Int(note.id), exclude: "")
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
        }
    }
    
    func update(note: NoteProtocol) {
        let parameters: Parameters = ["content": note.content,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
        }
    }
    
    func delete(note: NoteProtocol) {
        let router = Router.deleteNote(id: Int(note.id))
        NoteSessionManager.shared.request(router).responseData { (response) in
            switch response.result {
            case .success:
                CDNote.delete(ids: [Int32(note.id)], in: NotesData.mainThreadContext)
            default:
                break
            }
        }
    }

}
