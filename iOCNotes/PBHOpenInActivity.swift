//
//  PBHOpenInActivity.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 8/17/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

let openInActivityType = "OpenIn"

class PBHOpenInActivity: UIActivity {

    var documentController: UIDocumentInteractionController!
    weak var barButton: UIBarButtonItem!
    
    init(barButton: UIBarButtonItem) {
        self.barButton = barButton
    }

    override var activityType: ActivityType {
        return ActivityType(rawValue: openInActivityType)
    }

    override var activityTitle: String {
        return NSLocalizedString("Open In...", comment: "Title for Open In activity")
    }

    override var activityImage: UIImage {
        return UIImage(named: "share")!
    }

    override class var activityCategory: Category {
        return .share
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if item is URL  {
                return true
            }
        }
        return false
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let url = item as? URL  {
                documentController = UIDocumentInteractionController(url: url)
            }
        }
    }

    override func perform() {
        documentController.presentOpenInMenu(from: barButton, animated: true)
    }
}
