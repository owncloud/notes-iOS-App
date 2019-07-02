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

    var textAsMarkdown: String?
    var noteTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let content = textAsMarkdown {
            do {
                let downView = try DownView(frame: view.bounds, markdownString: content, didLoadSuccessfully: {
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
