//
//  HLTWebProgressView.m
//  Snapshot
//
//  Created by nscribble on 2017/7/5.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import "HLTWebProgressView.h"

#pragma mark - HTWebProgressView

@interface HLTWebProgressView ()

//! 进度视图
@property (nonatomic,strong) UIView *indicatorView;
//! 当前进度
@property (nonatomic,assign) CGFloat progress;

@end

@implementation HLTWebProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    if (newSuperview) {
        [self setup];
    }
}

#pragma mark - 属性

- (UIView *)indicatorView {
    if (!_indicatorView) {
        CGRect rect = self.bounds;
        rect.size.width = 0;
        _indicatorView = [[UIView alloc] initWithFrame:rect];
    }
    
    return _indicatorView;
}

#pragma mark - Private

- (void)setup  {
    [self addSubview:self.indicatorView];
    self.indicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

    UIColor *tintColor = [UIColor colorWithRed:0xd7/255.0 green:0x13/255.0 blue:0x39/255.0 alpha:1];// d71339
    
    if ([UIApplication.sharedApplication.delegate.window respondsToSelector:@selector(setTintColor:)] && UIApplication.sharedApplication.delegate.window.tintColor) {
        tintColor = UIApplication.sharedApplication.delegate.window.tintColor;
    }
    self.indicatorView.backgroundColor = tintColor;
}

#pragma mark - HTWebProgressView

- (void)updateProgress:(CGFloat)progress {
    [self setProgress:progress animated:YES];
}

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated {
    BOOL isGrowing = progress > _progress;
    
    CGRect frame = self.indicatorView.frame;
    frame.size.width = progress * self.bounds.size.width;
    
    if (isGrowing && animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.indicatorView.frame = frame;
        } completion:^(BOOL finished) {
            if (progress >= 1.0){
                [UIView animateWithDuration:animated ? 0.25 : 0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    self.indicatorView.alpha = 0;
                } completion:^(BOOL finished) {
                    CGRect frame = self.indicatorView.frame;
                    frame.size.width = 0;
                    self.indicatorView.frame = frame;
                }];
            }
        }];
    }
    else {
        self.indicatorView.frame = frame;
    }
    
    if (self.indicatorView.alpha <= 0) {
        [UIView animateWithDuration:animated ? 0.25 : 0 animations:^{
            self.indicatorView.alpha = 1;
        } completion:NULL];
    }
}

@end
