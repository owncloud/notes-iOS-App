//
//  OCEditorSettings.m
//  CloudNotes
//
//  Created by Peter Hedlund on 2/15/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCNotesSettings.h"

@implementation OCNotesSettings

@synthesize notesToAdd;

- (id) init {
	if (self = [super init]) {
        
    }
	return self;
}

#pragma mark - NSCoding Protocol

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super init])) {
        notesToAdd = [decoder decodeObjectForKey:@"NotesToAdd"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:notesToAdd forKey:@"NotesToAdd"];
}

@end
