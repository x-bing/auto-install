<?php

$client_ip = $_SERVER["REMOTE_ADDR"];

system("sed 's/\(.*$client_ip.*\)y/\\1n/' hostlist.csv > hostlist.csv.new");
system("mv -f hostlist.csv.new hostlist.csv");

system("./update_pxe_conf.sh $client_ip");

?>

