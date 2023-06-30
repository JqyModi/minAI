//
//  MOJiSearchWordListVC.swift
//  MOJiDict
//
//  Created by Chevalier on 2022/6/23.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

let MOJiSearchWordListVCNibName      = "MOJiSearchWordListVC"
let MOJiSearchWordListClassificationCellNibName    = "MOJiSearchWordListClassificationCell"
let MOJiSearchWordListClassificationCellIdentifier = "MOJiSearchWordListClassificationCell"
let MOJiSearchWordListHotCellNibName    = "MOJiSearchWordListHotCell"
let MOJiSearchWordListHotCellIdentifier = "MOJiSearchWordListHotCell"
let MOJiSearchResultsPageCellNibName    = "MOJiSearchResultsPageCell"
let MOJiSearchResultsPageCellIdentifier = "MOJiSearchResultsPageCell"
let MOJiSearchWordListCollectionReusableViewNibName    = "MOJiSearchWordListCollectionReusableView"
let MOJiSearchWordListCollectionReusableViewIdentifier = "MOJiSearchWordListCollectionReusableView"

class MOJiSearchWordListVC: MDBaseViewController {

    @objc enum MOJiSearchWordListVCSection: Int {
        case classification = 0
        case hot            = 1
        case history        = 2
        case all            = 3
    }
    
    @objc enum MOJiSearchWordListVCSearchStatus: Int {
        case searchPage        = 0
        case searchResultsPage = 1
    }

    @IBOutlet weak var titleL:      UILabel!
    @IBOutlet weak var backBtn:     MDButton!
    @IBOutlet weak var navBar:      UIView!
    @IBOutlet weak var collectionV: MOJiCollectionView!
    @IBOutlet weak var flowLayout:  UICollectionViewFlowLayout!
    
    @objc public var searchWordListVCSearchStatus: MOJiSearchWordListVCSearchStatus = .searchPage
    @objc public var keyword: String?
    
    public var searchV:             UIView!
    public var cancelBtn:           MDButton!
    public var searchTextField:     MOJiTextField!
    public var interests            = MOJiWordListHelper.getWordListTgs()
    public var hots                 = NSArray()
    public var pageIndex: NSInteger = MDDefaultPageIndex
    public var searchResults        = NSMutableArray()
    public var lastFrameSize        = CGSize()
    private var userInfo:           [String: DB_User] = [:]
    
    //MARK: - initialise
    public static func instance() -> MOJiSearchWordListVC {
        let controller = MOJiSearchWordListVC(nibName: MOJiSearchWordListVCNibName,
                                              bundle: nil)
        return controller
    }
    
    @objc public static func viewController() -> MOJiSearchWordListVC {
        self.instance()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        collectionV.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configViews()
        getTrending()
    }
    
    @objc func configViews() {
        self.view.setTheme_backgroundColor(MOJiViewControllerViewBgColor)

        titleL.setTheme_textColor(MOJiTextColor)
        titleL.text = NSLocalizedString("搜索", comment: "")
        
        backBtn.theme_setImage(MOJiThemeImageName.nav_icon_back_black, forState: .normal)
        backBtn.addTarget(self, action: #selector(clickBackBtn), for: .touchUpInside)
        
        cancelBtn                  = MDButton()
        cancelBtn.isHidden         = true
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 14)
        cancelBtn.setTitle(NSLocalizedString("取消", comment: ""), for: .normal)
        cancelBtn.theme_setTitleColor(MOJiTextColor, forState: .normal)
        cancelBtn.addTarget(self, action: #selector(clickBackBtn), for: .touchUpInside)
        self.view.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { make in
            make.top.equalTo(navBar.snp.bottom).offset(4)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
            make.height.equalTo(44)
            make.width.equalTo(56)
        }
        
        searchV                    = UIView()
        searchV.layer.cornerRadius = 18
        searchV.layer.borderWidth  = 1
        searchV.layer.borderColor  = MOJiThemeManager.color(name: MOJiTextColor)?.cgColor
        searchV.setTheme_backgroundColor(MOJiCollectionViewCellBgColor)
        self.view.addSubview(searchV)
        searchV.snp.makeConstraints { make in
            make.top.equalTo(navBar.snp.bottom).offset(8)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left).offset(16)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right).offset(-16)
            make.height.equalTo(36)
        }
        
        let searchImage   = UIImageView()
        searchImage.image = UIImage.init(named: "ic_logo_search")
        searchV.addSubview(searchImage)
        searchImage.snp.makeConstraints { make in
            make.top.equalTo(searchV).offset(8)
            make.left.equalTo(searchV).offset(16)
            make.height.width.equalTo(20)
        }
        
        searchTextField                 = MOJiTextField()
        searchTextField.delegate        = self
        searchTextField.returnKeyType   = .search
        searchTextField.clearButtonMode = .always
        searchTextField.font            = .systemFont(ofSize: 14)
        searchTextField.setTheme_textColor(MOJiTextColor)
        searchTextField.attributedPlaceholder = NSAttributedString.init(string: MOJiChineseLocalizedString(keyword ?? MOJiWordListSearchDefaultTitleString) ?? "", attributes: [
            NSAttributedString.Key.foregroundColor: HexColor("#ACACAC"),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
        ])
        searchV.addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(searchV).offset(8)
            make.left.equalTo(searchImage.snp.right).offset(8)
            make.right.equalTo(searchV).offset(-6)
            make.height.equalTo(20)
        }
        
        configCollectionV()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.65 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            self.searchTextField.becomeFirstResponder()
        })
    }
    
    @objc func clickBackBtn(_ btn: UIButton) { back() }
    
    func configCollectionV() {
        flowLayout.sectionInset       = UIEdgeInsets(top: 0, left: CGFloat(16), bottom: 0, right: CGFloat(16))
        flowLayout.minimumLineSpacing = CGFloat(12)
        
        collectionV.delegate                       = self
        collectionV.dataSource                     = self
        collectionV.showsVerticalScrollIndicator   = false
        collectionV.showsHorizontalScrollIndicator = false
        collectionV.backgroundColor                = .clear
        collectionV.refreshControl                 = self.refreshCtrl
        collectionV.mj_footer                      = MDRefreshHelper.addFooterView(withRefreshingTarget: self, refreshingAction: #selector(loadMoreData))
        collectionV.mj_footer!.isHidden            = true
        
        collectionV?.register(UINib.init(nibName: MOJiSearchWordListClassificationCellNibName, bundle: Bundle.main), forCellWithReuseIdentifier: MOJiSearchWordListClassificationCellIdentifier)
        collectionV?.register(UINib.init(nibName: MOJiSearchWordListHotCellNibName, bundle: Bundle.main), forCellWithReuseIdentifier: MOJiSearchWordListHotCellIdentifier)
        collectionV?.register(UINib.init(nibName: MOJiSearchResultsPageCellNibName, bundle: Bundle.main), forCellWithReuseIdentifier: MOJiSearchResultsPageCellIdentifier)
        collectionV?.register(UINib.init(nibName: MOJiSearchWordListCollectionReusableViewNibName, bundle: Bundle.main), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MOJiSearchWordListCollectionReusableViewIdentifier)
    }
}

//MARK: - 请求
extension MOJiSearchWordListVC {
    // 下拉
    @objc override func refreshData() {
        if searchWordListVCSearchStatus == .searchPage {
            MDUIUtils.endRefreshing(fromRefreshCtrl: self.refreshCtrl)
            return
        }
        
        guard let headerCtrl = self.collectionV.refreshControl else { return }
        guard let footerCtrl = self.collectionV.mj_footer else { return }
        
        if (footerCtrl.isRefreshing) {
            headerCtrl.endRefreshing()
            return
        }
    
        self.pageIndex = MDDefaultPageIndex
        searchWord(MDDefaultPageIndex, searchTextField.text ?? "")
    }
    
    // 上拉
    @objc override func loadMoreData() {
        if searchWordListVCSearchStatus == .searchPage {
            self.collectionV.mj_footer?.endRefreshing()
            return
        }
        
        if !MDUserHelper.isLogin() {
            collectionV.mj_footer?.endRefreshing()
            MDUIUtils.tryToPresentLoginVC()
            return
        }
        
        guard let headerCtrl = self.collectionV.refreshControl else { return }
        guard let footerCtrl = self.collectionV.mj_footer else { return }
        
        if (headerCtrl.isRefreshing) {
            footerCtrl.endRefreshing()
            return
        }
        
        // 搜索最多10页
        if self.pageIndex <= 10 {
            searchWord(pageIndex, searchTextField.text ?? "")
        }
    }
    
    @objc func searchWord(_ page: NSInteger, _ searchText: String) {
        let keywordStr = MDStringUtils.trimmingWhitespaceAndNewLineCharacters(with: searchText)
        
        if keywordStr == "" {
            MDUIUtils .showToast(NSLocalizedString("请输入搜索内容", comment: ""))
            return
        }
        
        self.view.endEditing(true)
        
        self.showProgressHUD()
        
        let targetTypesss: TargetType = .folder
        let types: NSArray            =  NSArray.init(object: NSNumber(integerLiteral: targetTypesss.rawValue))
        
        let searchHistorys: NSMutableArray = NSMutableArray.init(array: MOJiWordListHelper.getSearchWordListHistoryKeyword())
        
        // 搜索的关键词 历史里面没有的才添加进去
        if !searchHistorys.contains(searchText) {
            MOJiWordListHelper.saveSearchWordListHistory(withKeyword: searchText)
        }
        
        MOJiWordListHelper.getSearchWordList(withKeyword: searchText , types: types as! [Any], page: page, limit: MDDefaultPageSize) { response, error in
            if response.isOK() { 
                if page == MDDefaultPageIndex {
                    self.searchResults = NSMutableArray.init(array: response.result)
                } else {
                    self.searchResults.addObjects(from: response.result)
                }
                
                self.setUserInfo(users: response.users)
            }
            
            if page == MDDefaultPageIndex {
                self.collectionV.mj_footer?.isHidden = (self.searchResults.count == 0)
            } else {
                self.collectionV.mj_footer?.isHidden = (response.isOK() ? response.result.count == 0 : self.searchResults.count == 0)
            }
            
            if response.result.count >= MDDefaultPageSize {
                self.pageIndex += 1
                self.collectionV.mj_footer?.isHidden = self.pageIndex == 11
            } else {
                self.collectionV.mj_footer?.isHidden = true
            }
            
            self.collectionV.mj_footer?.endRefreshing()
            
            MDUIUtils.endRefreshing(fromRefreshCtrl: self.refreshCtrl)
            
            self.searchWordListVCSearchStatus = .searchResultsPage
            self.collectionV.reloadData()
            
//            if response.isOK() {
//                self.pageIndex = response.page + 1
//            }
            
            self.view.endEditing(true)
            
            self.hideProgressHUD()
            
            self.searchTextField.text = searchText
        }
    }
    
    private func setUserInfo(users: [DB_User]) {
        for i in 0..<users.count {
            let user = users[i]
            
            if (!user.objectId.isEmpty) {
                userInfo[user.objectId] = user
            }
        }
    }
    
    @objc func getTrending() {
        MOJiWordListHelper.getWordListTrending { response, error in
            if response.isOK() {
                self.hots = response.result.count > 0 ? (response.result as NSArray) : []
                self.collectionV.reloadData()
            }
        }
    }
}
  
//MARK: - Textfield delegates
extension MOJiSearchWordListVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        MOJiLogEvent.logEvent(withName: MOJiLogEventName.shareSearchSearch)
        self.pageIndex = MDDefaultPageIndex
        updateSearchList(((searchTextField.text?.count ?? 0) > 0 ? searchTextField.text : keyword) ?? MOJiWordListSearchDefaultTitleString, MDDefaultPageIndex)
        
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        updateStyle()
        
        return true
    }
    
    func updateStyle() {
        searchWordListVCSearchStatus    = .searchPage
        collectionV.mj_footer!.isHidden = true
        collectionV.reloadData()
        
        cancelBtn.isHidden = true
        searchV.snp.remakeConstraints { make in
            make.top.equalTo(navBar.snp.bottom).offset(8)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left).offset(16)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right).offset(-16)
            make.height.equalTo(36)
        }
    }
    
    func updateSearchList(_ searchText: String, _ pageIndex: NSInteger) {
        searchWord(pageIndex, searchText as String)
        
        cancelBtn.isHidden = false
        searchV.snp.remakeConstraints { make in
            make.top.equalTo(navBar.snp.bottom).offset(8)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left).offset(16)
            make.right.equalTo(self.cancelBtn.snp.left)
            make.height.equalTo(36)
        }
    }
}

//MARK: - UIScrollViewDelegate
extension MOJiSearchWordListVC: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }
}

//MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension MOJiSearchWordListVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if searchWordListVCSearchStatus == .searchResultsPage {
            return 1
        } else {
            return Int(MOJiSearchWordListVCSection.all.rawValue)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searchWordListVCSearchStatus == .searchResultsPage {
            return self.searchResults.count
        } else {
            if section == Int(MOJiSearchWordListVCSection.classification.rawValue) {
                return interests.count
            } else if section == Int(MOJiSearchWordListVCSection.hot.rawValue) {
                return hots.count
            } else {
                return MOJiWordListHelper.getSearchWordListHistoryKeyword().count
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if searchWordListVCSearchStatus == .searchResultsPage {
            let model: DB_UserActivity = self.searchResults[indexPath.row] as! DB_UserActivity
            
            let cell     = collectionView.dequeueReusableCell(withReuseIdentifier: MOJiSearchResultsPageCellIdentifier, for: indexPath) as! MOJiSearchResultsPageCell
            cell.keyword = self.searchTextField.text as NSString?
            
            if let user = userInfo[model.createdBy] {
                cell.user = user
            }
            
            cell.model   = model
            
            return cell
        } else {
            if indexPath.section == Int(MOJiSearchWordListVCSection.classification.rawValue) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MOJiSearchWordListClassificationCellNibName, for: indexPath) as! MOJiSearchWordListClassificationCell
                cell.titleBtn.setTitle(MOJiChineseLocalizedString(interests[indexPath.row]), for: .normal)
                cell.titleBtnEvent = {
                    MOJiLogEvent.logEvent(withName: MOJiLogEventName.shareSearchClassify)
                    MDUIUtils.pushWordListTypesVC(withCurrentVCIndex: indexPath.row)
                }
                
                return cell
            } else {
                let cell           = collectionView.dequeueReusableCell(withReuseIdentifier: MOJiSearchWordListHotCellIdentifier, for: indexPath) as! MOJiSearchWordListHotCell
                let datas: NSArray = (indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue)) ? self.hots : MOJiWordListHelper.getSearchWordListHistoryKeyword() as NSArray
                
                cell.titleBtnEvent = { [weak self] () -> () in
                    guard let self = self else { return }
                    
                    self.pageIndex = MDDefaultPageIndex
                    
                    self.updateSearchList(datas[indexPath.row] as? String ?? "", MDDefaultPageIndex)
                    
                    if indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue) {
                        MOJiLogEvent.logEvent(withName: MOJiLogEventName.shareSearchHot)
                    } else {
                        MOJiLogEvent.logEvent(withName: MOJiLogEventName.shareSearchHistory)
                    }
                }
                
                var titleStr = datas[indexPath.row] as? String
                if indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue) {
                    if titleStr?.count ?? 0 > 10 {
                        let strIndex = titleStr?.index(titleStr!.startIndex, offsetBy: 10)
                        titleStr     = "\(String(titleStr![..<strIndex!]))" + "..."
                    }
                } else {
                    if titleStr?.count ?? 0 > 8 {
                        let strIndex = titleStr?.index(titleStr!.startIndex, offsetBy: 8)
                        titleStr = "\(String(titleStr![..<strIndex!]))" + "..."
                    }
                }
                
                cell.titleBtn.setTitle(MOJiChineseLocalizedString(titleStr), for: .normal)
                    
                return cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var headerView: MOJiSearchWordListCollectionReusableView = MOJiSearchWordListCollectionReusableView()
        
        headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MOJiSearchWordListCollectionReusableViewIdentifier, for: indexPath) as! MOJiSearchWordListCollectionReusableView
        
        headerView.titleL.isHidden    = (indexPath.section == Int(MOJiSearchWordListVCSection.classification.rawValue))
        headerView.deleteBtn.isHidden = !(indexPath.section == Int(MOJiSearchWordListVCSection.history.rawValue))
        
        if searchWordListVCSearchStatus == .searchResultsPage {
            headerView.titleL.text     = NSLocalizedString("未搜索到匹配内容", comment: "")
            headerView.titleL.isHidden = (self.searchResults.count != 0)
        } else {
           if indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue) {
                headerView.titleL.text = (self.hots.count == 0) ? "" : NSLocalizedString("热门搜索", comment: "")
            } else if indexPath.section == Int(MOJiSearchWordListVCSection.history.rawValue) {
                headerView.deleteBtnEvent = { [weak self] () -> () in
                    guard let self = self else { return }
                    
                    MOJiWordListHelper.emptySearchWordListHistoryKeyword()
                    self.collectionV.reloadData()
                }
                
                headerView.titleL.text = (MOJiWordListHelper.getSearchWordListHistoryKeyword().count == 0) ? "" : NSLocalizedString("历史记录", comment: "")
                
                headerView.deleteBtn.isHidden = (MOJiWordListHelper.getSearchWordListHistoryKeyword().count == 0)
            }
        }
        
        return headerView
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if searchWordListVCSearchStatus == .searchResultsPage {
            return CGSize(width: Int(collectionV.width), height: Int((self.searchResults.count == 0) ? 56 : 16))
        } else {
            if section == MOJiSearchWordListVCSection.classification.rawValue {
                return CGSize(width: Int(collectionV.width), height: Int(16))
             } else if section == MOJiSearchWordListVCSection.hot.rawValue {
                return CGSize(width: Int(collectionV.width), height: Int((self.hots.count == 0) ? 16 : 56))
             } else {
                return CGSize(width: Int(collectionV.width), height: Int(56))
             }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if searchWordListVCSearchStatus == .searchResultsPage {
            return CGSize(width: Int(collectionV.width), height: Int(56))
        } else {
            if indexPath.section == Int(MOJiSearchWordListVCSection.classification.rawValue) {
                let classificationWidth = (MOJiTagCollectionViewCell.viewWidth(interests[indexPath.row], height: 28, fontSize: 12) + 36)
                return CGSize(width: Int(classificationWidth), height: Int(28))
            } else {
                let datas: NSArray = (indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue)) ? self.hots : MOJiWordListHelper.getSearchWordListHistoryKeyword() as NSArray

                var titleStr = datas[indexPath.row] as? String
                
                if indexPath.section == Int(MOJiSearchWordListVCSection.hot.rawValue) {
                    if titleStr?.count ?? 0 > 10 {
                        let strIndex = titleStr?.index(titleStr!.startIndex, offsetBy: 10)
                        titleStr     = "\(String(titleStr![..<strIndex!]))" + "..."
                    }
                } else {
                    if titleStr?.count ?? 0 > 8 {
                        let strIndex = titleStr?.index(titleStr!.startIndex, offsetBy: 8)
                        titleStr = "\(String(titleStr![..<strIndex!]))" + "..."
                    }
                }
                
                let width = (MOJiTagCollectionViewCell.viewWidth(titleStr ?? "", height: 32, fontSize: 13) + 24)
                
                return CGSize(width: Int(width), height: Int(32))
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.view.endEditing(true)
        
        if searchWordListVCSearchStatus == .searchResultsPage {
            MOJiLogEvent.logEvent(withName: MOJiLogEventName.shareSearchResultList)
            
            let model: DB_UserActivity = self.searchResults[indexPath.row] as! DB_UserActivity
            MDUIUtils.pushFavInfoVC(withFolderId: model.targetId, needParentCollectStatus: false)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !lastFrameSize.equalTo(view.frame.size) {
            flowLayout.invalidateLayout()
            collectionV.layoutIfNeeded()
            
            collectionV.reloadData()
        }
    
        lastFrameSize = view.frame.size
    }
}
