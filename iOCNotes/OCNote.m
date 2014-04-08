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
    return YES;
}

- (BOOL)shouldUpdate {
    return YES;
}

+ (id)primaryKeyValueForNewInstance {
    NSString * result;
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    
    result =[NSString stringWithFormat:@"%@", string];
    assert(result != nil);
    
    //NSLog(@"%@",result);
    return result;
}

@end
