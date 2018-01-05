#!/bin/bash
Dir=`dirname $0`
Working=`pwd -P $Dir`
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
