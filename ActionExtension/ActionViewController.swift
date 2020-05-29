//
//  ActionViewController.swift
//  ActionExtension
//
//  Created by Peter Hedlund on 5/16/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {

    private var content: String?

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Get the item[s] we're handling from the extension context.
        
        var textFound = false
        if let inputItems = self.extensionContext?.inputItems as? [NSExtensionItem] {
            for inputItem in inputItems {
                if let attachments = inputItem.attachments {
                    for provider in attachments {
                        if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil, completionHandler: {
                                [weak self] (item, error) in
                                self?.content = item as? String
                                textFound = true
                            })
                        } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                            provider.loadItem(forTypeIdentifier: "public.url", options: nil, completionHandler: {
                                [weak self] (item, error) in
                                self?.content = (item as? URL)?.absoluteString
                                textFound = true
                            })

                        }
                        if textFound {
                            // We only handle one item, so stop looking for more.
                            break
                        }
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let content = content, let context = extensionContext {
            let selector = Selector("openURL:")
            var urlComponents = URLComponents()
            urlComponents.scheme = "cloudnotes"
            urlComponents.path = "action"
            urlComponents.queryItems = [URLQueryItem(name: "note", value: content)]
            if let url = urlComponents.url {
                var responder: UIResponder? = self
                while let r = responder {
                    if r.responds(to: selector) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            context.completeRequest(returningItems: context.inputItems) { expired in
                                if !expired {
                                    r.perform(selector, with: url)
                                }
                            }
                        }
                        break
                    }
                    responder = r.next
                }
            }
        }
    }
    
}
