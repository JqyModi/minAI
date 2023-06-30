//
//  MOJiAIAnswerGPTCell.swift
//  MOJiDict
//
//  Created by Ji Xiang on 2023/5/31.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

private let BottomViewDefaultHeight = 92.0
private let BtnDefaultTag           = 10101

public typealias MOJiAIAnswerGPTCellFunctionBlock = (_ answer: DB_AIAnswer, _ type: MOJiAIAnswerGPTType) -> ()

class MOJiAIAnswerGPTCell: MOJiTableViewCell {
    
    @IBOutlet weak var maskV: UIView!
    @IBOutlet weak var contentV: UIView!
    @IBOutlet weak var titleL: UILabel!
    @IBOutlet weak var bottomV: UIView!
    @IBOutlet weak var lineV: UIView!
    @IBOutlet weak var bottomTitleL: UILabel!
    @IBOutlet weak var typeBtn1: MDButton!
    @IBOutlet weak var typeBtn2: MDButton!
    @IBOutlet weak var typeBtn3: MDButton!
    @IBOutlet weak var typeBtn4: MDButton!
    @IBOutlet weak var typeBtn5: MDButton!
    
    @IBOutlet weak var cons_bottomVHeight: NSLayoutConstraint!
    
    lazy var btns: [MDButton] = {
        return [typeBtn1, typeBtn2, typeBtn3, typeBtn4, typeBtn5]
    }()
    
    private var answer: DB_AIAnswer?
    public var longPressBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var functionBlock: MOJiAIAnswerGPTCellFunctionBlock?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        configViews()
    }
    
    func configViews() {
//        self.transform      = CGAffineTransform(scaleX: 1, y: -1)
        self.selectionStyle = .none
        
        maskV.mt.dynamicBgColor     = MOJiDynamicColors.k_FFFFFF_1C1C1E
        contentV.mt.dynamicBgColor  = MOJiDynamicColors.k_FFFFFF_1C1C1E
        contentV.layer.cornerRadius = 12
        
        titleL.setTheme_textColor(MOJiTextColor)
        bottomTitleL.setTheme_textColor(MOJiTextColor)
        bottomTitleL.text = "回答不够好？试试：".localized()
        
        bottomV.isHidden            = true
        cons_bottomVHeight.constant = CGFLOAT_MIN
        
        lineV.mt.dynamicBgColor = MOJiDynamicColors.k_F8F8F8_3B3B3B
        
        for i in 0..<btns.count {
            let btn                = btns[i]
            btn.highlightColor     = UIColor(hexString: "#ACACAC").withAlphaComponent(0.5)
            btn.layer.cornerRadius = 14
            btn.isHidden           = true
            btn.addTarget(self, action: #selector(typeAction), for: .touchUpInside)
        }
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        contentV.addGestureRecognizer(longPress)
    }
    
    func updateCell(tmpAnswer: DB_AIAnswer) {
        self.answer = tmpAnswer
        
        titleL.text = MOJiChineseLocalizedString(tmpAnswer.answer)
        updateView(answer: tmpAnswer)
    }
    
    func updateView(answer: DB_AIAnswer) {
        guard answer.type == MOJiAIAnswerType.GPT.rawValue else { return }
        
        let intents = answer.tmpIntents()
        
        if intents.count > 0 {
            bottomV.isHidden            = false
            cons_bottomVHeight.constant = BottomViewDefaultHeight
        } else {
            bottomV.isHidden            = true
            cons_bottomVHeight.constant = CGFLOAT_MIN
        }
        
        for i in 0..<intents.count {
            let type     = Int(intents[i] as String) ?? 0
            let btn      = btns[Int(i)]
            btn.isHidden = false
            btn.tag      = BtnDefaultTag + type
            let gptType  = MOJiAIAnswerGPTType(rawValue: UInt(type)) ?? .searchWord
            btn.setTitle(DB_AIAnswer.getGPTFunctionName(with: gptType), for: .normal)
        }
    }
    
    @objc func typeAction(_ btn: MDButton) {
        guard let tmpAnswer = self.answer else { return }
        
        let tag = btn.tag - BtnDefaultTag
        
        print("当前选中的类型: " + "\(String(tag))")
        
        functionBlock?(tmpAnswer, MOJiAIAnswerGPTType(rawValue: UInt(tag)) ?? MOJiAIAnswerGPTType.searchWord)
    }
    
    @objc func longPressAction(press: UILongPressGestureRecognizer) {
        guard let tmpAnswer = self.answer else { return }
        
        if press.state == .began {
            longPressBlcok?(tmpAnswer)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
