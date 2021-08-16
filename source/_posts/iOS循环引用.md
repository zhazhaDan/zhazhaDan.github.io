---
title: iOS循环引用
date: 2021-08-08 22:41:03
tags:
- 循环引用
- 内存泄漏
- block
- NSTimer/CADisplayLink
---

## 循环引用/内存泄漏

> 首先我们说一下什么是循环引用，说白了就是互相持有，无法释放

![循环引用](circle-1.png)

> 那么如果想要解决这个问题要怎么做呢？也很简单，打破这个循环，让其中一方变成弱引用
>
![解循环引用](circle-2.png)

> 道理是这么个道理，当然了，说起来是很简单，要想真正解决这个问题，首先要了解都有哪几种方式会引发循环引用，了解其中原理之后，想要解决问题不就简单咯。

<!-- more -->

- ### block 
  >  [探索block-一](探索block-一.md)

  > 这篇里我们有讲到block的源码及本质，下面我们基于此快速了解一下为什么block会产生循环引用。

> OC
  ``` 
    Persion * p = [[Persion alloc] init];
    p.name = @"GDD";
    Persion * p2 = [[Persion alloc] init];
    p2.name = @"🐶";
    p.printBlock = ^(NSString * _Nonnull name) {
        NSLog(@"%@-%@", p.name, p2.name);
    };
  ```
> C++
```
struct __main_block_impl_0 {
struct __block_impl impl;
struct __main_block_desc_0* Desc;
Persion *__strong p;
Persion *__strong p2;
__main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Persion *__strong _p, Persion *__strong _p2, int flags=0) : p(_p), p2(_p2) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```
> 可以看到在block里其实是做了强引用的：   
p -> printBlock  printBlock -> p.name
那么解这种循环引用其实也很简单了:  
> -  __unsafe_unretained:不会产生强引用,不安全,指向的对象销毁时,指针存储的地址不变
> - __weak:不会产生强引用,指向的对象销毁时,会自动让指针置为nil
> - __block能用解决block内部想修改外部的局部变量的问题,也能解决循环引用的问题

这里需要着重说一下block，我们先看一下，如果我用__block申明，编译器会做什么 
```
struct __Block_byref_weakP_0 {
  void *__isa;
__Block_byref_weakP_0 *__forwarding;
 int __flags;
 int __size;
 void (*__Block_byref_id_object_copy)(void*, void*);
 void (*__Block_byref_id_object_dispose)(void*);
 typeof (p) weakP;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  Persion *__strong p2;
  __Block_byref_weakP_0 *weakP; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Persion *__strong _p2, __Block_byref_weakP_0 *_weakP, int flags=0) : p2(_p2), weakP(_weakP->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```


编译器会对__block修饰的 值/对象 包装成一个对象，__forwarding就指向的是这个对象自己的地址，如此一来，即可以通过__forwarding指针来寻找并做修改了。  
需要注意的是，ARC下当使用__block来解循环引用的时候，实际上需要手动将__block的引用指向nil   
这其实是一个三角引用   
p -> block -> __block_p -> p

  

- ### delegate
 > 这个就很常见了，一般我们都用weak修饰，但这里抛出一个问题，OC中的assign 能否修饰 delegate?
- 答案是可以的，只是这两种方式在实际结果不太一样，简单来说就是：
- - weak表示的是一个弱引用，这个引用不会增加对象的引用计数，并且在所指向的对象被释放之后，weak指针会被置为nil。
- - assign 只是单纯的指针赋值。举例如果把对象A的指针赋值给assign声明的成员变量B，则B只是简单地保存此指针的值，且并不持有对象A，也就意味着如果A被销毁，则B就指向了一个已经被销毁的对象，如果再对其发送消息会引发崩溃。

- ### NSTimer/CADisplyLink
- - #### NSTimer
    通常我们创建的timer有几种方式
    - 1. 
    ```Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(test), userInfo: nil, repeats: true)```

    

    ``` Creates a timer and schedules it on the current run loop in the default mode. ```

    苹果官方文档是这么说的，如果是在主线成创建的，那么自然加入到主线程中，这里有个坑是，当发生滚动事件时，timer不会执行。如果加入的是子线程，需要手动开启runloop，因为子线程的runloop默认是不开启的。 

    - 2. 
    ```let timer = Timer.init(timeInterval: 1, target: self, selector: #selector(test), userInfo: nil, repeats: true)```
    ```RunLoop.current.add(timer, forMode: RunLoop.Mode.common)```

    官方文档这么说的：
    ```
    target
    The object to which to send the message specified by aSelector when the timer fires. The timer maintains a strong reference to target until it (the timer) is invalidated.
    ```
    和上面一样，只是这种方式需要手动添加runloop。
    需要注意的是 以上这两种创建timer的方式，会将 self传给timer强引用，故需要在 timer.invalidate()后才会释放引用。
    但有时候我们的代码可能在dealloc/deinit的时候才会去 invalidate,那么一定要注意，这个时候，如果没有其他处理，就会导致循环引用了。

    那么，如果我的释放时机只能是dealloc/deinit的话，有没有其他方式解决呢？有的，代理模式。
    创建一个代理类，来弱持有当前的self 

    ```
    class GDProxy: NSObject {
    weak var target: NSObjectProtocol?
    var sel: Selector?


    public convenience init(target: NSObjectProtocol?, sel: Selector?) {
        self.init()
        self.sel = sel
        self.target = target
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return self.target
    }
    // NSObject 一些方法复写

        override func isEqual(_ object: Any?) -> Bool {
            return target?.isEqual(object) ?? false
        }

        override var hash: Int{
            return target?.hash ?? -1
        }

        override var superclass: AnyClass?{
            return target?.superclass ?? nil
        }
    
        override func isProxy() -> Bool {
            return true
        }

        override func isKind(of aClass: AnyClass) -> Bool {
            return target?.isKind(of: aClass) ?? false
        }

        override func isMember(of aClass: AnyClass) -> Bool {
            return target?.isMember(of: aClass) ?? false
        }

        override func conforms(to aProtocol: Protocol) -> Bool {
            return  target?.conforms(to: aProtocol) ?? false
        }

        override func responds(to aSelector: Selector!) -> Bool {
            return target?.responds(to: aSelector) ?? false
        }

        override var description: String{
            return target?.description ?? "nil"
        }

        override var debugDescription: String{
            return target?.debugDescription ?? "nil"
        }

        deinit {
            print("Proxy释放了")
        }
    }


    ```

    使用的如下即可：
    ```
    let proxy = GDProxy.init(target: self, sel: #selector(test))
    let time = Timer.scheduledTimer(timeInterval: 1, target: proxy, selector: #selector(test), userInfo: nil, repeats: true)
    ```

    - 3.
    ``` Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in } ``` 

    这种方式是通过block回调，不会持有self
- - #### CADisplayLink
     CADisplayLink和NSTimer类似 
    ```
    let weakTarget = GDProxy.init(target: self, sel: #selector(linkStep))
    let v = CADisplayLink.init(target: weakTarget, selector: #selector(linkStep))
    v.add(to: RunLoop.current, forMode: .common)
    ```
## 检测工具

- instrument
- FLEX


> 参考文档 
> - [关于block的循环引用](https://juejin.cn/post/6943242244497358885)
> - [iOS循环引用/内存泄漏检测工具](https://www.jianshu.com/p/df4988adb95e)