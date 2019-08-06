//
//  FileBrowserTableViewController.swift
//  Simple Download Manager
//
//  Created by Tom Metzger on 12/27/16.
//  Copyright © 2016 Tom Metzger. All rights reserved.
//
// Reference: https://southernerd.us/blog/tutorial/2017/04/15/Download-Manager-Tutorial.html#downloadingFromURL

import UIKit



class FileBrowserTableViewController: UITableViewController
{
	var documentsDirectoryFiles : NSMutableArray = []
	let reuseIdentifier : String = "Cell"
	
	
    override func viewDidLoad()
	{
        super.viewDidLoad()
		
		self.navigationItem.title = "下載管理員"
		
		let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		
		do
		{
			documentsDirectoryFiles = try NSMutableArray.init(array: FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: []))
		}
		catch let error as NSError
		{
			print(error.localizedDescription)
		}
	}
	
	
	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		
		self.tableView.reloadData()
	}

	
    override func didReceiveMemoryWarning()
	{
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
	{
        return 1
    }
	

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
        return documentsDirectoryFiles.count
    }

	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let cell : FileTableViewCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! FileTableViewCell
		let file : NSURL = documentsDirectoryFiles[indexPath.row] as! NSURL
		var fileName : NSString = NSString(string: file.absoluteString!)
		fileName = fileName.lastPathComponent as NSString
		fileName = fileName.replacingOccurrences(of: "%20", with: " ") as NSString
		cell.fileNameLabel.text = fileName as String
		
		return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
