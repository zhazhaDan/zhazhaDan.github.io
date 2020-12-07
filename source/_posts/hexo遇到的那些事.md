---
title: hexo遇到的那些事
date: 2018-05-26 11:22:55
toc: true
tags: 
    - hexo
    - github pages
    - mac
    - theme
---
上一篇讲解了hexo搭建GitHub个人博客，我们建了两个分支
> master 分支用来存放我们生成的静态页面文件
> hexo 分支用来存放我们配置的git和hexo文件，包括主题等
但是在实际使用，我们经常会遇到各种情况，文章中我们总结一下常会遇见，或者说笔者遇见的问题

<!-- more -->


### 多电脑更新博客
> git clone你的hexo分支代码到本地，然后分别执行 npm install hexo,npm install, npm install hexo-deployer-git命令 
基本就OK了
> 亲测有效： 创建新的空目录 hexo install, copy 如下必要文件进入 xxx.github.io目录下  
> - ![hexo init](hexo_init.png)   
> 
> - 将老的文章相关文件copy到对应位置即可  
> ![hexo resource](hexo_resource.png)  
> 
> - 最后 hexo g, hexo s 本地部署检查一下，没有问题就可以继续编辑或者提交了
> 


### 主题无法推送远程Git
查看远程仓库里主题目录，你可能会看到这样的图片
![1](theme_default.png)
这种情况可能导致的结果就是，你换一台电脑，需要重新clone一下主题，否则在本地无法生效、调试。
更加糟糕的情况是，如果你在主题里面做了很多修改，那么，恭喜你！
所以这个时候，你就要确保把你本地的theme推送到远程分支上。
以下操作有效(next 是你需要推送的主题名)

    git rm -rf --cached themes/yilia
    git add theme/next/*
    git commit -m ""
    git push

之后再查看就是这样的(我用的是yilia主题)
![2](theme_normal.png)


### 首页文章列表里，文章内容全部会展示怎么办
笔者用的是yilia主题，默认是把所有文章内容都展示出来，这可不合适，以我对待工作的热情，这么下去，不是坑大了嘛。
所以查了一下，一个小技巧
在你觉得先要展示在首页的文字后面添加下面这句话就哦了。
![3](more.png)

### 图片等资源无法保存
可能是笔者没有研究透彻hexo的各种使用，一开始把资源文件都放到了public下，殊不知，每次hexo g的时候，都会根据source/下的md文件等重新编译，替换到public里面的资源，所以直接在public下添加资源的方法是不可行的，如需，如下可尝试
> 根目录下编辑  _config.yml
修改这个地方(默认是false)  post_asset_folder: true
这么修改之后，hexo new 方法除了会生成md文件外，还会生成同名文件夹，引用的时候，直接用文件名引用即可。

### 如何关联自己的域名
由于自己没有任何前端的了解，对域名，DNS解析也不是很懂的样子，所以只能简单说下步骤了。
我是去阿里云上花了29大洋买的一个域名[viris.cn](http://www.viris.cn)(这里真的不是打广告，只是顺便宣传一下，啊哈哈~)
然后去阿里云的[管理平台](https://dns.console.aliyun.com/?accounttraceid=b3eb9fcd-18bd-4829-8c6e-a4b64998b1f1#/dns/setting/viris.cn)云解析 -> 解析设置 -> 添加记录  作如下配置
![dns配置](aliyun_dns.png)
- 分别添加 记录类型A的时候添加你的github.io的IP地址，这里不知道的话 打开的你的teminal 然后ping一下你的GitHub主页地址,得到的IP输入到记录值里
- 添加 CNAME 记录类型， 主机记录填你想设置的前缀，我用的是wwww和@，记录纸就写你的username.github.io

最后，去你的博客目录下，找到source目录，创建一个文件名为CNAME的文件，必须大写，没有后缀，里面写上你的域名，比如我买的域名是viris.cn 就写上viris.cn

完美！
有其他问题，一边探索，一边补充哦，欢迎跟我交流沟通哦~