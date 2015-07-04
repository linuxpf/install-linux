#!/bin/bash
#modify by 20150508
grep -q "Centos6u5_xysetup.sh" /etc/rc.d/rc.local && sed -i '/Centos6u5_xysetup.sh/d' /etc/rc.d/rc.local
. /etc/profile
####1. Check network
/bin/ping -c 1 mirrors.xxx.com
if [ $? -ne 0 ];then
    echo "check dns config"
    echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
    exit 1
fi

####2. Get wip
#wip=`cat /etc/sysconfig/network-scripts/ifcfg-*|grep -i IPADDR|egrep -v '=127.*|=192.*|=10.*|#'|awk -F"=" '{print $2}'`
ip_prefix=`/sbin/ip route ls |awk '/default via/{print $3}'|cut -d"." -f1,2,3`
wip_ip=`/sbin/ip a |awk '/inet/{ print $2}'|grep -w $ip_prefix|sed 's#/[0-9]*##g'`
wip_netmask=`/sbin/ifconfig |grep -w $wip_ip| awk '{print$4}' | cut -d: -f2`
gateway=`/sbin/ip route ls |awk '/default via/{print $3}'`
nic=`/sbin/ifconfig|grep -wB1 $wip_ip|head -n 1|awk -F"[ |:]" '{print $1}'`
[ -z $wip_ip ] && echo "Null,do nothing,please chech wip" && exit 1

# add dns
if ! fgrep -q  '223.5.5.5' /etc/resolv.conf;then
echo "nameserver 223.5.5.5 
nameserver 223.6.6.6" >> /etc/resolv.conf

fi

####3 Get isp and setup hostname
SS=`curl http://icp.xxx.com/area/isp 2>/dev/null`
if [ "${SS}OK" == "电信OK" ]
then
        SP="t"
elif [ "${SS}OK" == "联通OK" ]
then
        SP="c"
elif [ "${SS}OK" == "移通OK" ]
then
        SP="m"
elif [ "${SS}OK" == "长宽OK" ]
then
        SP="gwbn"
elif [ "${SS}OK" == "小运营OK" ]
then
        SP="x"
else
        SP="c"
fi
[ -n $SP ] && echo $SP || echo "get sp fail"
host_prefix="${SP}_user"
HOSTNAME=`echo "${host_prefix}_${wip_ip}"|sed 's/\./\_/g'`
echo $HOSTNAME $ip

[ `ip a |grep -w $wip_ip |wc -l` -gt 0 ] && sed -i 's/HOSTNAME/#HOSTNAME/g' /etc/sysconfig/network||exit 1
echo "HOSTNAME=${HOSTNAME}" >> /etc/sysconfig/network
sed -i 's/id:5:initdefault/id:3:initdefault/g' /etc/inittab
hostname $HOSTNAME

####4. config host.allow
chattr -i /etc/hosts.allow
##add lan_range to hosts.allow
gw=`/sbin/ip route ls |awk '/default via/{print $3}'`
if [ -n $gw ];then
    network=`ipcalc -4 -n "$gw/24"|cut -d"=" -f2`
    lan_range=`ipcalc -4 -m -n  "$gw/24"|sort|xargs|sed -e 's/NETMASK=//g' -e 's/NETWORK=//g' |awk '{print $2"/"$1}'`
    grep -q ${network} /etc/hosts.allow ||echo "sshd:${lan_range}" >> /etc/hosts.allow

fi
##add hosts.allow to 
#grep -q "125.39.70.130" /etc/hosts.allow ||sed -i '/essh_backup/a sshd:119.147.41.43 123.150.173.130 125.39.70.130\nsshd:123.150.185.243 111.161.24.243 123.150.185.242 111.161.24.242' /etc/hosts.allow
cat << EOF >/etc/hosts.allow
sshd:$ip
#backup
sshd:$bakcup_ip
##mgmt server
sshd:$mgmt_ip
#vpn server
sshd:$vpn_ip
EOF

echo "all:all" >> /etc/hosts.deny
chattr +i /etc/hosts.deny

####5. Add iptables ports
if ! fgrep -q 161 /etc/sysconfig/iptables; then
{
cat <<'EOF'
# Firewall configuration written by system-config-securitylevel
# Manual customization of this file is not recommended.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:RH-Firewall-1-INPUT - [0:0]
-A INPUT -j RH-Firewall-1-INPUT
-A FORWARD -j RH-Firewall-1-INPUT
-A RH-Firewall-1-INPUT -i lo -j ACCEPT
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
-A RH-Firewall-1-INPUT -s x.x.x.x -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -m multiport -p tcp --dports 80,8000 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
} > /etc/sysconfig/iptables

#grep -q 'multiport' /etc/sysconfig/iptables||sed -i '/dport 22/a-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -m multiport -p tcp --dports 80,1935,1936,1940 -j ACCEPT' /etc/sysconfig/iptables


sed -i '245a echo "2621400" > /proc/sys/net/netfilter/nf_conntrack_max' /etc/init.d/iptables
service iptables restart

fi
####6. Config yum mirrors.xxx.com
[ ! -f /usr/bin/wget ] && yum -y install wget
\mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget http://mirrors.xxx.com/.help/xx/CentOS-Base6.repo -O /etc/yum.repos.d/CentOS-Base.repo
rpm -ivh http://mirrors.xxx.com/.help/epel-release-6-8.noarch.rpm
\mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo_backup
wget http://mirrors.xxx.com/.help/xx/epel6.repo -O /etc/yum.repos.d/epel.repo
rpm -ivH http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm 
\mv /etc/yum.repos.d/puppetlabs.repo /etc/yum.repos.d/puppetlabs.repo_backup
wget http://mirrors.xxx.com/.help/xx/puppetlabs.repo -O /etc/yum.repos.d/puppetlabs.repo
wget http://mirrors.xxx.com/images/.config/puppet.conf -O /etc/puppet/puppet.conf
yum clean all;yum makecache

#yum -y groupinstall "Additional Development"  Base "Development tools"
yum -y install sysstat vnstat telnet jwhois vim lshw  yum-plugin-priorities OpenIPMI  ipmitool  iptraf xinetd iperf lsscsi openssh-clients pciutils dmidecode smartmontools wget unzip zip ntp ntpdate puppet mcollective  mcollective-common  mcollective-client mcollective-package-client mcollective-package-common mcollective-puppet-client mcollective-puppet-common mcollective-package-agent mcollective-puppet-agent  xfsprogs xfsdump xfsprogs-devel xfsprogs-qa-devel glibc gcc gcc-c++ glibc-common glibc-devel glibc-headers  libgcc
yum -y update openssl bash glibc

#update kernel
wget http://mirrors.xxx.com/kernel/centos6.5/kernel-2.6.32-431.29.2.el6.x86_64.rpm -O /tmp/kernel-2.6.32-431.29.2.el6.x86_64.rpm
wget http://mirrors.xxx.com/kernel/centos6.5/kernel-devel-2.6.32-431.29.2.el6.x86_64.rpm -O /tmp/kernel-devel-2.6.32-431.29.2.el6.x86_64.rpm
wget http://mirrors.xxx.com/kernel/centos6.5/kernel-firmware-2.6.32-431.29.2.el6.noarch.rpm -O /tmp/kernel-firmware-2.6.32-431.29.2.el6.noarch.rpm
wget http://mirrors.xxx.com/kernel/centos6.5/kernel-headers-2.6.32-431.29.2.el6.x86_64.rpm -O /tmp/kernel-headers-2.6.32-431.29.2.el6.x86_64.rpm
cd /tmp/;rpm -ivh kernel-2.6.32-431.29.2.el6.x86_64.rpm kernel-devel-2.6.32-431.29.2.el6.x86_64.rpm kernel-firmware-2.6.32-431.29.2.el6.noarch.rpm


####7. Config rc.local
if ! fgrep -q  "proc" /etc/rc.d/rc.local;then
{
cat <<'EOF'
echo "1" >/proc/sys/net/ipv4/tcp_syncookies
echo "1" > /proc/sys/net/ipv4/tcp_synack_retries
echo "1" > /proc/sys/net/ipv4/tcp_syn_retries
echo "4096000">  /proc/sys/net/ipv4/route/max_size
echo "8192" > /proc/sys/net/core/somaxconn
echo "2621400" > /proc/sys/net/netfilter/nf_conntrack_max
echo "600" > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
echo "1048576" > /sys/module/nf_conntrack/parameters/hashsize 
echo "1024 65534" > /proc/sys/net/ipv4/ip_local_port_range
/usr/sbin/ntpdate clock.isc.org
/usr/local/snmpd/sbin/snmpd -c /usr/local/snmpd/snmpd.conf  -p /var/run/snmpd
/usr/local/irq.py
EOF
} >> /etc/rc.d/rc.local
fi
echo "*  soft  nofile 65536" >> /etc/security/limits.conf
echo "*  hard nofile 65536" >> /etc/security/limits.conf

wget http://mirrors.xxx.com/images/.config/irq.py -O /usr/local/irq.py
chmod +x /usr/local/irq.py

####8 Config crontab
[ ! -f /var/spool/cron/root ] && touch /var/spool/cron/root
if ! fgrep -q 'ntp.xxx.com' /var/spool/cron/root;then
{
cat <<'EOF'
1 0 * * * /usr/sbin/ntpdate clock.isc.org &
1 3 * * * /usr/sbin/ntpdate ntp.xxx.com &
*/5 * * * * /sbin/iptables -Z
EOF
} > /var/spool/cron/root
fi
#### Other config: fstab,ipv6,selinux xinetd
sed -i '/UUID/ s/defaults/defaults,noatime/g' /etc/fstab
grep "NETWORKING_IPV6" /etc/sysconfig/network ||echo "NETWORKING_IPV6=no" >> /etc/sysconfig/network 
sed -i 's/NETWORKING_IPV6=yes/NETWORKING_IPV6=no/g' /etc/sysconfig/network
#disabled ipv6
useradd -g0 -u0 -o root1
[ ! -f /etc/modprobe.d/ipv6-off.conf  ] &&\
echo -e "alias net-pf-10 off\noptions ipv6 disable=1" > /etc/modprobe.d/ipv6-off.conf
#disabled  SELINUX
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
#config xinetd.conf
\cp /etc/xinetd.conf /etc/xinetd.conf_backup
sed -i '/cps/ s/50 10/500 10/g' /etc/xinetd.conf 
sed -i '/instances/ s/50/500/g' /etc/xinetd.conf 
sed -i '/per_source/ s/10/200/g' /etc/xinetd.conf 

####9 disabled service
{
chkconfig --level 3 abrtd off
chkconfig --level 3 acpid off
chkconfig --level 3 atd off
chkconfig --level 3 auditd off
chkconfig --level 3 autofs off
chkconfig --level 3 avahi-daemon off
chkconfig --level 3 certmonger off
chkconfig --level 3 cgconfig off
chkconfig --level 3 cgred off
chkconfig --level 3 cpuspeed off
chkconfig --level 3 cups off
chkconfig --level 3 haldaemon off
chkconfig --level 3 ip6tables off
chkconfig --level 3 ipsec off
chkconfig --level 3 kdump off
chkconfig --level 3 lvm2-monitor off
chkconfig --level 3 mdmonitor off
chkconfig --level 3 messagebus off
chkconfig --level 3 netconsole off
chkconfig --level 3 netfs off
chkconfig --level 3 nfs off
chkconfig --level 3 nfslock off
chkconfig --level 3 ntpd off
chkconfig --level 3 ntpdate off
chkconfig --level 3 oddjobd off
chkconfig --level 3 portreserve off
chkconfig --level 3 postfix off
chkconfig --level 3 psacct off
chkconfig --level 3 quota_nld off
chkconfig --level 3 rdisc off
chkconfig --level 3 restorecond off
chkconfig --level 3 rhnsd off
chkconfig --level 3 rhsmcertd off
chkconfig --level 3 rpcbind off
chkconfig --level 3 rpcgssd off
chkconfig --level 3 rpcidmapd off
chkconfig --level 3 rpcsvcgssd off
chkconfig --level 3 saslauthd off
chkconfig --level 3 smartd off
chkconfig --level 3 sssd off
chkconfig --level 3 sysstat off
chkconfig --level 3 udev-post off
chkconfig --level 3 bluetooth  off
chkconfig --level 3 qpidd  off
chkconfig --level 3 ypbind off
chkconfig --level 3 irqbalance off
chkconfig --level 3 blk-availability off
chkconfig --level 3 libvirt-guests off
chkconfig --level 3 firstboot off
} > /dev/null 2>&1

####10. Centos5 or Centos6 update config
#Disabled SUID Core Dumps
echo '0' > /proc/sys/fs/suid_dumpable
grep -q suid_dumpable /etc/rc.d/rc.local || echo "echo '0' > /proc/sys/fs/suid_dumpable" >> /etc/rc.d/rc.local
if ! fgrep fs.suid_dumpable /etc/sysctl.conf; then
     sed -i '/kernel.core_uses_pid/afs.suid_dumpable = 0' /etc/sysctl.conf
fi

#disabled source_route /etc/sysctl.conf 
sed -i 's/net.ipv4.conf.default.accept_source_route.*/net.ipv4.conf.default.accept_source_route = 0/g' /etc/sysctl.conf
if ! fgrep net.ipv4.conf.default.accept_redirects /etc/sysctl.conf; then
     sed -i '/net.ipv4.conf.default.accept_source_route/a net.ipv4.conf.default.accept_redirects = 0\nnet.ipv4.conf.default.secure_redirects = 0' /etc/sysctl.conf
fi
#Prevent icmp attack and tcp syncookie enabled
sed -i 's/net.ipv4.tcp_syncookies.*/net.ipv4.tcp_syncookies = 1/g' /etc/sysctl.conf
[ `cat /etc/sysctl.conf |grep '^net.ipv4.icmp_echo_ignore_broadcasts'|wc -l` -lt  1 ] && \
sed -i '/net.ipv4.tcp_syncookies/a # Prevent icmp attack\nnet.ipv4.icmp_echo_ignore_broadcasts = 1' /etc/sysctl.conf
sysctl -p > /dev/null

##
if [ ! -f /etc/modprobe.conf ] ; then
   
   touch /etc/modprobe.d/dis-filemodule.conf
cat << 'EOF' > /etc/modprobe.d/dis-filemodule.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install ppp_generic /bin/true
install pppoe /bin/true
install pppox /bin/true
install slhc /bin/true
install bluetooth /bin/true
install irda /bin/true
install ax25 /bin/true
install x25 /bin/true
install appletalk /bin/true
EOF
else
if ! fgrep 'define disabled' /etc/modprobe.conf; then
  cat << 'EOF' >> /etc/modprobe.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install ppp_generic /bin/true
install pppoe /bin/true
install pppox /bin/true
install slhc /bin/true
install bluetooth /bin/true
install irda /bin/true
install ax25 /bin/true
install x25 /bin/true
install appletalk /bin/true
#define disabled 
EOF
  fi
fi

#check gpgcheck gpgcheck=1
rpm -q --queryformat "%{SUMMARY}\n" gpg-pubkey|egrep -q 'CentOS . Official Signing Key|Red Hat, Inc'  && echo -e "\033[32;1mGPG Check normal\033[0m" \
    || yum -y install gnupg
fgrep -q  'gpgcheck=1' /etc/yum.conf ||sed -i 's/gpgcheck.*/gpgcheck=1/g' /etc/yum.conf
find /etc/yum.repos.d/* | xargs grep "gpgcheck=0" && \
     find /etc/yum.repos.d/* | xargs grep "gpgcheck=0" |cut -d':' -f 1|xargs sed  -i 's/gpgcheck=0/gpgcheck=1/g'
#check file uid
find / -path /proc  -prune -o \( -nouser  -o -nogroup \)  -print > /tmp/nouid_file.txt
[ `cat /tmp/nouid_file.txt |wc -l ` -gt 0 ] && echo -e '\033[31;1mfind no uid or nogroupid file list /tmp/nouid_file.txt\033[0m'

#delete unnecessary user and groups
chattr -i /etc/shadow
chattr -i /etc/passwd
{
userdel adm
userdel sync
userdel shutdown
userdel halt
userdel news
userdel uucp
userdel operator
userdel games 
userdel gopher
groupdel adm
groupdel sync
groupdel shutdown
groupdel halt
groupdel news
groupdel uucp
groupdel operator
groupdel games 
groupdel gopher
} >/dev/null

#check Root uid exclude root1 and root
#awk -F: '($3 == "0" && $1 != "root" && $1 != "root1") {print}' /etc/passwd
User=`awk -F: '($3 == "0" && $1 != "root" && $1 != "root1") {print}' /etc/passwd|cut -d':' -f1`
[ ! -z $User ] && echo -e "\033[31;1mfind dangerous user: $User \033[0m" || echo 'passwd file normal'
#.....
[ `awk -F: '($2 == "") {print}' /etc/shadow|wc -l` -lt 1 ] ||\
  echo -e "\033[31;1mPlease set user:`awk -F: '($2 == "") {print$1}' /etc/shadow` password\033[0m"

chmod go-w /root
for user in `ls -1 /home/`
do
    chmod go-w /home/$user
    chmod go-w /home/$user/.[A-Za-z0-9]*
done

#umask check
if ! fgrep 'umask 077' /etc/profile > /dev/null; then
cp /etc/profile /etc/profile_backup
#centos6
sed -i -e 's/umask 002/#umask 002/g' -e '/umask 002/a umask 077' \
       -e 's/umask 022/#umask 022/g' -e '/umask 022/a umask 077'  /etc/profile
#centos5
grep -q 'umask 077' /etc/profile || echo 'umask 077' >> /etc/profile

fi
declare Profile=(/root/.bashrc /root/.bash_profile /root/.cshrc /root/.tcshrc)
for  file in ${Profile[@]};
do
[ `cat $file |grep '^umask 077'|wc -l` -lt 1 ] &&\
echo 'umask 077' >> $file
done
#ftp NETRC
for NETRC in `ls -1 /home/*/.netrc`; 
do
echo 'ftp passwd file deleting'
#rm -f  $NETRC
[ -n $NETRC ] && rm -f  $NETRC
done
#user 5 login fail locak
#system-auth 
#cp /etc/pam.d/system-auth /etc/pam.d/system-auth_backup
#sed -i 's/pam_cracklib.so.*$/pam_cracklib.so try_first_pass retry=3 minlen=12 minclass=3/g'  /etc/pam.d/system-auth-ac
#sed -i '/password    sufficient    pam_unix.so/ s/use_authtok$/use_authtok remember=5/g'  /etc/pam.d/system-auth-ac
#sed -i '/auth        sufficient    pam_unix.so/ s/sufficient/required/g' /etc/pam.d/system-auth-ac
#sed -i -e  '/pam_succeed_if.so uid >= 500/ s/^auth/#auth/g' \
#      -e '/auth        required      pam_deny.so/ s/^auth/#auth/g' /etc/pam.d/system-auth-ac 
#
#key mgmt
if [ ! -f /root/.ssh/authorized_keys ]; then
    mkdir -p /root/.ssh/ 
    touch  /root/.ssh/authorized_keys
    chmod 644 /root/.ssh/authorized_keys
fi
if ! fgrep -q "xvpn" /root/.ssh/authorized_keys;then
echo "#backup host" >> /root/.ssh/authorized_keys
echo "" >> /root/.ssh/authorized_keys
fi


#password 365 expire
#chage -M 365 -m 7 -W 7 root
#chage -M 365 -m 7 -W 7 root1
#chage -M 365 -m 7 -W 7 monitor
#if [ `cat /etc/pam.d/sshd |grep pam_tally2.so|wc -l` -lt 1 ]; then
#echo 'auth       required     pam_tally2.so deny=5 unlock_time=300
#account    required     pam_tally2.so' >> /etc/pam.d/sshd
#sed -i '/PAM-1.0/aauth       required     pam_tally2.so even_deny_root deny=5 unlock_time=300\naccount    required     pam_tally2.so' /etc/pam.d/sshd
#fi

#pam_tally2 
#echo '*/5 * * * * /sbin/pam_tally2 -r --quiet >/dev/null 2>&1 &' >>  /var/spool/cron/root

yum  -y erase pam_ccreds >/dev/null 2>1


#centos6 check
#config /etc/ssh/sshd_config
sed -i -e 's/#RhostsRSAAuthentication no/RhostsRSAAuthentication no/g' -e 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
[ ` cat /etc/ssh/sshd_config|grep Protocol |grep -v '#'|awk '{print $2}' ` != "2" ] && echo 'Check sshd Protocol' || echo 'sshd Protocol normal'
grep -q '^HashKnownHosts' /etc/ssh/ssh_config|| echo 'HashKnownHosts yes' >> /etc/ssh/ssh_config 
sed -i -e 's/#MaxAuthTries.*$/MaxAuthTries 5/g'  -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' \
       -e 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
#centos5 check

grep -q '^MaxAuthTries'  /etc/ssh/sshd_config|| echo 'MaxAuthTries 5' >> /etc/ssh/sshd_config
grep -q '^PermitEmptyPasswords'  /etc/ssh/sshd_config || echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config

#check timezone change to Asia/Shanghai
if [ `/usr/bin/md5sum /usr/share/zoneinfo/Asia/Shanghai|awk '{print $1}'` != `/usr/bin/md5sum  /etc/localtime|awk '{print $1}'` ];then
    \cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    sed -i 's/ZONE=/#ZONE=/g'  /etc/sysconfig/clock
    echo 'ZONE="Asia/Shanghai"' >> /etc/sysconfig/clock
    hwclock
fi


wget http://mirrors.xxx.com/images/.config/Install_diskutil.sh -O /tmp/Install_diskutil.sh
sh /tmp/Install_diskutil.sh

rm -f $0
reboot
