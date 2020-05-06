//
//  SyncOperation.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 5/5/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Foundation

class SyncOperation: Operation {

    private let lockQueue = DispatchQueue(label: "com.peterandlinda.asyncoperation", attributes: .concurrent)

    private var _isExecuting: Bool = false
    private var _isFinished: Bool = false

    override var isAsynchronous: Bool {
        return true
    }

    override private(set) var isExecuting: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }

    override private(set) var isFinished: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        isFinished = false
        isExecuting = true
        main()
    }

    override func main() {
        NoteSessionManager.shared.sync {
            self.finish()
        }
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }
}
