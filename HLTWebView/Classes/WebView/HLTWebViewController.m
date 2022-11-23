//
//  HLTWebViewController.m
//  Snapshot
//
//  Created by cc on 2017/5/31.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import "HLTWebViewController.h"
#import "HLTWebProgress.h"
#import "HLTJavaScriptBridge.h"
#import "HLTWebProgressViewProtocol.h"
#import "HLTWebView.h"
#import "HLTWebProgressView.h"

@import WebKit;

NSInteger const HTKVOContextWebviewProgress = 1;
NSInteger const HTKVOContextWebviewTitle = 2;
NSInteger const HTKVOContextWebviewIsLoading = 3;
NSInteger const HTKVOContextLoadingProgress = 4;

#pragma mark HTWebProgressView

@interface UIProgressView (HTWebProgressView)<HLTWebProgressView>

@end

@implementation UIProgressView (HTWebProgressView)

- (void)updateProgress:(CGFloat)progress
{
    [self setProgress:progress animated:YES];
}

@end

#pragma mark - HLTWebViewController

@interface HLTWebViewController ()

@property (nonatomic,strong,readwrite) HLTWebView *htWebview;
@property (nonatomic,strong) WKWebViewConfiguration *webviewConfiguration;
@property (nonatomic,strong) NSURLRequest *request;

@property (nonatomic,strong) HLTWebProgress *progress;
@property (nonatomic,strong) UIView<HLTWebProgressView> *progressView;
@property (nonatomic,assign) BOOL autoLoadRequest;// 是否自动加载请求

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"

@implementation HLTWebViewController

#pragma clang diagnostic pop

#pragma mark - 生命周期

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithRequest:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithRequest:nil];
}

- (instancetype)initWithRequestURL:(NSURL *)URL {
    return [self initWithRequest:[NSURLRequest requestWithURL:URL]];
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    if (self = [super initWithNibName:nil bundle:nil]) {
        _request = [self configuredRequestForRequest:request];
        
        // 默认使用BaseController的自定义导航栏样式
        _usingCustomNavBar = YES;
        _usingWebTitle = YES;
        _autoLoadRequest = YES;
        _allowsBackForwardNavigationGestures = YES;
        _showProgressView = NO;
        _shouldReload = YES;
    }
    
    return self;
}

- (void)dealloc {
    [self.webview removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
    [self.webview removeObserver:self forKeyPath:NSStringFromSelector(@selector(title))];
    [self.webview removeObserver:self forKeyPath:NSStringFromSelector(@selector(isLoading))];
    [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(progress))];
    
    [_htWebview clear];
    _htWebview = nil;
}

// 添加缓存策略+超时等控制
- (NSURLRequest *)configuredRequestForRequest:(NSURLRequest *)request {
#if DEBUG
    NSMutableURLRequest *confRequest = [request mutableCopy];
    confRequest.cachePolicy = NSURLRequestUseProtocolCachePolicy;
    confRequest.timeoutInterval = kHTWebProgressTimeout;
    request = [confRequest copy];
#endif
    return request;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addWebview];
    [self addProgressView];
    [self _layoutViewContraints];
    [self addWebviewObserver];
    
    self.usingWebTitle = !(self.title && self.title.length > 0);
    if (self.autoLoadRequest) {
        [self loadRequest];
    }
    [self.jsBridge preparedForJSEvent];
}

- (UIRectEdge)edgesForExtendedLayout {
    return UIRectEdgeNone;
}

#pragma mark - Initialization

- (void)addWebview {
    self.htWebview = [[HLTWebView alloc] initWithRequest:self.request];
    self.htWebview.delegate = self;
    self.htWebview.autoLoadRequest = self.autoLoadRequest;
    self.htWebview.uaConfiguration = ^NSString *(WKWebView *webview) {
        return nil;// 配置UA
    };
    
    self.htWebview.wvConfiguration = ^WKWebViewConfiguration *(WKWebViewConfiguration *conf) {
        return conf;// 配置WebView
    };
    self.htWebview.frame = self.view.bounds;
    self.htWebview.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.htWebview];
    
    // 侧滑手势
    self.webview.allowsBackForwardNavigationGestures = self.allowsBackForwardNavigationGestures;
}

- (void)_layoutViewContraints {
    NSLayoutConstraint *l = [NSLayoutConstraint constraintWithItem:self.htWebview attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    NSLayoutConstraint *t = [NSLayoutConstraint constraintWithItem:self.htWebview attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.htWebview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0];
    NSLayoutConstraint *r = [NSLayoutConstraint constraintWithItem:self.htWebview attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1 constant:0];
    [self.htWebview addConstraints:@[t, l, b, r]];
    
    CGFloat const kHeight = 2.0;
    l = [NSLayoutConstraint constraintWithItem:self.progressView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    r = [NSLayoutConstraint constraintWithItem:self.progressView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1 constant:0];
    NSLayoutConstraint *h = [NSLayoutConstraint constraintWithItem:self.progressView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeHeight multiplier:0 constant:kHeight];
    NSLayoutConstraint *w = [NSLayoutConstraint constraintWithItem:self.progressView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    
    [self.progressView addConstraints:@[l, r, w, h]];
}

- (void)addProgressView {
    if (!self.showProgressView) {
        return;
    }
    
    [self.view addSubview:self.progressView];
    self.progressView.hidden = YES;
}

/**
 添加webview属性监听，如加载进度、加载状态等
 */
- (void)addWebviewObserver
{
    //! WKWebview更新预测加载进度
    [self.webview addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(estimatedProgress))
                      options:NSKeyValueObservingOptionNew
                      context:(__bridge void * _Nullable)(@(HTKVOContextWebviewProgress))];
    [self.webview addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(title))
                      options:NSKeyValueObservingOptionNew
                      context:(__bridge void * _Nullable)(@(HTKVOContextWebviewTitle))];
    [self.webview addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(isLoading))
                      options:NSKeyValueObservingOptionNew
                      context:(__bridge void * _Nullable)(@(HTKVOContextWebviewIsLoading))];
    [self.progress addObserver:self
                    forKeyPath:NSStringFromSelector(@selector(progress))
                       options:NSKeyValueObservingOptionNew
                       context:(__bridge void * _Nullable)(@(HTKVOContextLoadingProgress))];
}

- (void)_updateWebviewProgress {// todo
    double progress = self.webview.estimatedProgress;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progress updateEstimatedProgress:progress];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([object isEqual:self.webview]) {
        NSNumber *num = (__bridge NSNumber *)(context);
        if (!num || [num isKindOfClass:[NSNumber class]]) {
            return;
        }
        switch (num.integerValue) {
            case HTKVOContextWebviewProgress: {
                [self _updateWebviewProgress];
                break;
            }
            case HTKVOContextWebviewTitle: {
                [self updateWebContentTitle:self.webview.title];
                break;
            }
            case HTKVOContextWebviewIsLoading: {
                HLTLog(@"Web页面加载状态：%@",@(self.webview.isLoading));
                break;
            }
            default: {
                HLTLog(@"KVO Keypath NOT handled! ");
                break;
            }
        }
    } else if ([object isEqual:self.progress]) {
        [self.progressView updateProgress:self.progress.progress];
    }
}

#pragma mark - 属性

- (WKWebView *)webview {
    return self.htWebview.webview;
}

- (HLTJavaScriptBridge *)jsBridge {
    return self.htWebview.jsBridge;
}

- (UIView<HLTWebProgressView> *)progressView
{
    if (!_progressView) {
        _progressView = [[HLTWebProgressView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 2)];
    }
    
    return _progressView;
}

- (HLTWebProgress *)progress
{
    if (!_progress) {
        _progress = [[HLTWebProgress alloc] initWithDuration:kHTWebProgressDuration
                                                      timeout:kHTWebProgressTimeout];
    }
    
    return _progress;
}

- (void)setAutoLoadRequest:(BOOL)autoLoadRequest {
    _autoLoadRequest = autoLoadRequest;
    _htWebview.autoLoadRequest = autoLoadRequest;
}



#pragma mark - Public

/**
 加载请求
 */
- (void)loadRequest
{
    [self.htWebview loadRequest];
        
    if (self.showProgressView) {
        self.progressView.hidden = NO;
        [self.progress start];
    }
}

// 配置进度条
- (void)configureProgressView:(void (^)(UIView *progressView))configuration {
    if (configuration) {
        configuration(self.progressView);
    }
}

- (BOOL)isWebviewLoaded {
    return self.htWebview.isWebviewLoaded;
}

- (void)setShowProgressView:(BOOL)showProgressView {
    BOOL update = showProgressView != _showProgressView;
    _showProgressView = showProgressView;
    if (!update) {
        return;
    }
    
    if (showProgressView) {
        if (!_progressView.superview || _progressView.hidden) {
            [self addProgressView];
            self.progressView.hidden = NO;
        }
    } else {
        if (_progressView.hidden != NO) {
            _progressView.hidden = YES;
        }
    }
}

#pragma mark - Private

- (void)loadHTMLString:(NSString *)html {
    NSAssert(self.request == nil, @"意外加载html？");
    [self.webview loadHTMLString:html baseURL:nil];
}

- (void)reloadWebview
{
    if (self.request) {
        [self.webview reload];
        
        if (self.showProgressView) {
            self.progressView.hidden = NO;
            [self.progress start];
        }
    }
}

- (void)updateWebContentTitle:(NSString *)title {
    if (self.usingWebTitle) {
        self.title = title;
        if (self.usingCustomNavBar) {
//            self.navTitle = title;
        }
    }
}

#pragma mark - WKWebView

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
}

#pragma mark - Action

- (void)actionBack:(id)sender {
    if (self.presentingViewController) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
    }
}

#pragma mark - Test case
/*
- (void)testJSBridge {
    HLTLog(@"testJSBridge");
    [self.jsBridge registerEvent:@"event-request-info" handler:^(NSString *event, id dataFromJS, HTJsBridgeResponseCallback responseCallback) {
        HLTLog(@"js->oc: %@, data: %@", event, dataFromJS);
        responseCallback(@{@"info": @"122333"});
    }];
    
    //[self.jsBridge preparedForJSEvent];
}

- (void)testOCCallJS {
    HLTLog(@"testOCCallJS");
    [self.jsBridge sendMessage:@"event-provide-info" data:@{@"key": @"1"} onResponse:^(id responseData) {
        HLTLog(@"on resp from js: %@", responseData);
    }];
}
*/
@end
