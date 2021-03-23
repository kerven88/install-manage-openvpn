# OpenVPN安装管理脚本

## 根据 https://github.com/Nyr/openvpn-install 进行的功能优化

1. 汉化
2. 增加选择客户端分配IP地址池网段的功能
3. 增加用户名密码验证脚本
4. 增加配置SMTP发送邮件的功能
5. 增加发送客户端连接、断开状态到钉钉Webhook机器人
6. 增加配置简单密码认证管理端口的功能
7. 增加创建用户后将用户名密码及配置文件等信息通过SMTP邮件服务发送到用户邮箱
8. 增加安装时控制是否允许客户端之间进行网络互联，是否允许客户端访问服务端所在的网络
9. 去除不必要的脚本代码

# 安装使用方法

```bash
bash ovpnx.sh
```

# 客户端连接方法参考

### Linux

```bash
openvpn --config 客户端配置文件(以.ovpn结尾的文件) --auth-user-pass --daemon
# 断开连接
ps -ef |grep openvpn |grep "daemon" |awk '{print $2}' | xargs kill -9
```

[参考文章](https://gitbook.curiouser.top/origin/openvpn-server.html)
