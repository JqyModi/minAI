//
//  MOJiWordListMsgVC.swift
//  MOJiDict
//
//  Created by Chevalier on 2022/6/24.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit

let MOJiWordListMsgVCNibName      = "MOJiWordListMsgVC"
let MOJiWordListMsgCellNibName    = "MOJiWordListMsgCell"
let MOJiWordListMsgCellIdentifier = "MOJiWordListMsgCell"

class MOJiWordListMsgVC: MDBaseViewController {

    @IBOutlet weak var titleL:  UILabel!
    @IBOutlet weak var backBtn: MDButton!
    @IBOutlet weak var tableV:  MOJiTableView!
    
    public var pageIndex: NSInteger = MDDefaultPageIndex
    public var messages             = NSMutableArray()
    
    private var userInfo:    [String: DB_User] = [:]
    private var folderInfo:  [String: Folder] = [:]
    private var commentInfo: [String: MOJiComment] = [:]
    
    public lazy var tipsV: MOJiQANoDataFooterView = {
        let tipsV                 = MOJiQANoDataFooterView.loadFromNib()
        tipsV.backgroundColor     = .clear
        tipsV.titleL.text         = NSLocalizedString("暂无消息", comment: "")
        tipsV.refreshBtn.isHidden = true
        
        return tipsV
    }()
    
    public static func instance() -> MOJiWordListMsgVC {
        let controller = MOJiWordListMsgVC(nibName: MOJiWordListMsgVCNibName,
                                           bundle: nil)
        return controller
    }
    
    @objc public static func viewController() -> MOJiWordListMsgVC {
        self.instance()
    }

    private var commentsInfo = [String: MOJiComment]()
    
    public lazy var inputBoxTextView: MOJiTextView = {
        let inputBoxTextView                        = MOJiTextView()
        inputBoxTextView.tintColor                  = .clear
        inputBoxTextView.inputAccessoryView         = commentInputView
        inputBoxTextView.inputAccessoryView?.height = screenHeight
        inputBoxTextView.delegate                   = self
        
        return inputBoxTextView
    }()

    private lazy var commentInputView: MOJiCommentInputView = {
        let commentInputView = MOJiCommentInputView()
        
        commentInputView.didSendBlock = { [weak self] inputView, comment  in
            guard let strongSelf = self else { return }
            
            strongSelf.view.endEditing(true)
            
            if comment.objectId.count > 0 {
                strongSelf.commentsInfo[comment.objectId] = comment
            }
            
            MOJiCommentHelper.requestToComment(withTargetId: inputView.targetId, targetType: inputView.targetType, content: inputView.editorTextView.text, replyToUserId:  comment.author.objectId, replyToId: comment.objectId, attachmentId:nil, attachmentType:0) { response, error in
                // 已经有MOJiCommentSuccess通知去处理了
            }
        }
        
        return commentInputView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initialize()
        configViews()
        loadData()
    }
    
    func initialize() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateLikeStauts(_:)), name:NSNotification.Name.MOJiDefaultLikeAction, object: nil)
    }
    
    @objc func configViews() {
        titleL.setTheme_textColor(MOJiTextColor)
        titleL.text = NSLocalizedString("通知", comment: "")
        
        backBtn.theme_setImage(MOJiThemeImageName.nav_icon_back_black, forState: .normal)
        backBtn.addTarget(self, action: #selector(clickBackBtn), for: .touchUpInside)
        
        configTableView()
        
        self.view.addSubview(self.inputBoxTextView)
        self.inputBoxTextView.snp.makeConstraints { make in
            make.left.top.equalTo(self.view)
            make.size.equalTo(CGSizeZero)
        }
    }
    
    @objc func clickBackBtn(_ btn: UIButton) { back() }

    func configTableView() {
        tableV.delegate            = self
        tableV.dataSource          = self
        tableV.backgroundColor     = .clear
        tableV.contentInset        = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableV.refreshControl      = self.refreshCtrl
        tableV.mj_footer           = MDRefreshHelper.addFooterView(withRefreshingTarget: self, refreshingAction: #selector(loadMoreData))
        tableV.mj_footer!.isHidden = true
        
        tableV?.register(UINib.init(nibName: MOJiWordListMsgCellNibName, bundle: nil), forCellReuseIdentifier: MOJiWordListMsgCellIdentifier)
    }
    
    override func themeStyleDidChange(_ notification: Notification) {
        super.themeStyleDidChange(notification)
        
        tableV.reloadData()
    }
}

extension MOJiWordListMsgVC {
    @objc func loadData() {
        self.showProgressHUD()
        getMessages(MDDefaultPageIndex)
    }
    
    // 下拉
    @objc override func refreshData() {
        guard let headerCtrl = self.tableV.refreshControl else { return }
        guard let footerCtrl = self.tableV.mj_footer else { return }
        
        if (footerCtrl.isRefreshing) {
            headerCtrl.endRefreshing()
            return
        }
        
        getMessages(MDDefaultPageIndex)
    }
    
    // 上拉
    @objc override func loadMoreData() {
        if !MDUserHelper.isLogin() {
            tableV.mj_footer?.endRefreshing()
            MDUIUtils.tryToPresentLoginVC()
            return
        }
        
        guard let headerCtrl = self.tableV.refreshControl else { return }
        guard let footerCtrl = self.tableV.mj_footer else { return }
        
        if (headerCtrl.isRefreshing) {
            footerCtrl.endRefreshing()
            return
        }
        
        getMessages(pageIndex)
    }
    
    @objc func getMessages(_ page: NSInteger) {
        MOJiWordListHelper.getWordListMessages(withPage: page, limit: MDDefaultPageSize) { response, error in
            self.hideProgressHUD()
            
            if response.isOK() {
                if page == MDDefaultPageIndex {
                    self.messages = NSMutableArray.init(array: response.result)
                } else {
                    self.messages.addObjects(from: response.result)
                }
                
                self.updateSubData(resp: response)
            }
            
            if page == MDDefaultPageIndex {
                self.tableV.mj_footer?.isHidden = (self.messages.count == 0)
            } else {
                self.tableV.mj_footer?.isHidden = (response.isOK() ? response.result.count == 0 : self.messages.count == 0)
            }
            
            self.tableV.mj_footer?.endRefreshing()
            
            MDUIUtils.endRefreshing(fromRefreshCtrl: self.refreshCtrl)
            
            self.tableV.reloadData()
            
            if response.isOK() {
                self.pageIndex = response.page + 1
            }
            
            if self.messages.count == 0 {
                self.tableV.tableFooterView         = self.tipsV
                self.tableV.tableFooterView?.height = 345
            } else {
                self.tableV.tableFooterView         = UIView()
                self.tableV.tableFooterView?.height = 0
            }
        }
    }
    
    private func updateSubData(resp: MDFetchUserActivitiesResponse) {
        setUserInfo(users: resp.users)
        setFolderInfo(folders: resp.folders)
        setCommentInfo(comments: resp.comments)
    }
    
    private func setCommentInfo(comments: [MOJiComment]) {
        for i in 0..<comments.count {
            let comment = comments[i]
            
            if (!comment.objectId.isEmpty) {
                commentInfo[comment.objectId] = comment
            }
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
    
    private func setFolderInfo(folders: [Folder]) {
        for i in 0..<folders.count {
            let folder = folders[i]
            
            if (!(folder.objectId?.isEmpty ?? false)) {
                folderInfo[folder.objectId ?? ""] = folder
            }
        }
    }
    
    func didBeginEditing() {
        commentInputView.editorTextView.becomeFirstResponder()
        commentInputView.editorTextView.inputView = nil
        commentInputView.editorTextView.reloadInputViews()
        commentInputView.expressionBtn.isSelected = false
    }
    
    @objc func updateLikeStauts(_ notification: Notification) {
        let userInfo = notification.userInfo! as NSDictionary
        let objectId = userInfo[MOJiKey.objectIdKey] as! String
        let isLiked  = userInfo[MOJiKey.isLikedKey] as! Bool

        if commentInfo.keys.contains(objectId) {
            let comment: MOJiComment = commentInfo[objectId]!
            comment.isLiked          = isLiked
            commentInfo[objectId]    = comment
            
            tableV.reloadData()
        }
    }
}

//MARK: - UITextViewDelegate
extension MOJiWordListMsgVC: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        didBeginEditing()
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return !MDUserHelper.tryToPushAccountEditVCWhenPersonalInfoIsIncomplete()
    }
}

//MARK: - UITableViewDelegate, UITableViewDataSource
extension MOJiWordListMsgVC: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MOJiWordListMsgCellIdentifier) as! MOJiWordListMsgCell

        processData(cell, messages[indexPath.row] as? DB_UserActivity ?? DB_UserActivity())
         
        cell.tapReplyBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.replayAction(cell)
        }
        
        cell.tapLikeBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.likeAction(cell)
        }
        
        return cell
    }
    
    func replayAction(_ cell: MOJiWordListMsgCell) {
        guard let comment = cell.comment else { return }
        
        comment.author = MOJiAuthor.init(objectId: cell.user?.objectId ?? "", name: cell.user?.name, username: cell.user?.username, brief: cell.user?.brief, vTag: cell.user?.vTag)
        
        self.commentInputView.targetId      = comment.parentId.count > 0 ? comment.parentId : comment.objectId
        self.commentInputView.targetType    = .comment
        self.commentInputView.comment       = comment
        self.commentInputView.replyToUserId = comment.author.objectId
        self.inputBoxTextView.becomeFirstResponder()
    }
    
    func likeAction(_ cell: MOJiWordListMsgCell) {
        guard let comment = cell.comment else { return }
        
        let type: MOJiActivityType = comment.isLiked ? .unlike : .like
        
        comment.isLiked = !comment.isLiked
        
//        let indexPath = self.tableV.indexPath(for: cell)!
//        self.tableV.reloadRows(at: [indexPath], with: .none)
        
        self.tableV.reloadData()
        
        MOJiCommentHelper.likeComment(withTargetId: comment.objectId, targetType: .comment, type: type)
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let message: DB_UserActivity = messages[indexPath.row] as? DB_UserActivity ?? DB_UserActivity()
        
        let activityType = MOJiActivityType(rawValue: UInt(message.activityType.intValue))
        
        if activityType == .follow || activityType == .passiveUpdate {
            MDUIUtils.pushFavInfoVC(withFolderId: message.folderId)
        } else {
            if let folder = folderInfo[message.folderId] {
                MDUIUtils.pushCommentListVC(withFolderId: message.folderId, title: folder.title)
            }
        }
    }
    
    func processData(_ cell: MOJiWordListMsgCell, _ activity: DB_UserActivity) {
        let activityType = MOJiActivityType(rawValue: UInt(activity.activityType.intValue))
        
        switch activityType {
        case .passiveUpdate:
            // 更新
            do {
                if let folder = folderInfo[activity.folderId] {
                    cell.folder = folder
                }
            }
            break
        case .follow:
            // 收藏
            do {
                if let folder = folderInfo[activity.folderId] {
                    cell.folder = folder
                }
                
                let createdBys: NSArray = activity.createdBy.components(separatedBy: ",") as NSArray
                
                let users: NSMutableArray = NSMutableArray.init()
                
                for i in 0..<createdBys.count {
                    if let user = userInfo[createdBys[i] as! String] {
                        users.add(user)
                    }
                }
                
                cell.followUsers = users
            }
            break
        case .like:
            // 点赞
            do {
                if let user = userInfo[activity.createdBy] {
                    cell.user = user
                }
                
                if let folder = folderInfo[activity.folderId] {
                    cell.folder = folder
                }
                
                if let comment = commentInfo[activity.targetId] {
                    cell.comment = comment
                }
            }
            break
        case .comment:
            // 评论
            do {
                getCommentMsg(cell, activity)
            }
            break
        case .replyComment:
            // 回复评论
            do {
                getCommentMsg(cell, activity)
            }
            break
        default:
            break
        }
    
        cell.model = activity
    }
    
    func getCommentMsg(_ cell: MOJiWordListMsgCell, _ activity: DB_UserActivity) {
        if let user = userInfo[activity.createdBy] {
            cell.user = user
        }
        
        if let folder = folderInfo[activity.folderId] {
            cell.folder = folder
        }
        
        if let comment = commentInfo[activity.activityId] {
            cell.comment = comment
        }
    }
}
