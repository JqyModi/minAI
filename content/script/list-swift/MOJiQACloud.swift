//
//  MOJiQACloud.swift
//  MOJiDict
//
//  Created by J.qy on 2023/3/20.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import Foundation

private let setAiAnswerLikeStatus = "aiAnswerStatus"

enum MOJiQACloud {
    /// 问答首页加载更多
    case questionList(tag: String, page: Int, limit: Int)
    /// 问答回答领会员进度
    case rewardPro(doDraw: Bool)
    /// 获取用户问答偏好配置
    case getQaConfig
    /// 更新用户问答配置
    case updateQaConfig(config: MOJiQAConfig)
    /// 查询用户自己的问题列表附带点赞数最多的第一个回答
    case questionListMine(req: MOJiQueListMineRequest)
    /// 每日回答排行
    case answerDailyRank(page: Int, limit: Int)
    /// 我要提问-问题匹配
    case searchCircle(keyw: String, types: [Int])
    /// 我要提问-问题匹配
    case answerList(targetId: String, page: Int, limit: Int)
    
    /// 设置ai回复为有帮助/无帮助
    case setLikeAiAnswer(status: Int, objectId: String)
}

extension MOJiQACloud: MOJiApiType {
    var path: String {
        switch self {
        case .questionList:
            return "question-list"
        case .rewardPro:
            return "activityRewardRecord-answer"
        case .getQaConfig:
            return "userConfig-get-qa"
        case .updateQaConfig:
            return "userConfig-update-qa"
        case .questionListMine:
            return "question-list-mine"
        case .answerDailyRank:
            return "answer-daily-rank"
        case .searchCircle:
            return "search-circle"
        case .answerList:
            return "answer-list"
        case .setLikeAiAnswer:
            return "question-edit"
        }
    }
    
    var params: [String : Any]? {
        switch self {
            case .questionList(let tag, let page, let limit):
                return [MOJiKey.tagKey.rawValue: tag,
                        MOJiKey.pageKey.rawValue: page,
                        MOJiKey.limitKey.rawValue: limit]
            case .answerList(let targetId, let page, let limit):
                return [MOJiKey.targetIdKey.rawValue: targetId,
                        MOJiKey.pageKey.rawValue: page,
                        MOJiKey.limitKey.rawValue: limit]
            case .updateQaConfig(config: let config):
                return [MOJiKey.configKey.rawValue: [MOJiKey.canBeAskedKey.rawValue: config.canBeAsked]]
            case .questionListMine(req: let req):
                return req.toDictionary()
            case .answerDailyRank(let page, let limit):
                return [MOJiKey.pageKey.rawValue: page,
                        MOJiKey.limitKey.rawValue: limit]
            case .rewardPro(let doDraw):
                return [MOJiKey.doDrawKey.rawValue: doDraw]
            case .searchCircle(let keyw, let types):
                return [MOJiKey.keywKey.rawValue: keyw,
                        MOJiKey.typesKey.rawValue: types]
            case .setLikeAiAnswer(let status, let id):
                return [MOJiKey.objectIdKey.rawValue: id,
                               setAiAnswerLikeStatus: status]
            default:
                return [:]
        }
    }
    
    var isAutoToastErrorMsg: Bool {
        true
    }
    
    var cacheExpirationTime: UInt {
        MRCDefaultMemoryCacheExpirationTimeInterval
    }
    
    var errorCodesSpecialHandler: [MOJiApiError] {
        []
    }
}

@objc class MOJiQACloudHelper: NSObject {
    
    /// 消息类型
    @objc enum QAMessageType: NSInteger {
        /// 点赞
        case like
        /// 向我提问
        case askMe
    }
    
    static func getAnswerDailyRank(page: Int = MDDefaultPageIndex,
                                   limit: Int = 10, // 最多显示第10名
                                   needCache: Bool = true,
                                   completion: @escaping RespAnyBlock<AnyObject>) {
        // 判断缓存是否过期
        guard needCache,
              let rankModel = self.getqaRankListResponse(),
                !(self.getQaRankListResponseExpired())
        else {
            MOJiQACloud.answerDailyRank(page: page, limit: limit).requestCustom(MDQARankListModel.self, success: { response in
                SwiftLog.mojiLog(items: #function, "非缓存数据")
                completion(response, nil)
                
                // 缓存数据库，未登录状态下个人主页是从数据库直接读取用户信息
                if let usersDict = response.originalData as? [AnyHashable : Any],
                    let users = NSArray.yy_modelArray(with: DB_User.self,
                                                      json: usersDict["1"] as Any) as? [DB_User] {
                    MDUserDBManager.transaction {
                        MDUserDBManager.add(users)
                    }
                    MDUserDBManager.db().refresh()
                }

            }) { error in
                completion(nil, error)
            }
            return
        }
        
        SwiftLog.mojiLog(items: #function, "缓存数据")
        completion(rankModel, nil)
    }
    
    static func getSearchCircle(keyw: String, types: [Int] = [MOJiTagPickerType.QA.rawValue], completion: @escaping RespBlock<NSArray>) {
        
        MOJiQACloud.searchCircle(keyw: keyw, types: types).requestResult([MDQAMatchModel].self, success: { response in
            completion(response as NSArray, nil)
        }) { error in
            completion(nil, error as NSError)
        }
    }
    
    @objc static func getQueLists(tag: String, page: Int = MDDefaultPageIndex, limit: Int = MDDefaultPageSize, completion: @escaping ((_ response: MOJiDiscoverGetQAListResponse?, _ error: Error?) -> Void)) {
        MOJiQACloud.questionList(tag: tag, page: page, limit: limit).requestCustom(MOJiDiscoverGetQAListResponse.self, success: { response in
            completion(response, nil)
        }) { error in
            completion(nil, error)
        }
    }
    
    @objc static func rewardPro(doDraw: Bool = false, completion: @escaping ((_ response: MOJiFreeMembershipModel?, _ error: Error?) -> Void)) {
        MOJiQACloud.rewardPro(doDraw: doDraw).requestResult(MOJiFreeMembershipModel.self, success: { response in
            completion(response, nil)
        }) { error in
            completion(nil, error)
        }
    }
    
    @objc static func getMineQueLists(req: MOJiQueListMineRequest, completion: @escaping ((_ response: MOJiDiscoverGetQAListResponse?, _ error: Error?) -> Void)) {
        MOJiQACloud.questionListMine(req: req).requestCustom(MOJiDiscoverGetQAListResponse.self, success: { response in
            completion(response, nil)
        }) { error in
            completion(nil, error)
        }
    }
    
    // MODI_MARK: - 红点
    
    class func qaNoticeUnreadNum(result: MOJiInboxReadResult, messageType type: QAMessageType) -> Int {
        let likeNum  = result.getInboxReadCount(with: .like, targetType: .qaAnswer).intValue
        let askMeNum = result.getInboxReadCount(with: .askMe, targetType: .qaQuestion).intValue
        
        var badgeNum = 0
        
        if type == .like {
            badgeNum = likeNum
        } else if type == .askMe {
            badgeNum = askMeNum
        }
        
        SwiftLog.mojiLog(items: "当前更新通知数量：", badgeNum)
        
        return badgeNum
    }
    
    /// 单独清空收到的赞和向我提问
    class func clearMineQANoticeBadge(messageType type: QAMessageType) {
        // 回答被点赞
        let likeItem = MOJiInboxReadItemType()
        likeItem.activityType = NSNumber(value: MOJiActivityType.like.rawValue)
        likeItem.srcTypes = [NSNumber(value: TargetType.qaAnswer.rawValue)]
        
        // 向我提问
        let askItem = MOJiInboxReadItemType()
        askItem.activityType = NSNumber(value: MOJiActivityType.askMe.rawValue)
        askItem.srcTypes = [NSNumber(value: TargetType.qaAnswer.rawValue)]
        
        if type == .like {
            MOJiCommentHelper.clearInboxRead(withDetails: [likeItem])
        } else {
            MOJiCommentHelper.clearInboxRead(withDetails: [askItem])
        }
        
    }

}

// MODI_MARK: - 问答榜缓存3小时
extension MOJiQACloudHelper {
    #if DEBUG
    static let qaRankListCacheTime = 10 // 缓存时间10s
    #else
    static let qaRankListCacheTime = 3600 * 3 // 缓存时间3小时
    #endif
    // MARK: - column
    static func qaRankListRequestParameters() -> [String: Any] {
        let parameters: [String: Any] = [
            MOJiKey.pageKey.rawValue: MDDefaultPageIndex,
            MOJiKey.limitKey.rawValue: MDDefaultPageSize
        ]
        return parameters
    }

    static func getqaRankListResponse() -> MDQARankListModel? {
        guard let result = MCCloud.result(withFunction: MOJiQACloud.answerDailyRank(page: MDDefaultPageIndex, limit: MDDefaultPageSize).path, parameters: MOJiQACloudHelper.qaRankListRequestParameters()) else {
            return nil
        }
        let response = MCRespCache.response(with: MDQARankListModel.self, result: result) as? MDQARankListModel
        return response
    }

    @objc static func getQaRankListResponseExpired() -> Bool {
        return MCCloud.resultExpired(withMemoryCacheExpirationTimeInterval: qaRankListCacheTime as NSNumber, function: MOJiQACloud.answerDailyRank(page: MDDefaultPageIndex, limit: MDDefaultPageSize).path, parameters: MOJiQACloudHelper.qaRankListRequestParameters())
    }
    
    // 更新问答榜缓存
    static func updateCacheForRankList(asked: Bool) {
        // 更新缓存 TODO
        return
        
        // 判断当前用户是否在榜单上
        guard let result = MCCloud.result(withFunction: MOJiQACloud.answerDailyRank(page: MDDefaultPageIndex, limit: MDDefaultPageSize).path, parameters: MOJiQACloudHelper.qaRankListRequestParameters()) else {
            SwiftLog.mojiLog(items: #function, "当前没有缓存数据")
            return
        }
        
        MCCloud.cacheResult(result, withFunction: MOJiQACloud.answerDailyRank(page: MDDefaultPageIndex, limit: MDDefaultPageSize).path, parameters: qaRankListRequestParameters())
    }
}

extension MOJiQACloudHelper {
    /// 获取用户答题领会员记录
    @objc static func loadUserAnswerPro() {
        if MOJiDefaultsManagerSwift.rewardPro {
            return
        }
        
        if !MDUserHelper.isLogin() {
            return
        }
        
        MOJiQACloud.rewardPro(doDraw: false).requestResult(MOJiFreeMembershipModel.self, success: { response in
            SwiftLog.mojiLog(items: #function, "答题领会员记录获取成功")
            MOJiDefaultsManagerSwift.rewardPro = response.isDrew
        }) { error in
            SwiftLog.mojiLog(items: #function, "答题领会员记录获取失败")
        }
    }
}
