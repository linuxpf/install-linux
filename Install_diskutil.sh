#!/bin/bash
#xycdn
[ ! -f /tmp/Install_diskutil.sh ] && echo "Install_diskutil.sh not exist!" && exit 1
###################

pcilog="/tmp/pci.log"
/sbin/lspci -m | grep -iE "sas|raid" > $pcilog
HOSTNAME=`uname -n`

function alarm_downerr()
{
        echo "$HOSTNAME $installer wget error" "null" "$HOSTNAME" >>/root/install
}

function alarm_insterr()
{
        echo "$HOSTNAME $installer install error" "null" "$HOSTNAME" >> /root/install
}
# install lshw
yum -y install lshw  lsscsi inxi
if [ ! -f /usr/sbin/lshw ];then
	installer="lshw-B.02.16.tar.gz"
    wget http://mirrors.xxx.com/images/.config/diskutil/$installer  -o /dev/null  -O /tmp/$installer || alarm_downerr
    tar zxf /tmp/$installer -C /tmp && cd /tmp/${installer%.tar.gz} && make install >/dev/null 2>&1 && echo "lshw install succeed !" || alarm_insterr
	
else
		echo "lshw already exist !"
fi

[ -f /usr/sbin/lshw ] && echo "lshw success!"

# install diskutil
if [ `cat $pcilog | grep -E "RAID bus controller|RAID controller" | grep -E "MegaRAID|PERC|PowerEdge Expandable RAID controller|MegaSAS" | wc -l` -gt 0 ]; then
    # MegeRAID
	# esx
	if [ ! -f /opt/MegaRAID/MegaCli/MegaCli* ];then
		installer="MegaCli-8.07.07-1.noarch.rpm"
		wget  "http://mirrors.xxx.com/images/.config/diskutil/$installer"   -o /dev/null -O /tmp/$installer || alarm_downerr
		rpm -ivh /tmp/$installer || alarm_insterr
		echo "Megacli install succeed !"
	else 
		echo "MegaCli already exist !"
	fi
elif [ `cat $pcilog |grep -iE "sas2[0-90-9]"|wc -l` -gt 0 ];then
        # SAS2008   DELLR510 R710 IBMX3630M3 HWRH2285V2 H200
    utilname="sas2ircu"
	if [ ! -f /usr/local/bin/$utilname ];then
		wget  "http://mirrors.xxx.com/images/.config/diskutil/$utilname"  -o /dev/null -O /usr/local/bin/$utilname || echo "wget utilname fail"
		chmod 755 /usr/local/bin/$utilname
		echo "$utilname install succeed !"
	else
		echo "$utilname already exist !"
	fi

elif [ `cat $pcilog|grep  "AAC-RAID"|wc -l` -gt 0 ];then
        # IBM ServeRAID8k AAC-RAID
        utilname="arcconf"
        if [ ! -f /usr/local/bin/$utilname ];then
            wget  "http://mirrors.xxx.com/images/.config/diskutil/$utilname"  -o /dev/null  -O /usr/local/bin/$utilname ||echo "wget utilname fail"
			chmod 755 /usr/local/bin/$utilname
			echo "$utilname install succeed !"
        else        
				echo "$utilname already exist !"
        fi 
	echo "install compat-libstdc++ ..."
        release=`lsb_release -r | awk '{print substr($2,1,1)}'`
        if [ x"$release" == x"5" ];then
            rpm -ivh http://mirrors.xxx.com/centos/5/os/i386/CentOS/compat-libstdc%2b%2b-33-3.2.3-61.i386.rpm
        elif [ x"$release" == x"6" ];then
            yum -y install compat-libstdc++-33.x86_64 compat-libstdc++-33.i686
            rpm -ivh http://mirrors.xxx.com/centos/6/os/x86_64/Packages/compat-libstdc%2b%2b-33-3.2.3-69.el6.i686.rpm
        fi
elif [ `cat $pcilog |grep  "Hewlett-Packard"|wc -l` -gt 0 ];then
        # Hp Smart Array
        if [ ! -f /usr/sbin/hpacucli ];then
        	[ `arch` == "x86_64" ] && installer='hpacucli-9.40-12.0.x86_64.rpm' || installer='hpacucli-9.40-12.0.i386.rpm'
                wget  "http://mirrors.xxx.com/images/.config/diskutil/$installer"  -o /dev/null  -O /tmp/$installer || alarm_downerr
                rpm -ivh /tmp/$installer || alarm_insterr
                echo "hpacucli install succeed !"
		else
			echo "hpacucli already exist !"
        fi
  
elif [ `cat $pcilog|grep -iE "SAS1068|SAS1068E|SAS 6/iR"|wc -l` -gt 0 ];then
        # SAS1068E Dell R710
	  [ `arch` == "x86_64" ] && utilname='lsiutil.x86_64' || utilname='lsiutil'
        if [ ! -f /usr/local/bin/$utilname ];then
            wget  "http://mirrors.xxx.com/images/.config/diskutil/$utilname"   -o /dev/null -O /usr/local/bin/$utilname ||echo "wget utilname fail"
			chmod 755 /usr/local/bin/$utilname
			echo "$utilname install succeed !"
        else
		    echo "$utilname already exist !"
        fi
  
elif [ `cat $pcilog|egrep "SuperTrak EX16650|SuperTrak EX8650"|wc -l` -gt 0 ];then
        # SuperTrak EX16650  PR3016N
        installer="WebPAMPRO_3_15_0360_05_linux.bin"
        if [ ! -f /opt/Promise/WebPAMPRO/Agent/bin/cliib ];then
                wget http://mirrors.xxx.com/images/.config/diskutil/$installer   -o /dev/null -O /tmp/$installer || alarm_downerr
		chmod 755 /tmp/$installer
                /tmp/$installer -i silent || alarm_insterr
                echo "webpampro install succeed !"
	else
		echo "webpampro already exist !"
        fi

elif [ `cat $pcilog|grep "SuperTrak EX8300"|wc -l` -gt 0 ];then
        # SuperTrak EX8300 PR3015N
	if [ ! -f /usr/sbin/cli ];then
		installer='i2cli-2.5.0-25.i386.rpm'
		wget  "http://mirrors.xxx.com/images/.config/diskutil/$installer"  -o /dev/null -O /tmp/$installer || alarm_downerr
		rpm -ivh /tmp/$installer || alarm_insterr
	else
		echo "cli already exist !"
	fi
else
        echo "unknown raid/scsi type !"  >> /root/install
fi
rm -f $0
