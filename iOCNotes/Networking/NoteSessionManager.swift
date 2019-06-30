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

    class var isConnectedToInternet: Bool {
        return NetworkReachabilityManager(host: KeychainHelper.server)?.isReachable ?? false
    }

    func sync(completion: SyncCompletionBlock? = nil) {
        let router = Router.allNotes(exclude: "")
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<[NoteStruct]>) in
            if let notes = response.value {
                CDNote.update(notes: notes)
            }
            completion?()
        }
    }
    
    func add(content: String, category: String?, favorite: Bool? = false, completion: SyncCompletionBlock? = nil) {
        let note = NoteStruct(content: content, category: category, favorite: favorite ?? false)
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        CDNote.update(notes: [note])
        let router = Router.createNote(paramters: parameters)
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
            completion?()
        }
    }
    
    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        let router = Router.getNote(id: Int(note.id), exclude: "")
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
            completion?()
        }
    }
    
    func update(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.updateNeeded = true
        CDNote.update(notes: [incoming])
        let parameters: Parameters = ["content": note.content ?? "" as Any,
                                      "category": note.category ?? "" as Any,
                                      "modified": Date().timeIntervalSince1970 as Any,
                                      "favorite": note.favorite]
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)
        NoteSessionManager.shared.request(router).responseDecodable { (response: DataResponse<NoteStruct>) in
            if let note = response.value {
                CDNote.update(notes: [note])
            }
            completion?()
        }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.deleteNeeded = true
        CDNote.update(notes: [incoming])
        let router = Router.deleteNote(id: Int(note.id))
        NoteSessionManager.shared.request(router).responseData { (response) in
            switch response.result {
            case .success:
                CDNote.delete(ids: [Int32(note.id)], in: NotesData.mainThreadContext)
            default:
                break
            }
            completion?()
        }
    }

}
