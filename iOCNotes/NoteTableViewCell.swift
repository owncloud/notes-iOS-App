//
//  NotesTableViewCell.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/31/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class NoteTableViewCell: UITableViewCell {

    weak var categoryDelegate: NoteCategoryDelegate?
    var indexPath: IndexPath?
    
    @objc func selectCategory(sender: UIMenuController) {
        if let indexPath = indexPath {
            self.categoryDelegate?.selectCategory(indexPath)
        }
    }
}
