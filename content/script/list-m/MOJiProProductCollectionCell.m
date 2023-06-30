//
//  MOJiProProductCollectionCell.m
//  MOJiDict
//
//  Created by Ji Xiang on 2022/2/21.
//  Copyright © 2022 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiProProductCollectionCell.h"
#import "MOJiProProductCollectionCellModel.h"

@interface MOJiProProductCollectionCell ()
@property (weak, nonatomic) IBOutlet UIView *contentV;
@property (weak, nonatomic) IBOutlet UIView *cornerV;
@property (weak, nonatomic) IBOutlet UILabel *titleL;
@property (weak, nonatomic) IBOutlet UILabel *currencyL;
@property (weak, nonatomic) IBOutlet UILabel *priceL;
@property (weak, nonatomic) IBOutlet UILabel *oneMonthPriceL;
@property (weak, nonatomic) IBOutlet UILabel *discountL;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cons_currencyLWidth;

@end

@implementation MOJiProProductCollectionCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self configViews];
}

- (void)configViews {
    self.discountL.layer.cornerRadius = 6.f;
    self.discountL.hidden             = YES;
    
    self.priceL.font = [MOJiProProductCollectionCell priceFont];
}

- (void)setModel:(MOJiProProductCollectionCellModel *)model {
    _model = model;
    
    self.currencyL.text               = model.currencyStr;
    CGFloat currencyWidth             = [MUIPureTools expectedSizeWithText:self.currencyL.text font:self.currencyL.font maxWidth:CGFLOAT_MAX].width + 1.f;
    self.cons_currencyLWidth.constant = currencyWidth;
    
    self.titleL.text = model.title;
    self.priceL.text = model.price;
    
    if (model.oneMonthPrice.length > 0) {
        self.oneMonthPriceL.text = [NSString stringWithFormat:@"%@%@/月", model.currencyStr, model.oneMonthPrice];
    } else {
        self.oneMonthPriceL.text = @"";
    }
    
    if (model.discountMsg.length > 0) {
        self.discountL.hidden = NO;
        self.discountL.text   = MOJiChineseLocalizedString(model.discountMsg);
    } else {
        self.discountL.hidden = YES;
        self.discountL.text   = nil;
    }
    
    if (model.isSelected) {
        self.priceL.textColor    = UIColorFromHEX(0xFF5252);
        self.currencyL.textColor = UIColorFromHEX(0xFF5252);
    } else {
        self.priceL.textColor    = UIColorFromHEX(0xACACAC);
        self.currencyL.textColor = UIColorFromHEX(0xACACAC);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 *  NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setCornerRadius];
    });
}

- (void)setCornerRadius {
    CGFloat cornerDefault = 12.f;
    CGFloat cornerMax     = 40.f;
    UIColor *lineColor    = self.model.isSelected ? UIColorFromHEX(0xFF5252) : UIColorFromHEX(0xECECEC);
    
    [MDUIUtils setRoundCornerWithView:self.cornerV
                                frame:self.cornerV.bounds
                        leftTopCorner:cornerDefault
                       rightTopCorner:cornerMax
                     leftBottomCorner:cornerDefault
                    rightBottomCorner:cornerDefault
                            lineWidth:6.f
                            lineColor:lineColor];
}

+ (UIFont *)currencyFont {
    return BoldFontSize(20);
}

+ (UIFont *)priceFont {
    return [UIFont gilroyExtraBoldFontOfSize:32];
}

+ (CGFloat)priceMinWidth {
    return 72.f;
}

+ (CGFloat)defaultWithoutCurrenyAndPrice {
    return 42.f;
}

+ (CGFloat)cellColumnSpace {
    return 8.f;
}

+ (CGSize)cellSize {
    return CGSizeMake(126.f, 148.f);
}

@end
