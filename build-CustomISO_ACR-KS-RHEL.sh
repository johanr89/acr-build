#!/bin/bash

WorkMain="/root/Desktop/acr-build-ISO-WorkMain"
WorkRHEL=$WorkMain"/workRHEL"
WorkAcrSw=$WorkMain"/workACR-software"
WorkAcrPatch=$WorkMain"/workACR-patch"
WorkAcrKickstart=$WorkMain"/workACR-kickstart"
ColDBG="normal"

StageTrackPrefix="/tmp/.build_iso_stage_tracker"
StageTrackFile=$StageTrackPrefix"_"$$".tmp"

KsCreator="create-an-ACR.sh"
DefaultsFile="create-an-ACR.variables.cfg"
Prefix=`grep -i ^prefix $KsCreator | cut -f2 -d\"` 
TimeOUT="2"
IsoLabel="ACR-BUILD"
IsoKSPath="/kickstart"

color_red=$'\033[31;1m'
color_green=$'\033[32;1m'
color_yellow=$'\033[33;1m'
color_blue=$'\033[34;1m'
color_normal=$'\033[0m'

MyDir=`dirname $0` ; cd $MyDir

function PrintMsg {

case $1 in
"red")
        printf "%s$2" "$color_red"
        ;;
"green")
        printf "%s$2" "$color_green"
        ;;
"yellow")
        printf "%s$2" "$color_yellow"
        ;;
"blue")
        printf "%s$2" "$color_blue"
        ;;
"normal")
        printf "%s$2" "$color_normal"
        ;;
*)
        printf "\n\tUsage:\n\t\tPrtMsg "
        printf "%sred " "$color_red"
        printf "%sgreen " "$color_green"
        printf "%syellow " "$color_yellow"
        printf "%sblue " "$color_blue"
        printf "%snormal " "$color_normal"
        printf " \"Hello World\"\n\n"
        ;;
esac

}
function StageProcess_GetLastEnd {

    if [ `ls -1tr $StageTrackPrefix* | wc -l` -gt 0 ]
    then
         LastStageFile=`ls -1tr $StageTrackPrefix* | tail -1` 2>/dev/null
	 LastCompleted=`grep -i \:end $LastStageFile | tail -1 | cut -f1 -d \:` 2>/dev/null
	 echo $LastCompleted
         return 0
    fi

    echo S00
    return 0
}

function Stage__Pre-Checks {

    StgNum=$1 

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Pre-Checks\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    PrintMsg normal "\nCheck root permission\t"
    if [ `id -u` -ne 0 ]; then            # Do you have root permission?
	PrintMsg red "FAIL"
        return 11
    else
	PrintMsg blue "OK"
    fi

    PrintMsg normal "\nCheck Linux disto.\t"
    if [ `uname -a | grep -i debian | wc -l` -lt 1 ]; then    # Is this Dedian ?
	PrintMsg red "FAIL"
	PrintMsg normal "\tBuilt using deb like, ubuntu or kali. This seems different."
        return 19
    else
	PrintMsg blue "OK"
	PrintMsg normal "\tDebian looks good - any flavour may do."
    fi

    PrintMsg normal "\nCheck Kickstart details\t"
    if [ `find $MyDir -type f | grep -i $Prefix | wc -l` -lt 1 ]; then         # Are there a minimum of one host definitions ?
	PrintMsg red "FAIL"
        PrintMsg normal "\tNo kickstart definitions found to build."
        return 12
    else
	KickSFiles=`ls -1 $MyDir/ | grep -i $Prefix | wc -l`
	PrintMsg blue "OK"
        PrintMsg normal "\tFound: $KickSFiles x ACR host."
    fi
    
    PrintMsg normal "\nCheck Dependencies\t"
    Deplist="genisoimage mount rsync"
    for DEP in $DepList
    do
        which $DEP &>/dev/null
        if [ $? -ne 0 ]
        then
            PrintMsg red "FAIL"
            PrintMsg normal "\t$DEP: not installed"
            return 15
        fi
    done
    PrintMsg blue "OK"
    PrintMsg normal "\t$DepList"
    PrintMsg normal "\n"

    PrintMsg normal "Check Working Dir Exist\t"
    for Dir in $WorkMain $WorkRHEL $WorkAcrSw $WorkAcrPatch $WorkAcrKickstart
    do
        [ -d $Dir ] || mkdir -p $Dir

        if [ -d $Dir ]
        then
            chown root $Dir &>/dev/null
            chmod u+r,u+w,u+x $Dir &>/dev/null
	else
            PrintMsg red "FAIL"
            PrintMsg normal "\t$Directory issue with: $Dir"
            return 15
        fi
    done
    PrintMsg blue "OK"
    PrintMsg normal "\n"

    PrintMsg normal "Check Workdir clean\t"
    PrintMsg blue "..."

    for Dir in $WorkRHEL $WorkAcrSw $WorkAcrPatch $WorkAcrKickstart
    do
        PrintMsg normal "\n\t$Dir\t"
        if [ -d $Dir ]
        then
            if [ `find $Dir  -maxdepth 2 -type f 2>/dev/null | wc -l` -gt 0 ] 2>/dev/null
	    then
                PrintMsg yellow "WARN"
                PrintMsg normal "\tNot empty, is this acceptable ? "
                # PrintMsg yellow "[ C "
                # PrintMsg red "cleanup now"
                # PrintMsg yellow " ]  or  [ A "
                # PrintMsg green " accept not empty"
                # PrintMsg yellow " ] ? "
		# read CleanOrAccept
		# if [ `echo $CleanOrAccept | grep -i c | wc -l` -eq 1 ] && [ -d $Dir ]
		# then
                #       PrintMsg normal "\nCleaning now\t"
		# 	rm -rf $Dir &>/dev/null
		# 	mkdir -p $Dir &>/dev/null
		# 	chown root $Dir &>/dev/null
    		#       chmod u+r,u+w,u+x $Dir &>/dev/null
		# fi
                # PrintMsg normal "\n"
	    fi
	else
            PrintMsg red "FAIL"
            PrintMsg normal "\tError checking."
            return 15
        fi
    done
    PrintMsg normal "\nCheck Workdir clean\t"
    PrintMsg blue "OK"
    PrintMsg normal "\n"

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__Mount {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Mount\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    PrintMsg normal "\nCheck Red Hat iso file\t"
    Rhl_Iso=`grep "RHEL_ISO_File" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    if [ `ls $Rhl_Iso 2>/dev/null | wc -l` -gt 0 ]
    then
	PrintMsg blue "OK"
        PrintMsg normal "\tISO: $Rhl_Iso"
    else
	PrintMsg red "FAIL"
        PrintMsg normal "\tNot usable: $Rhl_Iso"
	return 13
    fi

    PrintMsg normal "\nCheck ACR iso file\t"
    ACR_Iso=`grep "ACR_ISO_File" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=`
    if [ `ls $ACR_Iso 2>/dev/null | wc -l` -gt 0 ]
    then
	PrintMsg blue "OK"
        PrintMsg normal "\tISO: $ACR_Iso"
    else
	PrintMsg red "FAIL"
        PrintMsg normal "\tNot usable: $ACR_Iso"
	return 14
    fi

    PrintMsg normal "\nCheck RHEL mount dir\t"
    Rhl_Mnt=`grep "RHEL_ISO_Mount" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    [ -d $Rhl_Mnt ] || mkdir -p $Rhl_Mnt
    mountpoint -q $Rhl_Mnt && umount $Rhl_Mnt

    mountpoint -q $Rhl_Mnt
    if [ $? -ne 0 ] && [ -d $Rhl_Mnt ]
    then
	    PrintMsg blue "OK"
            PrintMsg normal "\tDir: $Rhl_Mnt"
    else
            PrintMsg red "FAIL"
            PrintMsg normal "\tCheck: $Rhl_Mnt"
            return 21
    fi

    PrintMsg normal "\nCheck ACR mount dir\t"
    ACR_Mnt=`grep "ACR_ISO_Mount" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    [ -d $ACR_Mnt ] || mkdir -p $ACR_Mnt
    mountpoint -q $ACR_Mnt && umount $ACR_Mnt

    mountpoint -q $ACR_Mnt
    if [ $? -ne 0 ] && [ -d $ACR_Mnt ]
    then
	    PrintMsg blue "OK"
            PrintMsg normal "\tDir: $ACR_Mnt"
    else
            PrintMsg red "FAIL"
            PrintMsg normal "\tCheck: $ACR_Mnt"
            return 22
    fi

    PrintMsg normal "\nMount RHEL iso loop\t"
    mount -o ro,loop $Rhl_Iso $Rhl_Mnt 
    mountpoint -q $Rhl_Mnt
    if [ $? -eq 0 ]
    then
	    PrintMsg blue "OK"
            PrintMsg normal "\t`df -h $Rhl_Mnt | tail -1 | awk '{print $6}'`"
    else
            PrintMsg red "FAIL"
            PrintMsg normal "\tCould not mount \"$Rhl_Iso\" on \"$Rhl_Mnt\""
            return 23
    fi

    PrintMsg normal "\nMount ACR iso loop\t"
    mount -o ro,loop $ACR_Iso $ACR_Mnt
    mountpoint -q $ACR_Mnt
    if [ $? -eq 0 ]
    then
	    PrintMsg blue "OK"
            PrintMsg normal "\t`df -h $ACR_Mnt | tail -1 | awk '{print $6}'`"
    else
            PrintMsg red "FAIL"
            PrintMsg normal "\tCould not mount \"$ACR_Iso\" on \"$ACR_Mnt\""
            return 23
    fi

    PrintMsg normal "\n"

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__CopyIso {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Copy ISO\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    PrintMsg normal "\nRun copy RHEL now\t"
    SizeRhelWork=`du -sk $WorkRHEL | awk '{print $1}'`
    if [ $SizeRhelWork -gt 3600000 ] # Usually 4054996
    then		
	PrintMsg blue "OK"
        PrintMsg normal "\tPreviously copied, or clean before this ... dir:`du -sh $WorkRHEL/.`"
        umount $Rhl_Mnt
    else
        mountpoint -q $Rhl_Mnt
        if [ $? -eq 0 ] && [ -d $WorkRHEL ]
        then
            PrintMsg blue "busy ... "
            {
        	    rsync --update -avz $Rhl_Mnt/* $WorkRHEL/.
            }&>/dev/null
    	if [ $? -eq 0 ]
            then
	        PrintMsg blue "OK"
                PrintMsg normal "\tDone  iso:`du -sh $Rhl_Mnt/.` Dir:`du -sh $WorkRHEL/.`"
	        umount $Rhl_Mnt
            else
                PrintMsg red "FAIL"
                PrintMsg normal "\tExit code indicates error."
                return 31
            fi
        else
            PrintMsg red "FAIL"
            PrintMsg normal "\tDir \"$WorkRHEL\" or mountpoint \"$Rhl_Mnt\" invalid."
            return 32
        fi
    fi

    PrintMsg normal "\n"
    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__CopyACR {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Copy ACR ISO\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    PrintMsg normal "\nRun copy ACR now\t"
    SizeAcrWork=`du -sk $WorkAcrSW | awk '{print $1}'`
    if [ $SizeAcrWork -gt 140000 ] # Usually 166230
    then
	PrintMsg blue "OK"
        PrintMsg normal "\tPreviously copied, or clean before this ... dir:`du -sh $WorkAcrSw/.`"
        umount $ACR_Mnt
    else
        mountpoint -q $ACR_Mnt
        if [ $? -eq 0 ] && [ -d $WorkAcrSw ]
        then
            PrintMsg blue "busy ... "
            {
                rsync --update -avz $ACR_Mnt/* $WorkAcrSw/.
            }&>/dev/null
            if [ $? -eq 0 ]
            then
	        PrintMsg blue "OK"
                PrintMsg normal "\tDone  iso:`du -sh $ACR_Mnt/.` Dir:`du -sh $WorkAcrSw/.`"
	        umount $ACR_Mnt
            else
                PrintMsg red "FAIL"
                PrintMsg normal "\tExit code indicates error."
                return 31
            fi
        else
            PrintMsg red "FAIL"
            PrintMsg normal "\tDir \"$WorkAcrSw\" or mountpoint \"$ACR_Mnt\" invalid."
            return 32
        fi
    fi

    PrintMsg normal "\n"
    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function CheckLEN { # checks if it has some characters

    [ `echo $1 | wc -c` -gt 1 ] \
	    && return 0
    return 1
}

function Stage__Kickstarts {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Generate ks.cfg\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    PrintMsg normal "\nRecorder template\t"
    TemplateNormalACR=$MyDir"/template/kickstart-acr.template"
    TemplatePostACR=$MyDir"/template/kickstart-post.template"
    if [ -f $TemplateNormalACR ] && [ -f $TemplatePostACR ]
    then
        if [ `grep -v ^# $TemplateNormalACR | grep ___ | wc -l` -gt 1 ]
	then
            PrintMsg blue "OK"
            PrintMsg normal "\tFound normal ACR template $TemplateNormalACR"
	else
            PrintMsg red "FAIL"
            PrintMsg normal "\tNot usable template found as $TemplateNormalACR"
            return 51
        fi 
    else
        PrintMsg red "FAIL"
        PrintMsg normal "\tNot found $TemplateNormalACR"
        return 52
    fi

    [ -d $WorkAcrKickstart ] || mkdir -p $WorkAcrKickstart 
    rm -f $WorkAcrKickstart/ks_*.cfg 2>/dev/null

    PrintMsg normal "\n\nBUILD:\t$WorkAcrKickstart\t"
    PrintMsg blue "..."
    PrintMsg normal "\n"

    for Host in `ls -1 ${MyDir}/${Prefix}*`
    do
        PrintMsg normal "\t`echo $Host | sed -e 's/\.\///g'`\t"
        
	# Keep_Calls
        HostKeepCalls=`grep \:Keep_Calls $Host | cut -f2 -d \=` ; CheckLEN $HostKeepCalls || return $STG
       	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tKeepCalls : $HostKeepCalls"

        #  Hostname #  ___HOSTNAME___
       	HostFQDN=`grep \:Hostname $Host | cut -f2 -d \=` ; CheckLEN $HostFQDN || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHostname : $HostFQDN"
	WorkingKSOUT=$WorkAcrKickstart/"ks__"`echo $HostFQDN | sed -e 's/\./_/g'`"__.cfg" 

	if [ `echo $HostKeepCalls | egrep -i '(yes)' | egrep -vi '(no)' | wc -l` -gt 0 ]
	then
            grep -vi clearpart $TemplateNormalACR > $WorkingKSOUT
	elif [ `echo $HostKeepCalls | egrep -vi '(yes)' | egrep -i '(no)' | wc -l` -gt 0 ]
        then
            cat $TemplateNormalACR > $WorkingKSOUT
        fi
	sed -i 's/___HOSTNAME___/'$HostFQDN'/g' $WorkingKSOUT

        #  Keyboard #  ___KEYBOARD___
        HostKeyboard=`grep \:Keyboard $Host | cut -f2 -d \=` ; CheckLEN $HostKeyboard || return $STG
       	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tKeyboard : $HostKeyboard"
	sed -i 's/___KEYBOARD___/'$HostKeyboard'/g' $WorkingKSOUT

        #  NIC #  ___NICDEV___
        HostNic=`grep \:NIC $Host | cut -f2 -d \=` ; CheckLEN $HostNic || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tNIC : $HostNic"
	sed -i 's/___NICDEV___/'$HostNic'/g' $WorkingKSOUT

        #  IP #  ___IPADDRESS___
        HostIpAddress=`grep \:IP $Host | cut -f2 -d \=` ; CheckLEN $HostIpAddress || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tIP-Address : $HostIpAddress"
	sed -i 's/___IPADDRESS___/'$HostIpAddress'/g' $WorkingKSOUT

        #  Netmask #  ___NETMASK___
        HostNetmask=`grep \:Netmask $Host | cut -f2 -d \=` ; CheckLEN $HostNetmask || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tNetmask : $HostNetmask"
	sed -i 's/___NETMASK___/'$HostNetmask'/g' $WorkingKSOUT

        #  Default_Route #  ___GATEWAY___
        HostGateway=`grep \:Default_Route $Host | cut -f2 -d \=` ; CheckLEN $HostGateway || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tGateway : $HostGateway"
	sed -i 's/___GATEWAY___/'$HostGateway'/g' $WorkingKSOUT

        #  DNS_Server #  ___NAMESERVER___
        HostNameServer=`grep \:DNS_Server $Host | cut -f2 -d \=` ; CheckLEN $HostNameServer || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tNameServer : $HostNameServer"
	sed -i 's/___NAMESERVER___/'$HostNameServer'/g' $WorkingKSOUT

        #  TimeZone #  ___TIMEZONE___
        HostTZ=`grep \:TimeZone $Host | cut -f2 -d \= | sed -e 's/\//\\\\\//g'` ; CheckLEN $HostTZ || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tTimeZone : $HostTZ"
	sed -i 's/___TIMEZONE___/'${HostTZ}'/g' $WorkingKSOUT

        #  NTP_Server #  ___NTPSERVER___
        HostNTP=`grep \:NTP_Server $Host | cut -f2 -d \=` ; CheckLEN $HostNTP || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tNTP : $HostNTP"
	sed -i 's/___NTPSERVER___/'$HostNTP'/g' $WorkingKSOUT

        HostCust=`grep \:Customer $Host | cut -f2 -d \= | sed -e 's/\ /\\\\\ /g'` ; CheckLEN $HostCust || return $STG
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tTimeZone : $HostCust"
	export $HostCust

        # NumberOfDisks
        HostNumOfDisk=`grep \:NumberOfDisks $Host | cut -f2 -d \=` 
	[ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tNumberOfDisks : $HostNumOfDisks"

	if [ `echo $HostNumOfDisk | egrep -i '(2|two)' | wc -l` -ge 1 ]
	then
            HostDiskCount=2
        else # asume 1
            HostDiskCount=1
        fi

        [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHostDiskCount : $HostDiskCount"

        HostLineBoot="part /boot"
        HostLineRoot="part /"
        HostLineWitness="part /opt/witness"
        HostLinePostgres="part /var/lib/pgsql"
        HostLineSwap="part"
        HostLineCalls="part /calls"

	if [ `echo $HostKeepCalls | grep -i yes | wc -l` -ge 1 ]
	then

            HostLineBoot=$HostLineBoot"             --ondisk=sda --usepart=sda1 --noformat"
            HostLineRoot=$HostLineRoot"             --ondisk=sda --usepart=sda2 --noformat"

	    if [ $HostDiskCount -eq 2 ]
	    then
                HostLineWitness=$HostLineWitness"   --ondisk=sda --usepart=sda3 --noformat"
                HostLinePostgres=$HostLinePostgres" --ondisk=sda --usepart=sda4 --noformat"
                HostLineSwap=$HostLineSwap"   swap  --ondisk=sdb --usepart=sdb1"
                HostLineCalls=$HostLineCalls"       --ondisk=sdb --usepart=sdb2 --noformat"
            else
                HostLinePostgres=$HostLinePostgres" --ondisk=sda --usepart=sda3 --noformat"
		# sda4 Extended
                HostLineWitness=$HostLineWitness"   --ondidk=sda --usepart=sda5 --noformat"
                HostLineSwap=$HostLineSwap"   swap  --ondidk=sda --usepart=sda6"
                HostLineCalls=$HostLineCalls"       --ondidk=sda --usepart=sda7 --noformat"
            fi

        elif [ `echo $HostKeepCalls | grep -i no | wc -l` -gt 0 ]
	then

            HostLineClearPart="yes"

            HostLineBoot=$HostLineBoot" --fstype=ext4 --ondisk=sda --size=1000"         # default:   200
            HostLineRoot=$HostLineRoot" --fstype=ext4 --ondisk=sda --size=20000"        # default: 10000

	    if [ $HostDiskCount -eq 2 ]
	    then
                HostLineWitness=$HostLineWitness"    --fstype=ext4 --ondisk=sda --size=15000"   # default: 10000
                HostLinePostgres=$HostLinePostgres"  --fstype=ext4 --ondisk=sda --size=20000"
                HostLineSwap=$HostLineSwap"   swap   --recommended --ondisk=sdb"
                HostLineCalls=$HostLineCalls"        --fstype=ext4 --ondisk=sdb --size=1000 --grow"
            else
                HostLineWitness=$HostLineWitness"    --fstype=ext4 --ondisk=sda --size=15000"   # default: 10000
		# sda4 Extended
                HostLinePostgres=$HostLinePostgres"  --fstype=ext4 --ondisk=sda --size=20000" # default: 10000
                HostLineSwap=$HostLineSwap"   swap   --recommended --ondisk=sda"
                HostLineCalls=$HostLineCalls"        --fstype=ext4 --ondisk=sda --size=1000 --grow"
            fi

        fi

        CheckLEN $HostLineBoot     || return $STG
        CheckLEN $HostLineRoot     || return $STG
        CheckLEN $HostLineWitness  || return $STG
        CheckLEN $HostLinePostgres || return $STG
        CheckLEN $HostLineSwap     || return $STG
        CheckLEN $HostLineCalls    || return $STG

	echo $HostLineBoot >> $WorkingKSOUT     ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Boot : $HostLineBoot"
	echo $HostLineRoot >> $WorkingKSOUT     ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Root : $HostLineRoot"
	echo $HostLinePostgres >> $WorkingKSOUT ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Postgres : $HostLinePostgres"
	echo $HostLineWitness >> $WorkingKSOUT  ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Witness : $HostLineWitness"
	echo $HostLineSwap >> $WorkingKSOUT     ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Swap : $HostLineSwap"
	echo $HostLineCalls >> $WorkingKSOUT    ; [ $DEBUG = "true" ] && PrintMsg $ColDBG "\nDEBUG\tHost Line Calls : $HostLineCalls"

        cat $TemplatePostACR >> $WorkingKSOUT

        PrintMsg blue "OK"
        PrintMsg normal "\n"

    done
    PrintMsg normal "BUILD:\t$WorkAcrKickstart\t"
    PrintMsg blue "OK"
    PrintMsg normal "\n"

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0

# CRS_Layout
# ACR_SW_TGZ
# ACR_Patch_Dir
# ACR_TOOLS

######  kickstart-acr.template
#
#  # JLR ___ clearpart --all --initlabel
#  ___CLEARPARTLINE___
#  # JLR-default ___ part /boot --fstype=ext4 --size=200
#  # JLR-custom  ___ part /boot        --fstype=ext4  --usepart=sda1
#  ___PARTLINE_BOOT___
#  # JLR-default ___ part / --fstype=ext4 --size=10000
#  # JLR-custom  ___ part /            --fstype=ext4  --usepart=sda2
#  ___PARTLINE_ROOT___
#  # JLR-default ___ part /opt/witness --fstype=ext4 --size=10000
#  # JLR-custom  ___ part /opt/witness  --fstype=ext4 --usepart=sda3
#  ___PARTLINE_WITNESS___
#  # JLR-default ___ part /var/lib/pgsql --fstype=ext4 --size=10000
#  # JLR-custom  ___ part /var/lib/pgsql --fstype=ext4 --usepart=sda4
#  ___PARTLINE_PGSQL___
#  # JLR-default ___ part  swap --recommended
#  # JLR-custom  ___ part  swap  --usepart=sdb1 --ondisk=sdb 
#  ___PARTLINE_SWAP___
#  # JLR-default ___ part /calls --fstype=ext4 --size=1000 --grow
#  # JLR-custom  ___ part /calls --usepart=sdb2 --ondisk=sdb --noformat 
#  ___PARTLINE_CALLS___
#  
#  

#WorkAcrPatch=$WorkMain"/workACR-patch"

}
function Stage__ISOLUNUX {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "RHEL Menu\n"
    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo DEBUG exit ; exit 1 ######################################################################

    # HostCust

    PrintMsg normal "\nCheck isolinux template\t"

      TemplateISODefault=$MyDir"/template/isolinux-default.template"
      TemplateISOaSingle=$MyDir"/template/isolinux-single.template"
      TemplateISOtoFinal=$MyDir"/template/isolinux-final.template"

    PrintMsg normal "\nCheck iso ks-path\t"
    [ -d ${WorkRHEL}${IsoKSPath} ] || mkdir -p ${WorkRHEL}${IsoKSPath} 
    if [ -d ${WorkRHEL}${IsoKSPath} ]
    then
	IsoKsDest=${WorkRHEL}${IsoKSPath}
        PrintMsg blue "OK"
        PrintMsg normal "\tFound: ${WorkRHEL}${IsoKSPath}"
    else
        PrintMsg red "FAIL"
        PrintMsg normal "\tNot found: ${WorkRHEL}${IsoKSPath}"
	return $STG
    fi

    if [ -f $TemplateISODefault ] && [ -f $TemplateISOaSingle ] && [ -f $TemplateISOtoFinal ]
    then
        PrintMsg blue "OK"
        PrintMsg normal "\tFound 3x required"
    else
        PrintMsg red "FAIL"
        PrintMsg normal "\tNot all are available."
	return $STG
    fi

    PrintMsg normal "\nCollect variales\t"

      CheckLEN $HostCust   || exit 1
      IsoHostTitle=$HostCust__`date +%F`         # isolinux-default.template  ___Title___ 

      CheckLEN $IsoLabel   || exit 2
      IsoHdLabel=$IsoLabel                       # isolinux-default.template  ___HdLabel___           # IsoLabel

      IsoSubMenu="ACR-BUILD" 
      CheckLEN $IsoSubMenu || exit 3                    # isolinux-default.template  ___SubMenu___           # HostCust

    PrintMsg blue "OK"
    PrintMsg normal "\t"


    PrintMsg normal "\nInitiate isolinux\t"

      if [ -f ${WorkRHEL}"/isolinux/isolinux.cfg" ]
      then
          cp ${WorkRHEL}"/isolinux/isolinux.cfg" ${WorkRHEL}"/isolinux/.isolinux.cfg_"`date +%F`"_"$$ \
              && cat $TemplateISODefault > ${WorkRHEL}"/isolinux/isolinux.cfg"
              && PrintMsg blue "OK" 
	      [ $? -ne 0 ] && PrintMsg red "FAIL" \
	                   && return 87
      else
          PrintMsg red "FAIL"
	  return 87
      fi

    PrintMsg normal "\nMain isolinux bits\t"

      #
      #
      #
      # isolinux-default.template  ___Title___
      # isolinux-default.template  ___HdLabel___
      # isolinux-default.template  ___SubMenu___

    PrintMsg normal "\nEack kickstart\t"
    if [ `ls -1 $WorkAcrKickstart/ks__*.cfg | wc -l` -gt 1 ]
    then
        PrintMsg normal "\nIndividual Host Files\t"
        PrintMsg blue "..."

	cd $WorkAcrKickstart/
        for AcrKsFile in `ls -1 ks__*.cfg`
	do
            PrintMsg normal "\n\t$AcrKsFile\t" 
	    IsoSingleLable=`echo $AcrKsFile | sed -e 's/\.cfg//g' | cut -c 4-999` # isolinux-single.template   ___SingleLabel___       # File ?
	    IsoSingleMenuText=$IsoSingleLable # isolinux-single.template   ___SingleMenuText___    # FQDN ?
	    IsoSingleMenuHelpText="install_It_Now" # isolinux-single.template   ___SingleHelpText___    # IP ?
	    IsoSingleMenuHdLabel=$IsoHdLabel # isolinux-single.template   ___HdLabel___           # IsoLabel
	    IsoSingleFullPathKsFile=$IsoKSPath"/"$AcrKsFile    # ="/kickstart" # isolinux-single.template   ___FullPathToKsCfg___   # /kickstart/

	    cp -f $AcrKsFile $IsoKsDest/. || exit 77

	    TestSingle=0
            cat $TemplateISOaSingle > /tmp/.isolinux_$IsoSingleLable_$$.tmp || TestSingle=1

            #
            #
            #
            # isolinux-single.template   ___SingleLabel___
            # isolinux-single.template   ___SingleMenuText___
            # isolinux-single.template   ___SingleHelpText___
            # isolinux-single.template   ___HdLabel___
            # isolinux-single.template   ___FullPathToKsCfg___
             
	    if [ $TestSingle -eq 0 ]
            then
                cat /tmp/.isolinux_$IsoSingleLable_$$.tmp >> ${WorkRHEL}"/isolinux/isolinux.cfg" \
                  && mv /tmp/.isolinux_$IsoSingleLable_$$.tmp /tmp/.isolinux_$IsoSingleLable_$$.done 

                PrintMsg blue "OK"
                PrintMsg normal "\t"
            else
                PrintMsg red "FAIL"
                PrintMsg normal "\t"
		return 65
            fi

	done
    fi

    # TemplateISOtoFinal=$MyDir"/template/isolinux-final.template"

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0

}

function Stage__ACRPatches {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Patch Collection\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__ACRTools {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "acr-tools\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__Combiner {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Combiner\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__GenISOImage {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Gen-ISO\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function Stage__Cleanup {

    StgNum=$1

    PrintMsg yellow "\nStage $StgNum start\t" ; PrintMsg normal "Cleanup\n"
    echo "S"$StgNum":start "`date +%F\ \ %H-%M-%S` >> $StageTrackFile

    echo "S"$StgNum":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
    PrintMsg yellow "\nStage $StgNum end\t" ; PrintMsg red "\tsleeping $TimeOUT ... [Ctrl-C to stop]" ; sleep $TimeOUT
    return 0
}

function ErrorStatus {

        ErrCode=$1

	if [ $ErrCode -ne 0 ]
	then
	    echo "Error Exit "$ErrCode
	    exit 1
        else
            return 0
        fi
	echo " OOPSIE "; exit 999
}

function Question {

	QQQ=$1
	PrintMsg yellow "\nQ:\t"
	PrintMsg normal "$QQQ"
	PrintMsg yellow " ?"
	PrintMsg normal "\t["   ; PrintMsg yellow "Y"
	PrintMsg normal "] YES  or  [" ; PrintMsg yellow "N" ; PrintMsg normal "] NO "
	read Answer ; PrintMsg normal "\n"

        if [ `echo $Answer | grep -i "y" | wc -l` -ge 1 ] 2>/dev/null
	then
            return 0
        elif [ `echo $Answer | grep -i "n" | wc -l` -ge 1 ] 2>/dev/null
	then
            return 1
        else
            return 3
        fi
}

############################################################

#  |////////////////|
#  |/|            |/|
#  |/|    MAIN    |/|
#  |/|            |/|
#  |////////////////|

DEBUG=false
#DEBUG=true

StageCurrent="S00"
StageLast="S11"

StageLast=`StageProcess_GetLastEnd` 2>/dev/null || StageLast="S00" ; [ $DEBUG = "true" 2>/dev/null ] && PrintMsg $ColDBG "\nDEBUG\tStageLast returned as $StageLast\n" 

if [ $StageLast = $StageCurrent ] 2>/dev/null
then
    StageCurrent="S00"
else
	Question "Resume after last completed stage? $StageLast"
	if [ $? -eq 0 ] 2>/dev/null
	then
            StageCurrent=`echo $StageLast | sed -e 's/S//g'`
        else
            StageCurrent="00"
	fi
	PrintMsg normal "\n"
        rm -f /tmp/.build_iso_stage_tracker_*.tmp 2>/dev/null
        echo $StageCurrent":end "`date +%F\ \ %H-%M-%S` >> $StageTrackFile
fi


while [ $StageCurrent <> $StageLast ]
do
    for STG in `seq -w $StageCurrent 1 11`
    do

    [ $DEBUG = "true" 2>/dev/null ] && PrintMsg $ColDBG "DEBUG\tEnter while $StageCurrent not $StageLast\n"

    PrintMsg normal "\n"
    PrintMsg red "================================================================="
    PrintMsg normal "\n"


    if [ $STG = "00" ] 
    then
        Stage__Pre-Checks $STG
        ErrorStatus $?
    fi
    if [ $STG = "01" ]
    then
        Stage__Mount $STG
        ErrorStatus $?
    fi
    if [ $STG = "02" ]
    then
        Stage__CopyIso $STG
        ErrorStatus $?
    fi
    if [ $STG = "03" ]
    then
        Stage__CopyACR $STG
        ErrorStatus $?
    fi
    if [ $STG = "04" ]
    then
        Stage__Kickstarts $STG
        ErrorStatus $?
    fi
    if [ $STG = "05" ]
    then
	Stage__ISOLUNUX $STG
        ErrorStatus $?
    fi
    if [ $STG = "06" ]
    then
	Stage__ACRPatches $STG
        ErrorStatus $?
    fi
    if [ $STG = "07" ]
    then
	Stage__ACRTools $STG
        ErrorStatus $?
    fi
    if [ $STG = "08" ]
    then
	Stage__Combiner $STG
        ErrorStatus $?
    fi
    if [ $STG = "09" ]
    then
	Stage__GenISOImage $STG
        ErrorStatus $?
    fi
    if [ $STG = "10" ]
    then
	Stage__Cleanup $STG
        ErrorStatus $?
    fi
    if [ $STG = "11" ]
    then
        exit 0
    fi

#    StageCurrent=`StageProcess_GetLastEnd` 
    done

done

exit 0
# if [ -e $Working/target ]; then
# 	echo "Clean Target?"
# 	read AA
# 	if [ $AA = "y" ] || [ $AA = "Y" ];then
# 		echo YES ; sleep 3
#                 mountpoint -q $Working/rhel.iso || exit 1
# 		rm -vrf $Working/target
#                 rsync --update -avz $Working/rhel.iso/* $Working/target/. && cd $Working/custom && tar -cf - * | tar -xvf - -C $Working/target/
#         fi
# fi	
# rm -v $Working/target/kde*
# 
# [ ! -e $Working/target ] && mkdir $Working/target
# [ -e $Working/custom ] || exit 2
# if [ -e $Working/custom/ks ]
# then
# 	cat $Working/custom/.start.template >  $Working/custom/isolinux/isolinux.cfg 
#     cd $Working/custom/ks && KS_FILES=`ls -1 *.cfg`
#     for KS_I in $KS_FILES
#     do
#        printf "  \nlabel linux_ks_$KS_I\n"  > /tmp/$$.tmp ;printf "    menu label Install using $KS_I\n" >> /tmp/$$.tmp
# # 	    cat $Working/custom/.single3.template >> /tmp/$$.tmp
#        printf "append initrd=initrd.img inst.text inst.ks=hd:LABEL=CUSTOM-RHEL:/ks/$KS_I\n" >> /tmp/$$.tmp
#        cat /tmp/$$.tmp >> $Working/custom/isolinux/isolinux.cfg && rm /tmp/$$.tmp
#     done
#     fi
# cat $Working/custom/.end.template >> $Working/custom/isolinux/isolinux.cfg
# [ -e $Working/acr.iso ] && cd $Working/acr.iso && tar -cvzf $Working/target/ACR.tgz *
# [ -e $Working/CUSTOM-RHEL.iso ] && rm -v $Working/completed.iso 
# cd $Working/target && genisoimage -o $Working/CUSTOM-RHEL.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V CUSTOM-RHEL -boot-load-size 4 -boot-info-table -R -J -v -T ./ \
# 	&& echo done
# 
# timezone ___TIMEZONE___ --utc --ntpservers=192.168.0.1
# ___CLEARPARTLINE___
# ___PARTLINE_BOOT___
# ___PARTLINE_WITNESS___
# ___PARTLINE_PGSQL___
# ___PARTLINE_SWAP___
# ___PARTLINE_CALLS___
