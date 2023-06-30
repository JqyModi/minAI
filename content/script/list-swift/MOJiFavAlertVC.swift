//
//  MOJiFavAlertVC.swift
//  MOJiDict
//
//  Created by 徐志勇 on 2022/11/1.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

enum MOJiFavAlertVcSection: Int {
    case operation
    case filter
    case sort
    case setting
}

@objc class MOJiFavAlertVC: UIViewController {
    @objc var filterType: MOJiFavCategorySelectorItemType = .all
    @objc var operationHandler: MOJiValueHandle<MOJiFavAlertVcOperationType>?
    
    private let operationCellId = NSStringFromClass(MOJiFavAlertOperationCell.self)
    private let filterCellId = NSStringFromClass(MOJiFavAlertFilterCell.self)
    private let sheetCellId = NSStringFromClass(MDActionSheetCell.self)
    private let sheetDetailCellId = NSStringFromClass(MDActionSheetDetailCell.self)
    private let sectionHeaderId = NSStringFromClass(MOJiFavAlertHeaderView.self)
    
    private var titles: [String] = [
        "操作".localized(),
        "筛选".localized(),
        "排序".localized(),
        "设置".localized(),
    ]
    @objc  var sortActions: [MOJiActionSheetAction]?
    @objc  var settingActions: [MOJiActionSheetAction]?
    
    private var contentV: UIView!
    var tableV: UITableView!
    var closeBtn: MDButton = {
        let v = MDButton()
        v.setImage(UIImage(named: "ic_member_close"), for: .normal)
        return v
    }()
    
    
    @objc func reloadData() {
        tableV.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func setupView() {
        contentV = UIView()
        contentV.layer.cornerRadius = 16
        contentV.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentV.setTheme_backgroundColor(MOJiTheme.FavAlertVcBgColor)
        view.addSubview(contentV)

        contentV.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
        }
        
        contentV.addSubview(closeBtn)
        closeBtn.snp.makeConstraints { make in
            make.right.equalTo(contentV.safeAreaLayoutGuide.snp.right).offset(-16)
            make.top.equalTo(16)
            make.width.height.equalTo(28)
        }
        
        tableV = UITableView(frame: .zero, style: .grouped)
        tableV.showsVerticalScrollIndicator = false
        tableV.setTheme_backgroundColor(MOJiTheme.FavAlertVcBgColor)
        tableV.delegate = self
        tableV.dataSource = self
        tableV.sectionFooterHeight = 0
        tableV.separatorStyle = .none
        tableV.register(MOJiFavAlertOperationCell.self, forCellReuseIdentifier: operationCellId)
        tableV.register(UINib.init(nibName: sheetCellId, bundle: nil), forCellReuseIdentifier: sheetCellId)
        tableV.register(UINib.init(nibName: sheetDetailCellId, bundle: nil), forCellReuseIdentifier: sheetDetailCellId)
        tableV.register(MOJiFavAlertHeaderView.self, forHeaderFooterViewReuseIdentifier: sectionHeaderId)
        contentV.addSubview(tableV)
        tableV.snp.makeConstraints { make in
            make.left.equalTo(contentV.safeAreaLayoutGuide.snp.left).offset(16)
            make.right.equalTo(contentV.safeAreaLayoutGuide.snp.right).offset(-16)
            make.bottom.equalToSuperview()
            make.top.equalTo(56)
        }
        
        closeBtn.addTarget(self, action: #selector(actionClose), for: .touchUpInside)
    }
    
    @objc func actionClose() {
        hide(completion: nil)
    }
    
    func hide(completion: MOJiEmptyHandle?) {
        self.dismiss(animated: true) {
            completion?()
        }
    }
    
    @objc func presentVc() {
        let nav = MDBaseNavigationController(rootViewController: self)
        if #available(iOS 15.0, *) { // 半屏 -> 全屏
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
        }
        MDUIUtils.visibleViewController().present(nav, animated: true)
    }
    
}

extension MOJiFavAlertVC: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == MOJiFavAlertVcSection.operation.rawValue {
            return 1
        }
        if section == MOJiFavAlertVcSection.filter.rawValue {
            return 1
        }
        if section == MOJiFavAlertVcSection.sort.rawValue {
            return sortActions?.count ?? 0
        }
        if section == MOJiFavAlertVcSection.setting.rawValue {
            return settingActions?.count ?? 0
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        if section == MOJiFavAlertVcSection.operation.rawValue {
            return 66
        }
        if section == MOJiFavAlertVcSection.filter.rawValue {
            return 44
        }
        if section == MOJiFavAlertVcSection.sort.rawValue ||
            section == MOJiFavAlertVcSection.setting.rawValue {
            return 56
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row
        
        if section == MOJiFavAlertVcSection.operation.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: operationCellId) as! MOJiFavAlertOperationCell
            cell.delegate = self
            return cell
        }
        if section == MOJiFavAlertVcSection.filter.rawValue {
            var cell = tableView.dequeueReusableCell(withIdentifier: filterCellId)
            if cell == nil {
                cell = MOJiFavAlertFilterCell(style: .default, reuseIdentifier: filterCellId)
                if let cell = cell as? MOJiFavAlertFilterCell {
                    cell.setSelectType(type: filterType)
                    cell.delegate = self
                }
            }
            return cell!
        }
        if section == MOJiFavAlertVcSection.sort.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: sheetCellId) as! MDActionSheetCell
            cell.setTheme_backgroundColor(MOJiOCRLoadingIndicatorViewColor)
            if let sortActions = sortActions {
                cell.action = sortActions[row]
                setCellRadius(cell: cell, row: row, array: sortActions)
                cell.separatorL?.isHidden = row == sortActions.count - 1
            }
            cell.titleL?.setTheme_textColor(MOJiTextColor)
            
            return cell
        }
        if section == MOJiFavAlertVcSection.setting.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: sheetDetailCellId) as! MDActionSheetDetailCell
            cell.setTheme_backgroundColor(MOJiOCRLoadingIndicatorViewColor)
            if let settingActions = settingActions {
                cell.action = settingActions[row]
                cell.action.delegate = self
                setCellRadius(cell: cell, row: row, array: settingActions)
                cell.separatorL?.isHidden = row == settingActions.count - 1
            }
            cell.delegate = self
            return cell
        }
        return UITableViewCell(style: .default, reuseIdentifier: nil)
    }
    
    func setCellRadius(cell: UITableViewCell, row: Int, array: Array<Any>) {
        cell.clipsToBounds = true
        cell.setTheme_backgroundColor(MOJiOCRLoadingIndicatorViewColor)
        if row == 0 {
            cell.layer.cornerRadius = 16
            cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        }
        else if row == array.count - 1 {
            cell.layer.cornerRadius = 16
            cell.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        else {
            cell.layer.cornerRadius = 0
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return MOJiFavAlertHeaderView.cellHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = tableView.dequeueReusableHeaderFooterView(withIdentifier: sectionHeaderId) as! MOJiFavAlertHeaderView
        v.label.text = titles[section]
        return v
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        let section = indexPath.section
        
        if section == MOJiFavAlertVcSection.sort.rawValue {
            MOJiLogEvent.logEvent(withName: .collectionSort)
            if let arr = sortActions {
                let action = arr[row]
                self.hide {
                    action.handler(action)
                }
            }
        }
        else if section == MOJiFavAlertVcSection.setting.rawValue {
            if let arr = settingActions {
                let action = arr[row]
                if action.style == .detailWithSwitchWithoutArrow { return }
                self.hide {
                    action.handler(action)
                }
            }
        }
    }
}

extension MOJiFavAlertVC: MOJiFavAlertOperationCellDelegate {
    func operationCellDidClickItem(type: MOJiFavAlertVcOperationType) {
        self.hide { [weak self] in
            self?.operationHandler?(type)
        }
    }
}

extension MOJiFavAlertVC: MOJiFavAlertFilterCellDelegate {
    func favAlertFilterCellDidClickItem(title: String, type: Int) {
        MOJiLogEvent.logEvent(withName: .collection_screen)
        self.hide {
            let menu = MOJiMenuListItem()
            menu.title = title
            menu.targetType = type
            NotificationCenter.default.post(name: NSNotification.Name.MOJiFavFilterDidSelected, object: menu)
        }
    }
}

extension MOJiFavAlertVC: MDActionSheetDetailCellDelegate {
    func md_actionSheetDetailCell(_ cell: MDActionSheetDetailCell, didSwitchOn on: Bool) {
        cell.action.on = on
        cell.action.didSwitch(cell.action, nil)
    }
}

extension MOJiFavAlertVC: MOJiActionSheetActionDelegate {
    func actionSheetActionNeedUpdateCellInfo() {
        self.tableV.reloadData()
    }
}
