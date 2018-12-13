#!/bin/bash

#================================================================= ===
# System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
# Author: wulabing
# Dscription: V2ray ws+tls onekey
# Version: 3.3.1
# Blog: https://www.wulabing.com
# Official document: www.v2ray.com
#================================================================= ===

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[Information]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[Error]${Font}"

V2ray_conf_dir="/etc/v2ray"
V2ray_conf="${v2ray_conf_dir}/config.json"
Client_conf="${v2ray_conf_dir}/client.json"

#Generate camouflage path
Camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

Source /etc/os-release

# Extract the English name of the distribution system from VERSION, in order to add the corresponding Nginx apt source under debian/ubuntu
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

Check_system(){
    
    If [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
        Echo -e "${OK} ${GreenBG} The current system is Centos ${VERSION_ID} ${VERSION} ${Font} "
        INS="yum"
    Elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        Echo -e "${OK} ${GreenBG} The current system is Debian ${VERSION_ID} ${VERSION} ${Font} "
        INS="apt"
    Elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        Echo -e "${OK} ${GreenBG} The current system is Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font} "
        INS="apt"
    Else
        Echo -e "${Error} ${RedBG} The current system is ${ID} ${VERSION_ID} is not in the list of supported systems, installation is interrupted ${Font} "
        Exit 1
    Fi

}
Is_root(){
    If [ `id -u` == 0 ]
        Then echo -e "${OK} ${GreenBG} The current user is the root user and enters the installation process ${Font} "
        Sleep 3
    Else
        Echo -e "${Error} ${RedBG} The current user is not the root user. Please switch to the root user and re-execute the script ${Font}"
        Exit 1
    Fi
}
Judge(){
    If [[ $? -eq 0 ]];then
        Echo -e "${OK} ${GreenBG} $1 complete ${Font}"
        Sleep 1
    Else
        Echo -e "${Error} ${RedBG} $1 failed ${Font}"
        Exit 1
    Fi
}
Ntpdate_install(){
    If [[ "${ID}" == "centos" ]];then
        ${INS} install ntpdate -y
    Else
        ${INS} update
        ${INS} install ntpdate -y
    Fi
    Judge "Install NTPdate Time Synchronization Service"
}
Time_modify(){

    Ntpdate_install

    Systemctl stop ntp &>/dev/null

    Echo -e "${Info} ${GreenBG} Time synchronization in progress ${Font}"
    Ntpdate time.nist.gov

    If [[ $? -eq 0 ]];then
        Echo -e "${OK} ${GreenBG} Time Synchronization Success ${Font}"
        Echo -e "${OK} ${GreenBG} Current system time `date -R` (please note that interval time conversion, the time error after conversion should be within three minutes) ${Font}"
        Sleep 1
    Else
        Echo -e "${Error} ${RedBG} Time synchronization failed, please check if the ntpdate service is working properly ${Font}"
    Fi
}
Dependency_install(){
    ${INS} install wget lsof -y

    If [[ "${ID}" == "centos" ]];then
       ${INS} -y install crontabs
    Else
        ${INS} install cron
    Fi
    Judge "Install crontab"

    # New version of IP judgment does not require the use of net-tools
    # ${INS} install net-tools -y
    # judge "Install net-tools"

    ${INS} install bc -y
    Judge "install bc"

    ${INS} install unzip -y
    Judge "Install unzip"
}
Port_alterid_set(){
    Stty erase '^H' && read -p "Please enter the connection port (default:443):" port
    [[ -z ${port} ]] && port="443"
    Stty erase '^H' && read -p "Please enter alterID(default:64):" alterID
    [[ -z ${alterID} ]] && alterID="64"
}

random_UUID(){
    Let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
}

modify_port_UUID(){
    Sed -i "/\"port\": 443/c \ \"port\": ${port}," ${1}
    Sed -i "/\"id\"/c \\\t \"id\":\"${UUID}\"," ${1}
    Sed -i "/\"alterId\"/c \\\t \"alterId\":${alterID}" ${1}
    Sed -i "/\"path\"/c \\\t \"path\":\"\/${camouflage}\/\"" ${1}
    Sed -i "/\"address\"/c \\\t \"address\":\"${domain}\"," ${1}
}
V2ray_install(){
    If [[ -d /root/v2ray ]];then
        Rm -rf /root/v2ray
    Fi

    Mkdir -p /root/v2ray && cd /root/v2ray
    Wget --no-check-certificate https://install.direct/go.sh

    ## wget http://install.direct/go.sh
    
    If [[ -f go.sh ]];then
        Bash go.sh --force
        Judge "Install V2ray"
    Else
        Echo -e "${Error} ${RedBG} V2ray installation file failed to download, please check if the download address is available ${Font}"
        Exit 4
    Fi
}
Ssl_install(){
    If [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y
    Else
        ${INS} install socat netcat -y
    Fi
    Judge "Install SSL certificate generation script dependency"

    Curl https://get.acme.sh | sh
    Judge "Install SSL certificate generation script"

}
Domain_check(){
    Stty erase '^H' && read -p "Please enter your domain information (eg: www.wulabing.com):" domain
    Domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    Echo -e "${OK} ${GreenBG} Getting public network ip information, please be patient with ${Font}"
    Local_ip=`curl -4 ip.sb`
    Echo -e "domain dns parsing IP: ${domain_ip}"
    Echo -e "native IP: ${local_ip}"
    Sleep 2
    If [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        Echo -e "${OK} ${GreenBG} Domain dns resolves IP to match native IP ${Font}"
        Sleep 2
    Else
        Echo -e "${Error} ${RedBG} Domain dns resolves IP and native IP does not match Continue to install? (y/n)${Font}" && read install
        Case $install in
        [yY][eE][sS]|[yY])
            Echo -e "${GreenBG} Continue to install ${Font}"
            Sleep 2
            ;;
        *)
            EcHo -e "${RedBG} installation terminated ${Font}"
            Exit 2
            ;;
        Esac
    Fi
}

Port_exist_check(){
    If [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
        Echo -e "${OK} ${GreenBG} $1 port is not occupied ${Font}"
        Sleep 1
    Else
        Echo -e "${Error} ${RedBG} detected that $1 port is occupied, the following is $1 port occupancy information ${Font}"
        Lsof -i:"$1"
        Echo -e "${OK} ${GreenBG} 5s will attempt to automatically kill the process ${Font}"
        Sleep 5
        Lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
        Echo -e "${OK} ${GreenBG} kill complete ${Font}"
        Sleep 1
    Fi
}
Acme(){
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --force
    If [[ $? -eq 0 ]];then
        Echo -e "${OK} ${GreenBG} SSL certificate generated successfully ${Font}"
        Sleep 2
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
        If [[ $? -eq 0 ]];then
        Echo -e "${OK} ${GreenBG} Certificate configuration succeeded ${Font}"
        Sleep 2
        Fi
    Else
        Echo -e "${Error} ${RedBG} SSL certificate generation failed ${Font}"
        Exit 1
    Fi
}
Start_process_systemd(){
    Systemctl start v2ray
    Judge "V2ray startup"
}

V2ray_conf_add(){
    Rm -rf ${v2ray_conf}
    Rm -rf ${client_conf}
    Cd /etc/v2ray
    Wget https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/master/http2/config.json
    Judge "config.json download"
    Wget https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/master/http2/client.json
    Judge "client.json download"
    random_UUID
    modify_port_UUID ${v2ray_conf}
    Judge "config.json configuration change"
    modify_port_UUID ${client_conf}
    Judge "client.json configuration change"
    Json_addr=`curl --upload-file ${client_conf} https://transfer.sh/wulabing_${camouflage}_${UUID}.json`
}

Show_information(){
    Clear

    Echo -e "${OK} ${Green} V2ray http2 over tls installed successfully "
    Echo -e "${Red} V2ray configuration information ${Font}"
    Echo -e "${Red} address (address): ${Font} ${domain} "
    Echo -e "${Red} port (port): ${Font} ${port} "
    Echo -e "${Red} user id (UUID): ${Font} ${UUID}"
    Echo -e "${Red} extra id(alterId): ${Font} ${alterID}"
    Echo -e "${Red} encryption (security): ${Font} adaptive"
    Echo -e "${Red} transport protocol (network): ${Font} h2 "
    Echo -e "${Red} masquerading type (type): ${Font} none "
    Echo -e "${Red} masquerading domain name (don't drop /): ${Font} /${camouflage}/ "
    Echo -e "${Red} Underlying transport security: ${Font} tls "
    Echo -e "${OK} ${GreenBG} Please note that the current GUI client (V2rayN) already supports H2 manual addition configuration, of course you can also add node information by adding a custom configuration ${Font}"
    Echo -e "${OK} ${GreenBG} Configure the address (for easy download): ${json_addr} ${Font}"
    Echo -e "${OK} ${GreenBG} Configure the address (server local backup): /etc/v2ray/client.json ${Font}"
}

Main(){
    Is_root
    Check_system
    Time_modify
    Dependency_install
    Domain_check
    Port_alterid_set
    V2ray_install
    Port_exist_check ${port}
    V2ray_conf_add
    
    # Put the certificate generation at the end, try to avoid multiple certificate requests caused by trying the script multiple times.
    Ssl_install
    Acme

    Show_information
    Start_process_systemd
}


