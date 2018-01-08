#!/bin/bash

#  |////////////////////////////////////
#  ||
#  ||
#  ||
#  ||
#  |\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\


MyDir=`dirname $0`    # Where ami I?
cd $MyDir             # Here I am ...

#  |--------------------------------------
#  |      ==>   VARIABLES   <== 
#  |--------------------------------------
 
MyTemplates=$MyDir"/template"
File_Kickstart_Defaults="create-an-ACR.variables.cfg"

Temp="/tmp/ks-details_"$$".tmp" && [ -f $Temp ] && rm -f $Temp
NewT="/tmp/ks-newTemp_"$$".tmp"     && [ -f $NewT ] && rm -f $NewT

CountMin="01"
Confirm="z"
IsThisTheFirst="yes"
PrefixNewKS="Host_Config_KS"

#  Some pretty colours
#
      color_red=$'\033[31;1m'
    color_green=$'\033[32;1m'
   color_yellow=$'\033[33;1m'
     color_blue=$'\033[34;1m'
   color_normal=$'\033[0m'

###############################################
#
#   ||====================================
#   ||
#   ||      ==>   FUNCTIONS   <== 
#   ||
#   ||------------------------------------
#

function PrintMsg {      # Use the pretty colours

#  USAGE:
#          PrintMsg yellow "Look I'm Yellow!"

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

##########################################################
##
##           MAIN
##
##########################################################

PrintMsg yellow "\nINFO\n\n\t$0"
PrintMsg red    "\tCollect a single ACR host's Kickstart configuration, to build the ISO\n"
PrintMsg normal "\n\t1st run will offer the minimum config to enter."
PrintMsg normal "\n\t2nd will offer all the more detailed, and assumed configuration."
PrintMsg normal "\n\t... repeated thereafter, or until you ACCEPT\n"
PrintMsg yellow "\n---------------------------------------------------------------------------"
PrintMsg normal "\n"

if [ -f $MyTemplates/$File_Kickstart_Defaults ]
then

    CountMax=`grep -v ^# $MyTemplates/$File_Kickstart_Defaults | grep \= | wc -l`
    grep -v ^# $MyTemplates/$File_Kickstart_Defaults | sort -n  > $Temp

    while [ `echo $Confirm | grep -i "y" | wc -l` -lt 1 ] 2>/dev/null
    do
	
	if [ $IsThisTheFirst = "yes" ] && [ `find $MyDir -maxdepth 2 -type f -ctime +1 -iname "Host_Config_KS*.cfg" | wc -l` -gt 0 ]
	then
            printf "\nFound older kickstart files:\n\n"
            find $MyDir -maxdepth 2 -type f -ctime +1 -name "Host_Config_KS*.cfg" | sed -e 's/^/\t/g'
            printf "\nRemove [y/n] ? "
	    read ConfRemove
            [ $ConfRemove = "y" ] && find $MyDir -maxdepth 2 -type f -ctime +1 -name "Host_Config_KS*.cfg" -exec /bin/rm -i '{}' \; 
	fi

	for Counter in `seq -w $CountMin 1 $CountMax`
	do
            VarLine=`grep ^$Counter $Temp`
            VarPriority=`echo $VarLine | cut -f1 -d \:`
            VarKey=`echo $VarLine | cut -f1 -d \= | cut -f2 -d \:`
            VarDefault=`echo $VarLine | cut -f2 -d \=`
            VarText=`echo $VarLine | cut -f3 -d \=`
		
            if [ `echo $VarPriority | grep "_" | wc -l` -eq 1 ] && [ $IsThisTheFirst = "yes" ]
	    then
                NewVal=$VarDefault
            else
                printf "\n$VarKey\t\"$VarText\" [$VarDefault] : "
                read NewCurrent
                if [ `echo $NewCurrent | wc -c` -gt 1 ] 2>/dev/null
                then
                    NewVal=$NewCurrent
                else
                    NewVal=$VarDefault
                fi
            fi

            printf "$Counter:$VarKey=$NewVal=$VarText\n" >> $NewT

	done

        IsThisTheFirst="no"

	printf "\n\nConfirm:\n\n"
	cat $NewT | cut -c4-999 | sed -e 's/^/\t/g' | sed -e 's/\=/\ \ \ /g' 
	printf "\n\nAccept [y/n] ? "
	read Confirm

	mv $NewT $Temp
        	
    done

    mv -f $Temp $MyDir/Host_Config_KS_`date +%F`_`grep -i hostname $Temp | cut -f 4-999 | cut -f2 -d \=`.cfg
    [ -f $Temp ] && rm -f $Temp 2>/dev/null
    exit 0

else
	echo  $MyDir/$File_Kickstart_Defaults" not found."
	exit 1
fi
