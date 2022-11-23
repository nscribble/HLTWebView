//
//  HLTWebView.m
//  Snapshot
//
//  Created by nscribble on 2017/7/3.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import "HLTWebView.h"
#import <objc/runtime.h>
@import WebKit;

#define IOSVersion ([UIDevice currentDevice].systemVersion.doubleValue)

@interface UIWindow (Ext)

+ (UIViewController*)ht_topViewController;
+ (UIViewController*)ht_currentViewController;

@end

@implementation UIWindow (Ext)

+(UIViewController *)ht_rootViewController {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

+ (UIViewController*)ht_topViewController
{
    UIViewController *topViewController = [self ht_rootViewController];
    //  Getting topMost ViewController
    while ([topViewController presentedViewController]) {
        topViewController = [topViewController presentedViewController];
    }
    return topViewController;
}

+ (UIViewController*)ht_currentViewController;
{
    UIViewController *currentViewController = [self ht_topViewController];
    while ([currentViewController isKindOfClass:[UINavigationController class]] && [(UINavigationController*)currentViewController topViewController]) {
        currentViewController = [(UINavigationController*)currentViewController topViewController];
    }
    return currentViewController;
}

@end

#pragma mark - HTWebView

@interface HLTWebView ()

@property (nonatomic,strong) WKWebView *webview;
@property (nonatomic,strong) WKWebViewConfiguration *webviewConfiguration;
@property (nonatomic,strong) NSURLRequest *request;
@property (nonatomic,strong) HLTJavaScriptBridge *jsBridge;

@property (nonatomic,weak) WKNavigation *mainNavigation;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"

@implementation HLTWebView
{
    BOOL _webviewHasLoadRequest;
}

#pragma clang diagnostic pop

#pragma mark - 生命周期

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithRequest:nil];
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithRequest:nil];
}

- (instancetype)initWithURL:(NSURL *)requestURL transformRequest:(NSURLRequest *(^)(NSURLRequest *))transform {
    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
    if (transform) {
        request = transform(request);
    }
    return [self initWithRequest:request];
}

- (instancetype)initWithRequest:(NSURLRequest *)request{
    if (self = [super initWithFrame:CGRectZero]) {
        _request = request;
        _autoLoadRequest = NO;
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    if (newSuperview  && !self.superview) {
        if (!_webviewHasLoadRequest) {
            [self addWebview];
            
            if (self.autoLoadRequest) {
                [self loadRequest];
            }
        }
    }
}

- (void)dealloc {
    [self clear];
    NSLog(@"webview dealloc");
}

- (void)clear {
    [_jsBridge clear];
    _jsBridge = nil;
    _webview.navigationDelegate = nil;
    _webview.UIDelegate = nil;
    _webview.scrollView.delegate = nil;
    _webview = nil;
}

#pragma mark - 初始化

- (void)addWebview {
    /* The initializer copies the specified configuration, so
     mutating the configuration after invoking the initializer has no effect
     on the web view. */
    if (self.wvConfiguration) {
        WKWebViewConfiguration *conf = self.webviewConfiguration;
        if (conf != nil) {
            self.webviewConfiguration = self.wvConfiguration(conf);
        }
    }
    
    self.webview = [[WKWebView alloc] initWithFrame:self.bounds configuration:self.webviewConfiguration];
    self.webview.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.webview.backgroundColor = [UIColor clearColor];
    self.webview.opaque = NO;
    [self addJSBridge];
    
    [self addSubview:self.webview];
    [self _layoutViewContraints];
    
    self.webview.navigationDelegate = self;
    self.webview.UIDelegate = self;
    self.webview.multipleTouchEnabled = YES;
    self.webview.autoresizesSubviews = YES;
    self.webview.allowsBackForwardNavigationGestures = YES;
    if (self.uaConfiguration) {
        NSString *ua = self.uaConfiguration(self.webview);
        [self setCustomUserAgent:ua];
    }
}

- (void)_layoutViewContraints {
    NSLayoutConstraint *l = [NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    NSLayoutConstraint *t = [NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1 constant:0];
    NSLayoutConstraint *r = [NSLayoutConstraint constraintWithItem:self.webview attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:0];
    [self.webview addConstraints:@[t, l, b, r]];
}


- (void)addJSBridge {
    if (self.jsBridge) {
        NSLog(@"addJSBridge self.jsBridge != nil");
        return;
    }
    
    self.jsBridge = [HLTJavaScriptBridge bridgeForWebView:self.webview webviewDelegate:self];
}

- (void)setCustomUserAgent:(NSString *)ua {
    if (@available(iOS 9.0, *)) {
        self.webview.customUserAgent = ua;
    }
    else {// iOS 8 是私有方法
        NSString *userAgent = ua;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.webview performSelector:NSSelectorFromString([@"_" stringByAppendingString:@"setCustomUserAgent:"]) withObject:userAgent];
#pragma clang diagnostic pop
    }
}

#pragma mark - 属性

- (BOOL)isWebviewLoaded {
    return _webviewHasLoadRequest == YES;
}

- (WKWebViewConfiguration *)webviewConfiguration {
    if (!_webviewConfiguration) {
        WKUserContentController *userContentController = [[WKUserContentController alloc] init];
        
        // 附加cookies
        //NSAssert(self.request.URL != nil, @"request为空！无法获取设置cookie");
        if (self.request.URL) {
            NSArray <NSHTTPCookie *>*cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:self.request.URL];
            NSMutableString *cookieJs = [@"document.cookie = " mutableCopy];
            [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [cookieJs appendFormat:@"\'%@=%@;\'", obj.name, obj.value];
            }];

            WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:cookieJs injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
            [userContentController addUserScript:cookieScript];
        }
        
        if (IOSVersion<9.0) {
            NSString *jScript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
            
            WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
            [userContentController addUserScript:wkUScript];

        }
        
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.userContentController = userContentController;
        
        WKPreferences *preferences = [[WKPreferences alloc] init];
        preferences.javaScriptEnabled = YES;
        preferences.javaScriptCanOpenWindowsAutomatically = NO;
        configuration.preferences = preferences;
        
        _webviewConfiguration = configuration;
    }
    
    return _webviewConfiguration;
}

#pragma mark - Public

- (void)injectJavaScriptAtDOMStart:(NSString *)js {
    [self.webview injectJavaScriptAtDOMStart:js];
}

- (void)injectJavaScriptAtDOMEnd:(NSString *)js {
    [self.webview injectJavaScriptAtDOMEnd:js];
}

- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id, NSError *error))handler {
    [self.webview evaluateJavaScript:script completionHandler:handler];
}

- (void)loadHTMLString:(NSString *)html {
    [self.webview loadHTMLString:html baseURL:nil];
}

- (void)loadRequest {
    if (_webviewHasLoadRequest) {
        NSLog(@"loadRequest 重复");
        return;
    }
    
    [self _loadRequestInternal];
}

- (void)_loadRequestInternal {
    self.mainNavigation = [self.webview loadRequest:self.request];
    _webviewHasLoadRequest = YES;
}

#pragma mark - Private

- (void)_reloadWithRequest:(NSURLRequest *)request {
    self.request = request;
    if (_webviewHasLoadRequest) {
        if (self.webview.isLoading) {
            [self.webview stopLoading];
        }
        
        [self _loadRequestInternal];
    }
}

- (void)reloadWebview {
    self.mainNavigation = [self.webview reload];
}

#pragma mark - WKWebview 代理

// ----跳转----
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    WKNavigationActionPolicy policy = WKNavigationActionPolicyAllow;
    if (!([navigationAction.request.URL.scheme.lowercaseString hasPrefix:@"http"] ||
          [navigationAction.request.URL isFileURL])) {
        policy = WKNavigationActionPolicyCancel;
    }
    else
    {
        policy = WKNavigationActionPolicyAllow;
    }
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:^(WKNavigationActionPolicy policy_delegate) {
            // 加载策略待定：目前为两者都允许才允许
            decisionHandler(policy & policy_delegate);
        }];
    }
    else
    {
        decisionHandler(policy);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:^(WKNavigationResponsePolicy policy_delegate) {
            decisionHandler(policy_delegate);
        }];
    }
    else {
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
    
//    webView.scrollView.backgroundColor = webView.backgroundColor;
}



// 重定向：Invoked when a server redirect is received for the main frame.
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
#if DEBUG
    NSLog(@"重定向：Invoked when a server redirect is received for the main frame.");
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
    }
}

// 页面加载开始：Invoked when a main frame navigation starts
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
#if DEBUG
    NSLog(@"页面加载开始：Invoked when a main frame navigation starts");
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

// 页面数据到达：Invoked when content starts arriving for the main frame.
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
#if DEBUG
    NSLog(@"页面数据到达：Invoked when content starts arriving for the main frame.");
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didCommitNavigation:navigation];
    }
    webView.scrollView.backgroundColor = webView.backgroundColor;
}

// 一次加载完成：Invoked when a main frame navigation completes.
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
#if DEBUG
    NSLog(@"一次加载完成：Invoked when a main frame navigation completes.");
#endif
    
    // workaround: WKWebview的scrollview的背景色未跟随其变化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        webView.scrollView.backgroundColor = webView.backgroundColor;
    });
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didFinishNavigation:navigation];
    }
}

// 加载失败：Invoked when an error occurs during a committed main frame
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"加载失败：Invoked when an error occurs during a committed main frame");
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didFailNavigation:navigation withError:error];
    }
}

// 鉴权
/**
 If you do not implement this method, the web view will respond to the authentication challenge with the NSURLSessionAuthChallengeRejectProtectionSpace disposition
 */
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    }
    else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

// （iOS 9）内容进程终止（白屏）：web view's web content process is terminated
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
#if DEBUG
    NSLog(@"内容进程终止（白屏）：web view's web content process is terminated");
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        if (@available(iOS 9.0, *)) {
            [self.delegate webViewWebContentProcessDidTerminate:webView];
        } else {
            // Fallback on earlier versions
        }
    }
    else {
        [webView reload];
    }
}

/** UI相关
 */

// 提供新页面webview（如_blank）
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
#if DEBUG
    NSLog(@"提供新页面webview（如_blank）:%@", navigationAction);
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        return [self.delegate webView:webView createWebViewWithConfiguration:configuration forNavigationAction:navigationAction windowFeatures:windowFeatures];
    }
    else {
        if (!navigationAction.targetFrame.isMainFrame) {
            if (!navigationAction.request) {
                NSLog(@"出错：navigationAction.request为空！");
            }
            [webView loadRequest:navigationAction.request];
        }
        return nil;
    }
}

// 页面关闭成功：DOM window object's close() method completed successfully.
- (void)webViewDidClose:(WKWebView *)webView
{
#if DEBUG
    NSLog(@"页面关闭成功：DOM window object's close() method completed successfully.");
#endif
    
    if ([self.delegate respondsToSelector:_cmd]) {
        [self.delegate webViewDidClose:webView];
    }
}

#if DEBUG
// 警告弹窗
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"确定", @"确定")
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler();
                                                      }]];
    
    UIViewController *rootViewController = [UIWindow ht_topViewController];
    [rootViewController presentViewController:alertController animated:YES completion:NULL];
}

// 确认弹窗
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler
{
#if DEBUG
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"取消", @"取消")
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          completionHandler(NO);
                                                      }]
     ];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"确定", @"确定")
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(YES);
                                                      }]];
    UIViewController *rootViewController = [UIWindow ht_topViewController];
    [rootViewController presentViewController:alertController animated:YES completion:NULL];
#endif
}

// 输入弹窗
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler
{
#if DEBUG
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = defaultText;
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"确定", @"确定")
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(alertController.textFields.firstObject.text);
                                                      }]];
    
    UIViewController *rootViewController = [UIWindow ht_topViewController];
    [rootViewController presentViewController:alertController animated:YES completion:NULL];
#endif
}
#endif

#pragma mark WK私有方法

#pragma mark - Message Forwarding

+ (NSArray *)protocols {
    return @[@protocol(WKNavigationDelegate),
             @protocol(WKScriptMessageHandler),
             @protocol(WKUIDelegate)
             ];
}

- (BOOL)protocolContainsSelector:(SEL)aSelector
{
    for (Protocol *protocol in [self.class protocols]) {
        struct objc_method_description methodDesc = protocol_getMethodDescription(protocol, aSelector, NO, YES);
        if (methodDesc.name != 0) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
#if DEBUG
    //NSLog(@"respondsToSelector:%@", NSStringFromSelector(aSelector));
#endif
    BOOL result = [super respondsToSelector:aSelector];
    if (result) {
        return result;
    }
    
    if ([self protocolContainsSelector:aSelector] && [self.delegate respondsToSelector:aSelector]) {
        return YES;
    }
    
    return result;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([self protocolContainsSelector:aSelector]) {
        return self.delegate;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    NSAssert(NO, @"Webview doesNotRecognizeSelector:%@", NSStringFromSelector(aSelector));
}

@end
