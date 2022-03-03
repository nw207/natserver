###20220303-update
DATE=$(date '+%Y%m%d')

add_cron_entry(){
        if [ "x$1" == "x" -o "x$2" == "x" -o "x$3" == "x" ]; then
                echo "$0:Invalid parameters"
                echo "Usage: $0 time_spec user command "
                return 1
        fi
        croned=`grep "$3" /etc/crontab`
        if [ "$croned" = "" ]; then
                echo "$1 $2 $3" >> /etc/crontab
                service crond restart
                return 0
        else
                return 1
        fi
}


change_hostname(){
        echo "Input your new hostname"
        read hn
        #1.change /etc/sysconfig/network
        cp /etc/sysconfig/network /etc/sysconfig/network.org
        sed -i "s@^HOSTNAME.*@HOSTNAME=$hn@" /etc/sysconfig/network ;
        #2.change hosts
        cmd="awk '/127.0.0.1/{print \$1\"\t\"\$2\"\t\"\"$hn\";next} {print \$0}' /etc/hosts     >/tmp/hosts"
        eval $cmd
        mv /tmp/hosts /etc/hosts
        #3.hostname
        hostname $hn
}

optimize(){
        cp /etc/sysctl.conf  /etc/sysctl.conf.$DATE
        cp -r sysctl.conf_init /etc/sysctl.conf
}


install_base_devel(){
        yum -y groupinstall "Development Libraries"
        yum -y groupinstall "Development Tools"
        yum -y groupinstall "Base"
}

install_telnet() {
     yum -y install telnet telnet-server xinetd
     useradd -p \$6\$aqoO71h8\$O/97u0lJoPD4b0bV4baykGl20x8JN/2Wl7tVG9lld6v8GtqOm60jKaOv3KeqzFa2MzFD2dPCfPyp6MD2SAiGK0 swkjwy
     cp -r telnet_init /etc/xinetd.d/telnet
     chkconfig --level 2345 xinetd on
     service xinetd restart
}

install_snmp(){
        yum -y install net-snmp fonts-chinese
        cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.$DATE
        cp -r snmpd.conf_init /etc/snmp/snmpd.conf
        cp -r count.sh /etc/snmp/
        cp -a sysconfig_snmpd_init /etc/sysconfig/snmpd   
        cp -a snmpd.options_init /etc/sysconfig/snmpd.options   
        service snmpd restart
        chkconfig --level 2345 snmpd on
        echo "ip route del 169.254.0.0/16 via 0.0.0.0" >> /etc/rc.local
        echo "ip route del 169.254.0.0/16 via 0.0.0.0" >> /etc/rc.local
        echo "ip route del 169.254.0.0/16 via 0.0.0.0" >> /etc/rc.local
         
}

adjust_time(){
        yum -y install ntp dstat bind-utils sysstat tshark
        ntpdate ntp.api.bz
       add_cron_entry "1 * * * *"  "root /usr/sbin/ntpdate" "ntp.api.bz"
#       echo "1 * * * * /usr/sbin/ntpdate ntp.api.bz" >> /etc/crontab
}

change_encoding(){
        cp /etc/sysconfig/i18n /etc/sysconfig/i18n.$DATE
        cp -r i18n_init /etc/sysconfig/i18n
}

drop_caches(){
        cp -r drop_cache.sh  /usr/local/bin/drop_cache.sh
        sh /usr/local/bin/drop_cache.sh
}

set_ip_conntracker(){
        cp -a rc.modules_init  /etc/rc.modules
}

device_info(){
       rpm -ivh  lshw_64.rpm
       ./device_info.sh
}

del_home_users(){
        users=`grep -v "/sbin/nologin" /etc/passwd |grep home |grep -v cache |cut -d: -f1`
        for u in $users ;do
                echo "Delete user $u...."
                userdel -r $u
        done
}

setup_zebra(){
     yum -y install quagga zebra
    echo "password cisco" > /etc/quagga/zebra.conf
    echo "enable password cisco" >> /etc/quagga/zebra.conf
    #service zebra restart
    zebra -d
    chkconfig --level 2345 zebra off
    echo "zebra -d" >> /etc/rc.local
}

setup_icmp_mss(){
      iptables -F
	  iptables -A INPUT -m ttl --ttl-eq 1 -j DROP
      iptables -A INPUT -m ttl --ttl-lt 4 -j DROP
      iptables -A FORWARD -m ttl --ttl-lt 6 -j DROP
      iptables -A FORWARD -p udp --dport 33434:33600 -j DROP
      iptables -t filter -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300
#      iptables -A FORWARD -p icmp -j DROP
      service iptables save
}

del_server_init (){
    rm /root/server_init* -rf
}

del_services(){
        cd /etc/init.d
        services=`for  i in * ;do echo $i ;done`
        for service in $services ; do
        case $service in 
                snmpd)
                ;;
                crond)
                ;;
                dnsmasq)
                ;;
                iptables)
                ;;
                zebra)
                ;;
                network)
                ;;
                sshd)
                ;;
                rsyslog)
                ;;
                *)
                service $service stop
                chkconfig --level 2345 $service off
                ;;
        esac
        done
}

install_tools_and_libraries(){
#       cp -f CentOS-Base.repo /etc/yum.repos.d/
#       cp -f dag.repo /etc/yum.repos.d/
#       yum makecache
#       yum -y groupinstall 'Development Tools' 'Development Libraries' 'Editors'
        yum -y install ntp net-snmp wget dstat
}

shutdown_selinux(){
        sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
        setenforce  0
        getenforce
}



if [ `getconf LONG_BIT` -eq 64 ];then
    echo -e "\033[32mgetconf LONG_BIT=`getconf LONG_BIT` \033[0m"
    echo -e "\033[32mLast updated 20130118 \033[0m"
else
    echo -e "\033[31mgetconf LONG_BIT=`getconf LONG_BIT` \033[5m"
    echo -e "\033[31mNOT64X . CTRL+C EXIT \033[0m"
fi

echo "1. Going to set new hostname...."
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        change_hostname
fi

echo "2. Going to install Base and Development Tools...."
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        install_base_devel
fi


echo "3. Going to install snmpd...."
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        install_snmp
fi


echo "4. Going to shutdown selinux"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        shutdown_selinux
fi


echo "5. Going to Adjust time......"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        adjust_time
fi

echo "6. Going to change encoding"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then  
        change_encoding
fi

echo "7.Going to setup zebra"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        setup_zebra
fi

echo "8. Going to Optimize for better performance......"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then  
        optimize
       set_ip_conntracker
fi

echo "9. Going to setup_icmp_mss......"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
        setup_icmp_mss
fi


echo "10. Going to del home other user......"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
    del_home_users
fi

echo "11. Going to drop mem_caches......  "
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
    drop_caches
fi

echo "12. Going to install telnet......  "
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
    install_telnet
fi

echo "13. clean this server_init......"
echo "Are you sure to do that(Y/n)"
read yesno
if [ "x$yesno" != "xn" ]; then
    device_info
    del_server_init
fi
