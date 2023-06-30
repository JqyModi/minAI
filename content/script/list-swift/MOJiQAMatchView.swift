//
//  MOJiQAMatchView.swift
//  MOJiDict
//
//  Created by lyb on 2023/3/6.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

private let TitleLTop      = 12.0
private let TableVMaxWidth = 202.0

private let NumLTop        = 6.0
private let NumLHeight     = 15.0

private let BottomLineTop    = 12.0
private let BottomLineHeight = 1.0

// MARK: -
// MARK: - MDQAMatchCell

class MDQAMatchCell: MOJiTableViewCell {
    private lazy var titleLabel: UILabel! = {
        let label                 = UILabel()
        label.numberOfLines       = 2
        label.mt.dynamicTextColor = MOJiDynamicColors.searchQAText
        label.theme_setFont(name: MOJiThemeFont, weight: .regular, size: 16)
        return label
    }()
    
    private lazy var numLabel: UILabel! = {
        let label       = UILabel()
        label.textColor = UIColor(hexString: "#ACACAC")
        label.theme_setFont(name: MOJiThemeFont, weight: .regular, size: 12)
        return label
    }()
    
    private lazy var bottomLine: UIView! = {
        let v = UIView()
        v.mt.dynamicBgColor = MOJiDynamicColors.commentWordListLine
        return v
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        configViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configViews() {
        backgroundColor = .clear
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(numLabel)
        contentView.addSubview(bottomLine)
        
        titleLabel.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(TitleLTop)
        }
        
        numLabel.snp.remakeConstraints { make in
            make.left.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(NumLTop)
            make.height.equalTo(NumLHeight)
        }
        
        bottomLine.snp.remakeConstraints { make in
            make.height.equalTo(BottomLineHeight)
            make.top.equalTo(numLabel.snp.bottom).offset(BottomLineTop)
            make.left.right.equalTo(titleLabel)
            make.bottom.equalToSuperview()
        }
    }
    
    func configData(question: String, model: MDQAMatchModel, row: Int, count: Int) {
        bottomLine.isHidden = row == count - 1
        numLabel.text = String(format: "%d 回答", model.answeredNum).localized()
        
        /// 查出所有匹配的目标字符，并设置颜色
        if model.title.count > 0 {
            titleLabel.attributedText = model.title.setAllTargetStr(target: question, font: nil, color: UIColor.color(hexString: "#FF5252"))
        }
    }
    
}



// MARK: -
// MARK: - MOJiQAMatchView

class MOJiQAMatchView: UIView {
    var searchText: String?

    private var datas: [MDQAMatchModel] = []
    
    private lazy var tableV: MOJiTableView! = {
        let v = MOJiTableView(frame: .zero, style: .grouped)
        
        v.delegate          = self
        v.dataSource        = self
        v.separatorStyle    = .none
        v.tableHeaderView   = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.01))
        v.tableFooterView   = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.01))
        v.mt.dynamicBgColor = MOJiDynamicColors.qaListBg
        v.register(MDQAMatchCell.self, forCellReuseIdentifier: MDQAMatchCell.cellIdentifier)
        // 自动填充Cell高度
        v.estimatedRowHeight = 64
        v.rowHeight = UITableView.automaticDimension
        
        return v
    }()
    
    private lazy var packUpBtn: UIButton! = {
        let btn = UIButton()
        
        btn.mt.dynamicBgColor = MOJiDynamicColors.qaListBg
        btn.setTitle("收起".localized(), for: .normal)
        btn.setTitleColor(UIColor(hexString: "#ACACAC"), for: .normal)
        btn.titleLabel?.theme_setFont(name: MOJiThemeFont, weight: .regular, size: 12)
        btn.addTarget(self, action: #selector(pachUpClick), for: .touchUpInside)
        
        return btn
    }()

    deinit {
        SwiftLog.mojiLog(items: #function, "MOJiQAMatchView release !")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
        configViews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        MDUIUtils.setRoundCornerWith(packUpBtn, rectCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 16, height: 16))
        // 布局改变时重新设置滚动：适配iPad分屏模式
        if !tableV.isScrollEnabled {
            // 重新比较contentSize
        }
    }
    
    private func initialize() {
        isHidden        = true
        backgroundColor = UIColor(white: 0, alpha: 0.2)
    }
    
    private func configViews() {
        addSubview(tableV)
        // 先有make才有remake
        tableV.snp.makeConstraints { make in
            make.height.equalTo(0.01)
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
        }
        
        addSubview(packUpBtn)
    }
    
    private func updateLayout(tableVCurrHeight: Double) {
        
        var height = tableVCurrHeight > TableVMaxWidth ? TableVMaxWidth : tableVCurrHeight
        height += (TitleLTop * 2)
        
        tableV.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
        
        packUpBtn.snp.remakeConstraints { make in
            make.height.equalTo(36)
            make.top.equalTo(tableV.snp.bottom).offset(-2)
            make.left.right.equalToSuperview()
        }
    }
}

// MARK: - HandleData

extension MOJiQAMatchView {
    func updateData(searchText: String) {
        
        self.searchText = searchText
        
        removeDatas()
        
        MOJiLogEvent.logEvent(withName: .qAaskSimilarQuestionList)
        
        MOJiQACloudHelper.getSearchCircle(keyw: searchText) { [self] result, error in
            guard let list = result, list.count > 0 else {
                self.isHidden = true
                tableV.reloadData()
                return
            }
            
            self.isHidden = false
            
            datas.append(contentsOf: list as! [MDQAMatchModel])
            self.layoutIfNeeded()
            
            /// 动态计算tableV高度
            var heightSum = 0.0
            for model in datas {
                // 第一次tableV.width为0，高度计算有误
                let size = MUIPureTools.expectedSize(withText: model.title, font: .pingFangRegular(size: 16), maxWidth: tableV.width - (32 + 2))
                let numHeight = NumLTop + NumLHeight + BottomLineTop + BottomLineHeight
                heightSum += size.height + numHeight
            }
            
            updateLayout(tableVCurrHeight: ceil(heightSum))
            
            tableV.reloadData()
        }
    }
    
    private func removeDatas() {
        if datas.count > 0 {
            datas.removeAll()
        }
    }
    
    func clearMemoryCache() {
        removeDatas()
        tableV.reloadData()
        isHidden = true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MOJiQAMatchView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MDQAMatchCell.cellIdentifier)
                   as? MDQAMatchCell
        
        cell?.configData(question: searchText ?? "",
                            model: datas[indexPath.row],
                              row: indexPath.row,
                            count: datas.count)
        
        return cell ?? UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        MOJiLogEvent.logEvent(withName: .qAaskSimilarQuestion)
        
        MDUIUtils.pushQAQuestionVC(withQuestionId: datas[indexPath.row].targetId)
    }
}

// MARK: - Response

extension MOJiQAMatchView {
    @objc func pachUpClick() {
        isHidden = true
    }
}
