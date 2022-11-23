//
//  HLTWebProgress.m
//  Snapshot
//
//  Created by cc on 2017/6/1.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import "HLTWebProgress.h"

#pragma mark - <BoBoProgressTimingFunction>

@protocol BoBoProgressTimingFunction <NSObject>

/**
 *  @brief 获取归一化时间t对应的归一化函数值，t超过max必返回上限值1
 *
 *  @param t   演进时间
 *  @param max 最大时间
 *
 *  @return 归一化进度值
 */
- (CGFloat)normalizedValueAtNormalizedTime:(CGFloat)t max:(CGFloat)max;

@end

#pragma mark - BoBoProgressTimingFunction

@interface BoBoProgressTimingFunction : NSObject <BoBoProgressTimingFunction>

- (CGFloat)normalizedValueAtNormalizedTime:(CGFloat)t max:(CGFloat)max;

- (CGFloat)normalizedValueAtTime:(CGFloat)t duration:(CGFloat)duration timeout:(CGFloat)timeout;

@end

@implementation BoBoProgressTimingFunction

- (CGFloat)normalizedValueAtTime:(CGFloat)t duration:(CGFloat)duration timeout:(CGFloat)timeout
{
    NSParameterAssert(duration != 0 && duration <= timeout);
    return [self normalizedValueAtNormalizedTime:(t / duration) max:timeout / duration];
}

- (CGFloat)normalizedValueAtNormalizedTime:(CGFloat)t max:(CGFloat)max
{
    CGFloat tx[6] = {0, 0.1/16, 1.0/16, 4.0/16, 8.0/16, 1};
    CGFloat vy[6] = {0, 0.09, 0.1, 0.6, 0.8, 0.9};  //TODO: 需修正（初始数值未考虑0.09）
    
    if (t >= max) {return 1.0;}
    if (t > tx[5]) {return vy[5];}
    
    for (NSInteger index = 0; index < 5; index ++)
    {
        CGFloat txi = tx[index];
        CGFloat txi1 = tx[index + 1];
        
        if (t < txi1)
        {
            CGFloat vyi = vy[index];
            CGFloat vyi1 = vy[index + 1];
            
            return vyi + (t - txi) * (vyi1 - vyi) / (txi1 -txi);
        }
    }
    
    return 0;
}

@end

#pragma mark - HTWebProgressEvolver

@interface HLTWebProgressEvolver : NSObject

@property (nonatomic,strong) id<BoBoProgressTimingFunction> timingFunction;// 也可使用CAMediaTimingFunction

@end

@implementation HLTWebProgressEvolver

+ (instancetype)wxEvolver
{
    HLTWebProgressEvolver *evolver = [[self alloc] init];
    evolver.timingFunction = [BoBoProgressTimingFunction new];
    
    return evolver;
}

- (float)progressAtTime:(CGFloat)time duration:(CGFloat)duration
{
    CGFloat const timeout = 2 * duration;
    return [self.timingFunction normalizedValueAtNormalizedTime:(time / duration) max:timeout / duration];
}

@end


@interface HLTWebProgress ()

@property (nonatomic,readwrite) CGFloat progress;

@property (nonatomic,readwrite) CGFloat duration;

@property (nonatomic,readwrite) CGFloat timeout;


@property (nonatomic,strong) HLTWebProgressEvolver *evolver;

@property (nonatomic,strong) CADisplayLink  *displayLink;

@property (nonatomic,assign) CGFloat loadingProgress;

@property (nonatomic,assign) CGFloat evolveProgress;

@property (nonatomic,assign) NSTimeInterval progressEvolveBeginTime;

@end

CGFloat const kHTWebProgressDuration  = 16;
CGFloat const kHTWebProgressTimeout   = 32;
CGFloat const kHTWebProgressInitValue = 0.05;

@implementation HLTWebProgress

- (instancetype)init
{
    return [self initWithDuration:kHTWebProgressDuration
                          timeout:kHTWebProgressTimeout];
}

- (instancetype)initWithDuration:(CGFloat)duration timeout:(CGFloat)timeout
{
    if (self = [super init]) {
        self.duration = duration;
        self.timeout = timeout;
        self.evolver = [HLTWebProgressEvolver wxEvolver];
    }
    
    return self;
}

#pragma mark - Public

//! 开始模拟进度
- (void)start
{
    self.progressEvolveBeginTime = 0;
    self.loadingProgress = kHTWebProgressInitValue;
    
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTimeRefresh:)];
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)updateEstimatedProgress:(CGFloat)estimateProgress
{
    if (estimateProgress <= self.loadingProgress) {
        return;
    }
    self.loadingProgress = estimateProgress;
    
    [self updateProgress];
}

#pragma mark - 更新进度

- (void)onTimeRefresh:(CADisplayLink *)displayLink
{
    if (self.progressEvolveBeginTime <= 0) {
        self.progressEvolveBeginTime = [NSDate timeIntervalSinceReferenceDate];
    }
    
    CGFloat const DURATION = self.duration;
    CGFloat const TIMEOUT = self.timeout;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.progressEvolveBeginTime > TIMEOUT + 0.1)
    {
        [displayLink invalidate];
        _displayLink = nil;
        return;
    }
    
    CGFloat value = [self.evolver progressAtTime:(now - self.progressEvolveBeginTime) duration:DURATION];
    self.evolveProgress = value;
    
    [self updateProgress];
}

- (void)updateProgress
{
    CGFloat progress = MAX(self.evolveProgress, self.loadingProgress);
    
    [self setProgress:progress];
    if (progress >= 1.0) {
        [self completeProgress];
    }
}

- (void)reset
{
    self.loadingProgress = 0;
    self.evolveProgress = 0;
    [_displayLink invalidate];
    _displayLink = nil;
    self.progressEvolveBeginTime = 0;
    
    //[self setProgress:0];
}

- (void)completeProgress
{
    self.loadingProgress = 1.0;
    if (self.progress < 1.0) {
        [self setProgress:1.0];
    }
    
    [self reset];
}

@end
