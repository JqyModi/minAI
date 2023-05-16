---
title: "Terminal Guild"
date: 2023-05-16T15:38:29Z
draft: false
---

#### 查看当前系统版本信息

`cat /etc/os-release`

#### 查看IP信息

`ip addr show`或`ifconfig`

公网IP查看 `curl ifconfig.me`

#### 测试端口连通性

`apt-get update`
`apt-get install -y netcat`
`nc -vz 127.0.0.1 <Shadowsocks端口号>`

#### 查看防火墙规则：

在服务器上运行以下命令，查看当前防火墙规则：`iptables -L`
这将显示当前防火墙配置。检查是否有任何规则阻止了<Shadowsocks>流量。
您可以搜索端口号或<Shadowsocks>相关的规则。

#### 暂时禁用防火墙：

为了排除防火墙是导致问题的原因，您可以尝试暂时禁用防火墙并进行测试。
在服务器上运行以下命令来禁用防火墙：`service iptables stop`

#### 检查端口是否开放：

确认Shadowsocks所使用的端口是否开放。可以尝试使用以下命令来检查端口是否处于监听状态：
`netstat -tuln | grep <端口号>`
如果没有输出或端口状态显示为"LISTEN"，则表示该端口处于开放状态。

#### 开启出站端口：

`iptables -A OUTPUT -p tcp --dport <port_number> -j ACCEPT`
请将 <port_number> 替换为你想要开启的出站端口号。

#### 开启入站端口：

`iptables -A INPUT -p tcp --dport <port_number> -j ACCEPT`
请将 <port_number> 替换为你想要开启的入站端口号。

通过以上步骤，你可以开启当前容器的 TCP 出入站端口。请注意，这些设置只对当前容器有效，并不会影响宿主机或其他容器的端口配置。

#### GitHub Codespaces如何搭建代理服务？