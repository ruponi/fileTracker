//
//  FileTrackerTests.swift
//  FileTrackerTests
//
//  Created by Ruslan on 5/18/17.
//  Copyright © 2017 RAsoft. All rights reserved.
//

import XCTest

@testable import FileTracker

class FileTrackerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitMonitirWithCorrectURL() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first!
        
        let directoryWatcher:DirectoryMonitor=DirectoryMonitor.init(pathToWatch: documentsDirectory as NSURL) { (notification:DirectoryMonitor.ChangeNotification) in
            print("Directory contents have changed",notification)

        }
        do {
            try directoryWatcher.startObserving()
            XCTAssert(directoryWatcher.isObserving)
        }
        catch  {
            print(error)
        }

        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testinitMonitirWithBedURL() {
        let documentsDirectory:URL = URL.init(string: "user/dfdfff/")!
        
        let directoryWatcher:DirectoryMonitor=DirectoryMonitor.init(pathToWatch: documentsDirectory as NSURL) { (notification:DirectoryMonitor.ChangeNotification) in
            print("Directory contents have changed",notification)
            
        }
        do {
            try directoryWatcher.startObserving()
            
        }
        catch  {
            print(error)
            XCTAssert(!directoryWatcher.isObserving)
        }
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    
    
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
