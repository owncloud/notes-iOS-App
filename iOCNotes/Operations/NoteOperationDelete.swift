//
//  NoteOperationDelete.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

class NoteOperationDelete: NoteOperation {

    override func performOperation() {
        if self.isCancelled == true {
            return
        }
        let path = "notes/\(self.note.serverId)"
        OCAPIClient.shared().requestSerializer = OCAPIClient.httpRequestSerializer()
        OCAPIClient.shared().delete(path, parameters: nil, success: { (task, responseObject) in
            if self.isCancelled == false {
                NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                    context.delete((self?.note)!)
                })
                NotificationCenter.default.post(name: NetworkSuccess, object: nil)
                self.finish(true)
            }
        }) { (task, error) in
            if self.isCancelled == false {
                if let response = task?.response as? HTTPURLResponse {
                    switch response.statusCode {
                    case 404:
                        NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                            context.delete((self?.note)!)
                        })
                        NotificationCenter.default.post(name: NetworkSuccess, object: nil)
                    default:
                        self.errorMessage = error.localizedDescription
                        self.delegate?.didFail(operation: self)
                    }
                    
                }
                self.finish(true)
            }
        }
    }

}

class NoteOperationDeleteSimple: NoteOperation {
    
    override func performOperation() {
        if self.isCancelled == false {
            NotesManager.shared.enqueueCoreDataBlock({ [weak self] (context)  in
                context.delete((self?.note)!)
            })
            NotificationCenter.default.post(name: NetworkSuccess, object: nil)
            self.finish(true)
        }
    }

}
