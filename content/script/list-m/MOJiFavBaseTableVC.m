//
//  MOJiFavBaseTableVC.m
//  MOJiDict
//
//  Created by Ji Xiang on 2021/4/2.
//  Copyright © 2021 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiFavBaseTableVC.h"
#import "MOJiFavCell.h"

@interface MOJiFavBaseTableVC () <UITableViewDelegate, UITableViewDataSource, MOJiFavCellDelegate>
@property (nonatomic, strong) NSMutableArray *pagesVCItems;
@end

@implementation MOJiFavBaseTableVC

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initialize];
    [self configViews];
}

- (void)themeStyleDidChange:notification {
    [super themeStyleDidChange:notification];
    
    [self.tableV reloadData];
}

- (void)initialize {
    /**
     由于该页面的页面结构问题，选择集成自MDBaseViewController，而非MDThemeBgBaseViewController
     手动添加themeStyleDidChange监听。
     这样做的原因：
     1、自定义背景下不会底层一个自定义图，本vc底层也有一个自定义图
     2、改变主题时要修改cell的图片
     */
}

- (NSString *)theme_backgroundColor {
    return nil;
}

- (BOOL)theme_backgroundImageViewHidden {
    return YES;
}

- (void)configViews {
    self.view.backgroundColor = UIColor.clearColor;
    
    self.tableV.delegate        = self;
    self.tableV.dataSource      = self;
    self.tableV.tableFooterView = [[UIView alloc] init];
    self.tableV.backgroundColor = UIColor.clearColor;
    self.tableV.separatorStyle  = UITableViewCellSeparatorStyleNone;
    
    //防止setContentOffset锁定位置不准
    self.tableV.estimatedRowHeight           = 0;
    self.tableV.estimatedSectionFooterHeight = 0;
    self.tableV.estimatedSectionHeaderHeight = 0;
    
    [self.tableV registerNib:[UINib nibWithNibName:NSStringFromClass(MOJiFavCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(MOJiFavCell.class)];
    
    self.tableV.contentInset = UIEdgeInsetsMake(0, 0, 100, 0);
}

#pragma mark - events

- (void)reloadData {
    [self.tableV reloadData];
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

- (void)setItems:(RLMResults<ItemInFolder *> *)items {
    _items = items;
    
    [self reloadData];
    [self updatePagesVCConfigs];
}

#pragma mark - ScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.delegate && [self.delegate respondsToSelector:@selector(moji_favBaseTableVCDidScroll:)]) {
        [self.delegate moji_favBaseTableVCDidScroll:self];
    }
}

#pragma mark MOJiFavCell delegate

- (void)moji_favCellDidClickTargetSource:(MOJiFavCell *)cell {
    if ([cell.item.parentFolderId isEqualToString:MDFavHelper.rootFolderId]) return;
    
    [MDUIUtils pushFavInfoVCWithFolderId:cell.item.parentFolderId];
}

#pragma mark - UITableView delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ItemInFolder *item = self.items[indexPath.row];
    MOJiFavCell *cell  = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(MOJiFavCell.class)];
    cell.delegate      = self;
    
    [cell updateCellWithItem:item searching:(self.folderContentFrom == MOJiFavVCFolderContentFromSearching) searchText:self.searchText];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.items.count) return;
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    ItemInFolder *item = [self.items objectAtIndex:indexPath.row];
    
    if ([item.targetType integerValue] == TargetTypeWord ||
        [item.targetType integerValue] == TargetTypeBookmark ||
        [item.targetType integerValue] == TargetTypeSentence ||
        [item.targetType integerValue] == TargetTypeExample) {
        
        //如果可以跳转指定界面，那么直接return结束该方法
        if ([item.targetType integerValue] == TargetTypeBookmark) {
            Bookmark *bookmark = [MDUserDBManager bookmarkWithObjectId:item.targetId];
            BOOL canPushVC     = [MDUrlHelper pushVCWithSharedUrl:bookmark.url];
            
            if (canPushVC) {
                return;
            }
        }
        
        if ([item.targetType integerValue] == TargetTypeWord &&
            [MDWordHelper isExtWordWithObjectId:item.targetId] &&
            !MDUserHelper.didPurchaseSubscriptionProduct) {
            [MDUIUtils presentExtLibVC];
            //跳转扩展词库界面时无需记录收藏搜索历史
            return;
        }
        
        NSInteger startIndex             = [self pagesVCStartIndexWithSelectedItem:item];
        WebContentDispatcherModel *model = [[WebContentDispatcherModel alloc] init];
        model.index                      = startIndex;
        model.targets                    = self.pagesVCItems;
        @weakify(self)
        MOJiContentPageController *pageVC = [WebContentDispatcher executeTaskToShowWebContentPageControllerWithModel:model andDeinitCompletion:^(MOJiContentPageController * _Nonnull page) {
            @strongify(self)
            [self contentDetailsVCViewWillDisappearWithCurrentIndex:page.currentIndex];
            [MAPPlusPlayerRecorder.shared resetLastRecorderInfo];
        } andDidAppearBlock:nil];
        [self push:pageVC];
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
        [MDFavHelper pushDetailVCWithItemInFolder:item fromCtrl:self isCollection:[MDSocialHelper favedWithFolderId:item.targetId]];
    }
}

- (void)contentDetailsVCViewWillDisappearWithCurrentIndex:(NSInteger)currentIndex {
    if (currentIndex >= self.pagesVCItems.count) return;
    
    ItemInFolder *pagesVCItem = self.pagesVCItems[currentIndex];
    NSInteger itemIndex = 0;
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
    CGFloat remainH = self.tableV.frame.size.height - MOJiFavCell.cellHeightForFavSearch;
    remainH        -= self.view.safeAreaInsets.bottom;
    return remainH;
}

/// 获取指定cell要移动到首位的offset.y
/// @param itemIndex <#itemIndex description#>
- (CGFloat)getCellOffsetYWithItemIndex:(NSInteger)itemIndex {
    CGFloat offsetY = MOJiFavCell.cellHeightForFavSearch * itemIndex;
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
    return MOJiFavCell.cellHeightForFavSearch;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 8;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view         = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (self.items.count == 0) {
        return self.tipsV.height;
    } else {
        return CGFLOAT_MIN;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (self.items.count == 0) {
        return self.tipsV;
    } else {
        //防止闪烁，只要有高度，就要配置对应的view
        UIView *view         = [[UIView alloc] init];
        view.backgroundColor = [UIColor clearColor];
        return view;
    }
}

#pragma mark UITargetedPreview 长按预览效果

- (nullable UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
    return [MDUIUtils createTargetedPreviewWithTableView:tableView configuration:configuration];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
    return [MDUIUtils createTargetedPreviewWithTableView:tableView configuration:configuration];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (tableView.isEditing) return nil;
    
    if (indexPath.row >= self.items.count) return nil;
    
    ItemInFolder *item = [self.items objectAtIndex:indexPath.row];
    
    return [MDUIUtils tableView:tableView contextMenuConfigurationForRowAtIndexPath:indexPath point:point targetInfo:item];
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator API_AVAILABLE(ios(13.0)) {
    UIViewController *vc = animator.previewViewController;
    
    if (vc) {
        [animator addCompletion:^{
            [MDUIUtils.visibleViewController.navigationController pushViewController:vc animated:YES];
        }];
    }
}

#pragma mark - setter/getter

- (MDFinishLoadingTipsView *)tipsV {
    if (!_tipsV) {
        _tipsV = [[MDFinishLoadingTipsView alloc] initWithFrame:CGRectMake(0, 0, self.tableV.frame.size.width, 600)];
        _tipsV.theme_backgroundColor = MOJiViewControllerViewBgColor;//通过tipsV的背景色盖住头部视图的背景图以阻止图片溢出时显示异常的问题出现
        _tipsV.autoresizingMask      = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tipsV.image                 = [UIImage imageNamed:@"img_none_collect"];
        _tipsV.title                 = NSLocalizedString(@"暂无收藏", nil);
    }
    return _tipsV;
}

@end
