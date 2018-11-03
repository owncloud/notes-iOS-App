//
//  NoteOperationGet.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

class NoteOperationGet: NoteOperation {

    override func performOperation() {
        if self.isCancelled == true {
            return
        }
        let params = [NoteKeys.exclude: "\(NoteKeys.title),\(NoteKeys.content)"]
        let path = "notes/\(self.note.serverId)"
        OCAPIClient.shared().requestSerializer = OCAPIClient.jsonRequestSerializer()
        OCAPIClient.shared().get(path, parameters: params, progress: nil, success: { (task, responseObject) in
            if (!self.isCancelled) {
                if let responseDictionary = responseObject as? [String: Any] {
                    if self.note.serverId == responseDictionary[NoteKeys.serverId] as? Int64 ?? 0 {
                        if responseDictionary[NoteKeys.modified] as? TimeInterval ??  0 > self.note.modified {
                            //The server has a newer version. We need to get it.
                            OCAPIClient.shared().get(path, parameters: nil, progress: nil, success: { (task, responseObject) in
                                if (!self.isCancelled) {
                                    if let responseDictionary = responseObject as? [String: Any] {
                                        if self.note.serverId == responseDictionary[NoteKeys.serverId] as? Int64 ?? 0 {
                                            if responseDictionary[NoteKeys.modified] as? TimeInterval ??  0 > self.note.modified {
                                                NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                                                    self?.note.title = responseDictionary[NoteKeys.title] as? String ?? ""
                                                    self?.note.content = responseDictionary[NoteKeys.content] as? String ?? ""
                                                    self?.note.modified = responseDictionary[NoteKeys.modified] as? Double ?? Date().timeIntervalSince1970
                                                })
                                            }
                                        }
                                    }
                                    NotificationCenter.default.post(name: NetworkSuccess, object: nil)
                                }
                                self.finish(true)
                            }, failure: { (task, error) in
                                if let response = task?.response as? HTTPURLResponse {
                                    switch response.statusCode {
                                    case 404:
                                        self.errorMessage = NSLocalizedString("The note does not exist", comment: "An error message");
                                    default:
                                        self.errorMessage = error.localizedDescription
                                    }
                                    
                                    self.delegate?.didFail(operation: self)
                                }
                                self.finish(true)
                            })
                        } else {
                            NotificationCenter.default.post(name: NetworkSuccess, object: nil)
                        }
                    }
                }
            }
            self.finish(true)
        }) { (task, error) in
            if (!self.isCancelled) {
                if let response = task?.response as? HTTPURLResponse {
                    switch response.statusCode {
                    case 404:
                        self.errorMessage = NSLocalizedString("The note does not exist", comment: "An error message");
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    
                    self.delegate?.didFail(operation: self)
                }
                self.finish(true)
                
            }
            self.finish(true)

        }
    }

}
