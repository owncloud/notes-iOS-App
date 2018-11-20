//
//  OCNoteOperationGet.m
//  iOCNotes
//
//  Created by Peter Hedlund on 5/22/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import "OCNoteOperationGet.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"

@implementation OCNoteOperationGet

- (void)performOperation {
    if (!self.isCancelled) {
        NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:self.note.id].stringValue];
        __block OCNote *noteToGet = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [NSNumber numberWithInt:self.note.id]]];
        if (noteToGet) {
            NSDictionary *params = @{@"exclude": @"title,content"};
            [OCAPIClient sharedClient].requestSerializer = [OCAPIClient jsonRequestSerializer];
            [[OCAPIClient sharedClient] GET:path parameters:params progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                if (!self.isCancelled) {
                    NSDictionary *noteDict = (NSDictionary*)responseObject;
//                    NSLog(@"NoteDict: %@", noteDict);
                    if ([[NSNumber numberWithInt:noteToGet.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                        if ([[noteDict objectForKeyNotNull:@"modified" fallback:[self dateAsNumber]] doubleValue] > noteToGet.modified) {
                            //The server has a newer version. We need to get it.
                            [OCAPIClient sharedClient].requestSerializer = [OCAPIClient httpRequestSerializer];
                            [[OCAPIClient sharedClient] GET:path parameters:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                                if (!self.isCancelled) {
                                    NSDictionary *responseDictionary = (NSDictionary*)responseObject;
                                    if ([[NSNumber numberWithInt:self.note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                        if ([[noteDict objectForKeyNotNull:@"modified" fallback:[self dateAsNumber]] doubleValue] > self.note.modified) {
                                            if ([self.note existsInDatabase]) {
                                                [self.note save:^{
                                                    self.note.title = [responseDictionary objectForKeyNotNull:@"title" fallback:@""];
                                                    self.note.content = [responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                                                    self.note.modified = [[responseDictionary objectForKeyNotNull:@"modified" fallback:[self dateAsNumber]] doubleValue];
                                                }];
                                            }
                                        }
                                    }
                                    if (self.delegate) {
                                        [self.delegate noteOperationDidFinish:self];
                                    }
                                }
                                [self finish];
                            } failure:^(NSURLSessionDataTask *task, NSError *error) {
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
                                [self finish];
                            }];
                        } else {
                            if (self.delegate) {
                                [self.delegate noteOperationDidFinish:self];
                            }
                        }
                    }
                }
                [self finish];
                //                            //NSLog(@"Note: %@", responseObject);
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
        
        [self finish];
    }
}

@end
