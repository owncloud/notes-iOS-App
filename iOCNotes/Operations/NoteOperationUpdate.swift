//
//  NoteOperationUpdate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

class NoteOperationUpdate: NoteOperation {

    override func performOperation() {
        if self.isCancelled == true {
            return
        }
        let params = [NoteKeys.content: self.note.content]
        let path = "notes/\(self.note.serverId)"
        OCAPIClient.shared().requestSerializer = OCAPIClient.jsonRequestSerializer()
        OCAPIClient.shared().put(path, parameters: params, success: { (task, responseObject) in
            if !self.isCancelled {
                if let responseDictionary = responseObject as? [String: Any] {
                    if self.note.serverId == responseDictionary[NoteKeys.serverId] as? Int64 ?? 0 {
                        NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                            self?.note.title = responseDictionary[NoteKeys.title] as? String ?? NSLocalizedString("New note", comment: "The title of a new note")
                            self?.note.content = responseDictionary[NoteKeys.content] as? String ?? ""
                            self?.note.modified = responseDictionary[NoteKeys.modified] as? TimeInterval ?? Date().timeIntervalSince1970
                            self?.note.favorite = responseDictionary[NoteKeys.favorite] as? Bool ?? false
                            self?.note.category = responseDictionary[NoteKeys.category] as? String ?? ""
                            self?.note.addNeeded = false
                            self?.note.updateNeeded = false
                        })
                    }
                }
                NotificationCenter.default.post(name: NetworkSuccess, object: nil)
            }
            self.finish(true)
        }) { (task, error) in
            if !self.isCancelled {
                if let response = task?.response as? HTTPURLResponse {
                    switch response.statusCode {
                    case 404:
                        self.errorMessage = NSLocalizedString("The note does not exist", comment: "An error message")
                        break;
                    default:
                        self.errorMessage = error.localizedDescription
                        break;
                    }
                }
                if let delegate = self.delegate {
                    delegate.didFail(operation: self)
                }
            }
            self.finish(true)
        }
    }
    
}
