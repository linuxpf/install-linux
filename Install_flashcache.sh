#!/bin/bash
CACHEDEV_NAME="cachedev"
#readme https://raw.githubusercontent.com/facebook/flashcache/master/doc/flashcache-sa-guide.txt
# Source function library.
. /etc/rc.d/init.d/functions
# Just a check
[ -b /dev/sdb -a -b /dev/sdc ] ||  exit 10

#check disk used 
use=`df -h |grep data|grep -v grep|wc -l`
bl=`blkid|egrep -i "sdc1"|wc -l`
if [ $use -gt 0 -o $bl -gt 0 ]; then
    echo "$0 do nothing"
    exit 1
fi
yum -y install xfsprogs xfsdump xfsprogs-devel xfsprogs-qa-devel >/dev/null
#parted /dev/sdc
parted -s /dev/sdc mklabel gpt
parted -s /dev/sdc mkpart primary 0% 100%

#install flashcache
wget http://mirrors.xxx.com/images/.config/flashcache_stable_v3.1.3.zip -O /tmp/flashcache_stable_v3.1.3.zip
cd /tmp/;unzip -oq flashcache_stable_v3.1.3.zip || exit 1
cd flashcache-stable_v3.1.3
make && make install
modprobe flashcache
#Copy 'utils/flashcache' from the repo to '/etc/init.d/flashcache'
wget http://mirrors.xxx.com/images/.config/flashcache -O /etc/init.d/flashcache -o /dev/null
[ ! -s /etc/init.d/flashcache  ] && echo 'wget /etc/init.d/flashcache  fail'||echo 'wget /etc/init.d/flashcache  success'
chmod +x /etc/init.d/flashcache
chkconfig --add /etc/init.d/flashcache
chkconfig flashcache on
fgrep -q mount /etc/rc.d/rc.local && sed -i '/mount/d' /etc/rc.d/rc.local
[ ! -f /sbin/flashcache_create ] && exit 11
#/sbin/flashcache_create -p around cachedev /dev/sdb /dev/md0p1
/sbin/flashcache_create -p back cachedev /dev/sdb /dev/sdc1
RETVAL=$?
if [ $RETVAL -ne 0 ]; then
    echo " flashcache_create: -p back cachedev /dev/sdb /dev/sdc1 fail"
    exit $RETVAL
fi

mkfs.xfs -f -i size=512 /dev/mapper/cachedev
RETVAL=$?
if [ $RETVAL -ne 0 ]; then
    echo " /dev/mapper/cachedev mkfs.xfs fail"
    exit $RETVAL
fi
xfs_admin -L /data /dev/mapper/cachedev
mkdir -p /data
if [ `blkid|grep xfs|wc -l` -gt 0 ];then
   echo 'format success'
   mount -t xfs -o noatime,nodiratime,inode64 /dev/mapper/cachedev /data
   if [ $RETVAL -ne 0 ]; then
       echo "Mount Failed: /dev/mapper/$CACHEDEV_NAME"
       exit $RETVAL
   fi
   
fi
df -Th
