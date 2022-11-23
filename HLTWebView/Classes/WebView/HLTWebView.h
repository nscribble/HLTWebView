//
//  HLTWebView.h
//  Snapshot
//
//	@version 1.0.0 2017/7/3
//
//  Created by nscribble on 2017/7/3.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import <UIKit/UIKit.h>
#if __has_include(<HTWebView/HTWebView.h>)
#import "HTJavaScriptBridge.h"
#else
#import <HLTJavaScriptBridge.h>
#endif

@import WebKit;

@class HLTWebView;

typedef WKWebViewConfiguration *(^HTWebViewConfigurationBlock)(WKWebViewConfiguration *conf);
typedef NSString *(^HTWebViewUserAgentBlock)(WKWebView *webview);

// WebView事件代理：接收四个代理事件(alert等不转发)
@protocol HTWebViewDelegate <WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler>
@optional

@end

@interface HLTWebView : UIView
<
WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler
>

//! 代理
@property (nonatomic,weak) id<HTWebViewDelegate> delegate;
//! 请求对象
@property (nonatomic,readonly) NSURLRequest *request;
//! webview
@property (nonatomic,readonly) WKWebView *webview;
//! js事件桥接对象（页面添加到视图/viewDidLoad/addJSBridge之后可用，目前都创建jsBridge）
@property (nonatomic,readonly) HLTJavaScriptBridge *jsBridge;
//! 是否自动加载请求（默认YES）
@property (nonatomic,assign) BOOL autoLoadRequest;

@property (nonatomic,copy) HTWebViewConfigurationBlock wvConfiguration;
@property (nonatomic,copy) HTWebViewUserAgentBlock uaConfiguration;


// 初始化
- (instancetype)initWithRequest:(NSURLRequest *)request NS_DESIGNATED_INITIALIZER;

/**
 @param URL 网络请求URL
 @param transform 发起请求前可对request处理（如用于host修改、等）
 */
- (instancetype)initWithURL:(NSURL *)URL transformRequest:(NSURLRequest * (^)(NSURLRequest *request))transform;

/**
 开始加载请求
 @note 请配合`autoLoadRequest`使用，避免重复加载
 */
- (void)loadRequest;

// 注入脚本：构建DOM之前（请注意在loadRequest前注入）
- (void)injectJavaScriptAtDOMStart:(NSString *)js;
// 注入脚本：构建DOM之后（请注意在loadRequest前注入）
- (void)injectJavaScriptAtDOMEnd:(NSString *)js;

/**
 执行JS脚本

 @param script 字符串形式的JS脚本
 @param handler 执行完成回调（result为JS执行结果，error为执行过程抛出的错误）
 */
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id result, NSError *error))handler;

/**
 清理代理、JSBridge等
 */
- (void)clear;

//! webview是否已被加载
- (BOOL)isWebviewLoaded;

@end
