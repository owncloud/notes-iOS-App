//
//  NoteOperationAdd.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import UIKit

class NoteOperationAdd: NoteOperation {
    
    override func performOperation() {
        if self.isCancelled == true {
            return
        }
        let params = ["content": self.note.content]
        OCAPIClient.shared().requestSerializer = OCAPIClient.jsonRequestSerializer()
        OCAPIClient.shared().post("notes", parameters: params, progress: nil, success: { (task, response) in
            if self.isCancelled == false {
                /*
                 if ([responseObject isKindOfClass:[NSDictionary class]]) {
                 NSDictionary *responseDictionary = (NSDictionary*)responseObject;
                 [self.note save:^{
                 self.note.id = [[responseDictionary objectForKey:@"id"] intValue];
                 self.note.modified = [[responseDictionary objectForKey:@"modified"] doubleValue];
                 self.note.title = [responseDictionary objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                 self.note.addNeeded = NO;
                 self.note.updateNeeded = NO;
                 }];
                 
                 if (self.delegate) {
                 [self.delegate noteOperationDidFinish:self];
                 }
                 } else {
                 if (self.delegate) {
                 self.errorMessage = NSLocalizedString(@"Failed to create note on server", @"An error message");
                 [self.delegate noteOperationDidFail:self];
                 }
                 }
                 }
                 */
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
