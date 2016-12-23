//
//  PBHNoteExporter.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/20/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import CoreFoundation
import UIKit

@objc(PBHNoteExporter)
class PBHNoteExporter: NSObject, UIPopoverPresentationControllerDelegate {

    var text: String?
    var title: String?
    var viewController: UIViewController?
    var barButtonItem: UIBarButtonItem?
    
    var alert: UIAlertController!
    var activityPopover: UIPopoverController!
    
    init(viewController: UIViewController, barButtonItem: UIBarButtonItem, text: String, title: String) {
        super.init()
        
        self.viewController = viewController
        self.barButtonItem = barButtonItem
        self.text = text
        self.title = title
    }
    
    func showMenu() -> Void {
        alert = UIAlertController.init(title: "Share Note As", message: nil, preferredStyle: .actionSheet)
        let plainTextAction = UIAlertAction.init(title: "Plain Text", style: .default, handler: beginExport(type: "txt"))
        let markdownAction = UIAlertAction.init(title: "Markdown", style: .default, handler: beginExport(type: "md"))
        let htmlAction = UIAlertAction.init(title: "HTML", style: .default, handler: beginExport(type: "html"))
        let richTextAction = UIAlertAction.init(title: "Rich Text", style: .default, handler: beginExport(type: "rtf"))
        let cancelAction = UIAlertAction.init(title: "Cancel", style: .cancel, handler: beginExport(type: ""))
        
        self.alert.addAction(plainTextAction)
        self.alert.addAction(markdownAction)
        self.alert.addAction(htmlAction)
        self.alert.addAction(richTextAction)
        self.alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController
        {
            popover.delegate = self
            popover.barButtonItem = self.barButtonItem!
            popover.permittedArrowDirections = .any
        }
        
        self.viewController?.present(self.alert, animated: true, completion: nil)
    }
    
    func beginExport(type: String) -> (_ action: UIAlertAction) -> Void {
        return { alertAction in
            print("Export type: \(type)")
            
            let fileManager = FileManager.default
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            var fileURL = docDir?.appendingPathComponent("export")
            var isDir : ObjCBool = true
            if fileManager.fileExists(atPath: (fileURL?.path)!, isDirectory: &isDir) {
                do {
                    try fileManager.removeItem(at: fileURL!)
                    try fileManager.createDirectory(at: fileURL!, withIntermediateDirectories: true, attributes: nil)
                    fileURL = fileURL!.appendingPathComponent(self.title!).appendingPathExtension(type)
                }
                catch
                {
                    //
                }
            }
            
            var activityItems: [AnyObject]?
            
            switch type {
            case "txt", "md":
                do {
                    try self.text?.write(to: fileURL!, atomically: true, encoding: String.Encoding.utf8)
                    activityItems = [self.text! as AnyObject, fileURL! as AnyObject]
                }
                catch {}
            case "html":
                if let textToTransform = self.text {
                    var markdown = Markdown()
                    let outputHtml: String = markdown.transform(textToTransform)
                    let htmlTemplateURL = Bundle.main.url(forResource: "export", withExtension: "html")
                    do
                    {
                        let htmlTemplate = try String(contentsOf: htmlTemplateURL!)
                        var outputHtml = htmlTemplate.replacingOccurrences(of: "$Markdown$", with: outputHtml)
                        outputHtml = outputHtml.replacingOccurrences(of: "$Title$", with: self.title!)
                        try outputHtml.write(to: fileURL!, atomically: true, encoding: String.Encoding.utf8)
                        activityItems = [outputHtml as AnyObject, fileURL! as AnyObject]
                    }
                    catch
                    {
                        //
                    }
                }
            case "rtf":
                if let textToTransform = self.text {
                    var markdown = Markdown()
                    let outputHtml: String = markdown.transform(textToTransform)
                    let htmlTemplateURL = Bundle.main.url(forResource: "export", withExtension: "html")
                    do
                    {
                        let htmlTemplate = try String(contentsOf: htmlTemplateURL!)
                        var outputHtml = htmlTemplate.replacingOccurrences(of: "$Markdown$", with: outputHtml)
                        outputHtml = outputHtml.replacingOccurrences(of: "$Title$", with: self.title!)
                        let data = outputHtml.data(using: String.Encoding.utf8)
                        let attributedString = try NSAttributedString(data: data!, options: [NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType], documentAttributes: nil)
                        let rtfData = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType])
                        try rtfData.write(to: fileURL!, options: .atomicWrite)
                        activityItems = [attributedString as AnyObject, fileURL! as AnyObject]
                    }
                    catch
                    {
                        //
                    }
                }
            default:
                self.viewController?.dismiss(animated: true, completion: nil)
            }
            if activityItems != nil {
                let openInAppActivity = TTOpenInAppActivity.init(view: self.viewController?.view, andBarButtonItem: self.barButtonItem)
                let activityViewController = UIActivityViewController(activityItems: activityItems as [AnyObject]!, applicationActivities: [openInAppActivity!])
                openInAppActivity?.superViewController = activityViewController
                if let popover = activityViewController.popoverPresentationController
                {
                    let barbuttonItem = self.viewController?.navigationItem.rightBarButtonItems?.first
                    popover.delegate = self
                    popover.barButtonItem = barbuttonItem
                    popover.permittedArrowDirections = .any
                }
                self.viewController?.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

}
