//
//  MOJiProHomeVC.m
//  MOJiDict
//
//  Created by Ji Xiang on 2022/2/21.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiProHomeVC.h"
#import "MOJiProListVC.h"
#import "MOJiMenuListView.h"
#import "MOJiPurchaseHistoryVC.h"
#import "MOJiProSegmentedControl.h"

static CGFloat const MOJiProHomeVCEmptyCellHeight = 88.f;

@interface MOJiProHomeVC () <UITableViewDelegate, UITableViewDataSource, UIPageViewControllerDelegate, UIPageViewControllerDataSource, MDSegmentedControlDelegate, UITextViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *navBar;
@property (weak, nonatomic) IBOutlet MDButton *backBtn;
@property (weak, nonatomic) IBOutlet MDButton *moreBtn;
@property (weak, nonatomic) IBOutlet MDButton *restoreBtn;

@property (weak, nonatomic) IBOutlet UIView *topV;
@property (weak, nonatomic) IBOutlet UIView *cardV;
@property (weak, nonatomic) IBOutlet UIImageView *titleImageV;
@property (weak, nonatomic) IBOutlet UIImageView *proImageV;
@property (weak, nonatomic) IBOutlet UILabel *titleL;
@property (weak, nonatomic) IBOutlet UILabel *descL;
@property (weak, nonatomic) IBOutlet UILabel *nameL;

@property (weak, nonatomic) IBOutlet UIView *bottomV;
@property (weak, nonatomic) IBOutlet MDButton *proBtn;
@property (weak, nonatomic) IBOutlet UILabel *proTitleL;
@property (weak, nonatomic) IBOutlet UILabel *proPriceL;
@property (weak, nonatomic) IBOutlet UILabel *proHavedL;
@property (weak, nonatomic) IBOutlet UITextView *proDescTextV;

@property (weak, nonatomic) IBOutlet UIView *cornerV;
@property (weak, nonatomic) IBOutlet UITableView *tableV;
@property (nonatomic, strong) MOJiMenuListView *menuListV;

@property (nonatomic, strong) MOJiProListVC *vipVC;
@property (nonatomic, strong) MOJiProListVC *subscriptionVC;

@property (nonatomic, strong) UIPageViewController *pageVC;
@property (nonatomic, strong) MOJiProSegmentedControl *segCtrl;
@property (nonatomic, strong) NSArray *listVCs;
@property (nonatomic, strong) NSArray *vcTitles;
@property (nonatomic, weak) id selectedVC;
@end

@implementation MOJiProHomeVC

- (void)dealloc {
    [MFKHelper removeScene];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColorFromHEX(0xE2E4E9);
    [self initialize];
    [self configViews];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [self.view layoutIfNeeded]; //需要加上这句，不然segCtrl的宽度会出问题
    
    UIBezierPath *path2      = [UIBezierPath bezierPathWithRoundedRect:self.segCtrl.bounds
                                                     byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                           cornerRadii:CGSizeMake(16, 16)];
    CAShapeLayer *maskLayer2 = [CAShapeLayer layer];
    maskLayer2.frame         = self.segCtrl.bounds;
    maskLayer2.path          = path2.CGPath;
    self.segCtrl.layer.mask  = maskLayer2;
    
    UIBezierPath *path       = [UIBezierPath bezierPathWithRoundedRect:self.cornerV.bounds
                                                     byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                           cornerRadii:CGSizeMake(16, 16)];
    CAShapeLayer *maskLayer  = [CAShapeLayer layer];
    maskLayer.frame          = self.cornerV.bounds;
    maskLayer.path           = path.CGPath;
    maskLayer.masksToBounds  = YES;
    self.cornerV.layer.mask  = maskLayer;
}

// 本页面不支持主题切换
- (BOOL)theme_supportsThemeSwitching {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (@available(iOS 13.0, *)) {
        return UIStatusBarStyleDarkContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)initialize {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProInfo) name:MDUpdateUserProInfoBySKPaymentTransactionDeferredNotification object:nil];
}

- (void)configViews {
    [self.backBtn addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.moreBtn addTarget:self action:@selector(moreAction) forControlEvents:UIControlEventTouchUpInside];
    [self.restoreBtn addTarget:self action:@selector(restore) forControlEvents:UIControlEventTouchUpInside];
    [self.restoreBtn setTitle:NSLocalizedString(@"恢复购买", nil) forState:UIControlStateNormal];
    self.restoreBtn.highlightColor = UIColor.clearColor;
    
    [self configTopView];
    [self configCornerView];
    [self configMenuListV];
    [self configBottomView];
}

- (void)configTopView {
    self.cardV.layer.cornerRadius = 20.f;
    self.descL.text               = NSLocalizedString(@"会员特权支持全平台，常用常新", nil);
    self.nameL.text               = [NSString stringWithFormat:@"ID：@%@", MOJiChineseLocalizedString(MDUserHelper.currentUsername)];
    [self updateCardViewByCurrentVCType];
}

- (void)configCornerView {
    self.tableV.delegate                       = self;
    self.tableV.dataSource                     = self;
    self.tableV.showsVerticalScrollIndicator   = NO;
    self.tableV.showsHorizontalScrollIndicator = NO;
    self.tableV.scrollsToTop                   = NO;
    self.tableV.separatorStyle                 = UITableViewCellSeparatorStyleNone;
    self.tableV.backgroundColor                = [UIColor clearColor];
    self.tableV.estimatedRowHeight             = 100.f;   //要设置默认值，不然会报约束警告
    
    id vc = [self.listVCs objectAtIndex:self.currentVCType];
    
    [self.pageVC setViewControllers:@[vc] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    self.selectedVC = vc;
    
    [self.segCtrl layoutIfNeeded];  //self.segCtrl.selectedIndex设置的时候，frame还没有及时刷新，所以需要layoutIfNeeded
    self.segCtrl.selectedIndex = self.currentVCType;
    
    UIScrollView *scrollV = [self findScrollView];
    scrollV.scrollsToTop  = NO;
    scrollV.delegate      = self;
//    scrollV.bounces       = NO;//暂时先注掉，防止无法左右拖拽
    
    [self.tableV reloadData];//刷新一下，防止sectionHeaderView会飘
}

- (void)configBottomView {
    self.proBtn.layer.cornerRadius = 25.f;
    self.proBtn.highlightColor     = [UIColor colorWithWhite:1 alpha:0.5];
    self.proBtn.followTouchPoint   = YES;
    [self.proBtn addTarget:self action:@selector(upgradeProAction) forControlEvents:UIControlEventTouchUpInside];
    
    self.proDescTextV.attributedText                    = [self getDescAttributedString];
    self.proDescTextV.delegate                          = self;
    self.proDescTextV.textContainerInset                = UIEdgeInsetsZero;
    self.proDescTextV.textContainer.lineFragmentPadding = 0;
    
    self.proHavedL.text = NSLocalizedString(@"你已是基础会员", nil);
    self.proPriceL.font = [UIFont gilroyExtraBoldFontOfSize:23];
    
    [self updateBottomViewByCurrentVCType];
}

- (NSAttributedString *)getDescAttributedString {
    NSString *linkString       = @"";
    NSString *subscriptionDesc = @"";
    NSString *protocolPrefix   = MOJiUserServiceProtocolPrefix;
    
    if (self.currentVCType == MOJiProTypeVip) {
        linkString       = NSLocalizedString(@"会员服务协议", nil);
        subscriptionDesc = NSLocalizedString(@"同意 会员服务协议", nil);
    } else {
        linkString       = NSLocalizedString(@"自动续费协议", nil);
        subscriptionDesc = NSLocalizedString(@"同意 自动续费协议，到期自动续费，可随时取消", nil);
    }
    
    NSRange linkRange                       = [subscriptionDesc rangeOfString:linkString];
    NSMutableAttributedString *resultString = [MDCommonHelper getAttributedStringByContent:subscriptionDesc
                                                                              textAligment:NSTextAlignmentCenter
                                                                               lineSpacing:4
                                                                                      font:FontSize(12)
                                                                                     color:UIColorFromHEX(0xACACAC)];
                                                
    [resultString addAttribute:NSLinkAttributeName value:[NSURL URLWithString:protocolPrefix] range:linkRange];
    
    return resultString;
}

- (void)configMenuListV {
    NSArray <MOJiMenuListItem *> *items = MOJiMenuList.purchaseMenuListItems;
    CGSize listVSize                    = [MOJiMenuListView viewSizeWithItemCount:items.count arrowLocaion:MOJiMenuListViewArrowLocationUpRight];
    self.menuListV                      = [[MOJiMenuListView alloc] initWithItems:items showLatest:NO arrowLocaion:MOJiMenuListViewArrowLocationUpRight];
    
    [self.view insertSubview:self.menuListV aboveSubview:self.navBar];
    
    @weakify(self)
    self.menuListV.tableV.didSelectItemBlock = ^(MOJiMenuListItem * _Nonnull item) {
        @strongify(self)
        
        [self menuListVDidSelectItem:item];
    };
    
    [self.menuListV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.navBar.mas_bottom);
        make.right.mas_equalTo(self.view).offset(-8);
        make.size.mas_equalTo(listVSize);
    }];
    
    //适配iPhone SE及以下设备
    if (SCREEN_MAX_LENGTH <= 568) {
        CGSize tmpListVSize = listVSize;
        tmpListVSize.height -= 80;
        [self.menuListV mas_updateConstraints:^(MASConstraintMaker *make) {
            make.size.mas_equalTo(tmpListVSize);
        }];
    }
}

- (UIScrollView *)findScrollView {
    UIScrollView *scrollView;
    for (id subview in self.pageVC.view.subviews) {
        if ([subview isKindOfClass:UIScrollView.class]) {
            scrollView = subview;
            break;
        }
    }
    return scrollView;
}

#pragma mark - Action

- (void)updateProInfo {
    [self updateBottomViewByCurrentVCType];
}

- (void)updateCardViewByCurrentVCType {
    if (self.currentVCType == MOJiProTypeVip) {
        self.cardV.backgroundColor = UIColorFromHEX(0xF2F2F2);
        self.titleImageV.image     = [UIImage imageNamed:@"img_card_moji_black"];
        self.proImageV.image       = [UIImage imageNamed:@"img_card_pro_white"];
        self.titleL.text           = @"辞書";
        self.titleL.textColor      = UIColorFromHEX(0x3A3A3A);
        self.descL.textColor       = UIColorFromHEX(0x8B8787);
        self.nameL.textColor       = UIColorFromHEX(0x3A3A3A);
    } else {
        self.cardV.backgroundColor = UIColorFromHEX(0x323233);
        self.titleImageV.image     = [UIImage imageNamed:@"img_card_moji_white"];
        self.proImageV.image       = [UIImage imageNamed:@"img_card_pro_black"];
        self.titleL.text           = @"辞書 Pro";
        self.titleL.textColor      = UIColorFromHEX(0xFAFAFA);
        self.descL.textColor       = UIColorFromHEX(0xACACAC);
        self.nameL.textColor       = UIColorFromHEX(0xFAFAFA);
    }
}

- (void)updateBottomViewByCurrentVCType {
    if (self.currentVCType == MOJiProTypeVip) {
        if (MDUserHelper.didPurchaseMOJiProUpgrade) {
            self.proHavedL.hidden = NO;
            self.proTitleL.hidden = YES;
            self.proPriceL.hidden = YES;
            
            self.proBtn.backgroundColor        = UIColorFromHEX(0xACACAC);
            self.proBtn.userInteractionEnabled = NO;
        } else {
            self.proHavedL.hidden = YES;
            self.proTitleL.hidden = NO;
            self.proPriceL.hidden = NO;
            self.proTitleL.text   = [NSString stringWithFormat:@"%@  ·  %@", NSLocalizedString(@"终身买断", nil), self.vipVC.currentModel.currencyStr];
            self.proPriceL.text   = self.vipVC.currentModel.price;
            
            self.proBtn.backgroundColor        = UIColorFromHEX(0xFF5252);
            self.proBtn.userInteractionEnabled = YES;
        }
    } else { // 高级会员可以一直购买，不显示【你已是高级会员】
        self.proHavedL.hidden = YES;
        self.proTitleL.hidden = NO;
        self.proPriceL.hidden = NO;
        
        self.proBtn.backgroundColor        = UIColorFromHEX(0xFF5252);
        self.proBtn.userInteractionEnabled = YES;
        
        NSString *titleStr  = MDUserHelper.didPurchaseSubscriptionProduct ? NSLocalizedString(@"立即续费", nil) : NSLocalizedString(@"立即购买", nil);
        self.proTitleL.text = [NSString stringWithFormat:@"%@  ·  %@", titleStr, self.subscriptionVC.currentModel.currencyStr];
        self.proPriceL.text = self.subscriptionVC.currentModel.price;
    }
    
    self.proDescTextV.attributedText = [self getDescAttributedString];
}

- (void)upgradeProAction {
    if (self.currentVCType == MOJiProTypeVip) {
        [self upgradeVipAction];
    } else {
        [self upgradeSubscriptionAction];
    }
    
    [MFKHelper addFKSceneWithProType:self.currentVCType];
}

- (void)upgradeVipAction {
    if (![MDConfigHelper getMOJiProUpgradePrice]) {
        [self showTipsWithNoGettingProPrice];
        return;
    }
    
    //这里去掉主项目loading事件，框架已经实现了loading
    @weakify(self)
    [MFKHelper FKProductWithProductId:MOJI_JISO_PRO_UPGRADE_ID_appstore proType:MOJiProTypeVip completion:^(BOOL result, NSString * _Nonnull info) {
        @strongify(self)
        
        if (result) {
            [self updateBottomViewByCurrentVCType];
        }
    }];
}

- (void)upgradeSubscriptionAction {
    MOJI_DICT_SUBSCRIPTION subscriptionProductId = self.subscriptionVC.currentModel.appStorePid;
    
    if (![MDConfigHelper getSubscriptionProductPriceWithSubscriptionProductId:subscriptionProductId]) {
        [self showTipsWithNoGettingProPrice];
        return;
    }
    
    //这里去掉主项目loading事件，框架已经实现了loading
    @weakify(self)
    [MFKHelper FKProductWithProductId:subscriptionProductId proType:MOJiProTypeSubscription completion:^(BOOL result, NSString * _Nonnull info) {
        @strongify(self)
        
        if (result) {
            [self updateBottomViewByCurrentVCType];
        }
    }];
}

- (void)showTipsWithNoGettingProPrice {
    MOJiAlertViewAction *know = [MOJiAlertViewAction actionWithTitle:NSLocalizedString(@"知道啦", nil) titleColor:[MOJiAlertView alertViewButtonRedColor] handler:nil];
    MOJiAlertView *alertV     = [MOJiAlertView alertViewWithTitle:NSLocalizedString(@"获取商品中，请重启App再尝试哦", nil) message:nil actions:@[know]];
    [self presentViewController:alertV animated:YES completion:nil];
}

- (void)moreAction {
    if (self.menuListV.alpha > 0) {
        [self.menuListV hide];
    } else {
        [self.menuListV showInView:self.view];
    }
}

- (void)menuListVDidSelectItem:(MOJiMenuListItem *)item {
    self.menuListV.tableV.selectedItem = item;
    [self.menuListV hide];
    
    if (item.targetType == MOJiMenuList.targetTypePurchaseRecord) {
        [self purchaseHistory];
    } else if (item.targetType == MOJiMenuList.targetTypeContact) {
        [self contact];
    }
}

- (void)purchaseHistory {
    if (MOJiUser.currentUser) {
        MOJiPurchaseHistoryVC *vc = (MOJiPurchaseHistoryVC *)[MDUIUtils xibVCWithClass:MOJiPurchaseHistoryVC.class];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        [MDUIUtils presentLoginVC];
    }
}

- (void)restore {
    /*
     说明：该地方只是简单的更新按钮的状态
     */
    @weakify(self)
    [MDConfigHelper restorePurchases:^(BOOL result) {
        @strongify(self)
        
        if (result) {
            [self updateBottomViewByCurrentVCType];
        }
    }];
}

- (void)contact {
    [MDMeHelper followUsFromCtrl:self];
}

#pragma mark - delegate
#pragma mark - TextView delegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction {
    NSString *absoluteString = URL.absoluteString;
    
    if ([absoluteString hasPrefix:MOJiUserServiceProtocolPrefix]) {
        [MDUIUtils pushWebSearchVCWithUrl:MOJiSubscriptionAgreementUrl];
    }
    
    return NO;
}

#pragma mark - ScrollView Delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([scrollView isMemberOfClass:NSClassFromString(@"_UIQueuingScrollView")]) {
        [self setupSubTableViewScrollEnabled:NO];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([scrollView isMemberOfClass:NSClassFromString(@"_UIQueuingScrollView")]) {
        [self setupSubTableViewScrollEnabled:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([scrollView isMemberOfClass:NSClassFromString(@"_UIQueuingScrollView")]) return;
    
    CGFloat offsetY = scrollView.contentOffset.y;
    
    //标记主列表的位置
    if (offsetY >= (scrollView.contentSize.height - scrollView.height - 0.5)) {
        self.offsetType = MOJiOffsetTypeMax;
    } else if (scrollView.contentOffset.y <= 0) {
        self.offsetType = MOJiOffsetTypeMin;
    } else {
        self.offsetType = MOJiOffsetTypeCenter;
    }
    
    //当子列表刚好拖到顶部的时候，或者更多，那么主列表就要固定住
    [self setupScrollViewContentOffsetWhenOffsetTypeIsCenterWithScrollView:scrollView];
}

- (void)setupScrollViewContentOffsetWhenOffsetTypeIsCenterWithScrollView:(UIScrollView *)scrollView {
    id tempVC = nil;
    for (NSInteger i = 0; i < self.listVCs.count; i++) {
        if ([[self.pageVC.viewControllers firstObject] isEqual:self.listVCs[i]]) {
            tempVC = self.listVCs[i];
            break;
        }
    }
    
    MOJiOffsetType offsetType = (MOJiOffsetType)[tempVC offsetType];
    
    if (offsetType == MOJiOffsetTypeCenter && [[self.pageVC.viewControllers firstObject] isEqual:tempVC]) {
        CGFloat contentOffset    = scrollView.contentSize.height - scrollView.height;
        scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, contentOffset);
    }
}

- (void)setupSubTableViewScrollEnabled:(BOOL)enabled {
    for (NSInteger i = 0; i < self.listVCs.count; i++) {
        id vc                = self.listVCs[i];
        UITableView *tableV  = (UITableView *)[vc tableV];
        tableV.scrollEnabled = enabled;
    }
}

- (void)subTableViewDidScrollToTop {
    for (NSInteger i = 0; i < self.listVCs.count; i++) {
        id vc               = self.listVCs[i];
        UITableView *tableV = (UITableView *)[vc tableV];
        [tableV setContentOffset:CGPointZero];
    }
}

#pragma mark UIPageViewController delegate

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger index = [self.listVCs indexOfObject:viewController];
    index          -= 1;
    
    if (index < 0) { return nil; }
    
    return self.listVCs[index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(nonnull UIViewController *)viewController{
    NSInteger index = [self.listVCs indexOfObject:viewController];
    index          += 1;
    
    if (index >= self.listVCs.count) { return nil; }
    
    return self.listVCs[index];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed {
    if (completed && finished) {
        id vc                      = [pageViewController.viewControllers firstObject];
        self.selectedVC            = vc;
        NSInteger index            = [self.listVCs indexOfObject:vc];
        self.segCtrl.selectedIndex = index;
        self.currentVCType         = index;
        [self updateCardViewByCurrentVCType];
        [self updateBottomViewByCurrentVCType];
    }
}

- (void)md_segmentedControl:(MOJiProSegmentedControl *)ctrl didSelectItemAtIndex:(NSInteger)index {
    id vc = self.listVCs[index];
    
    if ([self.selectedVC isEqual:vc]) { return; }
    
    [self.pageVC setViewControllers:@[vc] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    self.selectedVC            = vc;
    self.segCtrl.selectedIndex = index;
    self.currentVCType         = index;
    [self updateCardViewByCurrentVCType];
    [self updateBottomViewByCurrentVCType];
}

#pragma mark - TableView Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MOJiProHomeVCTableViewSectionAll;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MOJiProHomeVCTableViewSectionEmpty) {
        UITableViewCell *cell = [[UITableViewCell alloc] init];
        cell.backgroundColor  = UIColor.clearColor;
        cell.selectionStyle   = UITableViewCellSelectionStyleNone;
        return cell;
    } else {
        static NSString *identify = @"helloCell";
        UITableViewCell *cell     = [tableView dequeueReusableCellWithIdentifier:identify];
        
        if (!cell) {
            cell                   = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
            cell.backgroundColor   = self.bgColor;
            cell.selectionStyle    = UITableViewCellSelectionStyleNone;
            self.pageVC.view.frame = cell.contentView.bounds;
            [cell.contentView addSubview:self.pageVC.view];
            [self addChildViewController:self.pageVC];
        }
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MOJiProHomeVCTableViewSectionEmpty) {
        return MOJiProHomeVCEmptyCellHeight;
    } else {
        return self.tableV.height - [MOJiProSegmentedControl ctrlHeight];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == MOJiProHomeVCTableViewSectionEmpty) {
        UIView *view         = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        return view;
    } else {
        return self.segCtrl;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == MOJiProHomeVCTableViewSectionEmpty) {
        return CGFLOAT_MIN;
    } else {
        return [MOJiProSegmentedControl ctrlHeight];
    }
}

#pragma mark - getter/setter

- (UIColor *)bgColor {
    return UIColorFromHEX(0xF8F8F8);
}

- (MOJiProSegmentedControl *)segCtrl {
    if (!_segCtrl) {
        _segCtrl                     = [[MOJiProSegmentedControl alloc] initWithItems:self.vcTitles];
        _segCtrl.backgroundColor     = self.bgColor;
        _segCtrl.separatorLineHidden = YES;
        _segCtrl.delegate            = self;
    }
    return _segCtrl;
}

- (UIPageViewController *)pageVC {
    if (!_pageVC) {
        _pageVC = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                options:nil];
        _pageVC.delegate              = self;
        _pageVC.dataSource            = self;
        _pageVC.view.backgroundColor  = [UIColor clearColor];
        _pageVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [MDUIUtils setupSubviewsGestureRecognizerDisabledWithSubViews:_pageVC.view.subviews fromCtrl:self];
    }
    return _pageVC;
}

- (MOJiProListVC *)vipVC {
    if (!_vipVC) {
        _vipVC          = (MOJiProListVC *)[MDUIUtils xibVCWithClass:MOJiProListVC.class];
        _vipVC.parentVC = self;
        _vipVC.proType  = MOJiProTypeVip;
        
        @weakify(self)
        _vipVC.didSelectProductBlock = ^(MOJiProProductCollectionCellModel * _Nonnull model) {
            @strongify(self)
            
            [self updateBottomViewByCurrentVCType];
        };
    }
    return _vipVC;
}

- (MOJiProListVC *)subscriptionVC {
    if (!_subscriptionVC) {
        _subscriptionVC              = (MOJiProListVC *)[MDUIUtils xibVCWithClass:MOJiProListVC.class];
        _subscriptionVC.parentVC     = self;
        _subscriptionVC.proType      = MOJiProTypeSubscription;
        _subscriptionVC.currentIndex = self.subscriptionIndex;
        
        @weakify(self)
        _subscriptionVC.didSelectProductBlock = ^(MOJiProProductCollectionCellModel * _Nonnull model) {
            @strongify(self)
            
            [self updateBottomViewByCurrentVCType];
        };
    }
    
    return _subscriptionVC;
}

- (NSArray *)listVCs {
    if (!_listVCs) {
        _listVCs = @[self.vipVC, self.subscriptionVC];
    }
    return _listVCs;
}

- (NSArray *)vcTitles {
    if (!_vcTitles) {
        _vcTitles = @[NSLocalizedString(@"基础会员", nil), NSLocalizedString(@"高级会员", nil)];
    }
    return _vcTitles;
}

@end
