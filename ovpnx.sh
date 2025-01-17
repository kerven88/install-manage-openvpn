#!/bin/bash

# set -x

# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo '本脚本不支持使用sh执行'
	exit
fi

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Detect OpenVZ 6
if [[ $(uname -r | cut -d "." -f 1) -eq 2 ]]; then
	echo "内核太旧，本脚本不支持，请升级内核！"
	exit
fi

check_command() {
	set -x
	if command -v ifconfig >/dev/null 2>&1; then
		echo -e "\033[31mifconfig命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y net-tools >/dev/null 2>&1
		elif os="centos"; then
			yum install -y net-tools >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y net-tools >/dev/null 2>&1
		fi
	fi
	if command -v ip >/dev/null 2>&1; then
		echo -e "\033[31mip命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y iproute2 >/dev/null 2>&1
		elif os="centos"; then
			yum install -y iproute2 >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y iproute2 >/dev/null 2>&1
		fi
	fi
	if command -v curl >/dev/null 2>&1; then
		echo -e "\033[31mcurl命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y curl >/dev/null 2>&1
		elif os="centos"; then
			yum install -y curl >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y curl >/dev/null 2>&1
		fi
	fi
	if command -v wget >/dev/null 2>&1; then
		echo -e "\033[31mawk命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y wget >/dev/null 2>&1
		elif os="centos"; then
			yum install -y wget >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y wget >/dev/null 2>&1
		fi
	fi
	if command -v tail >/dev/null 2>&1; then
		echo -e "\033[31mcoreutils命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y coreutils >/dev/null 2>&1
		elif os="centos"; then
			yum install -y coreutils >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y coreutils >/dev/null 2>&1
		fi
	fi
	if command -v sed >/dev/null 2>&1; then
		echo -e "\033[31msed命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y sed >/dev/null 2>&1
		elif os="centos"; then
			yum install -y sed >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y sed >/dev/null 2>&1
		fi
	fi
	if command -v grep >/dev/null 2>&1; then
		echo -e "\033[31mgrep命令不存在，正在下载安装！\033[0m"
		if os="ubuntu"; then
			apt install -y grep >/dev/null 2>&1
		elif os="centos"; then
			yum install -y grep >/dev/null 2>&1
		elif os="fedora"; then
			dnf install -y grep >/dev/null 2>&1
		fi
	fi
}

# Detect OS
# $os_version variables aren't always in use, but are kept here for convenience
if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
elif [[ -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
	group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
	os="fedora"
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
	group_name="nobody"
else
	echo "本脚本只支持Ubuntu, Debian, CentOS, and Fedora."
	exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
	echo "本脚本仅支持Ubuntu 18.04 或更高的版本！"
	exit
fi

if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
	echo "本脚本仅支持Debian 9 或更高的版本！"
	exit
fi

if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
	echo "本脚本仅支持CentOS 7 或更高的版本！"
	exit
fi

# Detect environments where $PATH does not include the sbin directories
if ! grep -q sbin <<<"$PATH"; then
	echo '$PATH does not include sbin. Try using "su -" instead of "su".'
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "本脚本仅支持使用root权限执行"
	exit
fi

if [[ ! -e /dev/net/tun ]] || ! (exec 7<>/dev/net/tun) >/dev/null 2>&1; then
	echo "The system does not have the TUN device available. Tun needs to be enabled before running this installer."
	exit
fi

setup_smtp_server_profile() {
	read -p "SMTP服务器地址: " smtp_server_addr

	read -p "SMTP服务器是否使用SSL/TLS安全连接？[Yy/Nn] " setup_smtp_server_tls_ssl
	until [[ -z "$setup_smtp_server_tls_ssl" || "$setup_smtp_server_tls_ssl" =~ ^[yYnN]*$ ]]; do
		read -p "$setup_smtp_server_tls_ssl为无效的选项,SMTP服务器是否使用SSL/TLS连接？[Yy/Nn] " setup_client_profile_nat_pub_ip_domain
	done
	if [[ $setup_smtp_server_tls_ssl =~ ^[nN] ]]; then
		read -p "SMTP服务器端口: " smtp_server_port
		if [[ $smtp_server_port == 25 ]]; then
			smtp_url="smtp://$smtp_server_addr:$smtp_server_port"
		else
			echo "$smtp_server_port 是非常见SMTP服务商的普通端口，请和SMTP服务商确认。"
			exit
		fi
	elif [[ $setup_smtp_server_tls_ssl =~ ^[yY] ]]; then
		read -p "SMTP服务器安全端口: " smtp_server_security_port
		normal_smtp_security_port=("465 587")
		if [[ $smtp_server_security_port =~ ${normal_smtp_security_port[*]} ]]; then
			smtp_url="smtps://$smtp_server_addr:$smtp_server_security_port"
		else
			echo "$smtp_server_security_port 是非常见SMTP服务商的安全端口，请和SMTP服务商确认。"
			exit
		fi

	fi

	read -p "SMTP服务器用户名: " smtp_server_user
	read -s -p "SMTP服务器用户密码: " smtp_server_passwd
	{
		echo "smtp_server_addr=$smtp_server_addr"
		echo "smtp_server_port=$smtp_server_port"
		echo "smtp_server_user=$smtp_server_user"
		echo "smtp_server_passwd=$smtp_server_passwd"
	} >/etc/openvpn/server/smtp.conf
	echo
	echo "[SMTP已配置。如需重新配置请直接修改/etc/openvpn/server/smtp.conf或删除后重新运行该脚本进行配置]"
}

check_smtp_server_profile() {
	if [[ -f /etc/openvpn/server/smtp.conf ]]; then
		while read line; do
			eval "$line"
		done </etc/openvpn/server/smtp.conf

		if [[ -z $smtp_server_addr || -z $smtp_server_port || -z $smtp_server_user || -z $smtp_server_passwd ]]; then
			echo "SMTP配置不全，请重新配置！"
			rm -rf /etc/openvpn/server/smtp.conf
			setup_smtp_server_profile
			exit
		fi
	else
		echo "SMTP配置文件不存在,无法通过邮件发送新用户的配置！请先正确配置SMTP服务"
		setup_smtp_server_profile
	fi
}

send_email() {
	check_smtp_server_profile
	if [ $? -eq 0 ]; then
		echo "FROM: $smtp_server_user
To: $2 <$1>
Subject: VPN配置信息
Cc:
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="MULTIPART-MIXED-BOUNDARY"

--MULTIPART-MIXED-BOUNDARY
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: quoted-printable

<html>
<head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
    <style type=\"text/css\">
        p {text-indent: 4em;}
        h3 {text-indent: 2em;}
        .table {margin-left: 4em;}
    </style>
</head>
<body>
    <h2>Dear $2 :</h2>
    <h3>1. VPN配置信息</h3>
    <table class=\"table\" border=\"1\">
        <tr>
            <th>用户名</th>
            <th>密码</th>
            <th>配置文件</th>
        </tr>
        <tr>
            <td>
                <font size=\"4\" color=\"red\">$2</font>
            </td>
            <td>
                <font size=\"4\" color=\"red\">$3</font>
            </td>
            <td>
                <font size=\"4\" color=\"red\">见附件</font>
            </td>
        </tr>
    </table>
    <h3>2. 使用说明</h3>
    <p>Windows下使用客户端<b>openvpn gui</b>，下载附件中的配置文件，放置在<b>\"C盘:\用户\您的用户名\OpenVPN\ config\"</b>目录下即可导入配置文件</p>
    <p>MacOS下使用客户端<b>tunnelblick</b>，下载附件中的配置文件，使用tunnelblick打开即可导入配置文件</p>
</body>
</html>

--MULTIPART-MIXED-BOUNDARY
Content-Type: text/plain
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"$2.ovpn\"

[$(cat "$4" | base64)]

--MULTIPART-MIXED-BOUNDARY--
" >/tmp/emai-data.txt

		response=$(
			curl -s --ssl-reqd --write-out %{http_code} --output /dev/null \
				--url "$smtp_url" \
				--user "$smtp_server_user:$smtp_server_passwd" \
				--mail-from "$smtp_server_user" \
				--mail-rcpt $1 \
				--upload-file /tmp/emai-data.txt
		)
		if [ $response -eq 250 ]; then
			echo "新用户配置等信息已通过SMTP服务发送至用户邮箱，请提醒用户及时查收！"
			rm -rf /tmp/emai-data.txt
		else
			echo "新用户配置等信息通过SMTP服务无法发送至用户邮箱，SMTP服务返回状态码：$response 。请根据SMTP服务状态码检查SMTP服务配置！"
		fi
	else
		exit
	fi
}

new_client() {

	check_smtp_server_profile
	if [ $? -eq 0 ]; then
		cd /etc/openvpn/server/easy-rsa/
		EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass
		# Generates the custom client.ovpn
		{
			cat /etc/openvpn/server/client-common.txt
			echo "<ca>"
			cat /etc/openvpn/server/easy-rsa/pki/ca.crt
			echo "</ca>"
			echo "<cert>"
			sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
			echo "</cert>"
			echo "<key>"
			cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
			echo "</key>"
			echo "<tls-crypt>"
			sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
			echo "</tls-crypt>"
		} >/etc/openvpn/client/"$client".ovpn
		client_random_password=$(echo $(date +%s)$RANDOM | md5sum | head -c 10)
		echo "$client $client_random_password" >>/etc/openvpn/server/psw-file

		send_email $1 $client $client_random_password /etc/openvpn/client/$client.ovpn
	fi
}

mask2cdr() {
	local x=${1##*255.}
	set -- 0^^128^192^224^240^248^252^254^ $(((${#1} - ${#x}) * 2)) ${x%%.*}
	x=${1%%$3*}
	echo $(($2 + (${#x} / 4)))
}

if [[ ! -e /etc/openvpn/server/server.conf ]]; then
	check_command
	clear
	echo 'OpenVPN安装管理脚本(根据https://github.com/Nyr/openvpn-install进行的优化), 以下为优化的功能:'
	echo "    1. 汉化"
	echo "    2. 增加选择客户端分配IP地址池网段的功能"
	echo "    3. 增加用户名密码验证脚本"
	echo "    4. 增加配置SMTP发送邮件的功能"
	echo "    5. 增加发送客户端连接、断开状态到钉钉Webhook机器人"
	echo "    6. 增加配置简单密码认证管理端口的功能"
	echo "    7. 增加创建用户后将用户名密码及配置文件等信息通过SMTP邮件服务发送到用户邮箱"
	echo "    8. 增加安装时控制是否允许客户端之间进行网络互联，是否允许客户端访问服务端所在的网络"
	echo "    9. 去除不必要的脚本代码"
	# If system has a single IPv4, it is selected automatically. Else, ask the user
	if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
	else
		number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
		echo
		echo "OpenVPN服务端监听在以下哪个IPv4地址上?"
		ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
		read -p "IPv4地址[1]: " ip_number
		until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
			echo "$ip_number: 无效的选项."
			read -p "IPv4地址[1]: " ip_number
		done
		[[ -z "$ip_number" ]] && ip_number="1"
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
	fi

	server_ip_local_netmask=$(ifconfig eth0 | grep -w 'inet' | awk -F'[ :]+' '{print $5}')

	server_ip_local_net_cdr=$(mask2cdr $server_ip_local_netmask)

	case "$server_ip_local_net_cdr" in
	8)
		server_ip_local_net=$(echo $ip | awk -F'.' '{print $1".0.0.0"}')
		server_ip_local_net_with_cdr=$(echo $server_ip_local_net"/8")
		;;
	16)
		server_ip_local_net=$(echo $ip | awk -F'.' '{print $1"."$2".0.0"}')
		server_ip_local_net_with_cdr=$(echo $server_ip_local_net"/16")
		;;
	24)
		server_ip_local_net=$(echo $ip | awk -F'.' '{print $1"."$2"."$3".0"}')
		server_ip_local_net_with_cdr=$(echo $server_ip_local_net"/24")
		;;
	32)
		server_ip_local_net=$(echo $ip | awk -F'.' '{print $1"."$2"."$3"."$4}')
		server_ip_local_net_with_cdr=$(echo $server_ip_local_net"/32")
		;;
	esac

	# # If $ip is a private IP address, the server must be behind NAT
	# if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
	# 	echo
	# 	echo "This server is behind NAT. What is the public IPv4 address or hostname?"
	# 	# Get public IP and sanitize with grep
	# 	get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
	# 	read -p "Public IPv4 address / hostname [$get_public_ip]: " public_ip
	# 	# If the checkip service is unavailable and user didn't provide input, ask again
	# 	until [[ -n "$get_public_ip" || -n "$public_ip" ]]; do
	# 		echo "Invalid input."
	# 		read -p "Public IPv4 address / hostname: " public_ip
	# 	done
	# 	[[ -z "$public_ip" ]] && public_ip="$get_public_ip"
	# fi
	# If system has a single IPv6, it is selected automatically
	if [[ $(ip -6 addr | grep -c 'inet6 [23]') -eq 1 ]]; then
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')
	fi
	# If system has multiple IPv6, ask the user to select one
	if [[ $(ip -6 addr | grep -c 'inet6 [23]') -gt 1 ]]; then
		number_of_ip6=$(ip -6 addr | grep -c 'inet6 [23]')
		echo
		echo "Which IPv6 address should be used?"
		ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | nl -s ') '
		read -p "IPv6 address [1]: " ip6_number
		until [[ -z "$ip6_number" || "$ip6_number" =~ ^[0-9]+$ && "$ip6_number" -le "$number_of_ip6" ]]; do
			echo "$ip6_number: 无效的选项."
			read -p "IPv6 address [1]: " ip6_number
		done
		[[ -z "$ip6_number" ]] && ip6_number="1"
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | sed -n "$ip6_number"p)
	fi

	echo

	echo "配置OpenVPN使用的通信协议?"
	echo "   1) TCP (推荐)"
	echo "   2) UDP"
	read -p "默认协议[1]: " protocol
	until [[ -z "$protocol" || "$protocol" =~ ^[12]$ ]]; do
		echo "$protocol: 无效的选项."
		read -p "Protocol [1]: " protocol
	done
	case "$protocol" in
	1 | "")
		protocol=tcp
		;;
	2)
		protocol=udp
		;;
	esac

	echo

	echo "配置OpenVPN客户端IP地址池网段"
	echo "   1) 10.8.1.0"
	echo "   2) 10.6.2.0"
	echo "   3) 自定义"
	read -p "默认分配客户端IP地址池网段[1]: " server_ip_net_option
	until [[ -z "$server_ip_net_option" || "$server_ip_net_option" =~ ^[123]$ ]]; do
		echo "$server_ip_net_option 为无效的选项"
		read -p "默认分配客户端IP地址池网段[1]: " server_ip_net_option
	done
	case "$server_ip_net_option" in
	1 | "")
		server_ip_net="10.8.1.0"
		;;
	2)
		server_ip_net="10.6.2.0"
		;;
	3)
		read -p "请输入自定义的客户端IP地址池网段(规则: 四段位,前三段位数值范围1~254,最后一段需为0): " unsanitized_server_ip_net
		server_ip_net=$(sed 's/[^[1-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.0$]/_/g' <<<"$unsanitized_server_ip_net")

		until [[ -z "$server_ip_net" || $server_ip_net =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.0$ && $(echo $server_ip_net | awk -F. '$1<255&&$2<255&&$3<255&&$4<255{print "yes"}') == "yes" ]]; do
			echo "$server_ip_net为无效的IP地址池网段"
			read -p "请输入有效的客户端IP地址池网段: " server_ip_net
		done
		;;
	esac

	echo

	read -p "配置OpenVPN服务端监听的端口? 默认端口[1194]: " port
	until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 && "$port" -gt 1024 ]]; do
		echo "$port 端口无效，请设置1025 <= => 65535范围之内的端口号: "
		read -p "默认端口[1194]: " port
	done
	[[ -z "$port" ]] && port="1194"

	echo

	read -p "是否在客户端配置文件中设置NAT的公网IP地址或域名[Yy/Nn]? " setup_client_profile_nat_pub_ip_domain
	until [[ -z "$setup_client_profile_nat_pub_ip_domain" || "$setup_client_profile_nat_pub_ip_domain" =~ ^[yYnN]*$ ]]; do
		read -p "$setup_client_profile_nat_pub_ip_domain为无效的选项,是否在客户端配置文件中设置NAT的公网IP地址或域名[Yy/Nn]? " setup_client_profile_nat_pub_ip_domain
	done
	[[ -z "$setup_client_profile_nat_pub_ip_domain" ]] && setup_client_profile_nat_pub_ip_domain="y"
	case "$setup_client_profile_nat_pub_ip_domain" in
	y | Y)
		read -p "设置NAT的公网IP地址或域名: " client_profile_nat_pub_ip_domain
		until [[ ! -z "$client_profile_nat_pub_ip_domain" && "$client_profile_nat_pub_ip_domain" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ || "$client_profile_nat_pub_ip_domain" =~ ^[a-zA-Z\.]*$ ]]; do
			read -p "$client_profile_nat_pub_ip_domain为无效的IP地址与域名，请重新设置NAT的公网IP地址或域名: " client_profile_nat_pub_ip_domain
		done
		;;
	n | N) ;;

	esac

	# echo "配置推送给客户端使用的DNS服务器"
	# echo "   1) 114 DNS"
	# echo "   2) 阿里云DNS"
	# echo "   3) 谷歌DNS"
	# echo "   4) 当前系统配置的DNS"
	# read -p "默认DNS服务器[1]: " dns
	# until [[ -z "$dns" || "$dns" =~ ^[1-4]$ ]]; do
	# 	echo "$dns: 无效的选项."
	# 	read -p "默认DNS服务器[1]: " dns
	# done

	echo

	read -n1 -p "是否允许客户端间互联[Yy/Nn]? " setup_client_conn
	until [[ -z "$setup_client_conn" || "$setup_client_conn" =~ ^[yYnN]*$ ]]; do
		read -p "$setup_client_conn为无效的选项,是否允许客户端间互联[Yy/Nn]? " setup_client_conn
	done
	[[ -z "$setup_client_conn" ]] && setup_client_conn="y"

	echo

	read -n1 -p "是否允许客户端访问服务端所在网段[Yy/Nn]? " setup_client_conn_server_net
	until [[ -z "$setup_client_conn_server_net" || "$setup_client_conn_server_net" =~ ^[yYnN]*$ ]]; do
		read -p "$setup_client_conn_server_net为无效的选项,是否允许客户端访问服务端所在网段[Yy/Nn]? " setup_client_conn_server_net
	done
	[[ -z "$setup_client_conn_server_net" ]] && setup_client_conn_server_net="y"

	echo

	read -n1 -p "是否配置管理端口?[Yy/Nn]? " setup_management
	until [[ -z "$setup_management" || "$setup_management" =~ ^[yYnN]*$ ]]; do
		read -p "$setup_management为无效的选项，是否配置管理端口?[Yy/Nn] " setup_management
	done
	[[ -z "$setup_management" ]] && setup_management="y"

	echo

	case "$setup_management" in
	y | Y)
		read -p "设置管理端口[默认27506]: " management_port
		until [[ -z "$management_port" || ${management_port} =~ ^[0-9]{0,5}$ && $management_port -le 65535 && $management_port -gt 1024 ]]; do
			read -p "$management_port为无效的端口，请重新设置1025 <= => 65535之内的端口: " management_port
		done
		[[ -z "$management_port" ]] && management_port=27506

		read -p $'设置管理端口登录密码。[默认生产6位随机0-9a-zA-Z字符串密码]: ' management_psw
		until [[ -z "$management_psw" || ${management_psw} =~ ^[0-9a-zA-Z]{5,6}$ ]]; do
			read -s -p "请重新设置更为复杂的密码: " management_psw
		done
		[[ -z "$management_psw" ]] && management_psw=$(echo $(date +%s)$RANDOM | md5sum | base64 | head -c 6)
		echo "[密码保存在了/etc/openvpn/server/management-psw-file文件中，更多管理端口的使用方法详见:https://openvpn.net/community-resources/management-interface]"
		;;
	n | N) ;;

	esac

	echo

	read -n1 -p "是否配置钉钉通知?[Yy/Nn]? " setup_dingding_notify
	until [[ -z "$setup_dingding_notify" || "$setup_dingding_notify" =~ ^[yYnN]*$ ]]; do
		echo "$setup_dingding_notify 为无效的选项 "
		read -p "是否配置钉钉通知?[Yy/Nn]" setup_dingding_notify
	done
	[[ -z "$setup_dingding_notify" ]] && setup_dingding_notify="y"

	echo

	echo "[请先创建Webhook类型自定义关键词\"OpenVPN\"的钉钉机器人,详情查看:https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq/9e91d73c]"
	case "$setup_dingding_notify" in
	y | Y)
		read -p "设置钉钉机器人通知Webhook的访问Token: " dingding_notify_token
		until [[ ${dingding_notify_token} && ${dingding_notify_token} =~ ^[0-9a-z]{1,64}$ ]]; do
			echo "$dingding_notify_token 为无效的钉钉机器人访问Token. 设置钉钉机器人通知Webhook的访问Token: "
			read -p "请重新设置钉钉机器人Webhook访问的Token:" dingding_notify_token
		done
		echo "[钉钉机器人Webhook访问的Token已配置在了/etc/openvpn/server/openvpn-utils.sh文件中Ding_Webhook_Token变量对应的值，后续如需变动可直接修改]"
		;;
	n | N) ;;

	esac

	echo

	echo "开始准备安装OpenVPN服务端"
	# Install a firewall in the rare case where one is not already available
	if ! systemctl is-active --quiet firewalld.service && ! hash iptables 2>/dev/null; then
		if [[ "$os" == "centos" || "$os" == "fedora" ]]; then
			firewall="firewalld"
			# We don't want to silently enable firewalld, so we give a subtle warning
			# If the user continues, firewalld will be installed and enabled during setup
			echo "安装防火墙软件firewalld"
		elif [[ "$os" == "debian" || "$os" == "ubuntu" ]]; then
			# iptables is way less invasive than firewalld so no warning is given
			firewall="iptables"
			echo "安装防火墙软件iptables"
		fi
	fi
	echo "  正在检查防火墙软件，当前操作系统的防护墙为: $firewall"
	read -n1 -r -p "按任意键继续"
	# If running inside a container, disable LimitNPROC to prevent conflicts
	if systemd-detect-virt -cq; then
		mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/nul
		echo "[Service]
LimitNPROC=infinity" >/etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
	fi
	if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
		echo "  正在下载安装OpenVPN软件"
		apt-get update >/dev/null 2>&1
		apt-get install -y openvpn openssl ca-certificates $firewall >/dev/null 2>&1
	elif [[ "$os" = "centos" ]]; then
		echo "  正在下载安装OpenVPN软件"
		yum install -y epel-release >/dev/null 2>&1
		yum install -y openvpn openssl ca-certificates tar $firewall >/dev/null 2>&1
	else
		# Else, OS must be Fedora
		echo "  正在下载安装OpenVPN软件"
		dnf install -y openvpn openssl ca-certificates tar $firewall >/dev/null 2>&1
	fi
	# If firewalld was just installed, enable it
	if [[ "$firewall" == "firewalld" ]]; then
		echo "  开启防火墙"
		systemctl enable --now firewalld.service >/dev/null 2>&1
	fi
	# Get easy-rsa
	easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.7/EasyRSA-3.0.7.tgz'
	mkdir -p /etc/openvpn/server/easy-rsa/ /etc/openvpn/server/ccd
	echo "  正在下载easy-rsa证书工具"
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -# -sL "$easy_rsa_url"; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1
	chown -R root:root /etc/openvpn/server
	cd /etc/openvpn/server/easy-rsa/
	# Create the PKI, set up the CA and the server and client certificates
	echo "  正在创建CA和客户端证书"
	./easyrsa init-pki >/dev/null 2>&1
	./easyrsa --batch build-ca nopass >/dev/null 2>&1
	EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass >/dev/null 2>&1
	# EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl >/dev/null 2>&1
	# Move the stuff we need
	cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server
	# CRL is read with each client connection, while OpenVPN is dropped to nobody
	chown nobody:"$group_name" /etc/openvpn/server/crl.pem
	# Without +x in the directory, OpenVPN can't run a stat() on the CRL file
	chmod o+x /etc/openvpn/server/
	# Generate key for tls-crypt
	openvpn --genkey --secret /etc/openvpn/server/tc.key >/dev/null 2>&1
	# Create the DH parameters file using the predefined ffdhe2048 group
	echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----' >/etc/openvpn/server/dh.pem
	# Generate server.conf
	echo "  正在生成OpenVPN服务端配置文件"
	echo "local 0.0.0.0
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
mute 30
auth-user-pass-verify openvpn-utils.sh via-env
username-as-common-name
script-security 3
client-config-dir ccd
ifconfig-pool-persist ipp.txt
log-append openvpn-server.log
server $server_ip_net 255.255.255.0" >/etc/openvpn/server/server.conf
	echo "  正在生成OpenVPN服务端脚本"
	echo "#!/bin/sh
PASSFILE=\"/etc/openvpn/server/psw-file\"
LOG_FILE=\"/etc/openvpn/server/openvpn-authorized.log\"
TIME_STAMP=\`date \"+%Y-%m-%d %T\"\`
Ding_Webhook_Token=
Ding_Webhook=\"https://oapi.dingtalk.com/robot/send?access_token=\"\$Ding_Webhook_Token
swap_seconds ()
{
    SEC=\$1
    [ \"\$SEC\" -le 60 ] && echo \"\$SEC秒\"
    [ \"\$SEC\" -gt 60 ] && [ \"\$SEC\" -le 3600 ] && echo \"\$(( SEC / 60 ))分钟\$(( SEC % 60 ))秒\"
    [ \"\$SEC\" -gt 3600 ] && echo \"\$(( SEC / 3600 ))小时\$(( (SEC % 3600) / 60 ))分钟\$(( (SEC % 3600) % 60 ))秒\"
}

if [ \$script_type = 'user-pass-verify' ] ; then
	if [ ! -r \"\${PASSFILE}\" ]; then
		echo \"\${TIME_STAMP}: Could not open password file \"\${PASSFILE}\" for reading.\" >> \${LOG_FILE}
		exit 1
	fi
	CORRECT_PASSWORD=\`awk '!/^;/&&!/^#/&&\$1==\"'\${username}'\"{print \$2;exit}' \${PASSFILE}\`
	if [ \"\${CORRECT_PASSWORD}\" = \"\" ]; then
		echo \"\${TIME_STAMP}: User does not exist: username=\"\${username}\", password=\"\${password}\".\" >> \${LOG_FILE}
		exit 1
	fi
	if [ \"\${password}\" = \"\${CORRECT_PASSWORD}\" ]; then
		echo \"\${TIME_STAMP}: Successful authentication: username=\"\${username}\".\" >> \${LOG_FILE}
		exit 0
	fi
	echo \"\${TIME_STAMP}: Incorrect password: username=\"\${username}\", password=\"\${password}\".\" >> \${LOG_FILE}
	exit 1
fi

case  \"\$IV_PLAT\" in
  os )
    device_type=ios
  ;;
  win )
    device_type=Windows
  ;;
  linux )
    device_type=Linux
  ;;
  solaris )
    device_type=Solaris
  ;;
  openbsd )
    device_type=OpenBSD
  ;;
  mac )
    device_type=Mac
  ;;
  netbsd )
    device_type=NetBSD
  ;;
  freebsd )
    device_type=FreeBSD
  ;;
  * )
    device_type=None
  ;;
esac

if [ \$script_type = 'client-connect' ] ; then
	curl -s \"\$Ding_Webhook\" \\
        -H 'Content-Type: application/json' \\
        -d '
        {
            \"msgtype\": \"markdown\",
            \"markdown\": {
                \"title\": \"'\$common_name'连接到了OpenVPN\",
                \"text\": \"## '\$common_name'连接到了OpenVPN\n> ###    **客户端**:  '\"\$device_type\"'\n> ####    **连接时间**:  '\"\$TIME_STAMP\"'\n> ####    **IP + 端口**:  '\$trusted_ip':'\$trusted_port'\n> ####    **端对端IP**:  '\$ifconfig_pool_remote_ip' <===> '\$ifconfig_local'\"
            },
            \"at\": {
                \"isAtAll\": true
            }
        }'
fi
if [ \$script_type = 'client-disconnect' ]; then
	duration_time=\`swap_seconds \$time_duration\`
    curl -s \"\$Ding_Webhook\" \\
        -H 'Content-Type: application/json' \\
        -d '
        {
            \"msgtype\": \"markdown\",
            \"markdown\": {
                \"title\": \"'\$common_name'断开了OpenVPN\",
                \"text\": \"## '\$common_name'断开了OpenVPN\n> ###    **客户端**:  '\"\$device_type\"'\n> ####    **断开时间**:  '\"\$TIME_STAMP\"'\n> ####    **IP + 端口**:  '\$trusted_ip':'\$trusted_port'\n> ####    **端对端IP**:  '\$ifconfig_pool_remote_ip' <===> '\$ifconfig_local'\n> ####    **持续时间**: '\$duration_time'\"
            },
            \"at\": {
                \"isAtAll\": true
            }
        }'
fi
" >/etc/openvpn/server/openvpn-utils.sh
	chmod +x /etc/openvpn/server/openvpn-utils.sh
	# DNS
	# case "$dns" in
	# 	1|"")
	#         echo 'push "dhcp-option DNS 114.114.114.110"' >> /etc/openvpn/server/server.conf
	# 		echo 'push "dhcp-option DNS 114.114.115.110"' >> /etc/openvpn/server/server.conf
	# 	;;
	# 	2)
	#         echo 'push "dhcp-option DNS 223.6.6.6"' >> /etc/openvpn/server/server.conf
	# 		echo 'push "dhcp-option DNS 223.5.5.5"' >> /etc/openvpn/server/server.conf
	# 	;;
	# 	3)
	# 		echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server/server.conf
	# 		echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server/server.conf
	# 	;;
	# 	4)
	# 		# Locate the proper resolv.conf
	# 		# Needed for systems running systemd-resolved
	# 		if grep -q '^nameserver 127.0.0.53' "/etc/resolv.conf"; then
	# 			resolv_conf="/run/systemd/resolve/resolv.conf"
	# 		else
	# 			resolv_conf="/etc/resolv.conf"
	# 		fi
	# 		# Obtain the resolvers from resolv.conf and use them for OpenVPN
	# 		grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read line; do
	# 			echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server/server.conf
	# 		done
	# 	;;
	# esac
	echo "keepalive 10 120
cipher AES-256-CBC
user root
group $group_name
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify crl.pem" >>/etc/openvpn/server/server.conf
	if [[ "$protocol" = "udp" ]]; then
		echo "explicit-exit-notify" >>/etc/openvpn/server/server.conf
	fi

	if [[ "$setup_client_conn_server_net" =~ ^[yY]$ ]]; then
		echo "push \"route $server_ip_local_net $server_ip_local_netmask\"" >>/etc/openvpn/server/server.conf
	fi

	if [[ "$setup_client_conn" =~ ^[yY]$ ]]; then
		echo "client-to-client" >>/etc/openvpn/server/server.conf
	fi
	if [[ "$setup_management" =~ ^[yY]$ && ${management_port} ]]; then
		echo $management_psw >/etc/openvpn/server/management-psw-file
		echo "management 127.0.0.1 $management_port management-psw-file" >>/etc/openvpn/server/server.conf
	fi
	if [[ "$setup_dingding_notify" =~ ^[yY]$ && ${dingding_notify_token} ]]; then
		sed -i '/Ding_Webhook_Token=/c Ding_Webhook_Token='${dingding_notify_token}'' /etc/openvpn/server/openvpn-utils.sh
		echo "client-connect openvpn-utils.sh" >>/etc/openvpn/server/server.conf
		echo "client-disconnect openvpn-utils.sh" >>/etc/openvpn/server/server.conf
	fi

	# Enable net.ipv4.ip_forward for the system
	echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/30-openvpn-forward.conf
	# Enable without waiting for a reboot or service restart
	echo "  正在开起内核路由转发功能"
	echo 1 >/proc/sys/net/ipv4/ip_forward
	if [[ -n "$ip6" ]]; then
		# Enable net.ipv6.conf.all.forwarding for the system
		echo "net.ipv6.conf.all.forwarding=1" >/etc/sysctl.d/30-openvpn-forward.conf
		# Enable without waiting for a reboot or service restart
		echo 1 >/proc/sys/net/ipv6/conf/all/forwarding
	fi
	if systemctl is-active --quiet firewalld.service; then
		# Using both permanent and not permanent rules to avoid a firewalld
		# reload.
		# We don't use --add-service=openvpn because that would only work with
		# the default port and protocol.
		firewall-cmd --add-port="$port"/"$protocol"
		firewall-cmd --zone=trusted --add-source="$server_ip_net"/24
		firewall-cmd --permanent --add-port="$port"/"$protocol"
		firewall-cmd --permanent --zone=trusted --add-source="$server_ip_net"/24
		# Set NAT for the VPN subnet
		firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_ip_net"/24 ! -d "$server_ip_net"/24 -j SNAT --to "$ip"
		firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_ip_net"/24 ! -d "$server_ip_net"/24 -j SNAT --to "$ip"
		if [[ -n "$ip6" ]]; then
			firewall-cmd --zone=trusted --add-source=fddd:1194:1194:1194::/64
			firewall-cmd --permanent --zone=trusted --add-source=fddd:1194:1194:1194::/64
			firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
			firewall-cmd --permanent --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
		fi
	else
		# Create a service to set up persistent iptables rules
		iptables_path=$(command -v iptables)
		ip6tables_path=$(command -v ip6tables)
		# nf_tables is not available as standard in OVZ kernels. So use iptables-legacy
		# if we are in OVZ, with a nf_tables backend and iptables-legacy is available.
		if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
			iptables_path=$(command -v iptables-legacy)
			ip6tables_path=$(command -v ip6tables-legacy)
		fi
		echo "  正在生成OpenVPN的iptables规则"
		echo "[Unit]
Before=network.target
[Service]
Type=oneshot
ExecStart=$iptables_path -I INPUT -p $protocol --dport $port -j ACCEPT
ExecStart=$iptables_path -I FORWARD -s $server_ip_net/24 -j ACCEPT
ExecStart=$iptables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$iptables_path -D INPUT -p $protocol --dport $port -j ACCEPT
ExecStop=$iptables_path -D FORWARD -s $server_ip_net/24 -j ACCEPT
ExecStop=$iptables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" >/etc/systemd/system/openvpn-iptables.service

		if [[ "$setup_client_conn_server_net" =~ ^[yY]$ ]]; then
			echo "ExecStart=$iptables_path -t nat -A POSTROUTING -s $server_ip_net/24 -d $server_ip_local_net_with_cdr -j SNAT --to $ip" >>/etc/systemd/system/openvpn-iptables.service
			echo "ExecStop=$iptables_path -t nat -D POSTROUTING -s $server_ip_net/24 -d $server_ip_local_net_with_cdr -j SNAT --to $ip" >>/etc/systemd/system/openvpn-iptables.service
		fi
		# 		if [[ -n "$ip6" ]]; then
		# 			echo "ExecStart=$ip6tables_path -t nat -A POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
		# ExecStart=$ip6tables_path -I FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
		# ExecStart=$ip6tables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
		# ExecStop=$ip6tables_path -t nat -D POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
		# ExecStop=$ip6tables_path -D FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
		# ExecStop=$ip6tables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" >> /etc/systemd/system/openvpn-iptables.service
		# 		fi
		echo "RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >>/etc/systemd/system/openvpn-iptables.service
		echo "  正在生效OpenVPN的iptables规则"
		systemctl enable --now openvpn-iptables.service >/dev/null 2>&1
	fi
	# If SELinux is enabled and a custom port was selected, we need this
	if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != 1194 ]]; then
		# Install semanage if not already present
		if ! hash semanage 2>/dev/null; then
			if [[ "$os_version" -eq 7 ]]; then
				# Centos 7
				yum install -y policycoreutils-python >/dev/null 2>&1
			else
				# CentOS 8 or Fedora
				dnf install -y policycoreutils-python-utils >/dev/null 2>&1
			fi
		fi
		semanage port -a -t openvpn_port_t -p "$protocol" "$port"
	fi
	# If the server is behind NAT, use the correct IP address
	[[ -n "$client_profile_nat_pub_ip_domain" ]] && ip="$client_profile_nat_pub_ip_domain"
	# client-common.txt is created so we have a template to add further users later
	echo "  正在生成通用客户端配置文件"
	echo "client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3
auth-user-pass" >/etc/openvpn/server/client-common.txt
	# Enable and start the OpenVPN service
	echo "  正在启动OpenVPN服务并设置开机自启"
	systemctl enable --now openvpn-server@server.service >/dev/null 2>&1
	# Generates the custom client.ovpn
	# new_client $user_email_address
	echo "##################################################"
	echo
	echo "OpenVPN服务安装完成！可重新运行此脚本执行添加用户等其他功能"
	echo
	echo "##################################################"
else
	clear
	echo "OpenVPN服务已安装"
	echo
	echo "选择以下功能:"
	echo "   0) 配置SMTP"
	echo "   1) 添加用户"
	echo "   2) 删除用户"
	echo "   3) 卸载OpenVPN"
	echo "   4) 退出"
	read -p "功能选项: " option
	until [[ "$option" =~ ^[0-4]$ ]]; do
		read -p "$option为无效的选项，请重新输入选项: " option
	done
	case "$option" in
	0)
		check_smtp_server_profile
		;;
	1)
		read -p "新用户名(3~16位,包含以下字符a-zA-Z0-9_-): " client
		until [[ -z ${client+x} || ! -e /etc/openvpn/server/easy-rsa/pki/issued/$client.crt && $client =~ ^[a-zA-Z0-9_\-]{3,16}$ ]]; do
			read -p "$client已存在或不符合规则，请设置新的用户名: " client
		done

		read -p "设置用户邮箱: " user_email_address
		until [[ -z ${user_email_address+x} || ${user_email_address} =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; do
			read -p "${user_email_address}不是一个正确的邮箱格式，请重新设置: " user_email_address
		done

		new_client $user_email_address
		exit
		;;
	2)
		# This option could be documented a bit better and maybe even be simplified
		# ...but what can I say, I want some sleep too
		number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
		if [[ "$number_of_clients" = 0 ]]; then
			echo
			echo "暂时没有已存在的客户端用户"
			exit
		fi
		echo
		echo "请选择要删除的客户端用户:"
		tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
		read -p "用户名: " client_number
		until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
			echo "$client_number: 无效的选项."
			read -p "用户名: " client_number
		done
		client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
		read -p "请确认是否要删除用户$client? [y/N]: " revoke
		until [[ "$revoke" =~ ^[yYnN]*$ ]]; do
			echo "$revoke: 无效的选项."
			read -p "请确认是否要删除客户端用户$client [y/N]: " revoke
		done
		if [[ "$revoke" =~ ^[yY]$ ]]; then
			cd /etc/openvpn/server/easy-rsa/
			./easyrsa --batch revoke "$client" >/dev/null 2>&1
			EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl >/dev/null 2>&1
			rm -f /etc/openvpn/server/crl.pem
			cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
			# CRL is read with each client connection, when OpenVPN is dropped to nobody
			chown nobody:"$group_name" /etc/openvpn/server/crl.pem
			rm -f /etc/openvpn/client/$client.ovpn
			sed -i "/$client/d" /etc/openvpn/server/psw-file
			echo "用户$client已删除!"
		else
			echo "客户端用户$client删除中断!"
		fi
		exit
		;;
	3)
		echo
		read -p "请确认是否卸载OpenVPN? [y/N]: " remove
		until [[ "$remove" =~ ^[yYnN]*$ ]]; do
			echo "$remove: 无效的选项."
			read -p "请确认是否卸载OpenVPN? [y/N]: " remove
		done
		if [[ "$remove" =~ ^[yY]$ ]]; then
			port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
			protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
			if systemctl is-active --quiet firewalld.service; then
				ip=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s $server_ip_net/24 '"'"'!'"'"' -d $server_ip_net/24' | grep -oE '[^ ]+$')
				# Using both permanent and not permanent rules to avoid a firewalld reload.
				firewall-cmd --remove-port="$port"/"$protocol"
				firewall-cmd --zone=trusted --remove-source="$server_ip_net"/24
				firewall-cmd --permanent --remove-port="$port"/"$protocol"
				firewall-cmd --permanent --zone=trusted --remove-source="$server_ip_net"/24
				firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -s "$server_ip_net"/24 ! -d "$server_ip_net"/24 -j SNAT --to "$ip"
				firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s "$server_ip_net"/24 ! -d "$server_ip_net"/24 -j SNAT --to "$ip"
				# if grep -qs "server-ipv6" /etc/openvpn/server/server.conf; then
				# 	ip6=$(firewall-cmd --direct --get-rules ipv6 nat POSTROUTING | grep '\-s fddd:1194:1194:1194::/64 '"'"'!'"'"' -d fddd:1194:1194:1194::/64' | grep -oE '[^ ]+$')
				# 	firewall-cmd --zone=trusted --remove-source=fddd:1194:1194:1194::/64
				# 	firewall-cmd --permanent --zone=trusted --remove-source=fddd:1194:1194:1194::/64
				# 	firewall-cmd --direct --remove-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
				# 	firewall-cmd --permanent --direct --remove-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
				# fi
			else
				systemctl disable --now openvpn-iptables.service >/dev/null 2>&1
				rm -f /etc/systemd/system/openvpn-iptables.service
			fi
			if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != 1194 ]]; then
				semanage port -d -t openvpn_port_t -p "$protocol" "$port"
			fi
			systemctl disable --now openvpn-server@server.service >/dev/null 2>&1
			rm -rf /etc/openvpn /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf /etc/sysctl.d/30-openvpn-forward.conf
			if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
				apt-get remove --purge -y openvpn
			else
				# Else, OS must be CentOS or Fedora
				yum remove -y openvpn
			fi
			echo
			echo "OpenVPN已卸载!"
		else
			echo
			echo "OpenVPN卸载中断!"
		fi
		exit
		;;
	4)
		exit
		;;
	esac
fi
