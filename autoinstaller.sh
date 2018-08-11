#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===================================================================#
#   System Required:  Debian or Ubuntu                              #
#   Description: Install Shadowsocks-libev server for Debian/Ubuntu #
#   Intro:  https://teddysun.com/358.html                           #
#===================================================================#

# Current folder
cur_dir=`pwd`

# Make sure only root can run our script
rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error: This script must be run as root!" 1>&2
       exit 1
    fi
}

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_ipv6(){
    local ipv6=$(wget -qO- -t1 -T2 ipv6.icanhazip.com)
    if [ -z ${ipv6} ]; then
        return 1
    else
        return 0
    fi
}

get_latest_version(){
    ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${ver} ] && echo "Error: Get shadowsocks-libev latest version failed" && exit 1
    shadowsocks_libev_ver="shadowsocks-libev-$(echo ${ver} | sed -e 's/^[a-zA-Z]//g')"
    download_link="https://github.com/shadowsocks/shadowsocks-libev/archive/${ver}.tar.gz"
    init_script_link="https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev-debian"
}

check_installed(){
    if [ "$(command -v "$1")" ]; then
        return 0
    else
        return 1
    fi
}

check_version(){
    check_installed "ss-server"
    if [ $? -eq 0 ]; then
        installed_ver=$(ss-server -h | grep shadowsocks-libev | cut -d' ' -f2)
        get_latest_version
        latest_ver=$(echo ${ver} | sed -e 's/^[a-zA-Z]//g')
        if [ "${latest_ver}" == "${installed_ver}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

print_info(){
    clear
    echo "#############################################################"
    echo "# Install Shadowsocks-libev server for Debian or Ubuntu     #"
    echo "# Intro:  synricha.net                                      #"
    echo "# Author: Teddysun <i@teddysun.com>                         #"
    echo "# Github: https://github.com/shadowsocks/shadowsocks-libev  #"
    echo "#############################################################"
    echo
}

# Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Pre-installation settings
pre_install(){
    # Check OS system
    if ! check_sys packageManager apt; then
        echo "Error: Your OS is not supported to run it! Please change OS to Debian/Ubuntu and try again."
        exit 1
    fi

    # Check version
    check_version
    status=$?
    if [ ${status} -eq 0 ]; then
        echo "Latest version ${shadowsocks_libev_ver} has been installed, nothing to do..."
        echo
        exit 0
    elif [ ${status} -eq 1 ]; then
        echo "Installed version: ${installed_ver}"
        echo "Latest version: ${latest_ver}"
        echo "Upgrade shadowsocks libev to latest version..."
        ps -ef | grep -v grep | grep -i "ss-server" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
    elif [ ${status} -eq 2 ]; then
        print_info
        get_latest_version
        echo "Latest version: ${shadowsocks_libev_ver}"
        echo
    fi

    #Set shadowsocks-libev config password
    echo "Please input password for shadowsocks-libev:"
    read -p "(Default password: teddysun.com):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="teddysun.com"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo

    #Set shadowsocks-libev config port
    while true
    do
    echo -e "Please input port for shadowsocks-libev [1-65535]:"
    read -p "(Default port: 8989):" shadowsocksport
    [ -z "$shadowsocksport" ] && shadowsocksport="8989"
    expr ${shadowsocksport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        else
            echo "Input error, please input correct number"
        fi
    else
        echo "Input error, please input correct numbers"
    fi
    done
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo
    echo "Press any key to start...or press Ctrl+C to cancel"
    char=`get_char`
    # Update System
    apt-get -y update
    # Install necessary dependencies
    apt-get -y --no-install-recommends install build-essential autoconf libtool openssl libssl-dev zlib1g-dev xmlto asciidoc libpcre3 libpcre3-dev
    echo
    cd ${cur_dir}
}

# Download latest shadowsocks-libev
download_files(){
    if [ -f ${shadowsocks_libev_ver}.tar.gz ]; then
        echo "${shadowsocks_libev_ver}.tar.gz [found]"
    else
        if ! wget --no-check-certificate -O ${shadowsocks_libev_ver}.tar.gz ${download_link}; then
            echo "Failed to download ${shadowsocks_libev_ver}.tar.gz"
            exit 1
        fi
    fi

    # Download init script
    if ! wget --no-check-certificate -O /etc/init.d/shadowsocks ${init_script_link}; then
        echo "Failed to download shadowsocks-libev init script!"
        exit 1
    fi
}

# Config shadowsocks
config_shadowsocks(){
    local server_value="\"0.0.0.0\""
    if get_ipv6; then
        server_value="[\"[::0]\",\"0.0.0.0\"]"
    fi

    if [ ! -d /etc/shadowsocks-libev ]; then
        mkdir -p /etc/shadowsocks-libev
    fi
    cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":${server_value},
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":600,
    "method":"aes-256-cfb""
}
EOF
}

# Install Shadowsocks-libev
install_shadowsocks(){
    tar zxf ${shadowsocks_libev_ver}.tar.gz
    cd ${shadowsocks_libev_ver}
    ./configure
    make && make install
    if [ $? -eq 0 ]; then
        chmod +x /etc/init.d/shadowsocks
        update-rc.d -f shadowsocks defaults
        # Run shadowsocks in the background
        /etc/init.d/shadowsocks start
        if [ $? -eq 0 ]; then
            echo "Shadowsocks-libev start success!"
        else
            echo "Shadowsocks-libev start failure!"
        fi
    else
        echo
        echo "Shadowsocks-libev install failed! Please visit https://teddysun.com/358.html and contact."
        exit 1
    fi

    cd ${cur_dir}
    rm -rf ${shadowsocks_libev_ver} ${shadowsocks_libev_ver}.tar.gz

    clear
    echo
    echo "Congratulations, Shadowsocks-libev install completed!"
    echo -e "Your Server IP: \033[41;37m $(get_ip) \033[0m"
    echo -e "Your Server Port: \033[41;37m ${shadowsocksport} \033[0m"
    echo -e "Your Password: \033[41;37m ${shadowsockspwd} \033[0m"
    echo -e "Your Local IP: \033[41;37m 127.0.0.1 \033[0m"
    echo -e "Your Local Port: \033[41;37m 1080 \033[0m"
    echo -e "Your Encryption Method: \033[41;37m aes-256-cfb \033[0m"
    echo
    echo "Welcome to visit:https://teddysun.com/358.html"
    echo "Enjoy it!"
    echo
}

# Install Shadowsocks-libev
install_shadowsocks_libev(){
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    install_shadowsocks
}

# Uninstall Shadowsocks-libev
uninstall_shadowsocks_libev(){
    clear
    print_info
    printf "Are you sure uninstall Shadowsocks-libev? (y/n)"
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"

    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ps -ef | grep -v grep | grep -i "ss-server" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        update-rc.d -f shadowsocks remove

        rm -fr /etc/shadowsocks-libev
        rm -f /usr/local/bin/ss-local
        rm -f /usr/local/bin/ss-tunnel
        rm -f /usr/local/bin/ss-server
        rm -f /usr/local/bin/ss-manager
        rm -f /usr/local/bin/ss-redir
        rm -f /usr/local/bin/ss-nat
        rm -f /usr/local/lib/libshadowsocks-libev.a
        rm -f /usr/local/lib/libshadowsocks-libev.la
        rm -f /usr/local/include/shadowsocks.h
        rm -f /usr/local/lib/pkgconfig/shadowsocks-libev.pc
        rm -f /usr/local/share/man/man1/ss-local.1
        rm -f /usr/local/share/man/man1/ss-tunnel.1
        rm -f /usr/local/share/man/man1/ss-server.1
        rm -f /usr/local/share/man/man1/ss-manager.1
        rm -f /usr/local/share/man/man1/ss-redir.1
        rm -f /usr/local/share/man/man1/ss-nat.1
        rm -f /usr/local/share/man/man8/shadowsocks-libev.8
        rm -fr /usr/local/share/doc/shadowsocks-libev
        rm -f /etc/init.d/shadowsocks
        echo "Shadowsocks-libev uninstall success!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}
# Install monit
install_monit(){
    clear
	apt-get install monit
	mv ~/autoinstaller/monitrc /etc/monit/monitrc
	chmod 700 /etc/monit/monitrc
	monit
}
# Install openvpn
install_openvpn(){
    clear
	apt-get install openvpn easy-rsa
	make-cadir ~/openvpn-ca && cd ~/openvpn-ca
	mv ~/autoinstaller/vars ~/openvpn-ca/vars
	source vars && ./clean-all && ./build-ca &&./build-key-server server && ./build-dh
	openvpn --genkey --secret keys/ta.key
	source vars
	./build-key client1
	cd ~/openvpn-ca/keys
	cp ca.crt ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn
	mv ~/autoinstaller/server.conf /etc/openvpn/
	mv ~/autoinstaller/server-udp.conf /etc/openvpn/
	# Error PLEASE MANUAL Config
	# enable ufw
	# # echo '# START OPENVPN RULES' >> /etc/ufw/before.rules
	# echo '# NAT table rules' >> /etc/ufw/before.rules
	# echo '*nat' >> /etc/ufw/before.rules
	# echo ':POSTROUTING ACCEPT [0:0] ' >> /etc/ufw/before.rules
	# echo '# Allow traffic from OpenVPN client to eth0' >> /etc/ufw/before.rules
	# echo '-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE' >> /etc/ufw/before.rules
	# echo '-A POSTROUTING -s 10.9.0.0/8 -o eth0 -j MASQUERADE' >> /etc/ufw/before.rules
	# echo 'COMMIT' >> /etc/ufw/before.rules
	# echo '# END OPENVPN RULES' >> /etc/ufw/before.rules
	# iptables-save
	
sudo systemctl start openvpn@server
sudo systemctl start openvpn@server-udp
# automakeconfig
mkdir -p ~/client-configs/files && chmod 700 ~/client-configs/files
cp ~/autoinstaller/base.conf ~/client-configs/
cp ~/autoinstaller/base-udp.conf ~/client-configs/
cp ~/autoinstaller/make_config.sh ~/client-configs/
chmod 700 ~/client-configs/make_config.sh
}

# advanced shadowsocks
install_fasttcp(){
    clear
echo "3" > /proc/sys/net/ipv4/tcp_fastopen
echo "net.ipv4.tcp_fastopen=3" > /etc/sysctl.d/30-tcp_fastopen.conf
echo '* soft nofile 51200' >> /etc/security/limits.conf
echo '* hard nofile 51200' >> /etc/security/limits.conf
echo '* hard nproc 2' >> /etc/security/limits.conf
echo '* hard maxlogins 2' >> /etc/security/limits.conf
#echo 'net.ipv4.ip_forward = 1' >>/etc/sysctl.conf
#echo 'net.ipv4.conf.default.rp_filter = 1' >>/etc/sysctl.conf
#echo 'net.ipv4.conf.default.accept_source_route = 0' >>/etc/sysctl.conf
#echo 'net.ipv4.tcp_syncookies = 1' >>/etc/sysctl.conf
echo 'kernel.msgmnb = 65536' >>/etc/sysctl.conf
echo 'kernel.msgmax = 65536' >>/etc/sysctl.conf
echo 'kernel.shmmax = 4294967295' >>/etc/sysctl.conf
echo 'kernel.shmall = 268435456' >>/etc/sysctl.conf
echo 'fs.file-max = 51200' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_tw_reuse = 1' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_tw_recycle = 0' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout = 15' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_keepalive_time = 1200' >>/etc/sysctl.conf
echo 'net.ipv4.ip_local_port_range = 10000 65000' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 10240' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_max_tw_buckets = 5000' >>/etc/sysctl.conf
echo 'net.core.rmem_max = 67108864' >>/etc/sysctl.conf
echo 'net.core.wmem_max = 67108864' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_mem = 25600 51200 102400' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 67108864' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 67108864' >>/etc/sysctl.conf
echo 'net.core.netdev_max_backlog = 30000' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_mtu_probing=1' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_fastopen=3' >>/etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=hybla' >>/etc/sysctl.conf
echo 'vm.swappiness= 40' >>/etc/sysctl.conf
echo 'vm.vfs_cache_pressure = 50' >>/etc/sysctl.conf
	sysctl -p
	ulimit -n 51200
	cat /etc/sysctl.d/30-tcp_fastopen.conf
	/sbin/modprobe tcp_hybla
	sysctl net.ipv4.tcp_available_congestion_control
	sysctl net.ipv4.tcp_fastopen
	ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
	mv ~/autoinstaller/issue.net /etc/issue.net
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	echo '/swapfile none swap sw 0 0' >>/etc/fstab
	clear

}
# install squid
install_squid(){
    clear
	apt-get install squid
	apt-get install squid3
	mv ~/autoinstaller/squid.conf /etc/squid3/squid.conf
	service squid3 restart
	clear
}
# install ufw
install_ufw(){
    clear
	apt-get update && apt-get install ufw
	ufw allow OpenSSH
	ufw allow 222/tcp
	ufw allow 636/tcp
	ufw allow 1194/tcp
	ufw allow 443/tcp
	ufw allow 10000/tcp
	ufw allow 80/tcp
	ufw allow 8080/tcp
	ufw allow 3128/tcp
	ufw allow 27015/udp
	ufw allow 143/tcp
	ufw allow 8530/tcp
	ufw allow 2812/tcp
	ufw allow 22507/tcp
	ufw allow 67
	ufw allow 68
	ufw allow 5353
	ufw allow 1900
	ufw allow 7300/udp
	ufw disable
	ufw enable
iptables -N SSHATTACK
iptables -A SSHATTACK -j LOG --log-prefix "Possible SSH attack! " --log-level 7
iptables -A INPUT -i eth0 -p tcp -m state --dport 22 --state NEW -m recent --set
iptables -A INPUT -i eth0 -p tcp -m state --dport 80 --state NEW -m recent --set
iptables -A INPUT -i eth0 -p tcp -m state --dport 143 --state NEW -m recent --set
iptables -A INPUT -i eth0 -p tcp -m state --dport 443 --state NEW -m recent --set
iptables -A INPUT -i eth0 -p tcp -m state --dport 22507 --state NEW -m recent --set
iptables -A INPUT -i eth0 -p tcp -m state --dport 22 --state NEW -m recent --update --seconds 120 --hitcount 4 -j SSHATTACK
iptables -A INPUT -i eth0 -p tcp -m state --dport 80 --state NEW -m recent --update --seconds 120 --hitcount 4 -j SSHATTACK
iptables -A INPUT -i eth0 -p tcp -m state --dport 143 --state NEW -m recent --update --seconds 120 --hitcount 4 -j SSHATTACK
iptables -A INPUT -i eth0 -p tcp -m state --dport 443 --state NEW -m recent --update --seconds 120 --hitcount 4 -j SSHATTACK
iptables -A INPUT -i eth0 -p tcp -m state --dport 22507 --state NEW -m recent --update --seconds 120 --hitcount 4 -j SSHATTACK
iptables -t filter -I INPUT -p tcp --syn --dport 22 -m connlimit --connlimit-above 2 --connlimit-mask 32 -j SSHATTACK
iptables -t filter -I INPUT -p tcp --syn --dport 80 -m connlimit --connlimit-above 2 --connlimit-mask 32 -j SSHATTACK
iptables -t filter -I INPUT -p tcp --syn --dport 143 -m connlimit --connlimit-above 2 --connlimit-mask 32 -j SSHATTACK
iptables -t filter -I INPUT -p tcp --syn --dport 443 -m connlimit --connlimit-above 2 --connlimit-mask 32 -j SSHATTACK
iptables -t filter -I INPUT -p tcp --syn --dport 22507 -m connlimit --connlimit-above 2 --connlimit-mask 32 -j SSHATTACK
iptables -A SSHATTACK -j REJECT
iptables -N BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: Bittorrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: BitTorrent protocol' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: peer_id=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: .torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: announce.php?passkey=' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: Torrent' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: announce' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'User-Agent: info_hash' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 80 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 22 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 22 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --sport 443 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'Host: playstation.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'Host: account.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'Host: auth.api.sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'Host: auth.api.np.ac.playstation.net' -j BLOCKACCESS
iptables -I INPUT -p tcp --dport 443 -m string --algo bm --string 'Host: sonyentertainmentnetwork.com' -j BLOCKACCESS
iptables -A BLOCKACCESS -j DROP
iptables -N BLOCKS
iptables -I INPUT -m string --algo bm --string 'BitTorrent' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'BitTorrent' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'BitTorrent' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'BitTorrent protocol' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'BitTorrent protocol' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'BitTorrent protocol' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'peer_id=' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'peer_id=' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'peer_id=' -j BLOCKS
iptables -I INPUT -m string --algo bm --string '.torrent' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string '.torrent' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string '.torrent' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'announce.php?passkey=' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'announce.php?passkey=' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'announce.php?passkey=' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'torrent' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'torrent' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'torrent' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'announce' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'announce' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'announce' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'info_hash' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'info_hash' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'info_hash' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'playstation' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'playstation' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'playstation' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'sonyentertainmentnetwork' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'sonyentertainmentnetwork' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'sonyentertainmentnetwork' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'account.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'account.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'account.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'auth.np.ac.playstation.net' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'auth.np.ac.playstation.net' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'auth.np.ac.playstation.net' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'auth.api.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'auth.api.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'auth.api.sonyentertainmentnetwork.com' -j BLOCKS
iptables -I INPUT -m string --algo bm --string 'auth.api.np.ac.playstation.ne' -j BLOCKS
iptables -I OUTPUT -m string --algo bm --string 'auth.api.np.ac.playstation.ne' -j BLOCKS
iptables -I FORWARD -m string --algo bm --string 'auth.api.np.ac.playstation.ne' -j BLOCKS
iptables -A BLOCKS -j DROP
iptables-save
apt-get install iptables-persistent
invoke-rc.d iptables-persistent save
clear
}

# install dropbear
install_dropbear(){
    clear
	apt-get update
	apt-get install dropbear
	mv ~/autoinstaller/dropbear /etc/default/dropbear
	echo "/bin/false" >> /etc/shells
	echo "/usr/sbin/nologin" >> /etc/shells
	/etc/init.d/dropbear restart
	service dropbear restart
	echo 'MaxAuthTries 2' >>/etc/ssh/sshd_config
	echo 'Banner /etc/issue.net' >>/etc/ssh/sshd_config
	
}
# install sslh
install_sslh(){
    clear
	apt-get update
	apt-get install sslh
	mv ~/autoinstaller/sslh /etc/default/sslh
	/etc/init.d/sslh restart
	clear
}
# install failban
install_failban(){
    clear
    apt-get -y install fail2ban;service fail2ban restart
	cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
	service fail2ban restart
	clear
}
# install badvpn
install_badvpn(){
	clear
	apt-get -y install cmake make gcc libc6-dev
	wget https://raw.githubusercontent.com/malikshi/autoinstaller/master/badvpn-1.999.128.tar.bz2
	tar xf badvpn-1.999.128.tar.bz2
	mkdir badvpn-build
	cd badvpn-build
	cmake ~/autoinstaller/badvpn-1.999.128 -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
	make install
	echo 'badvpn-udpgw --listen-addr 127.0.0.1:7300 > /dev/nul &' >> /etc/rc.local
	echo 'service fail2ban restart' >> /etc/rc.local
	echo 'sudo /etc/init.d/sslh restart' >> /etc/rc.local
	echo 'service dropbear restart' >> /etc/rc.local
	echo 'sudo service squid3 restart' >> /etc/rc.local
	echo 'service iptables-persistent start' >> /etc/rc.local
	echo '/etc/init.d/dropbear restart' >> /etc/rc.local
	badvpn-udpgw --listen-addr 127.0.0.1:7300 > /dev/nul &
	cd /usr/bin
        wget https://raw.githubusercontent.com/malikshi/autoinstaller/master/badvpn-udpgw
        chmod 755 badvpn-udpgw
        cd ~/autoinstaller
        clear
}
# install webmin
install_webmin(){
    clear
	apt-get update
	echo 'deb http://download.webmin.com/download/repository sarge contrib' >>/etc/apt/sources.list
	echo 'deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib' >>/etc/apt/sources.list
	wget http://www.webmin.com/jcameron-key.asc
	apt-key add jcameron-key.asc
	apt-get update && sudo apt-get install webmin

}
# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install)
    install_shadowsocks_libev
    ;;
	# fix
	installmonit)
    install_monit
    ;;
	# fix but manual config tun for forwarding
	installopenvpn)
    install_openvpn
    ;;
	# fix
	installsquid)
    install_squid
    ;;
	# fix
	installsslh)
    install_sslh
    ;;
	installwebmin)
    install_webmin
    ;;
	# fix
	installdropbear)
    install_dropbear
    ;;
	# fix
	installufw)
    install_ufw
    ;;
    installfailban)
    install_failban
    ;;
    installbadvpn)
    install_badvpn
    ;;
	# fix
	fasttcp)
    install_fasttcp
    ;;
    uninstall)
    uninstall_shadowsocks_libev
    ;;
    *)
    echo "Arguments error! [${action}]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac
