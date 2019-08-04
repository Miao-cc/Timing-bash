#!/bin/bash

#################################################################
# ENV set
# Get input Cal Priod 1.00663296 , 0.201326592
#################################################################

##################################################################
## Default setting
##################################################################
rootPath=`pwd`
cpuNum=20
BinNum=256
FoldLen=20

##################################################################
## usage out put
#################################################################
show_usage="args: [ -psr -par -foldl -psrp -psrDM -cal1 -calp -cpus -nbins -psrzap -calzap -Calfile]
    -psr     psrfits name 
    -par     psr par file (tempo2)
    -foldl   pulsar fold time length (default 20 (sec))
    -psrp    if no par file, please gievn pulsar spin period  
    -psrDM   if no par file, please gievn pulsar spin DM
    -cal1    Calibrator file 1
    -calp    Calibrator Noise period
    -cpus    CPU numbers
    -nbins   bins in one period for pulsar
    -psrzap  pulsar zap file
    -calzap  cal zap file
    -Calfile file usged to calibrate pol (example: J0203-0150_20190725Cal1.txt)
"

if [ $# = 0 ];then
    echo "
${show_usage}
Please input filename, calname

Example:
  "
    exit
fi

##################################################################
## get input
#################################################################

while [ -n "$1" ]
do
        case "$1" in
            #For psr
                -psr|--psrFits) PulsarName=$2; shift 2;;    # pulsar fits file
                -par|--parFile) ParFile=$2; shift 2;;       # pulsar par file
                -foldl|--foldLen) FoldLen=$2; shift 2;;     # pulsar fold time length
                -psrp|--psrPeriod) psrPeriod=$2; shift 2;;  # pulsar period used to fold, P_topo
                -psrDM|--psrDM) psrDM=$2; shift 2;;         # pulsar DM used to fold
                -psrzap|--psrzap) psrzap=$2; shift 2;;      # pulsar zap file 
                -nbins|--binNums) BinNum=$2; shift 2;;      # pulsar fold bins
                -Calfile|--Calfile) Calfile=$2; shift 2;;   # txt file used to cal
            #For Cal
                -cal1|--cal1Fits) Cal1Name=$2; shift 2;;    # cal fits file
                -calzap|--calzap) calzap=$2; shift 2;;      # cal zap file
                -calp|--calPeriod) CalPeriod=$2; shift 2;;  # cal fold period
            #others
                -cpus|--cpuNum) cpuNum=$2; shift 2;;        # cpus numbers used 
                -plot|--plotpic) plot=$2; shift 2;;         # plot pics
                --) break ;;
                *) echo $1,$2,$show_usage; break ;;          
        esac
done



##################################################################
## Fold Cal
##################################################################
echo "Change to ${rootPath}"
cd ${rootPath}
if [ ${#Cal1Name} -gt 0 ] || [ ${#calzap} -gt 0 ];then
    if [ ${#Cal1Name} -gt 0 ];then
        echo "===== CAL FOLD====="
        CalFilePrefix=${Cal1Name%.*}
        echo "${CalFilePrefix}"
        # fold fits with dspsr in given period
        echo "Will fold ${Cal1Name} with period=${CalPeriod}, DM=0."
        dspsr -A -t ${cpuNum} -c ${CalPeriod} -O ${CalFilePrefix} -e rf ${Cal1Name}
        echo "Write to file ${CalFilePrefix}.rf"
        # Zap channels
        paz -r -L -e zap ${CalFilePrefix}.rf
        echo "Write to file ${CalFilePrefix}.zap"
        zapFile=${CalFilePrefix}.zap
    elif [ ${#calzap} -gt 0 ];then
        echo "===== PAM CAL ZAP FILE ====="
        zapFile=${calzap}
        CalFilePrefix=${calzap%.*}
    fi
    # sum time to one subint
    pam -T -e Tf4 ${zapFile}
    pam -e f4 ${zapFile}
    echo "Write to file ${CalFilePrefix}.Tf4"
    # correct the header
    psredit -c type='PolnCal',rcvr:name=19BEAM -e ucf ${CalFilePrefix}.Tf4
    mv ${CalFilePrefix}.ucf ucf.${CalFilePrefix}
    echo "Write to file ucf.${CalFilePrefix}"
    pac -u ${CalFilePrefix} -w -k ${CalFilePrefix}.txt
    echo "Write to file ${CalFilePrefix}.txt"
    # plot pics
    if [ ${#plot} -gt 0 ];then
        pacv -D ucf.${CalFilePrefix}.eps/CPS ucf.${CalFilePrefix}
        pav -dSFT ${zapFile} -g ${CalFilePrefix}-1.eps/CPS 
        pav -G ${zapFile} -g ${CalFilePrefix}-2.eps/CPS 
        #pav -dSFT ${CalFilePrefix}.zap -g ${CalFilePrefix}.zap-1.eps/CPS
        #pav -G ${CalFilePrefix}.zap -g ${CalFilePrefix}.zap-2.eps/CPS
    fi
fi

if [ ${#PulsarName} -gt 0 ] || [ ${#psrzap} -gt 0 ];then # fold file with given par file or period and DM
    if [ ${#PulsarName} -gt 0 ];then
        # fold with par file
        if [ ${#ParFile} -gt 0 ];then
           PsrFilePrefix=${PulsarName%.*}
           echo "===== PSR FOLD WITH PAR FILE ====="
           echo "Will fold ${PulsarName} with ${ParFile}"
           dspsr -A -b ${BinNum} -t ${cpuNum} -L ${FoldLen} -E ${ParFile} -O ${PsrFilePrefix} -e rf ${PulsarName}
           # zap channels
           paz -r -L -e zap ${PsrFilePrefix}.rf
           echo "Write to file ${PsrFilePrefix}.zap"
           zapFile=${PsrFilePrefix}.zap
        # fold with period, DM
        elif [ ${#psrPeriod} -gt 0 ];then
           echo "===== PSR FOLD WITH PERIOD AND DM ====="
            PsrFilePrefix=${PulsarName%.*}
            echo "Will fold ${PulsarName} with period=${psrPeriod}, DM=${psrDM}"
            dspsr -A -b ${BinNum} -t ${cpuNum} -L ${FoldLen} -c ${psrPeriod} -D ${psrDM} -O ${PsrFilePrefix} -e rf ${PulsarName}
            # zap channels
            paz -r -L -e zap ${PsrFilePrefix}.rf
            echo "Write to file ${PsrFilePrefix}.zap"
            zapFile=${PsrFilePrefix}.zap
        fi
    elif [ ${#psrzap} -gt 0 ];then
        # pam with zap file
           echo "===== PAM PSR ZAP FILE ====="
           echo "Get input ${psrzap}"
           PsrFilePrefix=${psrzap%.*}
           zapFile=${psrzap}
        #elif [ ${#psrPeriod} = 0 ];then
    fi
    # sum in file to on subint
    pam -e Tf4 ${zapFile}
    echo "Write to file ${PsrFilePrefix}.Tf4"
    # correct the header
    psredit -c rcvr:name=19BEAM -e feed ${PsrFilePrefix}.Tf4
    echo "Write to file ${PsrFilePrefix}.feed"
    # Polarization calibration
    pac -d ${Calfile} -c -Z -U ${PsrFilePrefix}.feed
    echo "Write to file ${PsrFilePrefix}.calibP"
    # sum freq to 32 channels
    pam -f 32 -e pf32 ${PsrFilePrefix}.calibP
    echo "Write to file ${PsrFilePrefix}.pf32"
    # add all pol and freq
    pam -pF -e pF ${PsrFilePrefix}.calibP
    pam -pTF -e pTF ${PsrFilePrefix}.calibP
    echo "Write to file ${PsrFilePrefix}.pTF, ${PsrFilePrefix}.pF"
    # plot pics
    if [ ${#plot} -gt 0 ];then
        pav -dSFT ${zapFile} -g ${zapFile}-1.eps/CPS 
        pav -G ${zapFile} -g ${zapFile}-2.eps/CPS 
    fi
fi

#pat -f "tempo2" -s pTF.std ${PsrFilePrefix}.pF > ${PsrFilePrefix}.tim
