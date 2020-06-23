//
//  PBHHeaderTextView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/20/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import UIKit
import Notepad

class PBHHeaderTextView: UITextView {

    let smallPadding: CGFloat = 20.0

    private var leftHeaderLayoutConstraint = NSLayoutConstraint()
    private var rightHeaderLayoutConstraint = NSLayoutConstraint()
    private var didSetupConstraints = false
    private var headerLabelConstraintConstant: CGFloat = 20.0
    
    private var noteTextStorage = Storage()

    private var textInset = UIEdgeInsets(top: 30, left: 0, bottom: 0, right: 0);
    private var containerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20);

    lazy var headerLabel: UILabel = {
        var label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1;
        if (self.traitCollection.horizontalSizeClass == .regular) {
            label.textAlignment = .left;
        } else {
            label.textAlignment = .center
        }
        label.textColor = .lightGray
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
    
        return label
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let attributedString = NSAttributedString(string: "")
        noteTextStorage.setAttributedString(attributedString)

        let containerSize = CGSize(width: frame.size.width, height:CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        let theme = Theme("system-minimal")
        noteTextStorage.theme = theme
        noteTextStorage.addLayoutManager(layoutManager)

        super.init(frame: frame, textContainer: container)
        self.contentInset = textInset
        self.textContainerInset = containerInset
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(headerLabel)
        self.backgroundColor = theme.backgroundColor
        self.tintColor = theme.tintColor
        self.setNeedsUpdateConstraints()
        self.traitCollectionDidChange(nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.contentInset = textInset
        self.textContainerInset = containerInset
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(headerLabel)
        
        let attributedString = NSAttributedString(string: "")
        noteTextStorage.setAttributedString(attributedString)
        
        let textViewRect = self.frame;
        let layoutManager = NSLayoutManager()
        
        let containerSize = CGSize(width:textViewRect.size.width, height:CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer.init(size: containerSize)
        container.widthTracksTextView = true
        
        layoutManager.addTextContainer(container)
        noteTextStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        let theme = Theme("system-minimal")
        noteTextStorage.theme = theme
        noteTextStorage.addLayoutManager(layoutManager)

        self.backgroundColor = theme.backgroundColor
        self.tintColor = theme.tintColor
        self.setNeedsUpdateConstraints()
        self.traitCollectionDidChange(nil)
    }
    
    override func updateConstraints() {
        if (self.didSetupConstraints == false) {
            self.headerLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            leftHeaderLayoutConstraint = self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: headerLabelConstraintConstant)
            rightHeaderLayoutConstraint = self.headerLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -headerLabelConstraintConstant)
            NSLayoutConstraint.activate([
                self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
                leftHeaderLayoutConstraint,
                rightHeaderLayoutConstraint,
                self.headerLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor)
            ])
            self.didSetupConstraints = true
        }
        super.updateConstraints()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (self.traitCollection.horizontalSizeClass == .regular) {
            self.headerLabel.textAlignment = .left
            if (self.traitCollection.userInterfaceIdiom == .pad) {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    self.updateInsets(size: 178)
                } else {
                    self.updateInsets(size: 50)
                }
            } else {
                self.updateInsets(size: smallPadding)
            }
        } else {
            self.headerLabel.textAlignment = .center;
            self.updateInsets(size: smallPadding)
        }
        self.isScrollEnabled = false
        self.isScrollEnabled = true
    }

    override var text: String! {
        get {
            return noteTextStorage.string
        }
        set {
            noteTextStorage.beginEditing()
            let attributedString = newValue != nil ? NSAttributedString(string: newValue) : NSAttributedString()
            noteTextStorage.setAttributedString(attributedString)
            noteTextStorage.endEditing()
        }
    }

    open func updateInsets(size: CGFloat) {
        self.textContainerInset = UIEdgeInsets(top: 2 * smallPadding, left: size, bottom: smallPadding, right: size);
        headerLabelConstraintConstant = size
        leftHeaderLayoutConstraint.constant = size;
        rightHeaderLayoutConstraint.constant = size;
    }

}

extension PBHHeaderTextView: UITextDropDelegate {

    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
        if drop.isSameView {
            return UITextDropProposal(operation: .move)
        } else {
            return UITextDropProposal(operation: .copy)
        }
    }
        
}
