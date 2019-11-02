//
//  NotesTests.swift
//  iOCNotesTests
//
//  Created by Peter Hedlund on 10/20/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import XCTest
@testable import iOCNotes

class NotesTests: XCTestCase {
    var currentServer: String = ""
    var currentUser: String = ""
    var currentPassword: String = ""
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        currentServer = KeychainHelper.server
        currentUser = KeychainHelper.username
        currentPassword = KeychainHelper.password
        
        //Test using a Docker container
        KeychainHelper.server = "http://localhost:8080"
        KeychainHelper.username = "cloudnotes"
        KeychainHelper.password = "cloudnotes"
        
        //Clear database
        CDNote.reset()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        KeychainHelper.server = currentServer
        KeychainHelper.username = currentUser
        KeychainHelper.password = currentPassword
        super.tearDown()
    }

    func testAddNote() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        let content = "Note added during test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            XCTAssertTrue(note?.addNeeded == false, "Expected addNeeded to be false")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 20.0)
    }

    func testAddNoteWithCategory() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        let content = "Note with category added during test"
        let category = "Test Category"
        NotesManager.shared.add(content: content, category: category, completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            XCTAssertTrue(note?.addNeeded == false, "Expected addNeeded to be false")
            XCTAssertEqual(note?.category, "Test Category", "Expected the category to be Test Category")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 20.0)
    }

    func testAddAndDeleteNote() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        let content = "Note added and deleted during test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            XCTAssertTrue(note?.addNeeded == false, "Expected addNeeded to be false")
            if let note = note {
                NotesManager.shared.delete(note: note) {
                    expectation.fulfill()
                }
            }
        })
        wait(for: [expectation], timeout: 25.0)
    }

    func testAddAndDeleteNoteWithCategory() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        let content = "Note added and deleted during test"
        let category = "Test Category"
        NotesManager.shared.add(content: content, category: category, completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            XCTAssertTrue(note?.addNeeded == false, "Expected addNeeded to be false")
            XCTAssertEqual(note?.category, "Test Category", "Expected the category to be Test Category")
            if let note = note {
                NotesManager.shared.delete(note: note) {
                    expectation.fulfill()
                }
            }
        })
        wait(for: [expectation], timeout: 25.0)
    }

    func testAddOffline() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        KeychainHelper.offlineMode = true
        let content = "Note added during offline test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            XCTAssertTrue(note?.addNeeded == true, "Expected addNeeded to be true")
            KeychainHelper.offlineMode = false
            NotesManager.shared.sync() {
                if CDNote.all()?.filter( { $0.addNeeded == true }).count ?? 0 > 0 {
                    XCTFail("Expected addNeeded count to be 0")
                }
                expectation.fulfill()
            }
        })
        wait(for: [expectation], timeout: 25.0)
    }

    func testAddAndReset() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        expectation.expectedFulfillmentCount = 4
        var content = "Note 1 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 2 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 3 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 4 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 35.0)
        CDNote.reset()
        if CDNote.all()?.count ?? 0 > 0 {
            XCTFail("Expected note count to be 0")
        }
    }

    func testAddAndResetWithCategories() {
        let expectation = XCTestExpectation(description: "Note Expectation")
        expectation.expectedFulfillmentCount = 4
        var content = "Note 1 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 2 added during reset test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 3 added during reset test"
        NotesManager.shared.add(content: content, category: "A Category", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        content = "Note 4 added during reset test"
        NotesManager.shared.add(content: content, category: "A Category", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 35.0)
        CDNote.reset()
        if CDNote.all()?.count ?? 0 > 0 {
            XCTFail("Expected note count to be 0")
        }
    }

    func testAddAndMove() {
//        var note1: CDNote?
        var note2: CDNote?
//        var note3: CDNote?
        var note4: CDNote?
        let expectation = XCTestExpectation(description: "Note Expectation")
        expectation.expectedFulfillmentCount = 4
        var content = "Note 1 added during add and move test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
//            note1 = note
            expectation.fulfill()
        })
        content = "Note 2 added during add and move test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            note2 = note
            expectation.fulfill()
        })
        content = "Note 3 added during add and move test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
//            note3 = note
            expectation.fulfill()
        })
        content = "Note 4 added during add and move test"
        NotesManager.shared.add(content: content, category: "", completion: { note in
            XCTAssertNotNil(note, "Expected note to not be nil")
            note4 = note
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 35.0)

        let expectation2 = XCTestExpectation(description: "Note Expectation 2")
        expectation2.expectedFulfillmentCount = 2

        note2?.category = "Add and Move Category"
        NotesManager.shared.update(note: note2!) {
            expectation2.fulfill()
        }
        note4?.category = "Add and Move Category"
        NotesManager.shared.update(note: note4!) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 15.0)
        if CDNote.all()?.filter( { $0.category == "Add and Move Category" }).count ?? 0 != 2 {
            XCTFail("Expected category count to be 2")
        }
    }
}
