//
//  FileTableViewCell.swift
//  Simple Download Manager
//
//  Created by Tom Metzger on 12/28/16.
//  Copyright © 2016 Tom Metzger. All rights reserved.
//
// Reference: https://southernerd.us/blog/tutorial/2017/04/15/Download-Manager-Tutorial.html#downloadingFromURL

import UIKit



class FileTableViewCell: UITableViewCell
{
	@IBOutlet weak var fileNameLabel: UILabel!

	
    override func awakeFromNib()
	{
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool)
	{
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
}
