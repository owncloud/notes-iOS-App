//
//  PBHPreviewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/9/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import UIKit

@objc class PBHPreviewController: UIViewController {

    @objc dynamic var textAsMarkdown: String?
    @objc dynamic var noteTitle: String?

    @IBOutlet var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let textToTransform = textAsMarkdown
        {
            var markdown = Markdown()
            let outputHtml: String = markdown.transform(textToTransform)
            loadPreview(html: outputHtml)
        }
        self.navigationItem.title = noteTitle
    }

    func loadPreview(html: String) -> Void {
        let cssTemplateURL = Bundle.main.url(forResource: "github-markdown", withExtension: "css")
        let htmlTemplateURL = Bundle.main.url(forResource: "markdown", withExtension: "html")
        do
        {
            let cssTemplate = try String(contentsOf: cssTemplateURL!)
            let htmlTemplate = try String(contentsOf: htmlTemplateURL!)
            var outputHtml = htmlTemplate.replacingOccurrences(of: "$Markdown$", with: html)
            outputHtml = outputHtml.replacingOccurrences(of: "$Title$", with: noteTitle!)
            
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let cssOutputUrl = docDir?.appendingPathComponent("github-markdown").appendingPathExtension("css")
            let htmlOutputUrl = docDir?.appendingPathComponent("markdown").appendingPathExtension("html")
            try cssTemplate.write(to: cssOutputUrl!, atomically: true, encoding: String.Encoding.utf8)
            try outputHtml.write(to: htmlOutputUrl!, atomically: true, encoding: String.Encoding.utf8)
            let request = NSURLRequest(url: htmlOutputUrl!)
            webView.loadRequest(request as URLRequest)
        }
        catch
        {
         //
        }
    }
    
}

