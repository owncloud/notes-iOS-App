//
//  NoteOperationAdd.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

class NoteOperationAdd: NoteOperation {
    
    override func performOperation() {
        if self.isCancelled == true {
            return
        }
        let params = [NoteKeys.content: self.note.content]
        OCAPIClient.shared().requestSerializer = OCAPIClient.jsonRequestSerializer()
        OCAPIClient.shared().post("notes", parameters: params, progress: nil, success: { (task, response) in
            if self.isCancelled == false {
                
                if let responseDictionary = response as? [String: Any] {
                    NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                        self?.note.serverId = responseDictionary[NoteKeys.serverId] as! Int64
                        self?.note.title = responseDictionary[NoteKeys.title] as? String ?? NSLocalizedString("New note", comment: "The title of a new note")
                        self?.note.modified = responseDictionary[NoteKeys.modified] as? TimeInterval ?? Date().timeIntervalSince1970
                        self?.note.favorite = responseDictionary[NoteKeys.favorite] as? Bool ?? false
                        self?.note.category = responseDictionary[NoteKeys.category] as? String ?? ""
                        self?.note.addNeeded = false
                        self?.note.updateNeeded = false
                    })
                    if let delegate = self.delegate {
                        delegate.didFinish(operation: self)
                    }
                 } else {
                    if let delegate = self.delegate {
                        self.errorMessage = NSLocalizedString("Failed to create note on server", comment: "An error message");
                        delegate.didFail(operation: self)
                    }
                 }
            }
        
            self.finish(true)
            
        }) { (task, error) in
            if self.isCancelled == false {
                if let response = task?.response as? HTTPURLResponse {
                    switch response.statusCode {
                        
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    self.delegate?.didFail(operation: self)
                }
                self.finish(true)
            }
        }
    }
    
}
