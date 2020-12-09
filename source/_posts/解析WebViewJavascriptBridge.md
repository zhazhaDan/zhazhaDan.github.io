---
title: 解析WebViewJavascriptBridge
date: 2020-12-08 10:42:12
tags:
- JS 
- swift/OC
- iOS
---

> 集成方式 pod 'WebViewJavascriptBridge', '~> 6.0'  

> 文件中 import WebViewJavascriptBridge   

> 初始化一个bridge  
```
private var bridge: WebViewJavascriptBridge!
```
<!-- more -->
注入JS以及调用JS
```
bridge = WebViewJavascriptBridge.init(webV)
bridge.registerHandler("testCallHandler") { [weak self](data, callback) in
    guard let self = self else { return }
    print(data)
    callback?("Response from testCallHandler")
}//注入

self.bridge.callHandler("testJavascriptHandler", data: ["foo": "before ready"]) //调用，当然，提前js要往 WebViewJavascriptBridge 里注入相应代码
```
JS里一定要做的事情 
- 往window添加一个src为`https://__bridge_loaded__`的iframe(非前端开发人员，不做详细探讨，总之为了和APP通信)
```
function setupWebViewJavascriptBridge(callback) {
        if (window.WebViewJavascriptBridge) { return callback(WebViewJavascriptBridge); }
        if (window.WVJBCallbacks) { return window.WVJBCallbacks.push(callback); }
        window.WVJBCallbacks = [callback];
        var WVJBIframe = document.createElement('iframe');
        WVJBIframe.style.display = 'none';
        WVJBIframe.src = 'https://__bridge_loaded__';
        document.documentElement.appendChild(WVJBIframe);
        setTimeout(function() { document.documentElement.removeChild(WVJBIframe) }, 0)
}
```

```
    setupWebViewJavascriptBridge(function(bridge) {
        var uniqueId = 1
        function log(message, data) {
            var log = document.getElementById('log')
            var el = document.createElement('div')
            el.className = 'logLine'
            el.innerHTML = uniqueId++ + '. ' + message + ':<br/>' + JSON.stringify(data)
            if (log.children.length) { log.insertBefore(el, log.children[0]) }
            else { log.appendChild(el) }
        }

        bridge.registerHandler('testJavascriptHandler', function(data, responseCallback) {
            log('ObjC called testJavascriptHandler with', data)
            var responseData = { 'Javascript Says':'Right back atcha!' }
            log('JS responding with', responseData)
            responseCallback(responseData)
        })//注册，以供app调用js
        document.body.appendChild(document.createElement('br'))

        var callbackButton = document.getElementById('buttons').appendChild(document.createElement('button'))
        callbackButton.innerHTML = 'Fire testCallHandler'
        callbackButton.onclick = function(e) {
            e.preventDefault()
            log('JS calling handler "testCallHandler"')
            bridge.callHandler('testCallHandler', {'foo': 'bar'}, function(response) {
                log('JS got response', response)
            })//js 调用app 
        }
    })
```
### WebViewJavascriptBridge 的工作流： 
- JS 端加入 src 为 https://__bridge_loaded__ 的 iframe
- Native 端检测到 Request，检测如果是 __bridge_loaded__ 则通过当前的 WebView 组件注入 WebViewJavascriptBridge_JS 代码
- 注入代码成功之后会加入一个 messagingIframe，其 src 为 https://__wvjb_queue_message__
- 之后不论是 Native 端还是 JS 端都可以通过 registerHandler 方法注册一个两端约定好的 HandlerName 的处理，也都可以通过 callHandler 方法通过约定好的 HandlerName 调用另一端的处理（两端处理消息的实现逻辑对称）
  

上面有了一个整体的认知以及使用，使用已经足够了，如果感兴趣的话，继续往下看

![bridge_folder](bridge_folder.png) 
看整个WebViewJavascriptBridge的文件内容，只有八个文件，看文件名也很清晰，咱们来分析一下，每个class都干了什么 
> ###  WebViewJavascriptBridge
> 判断WebView的类型，并通过不同的类型进行分发。针对UIWebView和WebView做的一层封装，主要从来执行JS代码，以及实现UIWebView和WebView的代理方法，并通过拦截URL来通知WebViewJavaScriptBridgeBase做的相应操作    
![WebViewJavascriptBridge](WebViewJavascriptBridge.png)   

这个类是对外暴露的，看一下接口   
- 初始化bridge时，传入我们使用的webview,针对iOS app这里支持UIWebView和WKWebView
- log 这俩接口就不说了
- setWebViewDelegate 这里因为会拿走webView的delegate，所以会再扔回去，如果有需要就实现一下，非必选，看自己业务需要
- registerHandler/removeHandler/callHandler 相关五个接口，这里就是精华所在了，JS和APP的交互调用都在这里了, 具体实现我们往下看

> ### WebViewJavascriptBridgeBase 
> bridge的核心类，用来初始化以及消息的处理
```
@property (weak, nonatomic) id <WebViewJavascriptBridgeBaseDelegate> delegate;
@property (strong, nonatomic) NSMutableArray* startupMessageQueue;//存 bridge.callHandler的函数，预存app调用 js的方法，等html加载完成注入对应的js之后，调用函数
@property (strong, nonatomic) NSMutableDictionary* responseCallbacks;//回调
@property (strong, nonatomic) NSMutableDictionary* messageHandlers;//注册事件
```
```
@protocol WebViewJavascriptBridgeBaseDelegate <NSObject>
- (NSString*) _evaluateJavascript:(NSString*)javascriptCommand;
@end
```
> ###  WKWebViewJavascriptBridge  
> 主要是针对WKWebView做的一些封装，主要也是执行JS代码和实现WKWebView的代理方法的。同上面这个类类似

> ###  WebViewJavascriptBridge_js
> 里面主要写了一些JS的方法，JS端与Native”互动“的JS端的方法基 本上都在这个里面  JS通过WebViewJavascriptBridge._fetchQueue()转发不同的message data 和 callback回去，最终实现交互。

![js-app](js-app.png) 

以上就是此次研究这个库的内容，加上前篇所讲，总结这三个JS交互，第二种是目前我们app中所使用的，但是用原生的方法，使用起来很麻烦，也不便于管理， 第三种库使用简洁，兼容性高，推荐使用