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
typealias SyncCompletionBlockWithRetry = (_ retry: Bool) -> Void

struct ErrorMessage {
    var title: String
    var body: String
}

final class CustomServerTrustPolicyManager: ServerTrustManager {
    override func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        let server = KeychainHelper.server
        if KeychainHelper.allowUntrustedCertificate,
            !host.isEmpty,
            let serverHost = URLComponents(string: server)?.host,
            host == serverHost {
            return DisabledEvaluator()
        } else {
            return DefaultTrustEvaluator()
        }
    }
}

class NotesManager {
    
    struct NoteError: Error {
        var retry: Bool
        var message: ErrorMessage
    }
    
    enum Result<CDNote, NoteError> {
        case success(CDNote?)
        case failure(NoteError)
    }

    typealias SyncHandler = (Result<CDNote, NoteError>) -> Void

    static let shared = NotesManager()

    private var session: Session

    class var isConnectedToInternet: Bool {
        return NetworkReachabilityManager(host: KeychainHelper.server)?.isReachable ?? false
    }

    class var isOnline: Bool {
        return NotesManager.isConnectedToInternet && !KeychainHelper.offlineMode
    }
    
    init() {
        session = Session(serverTrustManager: CustomServerTrustPolicyManager(allHostsMustBeEvaluated: true, evaluators: [:]))
    }
    
    func updateSession() {
        if KeychainHelper.allowUntrustedCertificate {
        let manager = ServerTrustManager(evaluators: [KeychainHelper.server: DisabledEvaluator()])
            session = Session(serverTrustManager: manager)
        } else {
            session = Session()
        }
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
                    self.session
                        .request(router)
                        .validate(statusCode: 200..<300)
                        .validate(contentType: [Router.applicationJson])
                        .responseDecodable(of: [NoteStruct].self) { response in
                            switch response.result {
                            case let .success(notes):
                                let serverIds = notes.map( { $0.id } )
                                if let knownIds = CDNote.all()?.map({ $0.id }).filter({ $0 > 0 }) {
                                    let deletedOnServer = Set(knownIds).subtracting(Set(serverIds))
                                    if !deletedOnServer.isEmpty {
                                        _ = CDNote.delete(ids: Array(deletedOnServer))
                                    }
                                }
                                CDNote.update(notes: notes)
                            case let .failure(error):
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
        if  let incoming = CDNote.update(note: note) { //addNeeded defaults to true
            self.add(note: incoming, completion: completion)
        }
    }

    func add(note: CDNote, completion: SyncCompletionBlockWithNote? = nil) {
        if NotesManager.isOnline {
            addToServer(note: note) { [weak self] result in
                switch result {
                case .success(let newNote):
                    completion?(newNote)
                case .failure(let error):
                    if error.retry {
                        KeychainHelper.server += "/index.php"
                        self?.addToServer(note: note) { result2 in
                            // only one retry
                            switch result2 {
                            case .success(let newNote):
                                completion?(newNote)
                            case .failure(let error):
                                self?.showErrorMessage(message: error.message)
                                completion?(note)
                            }
                        }
                    } else {
                        self?.showErrorMessage(message: error.message)
                        completion?(note)

                    }
                }
            }
        } else {
            completion?(note)
        }
    }

    func addToServer(note: CDNote, handler: @escaping SyncHandler) {
        let newNote = note
        var result: CDNote?
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let canRetry = !KeychainHelper.server.hasSuffix(".php")
        let router = Router.createNote(parameters: parameters)
        session
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self) { response in
                switch response.result {
                case let .success(note):
                    newNote.id = note.id
                    newNote.modified = note.modified
                    newNote.title = note.title
                    newNote.content = note.content
                    newNote.category = note.category
                    newNote.addNeeded = false
                    newNote.updateNeeded = false
                    result = CDNote.update(note: newNote)
                    handler(.success(result))
                case let .failure(error):
                    let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 405:
                            handler(.failure(NoteError(retry: canRetry, message: message)))
                        default:
                            handler(.failure(NoteError(retry: false, message: message)))
                        }
                    } else {
                        handler(.failure(NoteError(retry: false, message: message)))
                    }
                }
        }
    }

    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        guard NotesManager.isOnline else {
            completion?()
            return
        }
        let router = Router.getNote(id: Int(note.id), exclude: "", etag: note.etag)
        session
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self) { response in
                switch response.result {
                case let .success(note):
                    CDNote.update(notes: [note])
                case let .failure(error):
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 304:
                            // Not modified. Do nothing.
                            break
                        case 404:
                            if let guid = note.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                self.add(note: dbNote, completion: nil)
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
            updateOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    if error.retry {
                        KeychainHelper.server += "/index.php"
                        self?.updateOnServer(note) { result2 in
                            // only one retry
                            switch result2 {
                            case .success( _):
                                completion?()
                            case .failure(let error):
                                self?.showErrorMessage(message: error.message)
                                completion?()
                            }
                        }
                    } else {
                        self?.showErrorMessage(message: error.message)
                        completion?()
                    }
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }
    
    fileprivate func updateOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let parameters: Parameters = ["content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": Date().timeIntervalSince1970 as Any,
                                      "favorite": note.favorite]
        let canRetry = !KeychainHelper.server.hasSuffix(".php")
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)
        session
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self) { response in
                switch response.result {
                case let .success(note):
                    CDNote.update(notes: [note])
                    handler(.success(nil))
                case let .failure(error):
                    CDNote.update(notes: [note])
                    let message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            if let guid = note.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                self.add(note: dbNote, completion: nil)
                            }
                            handler(.success(nil))
                        case 405:
                            handler(.failure(NoteError(retry: canRetry, message: message)))
                        default:
                            handler(.failure(NoteError(retry: false, message: message)))
                        }
                    } else {
                        handler(.failure(NoteError(retry: false, message: message)))
                    }
                }
        }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.deleteNeeded = true
        if NotesManager.isOnline {
            deleteOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    if error.retry {
                        KeychainHelper.server += "/index.php"
                        self?.deleteOnServer(note) { result2 in
                            // only one retry
                            switch result2 {
                            case .success( _):
                                completion?()
                            case .failure(let error):
                                self?.showErrorMessage(message: error.message)
                                completion?()
                            }
                        }
                    } else {
                        self?.showErrorMessage(message: error.message)
                        completion?()
                    }
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }

    fileprivate func deleteOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let canRetry = !KeychainHelper.server.hasSuffix(".php")
        let router = Router.deleteNote(id: Int(note.id))
        session
            .request(router)
            .validate(statusCode: 200..<300)
            .responseData { (response) in
                switch response.result {
                case .success:
                    CDNote.delete(note: note)
                    handler(.success(nil))
                case .failure(let error):
                    let message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            //Note doesn't exist on the server but we are obviously
                            //trying to delete it, so let's do that.
                            CDNote.delete(note: note)
                            handler(.success(nil))
                        case 405:
                            CDNote.update(notes: [note])
                            handler(.failure(NoteError(retry: canRetry, message: message)))
                        default:
                            CDNote.update(notes: [note])
                            handler(.failure(NoteError(retry: false, message: message)))
                        }
                    }
                    if !message.body.isEmpty {
                        self.showErrorMessage(message: message)
                    }
                }
        }
    }
    
    func showErrorMessage(message: ErrorMessage) {
        #if !os(OSX)
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
        #endif
    }

}
