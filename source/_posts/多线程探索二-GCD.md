---
title: 多线程探索二-GCD
date: 2021-08-21 16:46:01
tags:
---
本文属于多线程系列：  
[多线程探索一-概念](../_posts/多线程探索一-概念.md)  
[多线程探索二-GCD](../_posts/多线程探索二-GCD.md)  
[多线程探索三-NSOperation](../_posts/多线程探索三-NSOperation.md)  
[多线程探索四-锁](../_posts/多线程探索四-锁.md)  

## 概念 

什么是GCD 
> Execute code concurrently on multicore hardware by submitting work to dispatch queues managed by the system  
> 通过提交工作到由系统管理的调度队列，在多核硬件上并发执行代码。  
> Grand Central Dispatch（GCD） 是 Apple 开发的一个多核编程的较新的解决方法。它主要用于优化应用程序以支持多核处理器以及其他对称多处理系统。它是一个在线程池模式的基础上执行的并发任务。在 Mac OS X 10.6 雪豹中首次推出，也可在 iOS 4 及以上版本使用

## 优点
- GCD自动管理线程的生命周期(创建/调度/销毁)
- 不需要单独管理，直接使用API执行任务即可

## API讲解 


### dispatch_barrier 栅栏
顾名思义，它起到了一个栅栏的作用，栅栏任务一定是在当前队列的任务完成之后开始，栅栏任务全部执行完之后才会开始之后的任务   
栅栏函数的执行一定是要等到上一个栅栏任务完成之后才会开始下一个   
![dispatch_barrier](dispatch_barrier.png) 
那么利用栅栏函数我们可以做些什么呢？ 
- 实现高效率的数据访问和文件读写
- 避免数据竞争，即线程安全的读写
  github上传了一个利用dispatch_barrier实现了一个多读单写的数组，当然这只是一个[Demo](https://github.com/zhazhaDan/GDDemo/tree/master/GDDemo/GDDemo/Other/BarrierSafeArrayOC) 

``` 
dispatch_barrier_async
 1. 立马返回 == 不阻塞当前线程
 2. 通过 dispatch_queue_create 创建的 <font color=red> 并发线程 </font>
 3. 当一个 barrier block到栈底了，它不会立马执行，会等到当前并发队列之行完当前的 block
 4. 如果你用了一个串行队列或者全局并发队列，这个函数的作用就和 dispatch_async 的作用一样了。
 ```

```  
dispatch_barrier_sync
 1. 不会立马返回，block执行完之后返回 == 阻塞当前线程
 2. 通过 dispatch_queue_create 创建的 并发线程
 3. 当一个 barrier block到栈底了，它不会立马执行，会等到当前并发队列之行完当前的 block
 4. 如果你用了一个串行队列或者全局并发队列，这个函数的作用就和 dispatch_sync 的作用一样了
 5. 他不会对block进行copy，也不会对他进行retain，因为他是同步的
 6. 在当前队列中调用 dispatch_barrier_sync 会导致死锁
 ```
### dispatch_semaphore 
信号量 通过计数来控制线程的开关, 计数小于0时阻塞线程，当计数大于等于0后可通过 
1. dispatch_semaphore_create 创建信号量
2. dispatch_semaphore_signal 发送信号，信号+1
3. dispatch_semaphore_wait   使信号量-1，当小于0时，阻塞线程
   
信号量的使用场景  
1. 异步任务变成同步执行，保持线程同步
2. 作为线程锁，保证线程安全 
   
```
    dispatch_queue_t queue = dispatch_queue_create("test", DISPATCH_QUEUE_CONCURRENT);

    NSLog(@"current thread %@", [NSThread currentThread]);

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_async(queue, ^{
        NSLog(@"dispatch_async %@", [NSThread currentThread]);
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"dispatch_semaphore_wait %@", [NSThread currentThread]);

```
```
2021-08-22 00:37:54.097070+0800 GDDemo[80131:5289843] current thread <NSThread: 0x6000022f4400>{number = 1, name = main}
2021-08-22 00:37:54.097474+0800 GDDemo[80131:5289964] dispatch_async <NSThread: 0x60000227d2c0>{number = 7, name = (null)}
2021-08-22 00:37:54.097985+0800 GDDemo[80131:5289843] dispatch_semaphore_wait <NSThread: 0x6000022f4400>{number = 1, name = main}

```

### dispatch_group
1. dispatch_group_async 相当于 dispatch_async+dispatch_group_enter/dispatch_group_leave的组合
2. dispatch_group_enter/dispatch_group_leave  当使用dispatch_async时，调用这两个方法通知group有任务加入/离开
3. dispatch_group_notify group中任务完成后调用
4. dispatch_group_wait  先阻塞线程不让其向下执行，等到group内的任务执行完之后继续向下执行。

### dispatch_after 

```
dispatch_queue_t queue = dispatch_queue_create("test", DISPATCH_QUEUE_CONCURRENT);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), queue, ^{
        NSLog(@"dispatch_after current thread %@", [NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        NSLog(@"dispatch_async at thread %@", [NSThread currentThread]);
    });

    dispatch_sync(queue, ^{
        NSLog(@"dispatch_sync at thread %@", [NSThread currentThread]);
    });

```

打印结果 
```
2021-08-21 23:43:24.588899+0800 GDDemo[79102:5235427] dispatch_sync at thread <NSThread: 0x600001edc700>{number = 1, name = main}
2021-08-21 23:43:24.589172+0800 GDDemo[79102:5235535] dispatch_async at thread <NSThread: 0x600001e59240>{number = 8, name = (null)}
2021-08-21 23:43:26.588595+0800 GDDemo[79102:5235536] dispatch_after current thread <NSThread: 0x600001e99280>{number = 7, name = (null)}

``` 
总结几点：   
1. dispatch_after 方法并不是在指定时间之后才开始执行处理，而是在指定时间之后将任务追加到主队列中。
2. dispatch_after 有能力开启一个新线程
3. dispatch_after 延时时间并不能完全准确
4. 如果 dispatch_time函数用 DISPATCH_TIME_NOW 的话，不如直接用dispatch_async
   
### dispatch_once 
```
 dispatch_once_t one;
    dispatch_once(&one, ^{
        NSLog(@"1 at thread %@", [NSThread currentThread]);
    });
```

app生命周期内只调用一次，多用于单例 
dispatch_once是同步任务，要等到block执行后才会返回
这里可以引申出两个问题： 
1. 单例如何销毁
2. 单例如何避免创建多个，如果我在其他地方调用alloc init呢？


### dispatch_apply 

1. dispatch_apply 按照指定的次数将指定的任务追加到指定的队列中，并等待全部队列执行结束。
2. 无论是在串行队列，还是并发队列中，dispatch_apply 都会等待全部任务执行完毕，这点就像是同步操作，也像是队列组中的 dispatch_group_wait方法。 
```
    dispatch_queue_t queue = dispatch_queue_create("test", DISPATCH_QUEUE_CONCURRENT);

    CFAbsoluteTime currentTime0 = CFAbsoluteTimeGetCurrent();
    for (int i ; i < 10000; i++) { }
    CFAbsoluteTime totalTime0 = CFAbsoluteTimeGetCurrent() - currentTime0;
    NSLog(@"for loop total time is %f", totalTime0);

    CFAbsoluteTime currentTime1 = CFAbsoluteTimeGetCurrent();
    dispatch_apply(10000, queue, ^(size_t index) {

    });
    CFAbsoluteTime totalTime1 = CFAbsoluteTimeGetCurrent() - currentTime1;
    NSLog(@"dispatch_apply total time is %f", totalTime1);

    CFAbsoluteTime currentTime2 = CFAbsoluteTimeGetCurrent();
    dispatch_sync(queue, ^{
        for (int i ; i < 10000; i++) { }
    });
    CFAbsoluteTime totalTime2 = CFAbsoluteTimeGetCurrent() - currentTime2;
    NSLog(@"dispatch_sync total time is %f", totalTime2);

```

实际执行结果  
```
2021-08-22 00:18:26.256352+0800 GDDemo[79814:5271453] for loop total time is 0.000017
2021-08-22 00:18:26.256790+0800 GDDemo[79814:5271453] dispatch_apply total time is 0.000249
2021-08-22 00:18:26.256949+0800 GDDemo[79814:5271453] dispatch_sync total time is 0.000010

```

看到这个结果我还挺奇怪的，dispatch_apply反而是最耗时的。
