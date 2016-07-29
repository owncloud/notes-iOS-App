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
        alert = UIAlertController.init(title: "Share Note As", message: nil, preferredStyle: .ActionSheet)
        let plainTextAction = UIAlertAction.init(title: "Plain Text", style: .Default, handler: beginExport("txt"))
        let markdownAction = UIAlertAction.init(title: "Markdown", style: .Default, handler: beginExport("md"))
        let htmlAction = UIAlertAction.init(title: "HTML", style: .Default, handler: beginExport("html"))
        let richTextAction = UIAlertAction.init(title: "Rich Text", style: .Default, handler: beginExport("rtf"))
        let cancelAction = UIAlertAction.init(title: "Cancel", style: .Cancel, handler: beginExport(""))
        
        self.alert.addAction(plainTextAction)
        self.alert.addAction(markdownAction)
        self.alert.addAction(htmlAction)
        self.alert.addAction(richTextAction)
        self.alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController
        {
            popover.delegate = self
            popover.barButtonItem = self.barButtonItem!
            popover.permittedArrowDirections = .Any
        }
        
        self.viewController?.presentViewController(self.alert, animated: true, completion: nil)
    }
    
    func beginExport(type: String) -> (action: UIAlertAction) -> Void {
        return { alertAction in
            print("Export type: \(type)")
            
            let fileManager = NSFileManager.defaultManager()
            let docDir = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
            var fileURL = docDir?.URLByAppendingPathComponent("export")
            var isDir : ObjCBool = true
            if fileManager.fileExistsAtPath((fileURL?.path)!, isDirectory: &isDir) {
                do {
                    try fileManager.removeItemAtURL(fileURL!)
                    try fileManager.createDirectoryAtURL(fileURL!, withIntermediateDirectories: true, attributes: nil)
                    fileURL = fileURL!.URLByAppendingPathComponent(self.title!)
                    fileURL = fileURL!.URLByAppendingPathExtension(type)
                }
                catch
                {
                    //
                }
            }
            
            var activityItems = []
            
            switch type {
            case "txt", "md":
                do {
                    try self.text?.writeToURL(fileURL!, atomically: true, encoding: NSUTF8StringEncoding)
                    activityItems = [self.text!, fileURL!]
                }
                catch {}
            case "html":
                if let textToTransform = self.text {
                    var markdown = Markdown()
                    let outputHtml: String = markdown.transform(textToTransform)
                    let htmlTemplateURL = NSBundle.mainBundle().URLForResource("export", withExtension: "html")
                    do
                    {
                        let htmlTemplate = try String(contentsOfURL: htmlTemplateURL!)
                        var outputHtml = htmlTemplate.stringByReplacingOccurrencesOfString("$Markdown$", withString: outputHtml)
                        outputHtml = outputHtml.stringByReplacingOccurrencesOfString("$Title$", withString: self.title!)
                        try outputHtml.writeToURL(fileURL!, atomically: true, encoding: NSUTF8StringEncoding)
                        activityItems = [outputHtml, fileURL!]
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
                    let htmlTemplateURL = NSBundle.mainBundle().URLForResource("export", withExtension: "html")
                    do
                    {
                        let htmlTemplate = try String(contentsOfURL: htmlTemplateURL!)
                        var outputHtml = htmlTemplate.stringByReplacingOccurrencesOfString("$Markdown$", withString: outputHtml)
                        outputHtml = outputHtml.stringByReplacingOccurrencesOfString("$Title$", withString: self.title!)
                        let data = outputHtml.dataUsingEncoding(NSUTF8StringEncoding)
                        let attributedString = try NSAttributedString(data: data!, options: [NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType], documentAttributes: nil)
                        let rtfData = try attributedString.dataFromRange(NSMakeRange(0, attributedString.length), documentAttributes: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType])
                        try rtfData.writeToURL(fileURL!, options: .AtomicWrite)
                        activityItems = [attributedString, fileURL!]
                    }
                    catch
                    {
                        //
                    }
                }
            default:
                self.viewController?.dismissViewControllerAnimated(true, completion: nil)
            }
            let openInAppActivity = TTOpenInAppActivity.init(view: self.viewController?.view, andBarButtonItem: self.barButtonItem)
            let activityViewController = UIActivityViewController(activityItems: activityItems as [AnyObject], applicationActivities: [openInAppActivity])
            openInAppActivity.superViewController = activityViewController
            if let popover = activityViewController.popoverPresentationController
            {
                let barbuttonItem = self.viewController?.navigationItem.rightBarButtonItems?.first
                popover.delegate = self
                popover.barButtonItem = barbuttonItem
                popover.permittedArrowDirections = .Any
            }
            self.viewController?.presentViewController(activityViewController, animated: true, completion: nil)
        }
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }

}
