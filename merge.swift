@implementation MOJiCommentInputViewConfig
- (instancetype)init {
    if (self = [super init]) {
        _submitText        = NSLocalizedString(@"发送", nil);
        _placeholderText   = NSLocalizedString(@"我来说两句", nil);
        _limitNumber       = 200;
        _limitedSubmitBtn  = YES;
        _randomPlaceholder = NO;
    }
    return self;
}
@end

@implementation MOJiCarouselView

- (void)dealloc {
    [self stopTimer];
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initialize];
        [self configViews];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.collectionView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(MOJiCarouselViewFlowLayout.itemSize.height);
    }];
    
    [self.pageCtrl mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self).offset(self.flowLayout.pageWidth - self.pageCtrl.frame.size.width - 16);
    }];
}

- (void)initialize {
    self.scheduledTimerWithTimeInterval = MOJiCarouselViewTimeInterval;
    
    //进入前后台都需要激活或者暂停定时器
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground)  name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)appWillEnterForeground {
    [self configTimer];
}

- (void)appDidEnterBackground {
    [self stopTimer];
}

- (void)configViews {
    // 默认显示
    self.pageControlHidden = NO;
    self.flowLayout        = [[MOJiCarouselViewFlowLayout alloc] init];
    self.collectionView    = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.flowLayout];
    [self.collectionView registerClass:MOJiCarouselViewCell.class forCellWithReuseIdentifier:NSStringFromClass(MOJiCarouselViewCell.class)];
    self.collectionView.delegate                       = self;
    self.collectionView.dataSource                     = self;
    self.collectionView.decelerationRate               = UIScrollViewDecelerationRateFast;
    self.collectionView.showsVerticalScrollIndicator   = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.backgroundColor                = UIColor.clearColor;

    [self addSubview:self.collectionView];
    [self collectionVDidRemakeConstraints];
    
    self.pageCtrl                        = [[MOJiCarouselViewPageControl alloc] init];
    self.pageCtrl.userInteractionEnabled = NO;
    
    [self addSubview:self.pageCtrl];
    [self.pageCtrl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self);
        make.height.mas_equalTo(MOJiCarouselViewPageControl.pageControlHeight);
        make.bottom.mas_equalTo(self.collectionView);
    }];
}

- (void)stopTimer {
    if (!self.timer) return;
    
    [self.timer invalidate];
}

- (void)configTimer {
    [self stopTimer];
    
    if (self.models.count <= 1) return;
    
    self.timer = [[MDTimer alloc] init];
    [self.timer scheduledTimerWithTimeInterval:self.scheduledTimerWithTimeInterval target:self selector:@selector(autoScroll) userInfo:nil repeats:YES];
}

- (void)autoScroll {
    NSInteger   currentOffsetX  = (NSInteger)self.collectionView.contentOffset.x;
    NSInteger   pageWidth       = (NSInteger)self.flowLayout.pageWidth;
    CGFloat     toOffsetX       = (self.collectionView.contentOffset.x + self.flowLayout.pageWidth);

    //只要不等于0，说明位置偏移了，需要修正(下一次触发自动滚动时自动恢复正确位置)
    if (currentOffsetX % pageWidth != 0) {
        NSInteger pageIndex = currentOffsetX / pageWidth;
        toOffsetX           = (pageIndex + 1) * self.flowLayout.pageWidth;
    }

    [self setContentOffsetWithOffsetX:toOffsetX animated:YES];
}

- (void)setDefaultOffset {
    [self setContentOffsetWithOffsetX:(self.flowLayout.pageWidth * self.totalPage / 2) animated:NO];
}

- (void)setContentOffsetWithOffsetX:(CGFloat)offsetX animated:(BOOL)animated {
    [self setContentOffsetWithOffsetX:offsetX animated:animated shouldResetCurrentOffsetX:YES];
}

- (void)setContentOffsetWithOffsetX:(CGFloat)offsetX animated:(BOOL)animated shouldResetCurrentOffsetX:(BOOL)shouldResetCurrentOffsetX {
    if (animated) {
        [UIView animateWithDuration:0.6 animations:^{
            self.collectionView.contentOffset = CGPointMake(offsetX - 1, 0);
        } completion:^(BOOL finished) {
            self.collectionView.contentOffset = CGPointMake(offsetX, 0);
        }];
    } else {
        self.collectionView.contentOffset = CGPointMake(offsetX, 0);
    }

    if (shouldResetCurrentOffsetX) {
        self.currentOffsetX = offsetX;
    }
}

- (void)setModels:(NSArray<MOJiCarouselViewCellModel *> *)models {
    _models = models;
    
    self.pageCtrl.currentPage   = 0;
    self.pageCtrl.numberOfPages = models.count;
    
    [self.collectionView reloadData];
    
    //重新设置默认offset（等待contentSize配置后再设置默认offset）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setDefaultOffset];
    });
    
    //只有大于1的时候才需要重新配置定时器，否则停掉自动滚动
    if (self.models.count > 1) {
        //重新配置定时器
        [self configTimer];
        
        //重新配置约束
        [self collectionVDidRemakeConstraintsForMoreThanOneItem];
        
        self.collectionView.scrollEnabled = YES;
    } else {
        [self stopTimer];
        
        self.collectionView.scrollEnabled = NO;//只有一个的时候不给滚动操作
        
        [self collectionVDidRemakeConstraintsForOnlyOneItem];
    }
}

- (void)collectionVDidRemakeConstraintsForMoreThanOneItem {
    [self collectionVDidRemakeConstraints];
}

- (void)collectionVDidRemakeConstraintsForOnlyOneItem {
    [self.collectionView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.center.mas_equalTo(self);
        make.size.mas_equalTo(CGSizeMake(MOJiCarouselViewFlowLayout.itemSize.width + MOJiCarouselViewFlowLayout.minimumLineSpacing * 2, MOJiCarouselViewFlowLayout.itemSize.height));
    }];
}

- (void)collectionVDidRemakeConstraints {
    [self.collectionView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.center.width.mas_equalTo(self);
        make.height.mas_equalTo(MOJiCarouselViewFlowLayout.itemSize.height);
    }];
}

- (void)scrollToItemAtIndex:(NSInteger)atIndex {
    [self setContentOffsetWithOffsetX:(self.flowLayout.pageWidth * (self.totalPage / 2 + atIndex)) animated:NO];
}


#pragma mark - delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.totalPage;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MOJiCarouselViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(MOJiCarouselViewCell.class) forIndexPath:indexPath];
    [cell updateCellWithModel:self.models[indexPath.row % self.models.count] titleToRightConst:-self.pageCtrl.frame.size.width - 32];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.didSelectItemAtIndexBlock) {
        self.didSelectItemAtIndexBlock(indexPath.row % self.models.count);
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return MOJiCarouselViewFlowLayout.itemSize;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    //每次停下来记录索引，方便横竖屏切换时，保持展示当前item
    self.currentOffsetX = scrollView.contentOffset.x;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self configTimer];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.models.count == 0) return; //这里如果没有数据源，不往下执行
    
    //这里过一半就表示下一页（优化体验）
    self.pageCtrl.currentPage = ((NSInteger)(roundf(scrollView.contentOffset.x / self.flowLayout.pageWidth)) % self.models.count);
    CGFloat toOffsetX         = (self.collectionView.contentOffset.x + self.flowLayout.pageWidth);
    
    if (toOffsetX >= self.flowLayout.pageWidth * (self.models.count * MOJiCarouselViewCellMultipleNumber - 1)) {
        toOffsetX = self.flowLayout.pageWidth * self.totalPage / 2 - self.flowLayout.pageWidth;
        [self setContentOffsetWithOffsetX:toOffsetX animated:NO];
    }
}

- (NSInteger)totalPage {
    return MOJiCarouselViewCellMultipleNumber * self.models.count;
}

+ (CGFloat)viewHeight {
    return MOJiCarouselViewFlowLayout.itemSize.height;
}

// MARK: - 开关控制相关
- (void)setPageControlHidden:(BOOL)pageControlHidden {
    _pageControlHidden = pageControlHidden;
    
    [self.pageCtrl setHidden:pageControlHidden];
}

@end

