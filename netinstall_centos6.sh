#!/bin/bash
# install Centos6 linux 
# 
#[ $# -ne 1 ] exit 1

read -t 100 -s -p "Are you sure whether to continue or not[yes/no]?" input
if [ ${input} == "yes" ] || [ ${input} == "y" ] ; then
    echo "continue"
else 
    echo -e "\033[31;1mByebye: $input\033[0m"
    exit 1
fi
############################################
ks_server="mirrors.xxx.com/"
sys_version="CentOS-6.5-x86_64"
ks_file="6u5_lan.cfg"

#define 
os_url="http://mirrors.xxx.com/images/CentOS-6.5-x86_64/"
ks_url="http://mirrors.xxx.com/images/ks/6u5.ks"
echo -e "\033[33;1mos_url: $os_url\033[0m"
echo -e "\033[33;1mks_url: $ks_url\033[0m"
grub_conf="/boot/grub/grub.conf"

############################################

#wip_dev=`/sbin/ifconfig | awk '(/eth/ || /em[0-9]/) {print $1}' | head -n 1`
#wip_dev=$1
#wip_ip=`/sbin/ifconfig $wip_dev | grep "inet addr" | awk '{print$2}' | cut -d: -f2`
#wip_netmask=`/sbin/ifconfig $lan_dev | grep "inet addr" | awk '{print$4}' | cut -d: -f2`
vnc_password="xxxxxx"

#get wip
ip_prefix=`/sbin/ip route ls |awk '/default via/{print $3}'|cut -d"." -f1,2,3`
wip_ip=`/sbin/ip a |awk '/inet/{ print $2}'|grep -w $ip_prefix|sed 's#/[0-9]*##g'`
wip_netmask=`/sbin/ifconfig |grep -w $wip_ip| awk '{print$4}' | cut -d: -f2`
gateway=`/sbin/ip route ls |awk '/default via/{print $3}'`


#get ksdevice
#ksdevice=`/usr/sbin/dmidecode -qt system | grep "R.[1-2]0" >/dev/null && echo "em1" || echo "eth0"`
nic=`/sbin/ifconfig|grep -wB1 $wip_ip|head -n 1|awk -F"[ |:]" '{print $1}'`
if [ $nic == "eth0" -o $nic == "em1" ]; then
    ksdevice="eth0"
elif [ $nic == "eth1" -o $nic == "em2" ]; then
     ksdevice="eth1"
else
     ksdevice=$nic
fi
echo "ksdevice:$ksdevice"
    

echo -e "\033[33;1mwip_ip=$wip_ip\033[0m"
echo -e "\033[33;1mwip_netmask=$wip_netmask\033[0m"
echo -e "\033[33;1mgateway=$gateway\033[0m"
echo -e "\033[33;1mksdevice=$ksdevice\033[0m"
echo -e "\033[33;1mvnc_password: $vnc_password\033[0m"

first_par=`df -kP | awk '/sda1|sdb1/{print$NF}' | head -1`
wget $os_url/isolinux/initrd.img -O $first_par/initrd.img && \
wget $os_url/isolinux/vmlinuz -O $first_par/vmlinuz && \
wget $ks_url -O $first_par/ks.cfg && \
echo -e "\033[32;1mBoot file download successfully\033[0m"
if [ $? -ne 0 ];then
    echo -e "\033[31;1mBoot file download fail\033[0m"
    exit 1
fi

cp $grub_conf /boot/grub/grub.conf.bak -f
sed -i "s/default=./default=0/" $grub_conf
# sed -i "/hiddenmenu/ a title install $sys_version via lan\nroot (hd0,0)\nkernel /vmlinuz nousb sshd=1 ks=$ks_url ksdevice=$ksdevice ip=$wip netmask=$wip_netmask vnc vncpassword=$vnc_password\ninitrd /initrd.img\n" $grub_conf && \

sed -i "/hiddenmenu/ a title install $sys_version via netinstall \nroot (hd0,0)\nkernel /vmlinuz sshd=0 ks=hd:sda1/ks.cfg nousb biosdevname=0 ksdevice=$ksdevice ip=$wip_ip netmask=$wip_netmask gateway=$gateway dns=8.8.8.8\ninitrd /initrd.img\n" $grub_conf && \
#sed -i "/hiddenmenu/ a title install $sys_version via netinstall \nroot (hd0,0)\nkernel /vmlinuz sshd=1 ks=hd:sda1/ks.cfg nousb biosdevname=0 ksdevice=$ksdevice ip=$wip_ip netmask=$wip_netmask gateway=$gateway dns=8.8.8.8\ninitrd /initrd.img\n" $grub_conf && \
echo -e "\033[32;1mGrub conf updated successfully!\033[0m"
