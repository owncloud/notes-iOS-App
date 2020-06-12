//
//  UtilityExtensions.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

#if os(macOS)
import Foundation
#else
import UIKit
#endif

extension NSNotification.Name {
    static let deletingNote = NSNotification.Name("DeletingNote")
    static let syncNotes = NSNotification.Name("SyncNotes")
    static let networkSuccess = NSNotification.Name("NetworkSucces")
    static let networkError = NSNotification.Name("NetworkError")
    static let offlineModeChanged = NSNotification.Name("OfflineModeChanged")
    static let doneSelectingCategory = NSNotification.Name("DoneSelectingCategory")
    static let editorUpdatedNote = NSNotification.Name("EditorUpdatedNote")
    static let categoryUpdated = NSNotification.Name("CategoryUpdated")
}

struct ExpandableSection: Codable {
    var title: String
    var collapsed: Bool
}

typealias ExpandableSectionType = [ExpandableSection]

#if os(iOS)
extension UIImage {
    static func colorResizableImage(color: UIColor) -> UIImage {
        var image = UIImage()
        let rect = CGRect(x: 0, y: 0, width: 3, height: 3)
        UIGraphicsBeginImageContext(rect.size)
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(rect)
            image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
        UIGraphicsEndImageContext()
        image = image.resizableImage(withCapInsets: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        return image
    }
    
}

extension UIColor {

    static let ph_backgroundColor = UIColor(named: "PHWhiteBackground")!
    static let ph_cellBackgroundColor = UIColor(named: "PHWhiteCellBackground")!
    static let ph_cellSelectionColor = UIColor(named: "PHWhiteCellSelection")!
    static let ph_iconColor = UIColor(named: "PHWhiteIcon")!
    static let ph_textColor = UIColor(named: "PHWhiteText")!
    static let ph_readTextColor = UIColor(named: "PHWhiteReadText")!
    static let ph_linkColor = UIColor(named: "PHWhiteLink")!
    static let ph_popoverBackgroundColor = UIColor(named: "PHWhitePopoverBackground")!
    static let ph_popoverButtonColor = UIColor(named: "PHWhitePopoverButton")!
    static let ph_popoverBorderColor = UIColor(named: "PHWhitePopoverBorder")!
//    static let ph_popoverIconColor = UIColor(named: "PHWhitePopoverIcon")!
    static let ph_switchTintColor = UIColor(named: "PHWhitePopoverBorder")!

}

extension UILabel {

    @objc dynamic var themeColor: UIColor {
        get {
            self.textColor
        }
        set {
            self.textColor = newValue
        }
    }

}

extension UITextView {
  #if targetEnvironment(macCatalyst)
  @objc(_focusRingType)
  var focusRingType: UInt {
       return 1 //NSFocusRingTypeNone
  }
  #endif
}  
#endif

#if targetEnvironment(macCatalyst)
extension NSToolbarItem.Identifier {
    static let add = NSToolbarItem.Identifier(rawValue: "add")
    static let refresh = NSToolbarItem.Identifier(rawValue: "refresh")
    static let back = NSToolbarItem.Identifier(rawValue: "back")
    static let preview = NSToolbarItem.Identifier(rawValue: "preview")
    static let share = NSToolbarItem.Identifier(rawValue: "share")
    static let segmented = NSToolbarItem.Identifier(rawValue: "segmented")
}
#endif

extension String {
    
    func truncate(length: Int, trailing: String = "…") -> String {
        if (self.count <= length) {
            return self
        }
        var truncated = self.prefix(length)
        while truncated.last != " " {
            truncated = truncated.dropLast()
        }
        return truncated + trailing
    }
    
}

func noteTitle(_ note: NoteProtocol) -> String {
    var result = note.title
    if note.content.isEmpty {
        result = note.title
    } else {
        if note.title.count <= 50 || note.title.hasPrefix(Constants.newNote) {
            let components = note.content.split(separator: "\n")
            result = String(components.first ?? "")
            let forbiddenCharacters: Set<Character> = ["*", "|", "/", "\\", ":", "\"", "<", ">", "?"]
            result.removeAll(where: { forbiddenCharacters.contains($0) })
            result = result.trimmingCharacters(in: .whitespaces)
            result = result.truncate(length: 50)
        }
    }
    return result
}
