//
//  MOJiAIAnswerWordCell.swift
//  MOJiDict
//
//  Created by Ji Xiang on 2023/5/31.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

class MOJiAIAnswerWordCell: MOJiTableViewCell {
    
    @IBOutlet weak var maskV: UIView!
    @IBOutlet weak var contentV: UIView!
    @IBOutlet weak var titleL: UILabel!
    @IBOutlet weak var subtitleL: UILabel!
    @IBOutlet weak var vipImgV: UIImageView!
    @IBOutlet weak var arrowImgV: UIImageView!
    
    @IBOutlet weak var favBgV: UIView!
    @IBOutlet weak var favBtn: MDButton!
    @IBOutlet weak var favImgV: UIImageView!
    @IBOutlet weak var noteBgV: UIView!
    @IBOutlet weak var noteBtn: MDButton!
    @IBOutlet weak var noteImgV: UIImageView!
    @IBOutlet weak var playBgV: UIView!
    @IBOutlet weak var playBtn: MDButton!
    @IBOutlet weak var playImgV: UIImageView!
    @IBOutlet weak var exampleBtn: MDButton!
    @IBOutlet weak var verbBtn: MDButton!
    @IBOutlet weak var AIBtn: MDButton!
    
    @IBOutlet weak var cons_titleRightToSuper: NSLayoutConstraint!
    @IBOutlet weak var cons_titleRightToImg: NSLayoutConstraint!
    @IBOutlet weak var cons_AILeftToExampleBtn: NSLayoutConstraint!
    @IBOutlet weak var cons_AILeftToVerbBtn: NSLayoutConstraint!
    
    private var answer: DB_AIAnswer?
    
    public var tapWordBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var longPressBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var favBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var noteBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var playBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var exampleBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var verbBlcok: MOJiValueHandle<DB_AIAnswer>?
    public var AIBlcok: MOJiValueHandle<DB_AIAnswer>?
    
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
        subtitleL.setTheme_textColor(MOJiTextColor)
        
        favBtn.highlightColor     = UIColor(hexString: "#ECECEC")
        noteBtn.highlightColor    = UIColor(hexString: "#ECECEC")
        playBtn.highlightColor    = UIColor(hexString: "#ECECEC")
        exampleBtn.highlightColor = UIColor(hexString: "#418EF4").withAlphaComponent(0.5)
        verbBtn.highlightColor    = UIColor(hexString: "#418EF4").withAlphaComponent(0.5)
        AIBtn.highlightColor      = UIColor(hexString: "#418EF4").withAlphaComponent(0.5)
        
        favBtn.layer.cornerRadius     = 22
        noteBtn.layer.cornerRadius    = 22
        playBtn.layer.cornerRadius    = 22
        favBgV.layer.cornerRadius     = 15
        noteBgV.layer.cornerRadius    = 15
        playBgV.layer.cornerRadius    = 15
        exampleBtn.layer.cornerRadius = 14
        verbBtn.layer.cornerRadius    = 14
        AIBtn.layer.cornerRadius      = 14
        
        exampleBtn.setTitle("例句".localized(), for: .normal)
        verbBtn.setTitle("动词活用".localized(), for: .normal)
        AIBtn.setTitle("AI回答".localized(), for: .normal)
        
        favBtn.addTarget(self, action: #selector(favAction), for: .touchUpInside)
        noteBtn.addTarget(self, action: #selector(noteAction), for: .touchUpInside)
        playBtn.addTarget(self, action: #selector(playAction), for: .touchUpInside)
        exampleBtn.addTarget(self, action: #selector(exampleAction), for: .touchUpInside)
        verbBtn.addTarget(self, action: #selector(verbAction), for: .touchUpInside)
        AIBtn.addTarget(self, action: #selector(AIAction), for: .touchUpInside)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapWordAction))
        contentV.addGestureRecognizer(tap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        contentV.addGestureRecognizer(longPress)
    }
    
    func updateCell(tmpAnswer: DB_AIAnswer) {
        self.answer = tmpAnswer
        
        titleL.text    = tmpAnswer.title
        subtitleL.text = tmpAnswer.excerpt
        
        cons_titleRightToSuper.priority = tmpAnswer.isFree.boolValue ? .defaultHigh : .defaultLow
        cons_titleRightToImg.priority   = tmpAnswer.isFree.boolValue ? .defaultLow : .defaultHigh
        vipImgV.isHidden                = tmpAnswer.isFree.boolValue
        
        cons_AILeftToExampleBtn.priority = tmpAnswer.hasVerb.boolValue ? .defaultLow : .defaultHigh
        cons_AILeftToVerbBtn.priority    = tmpAnswer.hasVerb.boolValue ? .defaultHigh : .defaultLow
        verbBtn.isHidden                 = !tmpAnswer.hasVerb.boolValue
        
        let isFaved   = MDFavHelper.getTargetFavStatus(withTargetId: tmpAnswer.targetId, targetType: TargetType(rawValue: tmpAnswer.targetType) ?? .unknown)
        let imgName   = isFaved ? "ai_common_collected" : "ai_common_collect"
        favImgV.image = UIImage.init(named: imgName)
    }
    
    @objc func tapWordAction() {
        guard let tmpAnswer = self.answer else { return }
        
        tapWordBlcok?(tmpAnswer)
    }
    
    @objc func longPressAction(press: UILongPressGestureRecognizer) {
        guard let tmpAnswer = self.answer else { return }
        
        if press.state == .began {
            longPressBlcok?(tmpAnswer)
        }
    }
    
    @objc func favAction() {
        guard let tmpAnswer = self.answer else { return }
        
        favBlcok?(tmpAnswer)
    }
    
    @objc func noteAction() {
        guard let tmpAnswer = self.answer else { return }
        
        noteBlcok?(tmpAnswer)
    }
    
    @objc func playAction() {
        guard let tmpAnswer = self.answer else { return }
        
        playBlcok?(tmpAnswer)
    }
    
    @objc func exampleAction() {
        guard let tmpAnswer = self.answer else { return }
        
        exampleBlcok?(tmpAnswer)
    }
    
    @objc func verbAction() {
        guard let tmpAnswer = self.answer else { return }
        
        verbBlcok?(tmpAnswer)
    }
    
    @objc func AIAction() {
        guard let tmpAnswer = self.answer else { return }
        
        AIBlcok?(tmpAnswer)
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
