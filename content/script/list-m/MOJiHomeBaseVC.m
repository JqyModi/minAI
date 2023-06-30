//
//  MOJiHomeBaseVC.m
//  MOJiDict
//
//  Created by 徐志勇 on 2022/10/25.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiHomeBaseVC.h"
#import "MOJiMeVC.h"
#import "MOJiFavVC.h"
#import "UITabBar+MOJiExtension.h"
#import "MDSettingsVC.h"
#import "MOJiAudioHelper.h"
#import "MOJiPlayerContainerView.h"
#import "MOJiHomePageType.h"

@interface MOJiHomeBaseVC () <MFKCoreDelegate, MOJiInterstitialAdVCDelegate, UIApplicationDelegate>
//@property (nonatomic, strong) NSArray<MOJiTabBarButtonItem *> *tabBarButtonItems;
//@property (nonatomic, strong) NSMutableArray<MOJiTabBarButton *> *tabBarButtons;
//@property (nonatomic, strong) MOJiTabBarButton *selectedTabBarButton;

@property (nonatomic, strong) MDButton *noticeBtn;
@property (nonatomic, strong) UILabel *numberL;
@property (nonatomic, assign) BOOL hadLoadedCtrl;
@property (nonatomic, strong) NSArray *interceptedVCs;
@property (nonatomic, strong) NSArray *interceptedWordListPlayingVCs;

@property (nonatomic, strong) UIButton *successfullyInvitedBgV;
@property (nonatomic, strong) MDButton *examineBtn;
@property (nonatomic, strong) UIButton *successfullyInvitedV;
@end

@implementation MOJiHomeBaseVC

#pragma mark - life cycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [MDConfigHelper updateSharedContentDetailsConfig];
    [self initialize];
    [self configViews];
    
    if (@available(iOS 14.0, *)) { [MOJiWidgetManager.shared reloadAllTimelines]; }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.hadLoadedCtrl) {
        return;
    }
    
    [self viewDidAppearToDo];
    
    self.hadLoadedCtrl = YES;
}

- (void)viewDidAppearToDo {
    //每次启动都更新一下
    if (MDUserHelper.isLogin) { [MDUserHelper updateUserContext]; }
    
    [self fetchData];
    
    //每次启动都要更新用户的登录信息(async)
    [MOJiDefaultsManager updateActionExtensionUserLoginInfo];
    
    //如果已经预热了db，那么就不需要再预热，除非coreDB更新了（会在coreDB更新代码段初始化coreDBHadPreheat标识）
    [self preheatDB];
    
    /*
        特别注意：
     
        6.18.0+不再使用自动登录操作
     */
//    [MOJiAutoLogin autoLogin];
    
#ifdef DEBUG

    //尝试开启监视器（监视：CPU、Memory、FPS等数据）
    [MOJiMonitor tryToStartMonitoring];

#else

#endif
}

- (void)preheatDB {
    if (!MOJiDefaultsManager.coreDBHadPreheat) {
        [MOJiNotify showWaitingViewWithText:NSLocalizedString(@"数据预热中，请稍后...", nil)];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            //Realm预热，防止卡进程（约2-5s）
            [[DBHandler shared] dbWithName:MD_CORE_DB_NAME];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MOJiDefaultsManager setupCoreDBHadPreheat:YES];
                [MOJiNotify dismissWaitingView];
            });
        });
    }
}

#pragma mark 监听横竖屏 及时刷新tabBar的布局
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    
    [MOJiSearchFloatTouchHelper updateSearchFloatTouchPosition];
}

#pragma mark - events

- (void)initialize {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginToDo:) name:LoginSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutToDo) name:LogoutSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signUpToDo:) name:SignUpSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutToDo) name:MDInvalidSessionTokenErrorToLogoutSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invalidSessionTokenErrorToLogout) name:MDInvalidSessionTokenErrorToLogoutSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invalidSessionTokenErrorToLogout) name:PFInvalidSessionTokenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeStyleDidChange) name:MOJiThemeStyleDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontStyleDidChange) name:MOJiFontStyleDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bindAccountSuccessToDo) name:MDBindAccountSuccessNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didTapMatcherButton) name:MCDVDidTapMatcherButtonNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(matcherButtonLongPress:) name:MCDVDidLongPressMatcherButtonNotification object:nil];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inboxReadDidUpdate:) name:MOJiInboxReadDidUpdateNotification object:nil];
    
    // app从后台进入前台都会调用这个方法
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestToInboxRead) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [self setupUIAppearance];
    
    MFKCore.shared.delegate = self;
    
    [self requestToInboxRead];
    [self clearAllOldWordListPlayRecord];
}

// 请求红点
- (void)requestToInboxRead {
    [MOJiCommentHelper inboxReadWithCompletion:nil];
    [MOJiWordListHelper getWordListUnreadCountWithCompletion:nil];
    [self loadSuccessfullyInvitedNotice];
}

//#warning xuzy 去掉
//- (void)inboxReadDidUpdate:(NSNotification *)notification {
//    NSDictionary *userInfo      = (NSDictionary *)notification.userInfo;
//    MOJiInboxReadResult *result = userInfo[MOJiInboxReadResultKey];
//
//    NSInteger commentedNum = result.commentedNum;
//    NSInteger answeredNum  = result.answeredNum;
//    NSInteger totalNotice  = commentedNum + answeredNum;
//
//    MOJiTabBarButton *tabBar = self.tabBarButtons.lastObject;
//    tabBar.badgeV.hidden     = !(totalNotice > 0);
//
//    if ((commentedNum > 0) && (answeredNum > 0)) {
//        self.numberL.text = [NSString stringWithFormat:@"%@%@", @(totalNotice), NSLocalizedString(@"条通知待查看", nil)];
//        [self showNoticeBtnNum:totalNotice];
//    } else if (commentedNum > 0) {
//        self.numberL.text = [NSString stringWithFormat:@"%@%@", @(commentedNum), NSLocalizedString(@"条新评论", nil)];
//        [self showNoticeBtnNum:commentedNum];
//    } else if (answeredNum > 0) {
//        self.numberL.text = [NSString stringWithFormat:@"%@%@", @(answeredNum),  NSLocalizedString(@"条新回答", nil)];
//        [self showNoticeBtnNum:answeredNum];
//    }
//}

- (void)showNoticeBtnNum:(NSInteger)num {
    NSUserDefaults *contentOffsetInfo = [NSUserDefaults standardUserDefaults];
    
    NSInteger oldNum = [contentOffsetInfo floatForKey:[NSString stringWithFormat:@"%@%@", MOJiUser.currentUser.objectId, MOJiNoteKey]];
    
    if (num == oldNum) {
        return;
    }
    
    [contentOffsetInfo setInteger:num forKey:[NSString stringWithFormat:@"%@%@", MOJiUser.currentUser.objectId, MOJiNoteKey]];
    [contentOffsetInfo synchronize];
    
    [self.noticeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view).offset(52);
        make.centerX.mas_equalTo(self.view);
        make.height.mas_equalTo(40);
    }];
    
    [UIView animateWithDuration:0.5f animations:^{
        [self.view layoutIfNeeded];
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hiddenNoticeBtn];
    });
}

- (void)hiddenNoticeBtn {
    [self.noticeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view).offset(-52);
        make.centerX.mas_equalTo(self.view);
        make.height.mas_equalTo(40);
    }];
    
    [UIView animateWithDuration:0.5f animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)matcherButtonLongPress:(NSNotification *)notification {
    NSDictionary *audioInfo = (NSDictionary *)notification.userInfo;
    [MOJiAudioHelper matcherBtnLongPressActionWithInfo:audioInfo];
}

- (void)bindAccountSuccessToDo {
    [MOJiUser.currentUser fetchInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                //1.更新最近登录的用户昵称跟头像到本地
                NSString *username = MOJiUser.currentUser.nickName.length > 0 ? MOJiUser.currentUser.nickName : MOJiUser.currentUser.email;
                
                [MOJiAutoLogin updateUsernameWhenUserDidUpdateUsername:username completion:^{
                    //2.发送广播告知我的界面、账户中心界面更新用户昵称或者头像
                    [NSNotificationCenter.defaultCenter postNotificationName:MOJiUpdateUserInfoNotification object:nil];
                }];
            }
        });
    }];
}

/*
    说明：
 
    由于MatcherButton播放语音时不会影响其他APP播放（混合），其采用了AVAudioSessionCategoryAmbient类型，但是该模式在静音时不会发音，所以才有了下面的弹窗提示）
 */
- (void)didTapMatcherButton {
    if (MOJiDefaultsManager.hadToldUserHowToTurnOffMuteMode) return;
    
    MOJiAlertViewAction *know = [MOJiAlertViewAction actionWithTitle:NSLocalizedString(@"知道啦", nil) titleColor:[MOJiAlertView alertViewButtonRedColor] handler:^(MOJiAlertViewAction * _Nonnull action) {
        [MOJiDefaultsManager setHadToldUserHowToTurnOffMuteMode];
    }];
    MOJiAlertView *alertV = [MOJiAlertView alertViewWithTitle:NSLocalizedString(@"可以在“我的” > “语音”设置中修改发音模式", nil) message:nil actions:@[know]];
    [self presentViewController:alertV animated:YES completion:nil];
}

- (void)themeStyleDidChange {
    //1.单词/例句/网页详情界面主题配置
    SharedContentDetailsConfig.shared.isDarkTheme = MOJiThemeManager.isDarkMode;
    
    //配置MOJiUI相关参数
    MUIConfig.shared.themeStyle                = MOJiThemeManager.themeStyle;
    MUIConfig.shared.themeBackgroundImage      = MOJiThemeManager.sharedManager.backgroundImage;
    MUIConfig.shared.themeBackgroundImageAlpha = MOJiThemeManager.sharedManager.backgroundImageAlpha;
}

- (void)fontStyleDidChange {
    //更新单词详情里面的字体
    SharedContentDetailsConfig.shared.wordKanaFont            = [MOJiFontManager fontWithName:MOJiThemeWordKanaFont weight:UIFontWeightRegular size:16];
    SharedContentDetailsConfig.shared.wordTypeFont            = [MOJiFontManager fontWithName:MOJiThemeWordTypeFont weight:UIFontWeightRegular size:16];
    SharedContentDetailsConfig.shared.wordDetailsMeaningFont  = [MOJiFontManager fontWithName:MOJiThemeWordDetailsMeaningFont weight:UIFontWeightRegular size:16];
    SharedContentDetailsConfig.shared.wordDetailsSentenceFont = [MOJiFontManager fontWithName:MOJiThemeWordDetailsSentenceFont weight:UIFontWeightRegular size:16];
    SharedContentDetailsConfig.shared.titleFont               = MOJiFontManager.themeListTitleFont;
    SharedContentDetailsConfig.shared.subtitleFont            = MOJiFontManager.themeListSubtitleFont;
}

- (void)setupUIAppearance {
    UITextField.appearance.tintColor = UIColorFromHEX(0xFF5252);
    UITextView.appearance.tintColor  = UIColorFromHEX(0xFF5252);
    WKWebView.appearance.tintColor   = UIColorFromHEX(0xFF5252);
    UISwitch.appearance.onTintColor  = UIColorFromHEX(0xFF5252);
    
    // 解决iOS 15新特性产生的问题
    if (@available(iOS 15.0, *)) {
        UITableView.appearance.sectionHeaderTopPadding = 0;
    }
    
}

- (void)invalidSessionTokenErrorToLogout {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(innerInvalidSessionTokenErrorToLogout) object:nil];
    [self performSelector:@selector(innerInvalidSessionTokenErrorToLogout) withObject:nil afterDelay:0.25];
}

- (void)innerInvalidSessionTokenErrorToLogout {
    /*
        弹出loginVC条件：
        1.user存在（token过期说明是能确定这个用户的，所以这个可以不用考虑）;
        2.强制登出成功
        3.loginVC没有弹出

        另外：为避免从后台切入前台时调用的接口导致token失效广播触发的重复操作，这里去重操作。
    */
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isProcessingSessionExpirationEvent) { return; }
        
        self.isProcessingSessionExpirationEvent = YES;
        
        @weakify(self)
        [MDUserHelper logOutWithCompletion:^(NSError * _Nonnull error) {
            [MDUserHelper invalidSessionTokenErrorAndTryToPresentLoginVCWithCompletion:^{
               @strongify(self)
                
                self.isProcessingSessionExpirationEvent = NO;
            }];
        }];
        
        [self innerLogoutToDo];
    });
}

- (void)innerLogoutToDo {
    //当st过期后，需要清掉因为OpenUrl而存储的SesTok数据
    [MDUrlHelper clearSestok];
    
    // clear memory cache
    [MOJiCloudManager clearData];
    
    [MOJiDBManager purifyDBs];
    [MDUserDBManager setup];    //里面注册的是Guest用户DB
    
    //更新内容详情配置信息
    [MDConfigHelper updateSharedContentDetailsConfig];
    
    [MOJiDefaultsManager clearActionExtensionUserLoginInfo];
    
    //清除相关播放器配置
    [MDPlayerHelper clearConfig];
    [self removeWordListPlayingView];
    
    //复习配置更新
    [MOJiTestHelper configReviewEngine];
    
//    MOJiTabBarButton *tabBarButton = self.tabBarButtons.lastObject;
//    tabBarButton.badgeV.hidden     = YES;
}

- (void)setupDeviceToken {
    // 获取用户授权状态 绑定DeviceToken
    [AlarmsManager requestAuthorizationWithCompletion:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MOJiPushCorrelationHelper bindDeviceTokenWithDeviceToken:[MOJiDefaultsManager getDeviceTokenStr] allowedToPush:granted completion:nil];
        });
    }];
}

- (void)signUpToDo:(NSNotification *)notification {
    [self innerLoginToDo:notification.userInfo];
    
    // PS:upload user avatar which is in userInfo object
    if ([notification.userInfo.allKeys containsObject:MOJiAvatarKey]) {
        UIImage *avatar = [notification.userInfo objectForKey:MOJiAvatarKey];
        
        [MDUserHelper uploadAvatarWhenDidFinishRegistering:avatar completion:^(BOOL result) {
            if (result) {
                [[NSNotificationCenter defaultCenter] postNotificationName:MDUploadAvatarSuccessFromSigningUpNotification object:nil];
            }
        }];
    }
    
    // 获取用户授权状态 绑定DeviceToken
    [self setupDeviceToken];
}

- (void)loginToDo:(NSNotification *)notification {
    [self innerLoginToDo:notification.userInfo];
    
    //登录成功后也需要更新当前用户信息
    [self fetchUserInfo];
    
    //登录成功刷新通知数量
    [MOJiCommentHelper inboxReadWithCompletion:nil];
    
    [MOJiWordListHelper getWordListUnreadCountWithCompletion:nil];

    [self loadSuccessfullyInvitedNotice];
    
    // 获取用户授权状态 绑定DeviceToken
    [self setupDeviceToken];
}

- (void)innerLoginToDo:(NSDictionary *)loginData {
    [MFKVerifier.shared updateFKedInfo:^(VerifyReceiptState state) {
        NSLog(@"MFKVerifier status : %@", @(state));
        SharedContentDetailsConfig.shared.isPro = MDUserHelper.didPurchaseMOJiProducts;
    }];
    
    [MDUserHelper updateUserContext];// 更新用户上下文,用户登录或者语言切换需要操作这个
    //重新登录也要setup(update 用户数据库)
    [MDUserDBManager setup];
    
    //更新内容详情配置信息
    [MDConfigHelper updateSharedContentDetailsConfig];
    
    //每次登录成功，都更新action的用户登录信息
    [MOJiDefaultsManager updateActionExtensionUserLoginInfo];
    
    //播放器配置
    [MDPlayerHelper setup];
    //设置一下底部的播放控件
    [self configWordListPlayAfterLogin];
    
    //登录信息保存到keychain（第三方账户登录令牌或MOJi账户登录信息）
    [self saveLoginData:loginData];
    
    //复习配置更新
    [MOJiTestHelper configReviewEngine];
}

- (void)configWordListPlayAfterLogin {
    [self clearAllOldWordListPlayRecord];
    
    [self addWordListPlayingView];
    [self.wordListPlayingV reloadData];
    // 刚登录完因为该方法中，的currentVC会显示为登录页面的vc，所以需要延迟一下处理
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MDPlayerHelper showOrHideWordListPlayingView];
    });
}

- (void)clearAllOldWordListPlayRecord {
    // 6.29.0+ 词单播放更新时添加，清空之前的那些播放记录
    if (![MOJiDefaultsManager hadClearOldAllWordListPlayRecord]) {
        [MOJiDefaultsManager setHadClearOldAllWordListPlayRecord];
        
        [MDUserDBManager clearAllPlayRecords];
    }
}

- (void)saveLoginData:(NSDictionary *)loginData {
    NSString *pwd          = loginData[MOJiPasswdKey];
    BOOL shouldTransferPwd = pwd && !loginData[MOJiPasswordKey];
    
    if (shouldTransferPwd) {
        // passwd -> password
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:loginData];
        dic[MOJiPasswordKey]     = pwd;
        [MOJiAutoLogin saveLoginData:dic completion:nil];
    } else {
        //登录信息保存到keychain（第三方账户登录令牌或MOJi账户登录信息）
        [MOJiAutoLogin saveLoginData:loginData completion:nil];
    }
}

/// 退出登录 清除收藏数据
- (void)resetFavVC {

}

- (void)logoutToDo {
    //clear cache after logout
    [self resetFavVC];
    
    [self innerLogoutToDo];
    
    // 获取用户授权状态 绑定DeviceToken
    [self setupDeviceToken];
    
    // 移除本地推送
    [UNUserNotificationCenter.currentNotificationCenter removeAllPendingNotificationRequests];
}

- (void)configViews {
    [self addNotice];
    
    [self addPlayerContainerView];
    [self addWordListPlayingView];
}

- (void)addPlayerContainerView {
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.playerContainerView.superview != nil) {
        return;
    }
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate.window addSubview:self.playerContainerView];
    
    [self.playerContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(appDelegate.window.mas_bottom);
        make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
        make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
    }];
    
    [appDelegate.window bringSubviewToFront:self.playerContainerView];
}

- (void)addWordListPlayingView {
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.wordListPlayingV.superview != nil) {
        return;
    }
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate.window addSubview:self.wordListPlayingV];
    
    [self.wordListPlayingV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(appDelegate.window.mas_bottom);
        make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
        make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
    }];
    
    [appDelegate.window bringSubviewToFront:self.wordListPlayingV];
}

- (void)removeWordListPlayingView {
    [self.wordListPlayingV removeFromSuperview];
    self.wordListPlayingV = nil;
}

- (void)loadSuccessfullyInvitedNotice {
    @weakify(self)
    [MOJiWordListHelper getRewardDaysWithCompletion:^(MOJiFetchRewardNumResponse * _Nonnull response, NSError * _Nonnull error) {
        @strongify(self)
        
        if (response.isOK) {
            // 每次调用都会清零。所以返回大于零就显示
            if (response.result.rewardedDays > 0) {
                [self addSuccessfullyInvitedNotice];
                [self.view endEditing:YES];
            }
        }
    }];
}

#pragma mark 添加成功邀请通知
- (void)addSuccessfullyInvitedNotice {
    self.successfullyInvitedBgV                 = [[UIButton alloc] init];
    self.successfullyInvitedBgV.backgroundColor = UIColor.clearColor;
    [self.successfullyInvitedBgV addTarget:self action:@selector(removeSuccessfullyInvitedBgV) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.successfullyInvitedBgV];
    [self.successfullyInvitedBgV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    self.successfullyInvitedV                 = [[UIButton alloc] init];
    self.successfullyInvitedV.backgroundColor = UIColor.clearColor;
    self.successfullyInvitedV.contentMode     = UIViewContentModeScaleAspectFill;
    [self.successfullyInvitedV setImage:[UIImage imageNamed:@"ic_successfullyInvited_image"] forState:UIControlStateNormal];
    [self.successfullyInvitedV setImage:[UIImage imageNamed:@"ic_successfullyInvited_image"] forState:UIControlStateHighlighted];
    [self.successfullyInvitedV addTarget:self action:@selector(examineBtnEvent) forControlEvents:UIControlEventTouchUpInside];
    [self.successfullyInvitedBgV addSubview:self.successfullyInvitedV];
    [self.successfullyInvitedV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideLeft).offset(10);
        make.right.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideRight).offset(-1);
        make.top.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideTop).offset(100);
        make.bottom.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideBottom).offset(-154);
    }];
    
    self.examineBtn                    = [[MDButton alloc] init];
    self.examineBtn.layer.cornerRadius = 24;
    self.examineBtn.backgroundColor    = UIColorFromHEX(0xFF5252);
    self.examineBtn.followTouchPoint   = YES;
    self.examineBtn.titleLabel.font    = MediumFontSize(18);
    self.examineBtn.highlightColor     = [UIColor colorWithWhite:1 alpha:0.5];
    [self.examineBtn setTitle:NSLocalizedString(@"查看", nil) forState:UIControlStateNormal];
    [self.examineBtn setTitleColor:UIColorFromHEX(0xFAFAFA) forState:UIControlStateNormal];
    [self.examineBtn addTarget:self action:@selector(examineBtnEvent) forControlEvents:UIControlEventTouchUpInside];
    [self.successfullyInvitedBgV addSubview:self.examineBtn];
    [self.examineBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideLeft).offset(48);
        make.right.mas_equalTo(self.successfullyInvitedBgV.mas_safeAreaLayoutGuideRight).offset(-48);
        make.top.mas_equalTo(self.successfullyInvitedV.mas_bottom).offset(8);
        make.height.mas_offset(48);
    }];
}

- (void)removeSuccessfullyInvitedBgV {
    [self.successfullyInvitedBgV removeFromSuperview];
    [self.successfullyInvitedV removeFromSuperview];
    [self.examineBtn removeFromSuperview];
    
    self.successfullyInvitedBgV = nil;
    self.successfullyInvitedV   = nil;
    self.examineBtn             = nil;
}

- (void)examineBtnEvent {
    [MOJiLogEvent logEventWithName:MOJiLogEventNamePopupGetMember];
    
    [self removeSuccessfullyInvitedBgV];
    
    [MDUIUtils pushInviteFriendVC];
}

#pragma mark 添加消息推送通知
- (void)addNotice {
    self.noticeBtn                         = [[MDButton alloc] init];
    self.noticeBtn.highlightColor          = [UIColor clearColor];
    self.noticeBtn.theme_backgroundColor   = MOJiNoticeBarBgColor;
    self.noticeBtn.layer.cornerRadius      = 20;
    self.noticeBtn.layer.theme_borderColor = MOJiFollowButtonLayerBorderColor;
    self.noticeBtn.layer.borderWidth       = 0.5;
    [self.noticeBtn addTarget:self action:@selector(noticeBtnEvent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.noticeBtn];
    [self.noticeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view).offset(-52);
        make.centerX.mas_equalTo(self.view);
        make.height.mas_equalTo(40);
    }];
    
    UIImageView *noticeImage = [[UIImageView alloc] init];
    noticeImage.theme_image  = @"ic_info_ring";
    [self.noticeBtn addSubview:noticeImage];
    [noticeImage mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.noticeBtn).offset(18);
        make.centerY.mas_equalTo(self.noticeBtn);
        make.size.mas_equalTo(CGSizeMake(20, 20));
    }];
    
    self.numberL                 = [[UILabel alloc] init];
    self.numberL.font            = FontSize(14);
    self.numberL.theme_textColor = MOJiTextColor;
    self.numberL.textAlignment   = NSTextAlignmentCenter;
    [self.noticeBtn addSubview:self.numberL];
    [self.numberL mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(noticeImage.mas_right).offset(5);
        make.right.mas_equalTo(self.noticeBtn).offset(-16);
        make.centerY.mas_equalTo(self.noticeBtn);
    }];
}

- (void)noticeBtnEvent {
    //1.清空评论的收件箱阅读数
    [MOJiCommentHelper clearAllInboxReadWithCompletion:nil];
    
    //2.跳转到个人主页-动态列表
    [MDUIUtils pushMyPersonalInfoVCWithItemType:MDPersonalInfoVCItemTypeActivities fromCtrl:MDUIUtils.visibleViewController];
}

- (void)willSelectTabAtIndexManually:(NSInteger)index {
    [self willSelectTabAtIndex:index feedbackEnabled:NO];
}

//- (void)willSelectTabBarItem:(MOJiTabBarButton *)tabBarButton {
//    [self willSelectTabBarItem:tabBarButton feedbackEnabled:YES];
//}

- (void)willSelectTabAtIndex:(NSInteger)index feedbackEnabled:(BOOL)enabled {
    _moji_selectedIndex = index;
    
    if (index == MDMainVCChildVCTypeFav) {
        [MFKHelper setScene:MFKSceneClickTabBarFavButton];
        [MOJiLogEvent logEventWithName:MOJiLogEventNameTabCollection];
    } else if (index == MDMainVCChildVCTypeSearch) {
        [MOJiLogEvent logEventWithName:MOJiLogEventNameTabSearch];
    } else if (index == MDMainVCChildVCTypeAI) {
        [MOJiLogEvent logEventWithName:MOJiLogEventNameTabAI];
    }
//    else {
//        [MOJiLogEvent logEventWithName:MOJiLogEventNameTabMy];
//    }
    
    // 是否需要点击响应反馈
    if (enabled) [MDImpactFeedbackGenerator feedbackLight];
    
    // 当出现这几种情况时，无法再继续执行下面的操作：
    // 1.当需要弹首登引导
    // 2.点击收藏 -> 未登录 或 点击收藏 -> 已登录 -> 未购买PRO会员
    // 3.点击测试 -> 未登录 或 点击收藏 -> 已登录 -> 未购买PRO会员
//    if (![self canSelectTabAtIndex:index]) return;
    
    // 当在选中的情况下再次选择时，内部会尝试处理各自的事情，如下：
    // 1.发现界面会回到顶部，并刷新数据
    // 2.收藏界面、我的界面再次点击时会滑动到顶部
    // 3.搜索界面会弹键盘
    // 4.测试界面会刷新计划数据
//    [self tryToHandleIndividualThingsWhenSelectedAgainWithTabBarButton:tabBarButton];

    // 更新选中的状态
    
}

- (BOOL)canSelectTabAtIndex:(NSInteger)index {
    MDMainVCChildVCType vcType = (MDMainVCChildVCType)index;
    
    if (vcType == MDMainVCChildVCTypeFav) {
        if (!MDUserHelper.isLogin) {
            [MDUIUtils presentLoginVC];
            
            return NO;
        }
        
        if (!MDUserHelper.didPurchaseMOJiProducts) {
            [MDUIUtils presentPrivilegeActionSheetWithPrivilegeType:MOJiPrivilegeTypeFavCategory];
            return NO;
        }
    }
    return YES;
}

//- (void)tryToHandleIndividualThingsWhenSelectedAgainWithTabBarButton:(MOJiTabBarButton *)tabBarButton {
//    BOOL selectedAgain         = (tabBarButton.tag == self.selectedTabBarButton.tag);
//    MDMainVCChildVCType vcType = (MDMainVCChildVCType)tabBarButton.tag;
//
//    if (!selectedAgain) return;
//
//    if (vcType == MDMainVCChildVCTypeSearch) {
//        [self tryToLetSearchBarBecomeFirstResponder];
//    } else if (vcType == MDMainVCChildVCTypeMe) {
//        [self tryToRefreshMe];
//    }
//}

//- (void)tryToRefreshMe {
//    MDBaseNavigationController *meNavCtrl = (MDBaseNavigationController *)[self.viewControllers objectAtIndex:MDMainVCChildVCTypeMe];
//    MOJiMeVC *vc                          = (MOJiMeVC *)meNavCtrl.rootViewController;
//
//    if ([vc respondsToSelector:@selector(manualRefreshData)]) {
//        [vc manualRefreshData];
//    }
//}

//- (void)tryToLetSearchBarBecomeFirstResponder {
//    MDBaseNavigationController *searchNavCtrl = [self.viewControllers objectAtIndex:MDMainVCChildVCTypeSearch];
//    MOJiSearchVC *searchVC                    = (MOJiSearchVC *)searchNavCtrl.rootViewController;
//
//    if ([searchVC respondsToSelector:@selector(searchBarBecomeFirstResponder)]) {
//        [searchVC searchBarBecomeFirstResponder];
//    }
//}

- (void)resetChildVcs:(CGPoint)offset {
    /*
        特别说明：
        
        考虑到采用【NSLocalizedString + ChineseConvertor】方式实现语言切换，既要注册Label、Button控件的
        语言切换通知，又要给列表Cell的Label的ChineseConvertor转换做列表刷新，还要考虑框架自定义的控件等。
        这种维护成本极高，故先参考微信APP做法（替换重新new tabBarCtrl.rootViewController，但我们这边为避免
        过多的renew操作，只替换子控制器即可），等后面有更好的想法再来优化。
     */
    
    MOJiHomeVC *home = [[MOJiHomeVC alloc] init];
    
    MOJiMeVC *meVc                = [[MOJiMeVC alloc] initWithNibName:NSStringFromClass(MOJiMeVC.class) bundle:nil];
    MDSettingsVC *setingVc        = (MDSettingsVC *)[MDUIUtils xibVCWithClass:MDSettingsVC.class];
    setingVc.defaultContentOffset = offset;
    
    MDBaseNavigationController *nav = [[MDBaseNavigationController alloc] initWithRootViewController:home];
    
    NSMutableArray *arr = nav.viewControllers.mutableCopy;
    [arr addObject:meVc];
    [arr addObject:setingVc];
    
    nav.viewControllers = arr;
    
    UIWindow *window          = [UIApplication sharedApplication].keyWindow;
    window.rootViewController = nav;
    [window makeKeyAndVisible];
}

#pragma mark 添加子控制器
//- (void)addChildVCs {
//    NSArray *childVCs = [self childVCs];
//    for (NSInteger i = 0; i < childVCs.count; i++) {
//        Class class          = childVCs[i];
//        UIViewController *vc = nil;
//
//        if ([class isEqual:MOJiSearchVC.class]) {
//            vc = [[MOJiHomeVC alloc] init];
//        } else {
//            vc = [[class alloc] initWithNibName:NSStringFromClass(class) bundle:nil];
//        }
//
//        [self addChildVC:vc];
//    }
//}

- (void)fetchData {
    [self fetchUserInfo];
}

- (void)fetchUserInfo {
    [MDUserHelper getMyPersonalInfoWithCompletion:nil];
}

#pragma mark - delegate
- (void)mojiSKPaymentTransaction:(SKPaymentTransaction *)trans finishedWithProductId:(NSString *)pid {
    [self handleSKPaymentTransactionCallbackWithProductId:pid];
}

- (void)mojiStoreRestoreTransactionsFinished:(NSArray *)transactions {
    [self handleSKPaymentTransactionCallbackWithProductId:MOJI_JISO_PRO_UPGRADE_ID_appstore];
    [self handleSKPaymentTransactionCallbackWithProductId:MOJI_WIDGETS_THEME_UPGRADE_ID_appstore];
}

- (void)mojiSKPaymentTransaction:(SKPaymentTransaction *)trans failedWithProductId:(NSString *)pid error:(NSError *)error {
    [self handleSKPaymentTransactionCallbackWithProductId:pid];
}

- (void)handleSKPaymentTransactionCallbackWithProductId:(NSString *)pid {
    if ([pid isEqual:MOJI_JISO_PRO_UPGRADE_ID_appstore]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MDUpdateUserProInfoBySKPaymentTransactionDeferredNotification object:nil];
    } if ([pid isEqual:MOJI_WIDGETS_THEME_UPGRADE_ID_appstore]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MOJiUpdateUserProInfoBySKPaymentWidgetsThemeNotification object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:MDUpdateUserSubscriptionInfoBySKPaymentTransactionDeferredNotification object:nil];
    }
    //更新内容详情配置信息
    [MDConfigHelper updateSharedContentDetailsConfig];
}

//#pragma mark 跟随系统主题 delegate
//- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
//    [super traitCollectionDidChange:previousTraitCollection];
//
//    //iOS 13系统主题外观切换触发广播唯一入口
//    if (@available(iOS 13.0, *)) {
//        if (MOJiThemeManager.themeStyleFollowed &&
//            (MOJiThemeManager.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)) {
//            //只要前后系统主题不一致，才触发
//            [MOJiThemeManager systemThemeStyleDidChange];
//        }
//    }
//}

#pragma mark MOJiInterstitialAdVCDelegate
- (void)moji_interstitialAdVCDidViewAdDetail:(MOJiInterstitialAdVC *)interstitialAdVC {
    [MDUIUtils presentAdsBrowserWithAd:interstitialAdVC.ad];
}

#pragma mark - setter/getter

- (MOJiPlayerContainerView *)playerContainerView {
    if (!_playerContainerView) {
        _playerContainerView = [[MOJiPlayerContainerView alloc] initWithMainVC:self];
    }
    return _playerContainerView;
}

- (MOJiWordListPlayingContainerV *)wordListPlayingV {
    if (!_wordListPlayingV) {
        _wordListPlayingV = [[MOJiWordListPlayingContainerV alloc] init];
    }
    return _wordListPlayingV;
}

- (void)showPlayerContainer {
    if (!_playerContainerView) { return; }
    
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.playerContainerView.superview == nil) {
        [self addPlayerContainerView];
    }
    
    //防止各种自定义转场动画导致控制有可能不能合理的显示与隐藏，所以延时一点点时间获取MDUIUtils.visibleViewController最终的真实值
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSString *currentVC      = NSStringFromClass(MDUIUtils.visibleViewController.class);
        
        if ([self.interceptedVCs containsObject:currentVC]) {
            [self.playerContainerView.superview bringSubviewToFront:self.playerContainerView];
            
            [self.playerContainerView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
                make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
                make.bottom.mas_equalTo(appDelegate.window);
            }];
            
            [UIView animateWithDuration:0.25 animations:^{
                [self.playerContainerView.superview layoutIfNeeded];
            }];
        } else {
            [self hidePlayerContainer];
        }
    });
}

- (void)hidePlayerContainer {
    if (!_playerContainerView) { return; }
    
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.playerContainerView.superview == nil) {
        [self addPlayerContainerView];
    }
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self.playerContainerView.superview bringSubviewToFront:self.playerContainerView];
    
    [self.playerContainerView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(appDelegate.window.mas_bottom);
        make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
        make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
    }];
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.playerContainerView.superview layoutIfNeeded];
    }];
}

- (void)closePlayerContainer {
    [self hidePlayerContainer];
    [MOJiDefaults.shared setDictionary:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@#%@", MOJiArticleAudioPlayerHelperCurrentPlayingArticleKey, MDUserHelper.currentUserId]];
}

- (void)showWordListPlayingView {
    if (!_wordListPlayingV) { return; }
    
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.wordListPlayingV.superview == nil) {
        [self addWordListPlayingView];
    }
    
    //防止各种自定义转场动画导致控制有可能不能合理的显示与隐藏，所以延时一点点时间获取MDUIUtils.visibleViewController最终的真实值
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSString *currentVC      = NSStringFromClass(MDUIUtils.visibleViewController.class);
        
        if ([MDUserHelper isLogin] && [self.interceptedWordListPlayingVCs containsObject:currentVC]) {
            [self.wordListPlayingV.superview bringSubviewToFront:self.wordListPlayingV];
            
            [self.wordListPlayingV mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
                make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
                make.bottom.mas_equalTo(appDelegate.window);
            }];
            
            [UIView animateWithDuration:0.25 animations:^{
                [self.wordListPlayingV.superview layoutIfNeeded];
            }];
        } else {
            [self hideWordListPlayingView];
        }
    });
}

- (void)hideWordListPlayingView {
    if (!_wordListPlayingV) { return; }
    
    // 如果走了resetChildVcs方法，重置了页面，可能会有这个问题
    if (self.wordListPlayingV.superview == nil) {
        [self addWordListPlayingView];
    }
    
    //防止各种自定义转场动画导致控制有可能不能合理的显示与隐藏，所以延时一点点时间获取MDUIUtils.visibleViewController最终的真实值
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [self.wordListPlayingV.superview bringSubviewToFront:self.wordListPlayingV];
        
        [self.wordListPlayingV mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(appDelegate.window.mas_bottom);
            make.left.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideLeft);
            make.right.mas_equalTo(appDelegate.window.mas_safeAreaLayoutGuideRight);
        }];
        
        [UIView animateWithDuration:0.25 animations:^{
            [self.wordListPlayingV.superview layoutIfNeeded];
        }];
    });
}

- (void)updateWordListPlayingViewStyle:(MOJiWordListPlayingVCStyle)style {
    if (!_wordListPlayingV) { return; }
    
    [self.wordListPlayingV updateViewWithStyle:style];
}

/*
    只要在下面方法添加相应的控制器名，会在该控制器下显示全局播放器。
 */
- (NSArray *)interceptedVCs {
    if (!_interceptedVCs) {
        _interceptedVCs = @[@"MOJiDict.MOJiReadingVC",
                            @"MOJiDict.MOJiColumnDetailVC",
                            @"MOJiDict.MOJiReadingArticleDetailVC"];
    }
    return _interceptedVCs;
}

/*
    只要在下面方法添加相应的控制器名，会在该控制器下显示全局播放器。
 */
- (NSArray *)interceptedWordListPlayingVCs {
    if (!_interceptedWordListPlayingVCs) {
        _interceptedWordListPlayingVCs = @[@"MOJiDict.MOJiHomeVC",
                                           @"MDFavInfoVC",
                                           @"MOJiDict.MOJiWordListHomeVC",
                                           @"MOJiDict.MOJiWordListPlayTypesVC"];
    }
    return _interceptedWordListPlayingVCs;
}

@end
