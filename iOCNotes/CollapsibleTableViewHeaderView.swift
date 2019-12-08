//  
//  CollapsibleTableViewHeaderView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 8/5/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

protocol CollapsibleTableViewHeaderViewDelegate {
    func toggleSection(_ header: CollapsibleTableViewHeaderView, sectionTitle: String, sectionIndex: Int)
}

class CollapsibleTableViewHeaderView: UITableViewHeaderFooterView {

    @IBOutlet var folderImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var collapsedImageView: UIImageView!
    
    var delegate: CollapsibleTableViewHeaderViewDelegate?
    var sectionTitle = Constants.noCategory
    var sectionIndex = 0

    var collapsed: Bool {
        didSet {
            collapsedImageView.rotate(collapsed ? -(.pi / 2) : 0.0)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        collapsed = false
        super.init(coder: aDecoder)
        #if !targetEnvironment(macCatalyst)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .ph_backgroundColor
        self.backgroundView = backgroundView
        #endif
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(CollapsibleTableViewHeaderView.onTap(_:))))
    }
    
    override func draw(_ rect: CGRect) {
        #if targetEnvironment(macCatalyst)
        self.titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        self.titleLabel.textColor = .label
        self.folderImageView.isHidden = true
        #endif
        super.draw(rect)
    }
    
    @objc func onTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let _ = gestureRecognizer.view as? CollapsibleTableViewHeaderView else {
            return
        }
        delegate?.toggleSection(self, sectionTitle: sectionTitle, sectionIndex: sectionIndex)
    }
}

extension UIView {
    
    func rotate(_ toValue: CGFloat, duration: CFTimeInterval = 0.2) {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        
        animation.toValue = toValue
        animation.duration = duration
        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        self.layer.add(animation, forKey: nil)
    }
    
}
