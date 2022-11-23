//
//  HLTJavaScriptBridge.m
//  Snapshot
//
//  Created by cc on 2017/6/1.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import "HLTJavaScriptBridge.h"
#import <objc/runtime.h>

@import WebKit;

static NSString * const JSB_HDL_PREPARE = @"JSBridgePrepare";
static NSString * const JSB_HDL_REQ = @"JSBridgeReq";
static NSString * const JSB_HDL_RESP = @"JSBridgeResp";
static NSString * const JSB_PAYLOAD_CODE = @"__code__";
static NSString * const JSB_PAYLOAD_EVENT = @"__event__";
static NSString * const JSB_PAYLOAD_DATA = @"__data__";
static NSString * const JSB_PAYLOAD_CALLBACKID = @"__callbackId__";

static NSString * const JSB_RESP_CODE_SUCC = @"1";
static NSString * const JSB_RESP_CODE_FAILED = @"0";

NSString * const HTWebViewOnDOMLoadedEvent = @"__onDOMLoaded__";

NSString * const HTWebViewScriptInjectedNotification = @"HTWebViewScriptInjectedNotification";
NSString * const HTWebViewDOMLoadedNotification = @"HTWebViewDOMLoadedNotification";

#pragma mark - WKWebView()

@implementation WKWebView (HTJavaScriptBridge)

- (void)injectJavaScriptAtDOMStart:(NSString *)js {
    [self __injectJavaScript:js time:WKUserScriptInjectionTimeAtDocumentStart];
}

- (void)injectJavaScriptAtDOMEnd:(NSString *)js {
    [self __injectJavaScript:js time:WKUserScriptInjectionTimeAtDocumentEnd];
}

- (void)__injectJavaScript:(NSString *)js time:(WKUserScriptInjectionTime)time {
    if (![js isKindOfClass:[NSString class]] ||
        js.length <= 0) {
        NSLog(@"invalid javascript to inject: %@", js);
        return;
    }
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:time forMainFrameOnly:YES];
    [self.configuration.userContentController addUserScript:script];
}

@end

#pragma mark - HTJavaScriptBridge

@interface HLTJavaScriptBridge ()<WKNavigationDelegate,WKScriptMessageHandler>

@property (nonatomic,weak,readwrite) id<WKNavigationDelegate,WKScriptMessageHandler> webviewDelegate;

@property (nonatomic,strong) NSMutableDictionary *handlers;
@property (nonatomic,strong) NSMutableDictionary *resps;
// 消息队列（若未初始化完毕需先缓存'消息'）
@property (nonatomic,strong) NSMutableArray<NSString *> *messageQueues;

@end


@implementation HLTJavaScriptBridge
{
    long _uniqueId;
    struct JSBState {
        BOOL jsInjected;// 注入jsb脚本
        BOOL jsPrepared;// 前端jsb初始化
        BOOL domLoaded;// dom加载完毕
        BOOL jsListened;// 前端jsb事件监听注册完毕
        BOOL nativePrepared;// 客户端已完成事件注册
        BOOL jsKnowNativePrepared;// js知道客户端prepared
    } _state;
}

+ (instancetype)bridgeForWebView:(WKWebView *)webview webviewDelegate:(id<WKNavigationDelegate,WKScriptMessageHandler>)webviewDelegate
{
    HLTJavaScriptBridge *bridge = [self new];
    [bridge setupWithWebview:webview
                    delegate:webviewDelegate];
    
    return bridge;
}

- (void)dealloc {
    NSLog(@"bridge dealloc");
    NSArray<NSString *> *events = [_handlers allKeys];
    [events enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self unregisterEvent:obj];
    }];
    
    NSArray<NSString *> *callbackIds = [_resps allKeys];
    [callbackIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self unregisterEvent:obj];
    }];
    
    [self clear];
}

- (void)clear {
    _webview.navigationDelegate = nil;
    _webviewDelegate = nil;
    _webview = nil;
    
    [_webview.configuration.userContentController removeScriptMessageHandlerForName:JSB_HDL_PREPARE];
    [_webview.configuration.userContentController removeScriptMessageHandlerForName:JSB_HDL_REQ];
    [_webview.configuration.userContentController removeScriptMessageHandlerForName:JSB_HDL_RESP];
    [_webview.configuration.userContentController removeAllUserScripts];
}

#pragma mark - Init

- (void)setupWithWebview:(WKWebView *)webview delegate:(id<WKNavigationDelegate, WKScriptMessageHandler>)delegate {
    self.webviewDelegate = delegate;
    self.webview = webview;
    webview.navigationDelegate = self;
    
    [webview.configuration.userContentController addScriptMessageHandler:self name:JSB_HDL_REQ];
    [webview.configuration.userContentController addScriptMessageHandler:self name:JSB_HDL_RESP];
    [webview.configuration.userContentController addScriptMessageHandler:self name:JSB_HDL_PREPARE];
    
    [self haveatea];
}

- (void)haveatea {
    NSString *js = [self jsBridgeScripts];
    [self.webview injectJavaScriptAtDOMStart:js];
    
    js = @"window.webkit.messageHandlers.JSBridgePrepare.postMessage('oninject');";
    [self.webview injectJavaScriptAtDOMStart:js];
    
    js = @"window.webkit.messageHandlers.JSBridgePrepare.postMessage('onload')";
    [self.webview injectJavaScriptAtDOMEnd:js];// html构建完之后
}

- (NSString *)jsBridgeScripts {
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"HLTJavaScriptBridge" withExtension:@"js"];
    if (!URL) {
        URL = [[NSBundle bundleForClass:[HLTJavaScriptBridge class]] URLForResource:@"HTJavaScriptBridge" withExtension:@"js"];
    }
    NSError *error = nil;
    NSString *js = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"load js error: %@", error);
    }
    
    return js;
}

#pragma mark - Public

- (BOOL)registerEvent:(NSString *)event handler:(HTJsBridgeHandler)handler
{
    [self _addHandler:handler forEvent:event];
    return YES;
}

- (BOOL)unregisterEvent:(NSString *)event
{
    [self _removeHandlerForEvent:event];
    return YES;
}

//! 设置event的回调块
- (void)_addHandler:(HTJsBridgeHandler)handler forEvent:(NSString *)event {
    {// 内部使用
        if (event && handler) {
            @synchronized (self.handlers) {
                self.handlers[event] = [handler copy];
            }
        }
    }
}

//! 移除event的回调块
- (void)_removeHandlerForEvent:(NSString *)event {
    if (event) {
        @synchronized (self.handlers) {
            [self.handlers removeObjectForKey:event];
        }
    }
}

//! 查询event的回调块
- (HTJsBridgeHandler)_handlerForEvent:(NSString *)event {
    if (!event) {
        return nil;
    }
    
    return self.handlers[event];
}

- (BOOL)sendMessage:(NSString *)event data:(NSDictionary *)data onResponse:(HTJsBridgeResponseCallback)response
{
    if (!event) {
        NSLog(@"event required NOT nil!");
        return NO;
    }
    
    NSMutableDictionary *message = @{JSB_PAYLOAD_EVENT: event,
                                     JSB_PAYLOAD_DATA: (data ?: @{}),
                                     }.mutableCopy;
    if (response) {
        NSString *callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
        message[JSB_PAYLOAD_CALLBACKID] = callbackId;
        self.resps[callbackId] = [response copy];
    }
    
    [self __sendMessage:message];
    return YES;
}

- (void)__sendMessage:(NSDictionary *)payload {// take from wvjb
    NSString *messageJSON = [self _serializeMessage:payload pretty:NO];

    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    
    NSString *messageScript = [NSString stringWithFormat:@"JSBridge._onReceiveNativeReq('%@');", messageJSON];
    [self __doSendMessage:messageScript];
}

- (void)__doSendMessage:(NSString *)messageScript {
    if (_state.jsPrepared) {
#if DEBUG
        NSLog(@"__send__ message: %@", messageScript);
#endif
        dispatch_main_async_safe(^{
            [self.webview evaluateJavaScript:messageScript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            }];
        });
    }
    else {
        NSLog(@"__send__ message, but not prepared!");
        [self.messageQueues addObject:messageScript];
    }
}

- (void)__sendResp:(NSDictionary *)payload {
    NSString *messageJSON = [self _serializeMessage:payload pretty:NO];
#if DEBUG
    NSLog(@"__send__ resp: %@", messageJSON);
#endif
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    
    NSString *javascript = [NSString stringWithFormat:@"JSBridge._onReceiveNativeResp('%@');", messageJSON];
    dispatch_main_async_safe(^{
        [self.webview evaluateJavaScript:javascript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        }];
    });
}

- (NSString *)_serializeMessage:(id)message pretty:(BOOL)pretty{
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:(NSJSONWritingOptions)(pretty ? NSJSONWritingPrettyPrinted : 0) error:nil] encoding:NSUTF8StringEncoding];
}

- (void)preparedForJSEvent {
    [self __tellJSThatNativePrepared];
}

- (void)__nativePreparedTimeout {
    // NSAssert(NO, @"Call `preparedForJSEvent` When Ready!");
    [self __tellJSThatNativePrepared];
}

- (void)__tellJSThatNativePrepared {
    HLTLog(@"__tellJSThatNativePrepared");
    self->_state.nativePrepared = YES;
    if (!self->_state.jsInjected) {
        return;
    }
    
    if (self->_state.jsKnowNativePrepared) {
        return;
    }
    NSString *javascript = [NSString stringWithFormat:@"JSBridge._onNativePrepared();"];
    dispatch_main_async_safe(^{
        weakify(self)
        [self.webview evaluateJavaScript:javascript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            strongify(self)
            self->_state.jsKnowNativePrepared = YES;
        }];
    });
}

#pragma mark - Getter

- (NSMutableDictionary *)handlers {
    if (!_handlers) {
        _handlers = @{}.mutableCopy;
    }
    
    return _handlers;
}

- (NSMutableDictionary *)resps {
    if (!_resps) {
        _resps = @{}.mutableCopy;
    }
    
    return _resps;
}

- (NSMutableArray<NSString *> *)messageQueues {
    if (!_messageQueues) {
        _messageQueues = [NSMutableArray<NSString *> array];
    }
    
    return _messageQueues;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
#if DEBUG
    NSLog(@"decidePolicyForNavigationAction:%@", navigationAction);
#endif
    
    WKNavigationActionPolicy policy = WKNavigationActionPolicyAllow;
    if ([navigationAction.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        policy = WKNavigationActionPolicyCancel;
    }

    if ([self.webviewDelegate respondsToSelector:_cmd]) {
        [self.webviewDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:^(WKNavigationActionPolicy policy_delegate) {
            // 加载策略待定：目前为两者都允许才允许
            decisionHandler(policy & policy_delegate);
        }];
    }
    else
    {
        decisionHandler(policy);
    }
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSLog(@"[JS->OC] 接收到JS脚本调用：[%@][%@]", message.name, message.body);
    // 注入js后，初始化js端的setup部分
    if ([message.name isEqualToString:JSB_HDL_PREPARE]) {
        [self _handlePrepare:message];
        return;
    }
    
    
    NSDictionary *payload = message.body;
    if (![payload isKindOfClass:[NSDictionary class]]) {
        NSError *error = nil;
        NSData *data = [payload isKindOfClass:[NSData class]] ? message.body : ([payload isKindOfClass:[NSString class]] ? [message.body dataUsingEncoding:NSUTF8StringEncoding] : nil);
        payload = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if (![payload isKindOfClass:[NSDictionary class]]) {
            payload = nil;// message.body
        }
    }
    
    // 消息结构（结合.js修改）
    if ([message.name isEqualToString:JSB_HDL_REQ]) {// 接收到请求
        if ([payload isKindOfClass:[NSDictionary class]]) {
            [self _handleReqWithPayload:payload];
        }
    } else if([message.name isEqualToString:JSB_HDL_RESP]) {// 接收到响应
        if ([payload isKindOfClass:[NSDictionary class]]) {
            [self _handleRespForPayload:payload];
        }
    }
    
    //! 消息转发给webviewController
    if ([self.webviewDelegate respondsToSelector:_cmd]) {
        [self.webviewDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

#pragma mark - Script Message Handling

- (void)_handlePrepare:(WKScriptMessage *)script {
    NSString *message = script.body;
    if ([message isKindOfClass:[NSString class]]) { // 初始化
        if ([message isEqualToString:@"oninject"]) {
            self->_state.jsInjected = YES;
            NSString *javascript = @"JSBridge._setupPrepare();";
            weakify(self)
            dispatch_main_async_safe(^{
                [self.webview evaluateJavaScript:javascript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                    strongify(self)
                    self->_state.jsPrepared = YES;
                    
                    if (self->_state.nativePrepared &&
                        !self->_state.jsKnowNativePrepared) {// 防止业务__tell时js端未准备好
                        [self __tellJSThatNativePrepared];
                    } else {// 防止客户端遗漏调用
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self __nativePreparedTimeout];
                        });
                    }
                    if (self->_state.domLoaded) {
                        [self __flushMessageQueue];
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:HTWebViewScriptInjectedNotification object:nil];
                }];
            });
        }
        else if ([message isEqualToString:@"onload"]) {
            self->_state.domLoaded = YES;
            [self __flushMessageQueue];
            [[NSNotificationCenter defaultCenter] postNotificationName:HTWebViewDOMLoadedNotification object:nil];
            [self __fakeSendJSMessage:HTWebViewOnDOMLoadedEvent param:@{}];
        }
    }
}

- (void)__flushMessageQueue {
    if (_messageQueues.count > 0) {
        [self.messageQueues enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self __doSendMessage:obj];
        }];
    }
}

// 接收到「js发起」的req
- (void)_handleReqWithPayload:(NSDictionary *)payload {
    NSString *event = payload[JSB_PAYLOAD_EVENT];
    NSDictionary *data = payload[JSB_PAYLOAD_DATA];
    NSString *callbackId = payload[JSB_PAYLOAD_CALLBACKID];
    
    if (!event) {
        NSLog(@"[Error] event = nil");
        return;
    }
    
    if (![data isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[Warn] params not dict");
    }
    
    if (self.handlers[event]) {
        HTJsBridgeHandler handler = self.handlers[event];
        if (handler) {
            HTJsBridgeResponseCallback responseBlock = ^(id responseData) {
                NSMutableDictionary *resp = @{}.mutableCopy;
                if (responseData) {
                    resp[JSB_PAYLOAD_DATA] = responseData;
                }
                if (callbackId) {
                    resp[JSB_PAYLOAD_CALLBACKID] = callbackId;
                }
                resp[JSB_PAYLOAD_CODE] = JSB_RESP_CODE_SUCC;
                resp[JSB_PAYLOAD_EVENT] = event;
                
                // 发回响应
                [self __sendResp:resp];
            };
            
            handler(event, data, responseBlock);
        }
    } else {// 无法响应
        NSMutableDictionary *resp = @{}.mutableCopy;
        if (callbackId) {
            resp[JSB_PAYLOAD_CALLBACKID] = callbackId;
        }
        resp[JSB_PAYLOAD_DATA] = @{};
        resp[JSB_PAYLOAD_CODE] = JSB_RESP_CODE_FAILED;
        resp[JSB_PAYLOAD_EVENT] = event;
        [self __sendResp:resp];
    }
}

// 接收到「向js发出req」的resp
- (void)_handleRespForPayload:(NSDictionary *)payload {
    NSString *callbackId = payload[JSB_PAYLOAD_CALLBACKID];
    NSDictionary *data = payload[JSB_PAYLOAD_DATA];
    [self _callRespOnId:callbackId params:data];
}

- (void)_callRespOnId:(NSString *)callbackId params:(NSDictionary *)params {
    if (![callbackId isKindOfClass:[NSString class]]) {
        NSLog(@"[Error] callbackId = nil !");
        return;
    }
    
    if (![params isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[Warn] params not JSON");
    }
    
    HTJsBridgeResponseCallback callback = self.resps[callbackId];
    if (callback) {
        callback(params);
        [self.resps removeObjectForKey:callbackId];
    }
}

- (void)__fakeSendJSMessage:(NSString *)event param:(NSDictionary *)param {
    NSString *ps = [self _serializeMessage:param pretty:NO];
    NSString *js = [NSString stringWithFormat:HTPackStr(JSBridge.sendMessage('%@', %@, function (respFromNative) {
    })), event, ps];
    
    dispatch_main_async_safe(^{
        [self.webview evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        }];
    });
}

#pragma mark - Message Forwarding

+ (Protocol *)protocol
{
    return @protocol(WKNavigationDelegate);
}

- (BOOL)protocolContainsSelector:(SEL)aSelector
{
    struct objc_method_description methodDesc = protocol_getMethodDescription([self.class protocol], aSelector, NO, YES);
    return methodDesc.name != 0;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
#if DEBUG
    //NSLog(@"respondsToSelector:%@", NSStringFromSelector(aSelector));
#endif
    if ([self protocolContainsSelector:aSelector] && [self.webviewDelegate respondsToSelector:aSelector]) {
        return YES;
    }
    
    BOOL result = [super respondsToSelector:aSelector];
    
    return result;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
//    return nil;
    
    if ([self protocolContainsSelector:aSelector]) {
        return self.webviewDelegate;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    
//    BoBoInvocation *bInvocation = [BoBoInvocation invocationWithMethodSignature:anInvocation.methodSignature];
//    bInvocation.target = anInvocation.target;
//    bInvocation.selector = anInvocation.selector;
//    
//    [super forwardInvocation:bInvocation];
    
    [super forwardInvocation:anInvocation];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    NSAssert(NO, @"Bridge doesNotRecognizeSelector:%@", NSStringFromSelector(aSelector));
}

@end
