//
//  OCHeaderTextView.h
//  iOCNotes
//
//  Created by Peter Hedlund on 10/26/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OCHeaderTextView : UITextView

@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) NSLayoutConstraint *bottomLayoutConstraint;

- (void)updateInsetsToSize:(CGFloat)inset;

@end
