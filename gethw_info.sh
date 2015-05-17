#!/bin/bash
#
#1. get serial
. /etc/profile
num=0
content=
alarm(){
  echo -e "\033[31;1mCheck $item fail($content) \033[0m"
  num=$((num+1))
}

pass(){
  echo -e  "\033[32;1mCheck $item Ok($content) \033[0m"

}
hwinfo=/tmp/hwinfo.txt
host=`hostname`
echo "####Hostname:$host" > $hwinfo
seri=`/usr/sbin/dmidecode --type 1, 27 | grep "Serial Number" | awk '{print $3}'`
echo "Serial Number:$seri" >> $hwinfo
/usr/sbin/dmidecode -t 1 |grep -E 'Manufacturer|Product' >> $hwinfo
#ostype check
item="ostype"
echo "####ostype check" >> $hwinfo
cat /etc/redhat-release >> $hwinfo
content=`cat /etc/redhat-release`
echo `uname -r` >> $hwinfo

i=6.2
if fgrep -q 'CentOS release 6' /etc/redhat-release ;then
    release=`cat /etc/redhat-release |sed -e "s/Red Hat Enterprise Linux Server release \(.*\) .*/\1/" -e "s/CentOS release \(.*\) .*/\1/"`
    if [ `echo "$release >= $i"|bc -l ` -gt 0  ] ; then
           #echo  "ostype=  Ok" >>$hwinfo
            pass >>$hwinfo
        else
           #echo  "ostype =NO (!!!)" >>$hwinfo
            alarm >>$hwinfo
        fi
fi
# 2. memory size
item="Memory"
echo "####memory size check" >> $hwinfo
mem=`free | awk '/Mem/{print$2}'`
content="$mem(kB)"
if [ $((mem/1024/1024)) -ge 15 ];then
    pass >> $hwinfo
    #echo "mem= Ok($mem)" >> $hwinfo
else
    alarm >> $hwinfo
    #echo "mem= NO($mem)" >> $hwinfo
fi
#3. CPU
echo "####CPU" >> $hwinfo
#item="CPU"
phynum=`cat /proc/cpuinfo |grep "physical id"|sort |uniq|wc -l`
core=`cat /proc/cpuinfo |grep "cpu cores" |head -n 1|awk -F": " '{print $2}'`
lgcore=`cat /proc/cpuinfo |grep processor|wc -l`
cpu_model=`cat /proc/cpuinfo  |grep 'model name'|head -n 1`
num=`expr $phynum \* $core `
echo "Cpu processor nums:$num Phy:$phynum  Cores:$core All:$lgcore  cpu_model:$cpu_model" >> $hwinfo
#check cpu hyper-threading
cat /proc/cpuinfo  |egrep  "siblings|cpu cores"|head -n 2|xargs --max-line=2|awk ' {if ($3 == $NF) print ("cpu hyper-threading disabled or not support!") ; else  print ("CPU Hyper-Threading enabled! ")  }' >>$hwinfo

###########
#time=`date`
#echo "$time start"
#check cpu
#for  (( i=0;  i < $num ; i++   ))
#do
#time echo "scale=5000; a(1)*4" | bc -l > /dev/null &
#done
#4.disk
echo "####disk and  raid" >> $hwinfo
item="Disk"
pcilog="/tmp/pci.log"
/sbin/lspci -m | grep -iE "sas|raid" > $pcilog
/sbin/fdisk -l 2>/dev/null|egrep -i disk|grep -v identifier|sort >>$hwinfo
if [ `df -Th |grep VolGroup|wc -l` -gt 0 ];then
    /sbin/pvdisplay|grep -E "PV Name|VG Name|PV Size" |xargs --max-line=3  >> $hwinfo
fi
if [ ! -s $pcilog -o `/sbin/lspci -m | grep -iE "SCSI storage controller"|wc -l` -gt 0 ];then
    for dev in ` ls -1 /dev/sd[a-z]`; do
            echo "====$dev==="  >>$hwinfo
           /usr/sbin/smartctl --all $dev|grep -E 'Model Family|Device Model:|Serial Number:|User Capacity|health' ;
        done >>$hwinfo
        /usr/bin/lsscsi >>$hwinfo
fi

df -Th>> $hwinfo
if [ `cat $pcilog | grep -E "RAID bus controller|RAID controller" | grep -E "MegaRAID|PERC|PowerEdge Expandable RAID controller|MegaSAS" | wc -l` -gt 0 ]; then
        # MegeRAID
        diskutil="/opt/MegaRAID/MegaCli/MegaCli64"
        if [ ! -f /opt/MegaRAID/MegaCli/MegaCli* ];then
        installer="MegaCli-8.07.07-1.noarch.rpm"
        wget  "http://mirrors.xxx.com/images/.config/diskutil/$installer"   -o /dev/null -O /tmp/$installer
        rpm -ivh /tmp/$installer  >/dev/null
 #       echo "Megacli install succeed !"
    fi
    $diskutil -PDList -aALL -nolog|grep -E  "Slot Number|Inquiry Data|Raw Size" | awk -F: '{print$2}' | awk '{if(NR%3==0){print}else {printf "%s ",$0}}' >> $hwinfo
    $diskutil -LDInfo -LALL -aAll |grep -iE 'Virtual Drive|RAID Level|^Size|Number Of Drives|Span Depth|Policy'|grep -v Adapter >> $hwinfo

fi
#


echo "####nic bond and ip" >> $hwinfo
#bond
item="NIC"
[ -f  /proc/net/bonding/bond0 ] && cat /proc/net/bonding/bond0 |egrep 'Bonding Mode' >> $hwinfo
if [ -f /proc/net/bonding/bond0 ];then
   cat /proc/net/bonding/bond0 |egrep 'Bonding Mode' >> $hwinfo
   bw=0
   nic="bond0"
   for dev in `cat /proc/net/bonding/bond0|grep Interface|awk '{print $NF}'`; do
      speed=`/sbin/ethtool $dev|awk '/Speed/ {print $2}'|sed 's/Mb\/s//g'`
      [ $speed == "Unknown!" ] && speed=0
      bw=$((bw+speed))
   done

else
ip_prefix=`/sbin/ip route ls |awk '/default via/{print $3}'|cut -d"." -f1,2,3`
wip_ip=`/sbin/ip a |awk '/inet/{ print $2}'|grep -w $ip_prefix|sed 's#/[0-9]*##g'`
wip_netmask=`/sbin/ifconfig |grep -w $wip_ip| awk '{print$4}' | cut -d: -f2`
gateway=`/sbin/ip route ls |awk '/default via/{print $3}'`
nic=`/sbin/ifconfig|grep -wB1 $wip_ip|head -n 1|awk -F"[ |:]" '{print $1}'`
bw=`/sbin/ethtool $nic |awk '/Speed/ {print $2}'|sed 's/Mb\/s//g'`
[ -z $bw ] && echo  "get bw fail" >> $hwinfo
fi

content="$nic $bw(Mbps)"
pass >> $hwinfo

ip a |grep bond0 >> $hwinfo
#get all info
echo "####get all info" >> $hwinfo
[ ! -f /usr/bin/inxi ]&& yum -y install inxi 2>/dev/null
/usr/bin/inxi -c0 -F -xx d >> $hwinfo
cat $hwinfo
