//
//  PBHHeaderTextView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/20/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import UIKit


@objc(PBHHeaderTextView)
class PBHHeaderTextView: UITextView, UITextDropDelegate {

    let kSmallPadding: CGFloat = 20.0

    var leftHeaderLayoutConstraint = NSLayoutConstraint()
    var rightHeaderLayoutConstraint = NSLayoutConstraint()
    var didSetupConstraints = false
    
    var myTextStorage = MarklightTextStorage()
    
    
    lazy var headerLabel: UILabel = {
        var theHeaderLabel = UILabel.newAutoLayout()
        theHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        theHeaderLabel.numberOfLines = 1;
        if (self.traitCollection.horizontalSizeClass == .regular) {
            theHeaderLabel.textAlignment = .left;
        } else {
            theHeaderLabel.textAlignment = .center
        }
        theHeaderLabel.textColor = UIColor.lightGray
        theHeaderLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        theHeaderLabel.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
    
        return theHeaderLabel
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        myTextStorage.marklightTextProcessor.codeColor = UIColor.green
        myTextStorage.marklightTextProcessor.quoteColor = UIColor.darkGray
        myTextStorage.marklightTextProcessor.syntaxColor = UIColor.blue
        
        let attributedString = NSAttributedString(string: "")
        myTextStorage.setAttributedString(attributedString)

//        let textViewRect = self.frame;
        
        let containerSize = CGSize(width: frame.size.width, height:CGFloat.greatestFiniteMagnitude)
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
        
        myTextStorage.marklightTextProcessor.codeColor = UIColor.green
        myTextStorage.marklightTextProcessor.quoteColor = UIColor.darkGray
        myTextStorage.marklightTextProcessor.syntaxColor = UIColor.blue
        
        let attributedString = NSAttributedString(string: "")
        myTextStorage.setAttributedString(attributedString)
        
        let textViewRect = self.frame;
        let layoutManager = NSLayoutManager()
        
        let containerSize = CGSize(width:textViewRect.size.width,  height:CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer.init(size: containerSize)
        container.widthTracksTextView = true
        
        layoutManager.addTextContainer(container)
        myTextStorage.addLayoutManager(layoutManager)
        
        self.setNeedsUpdateConstraints()
        self.traitCollectionDidChange(nil)
    }
    
    override func updateConstraints() {
        if (self.didSetupConstraints == false) {
            
            self.headerLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: UILayoutConstraintAxis.vertical)
            self.headerLabel.autoMatch(.height, to: .height, of: self.headerLabel, withOffset:0)
            self.headerLabel.autoPinEdge( toSuperviewEdge: .top, withInset:-kSmallPadding)
            leftHeaderLayoutConstraint = self.headerLabel.autoPinEdge( .leading, to: .leading, of: self, withOffset:kSmallPadding)
            rightHeaderLayoutConstraint = self.headerLabel.autoPinEdge( .trailing, to: .trailing, of: self, withOffset:kSmallPadding)
            self.headerLabel.autoAlignAxis( .vertical, toSameAxisOf: self)
            
            self.didSetupConstraints = true
        }
        super.updateConstraints()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if (self.traitCollection.horizontalSizeClass == .regular) {
            headerLabel.textAlignment = .left
            if (self.traitCollection.userInterfaceIdiom == .pad) {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    self.updateInsets(size: 178)
                } else {
                    self.updateInsets(size: 50)
                }
            } else {
                self.updateInsets(size: kSmallPadding)
            }
        } else {
            headerLabel.textAlignment = .center;
            self.updateInsets(size: kSmallPadding)
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
    
    open func updateInsets(size: CGFloat)
    {
        self.textContainerInset = UIEdgeInsetsMake(kSmallPadding, size, kSmallPadding, size);
        leftHeaderLayoutConstraint.constant = size;
        rightHeaderLayoutConstraint.constant = size;
    }
    
    @available(iOS 11, *)
    func textDroppableView(_ textDroppableView: UIView, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
        if drop.isSameView {
            return UITextDropProposal(operation: .move)

        } else {
            return UITextDropProposal(operation: .copy)
        }
    }
        
}
