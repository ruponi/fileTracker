//
//  ViewController.swift
//  FileTracker
//
//  Created by Ruslan on 5/18/17.
//  Copyright © 2017 RAsoft. All rights reserved.
//

import UIKit


protocol CellFolderDelegate {
    
    func on_startPressed(_ sender:Any)
}

class CellFolder:UITableViewCell{
    
    
    @IBOutlet weak var labelFolderName:UILabel!
    @IBOutlet weak var swithStart:UISwitch!
    var delegated:CellFolderDelegate?
    
    @IBAction func onSwitchChange(_ sender: Any) {
       delegated?.on_startPressed(self)
        
    }
}


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,CellFolderDelegate {

    @IBOutlet weak var tbl_folders: UITableView!
    var directoriesList:[(URL,String)]=[]
    var directoryWatcher:DirectoryMonitor?
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
   
    
    override func viewDidAppear(_ animated: Bool) {
  
 
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first!
        let cashesDirectory = FileManager.default.urls(for: .cachesDirectory , in: .userDomainMask).first!
        let tempDirectory = URL.init(string: NSTemporaryDirectory())
        let rootDirectories:[URL]=[documentsDirectory,cashesDirectory,tempDirectory!]
        for tmpurl:URL in rootDirectories {
            directoriesList+=getSubdirectories(aturl: tmpurl)
        }
      
        tbl_folders.reloadData()
        

    
    }
    
    
    
    
   //Get all subdirectories of the root folder
    func getSubdirectories(aturl:URL)->[(URL,String)]{
        var results:[(URL,String)]=[]
        results.append((aturl,aturl.lastPathComponent))
        let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        do {
            
            let enumerator = FileManager.default.enumerator(at: aturl,
                                                            includingPropertiesForKeys: resourceKeys,
                                                            options: [.skipsHiddenFiles,], errorHandler: { (url, error) -> Bool in
                                                                print("directoryEnumerator error at \(url): ", error)
                                                                return true
            })!
            
            let rootpathcount:[String]=aturl.pathComponents;
            for case let fileURL as URL in enumerator {
                
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if (resourceValues.isDirectory!){
                    
                    let tmppathcount:[String]=fileURL.pathComponents;
                    let header=String(repeating: "   ", count: (tmppathcount.count-rootpathcount.count))
                    results.append((fileURL,header+fileURL.lastPathComponent))
                    print(header+fileURL.lastPathComponent)
                }
                
            }
        } catch {
            print(error)
        }
       
        return results
    }
    
    //MARK: TableView delegate -
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return directoriesList.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tblcell:CellFolder=tableView.dequeueReusableCell(withIdentifier: "cell_folder", for: indexPath) as! CellFolder
         tblcell.labelFolderName.text=directoriesList[indexPath.row].1
        tblcell.swithStart.isOn=isMonitoringNow(forUrl: directoriesList[indexPath.row].0)
         tblcell.delegated=self
        return tblcell
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        showActiveNotification(title: "Full Path!", text: directoriesList[indexPath.row].0.path)
    }
    
    
    func isMonitoringNow(forUrl:URL)->Bool{
        var result = false
        if (directoryWatcher != nil){
            if (directoryWatcher?.watchedPath.path==forUrl.path){
                result=(directoryWatcher?.isObserving)!
            }
        }
        return result
    }
    
    //MARK: Folder cell start button delegate -
    
    func on_startPressed(_ sender: Any) {
        let hc:CellFolder=sender as! CellFolder
        let position=(tbl_folders.indexPath(for: hc)?.row)!
        let dirUrl=directoriesList[position]
        startMonitoring(foUrl: dirUrl.0,start: hc.swithStart.isOn)
        tbl_folders.reloadData()
    }
    
    
    func startMonitoring(foUrl:URL,start:Bool){
        if (directoryWatcher != nil){
            do {
                try directoryWatcher?.stopObserving()
            }
            catch  {
                print(error)
            }
        }
        if (start){
            directoryWatcher = DirectoryMonitor.init(pathToWatch: foUrl as NSURL, callback: {(notification:DirectoryMonitor.ChangeNotification) in
                self.pushNotification(notification)
                print("Directory contents have changed",notification)
            })
        
            do {
                try directoryWatcher?.startObserving()
            
            }
            catch  {
                print(error)
            }
        
                }

        
        
    }
    func showActiveNotification(title:String,text:String){
        let fullPathAlert:UIAlertController=UIAlertController.init(title: title, message: text, preferredStyle: .actionSheet)
        
        self.present(fullPathAlert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now()+3.0, execute: {
                fullPathAlert.dismiss(animated: true, completion: {
                    
                })
            })
        }

    }
    
    func pushNotification(_ forNotification:DirectoryMonitor.ChangeNotification){
        let notification = UILocalNotification()
        notification.fireDate = Date(timeIntervalSinceNow: 0.1)
        notification.alertBody = forNotification.changeObject+" "+forNotification.changeType.rawValue
        notification.alertAction = "Monitoring!"
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.shared.scheduleLocalNotification(notification)
    }
    
}




