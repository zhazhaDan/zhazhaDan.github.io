---
title: 线程探索三-NSOperation
date: 2021-08-22 13:26:22
tags:
---
本文属于多线程系列：  
[多线程探索一-概念](../_posts/多线程探索一-概念.md)  
[多线程探索二-GCD](../_posts/多线程探索二-GCD.md)  
[多线程探索三-NSOperation](../_posts/多线程探索三-NSOperation.md)  
[多线程探索四-锁](../_posts/多线程探索四-锁.md)  

## 概念
NSOperation是APPLE推出的基于 GCD 封装的一套面向对象的API，接口更加简洁，上手更加方便。   
优点 
> 1. 可以直接设置最大并发量
> 2. 可以设置operation的执行顺序
> 3. 可以通过KVO监听任务的状态
> 4. 可以通过添加 completionBlock 在任务结束后做一些处理 

## API
### NSOperation 
NSOperation是一个抽象类，无法直接使用。系统提供了两个子类的实现，可以直接上手，当然也可以自己继承定制operation。 


![NSOperation状态图](NSOperation状态图.png)

#### 1. NSInvocationOperation 
非并发的operation，通过 target selector添加任务
#### 2. NSBlockOperation
并发的operation，通过添加block添加并发任务，可以在一个opertation中添加多个block并发执行。
当所有的block都执行完成后，operation会自动finish.

测试发现   
``` + blockOperationWithBlock: ``` 添加的任务 一般在当前线程执行  
``` - addExecutionBlock: ``` 有开启新线程的能力

#### 3. custom Operation 
自定义operation, 抽象类提供了几个方法 [官方文档](https://developer.apple.com/documentation/foundation/nsoperation?language=objc) 其实超级详细   

非并发的operation 
``` main ``` 一般推荐把task内容放在这里, 如果需要访问operation里的数据，记得保证线程安全

并发的operation 至少需要重写以下几个方法
```
start       此方法默认在当前线程，所以如果需要异步开启任务，需要在这里开启新线程 去执行任务 
asynchronous    当前是同步还是异步的
executing       当前operation是否正在执行
finished        当前operation是否执行完
``` 
finished这个状态在操作完成后请及时设置为YES，因为NSOperationQueue所管理的队列中，只有isFinished为YES时才将其移除队列，这点在内存管理和避免死锁很关键。

下面是个demo  
```

#import "CustomOperation.h"

@interface CustomOperation()
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@end

@implementation CustomOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)main {
    if (self.isCancelled) {
        return;
    }
    NSLog(@"begin executing %@ at %@", NSStringFromSelector(_cmd), [NSThread currentThread]);

    for (int i = 0; i < 10; i++) {
        if (self.isCancelled) {
            self.executing = NO;
            self.finished = NO;
            return;
        }
        NSLog(@"%@ at thread %@", NSStringFromClass([self class]), [NSThread currentThread]);
    }
    self.executing = NO;
    self.finished = YES;
    NSLog(@"finish executing %@ at %@", NSStringFromSelector(_cmd), [NSThread currentThread]);
}

- (void)start {
    @synchronized (self) {

        if (self.isCancelled) {
            return;
        }
        [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil]; //默认start在主线程，如果想开启子线程，就需要手动开始子线程执行
    //    [self main];
        self.executing = YES;
    }
}

- (void)cancel {
    @synchronized (self) {
        if (self.isFinished) {
            return;
        }
        [super cancel];
        if (self.isExecuting) {
            self.executing = NO;
        }
        if (!self.isFinished) {
            self.finished = YES;
        }
    }
}



- (BOOL)isAsynchronous {
    return YES;
}


// custom 通知KVO
- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

@end

```

> ### KVO   
> isCancelled - read-only  
isAsynchronous - read-only  
isExecuting - read-only  
isFinished - read-only  
isReady - read-only  
dependencies - read-only  
queuePriority - readable and writable  
completionBlock - readable and writable  


### NSoperationQueue
NSoperationQueue 和 NSOperation配合使用 
NSoperationQueue内的对象是线程安全的
NSoperationQueue同时支持KVC和KVO  
```
operations - read-only
operationCount - read-only
maxConcurrentOperationCount - readable and writable
suspended - readable and writable
name - readable and writable
```

NSOperation 可以设置Dependency 但是 dependency的设置需要在operation 添加到 operation queue 之前才能生效。dependency可以跨queue。 当queue的maxConcurrentOperationCount == 1 的时候 无效。

NSOperationQueuePriority  默认是normal，当有需要时并且在没有设置dependency的情况下使用。 (不过本人尝试后发现并没有什么效果 ~~)  

```
addBarrierBlock:
```
此方法是iOS13以后添加的，用法类似dispatch_barrier,详情可以参考上篇 [多线程探索二-GCD](../_posts/多线程探索二-GCD.md)  ,可以用于在queue里前面添加的task执行后做一些同一个处理。 

> tips: 建议研究下SDWebImage，看下人家是怎么用NSOperation的。

