---
title: iOS下webView和JS交互
date: 2020-12-07 13:03:16
tags: 
    - js交互
    - wkwebview
    - JavaScriptCore
    - JavaScriptBridge
---

# 背景
* h5和native 交互代码冗余 不清晰 多人开发时效率地下
  
# 目的
* 为了寻找更搞笑的编程开发方式，节省代码量，以及多人开发的效率   
<!-- more -->
# 过程探索
##  JavaScriptCore 
> - 官方解释   
> The JavaScriptCore Framework provides the ability to evaluate JavaScript programs from within Swift, Objective-C, and C-based apps. You can use also use JavaScriptCore to insert custom objects to the JavaScript environment.  
> JavaScriptCore框架提供了从Swift、Objective-C和基于c的应用程序中评估JavaScript程序的能力。您还可以使用JavaScriptCore将定制对象插入到JavaScript环境中。   
> 苹果爸爸在iOS7.0以后推出的官方库，目前看起来是适用于UIWebView(官方以不推荐使用) 


下面说一下使用方法
> 关键词： JSContext  JSValue  JSExport  

- JSExport
继承并申明你需要到protocol - 注入到JS里到function 

```
@objc protocol SwiftJavaScriptProtocol: JSExport {
    func test(_ value: String?)
    // js调用App的功能后 App再调用js函数执行回调
    func callHandler(handleFuncName: String)

    var stringCallback: (@convention(block) (String) -> String)? { get set }
}
```
申明一个继承于NSObjectt的class, 并实现你的protocol  
```
class SwiftJavaScriptModel: NSObject, SwiftJavaScriptProtocol  {
    weak var jsContext: JSContext? //js 的执行环境，调用js 或者注入js
    var stringCallback: (@convention(block) (String) -> String)? // swift里想要让JS能够调用我们的clourse，一定要用这个关键字

    func test(_ value: String?) {
        print("js call test(_ value: \(value ?? ""))")
    }

    func callHandler(handleFuncName: String) {
        let jsHandlerFunc = self.jsContext?.objectForKeyedSubscript("\(handleFuncName)")
        let dict = ["name": "sean", "age": 18] as [String : Any]
        jsHandlerFunc?.call(withArguments: [dict])
    }

    override init() {
        super.init()
        self.stringCallback = {
            [weak self] value in
            print("SwiftJavaScriptModel stringCallback \(value)")
            return value.appending("this is append string")

        }
    }
}


```

最后，通过UIWebView的特性，获取JSContext,并将我们的function注入到上下文 
```
extension JSCoreVC: UIWebViewDelegate {
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if let jsContext = webView.value(forKeyPath:"documentView.webView.mainFrame.javaScriptContext") as? JSContext {
            let model = SwiftJavaScriptModel()
            model.jsContext = jsContext
            jsContext.setObject(model, forKeyedSubscript: ("WebViewJavascriptBridge" as NSString)) //注入
            jsContext.evaluateScript(self.htmlContent)
            jsContext.exceptionHandler = {
                [weak self] (context, exception) in
                guard let self = self else { return }
                print("exception：", exception)

            }
        }
    }
}

```
- `WebViewJavascriptBridge` 注意，这里注入的名字即是JS调用的名字，JS调用我们的函数和自己的使用方式一样,举例如下   
  
```
<div class="btn-block" onclick="WebViewJavascriptBridge.test('this is toast')">
    test
</div>
<div class="btn-block" onclick="appStringCallbackFunc('this is toast')">
    stringCallback
</div>
<script type="text/javascript">
    function appStringCallbackFunc(arg) {
        let value = WebViewJavascriptBridge.stringCallback('this is toast')
        document.getElementById('js-content').innerHTML = "App调用js回调函数啦， 返回 ->" + value;
    }
</script>
```
看起来很方便吧，app -> JS 也很方便    

``` 
let context = JSContext()
let _ = context?.evaluateScript("var triple = (value) => value + 3") //注入
let returnV = context?.evaluateScript("triple(3)") // 调用
print("__testValueInContext --- returnValue = \(returnV?.toNumber())")
        
```


##  WKWebView
> - 官方解释  
> You can make POST requests with httpBody content in a WKWebView.
After creating a new WKWebView object using the init(frame:configuration:) method, you need to load the web content. Use the loadHTMLString(_:baseURL:) method to begin loading local HTML files or the load(_:) method to begin loading web content. Use the stopLoading() method to stop loading, and the isLoading property to find out if a web view is in the process of loading. Set the delegate property to an object conforming to the WKUIDelegate protocol to track the loading of web content. See Listing 1 for an example of creating a WKWebView programmatically.  
> 你可以在WKWebView中用httpBody内容发出POST请求。
在使用init(frame:configuration:)方法创建一个新的WKWebView对象之后，您需要加载web内容。使用loadHTMLString(_:baseURL:)方法开始加载本地HTML文件，或使用load(_:)方法开始加载web内容。使用stopLoading()方法停止加载，使用isLoading属性查明web view是否在加载过程中。将委托属性设置为符合WKUIDelegate协议的对象，以跟踪web内容的加载。清单1给出了以编程方式创建WKWebView的示例。

WKWebView关键词  
> WKUIDelegate  WKNavigationDelegate WKScriptMessageHandler

```
/*
     实现原理：
     1、JS与iOS约定好xdart协议，用作JS在调用iOS时url的scheme；
     2、JS拿到的url：(xdart://lot_detail?id=123)；
     3、iOS的WKWebView在请求跳转前会调用-webView:decidePolicyForNavigationAction:decisionHandler:方法来确认是否允许跳转；
     4、iOS在此方法内截取xdart协议获取JS传过来的数据，执行内部schema跳转逻辑
     5、通过decisionHandler(.cancel)可以设置不允许此请求跳转 decisionHandler一定要调用
     */
    //! WKWeView在每次加载请求前会调用此方法来确认是否进行请求跳转
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {return}
        guard let scheme = url.scheme else {return}

        if scheme == "xdart" {
            // THSchemeManager.handleScheme(url.absoluteString)
        }
        decisionHandler(.allow)

    }
```

WKUIDelegate 基于JS系统的几个内部方法 实现一下方法要调用对应的completionHandler，否则崩溃
```
func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        // call toast
        completionHandler()
}

func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        // call alert
        completionHandler(true)
}
func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        // call input
        completionHandler("this is a message")
}
```

WKScriptMessageHandler 重点来了，这是苹果爸爸推荐使用的JS交互

```
let content = WKUserContentController()
content.add(self, name: "artproFunc") //此方法会造成循环引用，注意时机释放
let config = WKWebViewConfiguration()
config.userContentController = content
wkwebV = WKWebView.init(frame: self.view.bounds, configuration: config)
```
> - 这里往content里注入的是JS调用APP的函数 
> JS通过window.webkit.messageHandlers.artproFunc.postMessage()给artproFunc发送消息
> 我们的解析在此方法里 
```
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name != self.applicationName { return }
        if let body = message.body as? [String: Any],
           let method = body["method"] as? String {
            let aSel = NSSelectorFromString(method)
            if !self.canPerformAction(aSel, withSender: nil) {
                return
            }
            let para = body["parameter"]
            let callback = body["callback"]
        }
}

```
以artpro为例，我们是将 artproFunc当作了一个通道，所有的function都走message.body分发出来，所以会有switch case 解析 body中的method，然后再进行不同的方法分发。
> 缺点
> - 代码冗余
> - 字符串分发，容易出错
> - 函数格式各式各样，多人开发，他人不好接手
> ![artpro现状](artpro_userContent.png)


## WebViewJavascriptBridge 
最近研究JS和iOS native交互，偶然发现的库发现github上用的人也不少,感觉还不错的样子，就研究了下使用方法   
> ![WebViewJavascriptBridge_star](WebViewJavascriptBridge_star.png)

看起来很简单的样子 
```
bridge = WebViewJavascriptBridge.init(webV)
// js call app
bridge.registerHandler("testCallHandler") { [weak self](data, callback) in
    guard let self = self else { return }
    callback?("Response from testCallHandler")
}
// app call js
self.bridge.callHandler("testJavascriptHandler", data: ["foo": "before ready"])
```
> WebViewJavascriptBridge 原理将在下篇文章中剖析
> [参考文档1](https://juejin.cn/post/6844903855189164040)

