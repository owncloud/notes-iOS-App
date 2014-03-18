//
//  OCNote.m
//  iOCNotes
//
//  Created by Peter Hedlund on 3/10/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCNote.h"

@implementation OCNote

- (BOOL)shouldInsert {
    //self.modified = [NSDate date].timeIntervalSince1970;
    return YES;
}

- (BOOL)shouldUpdate {
    //self.modified = [NSDate date].timeIntervalSince1970;
    return YES;
}

@end
