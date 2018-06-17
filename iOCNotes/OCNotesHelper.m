//
//  OCNotesHelper.m
//  iOCNotes
//

/************************************************************************
 
 Copyright 2014-2015 Peter Hedlund peter.hedlund@me.com
 
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
#import "FCModel.h"
#import "OCNote.h"
#import "OCNoteOperationAdd.h"
#import "OCNoteOperationUpdate.h"
#import "OCNoteOperationGet.h"
#import "OCNoteOperationDelete.h"

@interface OCNotesHelper () <OCNoteOperationDelegate>  {
    BOOL online;
}

@property (nonatomic, strong) NSOperationQueue *notesOperationQueue;

@end

@implementation OCNotesHelper

@synthesize notesOperationQueue;

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
    
    [self setupDatabase];
    
    online = [[OCAPIClient sharedClient] reachabilityManager].isReachable;
    
    self.notesOperationQueue = [[NSOperationQueue alloc] init];
    self.notesOperationQueue.name = @"Notes Queue";
    self.notesOperationQueue.maxConcurrentOperationCount = 1;
    
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
        NSURL *dbURL = [self documentsDirectoryURL];
        dbURL = [dbURL URLByAppendingPathComponent:@"Notes" isDirectory:NO];
        dbURL = [dbURL URLByAppendingPathExtension:@"db"];
        [NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
        [self setupDatabase];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"dbReset"];
        [[NSNotificationCenter defaultCenter] postNotificationName:FCModelChangeNotification object:OCNote.class];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setupDatabase {
    NSURL *dbURL = [self documentsDirectoryURL];
    dbURL = [dbURL URLByAppendingPathComponent:@"Notes" isDirectory:NO];
    dbURL = [dbURL URLByAppendingPathExtension:@"db"];
    //[NSFileManager.defaultManager removeItemAtPath:dbURL.path error:nil];
    
    [FCModel openDatabaseAtPath:dbURL.path withDatabaseInitializer:nil schemaBuilder:^(FMDatabase *db, int *schemaVersion) {
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
        
        if (*schemaVersion < 3) {
            if (! [db executeUpdate:@"ALTER TABLE OCNote ADD COLUMN addNeeded    INTEGER NOT NULL DEFAULT 0"]) failedAt(7);
            if (! [db executeUpdate:@"ALTER TABLE OCNote ADD COLUMN updateNeeded INTEGER NOT NULL DEFAULT 0"]) failedAt(8);
            if (! [db executeUpdate:@"ALTER TABLE OCNote ADD COLUMN deleteNeeded INTEGER NOT NULL DEFAULT 0"]) failedAt(9);

            *schemaVersion = 3;
        }

        [db commit];
    }];
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
        [OCAPIClient sharedClient].requestSerializer = [OCAPIClient jsonRequestSerializer];
        [[OCAPIClient sharedClient] GET:@"notes" parameters:params progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            
            NSArray *serverNotesDictArray = (NSArray *)responseObject;
            if (serverNotesDictArray) {
                [serverNotesDictArray enumerateObjectsUsingBlock:^(NSDictionary *noteDict, NSUInteger idx, BOOL *stop) {
                    OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [noteDict objectForKey:@"id"]]];
                    //OCNote *ocNote = [OCNote instanceWithPrimaryKey:[noteDict objectForKey:@"id"] createIfNonexistent:YES];
                    if (!ocNote) { //don't re-add a deleted note (it will be deleted from the server below).
                        ocNote = [OCNote new];
                        [ocNote save:^{
                            ocNote.id = [[noteDict objectForKey:@"id"] intValue];
                            ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                            ocNote.title = [noteDict objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                            ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                        }];
                    } else {
                        if ([ocNote existsInDatabase]) {
                            [ocNote save:^{
                                if (ocNote.modified > [[noteDict objectForKey:@"modified"] doubleValue]) {
                                    ocNote.updateNeeded = YES;
                                } else {
                                    ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                                    ocNote.title = [noteDict objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                                    ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                                }
                            }];
                        }
                    }
                }];
                
                NSArray *serverIds = [serverNotesDictArray valueForKey:@"id"];
                
                NSArray *knownIds = [[OCNote resultDictionariesFromQuery:@"SELECT * FROM $T WHERE id > 0"] valueForKey:@"id"];
                
//                NSLog(@"Count: %lu", (unsigned long)knownIds.count);
                
                NSMutableArray *deletedOnServer = [NSMutableArray arrayWithArray:knownIds];
                [deletedOnServer removeObjectsInArray:serverIds];
                //TODO: Fix [deletedOnServer removeObjectsInArray:notesToAdd];
//                NSLog(@"Deleted on server: %@", deletedOnServer);
                while (deletedOnServer.count > 0) {
                    OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [deletedOnServer lastObject]]];
                    OCNoteOperationDeleteSimple *operation = [[OCNoteOperationDeleteSimple alloc] initWithNote:ocNote delegate:self];
                    [self addOperationToQueue:operation];
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
                                   @"Message": NSLocalizedString(@"Please check network connection and login.", @"A message to check network connection")};
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
            OCNoteOperationGet *operation = [[OCNoteOperationGet alloc] initWithNote:note delegate:self];
            [self addOperationToQueue:operation];
        }
        else
        {
            OCNoteOperationAdd *operation = [[OCNoteOperationAdd alloc] initWithNote:note delegate:self];
            [self addOperationToQueue:operation];
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

- (OCNote *)addNote:(NSString*)content {
    __block OCNote *newNote = [OCNote new];
    [newNote save:^{
        newNote.title = NSLocalizedString(@"New note", @"The title of a new note");
        newNote.content = content;
        newNote.modified = [[NSDate date] timeIntervalSince1970];
        newNote.addNeeded = YES;
    }];
    
    if (online) {
        OCNoteOperationAdd *operation = [[OCNoteOperationAdd alloc] initWithNote:newNote delegate:self];
        [self addOperationToQueue:operation];
    }
    return newNote;
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
    if (!note.addNeeded) {
        [note save:^{
            note.updateNeeded = YES;
        }];
    }
    if (online) {
        //online
        if (note.id > 0) {
            OCNoteOperationUpdate *operation = [[OCNoteOperationUpdate alloc] initWithNote:note delegate:self];
            [self addOperationToQueue:operation];
        } else {
            OCNoteOperationAdd *operation = [[OCNoteOperationAdd alloc] initWithNote:note delegate:self];
            [self addOperationToQueue:operation];
        }
    } else {
        //offline
        if (note.existsInDatabase) {
            [note save:^{
                note.modified = [[NSDate date] timeIntervalSince1970];
            }];
        }
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

- (void)deleteNote:(OCNote *)note {
    __block OCNote *noteToDelete = [OCNote instanceWithPrimaryKey:note.guid];
    __block int noteId = noteToDelete.id;
    [noteToDelete save:^{
        noteToDelete.deleteNeeded = YES;
        noteToDelete.addNeeded = NO;
        noteToDelete.updateNeeded = NO;
    }];
    
    if (noteId > 0) {
        if (online) {
            OCNoteOperationDelete *operation = [[OCNoteOperationDelete alloc] initWithNote:note delegate:self];
            [self addOperationToQueue:operation];
        }
    }
}

- (void)addNotesToServer {
    NSArray *notesToAdd = [OCNote instancesWhere:@"addNeeded = 1"];
    
    [notesToAdd enumerateObjectsUsingBlock:^(OCNote *note, NSUInteger idx, BOOL *stop) {
        if (note) {
            if (note.content.length > 0) {
                OCNoteOperationAdd *operation = [[OCNoteOperationAdd alloc] initWithNote:note delegate:self];
                [self addOperationToQueue:operation];
            }
        }
    }];
}

- (void)updateNotesOnServer {
    NSArray *notesToUpdate = [OCNote instancesWhere:@"updateNeeded = 1"];

    [notesToUpdate enumerateObjectsUsingBlock:^(OCNote *note, NSUInteger idx, BOOL *stop) {
        OCNoteOperationUpdate *operation = [[OCNoteOperationUpdate alloc] initWithNote:note delegate:self];
        [self addOperationToQueue:operation];
    }];
}

- (void)deleteNotesFromServer {
    NSArray *notesToDelete = [OCNote instancesWhere:@"deleteNeeded = 1"];
    
    [notesToDelete enumerateObjectsUsingBlock:^(OCNote *note, NSUInteger idx, BOOL *stop) {
        OCNoteOperationDelete *operation = [[OCNoteOperationDelete alloc] initWithNote:note delegate:self];
        [self addOperationToQueue:operation];
    }];
}

#pragma mark - notesOerationQueue

- (void)addOperationToQueue:(OCNoteOperation*)noteOperation {
    __block NSString *newGuid = noteOperation.note.guid;
//    NSLog(@"Adding operation to queue %@", newGuid);
    [self.notesOperationQueue.operations enumerateObjectsUsingBlock:^(OCNoteOperation *operation, NSUInteger idx, BOOL *stop) {
//        NSLog(@"Comparing %@ to operation %@", newGuid, operation.note.guid);
        
        if ([operation.note.guid isEqualToString:newGuid]) {
            if (operation.isExecuting) {
                if ([operation isKindOfClass:[OCNoteOperationAdd class]] && [noteOperation isKindOfClass:[OCNoteOperationAdd class]]) {
//                    NSLog(@"Changing operation to update");
                    OCNote *theNote = noteOperation.note;
                    OCNoteOperationUpdate *newNoteOperation = [[OCNoteOperationUpdate alloc] initWithNote:theNote delegate:self];
                    [newNoteOperation addDependency:operation];
                    [self.notesOperationQueue addOperation:newNoteOperation];
                    [noteOperation cancel];
                } else {
                    [noteOperation addDependency:operation];
                }
            } else {
//                NSLog(@"Cancelling operation");
                [operation cancel];
            }
        }
    }];
    
    [self.notesOperationQueue addOperation:noteOperation];
}

#pragma mark - OCNoteOperation delegate

- (void)noteOperationDidStart:(OCNoteOperation *)noteOperation {
    
}

- (void)noteOperationDidFinish:(OCNoteOperation *)noteOperation {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkSuccess" object:self userInfo:nil];
}

- (void)noteOperationDidFail:(OCNoteOperation *)noteOperation {
    if ([noteOperation isKindOfClass:[OCNoteOperationAdd class]])
    {
        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Adding Note", @"The title of an error message"),
                                   @"Message": noteOperation.errorMessage};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
    }
    if ([noteOperation isKindOfClass:[OCNoteOperationUpdate class]])
    {
        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Updating Note", @"The title of an error message"),
                                   @"Message": noteOperation.errorMessage};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        noteOperation.note.modified = [[NSDate date] timeIntervalSince1970];
    }
    if ([noteOperation isKindOfClass:[OCNoteOperationGet class]])
    {
        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Getting Note", @"The title of an error message"),
                                   @"Message": noteOperation.errorMessage};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
    }
    if ([noteOperation isKindOfClass:[OCNoteOperationDelete class]])
    {
        NSDictionary *userInfo = @{@"Title": NSLocalizedString(@"Error Deleting Note", @"The title of an error message"),
                                   @"Message": noteOperation.errorMessage};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
    }
}

@end
