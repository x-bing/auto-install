Memo：
This project is based linux pxe install.

Step overview:
Setup environment -> Modify hostlist.csv -> Run preinstall.sh -> Install your host by PXE boot

Feture:
1. Install host by pxe and setup hostname\IP and other information auto.
2. Use different install method and different system setup for different host function
3. After install, System will boot from local disk, don't need setup bios manualy.

Setup Install Server

1. Install Oracle Linux 6 update 7 and setup local DVD repo.
# mount /dev/cdrom /mnt
# vi /etc/yum.repos.d/ol67.repo
[ol67]
name=ol 6 u 7
gpgcheck=0
enabled=1
baseurl=file:///mnt
# yum clean all;yum list

2. Install httpd\dhcp\tftp Server
# yum install httpd php dhcp tftp tftp-server

2.1 setup pxe enviroment and install repo
# mkdir -p /var/www/html/repo/OL6.7
# cp -rf /mnt/* /var/www/html/repo/OL6.7/
# mkdir /var/lib/tftpboot/pxelinux.cfg/
# yum install syslinux
# cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/pxelinux.0
# mkdir /var/lib/tftpboot/pxeboot
# cp /var/www/html/repo/OL6.7/images/pxeboot/vmlinuz  /var/lib/tftpboot/pxeboot/vmlinuz-OL6.7
# cp /var/www/html/repo/OL6.7/images/pxeboot/initrd.img  /var/lib/tftpboot/pxeboot/initrd-OL6.7.img
# cp /usr/share/syslinux/vesamenu.c32 /var/lib/tftpboot/

memo: the key “OL6.7” must same as “OS版本”


3. Copy the auto-ks package and untar
# scp autoks.tar.gz root@192.168.56.80:/root/
# tar xzvf autoks.tar.gz
[root@localhost ~]# tree ./autoks
./autoks
├── dhcpd.conf                       # generate by preinstall.sh,bind mac and client ip
├── hostlist.csv                       # need setup, every line is one host tobe install
├── install_end.php                # after complete install, access this program upgrade hostlist.csv
├── ks_auto.php                     # will generate ks.cfg for every host
├── kslog                                # this is a directory, include every host ks file tobe use
├── preinstall.sh                     # generate dhcpd.conf,pxelinux.cfg and other file
├── pxelinux.cfg -> /var/lib/tftpboot/pxelinux.cfg/
├── template                          # ks template, #_REPO_# is the var will be replace
│   ├── ks-app01.cfg
│   ├── ks-comm.cfg
│   ├── ks-db01.cfg
│   └── partitions                   # disk partition template
│       ├── part01
│       └── part02
└── update_pxe_conf.sh       # call by install_end.php after host install complete

3.1 setup httpd and move the program into website
# mv autoks /var/www/html/auto-install
# chkconfig httpd on
# server start httpd
Now you can access http://192.168.56.80/auto-install/ for validate it

4. modify hostlist.csv like below
#主机名,IP地址,子网掩码,网关,MAC地址,物理机/虚拟机,应用类型,分区方案,OS版本,是否
需要重装系统
host01,192.168.56.81,255.255.255.0,192.168.56.1,52:08:00:27:19:C5:3E,vm,comm,part01,OL6.7,y

5. run preinstall.sh, generate dhcpd.conf, pxelinux.conf
# cd /var/www/html/auto-install
# ./preinstall.sh
This step will do the below things:
* create /etc/dhcp/dhcpd.conf and start dhcpd
  in the dhcpd.conf, only the host need tobe install will bind the mac and ip
* create pxe config file in /var/lib/tftpboot/pxelinux.cfg/ every mac bind a config file

6. memo
  Please search every file, find the IP message and other message about Server indentify, modify it to your environment
