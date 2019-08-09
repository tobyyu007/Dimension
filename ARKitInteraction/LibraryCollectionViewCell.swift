//
//  LibraryCollectionViewCell.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/8/8.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

class LibraryCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var modelThumbnail: UIImageView!
    @IBOutlet weak var modelTitle: UILabel!
    
    @IBOutlet weak var deleteButtonBackground: UIVisualEffectView!
    
    @IBAction func deleteButtonTap(_ sender: Any)
    {
        print("deleted")
    }
}
