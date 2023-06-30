//
//  MOJiHomeVC.swift
//  MOJiDict
//
//  Created by 徐志勇 on 2022/10/25.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

private let avatarWidth: CGFloat = 24
private let categoryOneWidth: CGFloat = 56

class MOJiHomeVC: MOJiHomeBaseVC {
    
    @objc lazy var translateVc: MOJiTranslationHomeVc = {
        let vc = MOJiTranslationHomeVc()
        return vc
    }()
    
    @objc lazy var searchVc: MOJiSearchVC = {
        let vc = MOJiSearchVC()
        return vc
    }()
    
    @objc lazy var favVc: MOJiFavVC = {
        let favVc = MOJiFavVC(nibName: NSStringFromClass(MOJiFavVC.self), bundle: nil)
        favVc.parentV = self.view
        favVc.homeVc = self
        favVc.favLoginFinishedBlock = {
            self.readSyncAction()
        }
        return favVc
    }()
    
    @objc lazy var AIVC: MOJiAIVC = {
        let vc = MOJiAIVC.viewController()
        return vc
    }()
    
    lazy var avatarImgV: MOJiAvatarImageView = {
        let v = MOJiAvatarImageView()
        v.layer.cornerRadius = 6
        v.clipsToBounds = true
        return v
    }()
    
    var navView: UIView = {
        let v = UIView()
        return v
    }()
    
    lazy var maintenanceBtn: MOJiMaintenanceBtn = {
        let btn = MOJiMaintenanceBtn.init()
        btn.addTarget(self, action: #selector(maintenanceBtnEvent), for: .touchUpInside)
        btn.isHidden = true
        
        return btn
    }()
    
    var meButton: MDButton = {
        let btn = MDButton()
        btn.highlightColor = .clear
        return btn
    }()
    
    @objc var notSelectedSearchVc: Bool {
        categoryView.selectedIndex != Int(MDMainVCChildVCType.search.rawValue)
    }
    
    @objc var isSelectedTranslation: Bool {
        categoryView.selectedIndex == Int(MDMainVCChildVCType.translation.rawValue)
    }
    
//    @objc public var listVCs: [JXCategoryListContentViewDelegate] = [JXCategoryListContentViewDelegate]()
    @objc public var listVCs: [UIViewController] = [UIViewController]()
    
    static func categoryTitles() -> [String] {
        var titles = ["翻译".localized(), "搜索".localized(), "收藏".localized()]
        
        if MDConfigHelper.shared().mojiConfig.aiChatItem().isOpen {
            let AITitle = Self.getAITabTitle()
            titles.append(AITitle)
        }
        
        return titles
    }
    
    var categoryView: JXCategoryTitleView = {
        let v = JXCategoryTitleView()
        v.titleColor = UIColor(hexString: "#ACACAC")
        v.titleSelectedColor = MOJiThemeManager.color(name: MOJiTextColor)
        v.cellSpacing = 0
        v.isAverageCellSpacingEnabled = true
        v.isCellWidthZoomEnabled = false
        v.titleLabelVerticalOffset = 8.0
        v.cellWidth = categoryOneWidth
        v.titles = MOJiHomeVC.categoryTitles()
        v.refreshDataSource()
        v.titleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        v.titleSelectedFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        v.isTitleLabelZoomEnabled = false
        v.titleLabelAnchorPointStyle = .bottom
        return v
    }()
    
    private var listContainerView: JXCategoryListContainerView!
    /// 记录阅读导入收藏夹携带的导出记录ID：由阅读APP生成导出记录
    var readingAddRecordId: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addObserver()
        setupView()
        // 拉取一次回答领会员记录
        MOJiQACloudHelper.loadUserAnswerPro()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMeAvatarImage()
        updateSystemPromptUI()
    }
    
    private func addObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.MOJiJump2FavTab, object: nil, queue: nil) { notify in
            guard let recordId = notify.userInfo?[MOJiKey.recordKey.rawValue] as? String else {
                return
            }
            
            // 切换到收藏Tab
            self.change(to: Int(MDMainVCChildVCType.fav.rawValue))
            self.readingAddRecordId = recordId
            self.readSyncAction()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateConfig), name: .MOJiConfigDidUpdateSuccess, object: nil)
    }
    
    private func readSyncAction() {
        // 登录检查
        if !MDUserHelper.isLogin() {
            self.favVc.isSyncFav = true
            return
        }
        
        // 会员检查
        if !MDUserHelper.didPurchaseMOJiProducts() {
            return
        }
        
        let item = ItemInFolder()
        item.targetId = self.readingAddRecordId
        item.targetType = NSNumber(value: TargetType.unknown.rawValue)
        // 跳转到选择文件夹组件
        MDUIUtils.presentFolderPicker(toFavItem: item, delegate: self)
    }
    
    func setupView() {
        view.mt.dynamicBgColor = MOJiDynamicColors.HomeVcBg
        
        translateVc.homeVc           = self
        translateVc.resultShowOnView = self.view
        searchVc.homeVc              = self
        searchVc.resultShowOnView    = self.view
        
        view.addSubview(navView)
        navView.snp.makeConstraints { make in
            make.left.equalTo(view.safeAreaLayoutGuide.snp.left)
            make.right.equalTo(0)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(0)
        }
        
        let categoryWidth = CGFloat(MOJiHomeVC.categoryTitles().count) * categoryOneWidth
        categoryView.delegate = self
        navView.addSubview(categoryView)
        categoryView.snp.makeConstraints { make in
            make.bottom.top.equalTo(0)
            make.centerX.equalToSuperview()
            make.width.equalTo(categoryWidth)
            make.height.equalTo(52)
        }
        
        view.addSubview(maintenanceBtn)
        
        listVCs.append(translateVc)
        listVCs.append(searchVc)
        listVCs.append(favVc)
        
        #warning("TODO 看后台如何返回该字段")
        if MDConfigHelper.shared().mojiConfig.aiChatItem().isOpen {
            AIVC.homeVc           = self
            AIVC.resultShowOnView = self.view
            listVCs.append(AIVC)
        }
        
        listContainerView = JXCategoryListContainerView(type: .scrollView, delegate: self)
        view.addSubview(listContainerView)
        listContainerView.snp.makeConstraints { make in
            make.top.equalTo(categoryView.snp.bottom)
            make.left.bottom.right.equalToSuperview()
        }
        
        categoryView.listContainer = listContainerView
        
        meButton.addTarget(self, action: #selector(actionMe), for: .touchUpInside)
        navView.addSubview(meButton)
        meButton.snp.makeConstraints { make in
            make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(10)
            make.width.equalTo(44)
            make.height.equalTo(52)
            make.centerY.equalTo(categoryView).offset(0)
        }
        
        meButton.addSubview(avatarImgV)
        avatarImgV.snp.makeConstraints { make in
            make.width.height.equalTo(avatarWidth)
            make.centerX.equalTo(meButton)
            make.centerY.equalTo(meButton).offset(8)
        }
        
        // line
        let lineV = UIView()
        lineV.mt.dynamicBgColor = MOJiDynamicColors.homeNavBarLineBg
        navView.addSubview(lineV)
        lineV.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(1/UIScreen.main.scale)
        }
        
        self.categoryView.selectItem(at: Int(MDMainVCChildVCType.search.rawValue))
        
        updateSystemPrompt()
    }
    
    @objc func updateConfig() {
        let AITitle = Self.getAITabTitle()
        
        if !MDConfigHelper.shared().mojiConfig.aiChatItem().isOpen {
            
            if categoryView.titles.contains(AITitle) {
                categoryView.titles = ["翻译".localized(), "搜索".localized(), "收藏".localized()]
                
                if let index = listVCs.firstIndex(of: AIVC) {
                    listVCs.remove(at: index)
                }
            }
            
            // 更新一下源数据
            categoryView.reloadData()
            
            return
        }
        
        // 已经加载过就不需要往下走了
        if categoryView.titles.contains(AITitle) {
            return
        }
        
        let titles          = ["翻译".localized(), "搜索".localized(), "收藏".localized(), AITitle]
        categoryView.titles = titles
        
        let categoryWidth = CGFloat(titles.count) * categoryOneWidth
        categoryView.snp.remakeConstraints({ make in
            make.bottom.top.equalTo(0)
            make.centerX.equalToSuperview()
            make.width.equalTo(categoryWidth)
            make.height.equalTo(52)
        })
        
        AIVC.homeVc           = self
        AIVC.resultShowOnView = self.view
        listVCs.append(AIVC)
        
        // 更新一下源数据
        categoryView.reloadData()
    }
    
    static func getAITabTitle() -> String {
        var title = "AI"
        
        if MOJiLocalizedStringManager.shared.preferredLanguage == MOJiLocalizedStringLanguage.zhHans {
            title = MDConfigHelper.shared().mojiConfig.aiChatItem().tab_name_zh_cn
        } else if MOJiLocalizedStringManager.shared.preferredLanguage == MOJiLocalizedStringLanguage.zhHant {
            title = MDConfigHelper.shared().mojiConfig.aiChatItem().tab_name_zh_hant
        }
//        else if MOJiLocalizedStringManager.shared.preferredLanguage == MOJiLocalizedStringLanguage.en {
//            title = MDConfigHelper.shared().mojiConfig.aiChatItem().tab_name_en
//        }
        
        return title
    }
    
    override func requestToInboxRead() {
        super.requestToInboxRead()
        self.updateSystemPromptUI()
    }
    
    @objc func updateSystemPromptUI() {
        if MDCommonHelper.isSystemMaintenanceStatecaching() {
            // 没有缓存
            updateSystemPrompt()
        } else {
            // 有缓存
            // 加载缓存
            let data: Data = MOJiDefaultsManager.getSystemPromptData()
            updateSystemPromptData(data)
            
            // 一分钟只能请求一次
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateSystemPrompt), object: nil)
            self.perform(#selector(updateSystemPrompt), with: nil, afterDelay: 30.0)
        }
    }
    
    @objc func updateSystemPrompt() {
        MDCommonHelper.getSystemMaintenanceStateCompletion { [weak self] result in
            guard let self = self else { return }
            
            self.updateSystemPromptData(result)
        }
    }
    
    @objc func updateSystemPromptData(_ data: Data) {
        MDCommonHelper.getSystemMaintenanceState(with: data, completion: { [weak self] result in
            guard let self = self else { return }
            
            if !self.maintenanceBtn.isDescendant(of: self.view) { return }
            if !self.listContainerView.isDescendant(of: self.view) { return }

            if result {
                // 显示系统维护提示
                self.maintenanceBtn.snp.remakeConstraints { make in
                    make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left)
                    make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
                    make.top.equalTo(self.navView.snp.bottom).offset(0)
                    make.height.equalTo(32)
                }
                
                self.listContainerView.snp.remakeConstraints { make in
                    make.top.equalTo(self.maintenanceBtn.snp.bottom)
                    make.left.bottom.right.equalToSuperview()
                }
            } else {
                self.listContainerView.snp.remakeConstraints { make in
                    make.top.equalTo(self.categoryView.snp.bottom)
                    make.left.bottom.right.equalToSuperview()
                }
            }
            
            self.maintenanceBtn.isHidden = !result
        })
    }
    
    @objc func maintenanceBtnEvent() {
        let vc = MOJiMaintenanceMessageVC()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func actionMe() {
        MOJiLogEvent.logEvent(withName: .tabMy)
        let vc = MOJiMeVC(nibName: NSStringFromClass(MOJiMeVC.self), bundle: nil)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    /// 更新avatar
    func updateMeAvatarImage() {
        if MDUserHelper.isLogin() {
            guard let uid = MOJiUser.current()?.objectId else {
                return
            }
            let objectId = MOJiDefaultsManager.getAvatarImageRecordObjectId()
            if objectId.isEmpty {
                avatarImgV.setImageWithUserId(uid)
                return
            }
            MDUserHelper.uploadAvartarRecordCompletion { recordCode, allowed in
                self.avatarImgV.setImageWithUserId(uid)
            }
        }
        else {
            avatarImgV.image = UIImage(named: "img_head_portrait")
        }
    }
    
    @objc func enableScroll(enable: Bool) {
        listContainerView.scrollView.isScrollEnabled = enable
    }
    
    override func themeStyleDidChange(_ notification: Notification) {
        super.themeStyleDidChange(notification)
        self.categoryView.titleSelectedColor = MOJiThemeManager.color(name: MOJiTextColor)
        self.categoryView.reloadData()
    }
    
    @objc func showOrHideNavView(show: Bool) {
        self.navView.isHidden = !show
    }
    
    func hideKeyboard() {
        self.searchVc.hideKeyboard()
    }
}

extension MOJiHomeVC: JXCategoryListContainerViewDelegate, JXCategoryViewDelegate {
    
    func number(ofListsInlistContainerView listContainerView: JXCategoryListContainerView!) -> Int {
        return listVCs.count
    }
    
    func listContainerView(_ listContainerView: JXCategoryListContainerView!, initListFor index: Int) -> JXCategoryListContentViewDelegate! {
        return listVCs[index] as? JXCategoryListContentViewDelegate
    }
    
    func categoryView(_ categoryView: JXCategoryBaseView!, didSelectedItemAt index: Int) {
        willSelectTab(at: index, feedbackEnabled: false)
        
        showOrHideSearchBar()
        self.searchVc.searchBar.isTranslateSelected = self.isSelectedTranslation
        
        let oldSelected = self.searchVc.searchBar.isAISelected
        let curSelected = index == MDMainVCChildVCType.AI.rawValue
        
        if oldSelected != curSelected { // 只有从非AI切换到AI tab时才会触发
            self.searchVc.searchBar.homeVcSelectedAITab(curSelected)
        }
        
        if (self.isSelectedTranslation) {
            MOJiLogEvent.logEvent(withName: .search_translateByHome)
        }
    }
    
    func showOrHideSearchBar() {
        if (self.categoryView.selectedIndex != MDMainVCChildVCType.fav.rawValue) {
            self.searchVc.showSearchbarWhenAppear()
        } else {
            self.searchVc.hideSearchbarWhenDisappear()
        }
    }
}

/// 处理main vc 事件
extension MOJiHomeVC {

    @objc func change(to index: Int) {
        if self.moji_selectedIndex == index { return }
        categoryView.selectItem(at: index)
    }
    
    @objc func changeToSearch() {
        self.searchVc.changeToSearch()
    }
    
    @objc func changeToTranslate(text: String?) {
        self.searchVc.changeToTranslate(withText: text)
    }
    
    override func signUp(toDo notification: Notification) {
        super.signUp(toDo: notification)
        updateMeAvatarImage()
    }
    
    override func login(toDo notification: Notification) {
        super.login(toDo: notification)
        updateMeAvatarImage()
        // 更新一次答题领会员记录
        MOJiQACloudHelper.loadUserAnswerPro()
    }
    
    override func logoutToDo() {
        super.logoutToDo()
        updateMeAvatarImage()
    }
    
}

extension MOJiHomeVC: MOJiFolderPickerDelegate {
    func moji_folderPicker(_ folderPicker: MOJiFolderPicker, didSelectFolderWithFolderId folderId: String) {
        if (folderPicker.config.targetId == self.readingAddRecordId) {
            self.showProgressHUD()
            MDFavHelper.exportFolder(self.readingAddRecordId, toFolderId: folderId) { response, error in
                self.hideProgressHUD()
                if (response.isOK()) {
                    MDUIUtils.showToast(NSLocalizedString("导入成功", comment: ""))
                    // 刷新数据
                    self.favVc.getFolderContent()
                } else if (response.code.rawValue == MCErrorCode.errorCodeObjectNotFound.rawValue) {
                    MDUIUtils.showToast(NSLocalizedString("记录已处理或不存在", comment: ""))
                } else if (response.code.rawValue == MCErrorCode.errorCodeProcessing.rawValue) {
                    MDUIUtils.showToast(NSLocalizedString("处理中，请勿频繁操作", comment: ""))
                } else {
                    MDUIUtils.showToast(NSLocalizedString("导入失败，遇到未知错误", comment: ""))
                }
            }
        }
    }
}
