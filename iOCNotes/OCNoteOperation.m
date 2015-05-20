//
//  OCNoteOperation.m
//  iOCNotes
//

/************************************************************************
 
 Copyright 2015 Peter Hedlund peter.hedlund@me.com
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *************************************************************************/


#import "OCNoteOperation.h"
#import "OCNote.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"

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
        NSLog(@"Creating operation of type %ld", (long)operationType);
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
//                        NSLog(@"Returning from add operation");
                        _responseDictionary = (NSDictionary*)responseObject;
                        _note.id = [[_responseDictionary objectForKey:@"id"] intValue];
                        _note.modified = [[_responseDictionary objectForKey:@"modified"] doubleValue];
                        _note.title = [_responseDictionary objectForKey:@"title"];
                        _note.content = [_responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                        _note.addNeeded = NO;
                        _note.updateNeeded = NO;
                        [_note save];

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
                NSDictionary *params = @{@"content": _note.content};
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id].stringValue];
                [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                    if (!self.isCancelled) {
//                        NSLog(@"Returning from update operation");
                        _responseDictionary = (NSDictionary*)responseObject;
                        if ([[NSNumber numberWithInt:_note.id] isEqualToNumber:[_responseDictionary objectForKey:@"id"]]) {
                            _note.title = [_responseDictionary objectForKey:@"title"];
                            _note.content = [_responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                            _note.modified = [[_responseDictionary objectForKey:@"modified"] doubleValue];
                            _note.addNeeded = NO;
                            _note.updateNeeded = NO;
                            if (_note.existsInDatabase) {
                                [_note save];
                            }
                        }

                        if (_delegate) {
                            [_delegate noteOperationDidFinish:self];
                        }
                    }
                    [self finish];
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
                }];
            }
                break;
            case NoteOperationTypeGet:
            {
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id].stringValue];
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
                                        if (!self.isCancelled) {
                                            _responseDictionary = (NSDictionary*)responseObject;
                                            if ([[NSNumber numberWithInt:_note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                                if ([[noteDict objectForKey:@"modified"] doubleValue] > _note.modified) {
                                                    _note.title = [_responseDictionary objectForKeyNotNull:@"title" fallback:@""];
                                                    _note.content = [_responseDictionary objectForKeyNotNull:@"content" fallback:@""];
                                                    _note.modified = [[_responseDictionary objectForKey:@"modified"] doubleValue];
                                                }
                                                if ([_note existsInDatabase]) {
                                                    [_note save];
                                                }
                                            }
                                            if (_delegate) {
                                                [_delegate noteOperationDidFinish:self];
                                            }
                                        }
                                        [self finish];
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
                    }];
                }
                
                [self finish];
            }
                break;
            case NoteOperationTypeDelete:
            {
                NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:_note.id].stringValue];
                [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                    if (!self.isCancelled) {
                        [_note delete];
                        if (_delegate) {
                            [_delegate noteOperationDidFinish:self];
                        }
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
                }];
            }
                break;
                
            default:
                break;
        }
    }
}

@end
