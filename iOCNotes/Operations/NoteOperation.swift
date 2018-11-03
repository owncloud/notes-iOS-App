//
//  NoteOperation.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation

protocol NoteOperationDelegate {
    func didFail(operation: NoteOperation)
}

class NoteOperation: Operation {
    
    var note: Note
    var errorMessage: String?
    var responseDictionary: [String: Any]?
    var delegate: NoteOperationDelegate?
    
    private var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool {
        return _executing
    }
    
    private var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool {
        return _finished
    }
    
    func executing(_ executing: Bool) {
        _executing = executing
    }
    
    func finish(_ finished: Bool) {
        _finished = finished
    }
    
    override var isConcurrent: Bool {
        return true
    }
    
    override func start() {
        if self.isCancelled == true {
            self.finish(true)
            return
        }
        
        self.executing(true)
        self.performOperation()
    }
    
    init(note: Note, delegate: NoteOperationDelegate?) {
        self.note = note
        self.delegate = delegate
        _executing = false
        _finished = false
        super.init()
        self.qualityOfService = .userInitiated
    }
    
    func performOperation() {
        fatalError("performOperation() should be implemented by subclasses")
    }
    
}
