//
//  MOJiAIVC.swift
//  MOJiDict
//
//  Created by Ji Xiang on 2023/5/29.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import UIKit
import BackendConfigRaw

private let MOJiAIVCNibName = "MOJiAIVC"

private let GPT_EVENT_ERROR   = "event:error"
private let GPT_EVENT_MESSAGE = "event:message"
private let GPT_EVENT_GPT     = "event:gpt"
private let GPT_EVENT_END     = "event:end"
private let GPT_DATA          = "data:"

private let SearchBarDefaultHeight = 68.0
private let SearchBarTopViewHeight = 50.0
private let MOJiAIVCToolViewHeight = 48.0

class MOJiAIVC: MDBaseLoginViewController {
    
    var resultShowOnView: UIView?
    var homeVc: MOJiHomeVC?

    @IBOutlet weak var toolV: UIView!
    @IBOutlet weak var proBtn: MDButton!
    @IBOutlet weak var proImageV: UIImageView!
    @IBOutlet weak var proTitleL: UILabel!
    @IBOutlet weak var qrCodeBtn: MDButton!
    @IBOutlet weak var descriptionBtn: MDButton!
    
    private lazy var stopBtn: MDButton = {
        let btn = MDButton()
//        btn.clipsToBounds      = true
//        btn.layer.cornerRadius = 16
        btn.highlightColor = .clear
        btn.setImage(UIImage(named: "ic_home_suspend"), for: .normal)
        btn.addTarget(self, action:#selector(stopGTPAnswer), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    private lazy var tableV: MOJiTableView = {
        let tableV                            = MOJiTableView(frame: .zero, style: .grouped)
        tableV.delegate                       = self
        tableV.dataSource                     = self
        tableV.showsVerticalScrollIndicator   = false
        tableV.showsHorizontalScrollIndicator = false
        tableV.backgroundColor                = .clear
#warning("TODO 反向")
//        tableV.contentInset                   = UIEdgeInsets(top: 0, left: 0, bottom: MOJiAIVCToolViewHeight, right: 0)
#warning("TODO 正向")
        tableV.contentInset                   = UIEdgeInsets(top: MOJiAIVCToolViewHeight, left: 0, bottom: 0, right: 0)
        return tableV
    }()
    
    private var searchText: String = ""
    private var menuItemObject: RLMObject?
    private var menuItemIndexPath: IndexPath?
    private var gptFunctionType: MOJiAIAnswerGPTType = .searchWord
    
    /// —— GPT请求相关 ——
    private lazy var session: URLSession = {
        let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return session
    }()
    
    private var task: URLSessionDataTask?
    
    private var isFirstSearch = true
    private var messages = [RLMObject]()
    private var tmpQuestionId: String = ""
    private var tmpGPTAnswer: DB_AIAnswer?
    private var tmpAnswerText = ""
    private var isAnswering = false // GPT正在回答中
    private var isGPTEnd = false // GPT回答结束
    /// ————
    
    private lazy var tableHeaderV: UIView = {
        let tableHeaderV             = UIView.init(frame: .zero)
//        tableHeaderV.backgroundColor = .clear
        tableHeaderV.backgroundColor = UIColor(hexString: "#FF5252")
        return tableHeaderV
    }()
    
    private var lastFooterHeight: CGFloat = 0
    private var lastSearchBarBottom: CGFloat = 0.1 // 第一次的时候默认为0，还是需要更新高度的
    private var isShowSearchBarAITopV = false
    
    public static func instance() -> MOJiAIVC {
        let controller = MOJiAIVC(nibName: MOJiAIVCNibName, bundle: nil)
        return controller
    }
    
    @objc public static func viewController() -> MOJiAIVC {
        self.instance()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !MDUserHelper.isLogin() {
            MDUIUtils.tryToPresentLoginVC {
                if !MDUserHelper.isLogin() {
                    self.homeVc?.change(to: Int(MDMainVCChildVCType.search.rawValue))
                }
            }
        }
        
        updateSearchBarAITopViewStatus(scrollToBottom: false)
        updateSearchBarBottom(bottom: self.homeVc?.searchVc.lastSearchBarBottom ?? 0.0, scrollToBottom: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addObserver()
        configViews()
        fetchData()
    }
    
    func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(LoginOrLogoutToDo), name: .LoginSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginOrLogoutToDo), name: .LogoutSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(operateItemsSuccess(_:)), name: .MDAddOrUpdateItemsSuccess, object: nil)
    }
    
    func configViews() {
        configToolView()
        configTableView()
    }
    
    func configToolView() {
        proBtn.layer.cornerRadius         = 16.0
        qrCodeBtn.layer.cornerRadius      = 16.0
        descriptionBtn.layer.cornerRadius = 16.0
        
        proBtn.highlightColor         = .clear
        qrCodeBtn.highlightColor      = .clear
        descriptionBtn.highlightColor = .clear
        
        proBtn.mt.dynamicBgColor         = MOJiAIColors.proBtnBgColor
        qrCodeBtn.mt.dynamicBgColor      = MOJiAIColors.proBtnBgColor
        descriptionBtn.mt.dynamicBgColor = MOJiAIColors.proBtnBgColor
        
        proImageV.image = UIImage.init(named: "ic_home_limit")
        proTitleL.setTheme_textColor(MOJiTextColor)
        proTitleL.text = "额度".localized()
        
        qrCodeBtn.mt.setDynamicImage(MOJiAIImages.homeGroup, for: .normal)
        descriptionBtn.mt.setDynamicImage(MOJiAIImages.homeNotice, for: .normal)
        
        proBtn.addTarget(self, action: #selector(showProAction), for: .touchUpInside)
        qrCodeBtn.addTarget(self, action: #selector(qrCodeAction), for: .touchUpInside)
        descriptionBtn.addTarget(self, action: #selector(descriptionAction), for: .touchUpInside)
    }
    
    func configTableView() {
        self.view?.insertSubview(tableV, belowSubview: toolV)
        tableV.snp.makeConstraints { make in
            make.top.equalTo(toolV.snp.top)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        
        // 为了下拉加载能够顺畅，需要将tableView进行翻转180°，因此cell也要跟着翻转
//        tableV.transform       = CGAffineTransform(scaleX: 1, y: -1)
//        tableV.tableHeaderView = tableHeaderV
        
        tableV.register(UINib.init(nibName: MOJiAIQuestionCell.cellIdentifier, bundle: nil), forCellReuseIdentifier: MOJiAIQuestionCell.cellIdentifier)
        tableV.register(UINib.init(nibName: MOJiAIAnswerWordCell.cellIdentifier, bundle: nil), forCellReuseIdentifier: MOJiAIAnswerWordCell.cellIdentifier)
        tableV.register(UINib.init(nibName: MOJiAIAnswerGPTCell.cellIdentifier, bundle: nil), forCellReuseIdentifier: MOJiAIAnswerGPTCell.cellIdentifier)
        
        #warning("TODO 反向")
//        tableV.mj_footer = MDRefreshHelper.addFooterView(withRefreshingTarget: self, stateIdleTitle: "", refreshingAction: #selector(loadMoreData))
        
        #warning("TODO 正向")
        tableV.refreshControl = self.refreshCtrl
        
        self.view?.insertSubview(stopBtn, belowSubview: toolV)
        stopBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.size.equalTo(CGSize(width: 32, height: 32))
            make.bottom.equalTo(self.tableV.snp.bottom).offset(-8)
        }
    }
}

// fetch data
extension MOJiAIVC {
    
    func fetchData() {
        // 先获取本地数据，展示
        var tmpMessages  = [RLMObject]()
        var tmpQuestions = MDUserDBManager.getOnePageQuestions(from: Date())
        // 因为获得的数据是新的在最前边，所以需要翻转一下数据
        tmpQuestions     = Array(tmpQuestions.reversed())
        
        for i in 0..<tmpQuestions.count {
            let question = tmpQuestions[i]
            
            #warning("TODO 反向")
//            if let answer = MDUserDBManager.aiAnswer(withObjectId: question.objectId) {
//                tmpMessages.append(answer)
//            }
//
//            // 问题被删除或者标题为空时，不需要显示
//            if !question.isTrash.boolValue && !MDStringUtils.isEmptyString(question.content) {
//                tmpMessages.append(question)
//            }
#warning("TODO 正向")
            // 问题被删除或者标题为空时，不需要显示
            if !question.isTrash.boolValue && !MDStringUtils.isEmptyString(question.content) {
                tmpMessages.append(question)
            }
            
            if let answer = MDUserDBManager.aiAnswer(withObjectId: question.objectId) {
                tmpMessages.append(answer)
            }
        }
        
        self.messages = tmpMessages
        self.reloadTableView(animated: false)
        
        // 同时去请求最新的数据，同步并展示
        var createdAt = 0
        
        #warning("TODO 反向")
//        if let lastCreatedAt = tmpQuestions.first?.createdAt {
//            createdAt = Int(MDDateUtils.timestamp(with: lastCreatedAt))
//        }
        #warning("TODO 正向")
        if let lastCreatedAt = tmpQuestions.last?.createdAt {
            createdAt = Int(MDDateUtils.timestamp(with: lastCreatedAt))
        }
        
        // 然后拉取最新的数据，展示
        MOJiAICloudHelper.fetchChat(createdAt: createdAt, isLast: true, limit: MDDefaultPageSize) { arr, error in
            guard let tmpArr = arr else { return }
            
            // 说明是第一次加载数据，直接展示系统消息
            if tmpArr.count == 0 && self.messages.count == 0 {
                self.showSystemMessage()
                return
            }
            
            self.messages = tmpArr + self.messages
            self.reloadTableView(animated: false)
            self.updateSearchBarAITopViewStatus()
        }
        
    }
    
    func showSystemMessage() {
        self.tableV.mj_footer?.isHidden = true
        
        let systemAnswer = MOJiAIHelper.defaultSystemAnswer()

        self.messages = systemAnswer
        self.reloadTableView()
        self.updateSearchBarAITopViewStatus()
    }
    
    // 每次提问的时候都要先生成一个临时的Question去展示
    func createTmpQuestion(text: String) {
        // 不能用text来生成MD5，因为会有重问，问AI等重复的问题
        let currentDateStr = MDDateUtils.string(from: Date(), dateFormat: DefaultDateFormat) ?? ""
        tmpQuestionId      = MDStringUtils.md5(with: currentDateStr)
        
        let question           = DB_AIQuestion()
        question.objectId      = tmpQuestionId
        question.userId        = MDUserHelper.currentUserId()
        question.content       = text
        question.createdAt     = Date()
        question.updatedAt     = question.createdAt
        question.isTrash       = NSNumber(value: false)
        question.answerIsTrash = NSNumber(value: false)
        
        MDUserDBManager.transaction {
            MDUserDBManager.add([question])
        }
        MDUserDBManager.db().refresh()
        
        guard let tmpQuestion = MDDBObjectCopyer.copy(question) else { return }
        
        #warning("TODO 反向")
        // 刷新界面
//        self.tableV.performBatchUpdates {
//            self.messages.insert(tmpQuestion, at: 0)
//            self.tableV.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
//        } completion: { _ in
//            self.reloadTableView()
//        }
        
        #warning("TODO 正向")
        self.messages.append(tmpQuestion)
        self.reloadTableView()
        self.updateSearchBarAITopViewStatus()
    }
    
    // 拿到数据之后，要更新临时的tmpQuestion
    func updateTmpQuestion(objectId: String, createdAt: Date) {
        guard let tmpQuestion = MDUserDBManager.aiQuestion(withObjectId: tmpQuestionId) else { return }
        
        guard let newQuestion = MDDBObjectCopyer.copy(tmpQuestion) else { return }
        
        newQuestion.objectId  = objectId
        newQuestion.createdAt = createdAt
        newQuestion.updatedAt = createdAt
        
        // 更新messages数据源中的数据
        for index in 0..<self.messages.count {
            let rlmobject = self.messages[index]
            
            if rlmobject.objectId == tmpQuestionId {
                self.messages[index] = newQuestion
                break
            }
        }
        
        MDUserDBManager.transaction {
            MDUserDBManager.add([newQuestion])
            MDUserDBManager.deleteTmpAIQuestion(tmpQuestion)
        }
        MDUserDBManager.db().refresh()
    }
    
    func deleteTmpQuestionWhenError() {
        guard let tmpQuestion = MDUserDBManager.aiQuestion(withObjectId: tmpQuestionId) else { return }
        
        MDUserDBManager.transaction {
            MDUserDBManager.deleteTmpAIQuestion(tmpQuestion)
        }
        MDUserDBManager.db().refresh()
    }
    
    //由SearchBaseVC中的actionAI调用
    @objc func innerSearch(text: String) {
        guard text.count > 0 else {
            searchText = ""
            return
        }
        
        guard !isAnswering else {
            MDUIUtils.showToast("正在回答中，请稍等".localized())
            return
        }
        
        // AI对话需要清除上次的输入内容
        self.homeVc?.searchVc.setTextViewText("")
        searchText = text
        
        // 与上次的GPT对话超过了我们规定的时间，且字数小于规定字数的时候，直接搜索单词
        if judgeSSLTimeOut() && text.count <= MOJiDefaultsManager.mojiConfig().aiChatItem().aiWordSearchLength {
            searchWord(text: text)
        } else {
            searchGPT(text: text)
        }
    }
    
    func judgeSSLTimeOut() -> Bool {
        if isFirstSearch { // 每次打开的第一次搜索不需要判断上次是否超时了
            isFirstSearch = false
            return true
        }
        
        let aiSessionTTL = MOJiDefaultsManager.mojiConfig().aiChatItem().aiSessionTTL
        var lastDate     = Date()
        let currentDate  = NSDate()
        
#warning("TODO 反向")
//        let message = self.messages.first
#warning("TODO 正向")
        let message = self.messages.last
        
        if message is DB_AIAnswer {
            let answer = message as! DB_AIAnswer
            lastDate   = answer.createdAt
            
            // 如果上一条数据不是GPT内容，那么不需要继续走GPT
            if answer.type == MOJiAIAnswerType.word.rawValue {
                return true
            }
        } else {
            let question = message as! DB_AIQuestion
            lastDate     = question.createdAt
            
            // 如果上一条数据不是GPT内容，那么不需要继续走GPT
            if let answer = MDUserDBManager.aiAnswer(withObjectId: question.objectId),
                answer.type == MOJiAIAnswerType.word.rawValue {
                return true
            }
        }
        
        let second = Int(currentDate.secondsLaterThan(lastDate as Date))
        return second >= aiSessionTTL // 超过了约定的会话时间，说明已经断开了GPT的会话
    }
    
    func searchWord(text: String) {
        guard !isAnswering else {
            MDUIUtils.showToast("正在回答中，请稍等".localized())
            return
        }
        
        searchText = text
#warning("TODO 反向")
//        tableV.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
#warning("TODO 正向")
        tableV.scrollToRow(at: IndexPath(row: (messages.count-1), section: 0), at: .top, animated: true)
        
        createTmpQuestion(text: text)
        
        MOJiAICloudHelper.searchWord(content: text) { answer, error in
            guard let tmpAnswer = answer else {
                // 找不到单词的时候要请求GPT
                self.searchGPT(text: text, isAskAgain: true)
                return
            }
            
            self.updateTmpQuestion(objectId: tmpAnswer.objectId, createdAt: tmpAnswer.createdAt)
            
            #warning("TODO 反向")
            // 刷新界面
//            self.tableV.performBatchUpdates {
//                self.messages.insert(tmpAnswer, at: 0)
//                self.tableV.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
//            } completion: { _ in
//                self.reloadTableView()
//            }
            
            #warning("TODO 正向")
            self.messages.append(tmpAnswer)
            self.reloadTableView()
        }
    }
    
    // 重说的时候需要传objectId
    func searchGPT(text: String, objectId: String = "", isAskAgain: Bool = false) {
        guard !isAnswering else {
            MDUIUtils.showToast("正在回答中，请稍等".localized())
            return
        }
        
        searchText = text
#warning("TODO 反向")
//        tableV.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
#warning("TODO 正向")
        tableV.scrollToRow(at: IndexPath(row: (messages.count-1), section: 0), at: .top, animated: true)
        
        /**
         1、objectId不为空，说明是【重说】(同时 isAskAgain = true)
         2、没有获取到单词时 isAskAgain = true
         以上两种情况下，都不需要重新创建Question
         */
        if MDStringUtils.isEmptyString(objectId) && !isAskAgain {
            createTmpQuestion(text: text)
        }
        
        var host = ""
        
        #if DEBUG
        let env = UserDefaults.standard.object(forKey: MOJiKeyPath.serverEnvironmentKey.rawValue) as! Int

        if (env == MOJiServerEnvironment.test.rawValue) { // 测试
            host = MOJiKeyPath.aisseDevHostKey.rawValue
        } else {
            host = MOJiKeyPath.aisseProductHostKey.rawValue
        }
        #else
        host = MOJiKeyPath.aisseProductHostKey.rawValue
        #endif
        
        let objectIdStr = MDStringUtils.isEmptyString(objectId) ? "" : "&objectId=" + objectId
        var urlStr      = host + MOJiAICloud.chat.path + "?content=" + text + objectIdStr
        urlStr          = urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url         = URL(string: urlStr)
        var request     = URLRequest.init(url: url!)
        request.httpMethod = "GET"
        request.setValue(PFInstallation.current()?.installationId, forHTTPHeaderField: X_HEADER_PARSE_INSTALLATION_ID)
        request.setValue(MOJiUser.current()?.sessionToken, forHTTPHeaderField: X_HEADER_PARSE_ACCESS_TOKEN)
        
        task = self.session.dataTask(with: request)
        task?.resume()
    }
    
    func fetchGPTEndInfo(objectId: String) {
        isAnswering = true
        
        MOJiAICloudHelper.fetchIntent(objectId: objectId) { model, error in
            self.endUrlSessionToDo()
            
            guard let tmpModel = model else { return }
            guard let tmpAnswer = MDUserDBManager.aiAnswer(withObjectId: objectId) else { return }
            guard let answer = MDDBObjectCopyer.copy(tmpAnswer) else { return }
            
            answer.intent = tmpModel.intent.joined(separator: "/")
            
            MDUserDBManager.transaction {
                MDUserDBManager.add([answer])
            }
            MDUserDBManager.db().refresh()
            
#warning("TODO 反向")
//            self.messages[0] = tmpAnswer
//            self.tableV.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
#warning("TODO 正向")
            let count            = self.messages.count - 1
            self.messages[count] = tmpAnswer
            self.tableV.reloadRows(at: [IndexPath(row: count, section: 0)], with: .none)
            self.tableV.scrollToRow(at: IndexPath(row: self.messages.count-1, section: 0), at: .bottom, animated: true)
        }
    }
    
    func reloadTableView(toBottom: Bool = true, animated: Bool = true) {
        self.tableV.reloadData()
        self.updateTableHeaderViewHeight()
        
        #warning("TODO 正向")
        if toBottom, self.messages.count > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.tableV.scrollToRow(at: IndexPath(row: self.messages.count-1, section: 0), at: .bottom, animated: animated)
            })
        }
    }
    
    #warning("TODO 正向")
    @objc override func refreshData() {
        let message   = self.messages.first
        var createdAt = 0
        
        if message is DB_AIQuestion {
            let question = message as! DB_AIQuestion
            createdAt = Int(MDDateUtils.timestamp(with: question.createdAt))
        } else {
            let answer = message as! DB_AIAnswer
            createdAt = Int(MDDateUtils.timestamp(with: answer.createdAt))
        }
        
        // 然后拉取最新的数据，展示
        MOJiAICloudHelper.fetchChat(createdAt: createdAt, isLast: false, limit: MDDefaultPageSize) { arr, error in
            self.tableV.refreshControl?.endRefreshing()
            
            guard let tmpArr = arr else { return }
            
            guard tmpArr.count > 0 else {
                self.tableV.refreshControl = nil
                return
            }
            
            let arr       = Array(tmpArr.reversed())
            self.messages = arr + self.messages
            self.reloadTableView(toBottom: false)
            // 更新了界面，需要定位到之前的位置
            self.tableV.scrollToRow(at: IndexPath(row: tmpArr.count, section: 0), at: .top, animated: false)
        }
    }
    
    #warning("TODO 反向")
    // 下拉加载历史数据
    @objc override func loadMoreData() {
        let message   = self.messages.last
        var createdAt = 0
        
        if message is DB_AIQuestion {
            let question = message as! DB_AIQuestion
            createdAt = Int(MDDateUtils.timestamp(with: question.createdAt))
        } else {
            let answer = message as! DB_AIAnswer
            createdAt = Int(MDDateUtils.timestamp(with: answer.createdAt))
        }
        
        // 然后拉取最新的数据，展示
        MOJiAICloudHelper.fetchChat(createdAt: createdAt, isLast: false, limit: MDDefaultPageSize) { arr, error in
            self.tableV.mj_footer?.endRefreshing()
            
            guard let tmpArr = arr else { return }
            
            if tmpArr.count < MDDefaultPageSize {// 不足limit时，说明没有更多了
                self.tableV.mj_footer?.isHidden = true
            }
            
            self.messages = self.messages + tmpArr
            self.reloadTableView()
        }
    }
    
    @objc func LoginOrLogoutToDo() {
        if MDUserHelper.isLogin() {
            self.fetchData()
            return
        }
        
        self.messages.removeAll()
        self.tableV.reloadData()
    }
}

// GPT回复
extension MOJiAIVC: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        isAnswering = true
        isGPTEnd    = false
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let tmpString = String.init(data: data, encoding: .utf8) else { return }
        
        // 一定要回到主线程处理，不然各种问题
        DispatchQueue.main.async {
            self.getGPTAnswerTextToDo(tmpString: tmpString)
        }
    }
    
    func getGPTAnswerTextToDo(tmpString: String) {
        var text = ""
        
        if tmpString.contains(GPT_EVENT_ERROR) {
            print("出错，需要处理: " + tmpString)
            isAnswering = false
            isGPTEnd    = true
            
            // 报错的话，删除数据库中的临时问题
            deleteTmpQuestionWhenError()
            
            let tmpText = tmpString.replacingOccurrences(of: "\n", with: "")
            let textArr = tmpText.components(separatedBy: GPT_DATA)
            
            guard textArr.count > 1 else { return }
            
            guard let code = Int(textArr.last ?? "") else { return }
            
            if code == MCErrorCode.errorCodeNotAllowedUpload.rawValue {
                showProAction()
            } else if code == MCErrorCode.errorCodeFrequentOperation.rawValue {
                MDUIUtils.showToast("当前提问人数过多，请稍后再来".localized())
            } else if code == MCErrorCode.errorCodeContainSensitiveWords.rawValue {
                MDUIUtils.showToast("请问日语学习相关问题".localized())
            } else {
                let response  = [MOJiKey.codeKey.rawValue: String(code)]
                let errorTips = MOJiCloudCore.getServerErrorTips(withFunction: "", response: response)
                MDUIUtils.showToast(errorTips)
            }
            
            return
        } else if tmpString.contains(GPT_EVENT_MESSAGE) {
            print("对话内容开始返回: " + tmpString)
            isAnswering = true
            isGPTEnd    = false
            
            var tmpText = tmpString.replacingOccurrences(of: "\n", with: "")
            tmpText     = tmpText.replacingOccurrences(of: GPT_EVENT_MESSAGE, with: "")
            tmpText     = tmpText.replacingOccurrences(of: GPT_DATA, with: "")
            tmpText     = tmpText.replacingOccurrences(of: "objectId=", with: "")
            
            let textArr = tmpText.components(separatedBy: "&createdAt=")
            
            guard textArr.count > 1 else { return }
            
            let objectId     = textArr.first ?? ""
            let createdAtStr = textArr.last
            let createdAt    = MDDateUtils.date(with: createdAtStr, dateFormat: DefaultDateFormatSSSZ) ?? Date()
            
            let answer       = DB_AIAnswer()
            answer.objectId  = objectId
            answer.type      = Int(MOJiAIAnswerType.GPT.rawValue)
            answer.answer    = ""
            answer.createdAt = createdAt
            answer.updatedAt = createdAt
            
            tmpGPTAnswer = answer
            updateTmpQuestion(objectId: objectId, createdAt: createdAt)
            
        } else if tmpString.contains(GPT_EVENT_GPT) {
            print("正在返回GPT: " + tmpString)
            isAnswering = true
            isGPTEnd    = false
            
            var tmpText = tmpString.replacingOccurrences(of: "\n", with: "")
            tmpText     = tmpText.replacingOccurrences(of: GPT_EVENT_GPT, with: "")
            tmpText     = tmpText.replacingOccurrences(of: GPT_EVENT_END, with: "")
            
            let textArr = tmpText.components(separatedBy: GPT_DATA)
            
            guard textArr.count > 1 else { return }
            
            text = textArr.joined()
            
            // 可能会有这种情况，需要先更新updateGPTCellText，不然会丢失最后一段的数据
            if tmpString.contains(GPT_EVENT_END) {
                tmpAnswerText = tmpAnswerText + text
                updateGPTCellText()
                
                isAnswering = false
                isGPTEnd    = true
            }
            
        } else if tmpString.contains(GPT_EVENT_END) {
            print("对话结束，不再返回内容")
            isAnswering = false
            isGPTEnd    = true
        }
        
        if isAnswering, tmpGPTAnswer != nil, text.count > 0 {
            
            // 说明开始回复第一个字，这时候要把answer插入到数据中，刷新界面
            if MDStringUtils.isEmptyString(tmpAnswerText) {
                tmpAnswerText        = text
                tmpGPTAnswer!.answer = text
                stopBtn.isHidden     = false
                
                guard let answer = MDDBObjectCopyer.copy(tmpGPTAnswer!) else { return }
                
                MDUserDBManager.transaction {
                    MDUserDBManager.add([answer])
                }
                MDUserDBManager.db().refresh()
                
#warning("TODO 反向")
//                self.tableV.performBatchUpdates {
//                    self.messages.insert(tmpGPTAnswer!, at: 0)
//                    self.tableV.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
//                } completion: { _ in
//                    self.reloadTableView()
//                }
                
#warning("TODO 正向")
                self.messages.append(tmpGPTAnswer!)
                self.reloadTableView()
            } else {
                tmpAnswerText = tmpAnswerText + text
                
                updateGPTCellText()
            }
        } else {
            updateGPTCellText()
        }
    }
    
    @objc func updateGPTCellText() {
        guard let answer = tmpGPTAnswer else { return }
        
        isAnswering = true
        
        // 对话结束的时候，要更新数据到数据库
        if isGPTEnd {
            DispatchQueue.main.async {
                self.stopBtn.isHidden = true
            }
            
            print("对话结束，全文：" + tmpAnswerText)
            
            if let tmpAnswer = MDDBObjectCopyer.copy(answer) {
                MDUserDBManager.transaction {
                    MDUserDBManager.add([tmpAnswer])
                }
                MDUserDBManager.db().refresh()
            }
            
            //获取GPT意图判断
            self.fetchGPTEndInfo(objectId: answer.objectId)
            
            return
        }
        
        if answer.answer == tmpAnswerText { return }
        
        answer.answer = tmpAnswerText
#warning("TODO 反向")
//        self.tableV.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
#warning("TODO 正向")
        
        // 防止闪烁
        UIView.animate(withDuration: 0, delay: 0, options: [.curveLinear], animations: {
            let indexPath = IndexPath(row: self.messages.count-1, section: 0)
            self.tableV.reloadRows(at: [indexPath], with: .none)
            self.tableV.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }, completion: nil)
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("SSE请求失败: " + error!.localizedDescription)
            
            isAnswering = false
            isGPTEnd    = true
            
            updateGPTCellText() // stopGTPAnswer会走到这里
        } else {
            print("SSE请求结束")
            
            let isEnd = isGPTEnd
            
            isAnswering = false
            isGPTEnd    = true
            
            if !isEnd { // 可能意外出错，这时候要能够暂停掉
                updateGPTCellText()
            }
        }
    }
    
    func endUrlSessionToDo() {
        self.isAnswering   = false
        self.tmpGPTAnswer  = nil
        self.tmpAnswerText = ""
    }
    
    @objc func stopGTPAnswer() {
        MDImpactFeedbackGenerator.feedbackLight()
        
        guard let tmpTask = task else { return }
        guard let _ = tmpGPTAnswer else { return }
        
        tmpTask.cancel()
    }
}

// tableView contentInset and tableHeaderView
extension MOJiAIVC {
    
    @objc func updateSearchBarAITopViewStatus(scrollToBottom: Bool = true) {
        guard messages.count > 0 else { return }
        
        #warning("TODO 反向")
//        let object      = messages.first
        #warning("TODO 正向")
        let object      = messages.last
        
        var lastDate    = NSDate()
        let currentDate = NSDate()
        
        if object is DB_AIQuestion {
            let question = object as! DB_AIQuestion
            lastDate     = question.createdAt as NSDate
        } else {
            let answer = object as! DB_AIAnswer
            lastDate   = answer.createdAt as NSDate
        }
        
        let hour = currentDate.hoursLaterThan(lastDate as Date)
        // 距离上一条记录超过一小时，需要显示提示内容
        isShowSearchBarAITopV = hour > 1.0
        self.homeVc?.searchVc.changeSearchBarAITopViewShowStatus(isShowSearchBarAITopV)
        self.updateTableHeight(scrollToBottom: scrollToBottom)
    }
    
    @objc func updateSearchBarBottom(bottom: CGFloat, scrollToBottom: Bool = true) {
        // 第一次进入的时候 lastSearchBarBottom = bottom = 0, 也是需要更新约束的
        if bottom == lastSearchBarBottom { return }
        
        lastSearchBarBottom = bottom
        
        updateTableHeight(scrollToBottom: scrollToBottom)
        
        updateTableHeaderViewHeight()
    }
    
    func updateTableHeight(scrollToBottom: Bool = true) {
        var bottomH = lastSearchBarBottom + SearchBarDefaultHeight
        
        if isShowSearchBarAITopV {
            bottomH = bottomH + SearchBarTopViewHeight
        }
        
        tableV.snp.updateConstraints { make in
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-bottomH)
        }
        
        #warning("TODO 正向")
        if self.messages.count > 0, scrollToBottom {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.tableV.scrollToRow(at: IndexPath(row: self.messages.count-1, section: 0), at: .bottom, animated: true)
            })
        }
    }
    
    func updateTableHeaderViewHeight() {
        #warning("TODO 正向时直接return")
        return
        
//        guard messages.count > 0 else { return }
//
//        guard let lastCell = tableV.visibleCells.last else { return }
//
//        var cellH = 0.0
//
//        for i in 0..<tableV.visibleCells.count {
//            let tmpCell = tableV.visibleCells[i]
//            let rect    = tmpCell.convert(tmpCell.bounds, to: self.tableV)
//            cellH       = cellH + rect.size.height
//        }
//
//        let rect    = lastCell.convert(lastCell.bounds, to: self.tableV)
//        print("rect = ", rect)
//        let maxY    = rect.origin.y + rect.size.height - tableHeaderV.height
//        let bottomH = lastSearchBarBottom + SearchBarDefaultHeight + SearchBarTopViewHeight + self.view.safeAreaInsets.bottom
//        // 这里不能用tableV.height来，因为这时候tableV还保持在上一个键盘状态中呢（当前是收起键盘，但是高度还是弹出键盘时的高度）
//        let tableVH = self.view.height - toolV.height - bottomH
//
//        var height = 0.0
//
//        /**
//         1、maxY < tableVH  ==>
//         是指当前这个cell的位置还在tableV中
//         2、(tableV.contentSize.height - tableHeaderV.height) <= tableVH  ==>
//         是指tableV的内容高度比可见高度要小，如果只有第一个条件，没有第二个条件，那么在键盘收起的时候，虽然内容高度超过屏幕了，但此时的maxY是在键盘弹起时的值，第一个条件也成立，这时候会进入if中，造成tableHeaderV的高度不为0
//         */
//        if maxY < tableVH && (tableV.contentSize.height - tableHeaderV.height) <= tableVH { // 当最后一个cell的高度还不能占满tableV减去底部内容的剩余高度时
//            height = tableVH - cellH - lastFooterHeight
//        }
//
//        tableHeaderV.height    = height
//        tableV.tableHeaderView = tableHeaderV
    }
}
    
// VC funcion
extension MOJiAIVC {
    
    @objc func operateItemsSuccess(_ noti: NSNotification) {
        var hasWordCell = false
        
        // 如果当前可见的cell中有单词类型的，刷新列表
        for i in 0..<tableV.visibleCells.count {
            let tmpCell = tableV.visibleCells[i]
            
            if tmpCell is MOJiAIAnswerWordCell {
                hasWordCell = true
                break
            }
        }
        
        if hasWordCell {
            self.tableV.reloadData()
        }
    }
    
    // 展示余额弹窗
    @objc func showProAction() {
        MOJiLogEvent.logEvent(withName: .aiQuota)
        
        let vc = MOJiPolishExpansionVC(fromType: .AI)
        vc.pushUrlHandler = { url in
            MDUIUtils.pushWebSearchVC(withUrl: url)
        }
        vc.pushQuotaDetailsHandle = { [weak self] in
            MOJiLogEvent.logEvent(withName: .proofreadHistoryBill)
            self?.navigationController?.pushViewController(MOJiPolishQuotaListVC(), animated: true)
        }
        self.present(vc, animated: true)
    }
    
    // 展示二维码
    @objc func qrCodeAction() {
        MOJiLogEvent.logEvent(withName: .aiGroup)
        #warning("TODO 待更换type")
//        MDUIUtils.publicJumpToMiniProgram(withType: "aiChat")
        
        let vc = MOJiAIQRCodeVC.viewController()
        self.present(vc, animated: true)
    }
    
    // 跳转详细说明
    @objc func descriptionAction() {
        MOJiLogEvent.logEvent(withName: .aiBoard)
        
        MDUIUtils.pushWebSearchVC(withUrl: MOJiAIChatTermsOfUseUrl)
    }
    
}

extension MOJiAIVC: UITableViewDelegate, UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = self.messages[indexPath.row]
        
        if message is DB_AIQuestion {
            let tmpMessage = message as! DB_AIQuestion
            let cell       = tableView.dequeueReusableCell(withIdentifier: MOJiAIQuestionCell.cellIdentifier) as! MOJiAIQuestionCell
            cell.updateCell(tmpQuestin: tmpMessage)
            
            cell.longPressBlcok = { question in
                self.menuItemIndexPath = indexPath
                self.showMenuItem(object: question, cell: cell)
            }
            
            return cell
        } else {
            let tmpMessage = message as! DB_AIAnswer
            
            if tmpMessage.type == MOJiAIAnswerType.word.rawValue {
                let cell = tableView.dequeueReusableCell(withIdentifier: MOJiAIAnswerWordCell.cellIdentifier) as! MOJiAIAnswerWordCell
                cell.updateCell(tmpAnswer: tmpMessage)
                    
                cell.tapWordBlcok = { answer in
                    self.tapToShowWord(answer: answer)
                }
                
                cell.longPressBlcok = { answer in
                    self.menuItemIndexPath = indexPath
                    self.showMenuItem(object: answer, cell: cell)
                }
                
                cell.favBlcok = { answer in
                    self.tapToFavWord(answer: answer)
                }
                
                cell.noteBlcok = { answer in
                    self.tapToAddNote(answer: answer)
                }
                
                cell.playBlcok = { answer in
                    self.tapToPlayWord(answer: answer)
                }
                
                cell.exampleBlcok = { answer in
                    self.tapToShowExample(answer: answer)
                }
                
                cell.verbBlcok = { answer in
                    self.tapToShowVerb(answer: answer)
                }
                
                cell.AIBlcok = { answer in
                    self.tapToFetchAI(answer: answer)
                }
                
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: MOJiAIAnswerGPTCell.cellIdentifier) as! MOJiAIAnswerGPTCell
                cell.updateCell(tmpAnswer: tmpMessage)
                
                cell.longPressBlcok = { answer in
                    self.menuItemIndexPath = indexPath
                    self.showMenuItem(object: answer, cell: cell)
                }
                
                cell.functionBlock = { answer, type in
                    if type == .askOther {
                        self.tapToAskOther(answer: answer)
                    } else {
                        self.tapGPTFunction(answer: answer, type: type)
                    }
                }
                
                return cell
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 400
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // nothing
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFLOAT_MIN
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        lastFooterHeight = MUIPureTools.expectedSize(withText: footerTitle(), font: .systemFont(ofSize: 12), maxWidth: tableView.width - 32).height + 16
        return lastFooterHeight
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view             = UIView()
        view.backgroundColor = .clear
//        view.transform       = CGAffineTransform(scaleX: 1, y: -1)
        
        let label           = UILabel()
        label.textColor     = .color(hexString: "#ACACAC")
        label.font          = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden      = true
        
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
        
        let textView                               = UITextView()
        textView.backgroundColor                   = .clear
        textView.textColor                         = .color(hexString: "#ACACAC")
        textView.textContainerInset                = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isEditable                        = false
        textView.isScrollEnabled                   = false
        textView.delegate                          = self
        
        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalTo(label)
        }
        
        let title          = footerTitle()
        let urlText        = "《内容安全协议》".localized()
        let urlLink        = MOJiUserServiceProtocolPrefix
        let linkRange      = title.ranges(of: urlText, options: .caseInsensitive)
        let attributedText = MDCommonHelper.getAttributedString(byContent: title,
                                                                textAligment: .center,
                                                                lineSpacing: 0,
                                                                font: .systemFont(ofSize: 12),
                                                                color: label.textColor)
        attributedText.addAttribute(.link, value: urlLink, range: linkRange.first ?? NSRange())
        
        label.attributedText    = attributedText
        textView.attributedText = attributedText
        
        return view
    }
    
    func footerTitle() -> String {
        return "请遵守《内容安全协议》，禁止提交违规内容，违规内容会被系统拦截，严重者可能会被注销账号。".localized()
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.homeVc?.hideKeyboard()
    }
}

extension MOJiAIVC: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        let url = URL.absoluteString
        
        if url.hasPrefix(MOJiUserServiceProtocolPrefix) {
            MDUIUtils.pushWebSearchVC(withUrl: MOJiAIContentSecurityUrl)
        }
        
        return false
    }
}

// cell funtion
extension MOJiAIVC {
    
    func questionMenuItem() -> [MOJiMenuItem] {
        let copyItem = MOJiMenuItem.init(title: "复制".localized(), image: UIImage(named: "ic_polish_copy_dark") ?? UIImage(), target: self, action: #selector(copyQuestion))
        let deleteItem = MOJiMenuItem.init(title: "删除".localized(), image: UIImage(named: "edit_icon_del") ?? UIImage(), target: self, action: #selector(deleteQuestion))
        
        return [copyItem, deleteItem]
    }
    
    func answerSimpleMenuItem() -> [MOJiMenuItem] {
        let copyItem = MOJiMenuItem.init(title: "复制".localized(), image: UIImage(named: "ic_polish_copy_dark") ?? UIImage(), target: self, action: #selector(copyWord))
        let deleteItem = MOJiMenuItem.init(title: "删除".localized(), image: UIImage(named: "edit_icon_del") ?? UIImage(), target: self, action: #selector(deleteAnswer))
        
        return [copyItem, deleteItem]
    }
    
    func answerMenuItem() -> [MOJiMenuItem] {
        let copyItem = MOJiMenuItem.init(title: "复制".localized(), image: UIImage(named: "ic_polish_copy_dark") ?? UIImage(), target: self, action: #selector(copyAnswer))
        let againItem = MOJiMenuItem.init(title: "重说".localized(), image: UIImage(named: "ic_common_repeat") ?? UIImage(), target: self, action: #selector(againAnswer))
        let noteItem = MOJiMenuItem.init(title: "笔记".localized(), image: UIImage(named: "ic_common_notes") ?? UIImage(), target: self, action: #selector(noteAnswer))
        let transItem = MOJiMenuItem.init(title: "翻译".localized(), image: UIImage(named: "ic_common_display") ?? UIImage(), target: self, action: #selector(transAnswer))
        let deleteItem = MOJiMenuItem.init(title: "删除".localized(), image: UIImage(named: "edit_icon_del") ?? UIImage(), target: self, action: #selector(deleteAnswer))
        
        return [copyItem, againItem, noteItem, transItem, deleteItem]
    }
    
    @objc func copyQuestion() {
        MOJiLogEvent.logEvent(withName: .aiMenuCopyAsk)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        
        if object is DB_AIQuestion {
            let question = object as! DB_AIQuestion
            
            MDCommonHelper.copyText(question.content)
        }
        
        hideMenuItemSuccessToDo()
    }
    
    @objc func deleteQuestion() {
        MOJiLogEvent.logEvent(withName: .aiMenuDelete)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        guard let indexPath = menuItemIndexPath else { return }
        
        if object is DB_AIQuestion {
            let question = object as! DB_AIQuestion
            
            let objectId = question.objectId
            MDUserDBManager.delete(question)
            
            self.tableV.performBatchUpdates {
                self.messages.remove(at: indexPath.row)
                self.tableV.deleteRows(at: [indexPath], with: .right)
            } completion: { _ in
                self.reloadTableView(toBottom: false)
            }
            
            // 如果这条问题的回答已经删除过了，不需要再次调用接口了，因为是同一个id
            if !question.answerIsTrash.boolValue {
                MOJiAICloudHelper.deleteChat(objectId: objectId) { success, error in
                    // nothing
                }
            }
        }
        
        hideMenuItemSuccessToDo()
    }
    
    @objc func copyWord() {
        MOJiLogEvent.logEvent(withName: .aiMenuCopyAnswer)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        
        if object is DB_AIAnswer {
            let answer = object as! DB_AIAnswer
            
            if answer.objectId == DefaultSystemAIQuestionID {
                MDCommonHelper.copyText(answer.answer)
            } else {
                MDCommonHelper.copyText(answer.title + "\n" + answer.excerpt)
            }
        }
        
        hideMenuItemSuccessToDo()
    }
    
    @objc func copyAnswer() {
        MOJiLogEvent.logEvent(withName: .aiMenuCopyAnswer)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        
        if object is DB_AIAnswer {
            let answer = object as! DB_AIAnswer
            
            MDCommonHelper.copyText(answer.answer)
        }
        
        hideMenuItemSuccessToDo()
    }
    
    @objc func againAnswer() {
        MOJiLogEvent.logEvent(withName: .aiMenuAfreshAnswer)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        guard object is DB_AIAnswer else { return }
        
        let answer = object as! DB_AIAnswer
        
        guard let index = self.messages.firstIndex(of: answer) else { return }
        
        // 是最新的一条，删掉，重新生成, 如果不是最新的一条，重新提问，
        #warning("反向")
//        if index == 0 {
        #warning("正向")
        if index == (self.messages.count - 1) {
            let indexPath = IndexPath(row: index, section: 0)
            
            MDUserDBManager.delete(answer, togetherQuesiton: false)
            
            self.tableV.performBatchUpdates {
                self.messages.remove(at: indexPath.row)
                self.tableV.deleteRows(at: [indexPath], with: .left)
            } completion: { _ in
                self.reloadTableView(toBottom: false)
            }
            
            if let question = MDUserDBManager.aiQuestion(withObjectId: answer.objectId) {
                searchGPT(text: question.content, objectId: answer.objectId, isAskAgain: true)
            }
        } else {
            if let question = MDUserDBManager.aiQuestion(withObjectId: answer.objectId) {
                searchGPT(text: question.content)
            }
        }
        
        hideMenuItemSuccessToDo()
    }
    
    // 回答添加到笔记
    @objc func noteAnswer() {
        MOJiLogEvent.logEvent(withName: .aiMenuNote)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        guard let tmpHomeVC = homeVc else { return }
        
        if object is DB_AIAnswer {
            let answer = object as! DB_AIAnswer
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                let content = "<p>" + answer.answer + "</p>"
                let model   = MOJiPushNoteVCFromAIAddModel.init(content: content)
                MDNoteHelper.shared().presentNoteVC(model, fromVC: tmpHomeVC)
            })
        }
        
        hideMenuItemSuccessToDo()
    }
    
    @objc func transAnswer() {
        MOJiLogEvent.logEvent(withName: .aiMenuTrans)
        hideMenuItem()
        
        guard MDUIUtils.canUseProFunction(with: .translation) else { return }
        
        guard let object = menuItemObject else { return }
        
        if object is DB_AIAnswer {
            let answer = object as! DB_AIAnswer

            let vc             = MOJiTranslationVCSwift()
            vc.view.isHidden   = false
            vc.toTranslateText = answer.answer
            let navVC          = MDBaseNavigationController.init(rootViewController: vc)
            self.homeVc?.navigationController?.present(navVC, animated: true)
        }
        
        hideMenuItemSuccessToDo()
    }
    
    // 删除回答
    @objc func deleteAnswer() {
        MOJiLogEvent.logEvent(withName: .aiMenuDelete)
        hideMenuItem()
        
        guard let object = menuItemObject else { return }
        guard let indexPath = menuItemIndexPath else { return }
        
        if object is DB_AIAnswer {
            let answer = object as! DB_AIAnswer
            
            let objectId = answer.objectId
            MDUserDBManager.delete(answer, togetherQuesiton: true)
            
            self.tableV.performBatchUpdates {
                self.messages.remove(at: indexPath.row)
                self.tableV.deleteRows(at: [indexPath], with: .left)
            } completion: { _ in
                self.reloadTableView(toBottom: false)
            }
            
            // 如果这条问题的回答已经删除过了，不需要再次调用接口了，因为是同一个id
            if let question = MDUserDBManager.aiQuestion(withObjectId: objectId), !question.isTrash.boolValue {
                MOJiAICloudHelper.deleteChat(objectId: objectId) { success, error in
                    // nothing
                }
            }
        }
        
        hideMenuItemSuccessToDo()
    }
    
    // 长按弹出气泡弹窗
    func showMenuItem(object: RLMObject, cell: UITableViewCell) {
        guard !isAnswering else { return }
        
        menuItemObject = object
        
        let menu       = MOJiMenuController.shared()
        menu.menuItems = object is DB_AIQuestion ? questionMenuItem() : answerMenuItem()
        
        if object is DB_AIQuestion {
            menu.menuItems = questionMenuItem()
            
            let tmpCell = cell as! MOJiAIQuestionCell
            let rect    = tmpCell.contentV.convert(tmpCell.contentV.bounds, to: self.tableV)
            menu.setTargetRect(rect, in: self.tableV)
        } else {
            let answer = object as! DB_AIAnswer
            
            // 系统的默认内容，以及单词类型的，只需要复制和删除即可
            if answer.objectId == DefaultSystemAIQuestionID || answer.type == MOJiAIAnswerType.word.rawValue {
                menu.menuItems = answerSimpleMenuItem()
            } else {
                menu.menuItems = answerMenuItem()
            }
            
            if answer.type == MOJiAIAnswerType.word.rawValue {
                let tmpCell = cell as! MOJiAIAnswerWordCell
                let rect    = tmpCell.contentV.convert(tmpCell.contentV.bounds, to: self.tableV)
                menu.setTargetRect(rect, in: self.tableV)
            } else {
                let tmpCell = cell as! MOJiAIAnswerGPTCell // MOJiAIAnswerWordCell没有长按事件
                let rect    = tmpCell.contentV.convert(tmpCell.contentV.bounds, to: self.tableV)
                menu.setTargetRect(rect, in: self.tableV)
            }
        }
        
        menu.setMenuVisible(true, animated: true)
    }
    
    func hideMenuItem() {
        MOJiMenuController.shared().setMenuVisible(false, animated: true)
    }
    
    func hideMenuItemSuccessToDo() {
        menuItemObject    = nil
        menuItemIndexPath = nil
    }
    
    // 点击查看单词
    func tapToShowWord(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordDetail)
        
        if MDStringUtils.isEmptyString(answer.targetId) { return }
        
        MDUIUtils.pushContentDetailVC(withTargetId: answer.targetId, targetType: TargetType(rawValue: answer.targetType) ?? TargetType.word)
    }
    
    // 点击收藏单词
    func tapToFavWord(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordCollect)
        
        if !MDUIUtils.canUseProFunction(with: .favCategory) { return }
        
        let itemInFolder        = ItemInFolder()
        itemInFolder.title      = answer.spell
        itemInFolder.targetId   = answer.targetId
        itemInFolder.targetType = NSNumber(value: answer.targetType)
        MDFavHelper.requestToFavTargetWithItem(itemInFolder)
    }
    
    // 点击添加笔记
    func tapToAddNote(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordNote)
        
        guard let tmpHomeVC = homeVc else { return }
        
        let model = MOJiPushNoteVCFromWordDetailModel(fromTargetId: answer.targetId, fromTargetType: NSNumber(value: answer.targetType))
        MDNoteHelper.shared().presentNoteVC(model, fromVC: tmpHomeVC)
    }
    
    // 点击播放单词
    func tapToPlayWord(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordPronounce)
        
        let targetType = Int(answer.targetType)
        
        if targetType == TargetType.word.rawValue {
            let word      = Wort()
            word.spell    = answer.spell
            word.objectId = answer.targetId
            MDPlayerHelper.playTargetOnce(word)
        } else if targetType == TargetType.example.rawValue {
            let example      = Example()
            example.title    = answer.title
            example.objectId = answer.targetId
            MDPlayerHelper.playTargetOnce(example)
        } else if targetType == TargetType.sentence.rawValue {
            let sentence      = Sentence()
            sentence.title    = answer.title
            sentence.objectId = answer.targetId
            MDPlayerHelper.playTargetOnce(sentence)
        }
    }
    
    // 点击查看例句
    func tapToShowExample(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordExample)
        
        MDUIUtils.presentSearchPopUpVC(withSearchText: answer.spell, sourceType: .AI, searchContentType: .example)
    }
    
    // 点击查看动词活用
    func tapToShowVerb(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordVerbform)
        
        if MDStringUtils.isEmptyString(answer.targetId) { return }
        
        MDUIUtils.pushContentDetailVC(withTargetId: answer.targetId, targetType: TargetType(rawValue: answer.targetType) ?? TargetType.word) { coordinator in
            coordinator.showVerbView()
        }
    }
    
    // 点击AI回答
    func tapToFetchAI(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiWordAiAnswer)
        
        guard let question = MDUserDBManager.aiQuestion(withObjectId: answer.objectId) else { return }
        
        searchGPT(text: question.content)
    }
    
    // 点击功能
    func tapGPTFunction(answer: DB_AIAnswer, type: MOJiAIAnswerGPTType) {
        gptFunctionType = type
        
        guard let question = MDUserDBManager.aiQuestion(withObjectId: answer.objectId) else { return }
        
        let vc    = MOJiAIFunctionSelectWordVC.viewController(originalText: question.content, type: gptFunctionType)
        let navVC = MDBaseNavigationController.init(rootViewController: vc)
        self.homeVc?.navigationController?.present(navVC, animated: true)
//        self.homeVc?.push(vc)
        
//        vc.selectBlock = { [weak self] text in
//            self?.tapGPTFunctionToDoAfterSelectText(text: text)
//        }
    }
    
//    func tapGPTFunctionToDoAfterSelectText(text: String) {
//        if gptFunctionType == .searchWord { // 搜词
//            MOJiLogEvent.logEvent(withName: .aiIntentionWord)
//            MDUIUtils.presentSearchPopUpVC(withSearchText: text, sourceType: .AI)
//        } else if gptFunctionType == .trans { // 翻译
//            MOJiLogEvent.logEvent(withName: .aiIntentionTranslate)
//            if !MDUIUtils.canUseProFunction(with: .translation) { return }
//
//            let vc             = MOJiTranslationVCSwift()
//            vc.view.isHidden   = false
//            vc.toTranslateText = text
//            self.homeVc?.push(vc)
//        } else if gptFunctionType == .analyze { // 分析
//            MOJiLogEvent.logEvent(withName: .aiIntentionAnalyze)
//            if !MDUIUtils.canUseProFunction(with: .wordAnalysis) { return }
//
//            MDUIUtils.pushAnalysisResultVC(withSearchText: text)
//        } else if gptFunctionType == .polish { // AI润色
//            MOJiLogEvent.logEvent(withName: .aiIntentionPolish)
//            let vc = MOJiPolishInputVC(input: text)
//            self.homeVc?.push(vc)
//        }
//    }
    
    // 点击问问船友
    func tapToAskOther(answer: DB_AIAnswer) {
        MOJiLogEvent.logEvent(withName: .aiIntentionQA)
        
        MOJiAICloudHelper.askOther(objectId: answer.objectId) { questionId, error in
            guard let questionId = questionId else { return }
            
            MDUIUtils.pushQAQuestionVC(withQuestionId: questionId)
        }
    }
}
                        
extension MOJiAIVC: JXCategoryListContentViewDelegate {
    func listView() -> UIView! {
        return self.view
    }
}

