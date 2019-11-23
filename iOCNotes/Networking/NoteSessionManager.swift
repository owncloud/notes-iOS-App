//
//  NoteSessionManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/6/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Alamofire
import Foundation
import SwiftMessages

typealias SyncCompletionBlock = () -> Void
typealias SyncCompletionBlockWithNote = (_ note: CDNote?) -> Void

struct ErrorMessage {
    var title: String
    var body: String
}

class NoteSessionManager: Alamofire.SessionManager {
    
    static let shared = NoteSessionManager()
    
    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.peterandlinda.CloudNotes.background")
        super.init(configuration: configuration)
    }
    
}

class NotesManager {
    
    static let shared = NotesManager()

    class var isConnectedToInternet: Bool {
        return NetworkReachabilityManager(host: KeychainHelper.server)?.isReachable ?? false
    }

    class var isOnline: Bool {
        return NotesManager.isConnectedToInternet && !KeychainHelper.offlineMode
    }

    func sync(completion: SyncCompletionBlock? = nil) {

        func deleteOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToDelete = CDNote.notes(property: "cdDeleteNeeded"),
                !notesToDelete.isEmpty {
                let group = DispatchGroup()
                
                for note in notesToDelete {
                    group.enter()
                    NotesManager.shared.delete(note: note, completion: {
                        group.leave()
                    })
                }
                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        func addOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToAdd = CDNote.notes(property: "cdAddNeeded"),
                !notesToAdd.isEmpty {
                let group = DispatchGroup()
                
                for note in notesToAdd {
                    group.enter()
                    self.addToServer(note: note) { _ in
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        func updateOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToUpdate = CDNote.notes(property: "cdUpdateNeeded"),
                !notesToUpdate.isEmpty {
                let group = DispatchGroup()

                for note in notesToUpdate {
                    group.enter()
                    NotesManager.shared.update(note: note, completion: {
                        group.leave()
                    })
                }

                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        deleteOnServer {
            addOnServer {
                updateOnServer {
                    let router = Router.allNotes(exclude: "")
                    NoteSessionManager
                        .shared
                        .request(router)
                        .validate(statusCode: 200..<300)
                        .validate(contentType: ["application/json"])
                        .responseDecodable { (response: DataResponse<[NoteStruct]>) in
                            switch response.result {
                            case .success:
                                if let notes = response.value {
                                    let serverIds = notes.map( { $0.id } )
                                    if let knownIds = CDNote.all()?.map({ $0.id }).filter({ $0 > 0 }) {
                                        let deletedOnServer = Set(knownIds).subtracting(Set(serverIds))
                                        if !deletedOnServer.isEmpty {
                                            _ = CDNote.delete(ids: Array(deletedOnServer))
                                        }
                                    }
                                    CDNote.update(notes: notes)
                                }
                            case .failure(let error):
                                let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                           body: error.localizedDescription)
                                self.showErrorMessage(message: message)
                            }
                            completion?()
                    }
                }
            }
        }
    }
    
    func add(content: String, category: String, favorite: Bool? = false, completion: SyncCompletionBlockWithNote? = nil) {
        let note = NoteStruct(content: content, category: category, favorite: favorite ?? false)
        let result = CDNote.update(note: note) //addNeeded defaults to true
        if NotesManager.isOnline, let note = result {
            addToServer(note: note) { (serverNote) in
                completion?(serverNote)
            }
        } else {
            completion?(result)
        }
    }

    func addToServer(note: CDNote, completion: @escaping SyncCompletionBlockWithNote) {
        let newNote = note
        var result: CDNote?
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let router = Router.createNote(paramters: parameters)
        NoteSessionManager
            .shared
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseDecodable { (response: DataResponse<NoteStruct>) in
                switch response.result {
                case .success:
                    if let note = response.value {
                        newNote.id = note.id
                        newNote.modified = note.modified
                        newNote.title = note.title
                        newNote.content = note.content
                        newNote.category = note.category
                        newNote.addNeeded = false
                        newNote.updateNeeded = false
                        result = CDNote.update(note: newNote)
                    }
                case .failure(let error):
                    let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    self.showErrorMessage(message: message)
                    result = newNote
                }
                completion(result)
        }
    }

    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        guard NotesManager.isOnline else {
            completion?()
            return
        }
        let router = Router.getNote(id: Int(note.id), exclude: "")
        NoteSessionManager
            .shared
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseDecodable { (response: DataResponse<NoteStruct>) in
                switch response.result {
                case .success:
                    if let note = response.value {
                        CDNote.update(notes: [note])
                    }
                case .failure(let error):
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            if let guid = note.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                self.addToServer(note: dbNote, completion: { _ in })
                            }
                        default:
                            let message = ErrorMessage(title: NSLocalizedString("Error Getting Note", comment: "The title of an error message"),
                                                       body: error.localizedDescription)
                            self.showErrorMessage(message: message)
                        }
                        
                    }
                }
                completion?()
        }
    }

    func update(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.updateNeeded = true
        if NotesManager.isOnline {
            let parameters: Parameters = ["content": note.content as Any,
                                          "category": note.category as Any,
                                          "modified": Date().timeIntervalSince1970 as Any,
                                          "favorite": note.favorite]
            let router = Router.updateNote(id: Int(note.id), paramters: parameters)
            NoteSessionManager
                .shared
                .request(router)
                .validate(statusCode: 200..<300)
                .validate(contentType: ["application/json"])
                .responseDecodable { (response: DataResponse<NoteStruct>) in
                    switch response.result {
                    case .success:
                        if let note = response.value {
                            CDNote.update(notes: [note])
                        }
                    case .failure(let error):
                        CDNote.update(notes: [incoming])
                        if let urlResponse = response.response {
                            switch urlResponse.statusCode {
                            case 404:
                                if let guid = incoming.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                    self.addToServer(note: dbNote, completion: { _ in })
                                }
                            default:
                                let message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                                           body: error.localizedDescription)
                                self.showErrorMessage(message: message)
                            }
                        }
                    }
                    completion?()
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.deleteNeeded = true
        if NotesManager.isOnline {
            let router = Router.deleteNote(id: Int(note.id))
            NoteSessionManager
                .shared
                .request(router)
                .validate(statusCode: 200..<300)
                .responseData { (response) in
                    switch response.result {
                    case .success:
                        CDNote.delete(note: note)
                    case .failure(let error):
                        var message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        if let urlResponse = response.response {
                            switch urlResponse.statusCode {
                            case 404:
                                //Note doesn't exist on the server but we are obviously
                                //trying to delete it, so let's do that.
                                CDNote.delete(note: note)
                                message.body = ""
                            default:
                                CDNote.update(notes: [incoming])
                            }
                        }
                        if !message.body.isEmpty {
                            self.showErrorMessage(message: message)
                        }
                    }
                    completion?()
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }

    func showErrorMessage(message: ErrorMessage) {
        var config = SwiftMessages.defaultConfig
        config.interactiveHide = true
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.error, iconStyle: .default)
            view.configureDropShadow()
            view.button?.isHidden = true
            view.configureContent(title: message.title,
                                  body: message.body,
                                  iconImage: Icon.error.image
            )
            return view
        })
    }

}
