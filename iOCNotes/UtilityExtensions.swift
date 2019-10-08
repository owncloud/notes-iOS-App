//
//  UtilityExtensions.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

extension NSNotification.Name {
    static let deletingNote = NSNotification.Name("DeletingNote")
    static let syncNotes = NSNotification.Name("SyncNotes")
    static let networkSuccess = NSNotification.Name("NetworkSucces")
    static let networkError = NSNotification.Name("NetworkError")
    static let offlineModeChanged = NSNotification.Name("OfflineModeChanged")
}

extension UIImage {
    static func colorResizableImage(color: UIColor) -> UIImage {
        var image = UIImage()
        let rect = CGRect(x: 0, y: 0, width: 3, height: 3)
        UIGraphicsBeginImageContext(rect.size)
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(rect)
            image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage();
        }
        UIGraphicsEndImageContext();
        image = image.resizableImage(withCapInsets: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        return image
    }
}
