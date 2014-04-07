//
//  OCNote.h
//  iOCNotes
//
//  Created by Peter Hedlund on 3/10/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FCModel.h"

@interface OCNote : FCModel

// database columns:
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, assign) int64_t id;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) int64_t modified;

// non-columns:
@property (nonatomic) NSInteger status;

@end
