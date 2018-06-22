//
//  NoteOperationDelete.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import UIKit

class NoteOperationDelete: NoteOperation {

    override func performOperation() {
        if self.isCancelled == true {
            return
        }
/*
        NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:self.note.id].stringValue];
        [OCAPIClient sharedClient].requestSerializer = [OCAPIClient httpRequestSerializer];
        [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            if (!self.isCancelled) {
            [self.note delete];
            if (self.delegate) {
            [self.delegate noteOperationDidFinish:self];
            }
            }
            [self finish];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
            if (!self.isCancelled) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            //            NSLog(@"Status code: %ld", (long)response.statusCode);
            switch (response.statusCode) {
            case 404:
            //Note doesn't exist on the server but we are obviously
            //trying to delete it, so let's do that.
            if (self.note.existsInDatabase) {
            [self.note delete];
            }
            if (self.delegate) {
            [self.delegate noteOperationDidFinish:self];
            }
            break;
            default:
            self.errorMessage = [error localizedDescription];
            if (self.delegate) {
            [self.delegate noteOperationDidFail:self];
            }
            break;
            }
            }
            [self finish];
            }];
 */
    }

}
