//
//  ModifiedValueTransformer.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/24/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class ModifiedValueTransformer: ValueTransformer {

    private var dateFormat: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none;
        df.doesRelativeDateFormatting = true
        return df
    }

    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let modifiedValue = value as? NSNumber else {
            return "Unknown"
        }

        let modified = modifiedValue.doubleValue
        let modifiedDate = Date(timeIntervalSince1970: modified)
        let result = dateFormat.string(from: modifiedDate as Date)
        return result
    }

}

extension NSValueTransformerName {
    static let modifiedValueTransformerName = NSValueTransformerName(rawValue: "ModifiedValueTransformer")
}
