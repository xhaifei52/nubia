#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
BLANK="\033[0m"

colorEcho(){
    COLOR=$1
    echo -e "${COLOR}${@:2}${BLANK}"
    echo
}

colorRead(){
    COLOR=$1
    OUTPUT=$2
    VARIABLE=$3
    echo -e -n "$COLOR$OUTPUT${BLANK}: "
    read $VARIABLE
    echo
}

cmd_need(){
    [ -z "$(command -v yum)" ] && CHECK=$(dpkg -l) || CHECK=$(rpm -qa)
    for command in $1;do
        echo "$CHECK" | grep -q "$command" || CMD="$command $CMD"
    done
    if [ ! -z "$CMD" ];then
		colorEcho $BLUE "正在安装 $CMD ..."
		if [ -z "$(command -v yum)" ];then
			apt-get update
			apt-get install $CMD -y
		else
			yum install $CMD -y
		fi > /dev/null 2>&1
		clear
	fi
}

systemd_init() {
    echo -e '#!/bin/bash\nexport PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /bin/systemd_init
    echo -e "$1" >> /bin/systemd_init
    echo -e "systemctl disable systemd_init.service\nrm -f /etc/systemd/system/systemd_init.service /bin/systemd_init" >> /bin/systemd_init
    chmod +x /bin/systemd_init
    echo -e '[Unit]\nDescription=koolproxy Service\nAfter=network.target\n\n[Service]\nType=forking\nExecStart=/bin/systemd_init\n\n[Install]\nWantedBy=multi-user.target' > /etc/systemd/system/systemd_init.service
    systemctl daemon-reload
    systemctl enable systemd_init.service
} > /dev/null 2>&1

install_zip(){
    key="$1"
    wp="/usr/local/$key"
    zip="$key.zip"
    colorEcho $YELLOW "正在安装$key到$wp..." 
    curl -sOL https://raw.githubusercontent.com/FH0/nubia/master/server_script/$zip
    [ -d "$wp" ] && bash $wp/uninstall.sh >/dev/null 2>&1
    rm -rf $wp ; mkdir -p $wp
    unzip -q -o $zip -d $wp ; rm -f $zip
    bash $wp/install.sh
}

install_bbr() {
    lsmod | grep -q "bbr" && return
    if (($(uname -r | grep -Eo '^.')>4)) || (uname -r | grep -q "^4" && (($(uname -r | awk -F "." '{print $2}')>=9)));then
        sed -i '/^net.core.default_qdisc=fq$/d' /etc/sysctl.conf
        sed -i '/^net.ipv4.tcp_congestion_control=bbr$/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1 && colorEcho $GREEN "BBR启动成功！"
        exit 0
    elif [ -z "$(command -v yum)" ];then
        colorEcho $BLUE "正在下载4.16内核..."
        curl -sL -o 4.16.deb http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.16/linux-image-4.16.0-041600-generic_4.16.0-041600.201804012230_amd64.deb
        colorEcho $BLUE "正在安装4.16内核..."
        dpkg -i 4.16.deb >/dev/null 2>&1
        rm -f 4.16.deb
    else
        colorEcho $BLUE "正在添加源支持..."
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org >/dev/null 2>&1
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm >/dev/null 2>&1
        colorEcho $BLUE "正在安装最新内核..."
        yum --enablerepo=elrepo-kernel install kernel-ml -y >/dev/null 2>&1
        grub2-set-default 0
        grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
    fi
    colorEcho $GREEN "新内核安装完成！"
    colorEcho ${YELLOW} "重启系统后即可安装BBR！"
    systemd_init "sed -i '/^net.core.default_qdisc=fq\$/d' /etc/sysctl.conf\nsed -i '/^net.ipv4.tcp_congestion_control=bbr\$/d' /etc/sysctl.conf\necho \"net.core.default_qdisc=fq\" >> /etc/sysctl.conf\necho \"net.ipv4.tcp_congestion_control=bbr\" >> /etc/sysctl.conf\nsysctl -p"
}

install_ssr() {
    [ -z "$ssr_status" ] || bash /usr/local/SSR-Bash-Python/uninstall.sh >/dev/null 2>&1
    curl -sOL https://raw.githubusercontent.com/FH0/nubia/master/ssr.zip
    unzip -o ssr.zip
    bash SSR-Bash-Python/install.sh
    rm -rf SSR-Bash-Python ssr.zip
}

check_system() {
    clear
    if [ -z "$(command -v yum apt-get)" ];then
        colorEcho $RED "不支持的操作系统！"
        exit 1
    elif ! uname -m | grep -q 'x86_64';then
        colorEcho $RED "不支持的系统架构！"
        exit 1
    fi
}

panel() {
    check_system
    cmd_need 'wget iproute unzip net-tools curl'

    [ -d "/usr/local/SSR-Bash-Python" ] && ssr_status="$GREEN"
    [ -d "/usr/local/v2ray" ] && v2ray_status="$GREEN"
    [ -d "/usr/local/ssr_jzdh" ] && ssr_jzdh_status="$GREEN"
    [ -z "$(lsmod | grep bbr)" ] || bbr_status="$GREEN"
    [ -d "/usr/local/AriaNG" ] && AriaNG_status="$GREEN"
    [ -d "/usr/local/frps" ] && frp_status="$GREEN"
    [ -d "/usr/local/swapfile" ] && swapfile_status="$GREEN"
    [ -d "/usr/local/oneindex" ] && oneindex_status="$GREEN"
    [ -d "/usr/local/openvpn" ] && openvpn_status="$GREEN"
    [ -d "/usr/local/wireguard" ] && wireguard_status="$GREEN"

    var=1
    colorEcho $BLUE "欢迎使用JZDH集合脚本"
    printf "%3s. 安装${ssr_status}SSR${BLANK}\n" "$((var++))"
    printf "%3s. 安装${v2ray_status}V2Ray${BLANK}\n" "$((var++))"
    printf "%3s. 安装${ssr_jzdh_status}ssr_jzdh${BLANK}\n" "$((var++))"
    printf "%3s. 安装${bbr_status}BBR${BLANK}\n" "$((var++))"
    printf "%3s. 安装${AriaNG_status}AriaNG${BLANK}\n" "$((var++))"
    printf "%3s. 安装${frp_status}frp${BLANK}\n" "$((var++))"
    printf "%3s. 安装${swapfile_status}swap分区${BLANK}\n" "$((var++))"
    printf "%3s. 安装${oneindex_status}oneindex${BLANK}\n" "$((var++))"
    printf "%3s. 安装${openvpn_status}openvpn${BLANK}\n" "$((var++))"
    printf "%3s. 安装${wireguard_status}wireguard${BLANK}\n" "$((var++))"
    echo && colorRead ${YELLOW} '请选择' panel_choice

    for M in $panel_choice;do
        var=1
        [ "$M" = "$((var++))" ] && install_ssr
        [ "$M" = "$((var++))" ] && install_zip v2ray
        [ "$M" = "$((var++))" ] && install_zip ssr_jzdh
        [ "$M" = "$((var++))" ] && install_bbr
        [ "$M" = "$((var++))" ] && install_zip AriaNG
        [ "$M" = "$((var++))" ] && install_zip frps
        [ "$M" = "$((var++))" ] && install_zip swapfile
        [ "$M" = "$((var++))" ] && install_zip oneindex
        [ "$M" = "$((var++))" ] && install_zip openvpn
        [ "$M" = "$((var++))" ] && install_zip wireguard
    done
}

panel
