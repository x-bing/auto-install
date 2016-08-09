<?php

$client_hostname="";
$client_ip="";
$client_netmask="";
$client_gateway="";
$client_app_type="";
$client_part_schema="";
$client_os_ver="";
$repo = "";
$server_ip = "192.168.56.80";
$crash_kernel = "";
$part_schema = "";

$iipp=$_SERVER["REMOTE_ADDR"];

$indexarray=file("hostlist.csv");
$len=count($indexarray);

for($i=0;$i<$len;$i++) {
    $line=explode(",",$indexarray[$i]);

    if (substr($line[0], 0, 1) == "#") {
        continue;
    }

    if($iipp==$line[1]) {
        $client_hostname=$line[0];
        $client_ip=$line[1];
        $client_netmask=$line[2];
        $client_gateway=$line[3];
        $client_app_type=$line[6];
        $client_part_schema=$line[7];
        $client_os_ver=$line[8];
        break;
    }
}

$content=@file_get_contents("template/ks-$client_app_type.cfg");

if(!$content) {
    exit("Error: template/ks-$client_app_type.cfg does not exist.<br/>");
}

if($client_ip!="NONE") {
    $content=preg_replace("[#_CLIENT_IP_#]", "$client_ip", $content);
}

if($client_netmask!="NONE") {
    $content=preg_replace("[#_CLIENT_NETMASK_#]", "$client_netmask", $content);
}

if($client_gw!="NONE") {
    $content=preg_replace("[#_CLIENT_GW_#]", "$client_gateway", $content);
}

if($client_hostname!="NONE") {
    $content=preg_replace("[#_CLIENT_HOSTNAME_#]", "$client_hostname", $content);
}

if ($client_os_ver != "NONE") {
    switch ($client_os_ver) {
        case "RHEL5.9":
            $repo = "rhel59repo";
            $crash_kernel = "crashkernel=128M@16M";
            break;
        case "RHEL6.5":
            $repo = "rhel65repo";
            $crash_kernel = "crashkernel=auto";
            break;
        case "OL6.7":
            $repo = "OL6.7";
            $crash_kernel = "crashkernel=auto";
            break;
        default:
            $repo = "rhel65repo";
            $crash_kernel = "crashkernel=auto";
            break;
    }
    $content = preg_replace("[#_REPO_#]", "$repo", $content);
    $content = preg_replace("[#_SERVER_IP_#]", "$server_ip", $content);
    $content = preg_replace("[#_CRASHKERNEL_#]", "$crash_kernel", $content);
}

if ($client_part_schema != "NONE") {
    $part_schema = @file_get_contents("template/partitions/$client_part_schema");
    if (! $part_schema) {
        exit("Error: cannot read template/partitions/$client_part_schema.<br/>");
    }
    $content = preg_replace("[#_PARTION_SCHEMA_#]", "$part_schema", $content);
}

echo $content;

$logfile="kslog/$client_ip.cfg";
file_put_contents($logfile,$content);

?>

