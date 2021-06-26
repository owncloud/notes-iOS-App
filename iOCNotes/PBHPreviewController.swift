//
//  PBHPreviewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/9/16.
//  Copyright © 2016 Peter Hedlund. All rights reserved.
//

import Down
import UIKit

class PBHPreviewController: UIViewController {

    var content: String?
    var noteTitle: String?
    var noteDate: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        var previewContent = ""
        if let noteTitle = noteTitle {
            previewContent.append("# \(noteTitle)\n")
        }
        if let noteDate = noteDate {
            previewContent.append("*\(noteDate)*\n\n")
        }
        if let content = content {
            do {
                previewContent.append(content)
                let downView = try DownView(frame: view.frame, markdownString: previewContent, openLinksInBrowser: true, templateBundle: Bundle(path: "DownView.bundle"), configuration: nil, options: [], didLoadSuccessfully: {
                    print("Markdown was rendered.")
                })
                downView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(downView)
                NSLayoutConstraint.activate([
                    downView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    downView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    downView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    downView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
                ])
            } catch { }
        }
        self.navigationItem.title = noteTitle
    }

}
