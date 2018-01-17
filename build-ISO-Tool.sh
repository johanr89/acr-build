#!/bin/bash

Confirm_Wait_Auto="auto"
TimeOUT="5"

IsoLabel="ACR_BUILD"
WorkMain="/root/Desktop/acr-build-ISO-WorkMain"
WorkRHEL=$WorkMain"/workRHEL"
WorkAcrSw=$WorkMain"/workACR-software"
WorkAcrPatch=$WorkMain"/workACR-patch"
WorkAcrKickstart=$WorkMain"/workACR-kickstart"
WorkAcrTools=$WorkMain"/workACR-tools"
AcrTools_Url="http://github.com/johanr89/acr-tools/archive/master.zip"
ColDBG="normal"

StageTrackPrefix="/tmp/.build_iso_stage_tracker"
StageListFile="/tmp/buil_stagelist.txt"
StageTrackFile=$StageTrackPrefix"_"$$".tmp"

KsCreator="add-ACR_kickstart.sh"
DefaultsFile="create-an-ACR.variables.cfg"
Prefix=`grep -i ^prefix $KsCreator | cut -f2 -d\"` 
IsoSubMenu="ACR_kickstart"
IsoKSPath="kickstart"

ColorStage="blue"
ColorGood="yellow"
ColorGood="green"
ColorFail="red"

color_red=$'\033[31;1m'
color_green=$'\033[32;1m'
color_yellow=$'\033[33;1m'
color_blue=$'\033[34;1m'
color_normal=$'\033[0m'

MeThinkIm=`dirname $0`               # Find Me
[ $? -ne 0 ] && exit 911             # Find Me
    cd $MeThinkIm                    # Find Me
    [ $? -ne 0 ] && exit 912         # Find Me
        MyDir=`pwd -P`               # Find Me
        [ $? -ne 0 ] && exit 913     # Find Me
            cd $MyDir                # Find Me
            [ $? -ne 0 ] && exit 914 # Find Me

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

    if [ -f $StageTrackPrefix ]
    then

        [ `cat $StageTrackPrefix 2>/dev/null | wc -l` -gt 0 ] &&  Stage=`tail -1 $StageTrackPrefix` 2>/dev/null
        if [ `echo $Stage | wc -c` -gt 1 ]
        then
            echo $Stage
            return 0
        fi
    fi

    echo "00"
    return 1

}

function PrintHead {

    LineColor="normal" ; LineChars="=" ; LineLenth="70"

    Stge=$1
    StartOrMode=$2
    Name=`GetLastKnownName $Stge`

    if [ $StartOrMode = "start" ] 2>/dev/null
    then
        Char1=">"
        Char2="<"
        PrintMsg normal "\n"
        for LineCount in `seq 1 1 $LineLenth`
        do
            PrintMsg normal "$LineChars"
        done
    else
        Char1="["
        Char2="]"
        StartOrMode=$Confirm_Wait_Auto
    fi

    PrintMsg normal "\n"
    PrintMsg normal "\n"
    PrintMsg normal   "=="
    PrintMsg red    "$Char1 "
    PrintMsg normal  "$StartOrMode"
    PrintMsg red " $Char2"
    PrintMsg normal   ="====="
    PrintMsg red "[ "
    PrintMsg yellow    "stage $Stge"
    PrintMsg red " ]"
    PrintMsg normal "===="
    PrintMsg red  "[ "
    printf '%s%30.30s' $color_yellow "$Name"
    #printf '%s%-33.33s' $color_yellow "$Name"
    #PrintMsg yellow "$Name"
    PrintMsg red " ]"
    PrintMsg normal "===\n"
    PrintMsg normal "\n"

#    if [ $2 = "ended" ] 2>/dev/null
#    then
#        PrintMsg normal "\n"
#        for LineCount in `seq 1 1 $LineLenth`
#        do
#            PrintMsg $LineColor "$LineChars"
#        done
#    fi

}
function Stage__Pre-Checks {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Check Dependancies" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" 

    ### ########################## check root permission ########################## 
    SubTitle="root permission"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    # PrintMsg $ColorGood "OK"
    # PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1

    if [ `id -u` -ne 0 ]
    then            # Do you have root permission?
	    PrintMsg $ColorFail "FAIL" 
        let Issue=$Issue+1
        return 11
    else
	    PrintMsg $ColorGood "OK"
    fi

    ########################## check linux distro ########################## 
    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "Linux disttribution"

    if [ `uname -a | grep -i "debian" | wc -l` -lt 1 ]    # Is this Dedian ?
    then
    	PrintMsg $ColorFail "FAIL"
    	PrintMsg normal "\tBuilt using deb like, ubuntu or kali. This seems different."
        let Issue=$Issue+1
        return 19
    else
	    PrintMsg $ColorGood "OK"
    fi

    ########################## valid kickstart files  ########################## 
    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "Kickstart details"

    if [ `find $MyDir -type f -name "Host_Config*" | wc -l` -lt 1 ]         # Are there a minimum of one host definitions ?
    then
    	PrintMsg $ColorFail "FAIL" 
        PrintMsg normal "\tNo kickstart definitions found to build."
        let Issue=$Issue+1
        return 12
    else
	    PrintMsg $ColorGood "OK"
    fi
    
    ########################## software dependancies  ########################## 
    Deplist="genisoimage mount rsync"
    for DEP in $DepList
    do
        let Stepper=$Stepper+1
            printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
            printf '%s %-35.35s | '   $color_normal "SW package $DEP"

        which $DEP &>/dev/null
        if [ $? -ne 0 ]
        then
            PrintMsg $ColorFail "FAIL"
            PrintMsg normal "\t$DEP: not installed"
            let Issue=$Issue+1
            return 15
        else
	        PrintMsg $ColorGood "OK"
        fi
    done

    ########################## Directory Access ########################## 
    for Dir in $WorkMain $WorkRHEL $WorkAcrSw $WorkAcrPatch $WorkAcrKickstart $WorkAcrTools
    do
        Short=`echo $Dir | sed -e 's/\//\n/g' | tail -1` 2>/dev/null

        let Stepper=$Stepper+1
            printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
            printf '%s %-35.35s | '   $color_normal "$Short Accessable"

        [ -d $Dir ] || mkdir -p $Dir &>/dev/null 

        if [ -d $Dir ] &>/dev/null 
        then
            chown root $Dir &>/dev/null
            chmod u+r,u+w,u+x $Dir &>/dev/null
	        PrintMsg $ColorGood "OK"
        else
            PrintMsg $ColorFail "FAIL"; let Issue=$Issue+1
            PrintMsg normal "\t$Directory issue with: $Dir"
            return 15
        fi
    done


    ########################## Directory Empty ########################## 
    for Dir in $WorkRHEL $WorkAcrSw $WorkAcrKickstart $WorkAcrTools     # $WorkAcrPatch 
    do
        Short=`echo $Dir | sed -e 's/\//\n/g' | tail -1` 2>/dev/null
    
        let Stepper=$Stepper+1
            printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
            printf '%s %-35.35s | '   $color_normal "$Short Empty"

        if [ -d $Dir ]
        then
            rmdir $Dir 2>/dev/null
            
            if [ $? -gt 0 ] 2>/dev/null
            # if [ `find $Dir  -maxdepth 2 -type f 2>/dev/null | wc -l` -gt 0 ] 2>/dev/null
    	    then
                let Issue=$Issue+1
                PrintMsg yellow "warning"
                PrintMsg normal "\t$Short not empty."
            else
                PrintMsg $ColorGood "OK"
	        fi
	    else
            PrintMsg $ColorFail "FAIL"
            PrintMsg normal "\tError checking $Short."
            return 15
        fi
        
        mkdir $Dir 2>/dev/null

    done

    #PrintMsg normal "\n\n==[ " && PrintMsg blue "Stage" &&  PrintMsg yellow "$StgNum" && PrintMsg normal " ]=========[\t" && PrintMsg red "\t$StgTitle" && PrintMsg normal "\t]==\n\n"

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Check_Issue_Mode {

    Issue=$1
    StgNum=$2

    

    if [ $Confirm_Wait_Auto = "auto" ] && [ $Issue -ne 0 ] 
    then
        PrintMsg normal "[ Mode : " ; PrintMsg blue   "AUTO" ; PrintMsg normal " ]" ; PrintMsg normal "\t"  ;   PrintMsg yellow " WARNING "
        PrintMsg blue   " ignore and continue ? "
        read; PrintMsg normal "\n"
    elif [ $Confirm_Wait_Auto = "wait" ]
    then
        if [ $Issue -ne 0 ]  
        then
            PrintMsg normal "[ Mode : " ; PrintMsg blue   "WAIT" ; PrintMsg normal " ]"
            PrintMsg normal "\n"; PrintMsg yellow " WARNING "; PrintMsg normal "\t"
            PrintMsg blue   " ignore and continue ? "
            read; PrintMsg normal "\n"
        else
            PrintMsg normal "[ Mode : " ; PrintMsg blue   "WAIT" ; PrintMsg normal " ]"
            PrintMsg normal "\n";  PrintMsg normal "\t"
            PrintMsg blue   " Waiting $TimeOUT sec ... "
            sleep $TimeOUT 
            PrintMsg normal "\n"
        fi
    elif [ $Confirm_Wait_Auto = "confirm" ]
    then
            PrintMsg normal "[ Mode : " ; PrintMsg blue   "CONFIRM" ; PrintMsg normal " ]"
            PrintMsg normal "\n"; PrintMsg normal "\t"
            PrintMsg blue   " Continue ? "
            read; PrintMsg normal "\n"
    else
            sleep 1
    fi

    echo $StgNum > $StageTrackPrefix
    return 0
}

function Stage__Mount {

    StgNum=$1 ; Issue="0" ; Stepper=0
   
    StgTitle="Everything mount-related" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle

    ########################## RHEL iso file ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "RHEL iso file"
    ### PrintMsg $ColorGood "OK" #  $ColorFail "FAIL"; let Issue=$Issue+1

    Rhl_Iso=`grep "RHEL_ISO_File" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    if [ `ls $Rhl_Iso 2>/dev/null | wc -l` -gt 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        $ColorFail "FAIL"; let Issue=$Issue+1
        PrintMsg normal "\tNot usable: $Rhl_Iso"
	return 13
    fi


########################## ACR iso file ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "ACR iso file"
    ACR_Iso=`grep "ACR_ISO_File" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=`
    if [ `ls $ACR_Iso 2>/dev/null | wc -l` -gt 0 ]
    then
        PrintMsg $ColorGood "OK" 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tNot usable: $ACR_Iso"
	return 14
    fi


########################## RHEL mountpoint ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "RHEL mountpoint"
    Rhl_Mnt=`grep "RHEL_ISO_Mount" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    [ -d $Rhl_Mnt ] || mkdir -p $Rhl_Mnt
    mountpoint -q $Rhl_Mnt && umount $Rhl_Mnt

    mountpoint -q $Rhl_Mnt
    if [ $? -ne 0 ] && [ -d $Rhl_Mnt ]
    then
        PrintMsg $ColorGood "OK" 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tCheck: $Rhl_Mnt"
        return 21
    fi


########################## ACR mountpoint ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "ACR mountpoint"
    ACR_Mnt=`grep "ACR_ISO_Mount" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    [ -d $ACR_Mnt ] || mkdir -p $ACR_Mnt
    mountpoint -q $ACR_Mnt && umount $ACR_Mnt

    Rhl_Mnt=`grep "RHEL_ISO_Mount" $MyDir/template/$DefaultsFile | cut -f2 -d \: | cut -f2 -d \=` 
    mountpoint -q $ACR_Mnt
    if [ $? -ne 0 ] && [ -d $ACR_Mnt ]
    then
        PrintMsg $ColorGood "OK" 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tCheck: $ACR_Mnt"
        return 22
    fi


########################## mounting RHEL ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "mounting RHEL"
    mount -o ro,loop $Rhl_Iso $Rhl_Mnt 
    mountpoint -q $Rhl_Mnt
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tCould not mount \"$Rhl_Iso\" on \"$Rhl_Mnt\""
        return 23
    fi


########################## mounting ACR ########################## 

    let Stepper=$Stepper+1
        printf '%s\n   %-3.3s | ' $color_blue   "$Stepper"
        printf '%s %-35.35s | '   $color_normal "mounting ACR"
    mount -o ro,loop $ACR_Iso $ACR_Mnt
    mountpoint -q $ACR_Mnt
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK" 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tCould not mount \"$ACR_Iso\" on \"$ACR_Mnt\""
        return 23
    fi

    # PrintMsg normal "\n\n==[ " && PrintMsg blue "Stage" &&  PrintMsg yellow "$StgNum" && PrintMsg normal " ]=========[\t" && PrintMsg red "\t$StgTitle" && PrintMsg normal "\t]==\n\n"

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__CopyIso {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Extract required from rhel iso"  && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle

    ########################## check root permission ########################## 
    SubTitle="rsync rhel iso target"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    # PrintMsg $ColorGood "OK"
    # PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1

    SizeRhelWork=`du -sk $WorkRHEL | awk '{print $1}'`
    if [ $SizeRhelWork -gt 2600000 ] # Usually 4054996
    then		
        umount $Rhl_Mnt
        PrintMsg $ColorGood "OK"
    else
        mountpoint -q $Rhl_Mnt
        if [ $? -eq 0 ] && [ -d $WorkRHEL ]
        then
                {
                    time rsync -az $Rhl_Mnt/* $WorkRHEL/. 
                    ExCoRsync=$?

                }&>/tmp/.rsync.rhel.$$.log

    	    if [ $ExCoRsync -eq 0 ]
            then
	            umount $Rhl_Mnt
                PrintMsg $ColorGood "OK"
            else
                PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                PrintMsg normal "\tcheck: /tmp/.rsync.rhel.$$.log"
                return 31
            fi
        else
            PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
            PrintMsg normal "\tDir \"$WorkRHEL\" or mountpoint \"$Rhl_Mnt\" invalid."
            return 32
        fi
    fi



    SubTitle="rem kde to slimming iso"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        {
            Removed=`find $WorkRHEL/Packages/. -type f -iname "*kde*.rpm" -exec rm -vf '{}' \; | wc -l`
            ExCdRemoveKde=$?

        }&>/tmp/.rm.find.$$.log

    if [ $Removed -gt 50 ] && [ $ExCdRemoveKde -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "warning"# ; let Issue=$Issue+1
        PrintMsg normal "\tNo kde files to clean"
    fi


    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__CopyACR {

    InstallerDirInWitness="install" 

    StgNum=$1 ; Issue="0" ; Stepper=0

    StgTitle="Extract software from ACR iso" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" 
    NeedaNewCopy="n"

    ############################# Installer Directory ########################## 

        SubTitle="Installer Directory"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        
        [ -d $WorkAcrSw/$InstallerDirInWitness ] || mkdir -p $WorkAcrSw/$InstallerDirInWitness 
        if [ $? -eq 0 ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
            PrintMsg normal "\tIssue with \"$WorkAcrSw/$InstallerDirInWitness\""
            return 23
        fi

        SubTitle="Verify ACR packages"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        if [ `find $WorkAcrSw/. -type f -iname "*.rpm" | grep -i \/acr | wc -l` -ge 1 ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg yellow "warning"
            PrintMsg normal "\tWill have to copy a new set"
            NeedaNewCopy="y"
        fi

        SubTitle="Verify Postgres packages"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        if [ `find $WorkAcrSw/. -type f -iname "*.r" | grep -i \/postgres | wc -l` -ge 1 ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg yellow "warning"
            PrintMsg normal "\tWill have to copy a new set"
            NeedaNewCopy="y"
        fi

        SubTitle="Verify Tomcat packages"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        if [ `find $WorkAcrSw/. -type f -iname "*.r" | grep -i \/tomcat | wc -l` -ge 1 ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg yellow "warning"
            PrintMsg normal "\tWill have to copy a new set"
            NeedaNewCopy="y"
        fi

        SubTitle="Verify Java packages"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        if [ `find $WorkAcrSw/. -type f -iname "*.r" | grep -i \/jdk | wc -l` -ge 1 ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg yellow "warning"
            PrintMsg normal "\tWill have to copy a new set"
            NeedaNewCopy="y"
        fi

        if [ $NeedaNewCopy = "y" ]
        then

            mountpoint -q $ACR_Mnt
            if [ $? -eq 0 ] && [ -d $WorkAcrSw ]
            then
                SubTitle="Copy .jar installer"
                let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
                {
                    find $ACR_Mnt -type f -iname "*.jar"  -exec cp -f '{}' $WorkAcrSw/$InstallerDirInWitness/. \;  
                }&>/tmp/.acr.copy.$$.log
                if [ $? -eq 0 ]
                then
                    PrintMsg $ColorGood "OK"
                else
                    PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                fi

                SubTitle="Copy .rpm installer"
                let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
                {
                    find  $ACR_Mnt -type f -iname "*.rpm"  -exec cp '{}' $WorkAcrSw/$InstallerDirInWitness/. \;
                }&>/tmp/.acr.copy.$$.log
                if [ $? -eq 0 ]
                then
                    PrintMsg $ColorGood "OK"
                else
                    PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                fi

                SubTitle="Copy .run installer"
                let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
                {
                    find  $ACR_Mnt -type f -iname "*.run"  -exec cp '{}' $WorkAcrSw/$InstallerDirInWitness/. \; 
                }&>/tmp/.acr.copy.$$.log
                if [ $? -eq 0 ]
                then
                    PrintMsg $ColorGood "OK"
                else
                    PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                fi

                SubTitle="Copy .html release note"
                let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
                {
                    find  $ACR_Mnt -type f -iname "*.html" -exec cp '{}' $WorkAcrSw/$InstallerDirInWitness/. \; 
                }&>/tmp/.acr.copy.$$.log
                if [ $? -eq 0 ]
                then
                    PrintMsg $ColorGood "OK"
                else
                    PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                fi

            fi

        fi

    # PrintMsg normal "\n\n==[ " && PrintMsg blue "Stage" &&  PrintMsg yellow "$StgNum" && PrintMsg normal " ]=========[\t" && PrintMsg red "\t$StgTitle" && PrintMsg normal "\t]==\n\n"

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function CheckLEN { # checks if it has some characters

    [ `echo $1 | wc -c` -gt 1 ] \
	    && return 0
    return 1
}

function Stage__Kickstarts {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Kickstart Builder ckecs" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle

    SubTitle="Check Template"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"


    TemplateNormalACR=$MyDir"/template/kickstart-acr.template"
    TemplatePostACR=$MyDir"/template/kickstart-post.template"
    if [ -f $TemplateNormalACR ] && [ -f $TemplatePostACR ]
    then
        if [ `grep -v ^# $TemplateNormalACR | grep ___ | wc -l` -gt 1 ]
    	then
            PrintMsg $ColorGood "OK"
    	else
            PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
            PrintMsg normal "\tNot usable template found as $TemplateNormalACR"
            return 51
        fi 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tNot found $TemplateNormalACR"
        return 52
    fi

    [ -d $WorkAcrKickstart ] || mkdir -p $WorkAcrKickstart 


    for Host in `ls -1 ${MyDir}/Host_Config*`
    do
        SubTitle="Read config "$Host
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

        ErCoBuildHost="0"
                    # || let ErCoBuildHost=$ErCoBuildHost+1 

        HostKeepCalls=`grep \:Keep_Calls $Host | cut -f2 -d \=`                  || let ErCoBuildHost=$ErCoBuildHost+1 
            CheckLEN $HostKeepCalls                                              || let ErCoBuildHost=$ErCoBuildHost+1 

       	HostFQDN=`grep \:Hostname $Host | cut -f2 -d \=`                         || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostFQDN                                                   || let ErCoBuildHost=$ErCoBuildHost+1
        
        WorkingKSOUT=$WorkAcrKickstart/"ks__"`echo $HostFQDN | sed -e 's/\./_/g'`"__.cfg" || let ErCoBuildHost=$ErCoBuildHost+1

    	if [ `echo $HostKeepCalls | egrep -i '(yes)' | egrep -vi '(no)' | wc -l` -gt 0 ]
    	then
            grep -vi clearpart $TemplateNormalACR > $WorkingKSOUT

    	elif [ `echo $HostKeepCalls | egrep -vi '(yes)' | egrep -i '(no)' | wc -l` -gt 0 ]
        then
            cat $TemplateNormalACR > $WorkingKSOUT                              || let ErCoBuildHost=$ErCoBuildHost+1
        fi
        
        sed -i 's/___HOSTNAME___/'$HostFQDN'/g' $WorkingKSOUT                   || let ErCoBuildHost=$ErCoBuildHost+1

        if [ $ErCoBuildHost -gt 0 ]
        then
             PrintMsg $ColorFail "FAIL"; let Issue=$Issue+1
        else
            PrintMsg $ColorGood "OK" 
        fi

    ###########################################################################################        

        ErCoBuildHost="0" ; Ctr="0"


        SubTitle="Fill Ks values "$Hosta ; let Stepper=$Stepper+1 
        printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

        HostKeyboard=`grep \:Keyboard $Host | cut -f2 -d \=`                    || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostKeyboard  || let ErCoBuildHost=$ErCoBuildHost+1       || let ErCoBuildHost=$ErCoBuildHost+1
                sed -i 's/___KEYBOARD___/'$HostKeyboard'/g' $WorkingKSOUT       || let ErCoBuildHost=$ErCoBuildHost+1

        HostNic=`grep \:NIC $Host | cut -f2 -d \=`                              || let ErCoBuildHost=$ErCoBuildHost+1
                CheckLEN $HostNic                                               || let ErCoBuildHost=$ErCoBuildHost+1
                sed -i 's/___NICDEV___/'$HostNic'/g' $WorkingKSOUT              || let ErCoBuildHost=$ErCoBuildHost+1

        HostIpAddress=`grep \:IP $Host | cut -f2 -d \=`                         || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostIpAddress                                             || let ErCoBuildHost=$ErCoBuildHost+1
            sed -i 's/___IPADDRESS___/'$HostIpAddress'/g' $WorkingKSOUT         || let ErCoBuildHost=$ErCoBuildHost+1

        HostNetmask=`grep \:Netmask $Host | cut -f2 -d \=`                      || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostNetmask || return $STG                                || let ErCoBuildHost=$ErCoBuildHost+1
            sed -i 's/___NETMASK___/'$HostNetmask'/g' $WorkingKSOUT             || let ErCoBuildHost=$ErCoBuildHost+1

        HostGateway=`grep \:Default_Route $Host | cut -f2 -d \=`                || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostGateway                                               || let ErCoBuildHost=$ErCoBuildHost+1
            sed -i 's/___GATEWAY___/'$HostGateway'/g' $WorkingKSOUT             || let ErCoBuildHost=$ErCoBuildHost+1

        HostNameServer=`grep \:DNS_Server $Host | cut -f2 -d \=`                || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostNameServer                                            || let ErCoBuildHost=$ErCoBuildHost+1
            sed -i 's/___NAMESERVER___/'$HostNameServer'/g' $WorkingKSOUT       || let ErCoBuildHost=$ErCoBuildHost+1

        HostTZ=`grep \:TimeZone $Host | cut -f2 -d \= | sed -e 's/\//\\\\\//g'` || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostTZ                                                    || let ErCoBuildHost=$ErCoBuildHost+1
            sed -i 's/___TIMEZONE___/'${HostTZ}'/g' $WorkingKSOUT               || let ErCoBuildHost=$ErCoBuildHost+1

        HostNTP=`grep \:NTP_Server $Host | cut -f2 -d \=`                       || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostNTP                                                   || let ErCoBuildHost=$ErCoBuildHost+1
    	    sed -i 's/___NTPSERVER___/'$HostNTP'/g' $WorkingKSOUT               || let ErCoBuildHost=$ErCoBuildHost+1

        HostCust=`grep \:Customer $Host | cut -f2 -d \= | sed -e 's/\ /\\\\\ /g'` || let ErCoBuildHost=$ErCoBuildHost+1
            CheckLEN $HostCust                                             || let ErCoBuildHost=$ErCoBuildHost+1
	        export $HostCust

        HostNumOfDisk=`grep \:NumberOfDisks $Host | cut -f2 -d \=`          || let ErCoBuildHost=$ErCoBuildHost+1
    	if [ `echo $HostNumOfDisk | egrep -i '(2|two)' | wc -l` -ge 1 ]
    	then
            HostDiskCount=2
        else # asume 1
            HostDiskCount=1
        fi


        if [ $ErCoBuildHost -gt 0 ]
        then
             PrintMsg $ColorFail "FAIL"; let Issue=$Issue+1
        else
            PrintMsg $ColorGood "OK" 
        fi
    ###########################################################################################        

        SubTitle="FS logic $Hosta" && ErCoBuildHost=0
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"


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

        CheckLEN $HostLineBoot     || let ErCoBuildHost=$ErCoBuildHost+1
        CheckLEN $HostLineRoot     || let ErCoBuildHost=$ErCoBuildHost+1
        CheckLEN $HostLineWitness  || let ErCoBuildHost=$ErCoBuildHost+1
        CheckLEN $HostLinePostgres || let ErCoBuildHost=$ErCoBuildHost+1
        CheckLEN $HostLineSwap     || let ErCoBuildHost=$ErCoBuildHost+1
        CheckLEN $HostLineCalls    || let ErCoBuildHost=$ErCoBuildHost+1


        if [ $ErCoBuildHost -gt 0 ]
        then
             PrintMsg $ColorFail "FAIL"; let Issue=$Issue+1
        else
            PrintMsg $ColorGood "OK" 
        fi

    ###########################################################################################        
        SubTitle="Write FS-config $Hosta" && ErCoBuildHost=0
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

    	    echo $HostLineBoot >> $WorkingKSOUT      || let ErCoBuildHost=$ErCoBuildHost+1
        	echo $HostLineRoot >> $WorkingKSOUT      || let ErCoBuildHost=$ErCoBuildHost+1
        	echo $HostLinePostgres >> $WorkingKSOUT  || let ErCoBuildHost=$ErCoBuildHost+1
         	echo $HostLineWitness >> $WorkingKSOUT   || let ErCoBuildHost=$ErCoBuildHost+1
    	    echo $HostLineSwap >> $WorkingKSOUT      || let ErCoBuildHost=$ErCoBuildHost+1
    	    echo $HostLineCalls >> $WorkingKSOUT     || let ErCoBuildHost=$ErCoBuildHost+1
            cat $TemplatePostACR >> $WorkingKSOUT    || let ErCoBuildHost=$ErCoBuildHost+1

        if [ $ErCoBuildHost -gt 0 ]
        then
             PrintMsg $ColorFail "FAIL"; let Issue=$Issue+1
        else
            PrintMsg $ColorGood "OK" 
        fi
    ###########################################################################################        

    done

# CRS_Layout

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum
}

function Stage__ISOLUNUX {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Boot menu isolinux" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle

###
#    if [ $? -eq 0 ]
#    then
#        PrintMsg $ColorGood "OK"
#    else
#        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
#    fi
####
#    PrintHead $StgNum "ended" $StgTitle
#    Check_Issue_Mode $Issue $StgNum
###


    TemplateISODefault=$MyDir"/template/isolinux-default.template"
    TemplateISOSingle=$MyDir"/template/isolinux-single.template"
    TemplateISOtoFinal=$MyDir"/template/isolinux-final.template"

    for File in $TemplateISODefault $TemplateISOSingle $TemplateISOtoFinal
    do
        Short=`echo $File | sed -e 's/\//\n/g' | tail -1` 2>/dev/null
        SubTitle="Template "$Short
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

        if [ -f $File ]
        then
            PrintMsg $ColorGood "OK"
        else
            PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
            return 81
        fi

    done


    SubTitle="Create ISO/"${IsoKSPath} 
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    [ -d ${WorkRHEL}/${IsoKSPath} ] || mkdir -p ${WorkRHEL}/${IsoKSPath} 
    if [ -d ${WorkRHEL}/${IsoKSPath} ]
    then
	    IsoKsDest=$WorkRHEL/$IsoKSPath
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
	    return 82
    fi


    Date=`date +%F`
    Text="acr-build"

    SubTitle="get var Title"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    IsoHostTitle=`echo $HostCust | sed -e 's/\ /_/g' | sed -e 's/\./_/g'`
    if [ `echo $IsoHostTitle | wc -c` -gt 2  ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
	    return 82
    fi

    IsoHdLabel=$IsoLabel                       # isolinux-default.template  ___HdLabel___           # IsoLabel

    IsoSubMenu="ACR_Kickstart"


    if [ `ls -1 $WorkAcrKickstart/ks__*.cfg | wc -l` -ge 1 ]
    then

        TemplateTMPISOCombo=/tmp/".isolinux_Combo_"`date +%F`"_"$$".tmp"

        cd $WorkAcrKickstart/

        for AcrKsFile in `ls -1 ks__*.cfg`
        do   
            SubTitle="kickstart "$AcrKsFile
            let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

    	    TestSingle=0
            #   IsoSingleLable  == { ___SingleLabel___ }  @  [ isolinux-single.template ]
	        #     #    Explain "sed" :      | change "." to "_"  | double "_" to one | rem leading "_"  | rem trailing "_" | rem leadingi  "ks_"
    	    IsoSingleLable=`echo $AcrKsFile | cut -f1 -d \.  | sed -e 's/__/_/g' | sed -e 's/^_//g' | sed -e 's/_$//g' | sed -e 's/^ks_//g'` 

            IsoSingleMenuText=$IsoSingleLable # isolinux-single.template   ___SingleMenuText___    # FQDN ?
            IsoSingleMenuHelpText="IpAddr__"`grep -v ^# $AcrKsFile | grep "ip=" | sed -e 's/\ /\n/g' | grep "ip=" | cut -f2 -d \= | sed -e 's/\./_/g'`
            IsoSingleMenuHdLabel=$IsoHdLabel # isolinux-single.template   ___HdLabel___           # IsoLabel
            IsoSingleFullPathKsFile=`echo '\\/'$IsoKSPath'\\/'$AcrKsFile`    # ="/kickstart" # isolinux-single.template   ___FullPathToKsCfg___   # /kickstart/
    	    IsoSingleHelpText="Install Now"
            TemplateTMPISOSingle="/tmp/.isolinux_Sngle_"$IsoSingleLable"_"`date +%F`"_"$$".tmp"
            cat $TemplateISOSingle > $TemplateTMPISOSingle || let TestSingle=$TestSingle+1
            cp -f $AcrKsFile $IsoKsDest/$AcrKsFile          || let TestSingle=$TestSingle+1

            #   ___FullPathToKsCfg___  $IsoSingleFullPathKsFile     isolinux-single.template 
            sed -i 's/___FullPathToKsCfg___/'$IsoSingleFullPathKsFile'/g' $TemplateTMPISOSingle || let TestSingle=$TestSingle+1

       	    #   ___SingleLabel___  $IsoSingleLable                  isolinux-single.template 
            sed -i 's/___SingleLabel___/'$IsoSingleLable'/g'              $TemplateTMPISOSingle || let TestSingle=$TestSingle+1
            sed -i 's/___SingleHelpText___/'$IsoSingleMenuHelpText'/g'              $TemplateTMPISOSingle || let TestSingle=$TestSingle+1
            sed -i 's/___SingleMenuText___/'$IsoSingleMenuText'/g'        $TemplateTMPISOSingle || let TestSingle=$TestSingle+1


            cat $TemplateTMPISOSingle >> $TemplateTMPISOCombo     # J1

    	    if [ $TestSingle -eq 0 ]
            then
                PrintMsg $ColorGood "OK"
            else
                PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        		return 65
            fi

	done
    fi

    # TemplateISOtoFinal=$MyDir"/template/isolinux-final.template"

    SubTitle="Build isolinux Boot Menu"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

    if [ -f $WorkRHEL/isolinux/isolinux.cfg ]
    then
        ErrCnt="0"
        TemplateTMPISODefault=/tmp/".isolinux_"`date +%F`"_"$$".tmp" || exit 992

        [ -f $TemplateISODefault  ] && cat $TemplateISODefault  >  $TemplateTMPISODefault || exit 94
        [ -f $TemplateTMPISOCombo ] && cat $TemplateTMPISOCombo >> $TemplateTMPISODefault || exit 95   
        [ -f $TemplateISOtoFinal  ] && cat $TemplateISOtoFinal  >> $TemplateTMPISODefault || exit 96  
            
	    if [ $? -ne 0 ]
        then
                PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
                return 87
        else
                PrintMsg $ColorGood "OK"
        fi

    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        return 87
    fi

    SubTitle="Replace variables"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

    ReplaceVar=0

    sed -i 's/___HdLabel___/'$IsoLabel'/g'   $TemplateTMPISODefault     || let ReplaceVar=$ReplaceVar+1
    sed -i 's/___Title___/'$IsoHostTitle'/g'   $TemplateTMPISODefault   || let ReplaceVar=$ReplaceVar+1
    sed -i 's/___SubMenu___/'$IsoHostTitle'/g'   $TemplateTMPISODefault || let ReplaceVar=$ReplaceVar+1
    sed -i 's/___Date___/'$Date'/g'   $TemplateTMPISODefault            || let ReplaceVar=$ReplaceVar+1

    if [ $ReplaceVar -ne 0 ]
    then
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        return 89
    else
        PrintMsg $ColorGood "OK"
    fi

    if [ $Confirm_Wait_Auto = "auto" ]
    then
        ConfIso="y"
    else
        PrintMsg normal "\n"
        PrintMsg blue "==========================================================================" ; PrintMsg normal "\n"
        cat $TemplateTMPISODefault 
        PrintMsg blue "==========================================================================" ; PrintMsg normal "\n"
        PrintMsg $ColorStage "\nAccept ? [y/n] "
        read ConfIso
        PrintMsg normal "\n"
    fi
    if [ $ConfIso = "y" ] || [ $ConfIso = "Y" ] 2>/dev/null
    then
    
        SubTitle="Check and inject isolinux"
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

        ISO_Issues="0"    
    #    PrintMsg green "\nConfirmed, writing ..." ; PrintMsg normal "\n"
        cp  ${WorkRHEL}/isolinux/isolinux.cfg /tmp/.isolinix.cfg.orig_`date +%F`_$$
	    cat $TemplateTMPISODefault > ${WorkRHEL}/isolinux/isolinux.cfg || let ISO_Issues=$ISO_Issues+1
        [ `cat ${WorkRHEL}/isolinux/isolinux.cfg | grep "___" | wc -l` -lt 1 ] || let ISO_Issues=$ISO_Issues+1
        [ `cat ${WorkRHEL}/isolinux/isolinux.cfg | wc -l` -lt 10 ] && let ISO_Issues=$ISO_Issues+1
        [ `cat ${WorkRHEL}/isolinux/isolinux.cfg | grep $IsoLabel | wc -l` -lt 1 ] && let ISO_Issues=$ISO_Issues+1

    elif [ $ConfIso = "n" ] || [ $ConfIso = "N" ] 2>/dev/null
    then
        PrintMsg green "\nNot writing to ISO, exit." ; PrintMsg normal "\n"
        exit 0
    fi
    if [ $ISO_Issues -gt 0 ]
    then
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        return 90
    else
        PrintMsg $ColorGood "OK"
    fi

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__ACRPatches {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="ACR Patches" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle
    PatchDirInWitness="patches"

    SubTitle="Collect acr-patched"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    [ -d $WorkAcrSw/$PatchDirInWitness ] || mkdir -p $WorkAcrSw/$PatchDirInWitness 
    [ -d $WorkAcrSw/$PatchDirInWitness ] && cp -r $WorkAcrPatch/* $WorkAcrSw/$PatchDirInWitness/.

    if [ $? -ne 0 ]
    then
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    else
        PrintMsg $ColorGood "OK"
    fi

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__ACRTools {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Bundle acr-tools github" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle
    
### ########################## check root permission ########################## 
    CurDir=`pwd -P`
    cd $WorkAcrTools 

    SubTitle="download"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
#    StgNum=$1 ; Issue="0" ; Stepper=0
#    StgTitle=" REPLACE " && echo ":"$StgNum":"$StgTitle >> $StageListFile
#    PrintHead $StgNum "start" $StgTitle
#    SubTitle=" REPLACE "
#    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
###
#    if [ $? -eq 0 ]
#    then
#        PrintMsg $ColorGood "OK"
#    else
#        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
#    fi
####
#    PrintHead $StgNum "ended" $StgTitle
#    Check_Issue_Mode $Issue $StgNum
###
	wget -O master.$$.zip $AcrTools_Url &>/dev/null
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    fi

    SubTitle="Unzip source"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
	unzip master.$$.zip &>/dev/null  
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
	    rm -f  master.$$.zip  &>/dev/null 
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    fi

    SubTitle="create archive"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
	tar -cvzf $WorkRHEL/acr-tools.tgz acr-tools-master  &>/dev/null
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    fi

    SubTitle="checksum"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
	cd $WorkRHEL/ \
	    && sha1sum acr-tools.tgz > acr-tools.tgz.`date +%F`.sha1sum.txt 
    if [ $? -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    fi

    cd $CurDir

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__Combiner {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Combine target build" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle
    
    PatchDirInWitness="patches"
    InstallerDirInWitness="install" 

    SubTitle="Add software and patches"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"

    CurDir=`pwd -P`
    IsoArchSoftware="acr-software.tgz"

   cd $WorkAcrSw
   if [ $? -eq 0 ]
   then
       ArchGood="1" # assume no
       {
           /bin/tar -cvzf $WorkRHEL/$IsoArchSoftware $PatchDirInWitness $InstallerDirInWitness
           ArchGood="0"

       }&>/tmp/.tar.comvine.$$.log

       if [ $ArchGood -eq 0 ]
       then
           cd $WorkRHEL/  &&  sha1sum $IsoArchSoftware > $IsoArchSoftware".sha1sum.txt" 

       	   if [ $? -eq 0 ]
           then
               PrintMsg $ColorGood "OK"
           else
               PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
	           return 87
           fi
       else 
           PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
	       return 89
       fi
   else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    	return 88
   fi
   cd $CurrDir

    SubTitle="Copy host config"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    cp $MyDir/Host_Config* $WorkRHEL/$IsoKSPath/.
    if [ $? -eq 0 ]
    then
               PrintMsg $ColorGood "OK"
    else
               PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
    fi
    
    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__GenISOImage {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Generate ISO" && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle
    
### ########################## check root permission ########################## 
    SubTitle="geniso"
    let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
    # PrintMsg $ColorGood "OK"
    # PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1

    cd $WorkRHEL

    if [ $Confirm_Wait_Auto = "auto" ] 
    then
        ConfGen="y" 
    else
        PrintMsg $ColorStage "\nGenerate ISO  ? [y/n] "
        read ConfGen # 
    fi

    [ $ConfGen = "y" ] || exit 22

        {
            [ -f $WorkMain/$IsoLabel.iso ] && rm -f $WorkMain/$IsoLabel.iso 

            time genisoimage -o $WorkMain/$IsoLabel.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
                -V $IsoLabel -boot-load-size 4 -boot-info-table -R -J -v -T ./ 
            
            ExCoGen=$?

        }&>/tmp/.geniso.$$.log

    if [ $ExCoGen -eq 0 ]
    then
        PrintMsg $ColorGood "OK"
    else
        PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        PrintMsg normal "\tcheck: /tmp/.geniso.&&.log"
        return 87
    fi

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function Stage__Cleanup {

    StgNum=$1 ; Issue="0" ; Stepper=0
    StgTitle="Cleanup"  && echo ":"$StgNum":"$StgTitle >> $StageListFile
    PrintHead $StgNum "start" $StgTitle

    for DirToClean in $WorkRHEL $WorkAcrSw $WorkAcrKickstart $WorkAcrTools     # $WorkAcrPatch 
    do
        Short=`echo $DirToClean | sed -e 's/\//\n/g' | tail -1` 2>/dev/null
        SubTitle="Clean "$Short
        let Stepper=$Stepper+1 ; printf '%s\n   %-3.3s | ' $color_blue  "$Stepper" ; printf '%s %-35.35s | '  $color_normal "$SubTitle"
        [ -d $DirToClean ] && rm -rf $DirToClean/* 2>/dev/null
        if [ $? -eq 0 ]
        then 
            PrintMsg $ColorGood "OK"
        else
            PrintMsg $ColorFail "FAIL" ; let Issue=$Issue+1
        fi
    done

    PrintHead $StgNum "ended" $StgTitle
    Check_Issue_Mode $Issue $StgNum

}

function ErrorStatus {

	if [ $1 -ne 0 ] 2>/dev/null
	then
	    echo "Error Exit "$ErrCode
	    exit 1
    else
        return 0
    fi
	echo " OOPSIE "; exit 999
}

function CleanDirs {

	PrintMsg blue "\n\nClean Directories:\n"
	PrintMsg normal "\n"

	AllClean="no"

    for DirToClean in $WorkRHEL $WorkAcrSw $WorkAcrKickstart $WorkAcrTools     # $WorkAcrPatch 
    do
        Short=`echo $DirToClean | sed -e 's/\//\n/g' | tail -1` 2>/dev/null
	    if [ $AllClean = "no" ]
	    then
    		    echo "Clean "$Short" ? (y)es, (n)o, (a)all ? "
         	    read CleanAnswer
	            [ $CleanAnswer = "a" ] 2>/dev/null && AllClean="yes"
	    fi

	    if [ $AllClean = "yes" ] || [ $CleanAnswer = "y" ] 2>/dev/null
	    then
		    rm -rf $DirToClean &>/dev/null
		    mkdir $DirToClean
		    echo "Cleaned : "$DirToClean
	    else
		    echo ; echo "No Action" ; echo
	    fi
    done
    return 0
}

function GetLastKnownName {

    StgQ=$1
    StgNameFile="/tmp/buil_stagelist.txt"
    StgName=""

    if [ -f $StgNameFile ]
    then
        [ `grep ^:$StgQ  $StgNameFile | wc -l` -ge 1 ] \
            && StgName=`grep ^:$StgQ $StgNameFile | tail -1 | cut -f3 -d \:` \
            && echo $StgName \
            && return 0
    fi
    echo $StgName
    return 1
}

function Question {

    LAST=$1

    ValidResponse=1
    LastStaga="00"
    if [ $# -gt 0 ] && [ `echo $LAST | wc -c` -gt 1 ]
    then
        LastName=`GetLastKnownName $LAST`
    fi

    while [ $ValidResponse -gt 0 ]
    do

	PrintMsg green  "\n\tMENU\n"
	PrintMsg red    "\t\t$0\n"
	PrintMsg normal "\n\tLast Stage "
	PrintMsg red    ">> "
	PrintMsg yellow "$LAST"
	PrintMsg red    " << "
	PrintMsg yellow " \"$LastName\" \n"
    PrintMsg normal "\n\t["
	PrintMsg yellow " R "
	PrintMsg normal "] run (default)"

	PrintMsg normal "\n\t["
	PrintMsg green  " E "
	PrintMsg normal "] exit"

	PrintMsg normal "\n\t["
	PrintMsg green  " C " 
	PrintMsg normal "] clean working dir"

	PrintMsg normal "\n\t["
	PrintMsg green  " S "
	PrintMsg normal "] specify stage"

	PrintMsg normal "\n\t["
	PrintMsg green  " N "
	PrintMsg normal "] next stage ("
	PrintMsg green "$NextStage"
	PrintMsg normal ")"

	PrintMsg yellow "\n\n\t? "
	unset $Option
	read Option
        [ `echo $Option | wc -c` -ne 2 ] && Option=r
	if [ `echo $Option | wc -c` -eq 2 ] 2>/dev/null
	then 
	     if [ `echo $Option | egrep -i '(r|e|c|s|n)' | wc -l` -gt 0 ] 2>/dev/null
	     then
                 ValidResponse=0

		 [ `echo $Option | grep -i "r" | wc -l` -gt 0 ] && return 0

		 [ `echo $Option | grep -i "e" | wc -l` -gt 0 ] && exit 0

	         [ `echo $Option | grep -i "c" | wc -l` -gt 0 ] && CleanDirs && let ValidResponse=$ValidResponse+1

		 [ `echo $Option | grep -i "s" | wc -l` -gt 0 ] && echo && echo "Enter stage:" && read StaNum && return $StaNum
#		 [ `echo $Option | grep -i "n" | wc -l` -gt 0 ] && echo "N"
	     else
                 let ValidResponse=$ValidResponse+1
	         PrintMsg red "\nER:\t$Option"
	         PrintMsg normal "\n"
	     fi
        fi
    done

}

function ListStageUpdate {

	if [ $# -ge 2 ]
	then
            StageNumber=$1
	    if [ $1 -lt 10 ]
            then

                StageLine=`echo ':0'$1':'$2`

            elif [ $1 -lt 100 ] || [ $1 -ge 10 ]
	    then

                StageLine=`echo ':'$1':'$2`

            else
                echo \#' ERROR '`date +%F_%H-%M-%S`' : '$1' : '$2' : '\# | tee -a $StageListFile
                return 2
            fi

            echo $StageLine >> $StageListFile 
            return 0
        else
            echo "ERR: ListStageUpdate requires 2 varables, not "$# 
        fi

}

############################################################

#  |////////////////|
#  |/|            |/|
#  |/|    MAIN    |/|
#  |/|            |/|
#  |////////////////|

# TEST
# TEST

DEBUG=false
#DEBUG="true"
export ErrCount="0"
export ErrNumCalls="0"

StageMin="00"
StageMax="12"
Sequence=`seq -w $StageMin 1 $StageMax`

LastSTG=`StageProcess_GetLastEnd`
Question $LastSTG
Start=$?

if [ $Start -le 12 ]
then
    Sequence=`seq -w $Now 1 $StageMax`
else
	echo "fukup "$Response" "$Sequence
	exit
fi

    if [ -f $StageTrackPrefix ] && [ `echo $Sequence | wc -c` -gt 1 ]
    then
	rm -f $StageTrackPrefix
    fi

    for STG in $Sequence
    do

    echo $STG > $StageTrackPrefix

    if [ $STG -eq 00 ] 
    then
        ListStageUpdate 0 "Pre-Menu"
        echo "00" > $StageTrackPrefix
    fi
    if [ $STG -eq 01 ] 
    then
        ListStageUpdate 1 "Pre-Checks"
        Stage__Pre-Checks $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 02 ]
    then
        ListStageUpdate 2 "Mount iso to mountpoint"
        Stage__Mount $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 03 ]
    then
        ListStageUpdate 3 "extract rhel"
        Stage__CopyIso $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 04 ]
    then
        ListStageUpdate 4 "acr-software"
        Stage__CopyACR $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 05 ]
    then
        ListStageUpdate 5 "kickstart file build"
        Stage__Kickstarts $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 06 ]
    then
        ListStageUpdate 6 "isolinux boot menu build"
	    Stage__ISOLUNUX $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 07 ]
    then
        ListStageUpdate 7 "acr-patches"
	    Stage__ACRPatches $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 08 ]
    then
        ListStageUpdate 8 "act-tools"
	    Stage__ACRTools $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 09 ]
    then
        ListStageUpdate 9 "Merge iso"
	    Stage__Combiner $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 10 ]
    then
        ListStageUpdate 10 "Generate ISO"
	    Stage__GenISOImage $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 11 ]
    then
        ListStageUpdate 11 "Post-Cleanup"
	    Stage__Cleanup $STG
        ErrorStatus $?
    fi
    if [ $STG -eq 12 ]
    then
        ListStageUpdate 12 "End"
	    echo $STS > $StageTrackPrefix
        PrintMsg yellow "\n\nCompleted ISO:"
        PrintMsg normal "\n\n\t"
        file $WorkMain/$IsoLabel".iso"
        PrintMsg normal "\n\t"
        du -h $WorkMain/$IsoLabel".iso"
        PrintMsg yellow "\n\n$WorkMain/$IsoLabel.iso"
        PrintMsg normal "\n"
        exit 0
    fi

    done

exit 0
