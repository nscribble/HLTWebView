//
//  HLTJavaScriptBridge.h
//  Snapshot
//
//  Created by cc on 2017/6/1.
//  Copyright © 2017年 Jason. All rights reserved.
//  JS/Native事件交互处理，参考WVJB

#import <Foundation/Foundation.h>
#import "HTWebViewPredefines.h"

@import WebKit;

extern NSString * const HTWebViewScriptInjectedNotification;
extern NSString * const HTWebViewDOMLoadedNotification;
extern NSString * const HTWebViewOnDOMLoadedEvent;

typedef void(^HTJsBridgeResponseCallback)(NSDictionary *responseData);
typedef void(^HTJsBridgeHandler)(NSString *event, NSDictionary * dataFromJS, HTJsBridgeResponseCallback responseCallback);

@interface HLTJavaScriptBridge : NSObject

@property (nonatomic,weak) WKWebView *webview;

/**
 `WKWebview`的Navigation事件代理。
 @note `HLTJavaScriptBridge`会重置`WKWebview`的Navigation事件代理，并将相关事件转发回该代理。
 @note 为保证`HLTJavaScriptBridge`正常工作，在获取到bridge后不应修改`WKWebview`的Navigation事件代理。
 */
@property (nonatomic,weak,readonly) id<WKNavigationDelegate,WKScriptMessageHandler> webviewDelegate;

+ (instancetype)bridgeForWebView:(WKWebView *)webview webviewDelegate:(id<WKNavigationDelegate,WKScriptMessageHandler>)webviewDelegate;

/**
 注册特定事件的回调
 @note 请在register完后调用 -preparedForJSEvent 

 @param event 事件名称
 @param handler 处理代码
 */
- (BOOL)registerEvent:(NSString *)event handler:(HTJsBridgeHandler)handler;
//! 取消监听JS调用
- (BOOL)unregisterEvent:(NSString *)event;
// 注册完event-handler之后准备接收JS事件
- (void)preparedForJSEvent;

/**
 向JS发送消息
 注：response 目前直接交由wvjsBridge处理，故只支持新方式的通信。其他情况暂建议直接调用webview执行JS脚本。
 
 @param event 消息名称
 @param data 消息实体数据
 @param response JS给OC的回调
 */
- (BOOL)sendMessage:(NSString *)event data:(NSDictionary *)data onResponse:(HTJsBridgeResponseCallback)response;

/**
 清理事件回调、webview引用等
 */
- (void)clear;

@end

@interface WKWebView (HTJavaScriptBridge)

- (void)injectJavaScriptAtDOMStart:(NSString *)js;
- (void)injectJavaScriptAtDOMEnd:(NSString *)js;

@end
