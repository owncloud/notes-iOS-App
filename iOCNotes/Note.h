//
//  Note.h
//  iOCNotes
//
//  Created by Peter Hedlund on 1/19/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Note : NSManagedObject

@property (nonatomic, retain) NSNumber * myId;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSNumber * modified;

@end
