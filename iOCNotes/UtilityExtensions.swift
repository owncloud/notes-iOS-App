//
//  UtilityExtensions.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation

extension NSNotification.Name {
    static let deletingNote = NSNotification.Name("DeletingNote")
}

extension UIImage {
    static func resizeableImage(color: UIColor) -> UIImage {
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
