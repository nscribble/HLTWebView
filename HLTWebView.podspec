#
# Be sure to run `pod lib lint HTWebView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HLTWebView'
  s.version          = '0.1.2'
  s.summary          = 'HTWebView is a wrapper of WKWebView with JavaScriptBridge supported. We Make a new JavaScriptBridge inspired by WebViewJavascriptBridge.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  HLTWebView is a wrapper of WKWebView with JavaScriptBridge supported. We Make a new JavaScriptBridge inspired by WebViewJavascriptBridge. Try it.
                       DESC

  s.homepage         = 'https://github.com/nscribble/HLTWebView'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'nscribble' => 'x201710216@163.com' }
  s.source           = { :git => 'git@github.com:nscribble/HLTWebView.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'HLTWebView/Classes/**/*.{h,m}'
  s.requires_arc = true

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'WebKit', 'UIKit', 'Foundation'
  
  non_arc_files = ['HLTWebView/Classes/WebView/WKScriptMessage+BoBo_WKScriptMessageLeakFix.{h,m}']
  s.exclude_files = non_arc_files
  s.subspec 'non-arc' do |mrc|
      mrc.source_files = non_arc_files
      mrc.requires_arc = false
  end
  
  s.subspec 'JavaScriptBridge' do |bridge|
      bridge.source_files = ['HLTWebView/Classes/JavaScriptBridge/*.{h,m}', 'HLTWebView/Classes/*.{h,m}']
      bridge.frameworks = 'WebKit', 'Foundation'
      bridge.resources = ['HLTWebView/Assets/*.png', 'HLTWebView/Classes/**/*.{html,js}']
#      bridge.resource_bundles = {
#          'HTWebView' => ['HTWebView/Assets/*.png', 'HTWebView/Classes/**/*.{html,js}']
#      }
  end
  
  s.subspec 'WebView' do |webview|
      webview.source_files = 'HLTWebView/Classes/WebView/*.{h,m}'
      webview.dependency 'HLTWebView/JavaScriptBridge'
      webview.dependency 'HLTWebView/non-arc'
      webview.frameworks = 'WebKit', 'UIKit', 'Foundation'
      webview.exclude_files = non_arc_files
  end
  
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
