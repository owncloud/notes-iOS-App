//
//  OCNoteOperationAdd.m
//  iOCNotes
//
//  Created by Peter Hedlund on 5/22/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import "OCNoteOperationAdd.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"

@implementation OCNoteOperationAdd

- (void)performOperation {
    if (!self.isCancelled) {
        NSDictionary *params = @{@"content": self.note.content};
        [OCAPIClient sharedClient].requestSerializer = [OCAPIClient jsonRequestSerializer];
        [[OCAPIClient sharedClient] POST:@"notes" parameters:params progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            if (!self.isCancelled) {
                //                        NSLog(@"Returning from add operation");
                NSDictionary *responseDictionary = (NSDictionary*)responseObject;
                self.note.id = [[responseDictionary objectForKey:@"id"] intValue];
                self.note.modified = [[responseDictionary objectForKey:@"modified"] doubleValue];
                self.note.title = [responseDictionary objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
//                self.note.content = [responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                self.note.addNeeded = NO;
                self.note.updateNeeded = NO;
                [self.note save];
                
                if (self.delegate) {
                    [self.delegate noteOperationDidFinish:self];
                }
            }
            [self finish];
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            if (!self.isCancelled) {
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                switch (response.statusCode) {
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
