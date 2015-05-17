#!/usr/bin/env python

import socket
import fcntl
import struct
import array
import platform
import os
import sys

BYTES = 4096
buf = 4096

def get_cpu_core_num():
    try:
        import multiprocessing
        return multiprocessing.cpu_count()
    except (ImportError, NotImplementedError):
        pass

    res = open('/proc/cpuinfo').read().count('processor\t:')
    if res > 0:
        return res
    
    return 0

def get_iface_list():
    arch = platform.architecture()[0]
   
    var1 = -1
    var2 = -1
    
    if arch == '32bit':
        var1 = 32
        var2 = 32
    elif arch == '64bit':
        var1 = 16
        var2 = 40
    else:
        raise OSError("Unknown architecture: %s\n" % arch)

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    names = array.array('B', '\0' * BYTES)
    bytelen = struct.unpack('iL', fcntl.ioctl(
        s.fileno(),
        0x8912,
        struct.pack('iL', BYTES, names.buffer_info()[0])
        ))[0]
    namestr = names.tostring()
    return [namestr[i:i+var1].split('\0', 1)[0] for i in range(0, bytelen, var2)]

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

def write_proc(path, content):
    print "echo %s > %s" % (content, path)
    f = open(path, 'w+')
    f.write(str(content))
    f.close()

cpu_num = get_cpu_core_num() 
if cpu_num < 4:
    print "small cpu core's, this program not support!"
    sys.exit()
#if cpu_num > 16:
if cpu_num > 64:
    print "too many cpu core's, this program not support!"
    sys.exit()

if cpu_num % 4 != 0:
    print "this program not support!"
    sys.exit()

'''
mask = list()
if cpu_num == 4:
    mask1 = 'f'
    mask = ['01', '02', '04', '08']
elif cpu_num == 8:
    mask1 = 'ff'
    mask = ['01', '02', '04', '08', '10', '20', '40', '80']
elif cpu_num == 12:
    mask1 = 'fff'
    mask = ['01', '02', '04', '08', '10', '20', '40', '80', '100', '200', '400', '800']
elif cpu_num == 16:
    mask1 = 'ffff'
    mask = ['01', '02', '04', '08', '10', '20', '40', '80', '100', '200', '400', '800', '1000', '2000', '4000', '8000']
'''

mask1 = 'f' * (cpu_num / 4)
mask = [ hex(2 ** x).split('0x')[1] for x in range(cpu_num)]

ifs = get_iface_list()
if len(ifs) == 0:
    print "Can not get net interface!"
    sys.exit()

i = 0
flag = 0
for iface in ifs:
    irqflag = 0
    if iface.find(':') == -1 and iface != 'lo' and iface.find('tun') == -1 and iface.find('pop') == -1:
        fp = open('/proc/interrupts', 'r').read()
        for line in open('/proc/interrupts', 'r'):
            if i == cpu_num:
                i = 0
            s ="%s-" % iface
            if line.find(s) == -1:
                if line.find(iface) != -1:
	            irqflag = 1
                continue
            irqflag = 0
            key = line.split()[0].strip()[:-1]
            path = "/proc/irq/%s/smp_affinity" % key
            write_proc(path, mask[i])
            i += 1

        ifsq = "/sys/class/net/%s/queues" % iface
        if not os.path.exists(ifsq):
            continue
        for dir in os.listdir(ifsq):
            if i == cpu_num:
                i = 0
            if dir.startswith('rx-'):
                path = "%s/%s/rps_cpus" % (ifsq, dir)
                if irqflag == 1:
                    write_proc(path, mask1)
                else:
                    write_proc(path, mask[i])
                path = "%s/%s/rps_flow_cnt" % (ifsq, dir)
                write_proc(path, buf)
                flag = 1
            else:
                path = "%s/%s/xps_cpus" % (ifsq, dir)
                if irqflag == 1:
                    write_proc(path, mask1)
                else:
                    write_proc(path, mask[i])
            i += 1
        
if flag == 1:
    path = '/proc/sys/net/core/rps_sock_flow_entries'
    if os.path.exists(path):
        write_proc(path, buf)

#modify iptables hashsize to 1048576
#kernel version > 2.6.20
path = "/sys/module/nf_conntrack/parameters/hashsize"
if os.path.exists(path):
    write_proc(path, '1048576')
#kernel version > 2.6.16 and version <= 2.6.19
path = "/sys/module/ip_conntrack/parameters/hashsize"
if os.path.exists(path):
    write_proc(path, '1048576')
