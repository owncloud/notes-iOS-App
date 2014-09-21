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
    NSMutableSet *notesToAdd;
    NSMutableSet *notesToDelete;
    NSMutableSet *notesToUpdate;
    BOOL online;
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
    notesToAdd = [NSMutableSet setWithArray:[[prefs arrayForKey:@"NotesToAdd"] mutableCopy]];
    notesToDelete = [NSMutableSet setWithArray:[[prefs arrayForKey:@"NotesToDelete"] mutableCopy]];
    notesToUpdate = [NSMutableSet setWithArray:[[prefs arrayForKey:@"NotesToUpdate"] mutableCopy]];
    
    [self setupDatabase];
    
    online = [[OCAPIClient sharedClient] reachabilityManager].isReachable;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:AFNetworkingReachabilityDidChangeNotification
                                               object:nil];

    return self;
}

- (void)reachabilityChanged:(NSNotification *)n {
    NSNumber *s = n.userInfo[AFNetworkingReachabilityNotificationStatusItem];
    AFNetworkReachabilityStatus status = [s integerValue];
    
    if (status == AFNetworkReachabilityStatusNotReachable) {
        online = NO;
    }
    if (status > AFNetworkReachabilityStatusNotReachable) {
        online = YES;
    }
}

- (NSURL*) documentsDirectoryURL {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)appDidBecomeActive:(NSNotification*)n {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"dbReset"]) {
        notesToAdd = [NSMutableSet new];
        notesToDelete = [NSMutableSet new];
        notesToUpdate = [NSMutableSet new];
        
        NSURL *dbURL = [self documentsDirectoryURL];
        dbURL = [dbURL URLByAppendingPathComponent:@"Notes" isDirectory:NO];
        dbURL = [dbURL URLByAppendingPathExtension:@"db"];
        [NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
        [self setupDatabase];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"dbReset"];
        [[NSNotificationCenter defaultCenter] postNotificationName:FCModelUpdateNotification object:OCNote.class];
        [self savePrefs];
    }
}

- (void)setupDatabase {
    NSURL *dbURL = [self documentsDirectoryURL];
    dbURL = [dbURL URLByAppendingPathComponent:@"Notes" isDirectory:NO];
    dbURL = [dbURL URLByAppendingPathExtension:@"db"];
    //[NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
    
    [FCModel openDatabaseAtPath:dbURL.path withSchemaBuilder:^(FMDatabase *db, int *schemaVersion) {
        [db setCrashOnErrors:NO];
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
        
        if (*schemaVersion < 2) {
            if (! [db executeUpdate:@"ALTER TABLE OCNote RENAME TO OCNote_temp"]) failedAt(3);
            
            if (! [db executeUpdate:
                   @"CREATE TABLE OCNote ("
                   @"    guid         TEXT PRIMARY KEY,"
                   @"    id           INTEGER,"
                   @"    title        TEXT NOT NULL DEFAULT '',"
                   @"    content      TEXT NOT NULL DEFAULT '',"
                   @"    modified     INTEGER NOT NULL"
                   @");"
                   ]) failedAt(4);
            
            FMResultSet *rs = [db executeQuery:@"SELECT * FROM OCNote_temp"];
            while ([rs next]) {
                NSString *guid = [OCNote primaryKeyValueForNewInstance];
                int myID = [rs intForColumn:@"id"];
                NSString *title = [rs stringForColumn:@"title"];
                NSString *content = [rs stringForColumn:@"content"];
                int modified = [rs doubleForColumn:@"modified"];
                NSString *keys = @"(guid, id, title, content, modified)";
                NSArray *args = @[guid,
                                  [NSNumber numberWithInteger:myID],
                                  title,
                                  content,
                                  [NSNumber numberWithDouble:modified]];
                
                NSString *sql = [NSString stringWithFormat:@"INSERT INTO OCNote %@ VALUES (?, ?, ?, ?, ?);", keys];
                if (! [db executeUpdate:sql withArgumentsInArray:args]) failedAt(5);
                
            }
            
            if (! [db executeUpdate:@"DROP TABLE OCNote_temp"]) failedAt(6);
            
            *schemaVersion = 2;
        }
        
        [db commit];
    }];
}


- (void)savePrefs {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:notesToAdd.allObjects forKey:@"NotesToAdd"];
    [prefs setObject:notesToDelete.allObjects forKey:@"NotesToDelete"];
    [prefs setObject:notesToUpdate.allObjects forKey:@"NotesToUpdate"];
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
    if (online) {
        
        NSDictionary *params = @{@"exclude": @""};
        [[OCAPIClient sharedClient] GET:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            
            NSArray *serverNotesDictArray = (NSArray *)responseObject;
            if (serverNotesDictArray) {
                [serverNotesDictArray enumerateObjectsUsingBlock:^(NSDictionary *noteDict, NSUInteger idx, BOOL *stop) {
                    OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [noteDict objectForKey:@"id"]]];
                    //OCNote *ocNote = [OCNote instanceWithPrimaryKey:[noteDict objectForKey:@"id"] createIfNonexistent:YES];
                    if (!ocNote) { //don't re-add a deleted note (it will be deleted from the server below).
                        if (![notesToDelete containsObject:[noteDict objectForKey:@"id"]]) {
                            ocNote = [OCNote new];
                            ocNote.id = [[noteDict objectForKey:@"id"] intValue];
                            ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                            ocNote.title = [noteDict objectForKey:@"title"];
                            ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                            [ocNote save];
                        }
                    } else {
                        if (ocNote.modified > [[noteDict objectForKey:@"modified"] doubleValue]) {
                            [notesToUpdate addObject:[noteDict objectForKey:@"id"]];
                            [self savePrefs];
                        } else {
                            ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                            ocNote.title = [noteDict objectForKey:@"title"];
                            ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                            [ocNote save];
                        }
                    }
                }];

                NSArray *serverIds = [serverNotesDictArray valueForKey:@"id"];
                
                NSArray *knownIds = [[OCNote resultDictionariesFromQuery:@"SELECT * FROM $T WHERE id > 0"] valueForKey:@"id"];
                
                NSLog(@"Count: %lu", (unsigned long)knownIds.count);
                
                NSMutableArray *deletedOnServer = [NSMutableArray arrayWithArray:knownIds];
                [deletedOnServer removeObjectsInArray:serverIds];
                //TODO: Fix [deletedOnServer removeObjectsInArray:notesToAdd];
                NSLog(@"Deleted on server: %@", deletedOnServer);
                while (deletedOnServer.count > 0) {
                    OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [deletedOnServer lastObject]]];
                    [notesToAdd removeObject:ocNote.guid];
                    if (ocNote.id > 0) {
                        [notesToDelete removeObject:@(ocNote.id)];
                        [notesToUpdate removeObject:@(ocNote.id)];
                    }
                    [ocNote delete];
                    [deletedOnServer removeLastObject];
                }
            }
            [self deleteNotesFromServer];
            [self addNotesToServer];
            [self updateNotesOnServer];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkSuccess" object:self userInfo:nil];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Updating Notes", @"The title of an error message"),
                                       @"Message": [error localizedDescription]};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        }];
    } else {
        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Unable to Reach Server", @"The title of an error message"),
                                   @"Message": @"Please check network connection and login."};
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
    if (online) {
        if (note.id > 0) {
            NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithLongLong:note.id].stringValue];
            __block OCNote *noteToGet = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [NSNumber numberWithLongLong:note.id]]];
            if (noteToGet) {
                NSDictionary *params = @{@"exclude": @"title,content"};
                [[OCAPIClient sharedClient] GET:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                    //NSLog(@"Note: %@", responseObject);
                    NSDictionary *noteDict = (NSDictionary*)responseObject;
                    NSLog(@"NoteDict: %@", noteDict);
                    if ([[NSNumber numberWithLongLong:noteToGet.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                        if ([[noteDict objectForKey:@"modified"] doubleValue] > noteToGet.modified) {
                            //The server has a newer version. We need to get it.
                            [[OCAPIClient sharedClient] GET:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                                //NSLog(@"Note: %@", responseObject);
                                NSDictionary *noteDict = (NSDictionary*)responseObject;
                                NSLog(@"NoteDict: %@", noteDict);
                                if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                                    if ([[noteDict objectForKey:@"modified"] doubleValue] > noteToGet.modified) {
                                        noteToGet.title = [noteDict objectForKey:@"title"];
                                        noteToGet.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                                        noteToGet.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                                    }
                                    [noteToGet save];
                                }
                            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                                NSString *message;
                                switch (response.statusCode) {
                                    case 404:
                                        message = NSLocalizedString(@"The note does not exist", @"An error message");
                                        break;
                                    default:
                                        message = [error localizedDescription];
                                        break;
                                }
                                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Getting Note", @"The title of an error message"),
                                                           @"Message": message};
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                            }];
                            
                        }
                        
                    }
                } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                    NSString *message;
                    switch (response.statusCode) {
                        case 404:
                            message = NSLocalizedString(@"The note does not exist", @"An error message");
                            break;
                        default:
                            message = [error localizedDescription];
                            break;
                    }
                    NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Getting Note", @"The title of an error message"),
                                               @"Message": message};
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                }];
            }
        }
        else
        {
            NSDictionary *params = @{@"content": note.content};
            [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                NSDictionary *noteDict = (NSDictionary*)responseObject;
                note.id = [[noteDict objectForKey:@"id"] intValue];
                note.title = [noteDict objectForKey:@"title"];
                note.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                note.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                [note save];
                [notesToAdd removeObject:note.guid];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                //TODO: Determine what to do with failures.
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    default:
                        message = [error localizedDescription];
                        break;
                }
                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Adding Note", @"The title of an error message"),
                                           @"Message": message};
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
    __block OCNote *newNote = [OCNote new];
    newNote.title = NSLocalizedString(@"New note", @"The title of a new note");
    newNote.content = content;
    newNote.modified = [[NSDate date] timeIntervalSince1970];
    [newNote save];
    
    if (online) {
        NSDictionary *params = @{@"content": newNote.content};
        [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            NSDictionary *noteDict = (NSDictionary*)responseObject;
            newNote.id = [[noteDict objectForKey:@"id"] intValue];
            newNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
            newNote.title = [noteDict objectForKey:@"title"];
            newNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
            [newNote save];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                default:
                    message = [error localizedDescription];
                    break;
            }
            NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Adding Note", @"The title of an error message"),
                                       @"Message": message};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            [notesToAdd addObject:newNote.guid];
            [self savePrefs];
        }];
        
    } else {
        [notesToAdd addObject:newNote.guid];
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
    if (online) {
        //online
        if (note.id > 0) {
            NSDictionary *params = @{@"content": note.content};
            NSString *path = [NSString stringWithFormat:@"notes/%@",[NSNumber numberWithLongLong:note.id]];
            __block OCNote *noteToUpdate = [OCNote instanceWithPrimaryKey:note.guid];
            
            [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                NSDictionary *noteDict = (NSDictionary*)responseObject;
                if ([[NSNumber numberWithLongLong:note.id] isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                    noteToUpdate.title = [noteDict objectForKey:@"title"];
                    noteToUpdate.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];;
                    noteToUpdate.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                    if (noteToUpdate.existsInDatabase) {
                        [noteToUpdate save];
                    }
                }
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    case 404:
                        message = NSLocalizedString(@"The note does not exist", @"An error message");
                        break;
                    default:
                        message = [error localizedDescription];
                        break;
                }
                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Updating Note", @"The title of an error message"),
                                           @"Message": message};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                noteToUpdate.modified = [[NSDate date] timeIntervalSince1970];
                if (noteToUpdate.existsInDatabase) {
                    [noteToUpdate save];
                }
            }];
        } else {
            NSDictionary *params = @{@"content": note.content};
            [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                NSDictionary *noteDict = (NSDictionary*)responseObject;
                note.id = [[noteDict objectForKey:@"id"] intValue];
                note.title = [noteDict objectForKey:@"title"];
                note.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                note.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                [note save];
                [notesToAdd removeObject:note.guid];
                [notesToUpdate removeObject:@(note.id)];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                //TODO: Determine what to do with failures.
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                NSString *message;
                switch (response.statusCode) {
                    default:
                        message = [error localizedDescription];
                        break;
                }
                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Adding Note", @"The title of an error message"),
                                           @"Message": message};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            }];
        }
        
    } else {
        //offline
        note.modified = [[NSDate date] timeIntervalSince1970];
        if (note.existsInDatabase) {
            [note save];
        }
        if (note.id > 0) { // Has been synced at least once and is not included in notesToAdd
            [notesToUpdate addObject:[NSNumber numberWithLongLong:note.id]];
        }
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
    __block OCNote *noteToDelete = [OCNote instanceWithPrimaryKey:note.guid];
    __block int noteId = noteToDelete.id;
    [noteToDelete delete];
    
    if (noteId > 0) {
        if (online) {
            NSString *path = [NSString stringWithFormat:@"notes/%@", [NSNumber numberWithInt:noteId]];
            [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                NSLog(@"Success deleting note");
                //[noteToDelete delete];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                NSLog(@"Failure to delete note");
                [notesToDelete addObject:[NSNumber numberWithInt:noteId]];
                [self savePrefs];
                //[noteToDelete delete];
                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Deleting Note", @"The title of an error message"),
                                           @"Message": [error localizedDescription]};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            }];
        } else {
            //offline
            [notesToDelete addObject:[NSNumber numberWithInt:noteId]];
            [self savePrefs];
        }
    }
}

- (void)updateNotesOnServer {
    __block NSMutableArray *successfulUpdates = [NSMutableArray new];
    __block NSMutableArray *failedUpdates = [NSMutableArray new];
    
    dispatch_group_t updateGroup = dispatch_group_create();
    [notesToUpdate enumerateObjectsUsingBlock:^(NSNumber *noteId, BOOL *stop) {
        __block OCNote *noteToUpdate = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", noteId]];
        if (noteToUpdate) {
            dispatch_group_enter(updateGroup);
            NSDictionary *params = @{@"content": noteToUpdate.content};
            NSString *path = [NSString stringWithFormat:@"notes/%@", noteId];
            [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                //NSLog(@"Note: %@", responseObject);
                @synchronized(successfulUpdates) {
                    NSDictionary *noteDict = (NSDictionary*)responseObject;
                    if ([noteId isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                        noteToUpdate.title = [noteDict objectForKey:@"title"];
                        noteToUpdate.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];;
                        noteToUpdate.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                        [noteToUpdate save];
                        [successfulUpdates addObject:[noteDict objectForKey:@"id"]];
                    }
                }
                dispatch_group_leave(updateGroup);
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
                        message = [error localizedDescription];
                        break;
                }
                NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Updating Note", @"The title of an error message"),
                                           @"Message": message};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                dispatch_group_leave(updateGroup);
            }];
        }
    }];
    dispatch_group_notify(updateGroup, dispatch_get_main_queue(), ^{
        [successfulUpdates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [notesToUpdate removeObject:obj];
        }];
    });
}

- (void)addNotesToServer {
    __block NSMutableArray *successfulAdditions = [NSMutableArray new];
    __block NSMutableArray *failedAdditions = [NSMutableArray new];
    
    dispatch_group_t addGroup = dispatch_group_create();
    [notesToAdd enumerateObjectsUsingBlock:^(NSString *noteGuid, BOOL *stop) {
    
        __block OCNote *ocNote = [OCNote instanceWithPrimaryKey:noteGuid];
        if (ocNote) {
            dispatch_group_enter(addGroup);
            if (ocNote.content.length <= 0) {
                //Don't add empty notes
                [successfulAdditions addObject:ocNote.guid];
            } else if (ocNote.id > 0) {
                //Already added for some reason
                [successfulAdditions addObject:ocNote.guid];
            } else {
                NSDictionary *params = @{@"content": ocNote.content};
                [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
                    //NSLog(@"Note: %@", responseObject);
                    @synchronized(successfulAdditions) {
                        NSDictionary *noteDict = (NSDictionary*)responseObject;
                        ocNote.id = [[noteDict objectForKey:@"id"] intValue];
                        ocNote.title = [noteDict objectForKey:@"title"];
                        ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                        ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                        [ocNote save];
                        [successfulAdditions addObject:ocNote.guid];
                    }
                    dispatch_group_leave(addGroup);
                } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    //TODO: Determine what to do with failures.
                    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                    NSString *message;
                    switch (response.statusCode) {
                        default:
                            message = [error localizedDescription];
                            break;
                    }
                    NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Adding Note", @"The title of an error message"),
                                               @"Message": message};
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
                    [failedAdditions addObject:ocNote.guid];
                    dispatch_group_leave(addGroup);
                }];
            }
        }
    }];
    dispatch_group_notify(addGroup, dispatch_get_main_queue(), ^{
        [successfulAdditions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [notesToAdd removeObject:obj];
        }];
    });
}

- (void)deleteNotesFromServer {
    __block NSMutableArray *successfulDeletions = [NSMutableArray new];
    __block NSMutableArray *failedDeletions = [NSMutableArray new];
    
    dispatch_group_t deleteGroup = dispatch_group_create();
    [notesToDelete enumerateObjectsUsingBlock:^(NSNumber *noteId, BOOL *stop) {
        dispatch_group_enter(deleteGroup);
        NSString *path = [NSString stringWithFormat:@"notes/%@", noteId];
        [[OCAPIClient sharedClient] DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"Success deleting from server");
            @synchronized(successfulDeletions) {
                NSString *successId = [task.originalRequest.URL lastPathComponent];
                [successfulDeletions addObject:[NSNumber numberWithInteger:[successId integerValue]]];
            }
            dispatch_group_leave(deleteGroup);
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
            dispatch_group_leave(deleteGroup);
        }];
    }];
    dispatch_group_notify(deleteGroup, dispatch_get_main_queue(), ^{
        [successfulDeletions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [notesToDelete removeObject:obj];
        }];
    });
}

@end
