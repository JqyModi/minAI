//
//  MOJiAIQuestionCell.swift
//  MOJiDict
//
//  Created by Ji Xiang on 2023/5/31.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

class MOJiAIQuestionCell: MOJiTableViewCell {
    
    @IBOutlet weak var maskV: UIView!
    @IBOutlet weak var contentV: UIView!
    @IBOutlet weak var titleL: UILabel!
    
    private var question: DB_AIQuestion?
    @IBOutlet weak var cons_contentVToTop: NSLayoutConstraint!
    @IBOutlet weak var cons_contentVToBottom: NSLayoutConstraint!
    @IBOutlet weak var cons_titleVToTop: NSLayoutConstraint!
    @IBOutlet weak var cons_titleVToBottom: NSLayoutConstraint!
    
    public var longPressBlcok: MOJiValueHandle<DB_AIQuestion>?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        configViews()
    }
    
    func configViews() {
//        self.transform      = CGAffineTransform(scaleX: 1, y: -1)
        self.selectionStyle = .none
        
        contentV.layer.cornerRadius = 12
        titleL.textColor            = UIColor(hexString: "#FAFAFA")
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        contentV.addGestureRecognizer(longPress)
    }
    
    func updateCell(tmpQuestin: DB_AIQuestion) {
        self.question = tmpQuestin
        
        // 问题被删除或者标题为空时
        if tmpQuestin.isTrash.boolValue || MDStringUtils.isEmptyString(tmpQuestin.content) {
            titleL.text                    = ""
            contentV.isHidden              = true
            cons_contentVToTop.constant    = CGFLOAT_MIN
            cons_contentVToBottom.constant = CGFLOAT_MIN
            cons_titleVToTop.constant      = CGFLOAT_MIN
            cons_titleVToBottom.constant   = CGFLOAT_MIN
        } else {
            titleL.text                    = MOJiChineseLocalizedString(tmpQuestin.content)
            contentV.isHidden              = false
            cons_contentVToTop.constant    = 8
            cons_contentVToBottom.constant = 8
            cons_titleVToTop.constant      = 12
            cons_titleVToBottom.constant   = 12
        }
    }
    
    @objc func longPressAction(press: UILongPressGestureRecognizer) {
        if press.state == .began {
            guard let tmpQuestion = self.question else { return }
            
            longPressBlcok?(tmpQuestion)
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
