---
title: Mac下实现hexo搭建github个人博客
date: 2018-04-18 23:07:02
toc: true
tags:
    - hexo
    - github pages
    - mac
---
博主工作将近四年，仍是IT小白一个，仅此开始记录一下进阶之路吧。
# 常识普及
* Github提供了免费而强大的服务器，并且不限流量，这对于需求量不大，又希望能有点逼格的人来说简直就是福音(后悔现在才开始用)
* Github Pages可以被认为是用户编写的、托管在github上的静态网页。
* Hexo是帮你把Markdown文档转成静态网页的工具。
<!-- more -->
# 工作准备
* 你的电脑需要安装哪些工具：npm、Node.js、Git
* 你需要的账号：github账号。

# 搭建流程
* 创建仓库，username.github.io (username是你的github用户名，约定俗成一致的)
* 创建两个分支master和hexo
* 1 创建 username.github.io repository的时候默认会创建master分支，这个时候是无法创建新的分支的，可以创建一个readme.md
然后在 新建hexo分支并设置为默认分支
* 2 hexo分支负责存放网站文件 master负责存放生成的静态网页（这个是hexo _config.yml文件里配置的）
* 本地打开terminal配置好本地git 信息
* 利用git clone https://github.com/username/username.github.io.git拷贝仓库
* cd 到 git@github.io文件夹  执行以下步骤
* 1 npm install hexo-cli
* 2 hexo init Blog(hexo 初始化需要一个空文件夹，Blog是你自己命名的) 然后 cd 到 Blog文件夹里
* 3 npm install
* 4 npm install hexo-deployer-git --save
* 5 执行 hexo generate和 hexo server
即可通过浏览器输入localhost:4000访问hexo的一个静态网页，如果这里4000端口被占用 可以通过hexo server 5000
修改端口号
* 1 hexo init Blog命令时，Blog会生成以下文件目录
* **
    _config.yml
    db.json
    node_modules
    package.json
    public
    scaffolds
    source
    themes
** *
这个时候修改_config.yml文件
在文件末尾修改如下：
* **
    deploy:
    type: git
    repo: https://github.com/zhazhaDan/zhazhaDan.github.io.git
    branch: master
** *
* 2 执行 hexo generate和 hexo deployer （或者放到一步执行hexo g -d）
即可通过浏览器输入git@github.io访问你的主页了
* 记得返回git@github.io文件夹下将Blog内的文件提交到hexo分支 
依次执行 git add.、 git commit -m ""、git push origin hexo提交网站相关文件
# 注意事项
* 这里注意每次改动网页内容都要执行hexo g -d来重新部署github上，如果想要将来在多台电脑上能够编辑你的博客主页，那么所有的改动最好都要提交的hexo分支上。
* 养成一个好的习惯非常重要

# 参考文档
[使用hexo，如果换了电脑怎么更新博客？](https://www.zhihu.com/question/21193762)
[搭建一个免费的，无限流量的Blog----github Pages和Jekyll入门](http://www.ruanyifeng.com/blog/2012/08/blogging_with_jekyll.html)


