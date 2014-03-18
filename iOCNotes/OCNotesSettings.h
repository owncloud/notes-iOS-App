//
//  OCEditorSettings.h
//  CloudNotes
//
//  Created by Peter Hedlund on 2/15/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCNotesSettings : NSObject <NSCoding> {
    NSArray *notesToAdd;
}

@property (nonatomic, copy) NSArray *notesToAdd;

@end
