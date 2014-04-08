#!/bin/bash
# dudmp6 by ZWA
# v1.0 09/13/2012
# As a response file can not be used for other versions of kits,
# for a newer version of V6 installation
# 1. generate a new response template file
# 2. Or autopatch after install
# v1.1 09/17/2012
# Randomize $U TCP port to allow multiple dump installation. 
# v1.3 To allow dump with non-standard directory structure
# To allow local template, response file.
# One can specify a different installation directory in the local template    
# Changing to KSH to adapt to different OS.
# create v6_kit link in "/" 
# v1.4 minor fix
# v1.5 do not dump the u_sync.dta
#set -x -v
node_=$1
company_=$2
if [ ${company_:-NONE} = NONE ] ; then 
	echo Please specify the node name and company name
	echo For example, dudmp6 node1 FLS600
	exit 1
fi
in_use="yes" # finding a set of empty ports
while [[ $in_use = "yes" ]] ; do 
	port_=$(($(($(($((RANDOM%=90000000))%1000))*10))+10000))
	echo port_ is $port_ 
	netstat -an|grep $port_
	if [ $? = 0 ] ; then 
		in_use="yes"
		echo ### $port_ is in use
	else
		in_use="no"
		echo ### $port_ is not in use
	fi
done 
local_dir_=`pwd`
if [ -r /home/zwa/home/pj31_dudmp_v6/template.install.file ] ; then 
	templ_resp_=/home/zwa/home/pj31_dudmp_v6/template.install.file
	response_=/apps/du/600/current.install.file
else 
	templ_resp_=$local_dir_/template.install.file
	response_=$local_dir_/current.install.file
fi
#v6_kit is a link in /apps/du/600 to the V6 kit that matches the template response file.
#/apps/du/600/v6_kit/unirun -i -s -f /apps/du/600/work.install.file

# Hard coded in response file
# UVMS info 
# $U port : 12000
# NODE : NODE_DUMP 
# COMPANY : FLS600
# $U admin : univa
# INSTALLDIR : must be in /apps/du/600/FLS600_NODE_DUMP
sed "s/FLS600/$company_/" $templ_resp_|sed "s/NODE_DUMP/$node_/"|sed "s/FLS600_NODE_DUMP/${company_}_$node_/"|sed "s/12000/$port_/"> $response_
#/apps/du/600/v6_kit/unirun -i -s -f $response_
if [ -r /home/zwa/home/pj31_dudmp_v6/template.install.file ] ; then 
	/apps/du/600/v6_kit/unirun -i -s -f $response_
else 
	/v6_kit/unirun -i -s -f $response_  #For non-standard structure create /v6_kit link in "/" 
fi

if [ $? -ne 0 ] ; then 
	echo '### Installation failed'
	exit 1
else 
	echo '### Installation finished'
fi
. /apps/du/600/${company_}_$node_/unienv.ksh
# Turn off engines 
echo "### Turn off engines" 
${UNI_DIR_EXEC}/unisetvar UNI_STARTUP_X IO,CDJ,BVS,DQM,EEP,SYN,ALM
${UNI_DIR_EXEC}/unisetvar UNI_STARTUP_S IO,CDJ,BVS,SYN,ALM
${UNI_DIR_EXEC}/unisetvar UNI_STARTUP_I IO,CDJ,BVS,SYN,ALM
${UNI_DIR_EXEC}/unisetvar UNI_STARTUP_A IO,CDJ,BVS,SYN,ALM
${UNI_DIR_EXEC}/unisetvar U_IO_PURGE_ENABLE N
${UNI_DIR_EXEC}/unisetvar  X_O_DYN_PURGE N
${UNI_DIR_EXEC}/unisetvar  S_O_DYN_PURGE N
${UNI_DIR_EXEC}/unisetvar  I_O_DYN_PURGE N
${UNI_DIR_EXEC}/unisetvar  A_O_DYN_PURGE N
${UNI_DIR_EXEC}/unistop 
if [ $? -ne 0 ] ; then 
	echo '###$U failed to stop'
	exit 1
fi
# Then load customer's data files  '
echo "Please select concerned area, A,I,S or [X]"
read area_ 
case $area_ in
	A|a|app)
	area_data_=`$UNI_DIR_EXEC/unigetvar UXDAP`
	area_3=app
	area_d=UXDAP
	;;
	I|i|int)
	area_data_=`$UNI_DIR_EXEC/unigetvar UXDIN`
	area_3=int
	area_d=UXDIN
	;;
	S|s|sim)
	area_data_=`$UNI_DIR_EXEC/unigetvar UXDSI`
	area_3=sim
	area_d=UXDSI
	;;
	X|x|exp)
	area_data_=`$UNI_DIR_EXEC/unigetvar UXDEX`
	area_3=exp
	area_d=UXDEX
	;;
	*)
	echo Default would be X 
	area_data_=`$UNI_DIR_EXEC/unigetvar UXDEX`
	area_3=exp
	area_d=UXDEX
esac
bass_data_=`$UNI_DIR_EXEC/unigetvar UNI_DIR_DATA`
# now should be in the DUFILES directory
cd DATA
mv u_sync.dta u_sync.dta_not_to_dump
cp -f *.dta $bass_data_
cp -f */*.dta $bass_data_
mv u_sync/u_sync.dta u_sync/u_sync.dta_not_to_dump
cp -f *.idx $bass_data_
cp -f */*.idx $bass_data_
chown univa:univ $bass_data_
cd ../$area_d
cp -f *.dta $area_data_
cp -f */*.dta $area_data_
cp -f *.idx $area_data_
cp -f */*.idx $area_data_
chown univa:univ $area_data_
#read nothing
echo "Do you want to run reorg? Answer [y]/n"
read answer_
if [ ${answer_:-y} = y ] ; then
	${UNI_DIR_EXEC}/unireorg
fi
# Restarting $U
echo "### Starting $U"
${UNI_DIR_EXEC}/unistart
if [ $? -ne 0 ] ; then 
	echo '###$U failed to start'
	exit 1
fi
echo "### do you want to generate the listings [y]/n"
read answer_
if [ ${answer_:-y} = y ] ; then
	${UNI_DIR_EXEC}/uxlst ctl full $area_3 >../../LST/dump_uxlst_ctl_full.txt &
	${UNI_DIR_EXEC}/uxlst fla full $area_3 >../../LST/dump_uxlst_fla_full.txt &
	${UNI_DIR_EXEC}/uxlst ctl hst $area_3 >../../LST/dump_uxlst_ctl_hst.txt & 
	${UNI_DIR_EXEC}/uxlst evt full $area_3 >../../LST/dump_uxlst_evt_full.txt &
fi
