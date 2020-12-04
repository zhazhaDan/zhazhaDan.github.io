---
title: '@synchronized在OC和swift中的前世今生'
date: 2018-05-27 13:52:48
toc: true
tags: 
    - synchronized
    - Obective-C
    - Swift
    - iOS
    - 锁
---
#### 什么是锁
当多个线程同时操作同一块资源或者说同一个对象的时候，可能会造成各种意想不到的情况(比如数据错乱、资源争夺、崩溃等)，而锁就是为了能够保证同一时刻只有一个线程在操作这个数据应运而生的。
<!-- more -->
iOS常用锁,当然不管那种锁，都是为了保证数据的原子性
> NSLock
> @synchronized
> dispatch_semaphore_wait


简单说一下NSLock的使用:

    TestObject * obj = [[TestObject alloc]init];
    [lock lock];
    [obj method1];
    [lock unlock];

着重探讨一下 synchronized

> synchronized的原理

synchronized关键字编译后，会在同步代码块的前后加上montor_enter和montor_exit两个指令。

> synchronized的使用方式

    @synchronized(OC对象，如果用self，但是要注意可能导致死锁){
        //加锁的代码
    }

synchronized 就是可以理解为互斥锁， synchronized里面传入的obj对象可以理解为互斥信号量，
> 什么是互斥锁？

互斥锁: 是一种用于多线程编程中，防止两条线程同时对同一公共资源进行读写的机制。
当我们通过@synchronized对一段代码加锁，信号量传入obj1的时候，其他线程如果使用的同样的信号量Obj1，那么就需要等待上一个线程执行完之后再执行，所以如果是对不同代码加锁，请使用不同的信号量。

> 比较NSLock和synchronized
很多博客也都说推荐用synchronized，因为使用起来简单方便，但是效率会比NSLock慢很多，但是就我个人考虑，现在的手机性能都很高了，基本都是无感的，这一点点性能的代价当然是好过产生bug的，当然不管是那一种方式，都是需要细心，一定要注意不要造成死锁的情况了。

> 实例思考，下面的打印记过是什么

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,   0), ^{
        @synchronized(obj) {
            sleep(10);
            NSLog(@"1");
        }
        sleep(3);
        NSLog(@"3");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        @synchronized(obj) {
            NSLog(@"2");
        }
    });

打印结果是

    2018-05-28 14:54:45.803498+0800 TestProj[18914:2407649] 1
    2018-05-28 14:54:45.803930+0800 TestProj[18914:2407661] 2
    2018-05-28 14:54:48.805917+0800 TestProj[18914:2407649] 3

这里分析一下，另个线程里我们用了同一个信号量，所以当1打印完之后才能打印2，那么这里思考一个问题，为什么1和2中间几乎是同时打印呢？
这里需要注意一下，sleep()函数是针对当前线程有效，所以sleep(2)是针对第二个线程sleep的，而sleep(10)是线程锁obj对象的，也就是这个obj这个信号量被锁住了10秒，那么NSLog(@"2")这段代码只要等到obj释放后，就可以开始执行了，所以1和2几乎同时打印。
那么这里如果将sleep(3)删除，可想而知，打印结果就是1，3，2
如果将第二个线程这么写
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(obj) {
            sleep(2);
            NSLog(@"2");
        }
    });

那么打印的结果会是什么呢？

    2018-05-28 15:08:10.846926+0800 TestProj[19137:2417813] 1
    2018-05-28 15:08:12.852428+0800 TestProj[19137:2417811] 2
    2018-05-28 15:08:13.852507+0800 TestProj[19137:2417813] 3


那么在swift中又是如何使用呢
很不幸的是在 Swift 中它已经 (或者是暂时) 不存在了。其实 @synchronized 在幕后做的事情是调用了 objc_sync 中的 objc_sync_enter 和 objc_sync_exit 方法，并且加入了一些异常判断。因此，在 Swift 中，如果我们忽略掉那些异常的话，我们想要 lock 一个变量的话，可以这样写：

    func synchronized(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
希望我的解释能够帮助到你

    



#### 参考文档
> [正确使用多线程同步锁@synchronized()](http://mrpeak.cn/blog/synchronized/)
> [LOCK](http://swifter.tips/lock/)
> [谈下iOS开发中知道的哪些锁? 哪个性能最差?SD和AFN使用的哪个? 一般开发中你最常用哪个? 哪个锁apple存在问题又是什么问题?](https://www.jianshu.com/p/70f97716881e)