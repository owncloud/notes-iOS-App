//
//  PBHNoteExporter.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/20/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import CoreFoundation
import Down
import UIKit

class PBHNoteExporter: NSObject {

    var text: String
    var title: String
    var viewController: UIViewController
    var barButtonItem: UIBarButtonItem
    
    var alert: UIAlertController!

    init(viewController: UIViewController, barButtonItem: UIBarButtonItem, text: String, title: String) {
        self.viewController = viewController
        self.barButtonItem = barButtonItem
        self.text = text
        self.title = title
        super.init()
    }
    
    func showMenu() -> Void {
        alert = UIAlertController.init(title: NSLocalizedString("Share Note As", comment: "Title of a menu with sharing options"), message: nil, preferredStyle: .actionSheet)
        let plainTextAction = UIAlertAction.init(title: NSLocalizedString("Plain Text", comment: "A menu option for sharing in plain text format"), style: .default, handler: beginExport(type: "txt"))
        let markdownAction = UIAlertAction.init(title: NSLocalizedString("Markdown", comment: "A menu option for sharing in markdown format"), style: .default, handler: beginExport(type: "md"))
        let htmlAction = UIAlertAction.init(title: NSLocalizedString("HTML", comment: "A menu option for plain sharing in html format"), style: .default, handler: beginExport(type: "html"))
        let richTextAction = UIAlertAction.init(title: NSLocalizedString("Rich Text", comment: "A menu option for sharing in rich text format"), style: .default, handler: beginExport(type: "rtf"))
        let cancelAction = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: "A menu option for cancelling"), style: .cancel, handler: beginExport(type: ""))
        
        alert.addAction(plainTextAction)
        alert.addAction(markdownAction)
        alert.addAction(htmlAction)
        alert.addAction(richTextAction)
        alert.addAction(cancelAction)
        alert.modalPresentationStyle = .popover
        
        if let popover = alert.popoverPresentationController {
            popover.delegate = self
            popover.barButtonItem = self.barButtonItem
            popover.permittedArrowDirections = .any
        }
        viewController.present(alert, animated: true, completion: nil)
    }
    
    func beginExport(type: String) -> (_ action: UIAlertAction) -> Void {
        return { alertAction in
            print("Export type: \(type)")
            guard !self.text.isEmpty else {
                return
            }
            let fileManager = FileManager.default
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            if let outputDirectory = docDir?.appendingPathComponent("export") {
                var isDir : ObjCBool = true
                if fileManager.fileExists(atPath: outputDirectory.path, isDirectory: &isDir) {
                    do {
                        try fileManager.removeItem(at: outputDirectory)
                    } catch { }
                }
                do {
                    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch { }
                let fileURL = outputDirectory.appendingPathComponent(self.title, isDirectory: false).appendingPathExtension(type)
                var activityItems: [AnyObject]?

                switch type {
                case "txt":
                    do {
                        try self.text.write(to: fileURL, atomically: true, encoding: .utf8)
                        activityItems = [self.text as AnyObject, fileURL as AnyObject]
                    } catch {}
                case "md":
                    do {
                        let down = Down(markdownString: self.text)
                        if let commonMark = try? down.toCommonMark() {
                            try commonMark.write(to: fileURL, atomically: true, encoding: .utf8)
                            activityItems = [self.text as AnyObject, fileURL as AnyObject]
                        }
                    } catch {}
                case "html":
                        do {
                            let down = Down(markdownString: self.text)
                            if let outputHtml = try? down.toHTML() {
                                let htmlTemplate = """
                                <?xml version="1.0" encoding="utf-8"?>
                                <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
                                <html xmlns="http://www.w3.org/1999/xhtml">
                                    <head>
                                        <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=2.0, user-scalable=yes" />
                                        <title>
                                            \(self.title)
                                        </title>
                                    </head>
                                    <body>
                                        <article>
                                            \(outputHtml)
                                        </article>
                                    </body>
                                </html>
                                """
                                try htmlTemplate.write(to: fileURL, atomically: true, encoding: .utf8)
                                activityItems = [htmlTemplate as AnyObject, fileURL as AnyObject]
                            }
                        } catch { }

                case "rtf":
                    do {
                        let down = Down(markdownString: self.text)
                        if let output = try? down.toAttributedString() {
                            let rtfData = try output.data(from: NSMakeRange(0, output.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
                                try rtfData.write(to: fileURL, options: .atomicWrite)
                                activityItems = [rtfData as AnyObject, fileURL as AnyObject]
                            }
                        } catch { }
                default:
                    self.viewController.dismiss(animated: true, completion: nil)
                }
                if let activityItems = activityItems {
                    let openInAppActivity = PBHOpenInActivity(barButton: self.barButtonItem)
                    let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: [openInAppActivity])
                    if let popover = activityViewController.popoverPresentationController {
                        let barbuttonItem = self.viewController.navigationItem.rightBarButtonItems?.first
                        popover.delegate = self
                        popover.barButtonItem = barbuttonItem
                        popover.permittedArrowDirections = .any
                    }
                    self.viewController.present(activityViewController, animated: true, completion: nil)
                }
            }
        }
    }

}

extension PBHNoteExporter: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

}
