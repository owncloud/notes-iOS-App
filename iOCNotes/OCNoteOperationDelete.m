//
//  OCNoteOperationDelete.m
//  iOCNotes
//
//  Created by Peter Hedlund on 5/22/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import "OCNoteOperationDelete.h"
#import "OCAPIClient.h"

@implementation OCNoteOperationDelete

- (void)performOperation {
    if (!self.isCancelled) {
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
    }
}

@end

@implementation OCNoteOperationDeleteSimple

- (void)performOperation {
    if (!self.isCancelled) {
        [self.note delete];
        if (self.delegate) {
            [self.delegate noteOperationDidFinish:self];
        }
        [self finish];
    }
}

@end
