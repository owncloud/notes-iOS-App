//
//  OCNoteOperation.m
//  iOCNotes
//
//  Created by Peter Hedlund on 4/27/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import "OCNoteOperation.h"
#import "OCNote.h"
#import "OCAPIClient.h"

@interface OCNoteOperation ()
{
    NoteOperationType _noteOperationType;
    BOOL _isFinished;
    BOOL _isExecuting;
}

- (void)finish;

@end

@implementation OCNoteOperation

@synthesize note = _note;
@synthesize delegate = _delegate;
@synthesize errorMessage = _errorMessage;
@synthesize responseDictionary = _responseDictionary;
@synthesize noteOperationType = _noteOperationType;

-(id)initWithNote:(OCNote *)note noteOperationType:(NoteOperationType)operationType delegate:(id<OCNoteOperationDelegate>)theDelegate {
    if ((self = [self init])) {
        _note = note;
        _noteOperationType = operationType;
        _delegate = theDelegate;
        _errorMessage = nil;
        _responseDictionary = nil;
        _noteOperationType = operationType;
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    
    if (self.isCancelled) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self performOperation];
}

- (void)finish {    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

- (void)performOperation {
    if (!self.isCancelled) {

        switch (_noteOperationType) {
            case NoteOperationTypeAdd:
            {
                NSDictionary *params = @{@"content": _note.content};
                [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                    if (!self.isCancelled) {
                        _responseDictionary = (NSDictionary*)responseObject;
                        if (_delegate) {
                            [_delegate noteOperationDidFinish:self];
                        }
                    }
                    [self finish];
                    
                } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    if (!self.isCancelled) {
                        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                        switch (response.statusCode) {
                            default:
                                _errorMessage = [error localizedDescription];
                                break;
                        }
                        
                        //                    [notesToAdd addObject:newNote.guid];
                        //                    [self savePrefs];
                        if (_delegate) {
                            [_delegate noteOperationDidFail:self];
                        }
                    }
                    [self finish];
                }];
            }
                break;
            case NoteOperationTypeUpdate:
            {
                OCNote *noteToUpdate = [OCNote instanceWithPrimaryKey:_note.guid];
                _note = noteToUpdate;
                NSDictionary *params = @{@"content": _note.content};
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id]];
                //                    __block OCNote *noteToUpdate = [OCNote instanceWithPrimaryKey:_note.guid];
                
                [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                    if (!self.isCancelled) {
                        _responseDictionary = (NSDictionary*)responseObject;
                        if (_delegate) {
                            [_delegate noteOperationDidFinish:self];
                        }
                    }
                    [self finish];
                    //                        if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                    //                            noteToUpdate.title = [noteDict objectForKey:@"title"];
                    //                            noteToUpdate.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];;
                    //                            noteToUpdate.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                    //                            if (noteToUpdate.existsInDatabase) {
                    //                                [noteToUpdate save];
                    //                            }
                    //                        }
                } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    if (!self.isCancelled) {
                        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                        switch (response.statusCode) {
                            case 404:
                                _errorMessage = NSLocalizedString(@"The note does not exist", @"An error message");
                                break;
                            default:
                                _errorMessage = [error localizedDescription];
                                break;
                        }
                        if (_delegate) {
                            [_delegate noteOperationDidFail:self];
                        }
                    }
                    [self finish];
                    
                    //                        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Updating Note", @"The title of an error message"),
                    //                                                   @"Message": message};
                    //                        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                    //                        noteToUpdate.modified = [[NSDate date] timeIntervalSince1970];
                    //                        if (noteToUpdate.existsInDatabase) {
                    //                            [noteToUpdate save];
                    //                        }
                }];
            }
                break;
            case NoteOperationTypeGet:
            {
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id]];
                __block OCNote *noteToGet = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [NSNumber numberWithInt:_note.id]]];
                if (noteToGet) {
                    NSDictionary *params = @{@"exclude": @"title,content"};
                    [[OCAPIClient sharedClient] GET:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                        if (!self.isCancelled) {
                            NSDictionary *noteDict = (NSDictionary*)responseObject;
                            NSLog(@"NoteDict: %@", noteDict);
                            if ([[NSNumber numberWithInt:noteToGet.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                if ([[noteDict objectForKey:@"modified"] doubleValue] > noteToGet.modified) {
                                    //The server has a newer version. We need to get it.
                                    [[OCAPIClient sharedClient] GET:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                                        //NSLog(@"Note: %@", responseObject);
                                        _responseDictionary = (NSDictionary*)responseObject;
                                        NSLog(@"NoteDict: %@", noteDict);
                                        if (_delegate) {
                                            [_delegate noteOperationDidFinish:self];
                                        }
                                        
                                        [self finish];
                                        
                                        //                                            if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                        //                                                if ([[noteDict objectForKey:@"modified"] doubleValue] > noteToGet.modified) {
                                        //                                                    noteToGet.title = [noteDict objectForKeyNotNull:@"title" fallback:@""];
                                        //                                                    noteToGet.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                                        //                                                    noteToGet.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                                        //                                                }
                                        //                                                if ([noteToGet existsInDatabase]) {
                                        //                                                    [noteToGet save];
                                        //                                                }
                                        //                                            }
                                    } failure:^(NSURLSessionDataTask *task, NSError *error) {
                                        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                                        switch (response.statusCode) {
                                            case 404:
                                                _errorMessage = NSLocalizedString(@"The note does not exist", @"An error message");
                                                break;
                                            default:
                                                _errorMessage = [error localizedDescription];
                                                break;
                                        }
                                        if (_delegate) {
                                            [_delegate noteOperationDidFail:self];
                                        }
                                        [self finish];
                                    }];
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
                                    _errorMessage = NSLocalizedString(@"The note does not exist", @"An error message");
                                    break;
                                default:
                                    _errorMessage = [error localizedDescription];
                                    break;
                            }
                            if (_delegate) {
                                [_delegate noteOperationDidFail:self];
                            }
                        }
                        [self finish];
                        //                            NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Getting Note", @"The title of an error message"),
                        //                                                       @"Message": message};
                        //                            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                    }];
                }
                
                [self finish];
            }
                break;
            case NoteOperationTypeDelete:
            {
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id]];
                [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                    //                    NSLog(@"Success deleting note");
                    if (_delegate) {
                        [_delegate noteOperationDidFinish:self];
                    }
                    [self finish];
                } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    if (!self.isCancelled) {
                        _errorMessage = [error localizedDescription];
                        if (_delegate) {
                            [_delegate noteOperationDidFail:self];
                        }
                    }
                    [self finish];
                    
                    //                    NSLog(@"Failure to delete note");
                    //                    [notesToDelete addObject:[NSNumber numberWithInt:noteId]];
                    //                    [self savePrefs];
                    //                    //[noteToDelete delete];
                    //                    NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Deleting Note", @"The title of an error message"),
                    //                                               @"Message": [error localizedDescription]};
                    //                    [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                }];
                
            }
                break;
                
            default:
                break;
        }
    }
}

@end
