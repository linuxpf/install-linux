#!/usr/bin/env python
#*- coding:utf-8 -*-
import os,getopt, sys
import time
import subprocess
import re

def reg(r,str):
    p = re.compile(r, re.IGNORECASE)
    x = p.findall(str)
    if( len(x) > 0 ):
        return x[0]
    return ""

def pingdata(Host):
    cmd = "/bin/ping -c 40 -q -i0.01 %s" % Host
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    ret = p.stdout.read()
    r = ", (\d+)%"
    lost = reg(r, ret)
    if lost == '':
        print 'ping fail'
        lost="100%"
    return lost

def main(Host):
    num = 0
    cmd = "/usr/sbin/mtr --n -i 0.01 -c10 --report %s" % Host
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    data = p.stdout.read()
    format="%3s\t%10s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s"
    for line in data.split('\n'):
        if line.startswith("HOST"):
            print "Hop\tIp\t\tUloss\tPloss\tSnt\tLast\tAvg\tBest\tWrst\tStDev"
            continue
        if line=='':
            continue
        try:
            hop,ip,Loss,Snt,Last,Avg,Best,Wrst,StDev =[ x for x in line.split() ]
            #_, ip, lost, _, _, _, _, _, _ = line.split()
        except:
            pass
        if ip == "???" :
            real_loss='100%'
            print format % (hop,ip,Loss,real_loss,Snt,Last,Avg,Best,Wrst,StDev )
            continue
        real_loss=pingdata(ip)+'%'
        print format % (hop,ip,Loss,real_loss,Snt,Last,Avg,Best,Wrst,StDev )

if __name__ == "__main__":
    if len(sys.argv[1:]) !=1:
        print "Usage: %s <mtrp.py> <host>" % sys.argv[0]
        sys.exit(2)
    else:
        main(sys.argv[1])
