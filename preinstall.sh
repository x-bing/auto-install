#!/bin/bash

# This script will parse the ./hostlist.csv file and do the following:
# 1. Check if there is any error in ./hostlist.csv file
# 2. Modify /etc/dhcp/dhcpd.conf for new hosts
# 3. Create configuation file in /var/lib/tftpboot/pxelinux.cfg/ for new hosts

server_ip='192.168.56.80'
autoks_root_dir="/var/www/html/auto-install" 
hostlist_file="$autoks_root_dir/hostlist.csv"
ks_php_file="http://$server_ip/auto-install/ks_auto.php"

# Adjust the following if any field of ks_matrix.csv is changed
hostname_field=0
ip_field=1
netmask_field=2
gateway_field=3
mac_field=4
machine_type_field=5
application_type_filed=6
partition_schema_filed=7
os_version_field=8
reinstall_flag_field=9

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Step1: check ./hostlist.csv

count=0
while read line; do
    ((count++))

    # skip the line started with '#'
    echo $line | egrep "[:space:]*#.*" 1> /dev/null
    if [ $? -eq 0 ]; then
        continue
    fi

    OIFS=$IFS
    IFS=','
    field=($line)
    IFS=$OIFS
 
    hostname=${field[$hostname_field]}
    ip=${field[$ip_field]}
    netmask=${field[$netmask_field]}
    gateway=${field[$gateway_field]}

    # Validate IP
    if ! valid_ip $ip; then
        echo "Error: line $count: the IP \"$ip\" for host \"$hostname\" is not valid."
        exit 1
    fi

    # Validate netmask
    if ! valid_ip $netmask; then
        echo "Error: line $count: the netmask \"$netmask\" for host \"$hostname\" is not valid."
        exit 1
    fi

    # Validate gateway
    if ! valid_ip $gateway; then
        echo "Error: line $count: the gateway \"$gateway\" for host \"$hostname\" is not valid."
        exit 1
    fi

    # Validate the network address

    # First, calculate the network address.
    network=$(ipcalc -n $ip $netmask | cut -d= -f2)

    # Check if there is corresponding section in dhcpd.conf
    grep "subnet $network netmask $netmask" $autoks_root_dir/dhcpd.conf 1> /dev/null
    if [ $? -eq 1 ]; then
        echo "Error: line $count: the network \"$network\" does not exist in $autoks_root_dir/dhcpd.conf."
        exit 1
    fi

    # TODO: add more check for other fields
done < $hostlist_file

# Step2: modify /etc/dhcp/dhcpd.conf
# Step3: create PXE configuration file in /var/lib/tftpboot/pxelinux.cfg/

[ -f /etc/dhcp/dhcpd.conf.new ] && rm -f /etc/dhcp/dhcpd.conf.new
cp $autoks_root_dir/dhcpd.conf /etc/dhcp/dhcpd.conf.new
tmp_hosts_file=`mktemp`  # keep the new hosts to be (re)installed

while read line; do
    # Skip the line started with '#'
    echo $line | egrep "[:space:]*#.*" 1> /dev/null
    if [ $? -eq 0 ]; then
        continue
    fi

    OIFS=$IFS
    IFS=','
    field=($line)
    IFS=$OIFS

    hostname=${field[$hostname_field]}
    ip=${field[$ip_field]}
    mac=${field[$mac_field]}

    flag_reinstall=${field[$reinstall_flag_field]}
    if [ "$flag_reinstall" == "y" ] || [ "$flag_reinstall" == "Y" ]; then
        echo $hostname >> $tmp_hosts_file

        # Check if the host already exists in /etc/dhcp/dhcpd.conf, if so, remove it first.
        # The reason we do this is to handle such a scenario that the user reinstalls the host
        # with different IP.
        grep "host $hostname" /etc/dhcp/dhcpd.conf.new 1> /dev/null
        if [ $? -eq 0 ]; then
            sed -i -ne "/host $hostname/{n;n;n;n;d}" -e p /etc/dhcp/dhcpd.conf.new
        fi

        # Append the new host to the end of /etc/dhcp/dhcpd.conf
        tac /etc/dhcp/dhcpd.conf.new | sed "0,/}/s/}/}\n  }\n    fixed-address $ip;\n    hardware ethernet $mac;\n  host $hostname {\n/" | tac > /etc/dhcp/dhcpd.conf.new2
        mv -f /etc/dhcp/dhcpd.conf.new2 /etc/dhcp/dhcpd.conf.new

        # Create PXE configuration file
        os_version=${field[$os_version_field]}
        mac_lowercase=$(echo $mac | tr '[:upper:]' '[:lower:]')
        mac_lowercase2=$(echo $mac_lowercase | sed 's/:/-/g')
        cat << EOF > /var/lib/tftpboot/pxelinux.cfg/01-$mac_lowercase2
default vesamenu.c32
prompt 1
timeout 10

display boot.msg

menu background splash.jpg
menu title Welcome to $os_version
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label install
  menu label ^Install or upgrade an existing $os_version system
  menu default
  kernel pxeboot/vmlinuz-$os_version
  append initrd=pxeboot/initrd-$os_version.img ks=$ks_php_file ksdevice=$mac_lowercase
label local
  menu label Boot from ^local drive
  localboot 0xffff
EOF
    fi
        chown apache:apache /var/lib/tftpboot/pxelinux.cfg/01-$mac_lowercase2
done < $hostlist_file 

test -s $tmp_hosts_file
if [ $? -eq 0 ]; then
    # There are hosts to be (re)installed...
    # Backup original dhcpd.conf first
    cd /etc/dhcp
    [ ! -d ./bak ] && mkdir ./bak
    mv dhcpd.conf ./bak/dhcpd.conf-`date +"%F_%H-%M-%S"`
    mv dhcpd.conf.new dhcpd.conf
    
    # Restart dhcpd service
    service dhcpd restart

    # Start tftpd
    chkconfig tftp on
    service xinetd restart

    # Restart httpd
    service httpd restart

    echo ""

    if [ $? -eq 0 ]; then
        echo "Finished preinstall successfully! Ready to (re)install the following host(s):"
        cat $tmp_hosts_file
        rm -f $tmp_hosts_file
        exit 0
    else
        echo "Failed to finish preinstall! Please check /etc/dhcp/dhcpd.conf."
        rm -f $tmp_hosts_file
        exit 1
    fi
else
    echo "Finished processing. No hosts need to be (re)installed."
    rm -f $tmp_hosts_file
    exit 0
fi

