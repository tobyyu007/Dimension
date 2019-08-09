//
//  LibraryCollectionViewCell.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/8/8.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

protocol LibraryCollectionViewCellDelegate: class {
    func delete(cell: LibraryCollectionViewCell)
}

class LibraryCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var modelThumbnail: UIImageView!
    @IBOutlet weak var modelTitle: UILabel!
    
    @IBOutlet weak var deleteButtonBackground: UIVisualEffectView!
    weak var delegate: LibraryCollectionViewCellDelegate?
    
    @IBAction func deleteButtonTap(_ sender: Any)
    {
        delegate?.delete(cell: self)
    }
}
