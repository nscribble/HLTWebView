//
//  HLTWebProgress.h
//  Snapshot
//
//  Created by cc on 2017/6/1.
//  Copyright © 2017年 Jason. All rights reserved.
//  加载进度演示（效果参考wx，需调参数）

#import <Foundation/Foundation.h>

//! 默认时长（16s）
extern CGFloat const kHTWebProgressDuration;
//! 默认超时时间（32s）
extern CGFloat const kHTWebProgressTimeout;

@interface HLTWebProgress : NSObject

//! 展示进度
@property (nonatomic,readonly) CGFloat progress;

//! 加载时长（一般设定为网络加载超时时间的一半）
@property (nonatomic,readonly) CGFloat duration;
//! 进度超时时间（一般设定为网络超时时间）
@property (nonatomic,readonly) CGFloat timeout;


- (instancetype)initWithDuration:(CGFloat)duration timeout:(CGFloat)timeout;

//! 开始计算进度
- (void)start;
//! 更新实际（预测）加载进度
- (void)updateEstimatedProgress:(CGFloat)estimateProgress;

@end
