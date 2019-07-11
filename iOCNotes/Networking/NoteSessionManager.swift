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
    
    func add(content: String, category: String?, favorite: Bool? = false, completion: SyncCompletionBlockWithNote? = nil) {
        let note = NoteStruct(content: content, category: category, favorite: favorite ?? false)
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let result = CDNote.update(note: note)
        let router = Router.createNote(paramters: parameters)
        NoteSessionManager
            .shared
            .request(router)
            .validate(statusCode: 201..<202)
            .validate(contentType: ["application/json"])
            .responseDecodable { (response: DataResponse<NoteStruct>) in
                switch response.result {
                case .success:
                    if let note = response.value, let newNote = result {
                        newNote.id = note.id
                        newNote.modified = note.modified
                        newNote.title = note.title
                        newNote.content = note.content
                        newNote.addNeeded = false
                        newNote.updateNeeded = false
                        let result = CDNote.update(note: newNote)
                        completion?(result)
                    }
                case .failure(let error):
                    let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    self.showErrorMessage(message: message)
                }
                completion?(result)
        }
    }
    
    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
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
                    var message = ErrorMessage(title: NSLocalizedString("Error Getting Note", comment: "The title of an error message"),
                                               body: "")
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            message.body = NSLocalizedString("The note does not exist", comment: "An error message")
                        default:
                            message.body = error.localizedDescription
                        }
                    } else {
                        message.body = NSLocalizedString("The note does not exist", comment: "An error message")
                    }
                    self.showErrorMessage(message: message)
                }
                completion?()
        }
    }
    
    func update(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.updateNeeded = true
        CDNote.update(notes: [incoming])
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category ?? "" as Any,
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
                    var message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                               body: "")
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            message.body = NSLocalizedString("The note does not exist", comment: "An error message")
                        default:
                            message.body = error.localizedDescription
                        }
                    } else {
                        message.body = NSLocalizedString("The note does not exist", comment: "An error message")
                    }
                    self.showErrorMessage(message: message)
                }
                completion?()
        }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.deleteNeeded = true
        CDNote.update(notes: [incoming])
        let router = Router.deleteNote(id: Int(note.id))
        NoteSessionManager
            .shared
            .request(router)
            .validate(statusCode: 200..<300)
            .responseData { (response) in
                switch response.result {
                case .success:
                    CDNote.delete(ids: [note.id], in: NotesData.mainThreadContext)
                case .failure(let error):
                    var message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                               body: "")
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            //Note doesn't exist on the server but we are obviously
                            //trying to delete it, so let's do that.
                            CDNote.delete(ids: [note.id], in: NotesData.mainThreadContext)
                        default:
                            message.body = error.localizedDescription
                        }
                    }
                    if !message.body.isEmpty {
                        self.showErrorMessage(message: message)
                    }
                }
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
