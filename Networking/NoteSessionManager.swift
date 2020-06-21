//
//  NoteSessionManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/6/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Alamofire
import Foundation
#if os(iOS)
import UIKit
import SwiftMessages
#else
import AppKit
#endif

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
            return DisabledTrustEvaluator()
        } else {
            return DefaultTrustEvaluator()
        }
    }
}

final class LoginRequestInterceptor: RequestInterceptor {

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let _ = request.request?.url else {
            return completion(.doNotRetryWithError(error))
        }
        
        let serverAddress = KeychainHelper.server
        if !serverAddress.hasSuffix(".php") {
            KeychainHelper.server = "\(serverAddress)/index.php"
            completion(.retry)
        } else {
            completion(.doNotRetryWithError(error))
        }
    }

}

final class NoteRequestInterceptor: RequestInterceptor {

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let _ = request.request?.url,
            let afError = error as? AFError else {
            return completion(.doNotRetryWithError(error))
        }
        
        if afError.responseCode == 405 {
            let serverAddress = KeychainHelper.server
            if !serverAddress.hasSuffix(".php") {
                KeychainHelper.server = "\(serverAddress)/index.php"
                completion(.retry)
            } else {
                completion(.doNotRetryWithError(error))
            }
        } else {
            completion(.doNotRetryWithError(error))
        }
    }

}

class NoteSessionManager {
    
    struct NoteError: Error {
        var message: ErrorMessage
    }
    
    enum Result<CDNote, NoteError> {
        case success(CDNote?)
        case failure(NoteError)
    }

    typealias SyncHandler = (Result<CDNote, NoteError>) -> Void

    static let shared = NoteSessionManager()

    private var session: Session

    class var isConnectedToInternet: Bool {
        return NetworkReachabilityManager()?.isReachable ?? false
    }

    class var isConnectedToServer: Bool {
        guard let url = URL(string: KeychainHelper.server),
            let host = url.host else {
            return false
        }
        return NetworkReachabilityManager(host: host)?.isReachable ?? false
    }

    class var isOnline: Bool {
        return NoteSessionManager.isConnectedToServer && !KeychainHelper.offlineMode
    }
    
    init() {
        session = Session(serverTrustManager: CustomServerTrustPolicyManager(allHostsMustBeEvaluated: true, evaluators: [:]))
    }

    func status(server: String, username: String, password: String, completion: SyncCompletionBlock? = nil) {
        var serverAddress = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
            !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        
        let router = StatusRouter.status
        session
            .request(router)
            .validate(contentType: [Router.applicationJson])
//                        .responseString(completionHandler: { (response) in
//                            print(response)
//                        })
            .responseDecodable(of: CloudStatus.self) { response in
                switch response.result {
                case let .success(result):
                    KeychainHelper.productVersion = result.versionstring
                    KeychainHelper.productName = result.productname
                case let .failure(error):
                    print(error.localizedDescription)
                }
                completion?()
        }
    }

    func capabilities(server: String, username: String, password: String, completion: SyncCompletionBlock? = nil) {
        var serverAddress = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
            !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password

        let router = OCSRouter.capabilities
        session
            .request(router)
            .validate(contentType: [Router.applicationJson])
//            .responseString(completionHandler: { (response) in
//                print(response)
//            })
            .responseDecodable(of: OCS.self) { [weak self] response in
                switch response.result {
                case let .success(result):
                    KeychainHelper.notesApiVersion = result.data.notes.api_version.last ?? Router.defaultApiVersion
                    KeychainHelper.notesVersion = result.data.notes.version
                    KeychainHelper.productVersion = result.data.version.string
                    self?.showSyncMessage()
                case let .failure(error):
                    KeychainHelper.notesApiVersion = Router.defaultApiVersion
                    print(error.localizedDescription)
                }
                completion?()
        }
    }

    func login(server: String, username: String, password: String, completion: SyncCompletionBlock? = nil) {
        var serverAddress = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
            !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        
        let router = Router.allNotes(exclude: "")
        session
            .request(router, interceptor: LoginRequestInterceptor())
            .validate(contentType: [Router.applicationJson])
            .responseJSON(completionHandler: { [weak self] response in
                var message: String?
                var title: String?
                switch response.result {
                case let .success(result):
                    if let jsonArray = result as? Array<[String: Any]> {
                        if !jsonArray.isEmpty {
                            self?.showSyncMessage()
                        } else {
                            self?.pickServer()
                        }
                    }
                case let .failure(error):
                    KeychainHelper.server = ""
                    KeychainHelper.username = ""
                    KeychainHelper.password = ""
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 200:
                            title = NSLocalizedString("Notes not found", comment: "An error message title")
                            message = NSLocalizedString("Notes could not be found on your server. Make sure it is installed and enabled", comment: "An error message");
                        case 401:
                            title = NSLocalizedString("Unauthorized", comment: "An error message title")
                            message = NSLocalizedString("Check username and password.", comment: "An error message")
                        case 404:
                            title = NSLocalizedString("Server not found", comment: "An error message title")
                            message = NSLocalizedString("A server installation could not be found. Check the server address.", comment: "An error message")
                        default:
                            title = NSLocalizedString("Connection failure", comment: "An error message title")
                            message = error.localizedDescription
                        }
                    } else {
                        title = NSLocalizedString("Connection failure", comment: "An error message title")
                        message = error.localizedDescription
                    }
                    if let title = title, let body = message {
                        NoteSessionManager.shared.showErrorMessage(message: ErrorMessage(title: title, body: body))
                    }
                }
                completion?()
        })
    }
    
    func sync(completion: SyncCompletionBlock? = nil) {

        func deleteOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToDelete = CDNote.notes(property: "cdDeleteNeeded"),
                !notesToDelete.isEmpty {
                let group = DispatchGroup()
                
                for note in notesToDelete {
                    group.enter()
                    NoteSessionManager.shared.delete(note: note, completion: {
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
                    NoteSessionManager.shared.update(note: note, completion: {
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
                        .responseJSON(completionHandler: { response in
                            switch response.result {
                            case let .success(json):
                                if let allHeaders = response.response?.allHeaderFields {
                                    if let lmIndex = allHeaders.index(forKey: "Last-Modified"),
                                        let lastModifiedString = allHeaders[lmIndex].value as? String {
                                        let dateFormatter = DateFormatter()
                                        dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
                                        let lastModifiedDate = dateFormatter.date(from: lastModifiedString) ?? Date.distantPast
                                        KeychainHelper.lastModified = Int(lastModifiedDate.timeIntervalSince1970)
                                        
                                    }
                                    if let etagIndex = allHeaders.index(forKey: "Etag"),
                                        let etag = allHeaders[etagIndex].value as? String {
                                        KeychainHelper.eTag = etag
                                    }
                                }
                                if let jsonArray = json as? Array<[String: Any]> {
                                    print(jsonArray)
                                    if let serverIds = jsonArray.map( { $0["id"] }) as? [Int64],
                                        let knownIds = CDNote.all()?.map({ $0.id }).filter({ $0 > 0 }) {
                                        let deletedOnServer = Set(knownIds).subtracting(Set(serverIds))
                                        if !deletedOnServer.isEmpty {
                                            _ = CDNote.delete(ids: Array(deletedOnServer))
                                        }
                                    }
                                    let filteredDicts = jsonArray.filter({ $0.keys.count > 1 })
                                    if !filteredDicts.isEmpty {
                                        var notes = [NoteStruct]()
                                        for noteDict in filteredDicts {
                                            notes.append(NoteStruct(dictionary: noteDict))
                                        }
                                        CDNote.update(notes: notes)
                                    }
                                }
                            case let .failure(error):
                                if error.isResponseValidationError {
                                    switch error.responseCode {
                                    case 304:
                                        // Not modified, do nothing
                                        break
                                    default:
                                        let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                                   body: error.localizedDescription)
                                        self.showErrorMessage(message: message)
                                    }
                                } else {
                                    let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                               body: error.localizedDescription)
                                    self.showErrorMessage(message: message)
                                }
                            }
                            completion?()
                        })
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
        if NoteSessionManager.isOnline {
            addToServer(note: note) { [weak self] result in
                switch result {
                case .success(let newNote):
                    completion?(newNote)
                case .failure(let error):
                    self?.showErrorMessage(message: error.message)
                    completion?(note)
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
        let router = Router.createNote(parameters: parameters)
        session
            .request(router, interceptor: NoteRequestInterceptor())
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
                    handler(.failure(NoteError(message: message)))
                }
        }
    }

    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        guard NoteSessionManager.isOnline else {
            completion?()
            return
        }
        let router = Router.getNote(id: Int(note.id), exclude: "", etag: note.etag)
        let validStatusCode = KeychainHelper.notesApiVersion == Router.defaultApiVersion ? 200..<300 : 200..<201
        session
            .request(router)
            .validate(statusCode: validStatusCode)
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
//                        case 400:
                            // Bad request (invalid ID)
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
        if NoteSessionManager.isOnline {
            updateOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    self?.showErrorMessage(message: error.message)
                    completion?()
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }
    
    fileprivate func updateOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": Date().timeIntervalSince1970 as Any,
                                      "favorite": note.favorite]
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)
        session
            .request(router, interceptor: NoteRequestInterceptor())
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
                        default:
                            handler(.failure(NoteError(message: message)))
                        }
                    } else {
                        handler(.failure(NoteError(message: message)))
                    }
                }
        }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        var incoming = note
        incoming.deleteNeeded = true
        if incoming.addNeeded {
            CDNote.delete(note: incoming)
            completion?()
        } else if NoteSessionManager.isOnline {
            deleteOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    self?.showErrorMessage(message: error.message)
                    completion?()
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }

    fileprivate func deleteOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let router = Router.deleteNote(id: Int(note.id))
        session
            .request(router, interceptor: NoteRequestInterceptor())
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
                        default:
                            CDNote.update(notes: [note])
                            handler(.failure(NoteError(message: message)))
                        }
                    }
                    if !message.body.isEmpty {
                        self.showErrorMessage(message: message)
                    }
                }
        }
    }
    
    func pickServer() {
        #if os(iOS)
        let alert = UIAlertController(title: NSLocalizedString("Server", comment: "Alert title for selecting server brand"),
                                      message: NSLocalizedString("Unable to automatically detect type of server.\nPlease select:", comment: "Alert message for selecting server brand"),
                                      preferredStyle: .alert)
        let nextCloudAction = UIAlertAction(title: "NextCloud", style: .default) { [weak self] (_) in
            KeychainHelper.productName = "Nextcloud"
            self?.showSyncMessage()
        }
        let ownCloudAction = UIAlertAction(title: "ownCloud", style: .default) { [weak self] (_) in
            KeychainHelper.productName = "ownCloud"
            self?.showSyncMessage()
        }
        alert.addAction(nextCloudAction)
        alert.addAction(ownCloudAction)
        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
        #else
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Server", comment: "Alert title for selecting server brand")
        alert.informativeText = NSLocalizedString("Unable to automatically detect type of server.\nPlease select:", comment: "Alert message for selecting server brand")
        alert.addButton(withTitle: "Nextcloud")
        alert.addButton(withTitle: "ownCloud")
        alert.buttons[0].keyEquivalent = "n"
        alert.buttons[1].keyEquivalent = "o"
        alert.beginSheetModal(for: NSApp.keyWindow!) { response in
            switch response {
            case .alertFirstButtonReturn:
                KeychainHelper.isNextCloud = true
            case .alertSecondButtonReturn:
                KeychainHelper.isNextCloud = false
            default:
                KeychainHelper.isNextCloud = true
            }
        }
        #endif
    }

    func showSyncMessage() {
        #if os(iOS)
        var config = SwiftMessages.defaultConfig
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        config.presentationContext = .viewController(UIApplication.topViewController()!)
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.success, iconStyle: .default)
            view.configureDropShadow()
            view.configureContent(title: NSLocalizedString("Success", comment: "A message title"),
                                  body: NSLocalizedString("You are now connected to Notes on your server", comment: "A message"),
                                  iconImage: Icon.success.image,
                                  iconText: nil,
                                  buttonImage: nil,
                                  buttonTitle: NSLocalizedString("Close & Sync", comment: "Title of a button allowing the user to close the login screen and sync with the server"),
                                  buttonTapHandler: { _ in
                                    SwiftMessages.hide()
                                    UIApplication.topViewController()?.dismiss(animated: true, completion: nil)
                                    NotificationCenter.default.post(name: .syncNotes, object: nil)
            })
            return view
        })
        #endif
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
