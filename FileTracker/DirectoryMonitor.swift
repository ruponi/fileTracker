//
//  DirectoryMonitor.swift
//  FileTracker
//
//  Created by Ruslan on 5/18/17.
//  Copyright © 2017 RAsoft. All rights reserved.
//

import Foundation

private struct Constants {
    static let pollInterval: TimeInterval = 0.2
    static let pollRetryCount = 5
}

public class DirectoryMonitor {
    
    // MARK: - Errors
    public enum ErrorService:Error {
        case MonitoringNow
        case FailedToStartMonitor
        case InvalidPath
    }
    
    // MARK: - Notifications
    public enum ChageType:String {
        case Added="File Was Added"
        case Deleted="File Was Deleted"
        case Changed="File Was Changed"
        case Renamed="File Was Renamed"
        case Nothing="Nothing"
    }
    public struct ChangeNotification{
        var changeType:ChageType
        var changeObject:String
        var isChanged:Bool
    }
    
    
    // MARK: - Attributes
    public let watchedPath: NSURL
    
    private(set) var isObserving = false
    private var metadata: [(String,NSInteger)]=[]
    private var changeNotification:ChangeNotification?
    // MARK: - Attributes (Private)
    private let completionHandler: ((_ notification:ChangeNotification) -> Void)
    private var queue = DispatchQueue(label:"DirectoryMonitorQueue", attributes:DispatchQueue.Attributes.concurrent)
    private var retriesLeft = Constants.pollRetryCount
    private var isDirectoryChanging = false
    private var source: DispatchSourceFileSystemObject??
    
    
    // MARK: - Initializers
    public init(pathToWatch path: NSURL, callback: @escaping (_ notification:ChangeNotification) -> Void) {
        watchedPath = path
        completionHandler = callback
    }
    
    deinit { try? stopObserving() }
    
    
    // MARK: - Public Interface
    /// Starts the observer
    public func startObserving() throws {
        if source != nil {
            throw ErrorService.MonitoringNow
        }
        
        guard let path = watchedPath.path else {
            throw ErrorService.InvalidPath
        }
        
        // Open an event-only file descriptor associated with the directory
        let fd: CInt = open(path, O_EVTONLY)
        if fd < 0 { throw ErrorService.FailedToStartMonitor }
        
        let cleanup = DispatchWorkItem{ close(fd) }
        print("start monitoring:",path)
         self.metadata = directoryMetadata()
 
        // Monitor the directory for writes, delete, rename
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename,], queue: queue)
        
            
                  if let sources = source {
            // Call directoryDidChange on event callback
            
            sources?.setEventHandler(handler: {
               
                self.directoryDidChange()

            })
        
               // Dispatch source destructor
          sources?.setCancelHandler(handler: cleanup)
                 
            sources?.resume()
            // Sources are create in suspended state, so resume it
        
        } else {
            cleanup.perform()
            throw ErrorService.FailedToStartMonitor
        }
        
        isObserving = true
    }
    
    
    /// Stops the observer
    public func stopObserving() throws {
        if source != nil {
            source!?.cancel()
            source = nil
        }
        print("Stop Monitoring")
        isObserving = false
    }
    
    
    // MARK: - Private Methods
    private func directoryDidChange() {
        if !isDirectoryChanging {
            isDirectoryChanging = true
            retriesLeft = Constants.pollRetryCount
            checkForChangesAfterDelay()
        }
    }
    
    private func checkForChangesAfterDelay() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.pollInterval)
         {
            self.pollDirectoryForChanges(metadata: self.metadata)
            self.metadata = self.directoryMetadata()
        }
    }
    
    private func directoryMetadata() -> [(String,NSInteger)] {
        let fm = FileManager.default
        let contents = try? fm.contentsOfDirectory(at: watchedPath as URL, includingPropertiesForKeys: nil, options:[])
       
        var directoryMetadata: [(String,NSInteger)] = []
        
        if let contents = contents {
            for file in contents {
                autoreleasepool {
                    if let fileAttributes = try? fm.attributesOfItem(atPath: file.path) {
                        let fileSize = fileAttributes[FileAttributeKey.size] as! Int
                        directoryMetadata.append((file.lastPathComponent,fileSize))
                    }
                }
            }
        }
        
        return directoryMetadata
    }
    
    private func pollDirectoryForChanges(metadata oldDirectoryMetadata: [(String,NSInteger)]) {
        let newDirectoryMetadata = directoryMetadata()
        let compare = compareMetadata(oldMetadat: oldDirectoryMetadata, newMetadat: newDirectoryMetadata)
        
        isDirectoryChanging = compare.isChanged
        
        if isDirectoryChanging {
            self.changeNotification=compare
            }
        retriesLeft = isDirectoryChanging ? Constants.pollRetryCount : retriesLeft
        
        if isDirectoryChanging || (retriesLeft > 0) {
            retriesLeft -= 1
            checkForChangesAfterDelay()
        } else {
            DispatchQueue.main.async {
             
                [weak self] in
                self?.completionHandler((self?.changeNotification!)!)
                
            }
            }
        }
    
    //Compare changes initial state and current state============
    //return notification
    private func compareMetadata(oldMetadat:[(String,NSInteger)],newMetadat:[(String,NSInteger)])->ChangeNotification{
        var notification:ChangeNotification = ChangeNotification.init(changeType: .Nothing,
                                                                      changeObject: "",
                                                                      isChanged: false)
        var fileObject:String="";
        
        let oldSort = oldMetadat.sorted(by: {
            return $0.0 > $1.0
        })
        
        let newSort = newMetadat.sorted(by: {
            return $0.0 > $1.0
        })
        
        //If File/Dir Was Delteted
        if (oldSort.count>newSort.count){
            for i in 0..<oldSort.count {
                if (!newSort.contains(where: { $0.0==oldSort[i].0})){
                    fileObject=oldSort[i].0
                }
                
            }
            
        notification=ChangeNotification.init(changeType: .Deleted,
                                             changeObject: fileObject,
                                             isChanged: true)
            
        } else
            //If File/Dir Was Added
            if (oldSort.count<newSort.count){
               
                for i in 0..<newSort.count {
                    if (  !oldSort.contains(where: { $0.0==newSort[i].0})){
                        fileObject=newSort[i].0
                    }
                    
                }
                notification=ChangeNotification.init(changeType: .Added,
                                                     changeObject: fileObject,
                                                     isChanged: true)
                
            } else {
                //check for changes
                //file name change
                for i in 0..<oldSort.count {
                    if (oldSort[i].0 != newSort[i].0){
                        fileObject=oldSort[i].0
                        notification=ChangeNotification.init(changeType: .Renamed,
                                                             changeObject: fileObject,
                                                             isChanged: true)
                    }

                }
                
                //change data in file======
                
                for i in 0..<oldSort.count {
                    if (oldSort[i].0 == newSort[i].0 && oldSort[i].1 != newSort[i].1){
                        fileObject=oldSort[i].0
                        notification=ChangeNotification.init(changeType: .Changed,
                                                             changeObject: fileObject,
                                                             isChanged: true)
                    }
                    
                }
        }
    
        
        
     return notification
    }

    
   
    
    
    }



 

 
 
 
 
 
 
 
 
 
 
 
 
