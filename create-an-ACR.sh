#!/bin/bash



#####   MAIN   #####

MyDir=`dirname $0`
MyTemplates=$MyDir"/template"
File_Kickstart_Defaults="create-an-ACR.variables.cfg"

Temp="/tmp/ks-details_"$$".tmp" && [ -f $Temp ] && rm -f $Temp
NewT="/tmp/ks-newTemp_"$$".tmp"     && [ -f $NewT ] && rm -f $NewT

CountMin="01"
Confirm="z"
IsThisTheFirst="yes"
PrefixNewKS="Host_Config_KS"

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
