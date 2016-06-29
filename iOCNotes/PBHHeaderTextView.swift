//
//  PBHHeaderTextView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/20/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import UIKit


@objc(PBHHeaderTextView)
class PBHHeaderTextView: UITextView {

    let kSmallPadding: CGFloat = 20.0

    var leftHeaderLayoutConstraint = NSLayoutConstraint()
    var rightHeaderLayoutConstraint = NSLayoutConstraint()
    var didSetupConstraints = false
    
    var myTextStorage = MarklightTextStorage()
    
    
    lazy var headerLabel: UILabel = {
        var theHeaderLabel = UILabel.newAutoLayoutView()
        theHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        theHeaderLabel.numberOfLines = 1;
        if (self.traitCollection.horizontalSizeClass == .Regular) {
            theHeaderLabel.textAlignment = .Left;
        } else {
            theHeaderLabel.textAlignment = .Center
        }
        theHeaderLabel.textColor = UIColor.lightGrayColor()
        theHeaderLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        theHeaderLabel.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
    
        return theHeaderLabel
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        myTextStorage.codeColor = UIColor.greenColor()
        myTextStorage.quoteColor = UIColor.darkGrayColor()
        myTextStorage.syntaxColor = UIColor.blueColor()
        
        let attributedString = NSAttributedString(string: "")
        myTextStorage.setAttributedString(attributedString)

//        let textViewRect = self.frame;
        
        let containerSize = CGSizeMake(frame.size.width,  CGFloat.max)
        let container = NSTextContainer.init(size: containerSize)
        container.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        myTextStorage.addLayoutManager(layoutManager)

        super.init(frame: frame, textContainer: container)
        self.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);
        self.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(headerLabel)
        self.setNeedsUpdateConstraints()
        self.traitCollectionDidChange(nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);
        self.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(headerLabel)
        
        myTextStorage.codeColor = UIColor.greenColor()
        myTextStorage.quoteColor = UIColor.darkGrayColor()
        myTextStorage.syntaxColor = UIColor.blueColor()
        
        let attributedString = NSAttributedString(string: "")
        myTextStorage.setAttributedString(attributedString)
        
        let textViewRect = self.frame;
        let layoutManager = NSLayoutManager()
        
        let containerSize = CGSizeMake(textViewRect.size.width,  CGFloat.max)
        let container = NSTextContainer.init(size: containerSize)
        container.widthTracksTextView = true
        
        layoutManager.addTextContainer(container)
        myTextStorage.addLayoutManager(layoutManager)
        
        self.setNeedsUpdateConstraints()
        self.traitCollectionDidChange(nil)
    }
    
    override func updateConstraints() {
        if (self.didSetupConstraints == false) {
            
            self.headerLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, forAxis: UILayoutConstraintAxis.Vertical)
            self.headerLabel.autoMatchDimension(.Height, toDimension: .Height, ofView: self.headerLabel, withOffset:0)
            self.headerLabel.autoPinEdgeToSuperviewEdge( .Top, withInset:-kSmallPadding)
            leftHeaderLayoutConstraint = self.headerLabel.autoPinEdge( .Leading, toEdge: .Leading, ofView: self, withOffset:kSmallPadding)
            rightHeaderLayoutConstraint = self.headerLabel.autoPinEdge( .Trailing, toEdge: .Trailing, ofView: self, withOffset:kSmallPadding)
            self.headerLabel.autoAlignAxis( .Vertical, toSameAxisOfView: self)
            
            self.didSetupConstraints = true
        }
        super.updateConstraints()
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        if (self.traitCollection.horizontalSizeClass == .Regular) {
            headerLabel.textAlignment = .Left
            if (self.traitCollection.userInterfaceIdiom == .Pad) {
                if (self.frame.size.width > self.frame.size.height) {
                    self.updateInsetsToSize(178)
                } else {
                    self.updateInsetsToSize(178)
                }
            } else {
                self.updateInsetsToSize(kSmallPadding)
            }
        } else {
            headerLabel.textAlignment = .Center;
            self.updateInsetsToSize(kSmallPadding)
        }
    }

    override var text: String! {
        get {
            return self.attributedText.string
        }
        set {
            myTextStorage.beginEditing()
            let attributedString = newValue != nil ? NSAttributedString.init(string: newValue) : NSAttributedString()
            myTextStorage.setAttributedString(attributedString)
            myTextStorage.endEditing()
        }
    }

    override var attributedText: NSAttributedString! {
        get {
            return myTextStorage.attributedString
        }
        set {
            myTextStorage.beginEditing()
            myTextStorage.setAttributedString(newValue)
            myTextStorage.endEditing()
        }
    }
    
    func updateInsetsToSize(inset: CGFloat)
    {
        self.textContainerInset = UIEdgeInsetsMake(kSmallPadding, inset, kSmallPadding, inset);
        leftHeaderLayoutConstraint.constant = inset;
        rightHeaderLayoutConstraint.constant = inset;
    }

}
