#!/bin/bash

mac=$(grep $1 hostlist.csv | cut -d, -f5 | tr '[:upper:]' '[:lower:]' | sed 's/:/-/g')

tmpfile=`mktemp`

cat /var/lib/tftpboot/pxelinux.cfg/01-$mac | sed -ne '/menu default/{n;d}' -e p > $tmpfile
cat $tmpfile | sed 's/localboot.*/&\n  menu default/' > /var/lib/tftpboot/pxelinux.cfg/01-$mac

rm -f $tmpfile

exit 0

