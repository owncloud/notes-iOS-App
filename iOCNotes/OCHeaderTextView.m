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
{
    NSLayoutConstraint *leftHeaderLayoutConstraint;
    NSLayoutConstraint *rightHeaderLayoutConstraint;
}

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
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_8_3) {
        self.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);
    } else {
        self.contentInset = UIEdgeInsetsMake(94, 0, 0, 0);
    }
    self.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.headerLabel];
    [self setNeedsUpdateConstraints]; // bootstrap Auto Layout
    [self traitCollectionDidChange:nil];
}

- (void)updateConstraints
{
    if (!self.didSetupConstraints) {
        static const CGFloat kSmallPadding = 20.0;
        
        [self.headerLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self.headerLabel autoMatchDimension:ALDimensionHeight toDimension:ALDimensionHeight ofView:self.headerLabel withOffset:0];
        [self.headerLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:-kSmallPadding];
        leftHeaderLayoutConstraint = [self.headerLabel autoPinEdge:ALEdgeLeading toEdge:ALEdgeLeading ofView:self withOffset:20];
        rightHeaderLayoutConstraint = [self.headerLabel autoPinEdge:ALEdgeTrailing toEdge:ALEdgeTrailing ofView:self withOffset:20];
        [self.headerLabel autoAlignAxis:ALAxisVertical toSameAxisOfView:self];
        
        self.didSetupConstraints = YES;
    }
    [super updateConstraints];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        headerLabel.textAlignment = NSTextAlignmentLeft;
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            if (self.frame.size.width > self.frame.size.height) {
                [self updateInsetsToSize:178];
            } else {
                [self updateInsetsToSize:178];
            }
        } else {
            [self updateInsetsToSize:20];            
        }
    } else {
        headerLabel.textAlignment = NSTextAlignmentCenter;
        [self updateInsetsToSize:20];
    }
}

- (void)updateInsetsToSize:(CGFloat)inset;
{
    self.textContainerInset = UIEdgeInsetsMake(20, inset, 20, inset);
    leftHeaderLayoutConstraint.constant = inset;
    rightHeaderLayoutConstraint.constant = inset;
}

- (UILabel*)headerLabel {
    if (!headerLabel) {
        headerLabel = [UILabel newAutoLayoutView];
        headerLabel.numberOfLines = 1;
        if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
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
