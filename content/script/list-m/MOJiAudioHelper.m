//
//  MOJiAudioHelper.m
//  MOJiDict
//
//  Created by Mingzhi on 2020/4/3.
//  Copyright © 2020 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiAudioHelper.h"
#import "MOJiChangeAudioCellModel.h"
#import "MOJiRepeatTime.h"
#import "MDSettingsCellModel.h"
#import "MOJiTtsCloud.h"

@interface MOJiAudioHelper()
@property (nonatomic, strong) NSArray<MOJiVoiceActor *>* jaVoiceActors;
@end

@implementation MOJiAudioHelper

+ (instancetype)sharedHelper {
    static MOJiAudioHelper *helper = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        helper = [[MOJiAudioHelper alloc] init];
    });
    
    return helper;
}

- (void)getJaVoiceActors:(void(^)(NSArray<MOJiVoiceActor *>* voiceActors))completion {
    if (self.jaVoiceActors) {
        completion(self.jaVoiceActors);
        return;
    }
    MOJiVoiceActorsFetchRequest *req = [MOJiVoiceActorsFetchRequest new];
    req.lang = @"ja";
    req.text = [MOJiAudioHelper getRandomJapaneseSentence];
    [MOJiTtsCloud getVoiceActors:req completion:^(MOJiVoiceActorsFetchResponse * _Nonnull response, NSError * _Nonnull error) {
        self.jaVoiceActors =  response.result;
        completion(self.jaVoiceActors);
    }];
}

- (MOJiVoiceActor *)getSelectedJpActor {
    MOJiVoiceActor *actor;
    for (MOJiVoiceActor *model in self.jaVoiceActors) {
        if ([model.voiceId isEqualToString:MOJiDefaultsManager.appSettingsConfig.voiceId]) {
            actor = model;
        }
    }
    if (actor == nil) {
        actor = self.jaVoiceActors.firstObject;
    }
    return actor;
}

+ (NSString *)getRandomJapaneseSentence {
    return @"いつもmojiを使ってくれて、ありがとう！";
//    NSArray *sentences = @[@"どうぞよろしくお願いします。",
//                            @"愛しています。",
//                            @"お邪魔します。",
//                            @"また遊びに来てくださいね。",
//                            @"これで失礼します。",
//                            @"お元気ですか。",
//                            @"ちょっと待ってください。",
//                            @"いただきます。",
//                            @"ごちそうさまでした。",
//                            @"お久しぶりですね。",
//                            @"お陰様で元気です。",
//                            @"お帰りなさい。",
//                            @"いってまいります。",
//                            @"いってらっしゃい。",
//                            @"天気がいいから、散歩しましょう。"];
//
//    int index = arc4random() % sentences.count; // 0 ~ sentences.count-1
//    return sentences[index];
}

+ (NSString *)getRandomEnglishSentence {
    return @"Hello, welcome to Mojisho, we will help you understand Japanese better!";
}

+ (NSString *)getRandomChineseSentence {
    return @"你好，欢迎使用 MOJi";
//    NSArray *sentences = @[@"很高兴认识你。",
//                           @"太阳当空照，花儿对我笑。",
//                           @"期待能为您的学习尽自己的绵薄之力。",
//                           @"不要等待，时机永远不会恰到好处。",
//                           @"读书不是为了雄辩和驳斥，也不是为了轻信和盲从，而是为了思考和权衡。",
//                           @"成功的唯一秘诀是坚持到最后一分钟。",
//                           @"凡事都要脚踏实地去作，不驰于空想，不骛于虚声，而惟以求真的态度作踏实的工夫。",
//                           @"只要朝着一个方向努力，一切都会变得得心应手。",
//                           @"从今日起，做一个幸福的人。",
//                           @"今天很残酷，明天更残酷，后天很美好。"];
//
//    int index = arc4random() % sentences.count; // 0 ~ sentences.count-1
//    return sentences[index];
}

+ (NSDictionary *)getPlayerItemJson {
    NSArray *itemJsons = @[@{
                               MOJiTargetIdKey:@"19895488",
                               MOJiTextKey:@"よろしくお願いします",
                               MOJiTargetTypeKey: @(TargetTypeWord)
                            },
                            @{
                               MOJiTargetIdKey:@"YMDLWweH8F",
                               MOJiTextKey:@"明日、何をすべきかわからない人は不幸である",
                               MOJiTargetTypeKey: @(TargetTypeSentence)},
                            @{
                               MOJiTargetIdKey:@"Oi92ZBdGkN",
                               MOJiTextKey:@"笑顔は敵にも自分にも勝ってる武器だ",
                               MOJiTargetTypeKey: @(TargetTypeSentence)},
                            @{
                               MOJiTargetIdKey:@"S3bYJ0V3uB",
                               MOJiTextKey:@"お前はひとりじゃないんだから、俺がいるんだから、怖がるな",
                               MOJiTargetTypeKey: @(TargetTypeSentence)
                            },
                            @{
                               MOJiTargetIdKey:@"deaobCC063",
                               MOJiTextKey:@"会って、知って、愛して、そして別れていくのが幾多の人間の悲しい物語である",
                               MOJiTargetTypeKey: @(TargetTypeSentence)
                            }];
    
    int index = arc4random() % itemJsons.count;
    return itemJsons[index];
}

+ (MAPPlusPlayerItem *)getPlayerItem {
    return [MDPlayerHelper getPlayerItemWithJson:[MOJiAudioHelper getPlayerItemJson]];
}

+ (void)getAvailableVoiceCellModelsWithCompletion:(void(^)(NSArray<MOJiChangeAudioCellModel *> *models))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *voices        = [[[MAPPlayer alloc] init] currentAvailableVoices];
        NSMutableArray *models = [NSMutableArray array];
        
        for (NSInteger i = 0; i < voices.count; i++) {
            MOJiChangeAudioCellModel *model = [[MOJiChangeAudioCellModel alloc] init];
            
            AVSpeechSynthesisVoice *voice = voices[i];
            model.voice                   = voice;
            model.title                   = [NSString stringWithFormat:@"%@（%@）", voice.name, voice.language];
            [models addObject:model];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(models);
            }
        });
    });
}

+ (nullable AVSpeechSynthesisVoice *)getSelectedEnglishVoice {
    NSString *selectedVoiceId             = MOJiDefaultsManager.appSettingsConfig.ttsVoiceIdInEnglish;
    NSArray<AVSpeechSynthesisVoice *> *voices = [MOJiAudioHelper availableEnglishVoices];
    
    if (!selectedVoiceId && voices.count > 0) {
        selectedVoiceId = voices[0].identifier;
    }
    
    for (NSInteger i = 0; i < voices.count; i++) {
        AVSpeechSynthesisVoice *voice = voices[i];
        
        if (selectedVoiceId && [voice.identifier isEqualToString:selectedVoiceId]) {
            return voice;
        }
    }
    return nil;
}

+ (nullable AVSpeechSynthesisVoice *)getSelectedChineseVoice {
    NSString *ttsVoiceIdInChinese             = MOJiDefaultsManager.appSettingsConfig.ttsVoiceIdInChinese;
    NSArray<AVSpeechSynthesisVoice *> *voices = MOJiAudioHelper.availableChineseVoices;
    
    if (!ttsVoiceIdInChinese && voices.count > 0) {
        ttsVoiceIdInChinese = voices[0].identifier;
    }
    
    for (NSInteger i = 0; i < voices.count; i++) {
        AVSpeechSynthesisVoice *voice = voices[i];
        
        if (ttsVoiceIdInChinese && [voice.identifier isEqualToString:ttsVoiceIdInChinese]) {
            return voice;
        }
    }
    return nil;
}

+ (void)getSelectedChineseVoiceIdentifierWithCompletion:(void(^)(NSString * _Nullable voiceIdentifier))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVSpeechSynthesisVoice *voice = [MOJiAudioHelper getSelectedChineseVoice];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(voice.identifier);
            }
        });
    });
}

+ (NSArray<AVSpeechSynthesisVoice *> *)availableChineseVoices {
    return [[[MAPPlayerCore alloc] init] availableVoices:VoiceTypeChineseWithRelatives];
}



+ (void)getAvailableChineseVoiceCellModelsWithCompletion:(void(^)(NSArray<MOJiChangeAudioCellModel *> *models))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<AVSpeechSynthesisVoice *> *voices          = MOJiAudioHelper.availableChineseVoices;
        AVSpeechSynthesisVoice *selectedChineseVoice       = [MOJiAudioHelper getSelectedChineseVoice];
        NSMutableArray<MOJiChangeAudioCellModel *> *models = NSMutableArray.array;
        
        for (NSInteger i = 0; i < voices.count; i++) {
            AVSpeechSynthesisVoice *voice   = voices[i];
            MOJiChangeAudioCellModel *model = [[MOJiChangeAudioCellModel alloc] init];
            model.voice                     = voice;
            model.title                     = [NSString stringWithFormat:@"%@（%@）", voice.name, voice.language];
        
            if ([selectedChineseVoice.identifier isEqualToString:voice.identifier]) {
                model.selected = YES;
            } else {
                model.selected = NO;
            }
            
            [models addObject:model];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(models);
            }
        });
    });
}

+ (NSArray<AVSpeechSynthesisVoice *> *)availableEnglishVoices {
    NSArray *arr = [[[MAPPlayerCore alloc] init] availableVoices:VoiceTypeUS];
    NSMutableArray *ma;
    if (arr) {
        ma = arr.mutableCopy;
    }
    else {
        ma = [NSMutableArray array];
    }
    return ma;
}

+ (void)getAvailableEnglishVoiceCellModelsWithCompletion:(void(^)(NSArray<MOJiChangeAudioCellModel *> *models))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<AVSpeechSynthesisVoice *> *voices          = MOJiAudioHelper.availableEnglishVoices;
        AVSpeechSynthesisVoice *selectedChineseVoice       = [MOJiAudioHelper getSelectedEnglishVoice];
        NSMutableArray<MOJiChangeAudioCellModel *> *models = NSMutableArray.array;
        
        for (NSInteger i = 0; i < voices.count; i++) {
            AVSpeechSynthesisVoice *voice   = voices[i];
            MOJiChangeAudioCellModel *model = [[MOJiChangeAudioCellModel alloc] init];
            model.voice                     = voice;
            model.title                     = [NSString stringWithFormat:@"%@（%@）", voice.name, voice.language];
        
            if ([selectedChineseVoice.identifier isEqualToString:voice.identifier]) {
                model.selected = YES;
            } else {
                model.selected = NO;
            }
            
            [models addObject:model];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(models);
            }
        });
    });
}



+ (NSArray *)getAudioSettingsCellModels {
    MOJiAppSettingsConfig *config       = [MOJiDefaultsManager appSettingsConfig];
    
    MDSettingsCellModel *jaVoiceModel = MDSettingsCellModel.new;
    jaVoiceModel.title                = NSLocalizedString(@"声优", nil);
    jaVoiceModel.desc                 = NSLocalizedString(@"定制专属语音", nil);
    jaVoiceModel.value                = @"";
    
    
    MDSettingsCellModel *speedModel = MDSettingsCellModel.new;
    speedModel.title                = NSLocalizedString(@"语速", nil);
    speedModel.desc                = NSLocalizedString(@"单词/例句朗读速度", nil); //[NSString stringWithFormat:@"%@：%.2fx", NSLocalizedString(@"朗读速率", nil), (config.ttsSpeed / MOJiTtsSpeedDefaultValue * 1.0f)];
    speedModel.value = [self speedDescWithSpeed:[self speedValueWithTtsSpeed:config.ttsSpeed]];
    speedModel.speed                = config.ttsSpeed;
    
    
    MDSettingsCellModel *autoVoiceModel = MDSettingsCellModel.new;
    autoVoiceModel.title                = NSLocalizedString(@"启动自动发音", nil);
    autoVoiceModel.desc                 = NSLocalizedString(@"展示单词详情页时，自动发音", nil);
    autoVoiceModel.on                   = config.autoPlayAudio;
    
    
    MDSettingsCellModel *repeatModel = MDSettingsCellModel.new;
    repeatModel.title                = NSLocalizedString(@"复读", nil);
    repeatModel.desc                 = NSLocalizedString(@"长按发音按钮可快速设置", nil);
    repeatModel.value                = MOJiAudioHelper.getRepeatSectionSubtitle;
    
    
    NSDictionary *pronunciationModeJson = MOJiAudioHelper.currentPronunciationModeJson;
    MDSettingsCellModel *pronounceModel = MDSettingsCellModel.new;
    pronounceModel.title                = NSLocalizedString(@"发音模式", nil);
    pronounceModel.desc                 = [pronunciationModeJson valueForKey:MOJiSubtitleKey];
    pronounceModel.value                = [pronunciationModeJson valueForKey:MOJiTitleKey];
    
    
    MDSettingsCellModel *cloudVoiceModel = MDSettingsCellModel.new;
    cloudVoiceModel.title                = NSLocalizedString(@"在线朗读", nil);
    cloudVoiceModel.desc                 = NSLocalizedString(@"使用声优朗读文章/翻译", nil);
    cloudVoiceModel.on                   = config.enableTextCloudTts;
    
    return @[jaVoiceModel, speedModel, autoVoiceModel, repeatModel, pronounceModel, cloudVoiceModel];
}

+ (NSArray *)getAudioSettingsCellModelsFowWordListPlay {
    NSDictionary *pronunciationModeJson = MOJiAudioHelper.currentPronunciationModeJson;
    
    MDSettingsCellModel *pronounceModel  = MDSettingsCellModel.new;
    pronounceModel.title                 = NSLocalizedString(@"发音模式", nil);
    pronounceModel.desc                  = [pronunciationModeJson valueForKey:MOJiSubtitleKey];
    pronounceModel.value                 = [pronunciationModeJson valueForKey:MOJiTitleKey];

    MDSettingsCellModel *jaVoiceModel = MDSettingsCellModel.new;
    jaVoiceModel.title                = NSLocalizedString(@"声优", nil);
    jaVoiceModel.desc                 = NSLocalizedString(@"定制专属语音", nil);
    jaVoiceModel.value                = @"";
    
//    MDSettingsCellModel *cnVoiceModel = MDSettingsCellModel.new;
//    cnVoiceModel.title                = NSLocalizedString(@"中文发音", nil);
//    cnVoiceModel.desc                 = NSLocalizedString(@"定制中文解释语音", nil);
//    cnVoiceModel.value                = @"";
    
    return @[pronounceModel, jaVoiceModel];
}

/// MatcherBtn的长按操作
+ (void)matcherBtnLongPressActionWithInfo:(NSDictionary *)info {
    
    NSArray<MOJiActionSheetAction *> *repeatTimeActions = [MOJiAudioHelper getRepeatTimesActionsWithSelectAction:nil];
    
    MOJiActionSheet *sheet  = [MOJiActionSheet actionSheetWithTitle:NSLocalizedString(@"更多", nil)];
    NSMutableArray *actions = [NSMutableArray arrayWithArray:repeatTimeActions];
    
    // 2023-5-29 隐藏入口
//    MOJiActionSheetAction *rectifyAction = [[MOJiActionSheetAction alloc] init];
//    rectifyAction.tag                    = repeatTimeActions.count;
//    rectifyAction.title                  = NSLocalizedString(@"发音纠正", nil);
//    rectifyAction.style                  = MOJiActionSheetActionStyleCheckHidden;
//
//    rectifyAction.handler = ^(MOJiActionSheetAction * _Nonnull action) {
//        [MOJiAudioHelper pushSoundMatchVCWithInfo:info];
//        [[NSNotificationCenter defaultCenter] postNotificationName:MDPlayerStopLoopPlayingNotification object:nil];
//    };
//    [actions addObject:rectifyAction];
    
    [sheet addActions:actions];
    [[MDUIUtils visibleViewController] presentViewController:sheet animated:YES completion:nil];
}

+ (void)pushSoundMatchVCWithInfo:(NSDictionary *)info {
    NSString *text = info[MOJiTextKey];
    
    if (![MDUserHelper isLogin]) {
        [MDUIUtils presentLoginVC];
        return;
    }
        
    if (SharedContentDetailsConfig.shared.disableCloudTtsRectify) {
        [MOJiNotify showWaitingViewFailedWithText:NSLocalizedString(@"云端发音纠正被禁用，请在设置中解禁", nil)];
        return;
    }
    
    if (text.length > 0 && ![KanaConvertor hasKanji:text]) {
        [MOJiNotify showSimpleAlert:NSLocalizedString(@"当前发音纠正只开放『含有漢字』的单词或例句", nil) message:NSLocalizedString(@"谢谢你的理解和支持！", nil)];
        return;
    }
    
    if (MOJiNetworkChecker.shared.netState == NetworkStateNotReachable) {
        [MOJiNotify showWaitingViewFailedWithText:NSLocalizedString(@"无网络连接", nil)];
        return;
    }
    
    if (MAPPlusPlayerRecorder.shared.isSoundMatchVC) return;
    
    NSString *targetId   = info[keyTargetId];
    NSInteger targetType = [info[keyTargetType] integerValue];
    
    [MAPPlusPlayerRecorder.shared setIsSoundMatchVC:YES];
    
    [MOJiNotify showWaitingViewAllowInteractionWithText:NSLocalizedString(Strings_Downloading, nil)];
    
    TtsHitmap *hm = [[TtsHitmap alloc] init];
    hm.tarId      = targetId;
    
    [[HitmapEngine shared] fetchWithHitmap:hm block:^(NSArray<TtsHitmap *> * _Nonnull results) {
        DLog(@"%s > %@", __PRETTY_FUNCTION__, results);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MOJiNotify dismissWaitingView];
            
            SoundMatchVC *matchVC  = [[SoundMatchVC alloc] init];
            matchVC.valueToRectify = info[MOJiTextKey];
            matchVC.identity       = targetId;
            matchVC.tarType        = targetType;
            matchVC.hitmaps        = results;
            
            [MDUIUtils.visibleViewController presentViewController:matchVC animated:YES completion:nil];
        });
    }];
}

+ (NSArray<MOJiRepeatTime *> *)repeatTimes {
    NSMutableArray<MOJiRepeatTime *> *times = NSMutableArray.array;
    MOJiRepeatTimes currentRepeatTimes      = MOJiDefaultsManager.audioRepeatTimes;
    NSArray *repeatTimeAll                  = @[@(MOJiRepeatTimesOne), @(MOJiRepeatTimesTwo), @(MOJiRepeatTimesThree), @(MOJiRepeatTimesUnlimited)];
    
    for (NSInteger i = 0; i < repeatTimeAll.count; i++) {
        MOJiRepeatTime *time        = [[MOJiRepeatTime alloc] init];
        MOJiRepeatTimes repeatTimes = (MOJiRepeatTimes)[repeatTimeAll[i] integerValue];
        time.title                  = repeatTimes == MOJiRepeatTimesUnlimited ? [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"发音", nil), NSLocalizedString(@"无限循环", nil)] : [NSString stringWithFormat:@"%@%@%@",  NSLocalizedString(@"连续", nil), @(repeatTimes), NSLocalizedString(@"次", nil)];
        time.repeatTimes            = repeatTimes;
        
        if (currentRepeatTimes == time.repeatTimes) {
            time.selected = YES;
        } else {
            time.selected = NO;
        }
        [times addObject:time];
    }
    
    return times;
}

+ (NSArray<MOJiActionSheetAction *> *)getSpeedActionsWithSelectAction:(void(^)(MOJiActionSheetAction *action))didSelectAction voiceClickBlock:(void(^)(MOJiActionSheetAction *action))voiceClickBlock {
    NSArray *speeds             = @[[self quickSpeedTitle], [self normalSpeedTitle], [self slowSpeedTitle]];
    NSMutableArray *tempActions = [NSMutableArray array];

    MOJiAppSettingsConfig *config = [MOJiDefaultsManager appSettingsConfig];
    NSString *currentSpeed        = [self speedDescWithSpeed:[self speedValueWithTtsSpeed:config.ttsSpeed]];
    
    for (NSInteger i = 0; i < speeds.count; i++) {
        NSString *speedTitle = speeds[i];
        
        MOJiActionSheetAction *action = [[MOJiActionSheetAction alloc] init];
        action.tag                    = i;
        action.title                  = speedTitle;
        
        if ([currentSpeed isEqualToString:speedTitle]) {
            action.style = MOJiActionSheetActionStyleCheck;
        } else {
            action.style = MOJiActionSheetActionStyleCheckHidden;
        }
        
        action.handler = ^(MOJiActionSheetAction * _Nonnull action) {
            // 记录选中的
            float rate = [MOJiAudioHelper ttsSpeedWithSpeedDesc:action.title];
            SharedMAPConfig.shared.ttsSpeed = rate;
            MOJiDefaultsManager.appSettingsConfig.ttsSpeed = rate;

            if (didSelectAction) {
                didSelectAction(action);
            }
        };
        
        action.rightBtnImgName = @"list_icon_voice";
        action.showRightBtn    = YES;
        action.rightBtnHandler = voiceClickBlock;
        
        [tempActions addObject:action];
    }

    MOJiActionSheetCancelAction *cancelAction = [[MOJiActionSheetCancelAction alloc] init];
    
    [tempActions addObject:cancelAction];
    
    return tempActions;
}

+ (float)speedValueWithTtsSpeed:(float)ttsSpeed {
    float value = ttsSpeed / MOJiTtsSpeedDefaultValue * 1.0f;
    return value;
}

+ (NSString *)speedDescWithSpeed:(float)speed {
    NSString *desc = nil;
    if (speed < 0.9) { // 慢
        desc = [self slowSpeedTitle];
    }
    else if (speed >= 0.9 && speed <= 1.1) { // 中
        desc = [self normalSpeedTitle];
    }
    else { // 快
        desc = [self quickSpeedTitle];
    }
    return desc;
}

+ (float)ttsSpeedWithSpeedDesc:(NSString *)speedDesc {
    float value = 1;
    if ([speedDesc isEqualToString:[self slowSpeedTitle]]) {
        value = 0.8;
    }
    if ([speedDesc isEqualToString:[self quickSpeedTitle]]) {
        value = 1.2;
    }
    return value*MOJiTtsSpeedDefaultValue;
}

+ (NSString *)slowSpeedTitle {
    return NSLocalizedString(@"慢速", nil);
}

+ (NSString *)normalSpeedTitle {
    return NSLocalizedString(@"中速", nil);
}

+ (NSString *)quickSpeedTitle {
    return NSLocalizedString(@"快速", nil);
}

+ (NSArray<MOJiActionSheetAction *> *)getRepeatTimesActionsWithSelectAction:(void(^)(MOJiActionSheetAction *action))didSelectAction {
    @weakify(self)
    
    NSMutableArray *tempActions = [NSMutableArray array];
    NSArray *times              = MOJiAudioHelper.repeatTimes;
    
    for (NSInteger i = 0; i < times.count; i++) {
        MOJiRepeatTime *time          = times[i];
        MOJiActionSheetAction *action = [[MOJiActionSheetAction alloc] init];
        action.tag                    = time.repeatTimes;
        action.title                  = time.title;

        if (time.selected) {
            action.style = MOJiActionSheetActionStyleCheck;
        } else {
            action.style = MOJiActionSheetActionStyleCheckHidden;
        }
        
        action.handler = ^(MOJiActionSheetAction * _Nonnull action) {
            @strongify(self)
            //记录选中的
            [self setupRepeatTimesWithActionSheetActionTag:action.tag];

            if (didSelectAction) {
                didSelectAction(action);
            }
        };
        
        [tempActions addObject:action];
    }

    MOJiActionSheetCancelAction *cancelAction = [[MOJiActionSheetCancelAction alloc] init];
    
    [tempActions addObject:cancelAction];
    
    return tempActions;
}


+ (void)setupRepeatTimesWithActionSheetActionTag:(NSInteger)tag {
    [MOJiDefaultsManager setAudioRepeatTimes:(MOJiRepeatTimes)tag];
    
    //更新全局配置
    SharedMAPConfig.shared.numberOfLoops = tag;
}

+ (NSString *)getRepeatSectionSubtitle {
    if (MOJiDefaultsManager.audioRepeatTimes < 0) {
        return NSLocalizedString(@"无限循环", nil);
    } else if (MOJiDefaultsManager.audioRepeatTimes > 3) { // 【6.10.0】之前的版本可能存在选择 4/5 次的情况，需要兼容
        [MOJiDefaultsManager setAudioRepeatTimes:3];
        //更新全局配置
        SharedMAPConfig.shared.numberOfLoops = 3;
        return [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"发音", nil), @(MOJiDefaultsManager.audioRepeatTimes), NSLocalizedString(@"遍", nil)];
    } else {
        return [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"发音", nil), @(MOJiDefaultsManager.audioRepeatTimes), NSLocalizedString(@"遍", nil)];
    }
}

+ (NSDictionary *)currentPronunciationModeJson {
    NSArray *pronunciationModeJsons = self.pronunciationModeJsons;
    
    for (NSDictionary *json in pronunciationModeJsons) {
        if ([[json valueForKey:MOJiPronunciationModeKey] integerValue] == SharedMAPConfig.shared.pronunciationMode) {
            return json;
        }
    }
    
    return [pronunciationModeJsons firstObject];
}

+ (NSArray<NSDictionary *> *)pronunciationModeJsons {
    return @[@{
                 MOJiTitleKey             : NSLocalizedString(@"主音模式", nil),
                 MOJiSubtitleKey          : NSLocalizedString(@"打断音乐播放、不跟随系统静音", nil),
                 MOJiPronunciationModeKey : @(MAPPronunciationModeDefault),
             },
             @{
                 MOJiTitleKey             : NSLocalizedString(@"混音模式", nil),
                 MOJiSubtitleKey          : NSLocalizedString(@"不影响音乐播放、不跟随系统静音", nil),
                 MOJiPronunciationModeKey : @(MAPPronunciationModeMixWithOthersCanPlayBack),
             },
             @{
                 MOJiTitleKey             : NSLocalizedString(@"混音模式", nil),
                 MOJiSubtitleKey          : NSLocalizedString(@"不影响音乐播放、跟随系统静音", nil),
                 MOJiPronunciationModeKey : @(MAPPronunciationModeMixWithOthers),
             },
             @{
                 MOJiTitleKey             : NSLocalizedString(@"静音模式", nil),
                 MOJiSubtitleKey          : NSLocalizedString(@"全局静音", nil),
                 MOJiPronunciationModeKey : @(MAPPronunciationModeMute),
             }];
}

+ (NSArray<MOJiActionSheetAction *> *)getPronunciationModeActionsWithSelectAction:(void(^)(MOJiActionSheetAction *action))didSelectAction {
    NSArray *pronunciationModeJsons                  = self.pronunciationModeJsons;
    NSMutableArray<MOJiActionSheetAction *> *actions = NSMutableArray.array;
    
    for (NSInteger i = 0; i < pronunciationModeJsons.count; i++) {
        NSDictionary *json            = pronunciationModeJsons[i];
        MAPPronunciationMode mode     = (MAPPronunciationMode)[[json valueForKey:MOJiPronunciationModeKey] integerValue];
        MOJiActionSheetAction *action = [[MOJiActionSheetAction alloc] init];
        
        action.title    = [json valueForKey:MOJiTitleKey];
        action.subtitle = [json valueForKey:MOJiSubtitleKey];
        action.style    = MOJiActionSheetActionStyleTitleSubtitleAndLeftCheck;
        action.tag      = mode;
        action.selected = (SharedMAPConfig.shared.pronunciationMode == mode);
        action.handler  = ^(MOJiActionSheetAction * _Nonnull action) {
            [MDConfigHelper setupPlayerPronunciationMode:action.tag];

            if (didSelectAction) {
                didSelectAction(action);
            }
        };
        
        [actions addObject:action];
    }
    
    [actions addObject:MOJiActionSheetCancelAction.new];
    
    return actions;
}

+ (void)getAudioVoiceIdsWithCompletion:(void(^)(MDFetchTtsVoiceIdsResponse *response, NSError *error))completion {
    [MDCommonCloud fetchTtsVoiceIdsWithCompletion:^(MDFetchTtsVoiceIdsResponse * _Nonnull response, NSError * _Nonnull error) {
        if (response.isOK) {
            [MOJiDefaultsManager setTtsVoicesInfo:[response.originalData valueForKey:MOJiResultKey]];
            
            /*
                调整男女声，防止服务器端将男声或者女声比较优质的往前调整
                如果开头为f，说明当前用户选择的是女声
             */
            if ([MAPPlusPlayer.shared.voiceId hasPrefix:@"f"]) {
                [MDConfigHelper setupVoiceId:MOJiAudioHelper.femaleVoiceId];
            } else {
                [MDConfigHelper setupVoiceId:MOJiAudioHelper.maleVoiceId];
            }
        }
        
        if (completion) {
            completion(response, error);
        }
    }];
}

+ (NSString *)femaleVoiceId {
    NSArray<NSDictionary *> *femaleArray = [MOJiDefaultsManager.ttsVoicesInfo valueForKey:MOJiFemaleKey];
    NSDictionary *firstFemaleInfo        = femaleArray.firstObject;
    NSString *femaleVoiceId              = [firstFemaleInfo valueForKey:MOJiVoiceIdKey];
    
    return (femaleVoiceId ?: MAPCloudFileDefaultFemaleVoiceId);
}

+ (NSString *)maleVoiceId {
    NSArray<NSDictionary *> *maleArray = [MOJiDefaultsManager.ttsVoicesInfo valueForKey:MOJiMaleKey];
    NSDictionary *firstMaleInfo        = maleArray.firstObject;
    NSString *maleVoiceId              = [firstMaleInfo valueForKey:MOJiVoiceIdKey];
    
    return (maleVoiceId ?: MAPCloudFileDefaultMaleVoiceId);
}

/*
 ttsVoicesInfo = {
     "female": [
         {
             "voiceId": "f000",
             "name": "Wavenet-A"
         },
         {
             "voiceId": "f001",
             "name": "Wavenet-B"
         }
     ],
     "male": [
         {
             "voiceId": "m000",
             "name": "Wavenet-C"
         }
     ]
 }

 */



+ (NSString *)ttsPath {
    NSString *docDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    //【说明】
    // 在使用OSS方法下载的时候，只判断oss-files目录是否存在，在下载的时候会根据完整路径自动创建目录
    // 这里跟OSS的下载方法做区分，参考ossObjectIdWithTargetType在OSS框架中的写法。路径整体是一样的。
    NSString *ttsPath = [docDirPath stringByAppendingPathComponent:@"oss-files/ja-demo"];
    return ttsPath;
}


+ (void)getJaDemoMp3FilePathWithActor:(MOJiVoiceActor *)actor completion:(void(^)(NSString *path))completion {
    if (!actor) {
        completion(nil);
        return;
    }
    // 下载 然后 播放
    NSString *path = [MOJiAudioHelper getJaDemoMp3FilePath:actor.voiceId];
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (isExist) {
        completion(path);
    }
    else {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:actor.url]];
            [data writeToFile:path atomically:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(path);
            });
        });
    }
}

+ (NSString *)getJaDemoMp3FilePath:(NSString *)voiceId {
    [MOJiAudioHelper createTtsFolderWithTtsPath:[MOJiAudioHelper ttsPath]];
    return [[self ttsPath] stringByAppendingFormat:@"/%@.mp3", voiceId];
}

+ (void)createTtsFolderWithTtsPath:(NSString *)ttsPath {
    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [[NSFileManager defaultManager] fileExistsAtPath:ttsPath isDirectory:&isDir];
    
    //如果您为withIntermediateDirectories传递"NO"，则在进行此调用时目录必须不存在。
    //为withIntermediateDirectories传递"YES"，将创建任何必要的中间目录
    if (!(isDir && existed)) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:ttsPath withIntermediateDirectories:YES attributes:nil error:&error];
        DLog(@"%s > create ttsPath folder %@", __func__, error ? error.localizedDescription : @"succeeded!");
        DLog(@"%s > filePath %@", __func__, ttsPath);
    }
}

@end
