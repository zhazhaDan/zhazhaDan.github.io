---
title: 基于SDWebImage的多线程分析
date: 2020-08-05 11:18:59
tags:
    - SDWebImage
    - 多线程
    - 线程锁
---
**1. 关于锁**   
<!-- more -->   

**1.1. NSLock**
```
_lock.lock()   
_lock.unlock()  
```

**2. synchronized** 
synchronized 可以嵌套 内部有递归锁 
```  
@synchronized(obj) {}   
```
**3. objc_sync**
```  
@try {  
    objc_sync_enter(obj);
} @finally {
    objc_sync_exit(obj);    
}
```

**4. ispatch_semaphore_t 作锁用  (SDImage)**
```
 dispatch_semaphore_create(1)
#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVE`R);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);
```


总之锁如果用不好，尽量避免使用：   
1. 消耗性能     
1. 有死锁的风险

[参考文档1](http://yulingtianxia.com/blog/2015/11/01/More-than-you-want-to-know-about-synchronized/)    
[参考文档2](https://satanwoo.github.io/2019/01/01/Synchronized/)


**2. 分析源码中的多线如何处理**
- 'SDWebImage', '4.4.6' 以下简称 SD   
- 本篇剖析一下SD的多线程下载处理  
  
**2.1 下载队列的线程安全**  
NSOperation、NSOperationQueue 是基于 GCD 更高一层的封装，完全面向对象。但是比 GCD 更简单易用、代码可读性也更高。    
NSOperationQueue控制并发和串行只需要设置maxConcurrentOperationCount    
调度队列 更可控 （eg. SDWebImageDownloaderExecutionOrder）FIFO LIFO
![SDWebImage4.4.6_operation](SDWebImage4.4.6_operation.png)   

业务分析：Art的PDF以后如果还有需求感觉也可以参考SD的这个模式，控制并发数和下载速度更方便




**2.2 内存缓存的线程安全(NSCache)**

NSCache是线程安全的，在多线程操作中，不需要对Cache加锁。读取缓存的时候是在主线程中进行，由于使用NSCache进行存储，所以不需要担心单个value对象的线程安全。


**2.3 磁盘缓存的线程安全(NSFileManager)** 
所有磁盘读写在一个ioqueue内，保证串行(art类似)



- 参考文档 
- - [NSOperation](https://juejin.im/post/5a9e57af6fb9a028df222555)