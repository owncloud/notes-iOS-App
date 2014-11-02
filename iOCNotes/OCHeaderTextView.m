//
//  OCHeaderTextView.m
//  iOCNotes
//
//  Created by Peter Hedlund on 10/26/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCHeaderTextView.h"
#import "PureLayout.h"

@interface OCHeaderTextView ()

@property (nonatomic, assign) BOOL didSetupConstraints;

@end

@implementation OCHeaderTextView

@synthesize headerLabel;
@synthesize bottomLayoutConstraint;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);
    self.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.headerLabel];
    [self setNeedsUpdateConstraints]; // bootstrap Auto Layout
}

- (void)updateConstraints
{
    if (!self.didSetupConstraints) {
        static const CGFloat kSmallPadding = 20.0;
        
        [self.headerLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.headerLabel autoSetDimension:ALDimensionWidth toSize:664];
            [self.headerLabel autoAlignAxis:ALAxisVertical toSameAxisOfView:self];
        } else {
            [self.headerLabel autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self withOffset:kSmallPadding];
            [self.headerLabel autoAlignAxis:ALAxisVertical toSameAxisOfView:self];
        }
        [self.headerLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:-kSmallPadding];
//        [self autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        self.didSetupConstraints = YES;
    }

    [super updateConstraints];
}

- (UILabel*)headerLabel {
    if (!headerLabel) {
        headerLabel = [UILabel newAutoLayoutView];
        headerLabel.numberOfLines = 1;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            headerLabel.textAlignment = NSTextAlignmentLeft;
        } else {
            headerLabel.textAlignment = NSTextAlignmentCenter;
        }
        headerLabel.textColor = [UIColor lightGrayColor];
        headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        headerLabel.text = NSLocalizedString(@"Select or create a note.", @"Placeholder text when no note is selected");
    }
    return headerLabel;
}

@end
