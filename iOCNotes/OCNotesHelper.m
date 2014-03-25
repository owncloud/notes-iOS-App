//
//  OCNotesHelper.m
//  iOCNotes
//

/************************************************************************
 
 Copyright 2014 Peter Hedlund peter.hedlund@me.com
 
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

#import "OCNotesHelper.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"
#import "OCNotesSettings.h"
#import "FCModel.h"
#import "OCNote.h"

@interface OCNotesHelper () {
    NSMutableArray *notesToAdd;
    NSMutableArray *notesToDelete;
    NSMutableArray *notesToUpdate;
}

@end

@implementation OCNotesHelper

+ (OCNotesHelper*)sharedHelper {
    static dispatch_once_t once_token;
    static id sharedHelper;
    dispatch_once(&once_token, ^{
        sharedHelper = [[OCNotesHelper alloc] init];
    });
    return sharedHelper;
}

- (OCNotesHelper*)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    notesToAdd = [NSMutableArray arrayWithArray:[[prefs arrayForKey:@"NotesToAdd"] mutableCopy]];
    notesToDelete = [NSMutableArray arrayWithArray:[[prefs arrayForKey:@"NotesToDelete"] mutableCopy]];
    notesToUpdate = [NSMutableArray arrayWithArray:[[prefs arrayForKey:@"NotesToUpdate"] mutableCopy]];
    
    NSURL *dbURL = [self documentsDirectoryURL];
    dbURL = [dbURL URLByAppendingPathComponent:@"Notes" isDirectory:NO];
    dbURL = [dbURL URLByAppendingPathExtension:@"db"];
    //[NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
    
    [FCModel openDatabaseAtPath:dbURL.path withSchemaBuilder:^(FMDatabase *db, int *schemaVersion) {
        [db setCrashOnErrors:YES];
        db.traceExecution = YES; // Log every query (useful to learn what FCModel is doing or analyze performance)
        [db beginTransaction];
        
        void (^failedAt)(int statement) = ^(int statement){
            int lastErrorCode = db.lastErrorCode;
            NSString *lastErrorMessage = db.lastErrorMessage;
            [db rollback];
            NSAssert3(0, @"Migration statement %d failed, code %d: %@", statement, lastErrorCode, lastErrorMessage);
        };
        
        if (*schemaVersion < 1) {
            if (! [db executeUpdate:
                   @"CREATE TABLE OCNote ("
                   @"    id           INTEGER PRIMARY KEY," // Autoincrement is optional. Just demonstrating that it works.
                   @"    title        TEXT NOT NULL DEFAULT '',"
                   @"    content      TEXT NOT NULL DEFAULT '',"
                   @"    modified     INTEGER NOT NULL"
                   @");"
                   ]) failedAt(1);
            /*if (! [db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS title ON Note (title);"]) failedAt(2);
            
            if (! [db executeUpdate:
                   @"CREATE TABLE Color ("
                   @"    name         TEXT NOT NULL PRIMARY KEY,"
                   @"    hex          TEXT NOT NULL"
                   @");"
                   ]) failedAt(3);
            */
            // Create any other tables...
            
            *schemaVersion = 1;
        }
        
        // If you wanted to change the schema in a later app version, you'd add something like this here:
        /*
         if (*schemaVersion < 2) {
         if (! [db executeUpdate:@"ALTER TABLE Person ADD COLUMN lastModified INTEGER NULL"]) failedAt(3);
         *schemaVersion = 2;
         }
         */
        
        [db commit];
    }];

    
    
    
    
    
    __unused BOOL reachable = [[OCAPIClient sharedClient] reachabilityManager].isReachable;
    
    return self;
}

- (NSURL*) documentsDirectoryURL {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)savePrefs {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:notesToAdd forKey:@"NotesToAdd"];
    [prefs setObject:notesToDelete forKey:@"NotesToDelete"];
    [prefs setObject:notesToUpdate forKey:@"NotesToUpdate"];
    [prefs synchronize];
}

/*
 Get all notes
 
 Status: Implemented
 Method: GET
 Route: /notes
 Parameters: none
 Returns:
 
 [
 {
 id: 76,
 modified: 1376753464,
 title: "New note"
 content: "New note\n and something more",
 }, // etc
 ]
 */
- (void) sync {
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        
        NSDictionary *params = @{@"exclude": @""};
        [[OCAPIClient sharedClient] GET:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            
            NSArray *serverNotesDictArray = (NSArray *)responseObject;
            if (serverNotesDictArray) {
                [serverNotesDictArray enumerateObjectsUsingBlock:^(NSDictionary *noteDict, NSUInteger idx, BOOL *stop) {
                    OCNote *ocNote = [OCNote instanceWithPrimaryKey:[noteDict objectForKey:@"id"] createIfNonexistent:YES];
                    if (ocNote.modified > [[noteDict objectForKey:@"modified"] intValue]) {
                        [notesToUpdate addObject:[noteDict objectForKey:@"id"]];
                        [self savePrefs];
                    } else {
                        ocNote.modified =  [[noteDict objectForKey:@"modified"] intValue];
                        ocNote.title = [noteDict objectForKey:@"title"];
                        ocNote.content = [noteDict objectForKey:@"content"];
                        [ocNote save];
                    }
                }];

                NSArray *serverIds = [serverNotesDictArray valueForKey:@"id"];
                
                NSArray *knownIds = [OCNote firstColumnArrayFromQuery:@"SELECT * FROM $T"];
                
                NSLog(@"Count: %lu", (unsigned long)knownIds.count);
                
                NSMutableArray *deletedOnServer = [NSMutableArray arrayWithArray:knownIds];
                [deletedOnServer removeObjectsInArray:serverIds];
                [deletedOnServer removeObjectsInArray:notesToAdd];
                NSLog(@"Deleted on server: %@", deletedOnServer);
                while (deletedOnServer.count > 0) {
                    OCNote *ocNote = [OCNote instanceWithPrimaryKey:[deletedOnServer lastObject]];
                    [ocNote delete];
                    [deletedOnServer removeLastObject];
                }
            }
            [self deleteNotesFromServer];
            [self addNotesToServer];
            [self updateNotesOnServer];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkSuccess" object:self userInfo:nil];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Updating Notes", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        }];
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Unable to Reach Server", @"Title",
                                  @"Please check network connection and login.", @"Message", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
    }
}

/*
 Get a note
 
 Status: Implemented
 Method: GET
 Route: /notes/{noteId}
 Parameters: none
 Return codes:
 HTTP 404: If the note does not exist
 Returns:
 
 {
 id: 76,
 modified: 1376753464,
 title: "New note"
 content: "New note\n and something more",
 }
 */

- (void)getNote:(OCNote *)note {
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        //online
        NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithLongLong:note.id].stringValue];
        __block OCNote *noteToGet = [OCNote instanceWithPrimaryKey:[NSNumber numberWithLongLong:note.id]];
        if (noteToGet) {
            NSDictionary *params = @{@"exclude": @"title,content"};
            [[OCAPIClient sharedClient] GET:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                NSDictionary *noteDict = (NSDictionary*)responseObject;
                NSLog(@"NoteDict: %@", noteDict);
                if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                    if ([[noteDict objectForKey:@"modified"] intValue] > noteToGet.modified) {
                        //The server has a newer version. We need to get it.
                        [[OCAPIClient sharedClient] GET:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                            //NSLog(@"Note: %@", responseObject);
                            NSDictionary *noteDict = (NSDictionary*)responseObject;
                            NSLog(@"NoteDict: %@", noteDict);
                            if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                if ([[noteDict objectForKey:@"modified"] intValue] > noteToGet.modified) {
                                    noteToGet.title = [noteDict objectForKey:@"title"];
                                    noteToGet.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                                    noteToGet.modified = [[noteDict objectForKey:@"modified"] intValue];
                                }
                                [noteToGet save];
                            }
                        } failure:^(NSURLSessionDataTask *task, NSError *error) {
                            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                            NSString *message;
                            switch (response.statusCode) {
                                case 404:
                                    message = @"The note does not exist";
                                    break;
                                default:
                                    message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                                    break;
                            }
                            
                            NSDictionary *userInfo = @{@"Title": @"Error Getting Note", @"Message": message};
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                        }];
                    
                    }
                    
                }
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    case 404:
                        message = @"The note does not exist";
                        break;
                    default:
                        message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                        break;
                }
                
                NSDictionary *userInfo = @{@"Title": @"Error Getting Note", @"Message": message};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            }];
        }
    } else {
        //offline
    }
}


/*
 Create a note
 
 Creates a new note and returns the note. The title is generated from the first line of the content. If no content is passed, a translated string New note will be returned as title
 
 Status: Implemented
 Method: POST
 Route: /notes
 Parameters:
 
 {
 content: "New content"
 }
 
 Returns:
 
 {
 id: 76,
 content: "",
 modified: 1376753464,
 title: ""
 }
 */

- (void)addNote:(NSString*)content {
    __block OCNote *newNote = [OCNote instanceWithPrimaryKey:[NSNumber numberWithLongLong:100000 + notesToAdd.count]];
    newNote.title = @"New note";
    newNote.content = content;
    newNote.modified = [[NSDate date] timeIntervalSince1970];
    [newNote save];
    
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        //online
        NSDictionary *params = @{@"content": newNote.content};
        [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            NSDictionary *noteDict = (NSDictionary*)responseObject;
            OCNote *returnedNote = [OCNote new];
            returnedNote.id = [[noteDict objectForKey:@"id"] intValue];
            returnedNote.modified = [[noteDict objectForKey:@"modified"] intValue];
            returnedNote.title = [noteDict objectForKey:@"title"];
            returnedNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
            [returnedNote save];
            [newNote delete];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                default:
                    message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    break;
            }
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Note", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            [notesToAdd addObject:[NSNumber numberWithLongLong:newNote.id]];
            [self savePrefs];
        }];
        
    } else {
        [notesToAdd addObject:[NSNumber numberWithLongLong:newNote.id]];
        [self savePrefs];
    }
}

/*
 Update a note
 
 Updates a note with the id noteId. Always update your app with the returned title because the title can be renamed if there are collisions on the server. The title is generated from the first line of the content. If no content is passed, a translated string New note will be returned as title
 
 Status: Implemented
 Method: PUT
 Route: /notes/{noteId}
 Parameters:
 
 {
 content: "New content",
 }
 
 Return codes:
 HTTP 404: If the note does not exist
 Returns:
 
 {
 id: 76,
 content: "New content",
 modified: 1376753464,
 title: "New title"
 }
 */

- (void)updateNote:(OCNote*)note {
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        //online
        NSDictionary *params = @{@"content": note.content};
        NSString *path = [NSString stringWithFormat:@"notes/%@",[[NSNumber numberWithLongLong:note.id] stringValue]];
        __block OCNote *noteToUpdate = [OCNote instanceWithPrimaryKey:[NSNumber numberWithLongLong:note.id]];

        [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            //NSLog(@"Note: %@", responseObject);
            NSDictionary *noteDict = (NSDictionary*)responseObject;
            if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                noteToUpdate.title = [noteDict objectForKey:@"title"];
                noteToUpdate.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];;
                noteToUpdate.modified = [[noteDict objectForKey:@"modified"] intValue];
                [noteToUpdate save];
            }
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                case 404:
                    message = @"The note does not exist";
                    break;
                default:
                    message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    break;
            }
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Updating Note", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            noteToUpdate.modified = [[NSDate date] timeIntervalSince1970];
            [noteToUpdate save];
        }];
        
    } else {
        //offline
        note.modified = [[NSDate date] timeIntervalSince1970];
        [note save];
        [notesToUpdate addObject:[NSNumber numberWithLongLong:note.id]];
        [self savePrefs];
    }
}

/*
 Delete a note
 
 Deletes a note with the id noteId
 
 Status: Implemented
 Method: DELETE
 Route: /notes/{noteId}
 Parameters: none
 Return codes:
 HTTP 404: If the note does not exist
 Returns: nothing
 */

- (void) deleteNote:(OCNote *)note {
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        //online
        ///__block OCNote *noteToDelete = (Note*)[self.context objectWithID:note.objectID];
        __block OCNote *noteToDelete = [OCNote instanceWithPrimaryKey:[NSNumber numberWithLongLong:note.id]];
        NSString *path = [NSString stringWithFormat:@"notes/%@", [[NSNumber numberWithLongLong:note.id] stringValue]];
        [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"Success deleting note");
            [noteToDelete delete];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"Failure to delete note");
            [notesToDelete addObject:[NSNumber numberWithLongLong:note.id]];
            [self savePrefs];
            [noteToDelete delete];
            NSString *message = [NSString stringWithFormat:@"The error reported was '%@'", [error localizedDescription]];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Deleting Note", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        }];
    } else {
        //offline
        [notesToDelete addObject:[NSNumber numberWithLongLong:note.id]];
        [self savePrefs];
        [note delete];
    }
}

- (void)updateNotesOnServer {
    __block NSMutableArray *successfulUpdates = [NSMutableArray new];
    __block NSMutableArray *failedUpdates = [NSMutableArray new];
    
    dispatch_group_t group = dispatch_group_create();
    [notesToUpdate enumerateObjectsUsingBlock:^(NSNumber *noteId, NSUInteger idx, BOOL *stop) {
        __block OCNote *noteToUpdate = [OCNote instanceWithPrimaryKey:noteId];
        if (noteToUpdate) {
            dispatch_group_enter(group);
            NSDictionary *params = @{@"content": noteToUpdate.content};
            NSString *path = [NSString stringWithFormat:@"notes/%@",[noteId stringValue]];
            [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                @synchronized(successfulUpdates) {
                    NSDictionary *noteDict = (NSDictionary*)responseObject;
                    if ([noteId isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                        noteToUpdate.title = [noteDict objectForKey:@"title"];
                        noteToUpdate.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];;
                        noteToUpdate.modified = [[noteDict objectForKey:@"modified"] intValue];
                        [noteToUpdate save];
                        [successfulUpdates addObject:[noteDict objectForKey:@"id"]];
                    }
                }
                dispatch_group_leave(group);
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                //TODO: Determine what to do with failures.
                NSString *failedId = [task.originalRequest.URL lastPathComponent];
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    case 404:
                        NSLog(@"Id %@ no longer exists", failedId);
                        @synchronized(successfulUpdates) {
                            [successfulUpdates addObject:[NSNumber numberWithInteger:[failedId integerValue]]];
                        }
                        break;
                    default:
                        @synchronized(failedUpdates) {
                            [failedUpdates addObject:[NSNumber numberWithInteger:[failedId integerValue]]];
                        }
                        message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                        break;
                }
                
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Note", @"Title", message, @"Message", nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                dispatch_group_leave(group);
            }];
        }
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [notesToUpdate removeObjectsInArray:successfulUpdates]; //try again next time
    });
}

- (void)addNotesToServer {
    __block NSMutableArray *successfulAdditions = [NSMutableArray new];
    __block NSMutableArray *failedAdditions = [NSMutableArray new];
    
    dispatch_group_t group = dispatch_group_create();
    //[notesToAdd enumerateObjectsUsingBlock:^(NSNumber *idNumber, NSUInteger idx, BOOL *stop) {
    [notesToAdd enumerateObjectsUsingBlock:^(NSNumber *noteId, NSUInteger idx, BOOL *stop) {
    
        __block OCNote *ocNote = [OCNote instanceWithPrimaryKey:noteId];
        if (ocNote) {
            dispatch_group_enter(group);
            NSDictionary *params = @{@"content": ocNote.content};
            [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                @synchronized(successfulAdditions) {
                    NSDictionary *noteDict = (NSDictionary*)responseObject;
                    OCNote *responseNote = [OCNote instanceWithPrimaryKey:[noteDict objectForKey:@"id"]];
                    if (responseNote) {
                        responseNote.title = [noteDict objectForKey:@"title"];
                        responseNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                        responseNote.modified = [[noteDict objectForKey:@"modified"] longLongValue];
                        [responseNote save];
                    }
                    [successfulAdditions addObject:[NSNumber numberWithLongLong:ocNote.id]];
                    [ocNote delete];
                }
                dispatch_group_leave(group);
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                //TODO: Determine what to do with failures.
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    default:
                        message = [NSString stringWithFormat:@"The server responded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                        break;
                }
                
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Note", @"Title", message, @"Message", nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                [failedAdditions addObject:[NSNumber numberWithLongLong:ocNote.id]];
                dispatch_group_leave(group);
            }];
        }
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [notesToAdd removeObjectsInArray:successfulAdditions]; //try again next time
    });
}

- (void)deleteNotesFromServer {
    __block NSMutableArray *successfulDeletions = [NSMutableArray new];
    __block NSMutableArray *failedDeletions = [NSMutableArray new];
    
    dispatch_group_t group = dispatch_group_create();
    [notesToDelete enumerateObjectsUsingBlock:^(NSNumber *noteId, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        NSString *path = [NSString stringWithFormat:@"notes/%@", [noteId stringValue]];
        [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"Success deleting from server");
            @synchronized(successfulDeletions) {
                NSString *successId = [task.originalRequest.URL lastPathComponent];
                [successfulDeletions addObject:[NSNumber numberWithInteger:[successId integerValue]]];
            }
            dispatch_group_leave(group);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"Failure to delete from server");
            NSString *failedId = [task.originalRequest.URL lastPathComponent];
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            switch (response.statusCode) {
                case 404:
                    NSLog(@"Id %@ no longer exists", failedId);
                    @synchronized(successfulDeletions) {
                        [successfulDeletions addObject:[NSNumber numberWithInteger:[failedId integerValue]]];
                    }
                    break;
                default:
                    NSLog(@"Status code: %ld", (long)response.statusCode);
                    @synchronized(failedDeletions) {
                        [failedDeletions addObject:[NSNumber numberWithInteger:[failedId integerValue]]];
                    }
                    break;
            }
            dispatch_group_leave(group);
        }];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [notesToDelete removeObjectsInArray:successfulDeletions];
    });
}

@end
