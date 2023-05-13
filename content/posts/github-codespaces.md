---
title: "Github Codespaces"
date: 2023-05-12T14:51:38Z
draft: false
---

## [github codespaces](https://docs.github.com/zh/codespaces)

#### 代码空间

- 云开发环境(默认镜像)，已经安装了常用的开发环境：如Python、Docker、Node.js等

    >   👋 Welcome to Codespaces! You are on our default image. 
    >   It includes runtimes and tools for Python, Node.js, Docker, and more. See the full list here: https://aka.ms/ghcs-default-image
    >   Want to use a custom image instead? Learn more here: https://aka.ms/configure-codespace
    >   🔍 To explore VS Code to its fullest, search using the Command Palette (Cmd/Ctrl + Shift + P or F1).
    >   📝 Edit away, run your app as usual, and we'll automatically make it available for you to access.

- 云VSCode，自带命令行，可安装插件，云端开发
- 可以尝试用它来部署VPN节点(免费🪜)
- 部署web项目
- 一台VPS[2C-4G-32G-RAM]

#### 限制
- 同时最多开启两个代码空间

#### 创建
- method1
    1.打开仓库
    2.选择codespaces
    3.点击+/绿色create按钮
    4.打开一个vscode界面代表创建成功
- method2
    1.打开仓库
    2.选择codespaces
    3.选择...
    4.点击new with option
    5.选择分支
    6.选择区域
    7.选择机器
    ```
    2C·4G·RAM·32G
    4C·8G·RAM·32G
    ```
    8.点击create
    
#### 导出保存修改
- method1
    > git提交[跟本地机器一样]
- method2
    > github首页点击codespaces找到对应仓库实例
    > 点击...
    > 点击Export Change
    > 等待分支创建成功 - 修改已被提交到新的分支

#### 入门

学习[核心概念](https://docs.github.com/zh/codespaces)

配置和管理
详细了解[机密管理](https://docs.github.com/zh/codespaces/managing-your-codespaces/managing-encrypted-secrets-for-your-codespaces)和[端口转发](https://docs.github.com/zh/codespaces/developing-in-codespaces/forwarding-ports-in-your-codespace)等功能。

本地开发
从[Visual Studio Code](https://docs.github.com/en/codespaces/developing-in-codespaces/using-github-codespaces-in-visual-studio-code)或JetBrains中访问代码空间。