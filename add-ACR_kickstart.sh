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
clear
PrintMsg yellow "\n\nACR KICKSTART INFO COLLECTOR\t[" ; PrintMsg normal " $0 " ; PrintMsg yellow "] \n"
    PrintMsg normal "\n *  Collect a single ACR host's Kickstart configuration.\n"
    PrintMsg normal "\n *  Serves as the primary input for the build-ISO-Tool.sh\n"

PrintMsg red "\n\n\n\t The key values, then more, if needed:"
PrintMsg normal "\n\t---------------------------------------"
    PrintMsg yellow  "\n\t 1st run "; PrintMsg normal " Minimal config, usually differs between hosts and installs." 
    PrintMsg yellow  "\n\t 2nd run "; PrintMsg normal " All configuration, including 1st run. Minimal usually serves the need."

PrintMsg red "\n\n\n\t Useful Tips:"
PrintMsg normal "\n\t--------------"
    PrintMsg yellow "\n\t defaults "; PrintMsg normal "When adding many similar hosts, change the defautls file first."
        PrintMsg normal "\n\t          Defaults here: "; PrintMsg blue "$File_Kickstart_Defaults\n"
    PrintMsg green "\n\t input "; PrintMsg normal "Limitation on input: "; PrintMsg red "NO" 
        PrintMsg normal " spces (\" \") !\n\t       Use unserscore (\"_\") if you have too."

PrintMsg normal   "\n\n\n\t#  github \""; PrintMsg blue "https://github.com/johanr89/acr-build" ; PrintMsg normal "\" "
PrintMsg normal   "\n\t#  Open source, use at your own risk. This has no software or OS vendor, no guarentees."

PrintMsg normal "\n\n\nPress ["
PrintMsg yellow "Enter"
PrintMsg normal "] to start.";read

##########################################################


if [ -f $MyTemplates/$File_Kickstart_Defaults ]
then


    CountMax=`grep -v ^# $MyTemplates/$File_Kickstart_Defaults | grep \= | wc -l`
    grep -v ^# $MyTemplates/$File_Kickstart_Defaults | sort -n  > $Temp

    while [ `echo $Confirm | grep -i "y" | wc -l` -lt 1 ] 2>/dev/null
    do
        clear
        PrintMsg normal "\n"

        if [ $IsThisTheFirst = "yes" ]
        then
            PrintMsg normal "run [" ; PrintMsg yellow " 1st essential only " ; PrintMsg normal "] \n"
        else
            PrintMsg normal "run [" ; PrintMsg yellow " Now all config values  " j PrintMsg normal "] \n"
        fi
	
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
                PrintMsg normal "\n\"$VarKey\"\t"
                PrintMsg green    "["
                PrintMsg normal  "$VarDefault"
                PrintMsg green    "]"
                PrintMsg normal  "\t\tNote \"$VarText\""
                PrintMsg normal "\nType a new value, "
                PrintMsg green  "Enter"
                PrintMsg normal " to accept : "
                  
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

    	PrintMsg red "\n\nPlease check and confirm:\n\n"
    
        Lcol="normal" ; Ccol="blue" ; Rcol="normal"
        while read Line
        do
            PrintMsg $Lcol "\t`echo $Line | cut -c4-999 | cut -f1 -d \=`"
            [ `echo $Line | cut -c4-999 | cut -f1 -d \= | wc -c` -le 8 ] && PrintMsg $Ccol "\t"
            PrintMsg $Ccol "\t=\t["
            PrintMsg $Rcol "`echo $Line | cut -c4-999 | cut -f2 -d \=`"
            PrintMsg $Ccol "]"
            PrintMsg normal "\n"

        done<$NewT

    	PrintMsg red "\nAccept ?" ; PrintMsg yellow " [y/n] "

    	read Confirm

        PrintMsg normal "\n"
        IsThisTheFirst="no"
        mv $NewT $Temp
        	
    done

    FileName="$MyDir/Host_Config_KS_"`date +%F`"_"`grep -i hostname $Temp | cut -f 4-999 | cut -f2 -d \=`".cfg"
    mv -f $Temp $FileName
    [ -f $Temp ] && rm -f $Temp 2>/dev/null
	PrintMsg yellow "\n\nNew ACR host saved as:\n"
	PrintMsg normal "\n\t $FileName \n\n"
    exit 0

else
	echo  $MyDir/$File_Kickstart_Defaults" not found."
	exit 1
fi
