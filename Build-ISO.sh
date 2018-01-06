#!/bin/bash

if [ `id -u` -ne 0 ]
then
    echo "Must be root!
    exit 6
fi

MyDir=`dirname $0` ; cd $MyDir

# Working=`pwd -P $MyDir`

KsCreator="Create-New-Host.sh"
DefaultsFile="ks-variables.cfg"

Prefix=`grep -i ^prefix $KsCreator | cut -f2 -d\"` 
if [ `find $MyDir -type f | grep -i $Prefix | wc -l` -lt 1 ]
then
	echo nothing to work with
	exit 5
else
	printf "\nFound some kickstart configs...\n\n"
	find $MyDir -type f | grep -i $Prefix | sed -e 's/^/\t/g'
	printf "\n... continue ... [Ctrl-C to stop] ?\n\n"
	read

fi

Rhl_Iso=`grep "RHEL_ISO_File"  $DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` \
       	&& echo "Found RHEL iso config : "$Rhl_Iso \
	&& [ `ls $Rhl_Iso 2>/dev/null | wc -l` -gt 0 ] \
	||  exit 1

ACR_Iso=`grep "ACR_ISO_File"   $DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` \
       	&& echo "Found ACR iso config : "$ACR_Iso \
	&& [ -f $ACR_Iso ] \
	||  exit 2

Rhl_Mnt=`grep "RHEL_ISO_Mount" $DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` \
	&& echo "Found RHEL mount config : "$Rhl_Mnt \
	&& [ -d $Rhl_Mnt ] \
	|| mkdir -p $Rhl_Mnt \
	|| exit 3

ACR_Mnt=`grep "ACR_ISO_Mount"  $DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` \
	&& echo "Found ACR  mount config : "$ACR_Mnt \
	&& [ -d $ACR_Mnt ] \
	|| mkdir -p $ACR_Mnt \
	|| exit 4
echo
    mountpoint -q $Rhl_Mnt && umount $Rhl_Mnt
    mount -o ro,loop $Rhl_Iso $Rhl_Mnt \
	    && echo "ACR iso mounted"
    mountpoint -q $ACR_Mnt && umount $ACR_Mnt
    mount -o ro,loop $ACR_Iso $ACR_Mnt \
	    && echo "ACR iso mounted"

printf "\n... continue ... [Ctrl-C to stop] ?\n\n"
read

# Customer
# IP
# NTP_Server
# Netmask
# Default_Route
# Hostname
# DNS_Server
# CRS_Layout
# NumberOfDisks
# Keep_Calls
# NIC
# ACR_SW_TGZ
# Keyboard
# TimeZone
# ACR_Patch_Dir
# ACR_TOOLS

exit

if [ -e $Working/target ]; then
	echo "Clean Target?"
	read AA
	if [ $AA = "y" ] || [ $AA = "Y" ];then
		echo YES ; sleep 3
                mountpoint -q $Working/rhel.iso || exit 1
		rm -vrf $Working/target
                rsync --update -avz $Working/rhel.iso/* $Working/target/. && cd $Working/custom && tar -cf - * | tar -xvf - -C $Working/target/
        fi
fi	
rm -v $Working/target/kde*

[ ! -e $Working/target ] && mkdir $Working/target
[ -e $Working/custom ] || exit 2
if [ -e $Working/custom/ks ]
then
	cat $Working/custom/.start.template >  $Working/custom/isolinux/isolinux.cfg 
    cd $Working/custom/ks && KS_FILES=`ls -1 *.cfg`
    for KS_I in $KS_FILES
    do
       printf "  \nlabel linux_ks_$KS_I\n"  > /tmp/$$.tmp ;printf "    menu label Install using $KS_I\n" >> /tmp/$$.tmp
	    cat $Working/custom/.single3.template >> /tmp/$$.tmp
       printf "append initrd=initrd.img inst.text inst.ks=hd:LABEL=CUSTOM-RHEL:/ks/$KS_I\n" >> /tmp/$$.tmp
       cat /tmp/$$.tmp >> $Working/custom/isolinux/isolinux.cfg && rm /tmp/$$.tmp
    done
    fi
cat $Working/custom/.end.template >> $Working/custom/isolinux/isolinux.cfg
[ -e $Working/acr.iso ] && cd $Working/acr.iso && tar -cvzf $Working/target/ACR.tgz *
[ -e $Working/CUSTOM-RHEL.iso ] && rm -v $Working/completed.iso 
cd $Working/target && genisoimage -o $Working/CUSTOM-RHEL.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V CUSTOM-RHEL -boot-load-size 4 -boot-info-table -R -J -v -T ./ \
	&& echo done
