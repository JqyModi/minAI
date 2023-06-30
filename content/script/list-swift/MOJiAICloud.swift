//
//  MOJiAICloud.swift
//  MOJiDict
//
//  Created by Ji Xiang on 2023/5/29.
//  Copyright © 2023 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

import Foundation
import HandyJSON

struct MOJiAISearchWordModel: HandyJSON {
    var objectId: String = ""
    var targetId: String = ""
    var targetType: Int  = 0
    var spell: String    = ""
    var title: String    = ""
    var excerpt: String  = ""
    var createdAt: Date  = Date()
    var updatedAt: Date  = Date()
    var hasVerb: Bool    = false
    var isFree: Bool     = false
    
    func changeToAnswer() -> DB_AIAnswer {
        let answer         = DB_AIAnswer()
        answer.objectId    = objectId
        answer.userId      = MDUserHelper.currentUserId()
        answer.createdAt   = createdAt
        answer.updatedAt   = updatedAt
        answer.type        = Int(MOJiAIAnswerType.word.rawValue)
        answer.isTrash     = NSNumber(value: false)
        
        answer.spell      = spell
        answer.title      = title
        answer.excerpt    = excerpt
        answer.targetId   = targetId
        answer.targetType = targetType
        answer.isFree     = NSNumber(value: isFree)
        answer.hasVerb    = NSNumber(value: hasVerb)
        
        return answer
    }
}

struct MOJiAIFetchIntentModel: HandyJSON {
    var intent: [String] = []
}

struct MOJiAIFetchChatModel: HandyJSON {
    var objectId: String     = ""
    var userId: String       = ""
    var type: Int            = 1 // 1-查词，2：GPT，3：查词+GPT
    var content: String      = ""
    var searchResult: String = ""
    var answer: String       = ""
    var isInterrupt: Bool    = false
    var createdAt: String    = ""
    var updatedAt: String    = ""
    var tags: [String]       = [String]()
    var intent: [String]     = [String]()
    var word: MOJiAISearchWordModel?
    
    func changeToQuestion() -> DB_AIQuestion {
        let tmpQuestion           = DB_AIQuestion()
        tmpQuestion.objectId      = objectId
        tmpQuestion.userId        = userId
        tmpQuestion.createdAt     = MDDateUtils.date(with: createdAt, dateFormat: DefaultDateFormatSSSZ) ?? Date()
        tmpQuestion.updatedAt     = MDDateUtils.date(with: updatedAt, dateFormat: DefaultDateFormatSSSZ) ?? Date()
        tmpQuestion.content       = content
        tmpQuestion.isTrash       = NSNumber(value: false)
        tmpQuestion.answerIsTrash = NSNumber(value: false)
        
        return tmpQuestion
    }
    
    func changeToAnswer() -> DB_AIAnswer {
        let tmpAnswer         = DB_AIAnswer()
        tmpAnswer.objectId    = objectId
        tmpAnswer.userId      = userId
        tmpAnswer.createdAt   = MDDateUtils.date(with: createdAt, dateFormat: DefaultDateFormatSSSZ) ?? Date()
        tmpAnswer.updatedAt   = MDDateUtils.date(with: updatedAt, dateFormat: DefaultDateFormatSSSZ) ?? Date()
        tmpAnswer.answer      = answer
        tmpAnswer.type        = type
        tmpAnswer.intent      = intent.joined(separator: "/")
        tmpAnswer.tags        = tags.joined(separator: "/")
        tmpAnswer.isInterrupt = NSNumber(value: isInterrupt)
        tmpAnswer.isTrash     = NSNumber(value: false)
        
        tmpAnswer.spell      = word?.spell ?? ""
        tmpAnswer.title      = word?.title ?? ""
        tmpAnswer.excerpt    = word?.excerpt ?? ""
        tmpAnswer.targetId   = word?.targetId ?? ""
        tmpAnswer.targetType = word?.targetType ?? 0
        tmpAnswer.isFree     = NSNumber(value: word?.isFree ?? false)
        tmpAnswer.hasVerb    = NSNumber(value: word?.hasVerb ?? false)
        
        return tmpAnswer
    }
}

struct MOJiAIAskOtherModel: HandyJSON {
    var questionId: String = ""
}

enum MOJiAICloud {
    /// 聊天提示语
    case fetchTips
    /// 查词
    case searchWord(content: String)
    /// 聊天
    case chat
    /// 聊天意图路由
    case fetchIntent(objectId: String)
    /// 查询聊天历史记录
    case fetchChat(createdAt: Int, isLast: Bool, limit: Int)
    /// 删除聊天记录
    case deleteChat(objectId: String)
    /// 问问船友
    case askOther(objectId: String)
}

extension MOJiAICloud: MOJiApiType {
    
    var path: String {
        switch self {
        case .fetchTips:
            return "aiChat-tip-fetch"
        case .searchWord:
            return "aiChat-searchWord"
        case .chat:
            return "chat/generate"
        case .fetchIntent:
            return "aiChat-intent-fetch"
        case .fetchChat:
            return "aiChat-fetch"
        case .deleteChat:
            return "aiChat-del"
        case .askOther:
            return "aiChat-question-ask"
        }
    }
    
    var params: [String : Any]? {
        switch self {
            case .searchWord(let content):
                return [MOJiKey.contentKey.rawValue: content]
            case .fetchIntent(let objectId):
                return [MOJiKey.objectIdKey.rawValue: objectId]
            case .fetchChat(let createdAt, let isLast, let limit):
                return [MOJiKey.createdAtKey.rawValue: createdAt,
                        MOJiKey.isLastKey.rawValue: isLast,
                        MOJiKey.limitKey.rawValue: limit]
            case .deleteChat(let objectId):
                return [MOJiKey.objectIdKey.rawValue: objectId]
            case .askOther(let objectId):
                return [MOJiKey.objectIdKey.rawValue: objectId]
            default:
                return [:]
        }
    }
    
    var isAutoToastErrorMsg: Bool {
        switch self {
            case .fetchIntent:
                return false
            default:
                return true
        }
    }
    
    var cacheExpirationTime: UInt {
        MRCDefaultMemoryCacheExpirationTimeInterval
    }
    
    var errorCodesSpecialHandler: [MOJiApiError] {
        switch self {
        case .searchWord(_):
            return [.mc_objectNotFound]
        default:
            return []
        }
    }
    
}

@objc class MOJiAICloudHelper: NSObject {
    static func fetchTips(completion: @escaping ((_ arr: [String]?, _ error: Error?) -> Void)) {
        MOJiAICloud.fetchTips.requestResult([String].self) { arr in
            completion(arr, nil)
        } failure: { error in
            completion(nil, error)
        }
    }
    
    static func searchWord(content: String, completion: @escaping ((_ answer: DB_AIAnswer?, _ error: Error?) -> Void)) {
        MOJiAICloud.searchWord(content: content).requestResult(MOJiAISearchWordModel.self) { model in
            
            let answer = model.changeToAnswer()
            
            MDUserDBManager.transaction {
                MDUserDBManager.add([answer])
            }
            MDUserDBManager.db().refresh()
            
            completion(answer, nil)
        } failure: { error in
            completion(nil, error)
        }
    }
   
    static func fetchIntent(objectId: String, completion: @escaping ((_ model: MOJiAIFetchIntentModel?, _ error: Error?) -> Void)) {
        MOJiAICloud.fetchIntent(objectId: objectId).requestResult(MOJiAIFetchIntentModel.self) { model in
            completion(model, nil)
        } failure: { error in
            completion(nil, error)
        }
    }
   
    static func fetchChat(createdAt: Int, isLast: Bool, limit: Int, completion: @escaping ((_ arr: [RLMObject]?, _ error: Error?) -> Void)) {
        
        if !isLast { // 说明是下拉加载历史数据
            var tmpMessage   = [RLMObject]()
            var oldQuestions = [DB_AIQuestion]()
            
            oldQuestions = MDUserDBManager.getOnePageQuestions(from: MDDateUtils.date(withTimestamp: Int64(createdAt)))
            
            if oldQuestions.count >= limit { //如果本地数据库的数据超过了一页，不需要再去请求了。
                
                for i in 0..<oldQuestions.count {
                    let question = oldQuestions[i] as DB_AIQuestion
                    
                    if let answer = MDUserDBManager.aiAnswer(withObjectId: question.objectId) {
                        tmpMessage.append(answer)
                    }

                    if !question.isTrash.boolValue {
                        tmpMessage.append(question)
                    }
                }
                
                completion(tmpMessage, nil)
                
                return // 注意，这里要直接return，不需要再去请求Api了
            }
        }
        
        // 接口返回的数据，最新的在最前边
        MOJiAICloud.fetchChat(createdAt: createdAt, isLast: isLast, limit: limit).requestResult([MOJiAIFetchChatModel].self) { arr in
            
            DispatchQueue.global().async {
                var message   = [RLMObject]()
                var questions = [DB_AIQuestion]()
                var answers   = [DB_AIAnswer]()
               
                for i in 0..<arr.count {
                    let model = arr[i] as MOJiAIFetchChatModel
                   
                    // 一份是存到数据库的，一份是返回给vc处理的，用同一份的话会触发跨线程
                    let question    = model.changeToQuestion()
                    let answer      = model.changeToAnswer()
                    let tmpQuestion = MDDBObjectCopyer.copy(question) ?? DB_AIQuestion()
                    let tmpAnswer   = MDDBObjectCopyer.copy(answer) ?? DB_AIQuestion()
                    
                    message.append(tmpAnswer)
                    message.append(tmpQuestion)
#warning("TODO 反向")
//                    questions.append(question)
//                    answers.append(answer)
#warning("TODO 正向")
                    if isLast {
                        questions.append(question)
                        answers.append(answer)
                    } else {
                        answers.append(answer)
                        questions.append(question)
                    }
                }
                
                /**
                 如果返回的数据量等于一页的，说明本地的数据差了很多， 这时候要删除本地的所有内容
                 isLast == true 不能省略，一定是在增量更新的时候，而不是在下拉获取历史数据的时候
                 */
                if isLast && arr.count >= limit {
                    MDUserDBManager.deleteAllAIQuestionsAIAnswers()
                }
               
                MDUserDBManager.transaction {
                    MDUserDBManager.add(questions)
                    MDUserDBManager.add(answers)
                }
               
                DispatchQueue.main.async {
                    MDUserDBManager.db().refresh()
                    completion(message, nil)
                }
            }
        } failure: { error in
            completion(nil, error)
        }
    }

    static func deleteChat(objectId: String, completion: @escaping ((_ success: Bool?, _ error: Error?) -> Void)) {
        if MDStringUtils.isEmptyString(objectId) { return }
        
        MOJiAICloud.deleteChat(objectId: objectId).requestCodeCorrect {
            completion(true, nil)
        } failure: { error in
            completion(false, error)
        }
    }
    
    static func askOther(objectId: String, completion: @escaping ((_ questionId: String?, _ error: Error?) -> Void)) {
        if MDStringUtils.isEmptyString(objectId) { return }
        
        MOJiAICloud.askOther(objectId: objectId).requestResult(MOJiAIAskOtherModel.self) { model in
            completion(model.questionId, nil)
        } failure: { error in
            completion(nil, error)
        }
    }
}

@objc class MOJiAIHelper: NSObject {
    
    static func defaultSystemAnswer() -> [RLMObject] {
        let answer = DB_AIAnswer.defaultSystem()
        
        return [answer]
    }
}
