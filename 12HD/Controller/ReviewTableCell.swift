//
//  ReviewTableCell.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 3/6/21.
//

import UIKit


class ReviewTableCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBOutlet weak var reviewCell: UILabel!
    
    
}
