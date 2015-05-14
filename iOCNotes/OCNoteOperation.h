//
//  OCNoteOperation.h
//  iOCNotes
//
//  Created by Peter Hedlund on 4/27/15.
//  Copyright (c) 2015 Peter Hedlund. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCNote.h"

typedef NS_ENUM(NSInteger, NoteOperationType) {
    NoteOperationTypeAdd,
    NoteOperationTypeUpdate,
    NoteOperationTypeGet,
    NoteOperationTypeDelete
};

@protocol OCNoteOperationDelegate;

@interface OCNoteOperation : NSOperation
{
    id <OCNoteOperationDelegate> __unsafe_unretained delegate;
}

- (id)initWithNote:(OCNote *)note noteOperationType:(NoteOperationType)operationType delegate:(id<OCNoteOperationDelegate>)delegate;

@property (nonatomic, unsafe_unretained) id <OCNoteOperationDelegate> delegate;
@property (nonatomic, strong, readonly) OCNote *note;
@property (nonatomic, strong, readonly) NSString *errorMessage;
@property (nonatomic, strong, readonly) NSDictionary *responseDictionary;
@property (nonatomic, assign) NoteOperationType noteOperationType;

@end

@protocol OCNoteOperationDelegate <NSObject>

@optional
- (void)noteOperationDidStart:(OCNoteOperation *)noteOperation;
- (void)noteOperationDidFinish:(OCNoteOperation *)noteOperation;
- (void)noteOperationDidFail:(OCNoteOperation *)noteOperation;

@end
