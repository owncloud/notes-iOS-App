//
//  OCNoteOperationUpdate.m
//  iOCNotes
//
//  Created by Peter Hedlund on 5/22/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import "OCNoteOperationUpdate.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"

@implementation OCNoteOperationUpdate

- (void)performOperation {
    if (!self.isCancelled) {
        NSDictionary *params = @{@"content": self.note.content};
        NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:self.note.id].stringValue];
        [OCAPIClient sharedClient].requestSerializer = [OCAPIClient jsonRequestSerializer];
        [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            if (!self.isCancelled) {
                //                        NSLog(@"Returning from update operation");
                NSDictionary *responseDictionary = (NSDictionary*)responseObject;
                if ([[NSNumber numberWithInt:self.note.id] isEqualToNumber:[responseDictionary objectForKey:@"id"]]) {
                    self.note.title = [responseDictionary objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                    self.note.content = [responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                    self.note.modified = [[responseDictionary objectForKey:@"modified"] doubleValue];
                    self.note.addNeeded = NO;
                    self.note.updateNeeded = NO;
                    if (self.note.existsInDatabase) {
                        [self.note save];
                    }
                }
                
                if (self.delegate) {
                    [self.delegate noteOperationDidFinish:self];
                }
            }
            [self finish];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            if (!self.isCancelled) {
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                switch (response.statusCode) {
                    case 404:
                        self.errorMessage = NSLocalizedString(@"The note does not exist", @"An error message");
                        break;
                    default:
                        self.errorMessage = [error localizedDescription];
                        break;
                }
                if (self.delegate) {
                    [self.delegate noteOperationDidFail:self];
                }
            }
            [self finish];
        }];
    }
}

@end
