//
//  OCAPIClient.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2013 Peter Hedlund peter.hedlund@me.com
 
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

#import "OCAPIClient.h"
//#import "KeychainItemWrapper.h"
#import "Note.h"

//See http://twobitlabs.com/2013/01/objective-c-singleton-pattern-unit-testing/
//Being able to reinitialize a singleton is a no no, but should happen so rarely
//we can live with it?

static const NSString *rootPath = @"index.php/apps/notes/api/v0.2/";

static OCAPIClient *_sharedClient = nil;
static dispatch_once_t oncePredicate = 0;

@interface OCAPIClient () {
    NSMutableArray *notesToAdd;
    NSMutableArray *notesToDelete;
    NSMutableArray *notesToUpdate;
}

@end
    
@implementation OCAPIClient

@synthesize context;
@synthesize objectModel;
@synthesize coordinator;
@synthesize noteRequest;

+(OCAPIClient *)sharedClient {
    //static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        NSString *serverURLString = @"https://secure3120.hostgator.com/~phedlund/owncloud"; // [[NSUserDefaults standardUserDefaults] stringForKey:@"Server"];
        if (serverURLString.length > 0) {
            _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", serverURLString, rootPath]]];
        }
    });
    return _sharedClient;
}

-(id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    //BOOL allowInvalid = [[NSUserDefaults standardUserDefaults] boolForKey:@"AllowInvalidSSLCertificate"];
    self.securityPolicy.allowInvalidCertificates = YES;

    //KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"iOCNotes" accessGroup:nil];
    //[keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    
    [self setRequestSerializer:[AFJSONRequestSerializer serializer]];
    //[self.requestSerializer setAuthorizationHeaderFieldWithUsername:[keychain objectForKey:(__bridge id)(kSecAttrAccount)] password:[keychain objectForKey:(__bridge id)(kSecValueData)]];
    [self.requestSerializer setAuthorizationHeaderFieldWithUsername:@"peter" password:@"sb269970"];
    [self.reachabilityManager startMonitoring];
    
    notesToAdd = [NSMutableArray new];
    notesToDelete = [NSMutableArray new];
    notesToUpdate = [NSMutableArray new];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [notesToAdd addObjectsFromArray:[[prefs arrayForKey:@"NotesToAdd"] mutableCopy]];
    [notesToDelete addObjectsFromArray:[[prefs arrayForKey:@"NotesToDelete"] mutableCopy]];
    [notesToUpdate addObjectsFromArray:[[prefs arrayForKey:@"NotesToUpdate"] mutableCopy]];

    return self;
}

+(void)setSharedClient:(OCAPIClient *)client {
    oncePredicate = 0; // resets the once_token so dispatch_once will run again
    _sharedClient = client;
}

- (NSManagedObjectModel *)objectModel {
    if (!objectModel) {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Notes" withExtension:@"momd"];
        objectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return objectModel;
}

- (NSPersistentStoreCoordinator *)coordinator {
    if (!coordinator) {
        NSURL *storeURL = [self documentsDirectoryURL];
        storeURL = [storeURL URLByAppendingPathComponent:@"Notes.sqlite"];
        NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption : @YES,
                                  NSInferMappingModelAutomaticallyOption : @YES };
        NSError *error = nil;
        coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self objectModel]];
        if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
            NSLog(@"Error %@, %@", error, [error localizedDescription]);
            abort();
        }
    }
    return coordinator;
}

- (NSManagedObjectContext *)context {
    if (!context) {
        NSPersistentStoreCoordinator *myCoordinator = [self coordinator];
        if (myCoordinator != nil) {
            context = [[NSManagedObjectContext alloc] init];
            [context setPersistentStoreCoordinator:myCoordinator];
        }
    }
    return context;
}

- (NSURL*) documentsDirectoryURL {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)saveContext {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:notesToAdd forKey:@"NotesToAdd"];
    [prefs setObject:notesToDelete forKey:@"NotesToDelete"];
    [prefs setObject:notesToUpdate forKey:@"NotesToUpdate"];
    [prefs synchronize];

    NSError *error = nil;
    if (self.context != nil) {
        if ([self.context hasChanges] && ![self.context save:&error]) {
            NSLog(@"Error saving data %@, %@", error, [error userInfo]);
            //abort();
        } else {
            NSLog(@"Data saved");
        }
    }
}

- (Note*)noteWithId:(NSNumber *)noteId {
    [self.noteRequest setPredicate:[NSPredicate predicateWithFormat:@"myId == %@", noteId]];
    NSArray *notes = [self.context executeFetchRequest:self.noteRequest error:nil];
    return (Note*)[notes firstObject];
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
    if (self.reachabilityManager.isReachable) {
        
        //TODO: Process notes to update
        [self GET:@"notes" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {

            NSArray *serverNotesDictArray = (NSArray *) responseObject;
            NSLog(@"Notes: %@", [serverNotesDictArray objectAtIndex:0]);
            NSArray *serverIds = [serverNotesDictArray valueForKey:@"id"];
        
            NSError *error = nil;
            [self.noteRequest setPredicate:nil];
            NSArray *knownLocalNotes = [self.context executeFetchRequest:self.noteRequest error:&error];
            NSArray *knownIds = [knownLocalNotes valueForKey:@"myId"];
            
            NSLog(@"Count: %lu", (unsigned long)knownLocalNotes.count);
            
            error = nil;
             
            NSMutableArray *newOnServer = [NSMutableArray arrayWithArray:serverIds];
            [newOnServer removeObjectsInArray:knownIds];
            NSLog(@"New on server: %@", newOnServer);
            [newOnServer enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSPredicate * predicate = [NSPredicate predicateWithFormat:@"id == %@", obj];
                NSArray * matches = [serverNotesDictArray filteredArrayUsingPredicate:predicate];
                if (matches.count > 0) {
                    if (![notesToDelete indexOfObject:obj]) {
                        [self addNoteFromDictionary:[matches lastObject]];
                    }
                }
            }];
            
            NSMutableArray *deletedOnServer = [NSMutableArray arrayWithArray:knownIds];
            [deletedOnServer removeObjectsInArray:serverIds];
            NSLog(@"Deleted on server: %@", deletedOnServer);
            while (deletedOnServer.count > 0) {
                Note *noteToRemove = [self noteWithId:[deletedOnServer lastObject]];
                [self.context deleteObject:noteToRemove];
                [deletedOnServer removeLastObject];
            }
            
            [serverNotesDictArray enumerateObjectsUsingBlock:^(NSDictionary *noteDict, NSUInteger idx, BOOL *stop) {
                Note *note = [self noteWithId:[noteDict objectForKey:@"id"]];
                note.title = [noteDict objectForKey:@"title"];
                note.content = [noteDict objectForKey:@"content"];
                note.modified = [noteDict objectForKey:@"modified"];
                [self.context processPendingChanges]; //Prevents crash if a feed has moved to another folder
            }];
            
            [self deleteNotesFromServer:notesToDelete];
            
            for (NSNumber *noteId in notesToAdd) {
                Note *note = [self noteWithId:noteId];
                //TODO: [self addNoteToServer:note]; //the feed will have been readded as new on server
            }
            [notesToAdd removeAllObjects];

        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
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

- (void)addNote {
    Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.context];
    newNote.myId = [NSNumber numberWithInt:10000 + notesToAdd.count];
    newNote.title = @"New Note";
    newNote.content = @"";
    newNote.modified = [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];
    [self saveContext];
    
    if (self.reachabilityManager.isReachable) {
        //online
        NSDictionary *params = @{@"content": newNote.content};
        __block Note *blockNote = newNote;
        [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            //NSLog(@"Feeds: %@", responseObject);
            [self updateNote:blockNote fromDictionary:(NSDictionary*)responseObject];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                default:
                    message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    break;
            }
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Feed", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            [notesToAdd addObject:blockNote.myId];
        }];
        
    } else {
        //offline
        [notesToAdd addObject:newNote.myId];
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

- (void)updateNote:(Note*)note {
    if (self.reachabilityManager.isReachable) {
        //online
        NSDictionary *params = @{@"content": note.content};
        NSString *path = [NSString stringWithFormat:@"notes/%@", [note.myId stringValue]];
        __block Note *blockNote = note;
        
        [[OCAPIClient sharedClient] PUT:path parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            //NSLog(@"Note: %@", responseObject);
            NSDictionary *noteDict = (NSDictionary*)responseObject;
            if ([blockNote.myId isEqualToNumber:[noteDict objectForKey:@"id"]]) {
                blockNote.title = [noteDict objectForKey:@"title"];
                blockNote.content = [noteDict objectForKey:@"content"];
                blockNote.modified = [noteDict objectForKey:@"modified"];
                [self saveContext];
            }
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                case 404:
                    message = @"The note does not exist";
                    break;
                default:
                    message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    break;
            }
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Feed", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
            blockNote.modified = [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];
            [self saveContext];
        }];
        
    } else {
        //offline
        note.modified = [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];
        [self saveContext];
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

- (void) deleteNote:(Note *)note {
    if (self.reachabilityManager.isReachable) {
        //online
        __block Note *blockNote = note;
        NSString *path = [NSString stringWithFormat:@"notes/%@", [note.myId stringValue]];
        [self DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"Success");
            [self.context deleteObject:blockNote];
            [self saveContext];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"Failure");
            [notesToDelete addObject:blockNote.myId];
            [self.context deleteObject:blockNote];
            [self saveContext];
            NSString *message = [NSString stringWithFormat:@"The error reported was '%@'", [error localizedDescription]];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Deleting Note", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        }];
    } else {
        //offline
        [notesToDelete addObject:note.myId];
        [self.context deleteObject:note];
        [self saveContext];
    }
}

- (void)addNoteFromDictionary:(NSDictionary*)noteDict {
    Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.context];
    [self updateNote:newNote fromDictionary:noteDict];
}

- (void)updateNote:(Note *)note fromDictionary:(NSDictionary*)noteDict {
    note.myId = [noteDict objectForKey:@"id"];
    note.modified = [noteDict objectForKey:@"modified"];
    note.title = [noteDict objectForKey:@"title"];
    note.content = [noteDict objectForKey:@"content"];
    [self saveContext];
}

- (void)addNotesToServer:(NSArray*)notesArray {
    __block NSMutableArray *successfulAdditions = [NSMutableArray new];
    __block NSMutableArray *failedAdditions = [NSMutableArray new];

    dispatch_group_t group = dispatch_group_create();
    [notesToAdd enumerateObjectsUsingBlock:^(NSNumber *noteId, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        Note *note = [self noteWithId:noteId];
        NSDictionary *params = @{@"content": note.content};
        [[OCAPIClient sharedClient] POST:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            //NSLog(@"Feeds: %@", responseObject);
            @synchronized(successfulAdditions) {
                NSDictionary *noteDict = (NSDictionary*)responseObject;
                Note *responseNote = [self noteWithId:[noteDict objectForKey:@"id"]];
                if (responseNote) {
                    responseNote.title = [noteDict objectForKey:@"title"];
                    responseNote.content = [noteDict objectForKey:@"content"];
                    responseNote.modified = [noteDict objectForKey:@"modified"];
                }
                [successfulAdditions addObject:responseNote.myId];
            }
            dispatch_group_leave(group);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSString *message;
            switch (response.statusCode) {
                default:
                    message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    break;
            }
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Error Adding Feed", @"Title", message, @"Message", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkError" object:self userInfo:userInfo];
        }];

        
    }];
}

- (void)deleteNotesFromServer:(NSArray*)notesArray {
    __block NSMutableArray *successfulDeletions = [NSMutableArray new];
    __block NSMutableArray *failedDeletions = [NSMutableArray new];

    dispatch_group_t group = dispatch_group_create();
    [notesToDelete enumerateObjectsUsingBlock:^(NSNumber *noteId, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        NSString *path = [NSString stringWithFormat:@"notes/%@", [noteId stringValue]];
        [self DELETE:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"Success");
            @synchronized(successfulDeletions) {
                NSString *successId = [task.originalRequest.URL lastPathComponent];
                [successfulDeletions addObject:[NSNumber numberWithInteger:[successId integerValue]]];
            }
            dispatch_group_leave(group);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            //TODO: Handle 404 and count as success. Determine what to do with real failures.
            NSLog(@"Failure");
            NSString *failedId = [task.originalRequest.URL lastPathComponent];
            @synchronized(failedDeletions) {
                [failedDeletions addObject:[NSNumber numberWithInteger:[failedId integerValue]]];
            }
            dispatch_group_leave(group);
        }];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [notesToDelete removeObjectsInArray:successfulDeletions];
    });
}

- (NSFetchRequest *)noteRequest {
    if (!noteRequest) {
        noteRequest = [[NSFetchRequest alloc] init];
        [noteRequest setEntity:[NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.context]];
        noteRequest.predicate = nil;
    }
    return noteRequest;
}

@end
