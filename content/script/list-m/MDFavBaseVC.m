//
//  MDFavBaseVC.m
//  MOJiDict
//
//  Created by Yemingzhi on 2019/11/26.
//  Copyright © 2019 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MDFavBaseVC.h"
#import "MDSettingsActionSheet.h"
#import "MOJiBookmarkEditor.h"
#import "MOJiFolderPickerHelper.h"

#import "MOJiFavCell.h"
#import "MDFavEditNavBar.h"
#import "MDBlackToolBar.h"

#import "MDFavInfoVC.h"
#import "MDFavoriteInfoHeaderVC.h"
#import "MOJiFavSearchVC.h"

#import "MDFavInfoSectionHeaderView.h"
#import "MOJiSharedCenterEntranceView.h"

#import "MOJiMenuListView.h"

static NSInteger const DefaultFavFolderPickerTag              = 100000;
static NSInteger const AutoImportSearchHistoryFolderPickerTag = 100001;
static CGFloat   const UIViewAnimateDurationDefault           = 0.2;

@interface MDFavBaseVC () <MOJiFolderPickerDelegate, MDBlackToolBarDelegate, SentenceComposerDelegate, WordComposerDelegate, MOJiFavCellDelegate, MOJiNoteVCDelegate, MCCCreationCenterVCDelegate>
@property (nonatomic, strong) NSMutableArray *tempDelItemInFolders;
@property (nonatomic, strong) NSMutableArray *tempDelFolders;
@property (nonatomic, strong) NSMutableArray *tempDelWorts;
@property (nonatomic, strong) NSMutableArray *tempDelNews;
@property (nonatomic, strong) NSMutableArray *tempDelBookmarks;

@property (nonatomic, strong) NSMutableArray *sortModels;
@property (nonatomic, strong) MOJiActionSheetAction *selectedSortAction;
@property (nonatomic, strong) NSMutableArray *pagesVCItems;
@property (nonatomic, assign) BOOL isLoadingData;
@property (nonatomic, assign) MOJiWordsExportType wordsExportType;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *navBarHeightConstraint;
@property (nonatomic, assign) NSInteger lastViewWidth;

@end

@implementation MDFavBaseVC

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initialize];
    [self configViews];
    [self getFolderContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateRefreshCtrlRefreshingStatus];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    NSInteger width = (NSInteger)self.view.frame.size.width;
    
    if (self.lastViewWidth == width) return; // 防止删除ItemInFolder时还在reload，然后崩溃
    
    self.lastViewWidth = width;
    
    CGFloat toolBarH = [MDBlackToolBar barHeight];
    
    if (self.isEditing) {
        [self.blackToolBar mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.view.mas_bottom).offset(-toolBarH);
        }];
    } else {
        [self.blackToolBar mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.view.mas_bottom);
        }];
    }
    
    [self.blackToolBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(toolBarH);
    }];
    
    [self.view layoutIfNeeded];
}

#pragma mark - events
- (void)initialize {
    self.tempDelItemInFolders   = [NSMutableArray array];
    self.tempDelFolders         = [NSMutableArray array];
    self.tempDelWorts           = [NSMutableArray array];
    self.tempDelNews            = [NSMutableArray array];
    self.tempDelBookmarks       = [NSMutableArray array];
    self.selected_itemObjectIds = [NSMutableArray array];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolderSuccess:) name:MOJiUpdateFolderSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createFolderSuccess:) name:MOJiCreateFolderSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MOJiUpdateBookmarkSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MOJiCreateBookmarkSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(operateItemsSuccess:) name:MDAddOrUpdateItemsSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteItemsNotification:) name:MDDeleteItemsSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(operateItemsSuccess:) name:MDMoveItemsSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addOrUpdateCreationWordSuccess:) name:MDAddOrUpdateCreationWordSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addOrUpdateCreationSentenceSuccess:) name:MDAddOrUpdateCreationSentenceSuccessNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followFolderSuccess:) name:MDFollowFolderSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unfollowFolderSuccess:) name:MDUnfollowFolderSuccessNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MDPublishOrCancelPublishFolderSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MDAddOrDeleteNoteSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MDUpdateNoteSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableVData) name:MDSetupAutoImportSearchHistoryFolderOnSuccessNotification object:nil];
    
//    if ([MDFavHelper isMyFolderWithFolderId:self.folderId]) {
        //暂时只支持只有自己文件夹需要监听第三方文件夹排序事件
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MDFavListSortTypeDidChangeNotification object:nil];
//    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableVData) name:MDFavListDidChangeCompleteDisplayNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableVData) name:MOJiFontStyleDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(derivePDF) name:MOJiFavListDerivePDFNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deriveWordCardPDF) name:MOJiFavListDerivePDFWordCardNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getFolderContentFromDB) name:MOJiFavUpdateSelfDataSuccessNotification object:nil];
}

- (void)reloadTableVData {
    [self.tableV reloadData];
}

- (void)followFolderSuccess:(NSNotification *)notification {
    // 增加收藏标识
    self.previousParentFolderCollection = YES;
    
    [self getFolderContentFromDB];
}

- (void)unfollowFolderSuccess:(NSNotification *)notification {
    // 增加收藏标识
    self.previousParentFolderCollection = NO;
    
    [self getFolderContentFromDB];
}

- (void)addOrUpdateCreationSentenceSuccess:(NSNotification *)notification {
    [self getFolderContentFromDB];
}

- (void)addOrUpdateCreationWordSuccess:(NSNotification *)notification {
    [self getFolderContentFromDB];
}

- (void)updateFolderSuccess:(NSNotification *)notification {
    [self getFolderContentFromDB];
}

- (void)operateItemsSuccess:(NSNotification *)notification {
    [self getFolderContentFromDB];
    [self updateEditNavBarSubviews];
}

- (void)deleteItemsNotification:(NSNotification *)noti {
    NSDictionary *info       = noti.object;
    NSString *parentFolderId = info[MOJiParentFolderIdKey];
    
    if (parentFolderId && [parentFolderId isEqualToString:self.folderId]) {
        [self getFolderContentFromDB];
        [self updateEditNavBarSubviews];
    }
}

- (void)createFolderSuccess:(NSNotification *)notification {
    [self getFolderContentFromDB];
}

- (void)configViews {
    [self configTableV];
    [self configNavBar];
    [self configToolBar];
}

- (void)configTableV {
    self.tableV.delegate        = self;
    self.tableV.dataSource      = self;
    self.tableV.tableFooterView = [[UIView alloc] init];
    self.tableV.separatorStyle  = UITableViewCellSeparatorStyleNone;
    
    //防止setContentOffset锁定位置不准
    self.tableV.estimatedRowHeight           = 0;
    self.tableV.estimatedSectionFooterHeight = 0;
    self.tableV.estimatedSectionHeaderHeight = 0;
    
    [self.tableV registerNib:[UINib nibWithNibName:NSStringFromClass(MOJiFavCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(MOJiFavCell.class)];
    
    /*
        说明：
     
        1.iPad下，输入框会一直显示，所以间距调大点（优化）
        2.如果采用+[MUIPureTools addFooter2tableView:height:]方法设置底部间距，会导致
        加载更多菊花距离最后一个Cell一个height的高度，所以这里还是采用UIEdgeInsets设置
        
     */
    
    UIEdgeInsets insets = self.tableV.contentInset;
    insets.bottom              = MOJiFavCell.cellHeight * 3 - 80;
    self.tableV.contentInset   = insets;
    self.tableV.mj_header = self.refreshHeader;
}

- (void)configNavBar {
    [self.backBtn      addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.shareBtn     addTarget:self action:@selector(shareAction) forControlEvents:UIControlEventTouchUpInside];
    [self.searchBtn     addTarget:self action:@selector(pushToSearchAction) forControlEvents:UIControlEventTouchUpInside];
    [self.navSearchBtn addTarget:self action:@selector(searchAction) forControlEvents:UIControlEventTouchUpInside];
    
    self.navSearchBtn.hidden                = YES;
    self.navSearchBtn.titleEdgeInsets       = UIEdgeInsetsMake(0, 4, 0, 0);
    self.navSearchBtn.layer.cornerRadius    = self.navSearchBtn.defaultCornerRadius;
    self.navSearchBtn.theme_backgroundColor = MOJiDiscoverToolBarButtonBgColor;
    self.navSearchBtn.disableAutoResize     = YES;
    self.navSearchBtn.followTouchPoint      = YES;
    
    [self.editNavBar.cancelBtn    addTarget:self action:@selector(cancelAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.editNavBar.selectAllBtn addTarget:self action:@selector(selectAllAction:) forControlEvents:UIControlEventTouchUpInside];
    
    //1.编辑导航栏-默认隐藏
    self.editNavBar.hidden      = YES;
    self.editNavBar.alpha       = 0;
    self.editNavBar.titleL.text = [NSString stringWithFormat:@"%@0%@", NSLocalizedString(@"已选择", nil), NSLocalizedString(@"项", nil)];
    
    [self.editNavBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideTop).offset(-[self editNavBarY]);
    }];
}

- (CGFloat)editNavBarY {
    return [MDFavEditNavBar barHeight] + 60;
}

- (void)configToolBar {
   
}

- (void)configMenuListAddTargetV {
    // 由于每一页的位置和层级都不尽相同，由子类实现
}

- (void)menuListAddVDidSelectItem:(MOJiMenuListItem *)item {
    //1.按targetType跳转页面
    [self createTargetWithTargetType:item.targetType];
    
    //2.隐藏
    [self setMenuListAddTargetVHidden:YES];
}

- (void)createTargetWithTargetType:(TargetType)targetType {
    if (targetType == TargetTypeFolder) {
        MOJiFolderEditor *editor = [[MOJiFolderEditor alloc] initWithFolderEditorType:MOJiFolderEditorTypeCreate folderId:self.folderId isReleaseFolder:NO];
        [self presentViewController:editor animated:YES completion:nil];
    } else if (targetType == TargetTypeNote) {
        [MDNoteHelper.shared pushNoteVC:[MOJiPushNoteVCFromFolderInfoModel modelWithFromTargetId:self.folderId fromTargetType:@(TargetTypeFolder)]];
    } else if (targetType == TargetTypeWord) {
        [MDUIUtils pushCreateCenterVC];
    } else if (targetType == TargetTypeSentence) {
        [MDUIUtils pushCreateCenterVCWithTargetType:targetType];
    }
}

- (CGSize)floatingButtonSize {
    return CGSizeMake(72, 48);
}

- (void)configAddFunctionButton {
    [self.view addSubview:self.addFunctionBtn];
}

- (void)getFolderContentFromDB {
    [self hideProgressHUD];
    
    self.items = [MDFavHelper itemInFoldersWithParentFolderId:self.folderId searchText:self.searchText targetType:self.menuListTargetType isFavInfo:(self.vcType == MOJiFavVCTypeFavInfo || self.vcType == MOJiFavVCTypeFavInfoManualSorting) folderId:self.folderId];
    
    [self.tableV reloadData];
    [self updatePagesVCConfigs];
}

- (void)resetItems:(RLMResults *)items {
    // 修复数据不同步bug
    self.items = items;
}

/// 更新页码控制器配置（增删改查都需要更新）
- (void)updatePagesVCConfigs {
    self.pagesVCItems = [NSMutableArray array];
    for (NSInteger i = 0; i < self.items.count; i++) {
        ItemInFolder *item = self.items[i];
        
        if ([item.targetType integerValue] == TargetTypeWord ||
            [item.targetType integerValue] == TargetTypeBookmark ||
            [item.targetType integerValue] == TargetTypeSentence ||
            [item.targetType integerValue] == TargetTypeExample) {
            [self.pagesVCItems addObject:item];
        }
    }
}

- (void)getFolderContent {
    [self getFolderContentFromDB];
}

- (void)refreshData {
    [MDPlayerHelper stopPlayerPlus];
}

- (void)getMyFolderContent {
    self.isLoadingData = YES;
    @weakify(self)
    [MDFavHelper fetchLatestDataWithIsFavInfo:(self.vcType == MOJiFavVCTypeFavInfo || self.vcType == MOJiFavVCTypeFavInfoManualSorting) completion:^(BOOL succeeded) {
        @strongify(self)
        [self.refreshHeader endRefreshing];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [MOJiNotify dismissWaitingView];
        });
        
        self.isLoadingData = NO;
        
        if (succeeded) {
            [self getFolderContentFromDB];
        }
    }];
}

- (void)getMyCollectionFolderContent:(nullable void(^)(BOOL success))completion erorCallBack:(nullable void(^)(NSInteger errorCode))erorCallBack {
    self.isLoadingData = YES;
    @weakify(self)
    [MDFavHelper fetchLatestItemInFolderWithFolderId:self.folderId isFavInfo:(self.vcType == MOJiFavVCTypeFavInfo || self.vcType == MOJiFavVCTypeFavInfoManualSorting) completion:^(BOOL succeeded) {
        @strongify(self)
                   
        [self.refreshHeader endRefreshing];
        
        self.isLoadingData = NO;
        
        if (succeeded) {
            [self getFolderContentFromDB];
            
            [self.tableV.mj_footer endRefreshing];
            self.tableV.mj_footer.hidden = YES;
        }
        if (completion) {
            completion(succeeded);
        }
        [self updateFavInfoHeader];
    } errorCallback:erorCallBack];
}

- (void)updateFavInfoHeader {
    // 由子类实现该方法
}

- (void)getOtherUserFolderContent {
    self.tableV.mj_footer.hidden = self.items.count == 0;
    BOOL need = [MDFavHelper needRefreshFolderInfoWithFolderId:self.folderId];
    if (need) {
        [self.refreshHeader beginRefreshing];
    }
}

- (void)fetchFolderContentWithPageIndex:(NSInteger)pageIndex completion:(nullable void(^)(NSInteger code))completion; {
    self.isLoadingData = YES;
    
    MDFetchFolderContentRequest *req = [[MDFetchFolderContentRequest alloc] init];
    req.pageIndex                    = pageIndex;
    req.sortType                     = MOJiDefaultsManager.favListSortType;
    req.count                        = MDDefaultPageSize;
    req.fid                          = [self.folderId isEqualToString:MDFavHelper.rootFolderId] ? @"" : self.folderId;
    
    @weakify(self)
    [MDFavHelper fetchFolderContentWithRequest:req completion:^(MDFetchFolderContentResponse * _Nullable response, NSError * _Nullable error) {
        @strongify(self)
        [self hideProgressHUD];
        [self.refreshHeader endRefreshing];
        [self.tableV.mj_footer endRefreshing];

        self.isLoadingData = NO;
        
        if (response.sortType != MOJiDefaultsManager.favListSortType) {
            return;
        }
        
        if (response.isOK) {
            [self fetchFolderContentSuccessWithResponse:response];
        }
        
        if (completion) {
            completion(response.code);
        }
        self.tableV.mj_footer.hidden = response.result.count < MDDefaultPageSize;
    }];
}

- (void)fetchFolderContentSuccessWithResponse:(MDFetchFolderContentResponse *)response {
    /*
     收藏内容获取成功要做的事情：
     1.清除收藏的本地缓存
     2.然后把成功返回的数据(文件夹、单词、书签、新闻)写入本地数据库
     3.刷新列表
     4.记录分页以及刷新状态
     */
    
    [self getFolderContentFromDB];

    self.tableV.mj_footer.hidden = response.result.count == 0;
    
    if (response.pageIndex == MDDefaultPageIndex) {
        [self updateFolderInfoAndUserInfo];
    }
    
    //发广播，让播放器记录刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:MDAddOrUpdateItemsSuccessNotification object:self.folderId];
}

- (void)updateFolderInfoAndUserInfo {
    
}

- (void)loadMoreData {
    
}

- (void)cancelAction:(id)sender {
    [self endEditingAction];
}

- (void)endEditingAction {
    if (MDPlayerHelper.shared.currentPlayRecord) {
        [MDPlayerHelper showWordListPlayingView];
    }
    self.actionType = MOJiFavDetailMoreActionTypeNone;
    [self.homeVc showOrHideNavViewWithShow:YES];
    self.isEditing = NO;
    [self hideEditNavBarAndToolBar];
    [self.tableV setEditing:NO animated:YES];
    [self clearSelectedItemInFolders];
    [self updateEditNavBarSubviews];
    [self updateOtherBtnHiddenStatus];
    // 展示可能存在的底部播放器
    [MDPlayerHelper showOrHideWordListPlayingView];
}

- (void)updateOtherBtnHiddenStatus {

}

- (void)clearSelectedItemInFolders {
    self.selected_itemObjectIds = [NSMutableArray array];
    self.editNavBar.selectAllBtn.selected = NO;
}

- (void)selectAllAction:(MDButton *)sender {
    if (self.items.count == 0) {
        [MDUIUtils showToast:NSLocalizedString(@"未找到可选择的内容", nil)];
        return;
    }
    
    sender.selected = !sender.selected;
    
    self.selected_itemObjectIds = [NSMutableArray array];
    
    if (sender.selected) {
        for (NSInteger i = 0; i < self.items.count; i++) {
            ItemInFolder *itemInFolder = [self.items objectAtIndex:i];
            [self.selected_itemObjectIds addObject:itemInFolder.objectId];
        }
        
        for (NSInteger i = 0; i < self.selected_itemObjectIds.count; i++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
            [self.tableV selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    } else {
        for (NSInteger i = 0; i< self.items.count; i++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
            [self.tableV deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
    
    [self updateEditNavBarSubviews];
}

- (void)addAction {
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory];

    if (!canUse)            return;
    if (self.isLoadingData) return;
    
    [self showOrHideMenuListAddTargetV];
}

- (void)showOrHideMenuListAddTargetV {
    BOOL menuListAddTargetVHidden = (self.menuListAddTargetV.alpha > 0);
    [self setMenuListAddTargetVHidden:menuListAddTargetVHidden];
}

- (void)setMenuListAddTargetVHidden:(BOOL)menuListAddTargetVHidden {
    if (menuListAddTargetVHidden) {
        [self.menuListAddTargetV hide];
    } else {
        [self.menuListAddTargetV showInView:self.view];
    }
}

- (void)shareAction {
    if (self.isLoadingData) return;
    self.tableV.editing    = NO;
    [self showSettingAlert];
}

- (void)pushToSearchAction {
    MOJiFavInfoSearchVC *vc = [MOJiFavInfoSearchVC viewControllerWithFolderId:self.folderId];
    [MDUIUtils pushOrPresentVC:vc animated:YES];
}

- (void)searchAction {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionSearch];
    
    MOJiFavSearchVC *vc = [[MOJiFavSearchVC alloc] initWithNibName:NSStringFromClass(MOJiFavSearchVC.class) bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)setupCompleteDisplayWithOn:(BOOL)on {
    [MDFavHelper setupFavListSupportTitleCompleteDisplayModeOn:on];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MDFavListDidChangeCompleteDisplayNotification object:nil];
}

- (void)setupDefaultFavWithOn:(BOOL)on tag:(NSInteger)tag actionSheet:(MOJiActionSheet *)actionSheet {
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory];
    
    if (!canUse) return;
    
    if (tag == DefaultFavFolderPickerTag) {
        [MDFavHelper setupDefaultFavFolderWithOn:on];
    } else if (tag == AutoImportSearchHistoryFolderPickerTag) {
        [MDFavHelper setupAutoImportSearchHistoryFolderWithOn:on];
    }
}

- (NSString *)getActionSubtitleWithTag:(NSInteger)tag {
    NSString *subtitle = nil;
    
    if (tag == DefaultFavFolderPickerTag) {
        subtitle = MDFavHelper.defaultFavFolderTitle.length > 0 ? [NSString stringWithFormat:@"%@「%@」", NSLocalizedString(@"默认收藏到", nil), MDFavHelper.defaultFavFolderTitle] : NSLocalizedString(@"轻触选择默认文件夹", nil);
    } else if (tag == AutoImportSearchHistoryFolderPickerTag) {
        subtitle = MDFavHelper.autoImportSearchHistoryFolderTitle.length > 0 ? [NSString stringWithFormat:@"%@「%@」", NSLocalizedString(@"自动导入到", nil), MDFavHelper.autoImportSearchHistoryFolderTitle] : NSLocalizedString(@"轻触选择历史自动导入文件夹", nil);
    }
    
    return subtitle;
}

- (void)presentFolderPickerForSelectingDefaultFavWithTag:(NSInteger)tag {
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory];
    
    if (!canUse) return;
 
    MOJiFolderPickerConfig *config = [[MOJiFolderPickerConfig alloc] init];
    config.tag                     = tag;//用于区别其他事件触发
    
    if (tag == DefaultFavFolderPickerTag) {
        config.vcTitle = NSLocalizedString(@"请选择默认收藏夹", nil);
    } else if (tag == AutoImportSearchHistoryFolderPickerTag) {

    }
    
    MOJiFolderPicker *picker = [[MOJiFolderPicker alloc] init];
    picker.fp_delegate       = self;
    picker.config            = config;
    [[self visibleViewController] presentViewController:picker animated:YES completion:nil];
}

- (void)editFolder:(Folder *)folder showToast:(BOOL)showToast {
    //根目录不会进来。只有次级文件夹才会
    MOJiFolderEditor *editor = [[MOJiFolderEditor alloc] initWithFolderEditorType:MOJiFolderEditorTypeEdit folderId:folder.objectId isReleaseFolder:NO];
    [self presentViewController:editor animated:YES completion:^{
        if (showToast) {
            [MDUIUtils showToast:NSLocalizedString(@"快添加标签，让更多船友发现它，良好的社区环境需要你的支持！", nil)];
        }
    }];
}

- (void)exportAction {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionExportPDF];
    
    //如果已登录的用户未购买PRO，那么直接跳转到特权界面之大收藏
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory detailType:MOJiPrivilegeFavTypeBatchExport];
    
    if (!canUse) return;
    
    if (![self isFavedCurrentFolder]) {
        [MDUIUtils showToast:NSLocalizedString(@"请先收藏再导出", nil)];
        return;
    }
    
    NSMutableArray<NSString *> *selectedIds = [NSMutableArray arrayWithArray:self.selected_itemObjectIds];
    
    if (selectedIds.count == 0) { // 表示全选
        for (ItemInFolder *itemInFolder in self.items) {
            [selectedIds addObject:itemInFolder.objectId];
        }
    }
    if (self.vcType == MOJiFavVCTypeFavInfo) {
        [MDFavHelper exportWordsWithWordsExportType:self.wordsExportType folderId:self.folderId itemIds:selectedIds sourceRect:self.shareBtn.bounds sourceView:self.shareBtn];
    } else {
        [MDFavHelper exportWordsWithFolderId:self.folderId itemIds:selectedIds sourceRect:self.shareBtn.bounds sourceView:self.shareBtn];
    }
}

- (BOOL)isFavedCurrentFolder {
    return [MDFavHelper isMyFolderWithFolderId:self.folderId] || [MDSocialHelper favedWithFolderId:self.folderId];
}

- (void)derivePDF {
    [self setupDerivePDF];
    self.wordsExportType = MOJiWordsExportTypePDF;
}

- (void)deriveWordCardPDF {
    [self setupDerivePDF];
    self.wordsExportType = MOJiWordsExportTypeWordCard;
}

- (void)setupDerivePDF {
    if (![MDUserHelper isLogin]) {
        [MDUIUtils presentLoginVC];
        return;
    }
    
    if (![MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory detailType:MOJiPrivilegeFavTypeBatchExport]) {
        return;
    }
    
    if (![self isFavedCurrentFolder]) { 
        [MDUIUtils showToast:NSLocalizedString(@"请先收藏再导出", nil)];
        return;
    }
    
    if (self.vcType == MOJiFavVCTypeFavInfo) {
        self.isSharePDF = YES;
        
        [self beginEditingAction];
        [[NSNotificationCenter defaultCenter] postNotificationName:MDPlayerStopLoopPlayingNotification object:nil];
        
        //恢复原来状态
        self.isSharePDF = NO;
    }
}

- (void)beginEditingAction {
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory];
    
    if (!canUse) return;
    
    // 隐藏可能存在的底部播放器
    [MDPlayerHelper hideWordListPlayingView];
    
    //首次打开批量处理时，提示：批量删除不支持收藏自共享中心的文件夹，请逐一进入详细界面取消收藏。
//    if (MOJiDefaultsManager.isFirstTimeToBatchProcessingFavListItems) {
//        [self showBatchProcessingTips];
//        return;
//    }
    
    [self innerBeginEditingAction];
}

- (void)innerBeginEditingAction {
    self.isEditing = YES;
    [self showEditNavBarAndToolBar];
    [self hideTabBar];
    [self.tableV setEditing:YES animated:YES];
    [self updateOtherBtnHiddenStatus];

    [self.tableV reloadData];
    
    NSArray *btnTypes = [NSArray array];
    
    if ([MDFavHelper isMyFolder:[MDUserDBManager folderWithObjectId:self.folderId]]) {
        btnTypes = self.isSharePDF ? @[@(MDBlackToolBarBtnTypeExport)] : @[@(MDBlackToolBarBtnTypeMove), @(MDBlackToolBarBtnTypeDelete)];
    } else {
        btnTypes = self.isSharePDF ? @[@(MDBlackToolBarBtnTypeExport)] : @[@(MDBlackToolBarBtnTypeExport), @(MDBlackToolBarBtnTypeMove), @(MDBlackToolBarBtnTypeDelete)];
    }

    self.blackToolBar.btnTypes = btnTypes;
}

- (void)showBatchProcessingTips {
    @weakify(self)
    MOJiAlertViewAction *know = [MOJiAlertViewAction actionWithTitle:NSLocalizedString(@"知道啦", nil) handler:^(MOJiAlertViewAction * _Nonnull action) {
        @strongify(self)
        [self innerBeginEditingAction];
        [MOJiDefaultsManager setupFirstTimeToBatchProcessingFavListItems];
    }];
    
    MOJiAlertView *alertV = [MOJiAlertView alertViewWithTitle:NSLocalizedString(@"批量删除不支持收藏自词单的文件夹，请逐一进入详细界面取消收藏。", nil) message:nil actions:@[know]];
    [MDUIUtils.visibleViewController presentViewController:alertV animated:YES completion:nil];
}

- (void)showTabBar {
//    if (self.vcType == MOJiFavVCTypeFavInfo) return;
//
//    self.tabBarController.tabBar.hidden = NO;
//    [UIView animateWithDuration:UIViewAnimateDurationDefault animations:^{
//        self.tabBarController.tabBar.alpha = 1;
//    }];
}

- (void)hideTabBar {
//    if (self.vcType == MOJiFavVCTypeFavInfo) return;
//
//    [UIView animateWithDuration:UIViewAnimateDurationDefault animations:^{
//        self.tabBarController.tabBar.alpha = 0;
//    } completion:^(BOOL finished) {
//        self.tabBarController.tabBar.hidden = YES;
//    }];
}

#pragma mark 显示顶部编辑导航栏和底部工具栏
- (void)showEditNavBarAndToolBar {
    [self.editNavBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideTop);
    }];
    
    [self.blackToolBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_bottom).offset(-[MDBlackToolBar barHeight]);
    }];
    
    self.editNavBar.hidden = NO;
    self.navBarTopConstraint.constant = 0;
    if (self.navBarTopConstraintConst > 0) {
        self.navBarHeightConstraint.constant = 0;
    }
    
    [self.homeVc enableScrollWithEnable:NO];
    
    [UIView animateWithDuration:UIViewAnimateDurationDefault animations:^{
        self.editNavBar.alpha = 1;
        self.navBar.alpha     = 0;
        [self.view layoutIfNeeded];
    }];
}

- (void)hideEditNavBarAndToolBar {
    [self.editNavBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideTop).offset(-[self editNavBarY]);
    }];
    
    [self.blackToolBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_bottom);
    }];
    
    self.navBarTopConstraint.constant = self.navBarTopConstraintConst;
    self.navBarHeightConstraint.constant = 44;
    [self.homeVc enableScrollWithEnable:YES];
    
    [UIView animateWithDuration:UIViewAnimateDurationDefault animations:^{
        self.editNavBar.alpha = 0;
        self.navBar.alpha     = 1;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.editNavBar.hidden = YES;
        
        //隐藏工具栏后，显示标签栏
        if (self.vcType == MOJiFavVCTypeMyFav) {
            [self showTabBar];
        }
    }];
    [self.tableV reloadData];
}

- (void)showSettingAlert {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollection_more];
    MOJiFavAlertVC *vc = [[MOJiFavAlertVC alloc] init];
    vc.sortActions = self.sortModels;
    vc.settingActions = self.actions;
    vc.filterType = self.favCategoryType;
    @weakify(self);
    [vc setOperationHandler:^(MOJiFavAlertVcOperationType type) {
        @strongify(self)
        if (type == MOJiFavAlertVcOperationTypeMultiManage) {
            [MOJiLogEvent logEventWithName:MOJiLogEventNameCollection_batch];
            [self actionMultiManage];
        }
        else if (type == MOJiFavAlertVcOperationTypeExportCard) {
            [MOJiLogEvent logEventWithName:MOJiLogEventNameCollection_wordCard];
            [self favHomeExportCard];
        }
        else if (type == MOJiFavAlertVcOperationTypeExportPdf) {
            [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionExportPDF];
            [self favHomeExportPdf];
        }
    }];
    [vc presentVc];
}

- (void)actionMultiManage {
    [MDPlayerHelper hideWordListPlayingView];
    [self.homeVc showOrHideNavViewWithShow:NO];
    [self beginEditingAction];
    [[NSNotificationCenter defaultCenter] postNotificationName:MDPlayerStopLoopPlayingNotification object:nil];
}

- (void)favHomeExportCard {
    if (![MDUserHelper isLogin]) {
        [MDUIUtils presentLoginVC];
        return;
    }
    
    if (![self isFavedCurrentFolder]) {
        [MDUIUtils showToast:NSLocalizedString(@"请先收藏再导出", nil)];
        return;
    }
    
    CGRect frame   = CGRectMake(self.shareBtn.width/2 - 8, self.shareBtn.height/2, 0, 0);
    NSArray *items = [self favHomeExportWordList];
    [MDFavHelper exportWordsWithWordsExportType:MOJiWordsExportTypeWordCard folderId:self.folderId itemIds:items sourceRect:frame sourceView:self.shareBtn];
}

- (void)favHomeExportPdf {
    if (![MDUserHelper isLogin]) {
        [MDUIUtils presentLoginVC];
        return;
    }
    
    if (![self isFavedCurrentFolder]) {
        [MDUIUtils showToast:NSLocalizedString(@"请先收藏再导出", nil)];
        return;
    }
    
    CGRect frame   = CGRectMake(self.shareBtn.width/2 - 8, self.shareBtn.height/2, 0, 0);
    NSArray *items = [self favHomeExportWordList];
    [MDFavHelper exportWordsWithWordsExportType:MOJiWordsExportTypePDF folderId:self.folderId itemIds:items sourceRect:frame sourceView:self.shareBtn];
}

- (NSArray *)favHomeExportWordList {
    NSMutableArray<NSString *> *selectedIds = [NSMutableArray arrayWithArray:self.selected_itemObjectIds];
    if (selectedIds.count == 0) { // 表示全选
        for (ItemInFolder *itemInFolder in self.items) {
            [selectedIds addObject:itemInFolder.objectId];
        }
    }
    return selectedIds;
}

#pragma mark - delegate
#pragma mark UIScrollView delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // 不能删除，子类要用
}

#pragma mark MOJiFavCell delegate
- (void)moji_favCellDidClickTargetSource:(MOJiFavCell *)cell {
    if ([cell.item.parentFolderId isEqualToString:MDFavHelper.rootFolderId]) return;
    
    [MDUIUtils pushFavInfoVCWithFolderId:cell.item.parentFolderId];
}

- (void)favCellDidLongPress:(MOJiFavCell *)cell {
    [self.tableV deselectRowAtIndexPath:cell.indexPath animated:NO];
    BOOL canUse = [MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeFavCategory];
    if (!canUse) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.tableV.isEditing) {
            [self actionMultiManage];
//            [self tableView:self.tableV didSelectRowAtIndexPath:cell.indexPath];
        }
    });
}

#pragma mark UITableView delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ItemInFolder *item = self.items[indexPath.row];
    MOJiFavCell *cell  = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(MOJiFavCell.class)];
    cell.delegate      = self;
    
    cell.voiceBtn.hidden = (self.vcType == MOJiFavVCTypeFavInfoManualSorting);
    
    [cell updateCellWithItem:item searching:(self.folderContentFrom == MOJiFavVCFolderContentFromSearching)];
    
    /*
     PS:tableView 已经帮忙处理了非选中的状态，这里只处理选中状态
     */
    BOOL shouldSelect = [self.selected_itemObjectIds containsObject:cell.item.objectId];
    
    if (shouldSelect && !cell.isSelected) {
        [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
    cell.indexPath = indexPath;
    return cell;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing) {
        ItemInFolder *item     = self.items[indexPath.row];
        NSString *itemObjectId = item.objectId;
        
        if ([self.selected_itemObjectIds containsObject:itemObjectId]) {
            [self.selected_itemObjectIds removeObject:itemObjectId];
        }

        [self updateEditNavBarSubviews];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionList];
    
    if (indexPath.row >= self.items.count) return;
    
    MOJiFavCell *cell  = [tableView cellForRowAtIndexPath:indexPath];
    ItemInFolder *item = cell.item;//[self.items objectAtIndex:indexPath.row];
    
    if (item.targetType.intValue == TargetTypeFolder && self.actionType == MOJiFavDetailMoreActionTypeExportCard) {
        [MDUIUtils showToast:NSLocalizedString(@"文件夹无法勾选导出", nil)];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    //如果处于编辑状态，就不跳转操作
    if (tableView.isEditing) {
        NSString *itemObjectId = item.objectId;
        
        if (![self.selected_itemObjectIds containsObject:itemObjectId]) {
            [self.selected_itemObjectIds addObject:itemObjectId];
        }
        
        [self updateEditNavBarSubviews];
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (![MDFavHelper canPushTargetVCWhenDidDetectBlockStatusWithItem:item]) { return; }
    
    if ([item.targetType integerValue] == TargetTypeWord ||
        [item.targetType integerValue] == TargetTypeBookmark ||
        [item.targetType integerValue] == TargetTypeSentence ||
        [item.targetType integerValue] == TargetTypeExample) {
        
        //如果可以跳转指定界面，那么直接return结束该方法
        if ([item.targetType integerValue] == TargetTypeBookmark) {
            Bookmark *bookmark = [MDUserDBManager bookmarkWithObjectId:item.targetId];
            BOOL canPushVC     = [MDUrlHelper pushVCWithSharedUrl:bookmark.url];
            
            if (canPushVC) { return; }
        }
        
        if ([item.targetType integerValue] == TargetTypeWord &&
            [MDWordHelper isExtWordWithObjectId:item.targetId] &&
            !MDUserHelper.didPurchaseSubscriptionProduct) {
            [MDUIUtils presentExtLibVC];
            //跳转订阅界面时无需记录收藏搜索历史
            return;
        }
        
        NSInteger startIndex = [self pagesVCStartIndexWithSelectedItem:item];
        
        @weakify(self)
        [MDUIUtils pushContentDetailVCWithTargets:self.pagesVCItems index:startIndex deinitCompletion:^(MOJiContentPageController * _Nonnull pageVC) {
            @strongify(self)
            [self contentDetailsVCViewWillDisappearWithCurrentIndex:pageVC.currentIndex];
            [MAPPlusPlayerRecorder.shared resetLastRecorderInfo];
        }];
    } else if ([item.targetType integerValue] == TargetTypeNote) {
        [MDNoteHelper.shared pushNoteVC:[MOJiPushNoteVCFromFavListModel modelWithItemId:item.objectId]];
    } else if ([item.targetType integerValue] == TargetTypeTrans) {
        Trans *trans = [MDUserDBManager transWithObjectId:item.targetId];
        [MDUIUtils pushTranslationVCWithTrans:trans animated:YES];
    } else if (item.targetType.integerValue == TargetTypeAnalysis) {
        Analysis *analysis = [MDUserDBManager analysisWithObjectId:item.targetId];
        
        if (!analysis) {
            analysis          = [[Analysis alloc] init];
            analysis.objectId = item.targetId;
        }
        
        [MOJiAnalysisHelper pushAnalysisResultVCWithAnalysis:analysis];
    } else if ([item.targetType integerValue] == TargetTypeQAQuestion) {
        [MDUIUtils pushQAQuestionVCWithQuestionId:item.targetId];
    } else if ([item.targetType integerValue] == TargetTypeQAAnswer) {
        [MDUIUtils pushQAAnswerVCWithAnswerId:item.targetId];
    } else {
        BOOL isCollection = NO;
        
        if (self.vcType == MOJiFavVCTypeMyFav) {
            isCollection = NO;
        } else if (self.vcType == MOJiFavVCTypeFavInfo) {
            if (self.previousParentFolderCollection) {
                isCollection = self.previousParentFolderCollection;
            } else {
                isCollection = [MDSocialHelper favedWithFolderId:item.targetId];
            }
        }
        
        [MDFavHelper pushDetailVCWithItemInFolder:item fromCtrl:self isCollection:isCollection];
    }
}

- (void)contentDetailsVCViewWillDisappearWithCurrentIndex:(NSInteger)currentIndex {
    if (currentIndex >= self.pagesVCItems.count) return;
    
    ItemInFolder *pagesVCItem = self.pagesVCItems[currentIndex];
    NSInteger itemIndex       = 0;

    for (NSInteger i = 0; i < self.items.count; i++) {
        ItemInFolder *item = self.items[i];

        if ([item.objectId isEqualToString:pagesVCItem.objectId]) {
            itemIndex = i;
            break;
        }
    }
    
    BOOL isVisibleRow                  = NO; //是否为可见行
    NSArray<NSIndexPath *> *indexPaths = [self.tableV indexPathsForVisibleRows];
    for (NSInteger i = 0; i < indexPaths.count; i++) {
        NSIndexPath *tmpIndexPath = indexPaths[i];
        
        if (tmpIndexPath.row == itemIndex) {
            isVisibleRow = YES;
            break;
        }
    }
    
    //如果翻到的页数是在可见行数的话就不需要指定位置，否则执行一下操作
    if (!isVisibleRow) {
        CGFloat remainH = [self getTableViewRemainHeight];
        CGFloat offsetY = [self getCellOffsetYWithItemIndex:itemIndex];
        
        if (offsetY + remainH >= self.tableV.contentSize.height) {
            //如果指定Cell的y + 剩余部分高度大于或者列表的contentSize.height，说明已经到临界点，这时候就不需要置顶，直接拖到尾部即可（优化）
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.items.count-1 inSection:0];
            [self.tableV scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        } else {
            //指定在第一行显示
            [self.tableV setContentOffset:CGPointMake(0, offsetY) animated:NO];
        }
    }
}

/// 获取当前列表除掉单个Cell或者HeaderView高度的剩余高度
- (CGFloat)getTableViewRemainHeight {
    CGFloat remainH = self.tableV.frame.size.height - MOJiFavCell.cellHeight;
    remainH        -= self.view.safeAreaInsets.bottom;
    
    if (![self.folderId isEqualToString:MDFavHelper.rootFolderId]) {
        remainH -= [MDFavInfoSectionHeaderView viewHeight:YES];
    }
    
    return remainH;
}

/// 获取指定cell要移动到首位的offset.y
/// @param itemIndex <#itemIndex description#>
- (CGFloat)getCellOffsetYWithItemIndex:(NSInteger)itemIndex {
    CGFloat offsetY = MOJiFavCell.cellHeight * itemIndex;
    
    if (![self.folderId isEqualToString:MDFavHelper.rootFolderId]) {
        if ([self isKindOfClass:MDFavInfoVC.class]) {
            MDFavInfoVC *infoVC = (MDFavInfoVC *)self;
            offsetY            += infoVC.headerViewHeight;
        }
    }
    
    return offsetY;
}

- (NSInteger)pagesVCStartIndexWithSelectedItem:(ItemInFolder *)item {
    for (NSInteger i = 0; i < self.pagesVCItems.count; i++) {
        id tempItem = self.pagesVCItems[i];
        
        if ([tempItem isEqual:item]) {
            return i;
        }
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return MOJiFavCell.cellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (self.items.count == 0) {
        if ([MDFavHelper isMyFolderWithFolderId:self.folderId]) {
            return self.sharedCenterEntranceView.height;
        } else {
            return self.tipsV.height;
        }
    } else {
        return CGFLOAT_MIN;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (self.items.count == 0) {
        if ([MDFavHelper isMyFolderWithFolderId:self.folderId]) {
            return self.sharedCenterEntranceView;
        } else {
            return self.tipsV;
        }
    } else {
        //防止闪烁，只要有高度，就要配置对应的view
        UIView *view         = [[UIView alloc] init];
        view.backgroundColor = [UIColor clearColor];
        return view;
    }
}

#pragma mark UITargetedPreview 长按预览效果

//- (nullable UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
//    return [MDUIUtils createTargetedPreviewWithTableView:tableView configuration:configuration];
//}
//
//- (UITargetedPreview *)tableView:(UITableView *)tableView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
//    return [MDUIUtils createTargetedPreviewWithTableView:tableView configuration:configuration];
//}
//
//- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
//    if (tableView.isEditing) return nil;
//
//    if (indexPath.row >= self.items.count) return nil;
//
//    ItemInFolder *item = [self.items objectAtIndex:indexPath.row];
//
//    if (![MDFavHelper canPushTargetVCWhenDidDetectBlockStatusWithItem:item]) return nil;
//
//    return [MDUIUtils tableView:tableView contextMenuConfigurationForRowAtIndexPath:indexPath point:point targetInfo:item];
//}
//
//- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator API_AVAILABLE(ios(13.0)) {
//    UIViewController *vc = animator.previewViewController;
//
//    if (vc) {
//        [animator addCompletion:^{
//            [MDUIUtils.visibleViewController.navigationController pushViewController:vc animated:YES];
//        }];
//    }
//}

#pragma mark 左滑删除

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    /*
        原来的写法：return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
        导致在iOS 10中无法手势左滑操作事件，而iOS 11+无此问题
        
        现根据编辑模式对其调整如下：
     */
    if (tableView.isEditing) {
        return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
}

//- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
//    ItemInFolder *item = self.items[indexPath.row];
//    [MDPlayerHelper stopPlayerPlusWithItems:@[item]];
//    @weakify(self)
//    NSArray *actions = [MDFavHelper favTableViewSwipeActionsWithItem:item handler:^(UIContextualAction * _Nonnull action, UIView * _Nonnull sourceView, MDTableViewRowActionType type) {
//        @strongify(self)
//        [self cellDidActionAtIndexPath:indexPath actionType:type];
//    }];
//
//    UISwipeActionsConfiguration *config     = [UISwipeActionsConfiguration configurationWithActions:actions];
//    config.performsFirstActionWithFullSwipe = NO; //完全滑动时,是否执行第一个操作
//    return config;
//}

- (void)cellDidActionAtIndexPath:(NSIndexPath *)indexPath actionType:(MDTableViewRowActionType)actionType {
    ItemInFolder *item = self.items[indexPath.row];
    switch (actionType) {
        case MDTableViewRowActionTypeDelete:
            if (item.targetType.integerValue == TargetTypeFolder) {
                [self alertCtrlToConfirmDeletingItems:@[item]];
            } else {
                [self confirmDeletingItems:@[item]];
            }
            break;
        case MDTableViewRowActionTypeMove:
            //移动
            [self showFolderPickerToMoveSingleItem:item];
            break;
        case MDTableViewRowActionTypeEdit:
            //编辑
            [self cellDidEditWithIndexPath:indexPath];
            break;
        case MDTableViewRowActionTypeUnfollowFolder:
            [self unfollowFolderWithItem:item];
        default:
            break;
    }
}

- (void)unfollowFolderWithItem:(ItemInFolder *)item {
    MOJiAlertViewAction *confirm = [MOJiAlertViewAction actionWithTitle:NSLocalizedString(@"确定", nil) handler:^(MOJiAlertViewAction * _Nonnull action) {
        [MDSocialHelper requestToUnfollowFolderWithFolderId:item.targetId sucessBlock:nil];
    }];
    
    MOJiAlertViewCancelAction *cancel = [MOJiAlertViewCancelAction actionWithHandler:nil];
    MOJiAlertView *alertV             = [MOJiAlertView alertViewWithTitle:NSLocalizedString(@"确定要取消收藏吗？", nil) message:nil actions:@[cancel, confirm]];
    [self presentViewController:alertV animated:YES completion:nil];
}

- (void)cellDidEditWithIndexPath:(NSIndexPath *)indexPath {
    ItemInFolder *item    = self.items[indexPath.row];
    TargetType targetType = (TargetType)[item.targetType integerValue];
    
    switch (targetType) {
        case TargetTypeFolder:
            [self editFolder:[MDUserDBManager folderWithObjectId:item.targetId] showToast:NO];
            break;
        case TargetTypeBookmark:
            [self updateBookmarkWithItemInFolder:item];
            break;
        case TargetTypeWord:
            //能进来编辑的都是自己的单词，同时关联的details也已经通过离线收藏数据包一起返回
            //（原来做了complete word的判断，现已取消该判断，特此说明）
            [self presentWordComposerWithWord:[MDWordHelper getWordWithObjectId:item.targetId]];
            break;
        case TargetTypeSentence: {
            UINavigationController *navCtrl = [MDUIUtils getSentenceCreationCenterNavCWithOrgSentence:[MDUserDBManager sentenceWithObjectId:item.targetId] delegate:self isEditor:YES];
            [self presentViewController:navCtrl animated:YES completion:nil];
            break;
        }
        case TargetTypeExample:
            //TODO:后面加入，收藏列表手势左滑的编辑入口已隐藏
            break;
        default:
            break;
    }
}

- (void)presentWordComposerWithWord:(Wort *)word {
    UINavigationController *wordComposerNavC = [MDUIUtils getWordCreationCenterNavCWithOrgWord:word delegate:self isEditor:YES];
    [self presentViewController:wordComposerNavC animated:YES completion:nil];
}

- (void)updateBookmarkWithItemInFolder:(ItemInFolder *)item {
    Bookmark *bookmark = [[Bookmark alloc] init];
    bookmark.objectId  = item.targetId;
    bookmark.url       = [MDUserDBManager bookmarkWithObjectId:item.targetId].url;
    bookmark.title     = [MDUserDBManager bookmarkWithObjectId:item.targetId].title;
    bookmark.excerpt   = [MDUserDBManager bookmarkWithObjectId:item.targetId].excerpt;
    
    MOJiBookmarkEditor *editor = [[MOJiBookmarkEditor alloc] initWithBookmarkEditorStyle:MOJiBookmarkEditorStyleEdit bookmark:bookmark];
    [self presentViewController:editor animated:YES completion:nil];
}

- (void)showFolderPickerToMoveSingleItem:(ItemInFolder *)item {
    MOJiFolderPicker *picker = [self getFolderPickerWithItems:@[item]];
    [[self visibleViewController] presentViewController:picker animated:YES completion:nil];
}

- (void)showFolderPickerToMoveManyItems:(NSArray<ItemInFolder *> *)items {
    MOJiFolderPicker *picker = [self getFolderPickerWithItems:items];
    [[self visibleViewController] presentViewController:picker animated:YES completion:nil];
}

- (MOJiFolderPicker *)getFolderPickerWithItems:(NSArray<ItemInFolder *> *)items {
    BOOL single = YES;
    
    if (items.count > 1) {
        single = NO;
    }
    
    MOJiFolderPickerConfig *config = [[MOJiFolderPickerConfig alloc] init];
    
    if (single) {
        ItemInFolder *item      = [items firstObject];
        config.targetId         = item.targetId;
        config.targetType       = [item.targetType integerValue];
        config.objectId         = item.objectId;
        config.folderPickerType = MOJiFolderPickerTypeFav;
    }
    
    MOJiFolderPicker *picker = [[MOJiFolderPicker alloc] init];
    picker.fp_delegate       = self;
    picker.config            = config;
    return picker;
}

- (void)moveAction {
    if (self.selected_itemObjectIds.count == 0) {
        [MDUIUtils showToast:NSLocalizedString(@"未选择，请轻触选择后操作", nil)];
        return;
    }
    
    NSArray *items = [self getSelectedItems];
    [self showFolderPickerToMoveManyItems:items];
}

- (void)testAction {
    NSMutableArray *wordItems = [NSMutableArray array];
    for (NSInteger i = 0; i < self.selected_itemObjectIds.count; i++) {
        NSString *itemObjectId = self.selected_itemObjectIds[i];
        ItemInFolder *item     = [MDUserDBManager itemInFolderWithObjectId:itemObjectId];
        
        if ([item.targetType integerValue] == TargetTypeWord) {
            [wordItems addObject:item];
        }
    }
    
    if (wordItems.count == 0) {
        [MDUIUtils showToast:NSLocalizedString(@"未选择单词，请轻触选择后再操作", nil)];
    }
}

- (void)deleteAction {
    NSArray *items = [self getSelectedItems];
    [self alertCtrlToConfirmDeletingItems:items];
}

- (void)alertCtrlToConfirmDeletingItems:(NSArray<ItemInFolder *> *)items {
    if (items.count == 0) {
        [MDUIUtils showToast:NSLocalizedString(@"未选择，请轻触选择后再操作", nil)];
        return;
    }
    
    @weakify(self)
    
    MOJiActionSheet *sheet           = [MOJiActionSheet actionSheetWithTitle:NSLocalizedString(@"确定要删除吗？", nil)];
    MOJiActionSheetAction *delAction = [[MOJiActionSheetAction alloc] init];
    delAction.title                  = NSLocalizedString(@"删除", nil);
    delAction.style                  = MOJiActionSheetActionStyleDestructive;
    delAction.handler                = ^(MOJiActionSheetAction * _Nonnull action) {
        @strongify(self)
        
        [self confirmDeletingItems:items];
    };
    
    MOJiActionSheetCancelAction *cancelAction = [[MOJiActionSheetCancelAction alloc] init];
    
    [sheet addActions:@[delAction, cancelAction]];
    [[self visibleViewController] presentViewController:sheet animated:YES completion:nil];
}

- (void)confirmDeletingItems:(NSArray<ItemInFolder *> *)items {
    @weakify(self)
    [self showProgressHUD];
    [MDFavHelper deleteItems:items parentFolderId:self.folderId completion:^(MDDeleteItemsResponse * _Nonnull response, NSError * _Nonnull error) {
        @strongify(self)
        [self hideProgressHUD];
        
        if (!error && [response isKindOfClass:[NSNumber class]] && [response boolValue]) {
            [self deleteItemsSuccess:items];
        }
    }];
}

/// 右上角 删除当前文件夹
- (void)confirmDeletingCurrentFolder:(NSString *)currentFolderId fromParentFolder:(NSString *)parentFolderId completion:(void(^)(void))completion {
    ItemInFolder *itemFolder = [MDUserDBManager folderItemInFoldersWithFolderIds:@[currentFolderId]].firstObject;
    if (!parentFolderId) return;
    if (!itemFolder) return;
    if (![itemFolder.targetId isEqualToString:currentFolderId]) return;
    
    NSArray *items = @[itemFolder];
    @weakify(self)
    [self showProgressHUD];
    [MDFavHelper deleteItems:items parentFolderId:parentFolderId completion:^(MDDeleteItemsResponse * _Nonnull response, NSError * _Nonnull error) {
        @strongify(self)
        [self hideProgressHUD];
        if (!error && [response isKindOfClass:[NSNumber class]] && [response boolValue]) {
            NSArray <NSString *>* folderIds = @[itemFolder.objectId];
            [MOJiFolderPickerHelper removeRecentUsedFoldersByIds:folderIds];
            [MDUserDBManager transactionWithBlock:^{
                for (NSInteger i = 0; i < items.count; i++) {
                    ItemInFolder *item = items[i];
                    item.isTrash       = @(YES);
                }
            }];
            [MDUserDBManager.db refresh];
            //判断删除的是否有文件夹，如果有发个广播告诉播放器
            NSDictionary *json = @{ MOJiParentFolderIdKey: parentFolderId,
                                    MOJiFolderIdsKey: @[currentFolderId]};
            [[NSNotificationCenter defaultCenter] postNotificationName:MDDeleteItemsSuccessNotification object:json];
            completion();
        }
    }];
}

- (NSInteger)indexOfItemInFoldersWithItem:(ItemInFolder *)item {
    for (NSInteger i = 0; i < self.items.count; i++) {
        ItemInFolder *tempItem = self.items[i];
        
        if ([item.objectId isEqualToString:tempItem.objectId]) {
            return i;
        }
    }
    return -1;
}

- (void)deleteItemsSuccess:(NSArray<ItemInFolder *> *)items {
    /*
     删除记录成功要做的事情:
     1.先移除UserDefaults上最近常用的folderId的记录
     2.移除缓存中的收藏记录
     3.刷新列表
     */
    
    /*
     删除单词
     先判断是自创还是官方单词。
     如果是官方单词，只是删除itemInFolder表，如果是自创单词，还需要删除UserDB的wort表
     */
    NSMutableArray *indexPaths    = [NSMutableArray array];
    NSMutableArray *tempFolderIds = [NSMutableArray array];
    for (NSInteger i = 0; i < items.count; i++) {
        ItemInFolder *item = items[i];

        if ([item.targetType integerValue] == TargetTypeFolder) {
            [tempFolderIds addObject:item.targetId];
        }
    }
    [MOJiFolderPickerHelper removeRecentUsedFoldersByIds:tempFolderIds];
    
    for (NSInteger i = 0; i < items.count; i++) {
        ItemInFolder *item = items[i];
        NSInteger row      = [self indexOfItemInFoldersWithItem:item];
        
        if (row != NSNotFound) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
        }
    }
    
    [MDUserDBManager transactionWithBlock:^{
        for (NSInteger i = 0; i < items.count; i++) {
            ItemInFolder *item = items[i];
            item.isTrash       = @(YES);
        }
    }];
    [MDUserDBManager.db refresh];
    
    //每次删除成功，都需要把选中的收藏初始化
    self.selected_itemObjectIds = [NSMutableArray array];

    //删除完毕后，需要更新选中项状态
    [self updateEditNavBarSubviews];
    
    [self getFolderContentFromDB];
    
    //判断删除的是否有文件夹，如果有发个广播告诉播放器
    NSDictionary *json = @{ MOJiParentFolderIdKey : self.folderId,
                            MOJiFolderIdsKey      : tempFolderIds};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MDDeleteItemsSuccessNotification object:json];
    
    //删除完毕后，判断是否为0条记录，如果是，那么直接结束编辑状态（已考虑过滤类型）
    if (self.items.count == 0) {
        [self endEditingAction];
    }
}

- (void)updateEditNavBarSubviews {
    self.editNavBar.titleL.text = [NSString stringWithFormat:@"%@%zi%@", NSLocalizedString(@"已选择", nil), self.selected_itemObjectIds.count, NSLocalizedString(@"项", nil)];
    
    //2.更新全选选中标识
    if (self.selected_itemObjectIds.count > 0) {
        self.editNavBar.selectAllBtn.selected = (self.selected_itemObjectIds.count == self.items.count);
    } else {
        self.editNavBar.selectAllBtn.selected = NO;
    }
    
    //更新blackToolBar按钮状态
    [self updateBlackToolBarButtonsStatus];
}

- (void)updateBlackToolBarButtonsStatus {
    BOOL canExport = NO;
    BOOL canMove   = self.selected_itemObjectIds.count > 0;
    BOOL canDelete = self.selected_itemObjectIds.count > 0;
    
    //如果是收藏信息界面并且不是我的收藏夹那么就不能移动和删除操作
    Folder *folder = [MDUserDBManager folderWithObjectId:self.folderId];
    
    if (self.vcType == MOJiFavVCTypeFavInfo && ![MDFavHelper isMyFolder:folder]) {
        canMove   = NO;
        canDelete = NO;
    }
    
    for (NSInteger i = 0; i < self.selected_itemObjectIds.count; i++) {
        NSString *itemObjectId = self.selected_itemObjectIds[i];
        ItemInFolder *item     = [MDUserDBManager itemInFolderWithObjectId:itemObjectId];
        
        if (item && [item.targetType integerValue] == TargetTypeFolder) {
            Folder *folder = [MDUserDBManager folderWithObjectId:item.targetId];
            if (folder && ![MDFavHelper isMyFolder:folder]) {
                canDelete = NO;
            }
        }
        
        if (item && ([item.targetType integerValue] == TargetTypeWord     ||
                     [item.targetType integerValue] == TargetTypeSentence ||
                     [item.targetType integerValue] == TargetTypeExample)) {
            canExport = YES;
        }
    }
    
    [self.blackToolBar setupButtonEnabled:canExport atType:MDBlackToolBarBtnTypeExport];
    [self.blackToolBar setupButtonEnabled:canMove atType:MDBlackToolBarBtnTypeMove];
    [self.blackToolBar setupButtonEnabled:canDelete atType:MDBlackToolBarBtnTypeDelete];
}

- (BOOL)canDeleteSelectedItems {
    //如果存在收藏的文件夹，就不给删除操作
    for (NSInteger i = 0; i < self.selected_itemObjectIds.count; i++) {
        NSString *itemObjectId = self.selected_itemObjectIds[i];
        ItemInFolder *item     = [MDUserDBManager itemInFolderWithObjectId:itemObjectId];
        
        if ([item.targetType integerValue] == TargetTypeFolder) {
            Folder *folder = [MDUserDBManager folderWithObjectId:item.targetId];
            
            if (folder && ![MDFavHelper isMyFolder:folder]) {
                return NO;
            }
        }
    }
    return YES;
}

#pragma mark MDBlackToolBar delegate
- (void)md_blackToolBar:(MDBlackToolBar *)toolBar didClickBtnAtType:(MDBlackToolBarBtnType)btnType {
    switch (btnType) {
        case MDBlackToolBarBtnTypeExport: {
            [self exportAction];
        }
            break;
        case MDBlackToolBarBtnTypeMove:
            [self moveAction];
            break;
        case MDBlackToolBarBtnTypeDelete:
            [self deleteAction];
            break;
        default:
            break;
    }
}

- (nullable ItemInFolder *)itemInFolderWithObjectId:(NSString *)objectId {
    for (ItemInFolder *item in self.items) {
        if ([item.objectId isEqualToString:objectId]) {
            return item;
        }
    }
    
    return nil;
}

- (NSArray *)getSelectedItems {
    NSMutableArray *items = [NSMutableArray array];
    for (NSInteger i = 0; i < self.selected_itemObjectIds.count; i++) {
        NSString *itemObjectId = self.selected_itemObjectIds[i];
        ItemInFolder *item     = [MDUserDBManager itemInFolderWithObjectId:itemObjectId];
        
        if (item) {
            [items addObject:item];
        }
    }
    return items;
}

#pragma mark MDFolderPicker delegate
- (void)moji_folderPicker:(MOJiFolderPicker *)folderPicker didSelectFolderWithFolderId:(NSString *)folderId {
    if (folderPicker.config.tag == DefaultFavFolderPickerTag) {
        //从默认收藏进来的folderPicker
        [MDFavHelper setupDefaultFavFolderWithObjectId:folderId];
        //只要选择了文件夹，都默认选中
        [MDFavHelper setupDefaultFavFolderWithOn:YES];
        [self.tableV reloadData];
        [self shareAction];
        return;
    }
    
    if (folderPicker.config.tag == AutoImportSearchHistoryFolderPickerTag) {
        [MDFavHelper setupAutoImportSearchHistoryFolderWithObjectId:folderId];
        //只要选择了文件夹，都默认选中
        [MDFavHelper setupAutoImportSearchHistoryFolderWithOn:YES];
        [self.tableV reloadData];
        [self shareAction];
        return;
    }
    
    if (folderPicker.config.targetId.length > 0) {
        //单个的时候，才有
        ItemInFolder *item = [self itemInFolderWithObjectId:folderPicker.config.objectId];
        [self moveItems:@[item] toFolderWithFolderId:folderId];
    } else {
        NSArray *items = [self getSelectedItems];
        [self moveItems:items toFolderWithFolderId:folderId];
    }
}

- (void)moveItems:(NSArray<ItemInFolder *> *)items toFolderWithFolderId:(NSString *)folderId {
    @weakify(self)
    [MDFavHelper requestToMoveItems:items pfid:folderId successBlock:^{
        @strongify(self)
        [self getFolderContentFromDB];
        [self clearSelectedItemInFolders];
        [self updateEditNavBarSubviews];
    }];
}

- (void)moji_folderPicker:(MOJiFolderPicker *)folderPicker didDeselectFolderWithFolderId:(NSString *)folderId {
    ItemInFolder *item = [self itemInFolderWithObjectId:folderPicker.config.objectId];
    
    if ([item.targetType integerValue] == TargetTypeFolder) {
        BOOL isMyFolder = [item.targetUserId isEqualToString:MOJiUser.currentUser.objectId];

        if (!isMyFolder) {
            //收藏的文件夹取消的话，就是取消关注了
            [MDSocialHelper requestToUnfollowFolderWithFolderId:item.targetId sucessBlock:nil];
            return;
        }
    }
    
    [MDFavHelper requestToDeleteItem:item pfid:folderId successBlock:^{
        [self clearSelectedItemInFolders];
    }];
}

#pragma mark Sentence Composer delegate
- (void)sentenceComposer:(SentenceComposer *)composer didFinishComposingSentence:(Sentence *)orgSen withNewSen:(Sentence *)newSen {
    DLog(@"orgSen:%@", orgSen);
    DLog(@"newSen:%@", newSen);
    
    if (newSen.title.length > MOJiSentenceContentMaxLength ||
        newSen.trans.length > MOJiSentenceContentMaxLength) {
        [MDUIUtils showToast:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"内容太长啦，控制在", nil), @(MOJiSentenceContentMaxLength), NSLocalizedString(@"字以内吧", nil)]];
        return;
    }
    
    [MDSentenceHelper requestToUpdateSentenceWithObjectId:orgSen.objectId title:newSen.title trans:newSen.trans pfid:self.folderId successBlock:^(NSString * _Nonnull sentenceId) {
        [composer dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didFinishComposingSentence:(Sentence *)orgSentence withNewSentence:(Sentence *)newSentence {
    if ([MDUserHelper tryToPushAccountEditVCWhenPersonalInfoIsIncomplete]) return;
    
    DLog(@"orgSen:%@", orgSentence);
    DLog(@"newSen:%@", newSentence);
    
    if (newSentence.title.length > MOJiSentenceContentMaxLength ||
        newSentence.trans.length > MOJiSentenceContentMaxLength) {
        [MDUIUtils showToast:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"内容太长啦，控制在", nil), @(MOJiSentenceContentMaxLength), NSLocalizedString(@"字以内吧", nil)]];
        return;
    }
    
    [MDSentenceHelper requestToUpdateSentenceWithObjectId:orgSentence.objectId title:newSentence.title trans:newSentence.trans pfid:self.folderId successBlock:^(NSString * _Nonnull sentenceId) {
        [creationCenterVC dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didFinishCompsingSplitTypeArray:(NSMutableArray *)splitTypeArray {
    if ([MDUserHelper tryToPushAccountEditVCWhenPersonalInfoIsIncomplete]) return;
    
    [MDSentenceHelper favManySentencesWithItemsJson:splitTypeArray useProgressHUD:YES completion:^(BOOL result) {
        if (result) {
            [creationCenterVC goBack];
            [creationCenterVC reset];
        }
    }];
}

- (void)wordComposer:(WordComposer *)composer didFinishComposingWord:(Wort *)orgWord withNewWordData:(CCCache *)cache {
    DLog(@"orgSen:%@", orgWord);
    DLog(@"newSen:%@", cache);
    
    [MDWordHelper requestToUpdateCreationWordWithWord:cache.word details:cache.details subdetails:cache.subdetails examples:cache.examples pfid:self.folderId successBlock:^(NSString * _Nonnull wordId) {
        [composer dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didFinishCompsingWord:(Wort *)orgWord withNewWordData:(CCCache *)cache {
    if ([MDUserHelper tryToPushAccountEditVCWhenPersonalInfoIsIncomplete]) return;
    
    DLog(@"orgSen:%@", orgWord);
    DLog(@"newSen:%@", cache);
    
    [MDWordHelper requestToUpdateCreationWordWithWord:cache.word details:cache.details subdetails:cache.subdetails examples:cache.examples pfid:self.folderId successBlock:^(NSString * _Nonnull wordId) {
        [creationCenterVC
         dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)confirmDeletingNotesWithIds:(NSArray<NSString *> *)noteIds {
    @weakify(self)
    [self showProgressHUD];
    [MDNoteHelper deleteManyNotesWithObjectIds:noteIds completion:^(MDDeleteManyNotesResponse * _Nonnull response, NSError * _Nonnull error) {
        @strongify(self)
        [self hideProgressHUD];
        
        if (response.isOK) {
            [self deleteNotesSuccessToDo];
        }
    }];
}

- (void)deleteNotesSuccessToDo {
    [self getFolderContentFromDB];
}

#pragma mark CustomTextViewDelegate
- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didPressPlayMenuItem:(NSString *)text {
    [MDPlayerHelper playSiriWithText:text];
}

- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didPressJishoMenuItem:(NSString *)text {
    [MDUIUtils presentSearchVCWithSearchText:text sourceType:MOJiSearchVCSourceTypePressJisho];
}

- (void)mcc_creationCenterVC:(MCCCreationCenterVC *)creationCenterVC didPressCreateSentenceMenuItem:(NSString *)text {
    Sentence *sentence = [[Sentence alloc] init];
    sentence.title     = text;
    [MDUIUtils pushCreateCenterVCWithTargetType:TargetTypeSentence target:sentence];
}

- (void)mcc_didMyCreateWithCreationCenterVC:(MCCCreationCenterVC *)creationCenterVC {
    if (![MDUIUtils canUseProFunctionWithPrivilegeType:MOJiPrivilegeTypeCreationMode]) return;
    
    MOJiMyLibCreationVC *vc = [[MOJiMyLibCreationVC alloc] initWithNibName:NSStringFromClass(MOJiMyLibCreationVC.class) bundle:nil];
    [MDUIUtils.visibleViewController.navigationController pushViewController:vc animated:YES];
}

#pragma mark - setter/getter

- (void)setNavBarTopConstraintConst:(CGFloat)navBarTopConstraintConst {
    _navBarTopConstraintConst = navBarTopConstraintConst;
    self.navBarTopConstraint.constant = navBarTopConstraintConst;
}

- (MDFavEditNavBar *)editNavBar {
    if (!_editNavBar) {
        _editNavBar = [[MDFavEditNavBar alloc] init];
        [self.parentV addSubview:_editNavBar];
        [_editNavBar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo([MDFavEditNavBar barHeight]);
            make.left.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideLeft);
            make.right.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideRight);
            make.top.mas_equalTo(self.parentV.mas_safeAreaLayoutGuideTop);
        }];
    }
    return _editNavBar;
}

- (MDBlackToolBar *)blackToolBar {
    if (!_blackToolBar) {
        _blackToolBar = [[MDBlackToolBar alloc] init];
        _blackToolBar.delegate = self;
        [self.view addSubview:_blackToolBar];
        [_blackToolBar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.view.mas_safeAreaLayoutGuideLeft);
            make.right.mas_equalTo(self.view.mas_safeAreaLayoutGuideRight);
            make.top.mas_equalTo(self.view.mas_bottom);
            make.height.mas_equalTo([MDBlackToolBar barHeight]);
        }];
        [self.view layoutIfNeeded];
    }
    
    return _blackToolBar;
}

- (NSMutableArray *)sortModels {
    @weakify(self)
    return [MDFavHelper getSortModeActionsWithSelectAction:^(MOJiActionSheetAction * _Nonnull action) {
        @strongify(self)
        [self actionSheetDidSelectAction:action];
    }].mutableCopy;
}

- (void)actionSheetDidSelectAction:(MOJiActionSheetAction *)action {
    if ([MDFavHelper isMyFolderWithFolderId:self.folderId]) {
        //直接跟随广播一起调用
//        [self getFolderContentFromDB];
    } else {
        //第三方的文件夹还是要请求数据
        [self showProgressHUD];
        [self fetchFolderContentWithPageIndex:MDDefaultPageIndex completion:nil];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MDFavListSortTypeDidChangeNotification object:nil];
}

- (MDFinishLoadingTipsView *)tipsV {
    if (!_tipsV) {
        _tipsV = [[MDFinishLoadingTipsView alloc] initWithFrame:CGRectMake(0, 0, self.tableV.frame.size.width, 414)];
        _tipsV.theme_backgroundColor = MOJiViewControllerViewBgColor;//通过tipsV的背景色盖住头部视图的背景图以阻止图片溢出时显示异常的问题出现
        _tipsV.autoresizingMask      = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tipsV.image                 = [UIImage imageNamed:@"img_none_collect"];
        _tipsV.title                 = NSLocalizedString(@"暂无收藏", nil);
    }
    return _tipsV;
}

- (MDButton *)addFunctionBtn {
    if (!_addFunctionBtn) {
        _addFunctionBtn = [[MDButton alloc] init];
        [_addFunctionBtn addTarget:self action:@selector(addAction) forControlEvents:UIControlEventTouchUpInside];
        [_addFunctionBtn setImage:[UIImage imageNamed:@"list_icon_add"] forState:UIControlStateNormal];
    }
    return _addFunctionBtn;
}

- (void)pushToWordListPlayHomeVC {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionDeacon];
    
    if (self.items.count == 0) {
        [MDUIUtils showToast:NSLocalizedString(@"当前列表未发现可播放的内容", nil)];
        return;
    }
    
    //如果是文件夹信息界面，并且还未加载好时，点击无效处理
    Folder *folder = [MDUserDBManager folderWithObjectId:self.folderId];
    
    if (!folder && self.vcType == MOJiFavVCTypeFavInfo) return;
    
    [MDUIUtils pushNewWordListPlayHomeVCWithFolderId:self.folderId];
}

- (UIView *)parentV {
    if (_parentV) {
        return _parentV;
    }
    return self.view;
}

- (NSArray<MOJiActionSheetAction *> *)actions {
    NSMutableArray *tempActions = [NSMutableArray array];
    
    MOJiActionSheetAction *action0 = [[MOJiActionSheetAction alloc] init];
    action0.title                  = NSLocalizedString(@"词条标题完整展示", nil);
    action0.logoName               = @"ic_common_defcollect";
    action0.style                  = MOJiActionSheetActionStyleDetailWithSwitchWithoutArrow;
    action0.on                     = MDFavHelper.favListSupportTitleCompleteDisplayModeOn;
    @weakify(self)
    action0.didSwitch = ^(MOJiActionSheetAction * _Nonnull action, MOJiActionSheet *actionSheet) {
        @strongify(self)
        [self setupCompleteDisplayWithOn:action.on];
    };
    [tempActions addObject:action0];
    
    [tempActions addObject:[self getLaunchDefaultFavAction]];
    
    return tempActions;
}

- (MOJiActionSheetAction *)getLaunchDefaultFavAction {
     return [self getLaunchActionWithTag:DefaultFavFolderPickerTag];
}

/// 只适用启动默认收藏、启动自动导入搜索历史
- (MOJiActionSheetAction *)getLaunchActionWithTag:(NSInteger)tag {
    MOJiActionSheetAction *action = [[MOJiActionSheetAction alloc] init];
    action.title                  = (tag == DefaultFavFolderPickerTag) ? NSLocalizedString(@"默认收藏", nil) : NSLocalizedString(@"启用自动导入搜索历史", nil);
    action.subtitle               = [self getActionSubtitleWithTag:tag];
    action.logoName               = (tag == DefaultFavFolderPickerTag) ? @"ic_common_autosave" : @"ic_common_autosave";
    
    NSString *folderTitle = (tag == DefaultFavFolderPickerTag) ? MDFavHelper.defaultFavFolderTitle : MDFavHelper.autoImportSearchHistoryFolderTitle;
    
    if (folderTitle.length > 0) {
        action.style = MOJiActionSheetActionStyleDetailWithSwitch;
        action.on    = (tag == DefaultFavFolderPickerTag) ? MDFavHelper.defaultFavFolderOn : MDFavHelper.autoImportSearchHistoryFolderOn;
    } else {
        action.style = MOJiActionSheetActionStyleDetail;
    }

    @weakify(self)
    action.didSwitch = ^(MOJiActionSheetAction * _Nonnull action, MOJiActionSheet *actionSheet) {
        @strongify(self)
        [self setupDefaultFavWithOn:action.on tag:tag actionSheet:actionSheet];
        if ([action.delegate respondsToSelector:@selector(actionSheetActionNeedUpdateCellInfo)]) {
            [action.delegate actionSheetActionNeedUpdateCellInfo];
        }
    };

    action.handler = ^(MOJiActionSheetAction * _Nonnull action) {
        @strongify(self)

        [self presentFolderPickerForSelectingDefaultFavWithTag:tag];
    };
    
    return action;
}

- (MOJiSharedCenterEntranceView *)sharedCenterEntranceView {
    if (!_sharedCenterEntranceView) {
        _sharedCenterEntranceView                       = [MOJiSharedCenterEntranceView viewFromXib];
        _sharedCenterEntranceView.theme_backgroundColor = MOJiSharedCenterEntranceViewBgColorInFavVC;
        [_sharedCenterEntranceView.contentV addTarget:self action:@selector(pushSharedCenterVC) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sharedCenterEntranceView;
}

- (void)pushSharedCenterVC {
    [MOJiLogEvent logEventWithName:MOJiLogEventNameCollectionDetailJumpShare];
    [MDUIUtils pushWordListHomeVCWithTitleStr:NSLocalizedString(@"词单", nil)];
}

- (NSMutableArray<ItemInFolder *> *)sortItems {
    if (!_sortItems) {
        _sortItems = [NSMutableArray array];
    }
    
    return _sortItems;
}

@end
