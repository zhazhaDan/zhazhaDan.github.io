---
title: 使用atomic一定是线程安全的吗?
date: 2018-05-27 18:39:31
toc: true
tags:
    - atomic
    - nonatomic
    - Obective-C
    - iOS
---
一般当我们想要保证对象属性的线程安全的时候可以在定义属性的时候用 atomic 关键字来修饰，那么
这篇文章让我们来探讨一下atomic和nonatomic分别都替我们做了什么工作
<!-- more -->   

两个关键字修饰的OC对象 系统都会自动生成setter/getter方法，区别就在于一个会进行加锁操作，一个不会。系统默认是使用atomic的。
因为atomic做了线程锁，所以理论上讲atomic是要比nonatomic更加耗费性能、更慢。
atomic 系统会在生成的setter/getter方法里添加锁，但是这个锁仅仅是保证了setter/getter存取的安全，并不能保证数据结果正确，举个🌰

> A线程执行setter方法到一半的时候，B线程执行getter方法，那么B线程的getter方法会被阻塞，等到setter继续执行完成之后才能取到值。这里系统使用的也是 @synchronized 可以参考[这里](https://zhazhadan.github.io/2018/05/27/synchronized%E5%9C%A8OC%E5%92%8Cswift%E4%B8%AD%E7%9A%84%E5%89%8D%E4%B8%96%E4%BB%8A%E7%94%9F/)

> A、B、C等多个线程都要操作同一个对象setter，D线程要getter这个对象的值，那么每个线程都成保证各自数据的完整性，但是D线程最后get到的值并不能确定。

以上，所以atomic能够保证数据的完成性，也就是说他只是读写安全，并不能准确定义说他是线程安全的。因为线程可以对数据做很多操作，包括读写，还有release、retain,假如说对一个已经释放的对象进行release，就会导致crash

by the way

> @synthesize和@dynamic的区别
@synthesize var= _var是默认的，如果你没有手动实现setter/getter方法，那么编译器就会自动给你加上这两个方法
atomic关键字实现setter/getter方法如下

    @synthesize username = _username;
    - (void)setUsername:(NSString *)username {
        @synchronized(self) {
            if (_username != username) {
                _username = username;
            }
        }
       
    }
    - (NSString *)username {
        NSString * str = nil;
        @synchronized(self) {
            str = _username;
        }
        return str;
    }

@dynamic 则是告诉编译器，用户自己去实现setter/getter方法，但是如果你这么申明了，最后却没有手动去实现，那么编译可能是没问题的，可是到程序执行到obj.var = svar的时候，会因为找不到方法而crash.

> 参考文档 
[[爆栈热门 iOS 问题] atomic 和 nonatomic 有什么区别？](https://www.jianshu.com/p/7288eacbb1a2)