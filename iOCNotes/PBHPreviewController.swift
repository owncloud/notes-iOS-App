//
//  PBHPreviewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/9/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import UIKit

@objc class PBHPreviewController: UIViewController {

    dynamic var textAsMarkdown: String?
    dynamic var noteTitle: String?

    @IBOutlet var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let textToTransform = textAsMarkdown
        {
            var markdown = Markdown()
            let outputHtml: String = markdown.transform(textToTransform)
            loadPreview(outputHtml)
        }
        self.navigationItem.title = noteTitle
    }

    func loadPreview(html: String) -> Void {
        let cssTemplateURL = NSBundle.mainBundle().URLForResource("github-markdown", withExtension: "css")
        let htmlTemplateURL = NSBundle.mainBundle().URLForResource("markdown", withExtension: "html")
        do
        {
            let cssTemplate = try String(contentsOfURL: cssTemplateURL!)
            let htmlTemplate = try String(contentsOfURL: htmlTemplateURL!)
            var outputHtml = htmlTemplate.stringByReplacingOccurrencesOfString("$Markdown$", withString: html)
            outputHtml = outputHtml.stringByReplacingOccurrencesOfString("$Title$", withString: noteTitle!)
            
            let docDir = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
            let cssOutputUrl = docDir?.URLByAppendingPathComponent("github-markdown").URLByAppendingPathExtension("css")
            let htmlOutputUrl = docDir?.URLByAppendingPathComponent("markdown").URLByAppendingPathExtension("html")
            try cssTemplate.writeToURL(cssOutputUrl!, atomically: true, encoding: NSUTF8StringEncoding)
            try outputHtml.writeToURL(htmlOutputUrl!, atomically: true, encoding: NSUTF8StringEncoding)
            let request = NSURLRequest(URL: htmlOutputUrl!)
            webView.loadRequest(request)
        }
        catch
        {
         //
        }
    }
    
}

