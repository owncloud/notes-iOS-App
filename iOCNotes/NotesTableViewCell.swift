//
//  NotesTableViewCell.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/31/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class NoteTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @objc func selectCategory(sender: UIMenuController) {
        print("Help 3")
    }
}
