#!/bin/bash
#
# Installation script for Open64 SDK version 1.0
#

PROGRAM=`basename ${0}`
DIRNAME=`dirname $PROGRAM`
if [ "x${DIRNAME}" == "x." ]; then
	TOPDIR=`pwd`
else
	TOPDIR=$DIRNAME
fi

OPEN64_TOOLCHAIN=$TOPDIR/open64/binaries/x86_open64-4.2.4-1.x86_64.tar.bz2
CODE_ANALYST_PKG="EMPTY"
CODE_ANALYST_SOURCE_PKG=$TOPDIR/CA/SOURCES/codeanalyst-2.9.18.tar.gz
ACML_LIBRARY=$TOPDIR/acml/binaries/acml-4-4-0-open64-64bit.tgz
ACMLGPU_LIBRARY=$TOPDIR/acml_gpu/binaries/acmlgpu-1-1-1-gfortran-64bit.tgz
AMD_LIBM_LIBRARY=$TOPDIR/amdlibm/binaries/amdlibm-2-1-lin64.tgz
DOCUMENTATION=$TOPDIR/pdf/
AMDSDK_README=$TOPDIR/ReadMe.txt
AMDSDK_HELPTEXT=$TOPDIR/sdkhelp.txt
AMDSDK_VERSIONTEXT=$TOPDIR/version

REMOVE_CMD="/bin/rm -fr"
CLEAR_SCREEN="/usr/bin/clear"
COPY_FILE="/bin/cp"
WHOLE_SDK=7
tried_once=0
INSTALL_STATUS=0
gotsignal=0
bold=`tput smso`
offbold=`tput rmso`
last_command=

waiting_ind=

function output_error
{
	error_str="${1}"
	echo "    ${bold}ERROR:${offbold} ${error_str}"
}

function clean_tmpdir
{
	if [ -d ${TMPDIR} ]; then
		stop_waiting_dots
		if [ ${INSTALL_STATUS} -eq 1 ]; then
			sleep 1
		fi
		for i in `ls ${TMPDIR}`
		do
			${REMOVE_CMD} ${i}
		done
	fi
}

function stop_waiting_dots
{
	if [ "x${waiting_ind}" != "x" ]; then
		touch ${waiting_ind}
	fi
}

function show_waiting_dots
{
	echo -n "    install in progress. Please wait "
	while(true)
	do
		if [ ! -f ${waiting_ind} ]; then
			echo -n "."
			sleep 1
		else
			${REMOVE_CMD} ${waiting_ind}
			return
		fi
	done
}

function toContinue
{
	if [ $OPTION -ne $WHOLE_SDK ]; then
		echo
		echo -e "    ${bold}Hit Enter to continue with installation${offbold}"
		read enter
	fi
}

function on_die()
{
	gotsignal=1
	reply=""
	echo
	while [ "${reply}" != "y" -a "${reply}" != "n" ]; do
		echo -e "    Do you really want to quit the installation [y/N]? : \c"
		read reply
		reply=`echo ${reply} | tr [:upper:] [:lower:]`
	done
	if [ "$reply" == "y" ]; then
		clean_tmpdir
		if [ "x${last_command}" == "x" ]; then
			echo "    Installation was interrupted, please try re-installing again."
		fi
		echo "    Goodbye!"
		exit 0
	fi
	#echo "    ${bold}Hit Enter${offbold}"
	if [ "x${last_command}" != "x" ]; then
		echo -e "    ${last_command} \c"
	else
		echo "    Installation was interrupted, please try to install the product again."
	fi
	install_sighandler
}

# Execute function on_die() receiving TERM signal
function install_sighandler()
{
	gotsignal=0
	trap 'on_die' SIGTERM
	trap 'on_die' SIGINT
	trap 'on_die' SIGHUP
}

function select_installation_path
{
	newpath=$INSTALL_PATH
	while(true); do
	if [ ${tried_once} -eq 0 ]; then
		echo "    Default installation path is set [$INSTALL_PATH]"
		echo "    To select a different location, please enter it at the prompt."
		echo -e "    ${bold}>>${offbold} \c"
		read install_loc
		if [ "x${install_loc}" != "x" ]; then
			newpath=$install_loc/v${SDK_VERSION}
		else
			newpath=$INSTALL_PATH
		fi
		mkdir -p $newpath 2> /tmp/install_path.$$.error
		sys_status=$?
		if [ $sys_status != 0 ]; then
			if [ -f  /tmp/install_path.$$.error ]; then
				echo
				output_error "    -`cat /tmp/install_path.$$.error`"
				${REMOVE_CMD} /tmp/install_path.$$.error
			fi
			if [ ${OPTION} -eq $WHOLE_SDK ]; then
				output_error "    Installation requires administrative (root) privileges."
				echo
				exit
			fi
		fi
		if [ ${OPTION} -eq $WHOLE_SDK ]; then
			tried_once=1
		fi
	fi
	if [ -d ${newpath} -a -w ${newpath} ]; then
		cd $INSTALL_PATH
		sys_status=$?
		if [ $sys_status != 0 ]; then
			output_error "Something is wrong with install path. Exiting."
			exit
		fi
		INSTALL_PATH=$newpath
		return
	fi
	done
}

function showLicense()
{
	sleep 2

	lic_txt="$1"
	echo
	more $lic_txt
	reply=""
	echo
	while [ "${reply}" != "accept" -a "${reply}" != "decline" ]; do
		echo -e "[accept/decline]? : \c"
		read reply
		reply=`echo ${reply} | tr [:upper:] [:lower:]`
	done
}

function install_open64_toolchain
{
	echo
	if [ $MAIN_OPTION -eq 2 ]; then
		installation_path=$INSTALL_PATH/x86_open64-4.2.4
		echo    "    Un-installing Open64 compiler toolchain"
		echo -n "      - Removing $installation_path."
		${REMOVE_CMD} $installation_path
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo "    [${bold}FAILED${offbold}]"
			return
		fi
		echo "    [${bold}OK${offbold}]"
	else
		echo "    Open64 compiler Installation (v4.2.4)"
		echo "    ====================================="
		OPEN64_EU_LICENSE=$TOPDIR/open64/AMD-x86-open64-EULA.txt
		showLicense ${OPEN64_EU_LICENSE}
		if [ "${reply}" != "accept" ]; then
			output_error "Installation declined. Skipping."
			return
		fi
		select_installation_path
		show_waiting_dots &
		cd $INSTALL_PATH
		tar jxf $OPEN64_TOOLCHAIN 
		sys_status=$?
		stop_waiting_dots
		if [ $sys_status != 0 ]; then
			output_error "Something went wrong while installing open64 toolchain. Please re-install."
			clean_tmpdir
			return
		fi
		INSTALL_STATUS=1
	    echo "    [${bold}OK${offbold}]"
		echo "    Please update your path to include $INSTALL_PATH/x86_open64-4.2.4/bin before using the compiler."
		toContinue
	fi
}

function install_ca_from_binary_pkg
{
	if [ $OPTION -eq $WHOLE_SDK ]; then
		x=`uname -a |grep x86_64`
		if [ "x${x}" != "x" ]; then
	 	#Select a 64bit package to install
			x=`which dpkg`
			if [ "x${x}" != "x" ]; then
				default_pkg="codeanalyst-2.9.18-2-Ubuntu910-64bit.deb"
			else
				default_pkg="codeanalyst-2.9.18-303-RHEL5U4-64bit.rpm"
			fi
		else
			x=`which dpkg`
			if [ "x${x}" != "x" ]; then
				default_pkg="codeanalyst-2.9.18-2-Ubuntu910-32bit.deb"
			else
				default_pkg="codeanalyst-2.9.18-303-RHEL5U4-32bit.rpm"
			fi
		fi
		echo "    With autoinstall setup, will be installing ${default_pkg}"
		CA_BINARY_PKG=$default_pkg
	else
		echo "    Following binary packages are available, please select appropriate one for your system."
		j=0
		echo
		oldwd=`pwd`
		cd ${TOPDIR}/CA/binaries
		x=`uname -a |grep i386`
		if [ "x${x}" != "x" ] ;then
			for i in `ls codeanalyst*32bit*`
			do
				echo "    $i"
				j=`expr $j + 1`
			done
		else
			for i in `ls codeanalyst*64bit*`
			do
				echo "    $i"
				j=`expr $j + 1`
			done
		fi
		echo -e "    Select a pkg. to install.: \c"
		read CA_BINARY_PKG
		cd $oldwd
	fi 

	if [ -f ${TOPDIR}/CA/binaries/${CA_BINARY_PKG} ]; then
		x=`file ${TOPDIR}/CA/binaries/${CA_BINARY_PKG} |grep RPM`
		if [ "x${x}" != "x" ]; then
			if [ $EUID -eq 0 ]; then
				rpm -ih ${TOPDIR}/CA/binaries/${CA_BINARY_PKG}
			else 
				sudo rpm -ih ${TOPDIR}/CA/binaries/${CA_BINARY_PKG}
			fi
		else
			x=`file ${TOPDIR}/CA/binaries/${CA_BINARY_PKG} |grep Debian`
			if [ "x${x}" != "x" ]; then
				echo "    It's a Debian package"
				echo "    Will be using dpkg tool to install CodeAnalyst"

				x=`which dpkg`
				if [ "x${x}" != "x" ]; then
					if [ $EUID -eq 0 ]; then
						dpkg -i ${TOPDIR}/CA/binaries/${CA_BINARY_PKG}
					else
						sudo dpkg -i ${TOPDIR}/CA/binaries/${CA_BINARY_PKG}
					fi
				else
					output_error "   Cannot install ${CA_BINARY_PKG}. No dpkg program."
					return
				fi
			else
					output_error "   Invalid package name."
					return
			fi
		fi

		sys_status=$?
		if [ $sys_status != 0 ]; then
			output_error "Installation of Code Analyst failed"
			output_error "Please resolve issue(s) involved and try again, or"
			output_error "Send us a detail email codeanalyst.support@amd.com"
			return
		fi
	else
		echo "    Invalid pkg name/package doesn't exists"
		INSTALL_STATUS=0
		return
	fi
	INSTALL_STATUS=1
	installation_path=$INSTALL_PATH/ca
	if [  ! -d $installation_path ]; then
		mkdir $installation_path
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo
			output_error "   mkdir failed while installing Code Analyst" 
			return
		fi
	fi

	cp ${CA_EU_LICENSE} ${INSTALL_PATH}/ca/
	echo "    [${bold}OK${offbold}]"
	toContinue
}

function remove_rpm_pkg 
{
	x=`which rpm 2> /dev/null`
	if [ "x${x}" == "x" ]; then
		return
	fi
	pkgs=`rpm -qa |grep -i codeanalyst`
	echo
	echo "    Found following Code Analyst package(s)."
	for i in `echo $pkgs`
	do
		echo "    $i"
	done
	echo
	while (true); do
		echo -e "    Select a package to uninstall: \c"
		read pkgname
		if [ "x${pkgname}" != "x" ]; then
			break
		fi
	done
	rpm -e ${pkgname}
	return $?

}

function remove_debian_pkg
{
	x=`which dpkg 2> /dev/null`
	if [ "x${x}" == "x" ]; then
		return
	fi
	#pkgs=`dpkg -l |grep -i codeanalyst`
	pkgs=`dpkg -s codeanalyst|grep ^Package | cut -d' ' -f2`
	echo
	echo "    Found following Code Analyst package(s)."
	for i in `echo $pkgs`
	do
		echo "    $i"
	done
	echo
	while (true); do
		echo -e "    Select a Code Analyst package to uninstall: \c"
		read pkgname
		if [ "x${pkgname}" != "x" ]; then
			break
		fi
	done
	dpkg -r ${pkgname}
	return $?

}

function install_code_analyst
{
	echo
	if [ $MAIN_OPTION -eq 2 ]; then
		echo "    Uninstallation of Code Analyst tool"

		#check if rpm pkg installed
		x=`which rpm 2> /dev/null`
		if [ "x${x}" != "x" ]; then
			x=`rpm -qa |grep -i codeanalyst`
			if [ "x${x}" != "x" ]; then
				remove_rpm_pkg
				sys_status=$?
			fi
		else
			x=`which dpkg 2> /dev/null`
			if [ "x${x}" == "x" ]; then
				return
			fi

			#check if debian pkg installed
			x=`dpkg -s codeanalyst|grep ^Package | cut -d' ' -f2`
			if [ "x${x}" != "x" ]; then
				remove_debian_pkg
				sys_status=$?
			else
				echo
				output_error "    No CodeAnalyst installation found."
				return
			fi
		fi
		if [ $sys_status != 0 ]; then
			echo
			output_error "    Uninstall of CodeAnalyst failed."
			return
		fi
		echo "    [${bold}OK${offbold}]"
	else
		echo "    Code Analyst Installation (v2.9.18)"
		echo "    ==================================="
		CA_EU_LICENSE=$TOPDIR/CA/AMD-CodeAnalyst-EULA.txt
		showLicense ${CA_EU_LICENSE}
		if [ "${reply}" != "accept" ]; then
			output_error "    Installation declined. Skipping."
			return
		fi

		if [ $OPTION -eq $WHOLE_SDK ]; then
			if [ $EUID -ne 0 ]; then
				output_error "You need administrator (root) access to install Code Analyst tool."
				output_error "Skipping CA installation."
				return
			fi
		fi
		select_installation_path
		install_ca_from_binary_pkg
	fi
}

function install_acml
{
	echo
	if [ $MAIN_OPTION -eq 2 ]; then
		installation_path=$INSTALL_PATH/acml
		echo    "    Un-installing AMD's Core Math library (ACML) package"
		echo -n "      - Removing $installation_path."
		${REMOVE_CMD} $installation_path
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo "    [${bold}FAILED${offbold}]"
			return
		fi
		echo "    [${bold}OK${offbold}]"
	else
		echo "    AMD Core Math Library Installation (v4.4.0)"
		echo "    =========================================="
		ACML_EU_LICENSE=$TOPDIR/acml/AMD-acml-EULA.txt
		showLicense ${ACML_EU_LICENSE}
		if [ "${reply}" != "accept" ]; then
			output_error "Installation declined. Skipping."
			return
		fi
		select_installation_path
		show_waiting_dots &
		mkdir -p $TMPDIR
		cd $TMPDIR
		tar zxf $ACML_LIBRARY
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo
			stop_waiting_dots
			output_error "Something went wrong while uncompressing acml library package. Bad file? Skipping."
			clean_tmpdir
			return
		fi
	
		installation_path=$INSTALL_PATH/acml	
		./install-acml-4-4-0-open64-64bit.sh -installdir=$installation_path -accept -noverbose
		sys_status=$?
		stop_waiting_dots
		if [ $sys_status != 0 ]; then
			clean_tmpdir
			output_error "ACML installation failed. Skipping."
			return
		fi
		INSTALL_STATUS=1
		echo "    [${bold}OK${offbold}]"
		echo "    Please read $installation_path/Doc/acml.txt file before start using the library."
		toContinue
	fi
}

function install_acml_gpu
{
	echo
	if [ $MAIN_OPTION -eq 2 ]; then
		installation_path=$INSTALL_PATH/acml_gpu
		echo    "    Un-installing AMD's Core Math library (ACML_GPU) package"
		echo -n "      - Removing $installation_path."
		${REMOVE_CMD} $installation_path
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo
			echo "    [${bold}FAILED${offbold}]"
			return
		fi
		echo "    [${bold}OK${offbold}]"
	else
		echo "    AMD Core Math Library (ACML_GPU) Installation (v4.4.0)"
		echo "    ======================================================"
		ACMLGPU_EU_LICENSE=$TOPDIR/acml_gpu/AMD-acmlgpu-EULA.txt
		showLicense ${ACMLGPU_EU_LICENSE}
		if [ "${reply}" != "accept" ]; then
			output_error "Installation declined. Skipping."
			return
		fi
		select_installation_path
		show_waiting_dots &
		mkdir -p $TMPDIR
		cd $TMPDIR
		tar zxf $ACMLGPU_LIBRARY
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo
			stop_waiting_dots
			output_error "Something went wrong while uncompressing acml_gpu library package. Bad file? Skipping."
			clean_tmpdir
			return
		fi
		installation_path=$INSTALL_PATH/acml_gpu
		./install-acmlgpu-1-1-1-gfortran-64bit.sh -installdir=$installation_path -accept -noverbose
		sys_status=$?
		stop_waiting_dots
		if [ $sys_status != 0 ]; then
			clean_tmpdir
			output_error "ACML_GPU installation failed. Skipping."
			return
		fi
		INSTALL_STATUS=1
		echo "    [${bold}OK${offbold}]"
		echo "    Please read $installation_path/Doc/acml.txt file before start using the library."
		toContinue
	fi
}

function install_amd_libm
{
	echo
	if [ $MAIN_OPTION -eq 2 ]; then
		installation_path=$INSTALL_PATH/amdlibm-2-1-lin64
		echo    "    Un-installing AMD's Math library (libm) package"
		echo -n "      - Removing $installation_path."
		${REMOVE_CMD} $installation_path
		sys_status=$?
		if [ $sys_status != 0 ]; then
			echo "    [${bold}FAILED${offbold}]"
			return
		fi
		echo "    [${bold}OK${offbold}]"
	else
		echo "    AMD Math Library Installation (v2.1)"
		echo "    ===================================="
		AMDLIBM_EU_LICENSE=$TOPDIR/amdlibm/AMD-LIBM-EULA.txt
		showLicense ${AMDLIBM_EU_LICENSE}
		if [ "${reply}" != "accept" ]; then
			output_error "Installation declined. Skipping."
			return
		fi
		select_installation_path
		show_waiting_dots &
		cd $INSTALL_PATH
		tar zxf $AMD_LIBM_LIBRARY
		sys_status=$?
		stop_waiting_dots
		clean_tmpdir
		if [ $sys_status != 0 ]; then
			echo
			output_error "AMD libM installation failed. Bad file? Skipping."
			return
		fi
		INSTALL_STATUS=1
		echo "    [${bold}OK${offbold}]"
		echo "    Please read $INSTALL_PATH/amdlibm-2-1-lin64/ReleaseNotes before using the library."
		toContinue
	fi
	echo
}

function install_documentation
{
	cd $INSTALL_PATH
	if [ $MAIN_OPTION -eq 2 ]; then
		if [ $OPTION -eq $WHOLE_SDK ]; then
			echo "    Uninstalling documentation."
			${REMOVE_CMD} ${INSTALL_PATH}/`basename ${AMDSDK_README}`
			${REMOVE_CMD} ${INSTALL_PATH}/`basename ${AMDSDK_HELPTEXT}`
			${REMOVE_CMD} ${INSTALL_PATH}/`basename ${AMDSDK_VERSIONTEXT}`
			${REMOVE_CMD} ${INSTALL_PATH}/pdf
		fi
	else
		echo "    Installing documentation (pdfs, ReadMe.txt and sdkhelp.txt)"
		echo "    ==========================================================="
		${COPY_FILE} ${AMDSDK_README}   $INSTALL_PATH
		${COPY_FILE} ${AMDSDK_HELPTEXT} $INSTALL_PATH
		${COPY_FILE} ${AMDSDK_VERSIONTEXT} $INSTALL_PATH

		chmod 644 $INSTALL_PATH/`basename ${AMDSDK_VERSIONTEXT}`
		chmod 644 $INSTALL_PATH/`basename ${AMDSDK_README}`
		chmod 644 $INSTALL_PATH/`basename ${AMDSDK_HELPTEXT}`

		${COPY_FILE} -pr $DOCUMENTATION $INSTALL_PATH
		sys_status=$?
		clean_tmpdir
		if [ $sys_status != 0 ]; then
			output_error "Something went wrong copying the documentation. Skipping."
			return
		fi
		echo "    [${bold}OK${offbold}]"
	fi
}

function install_complete_sdk
{
	tried_once=0
	if [ $MAIN_OPTION -eq 1 ]; then
		echo
		echo "    Installing all products "
		echo "    ======================="
		select_installation_path
	else
		echo
		echo "    Un-installing all components"
		echo "    ============================"
	fi

	install_open64_toolchain
	install_code_analyst
	install_acml
	install_acml_gpu
	install_amd_libm
}

$CLEAR_SCREEN
install_sighandler
SDK_VERSION="1.0"
if [ -f ./version ]; then
	SDK_VERSION=`cat ./version`
fi

INSTALL_PATH=$HOME/amdsdk/v${SDK_VERSION}
if [ $EUID -eq 0 ]; then
	INSTALL_PATH=/opt/amdsdk/v${SDK_VERSION}
fi

TMPDIR=${INSTALL_PATH}/.amdsdkinstall.${USER}.tmp
mkdir -p $TMPDIR
sys_status=$?
if [ $sys_status != 0 ]; then
	TMPDIR=/tmp/.amdsdkinstall.${USER}.tmp
fi
clean_tmpdir
waiting_ind="${TMPDIR}/install_wait_doneit"
exit_flag=false

echo "    ********************************************************************"
echo "    ${bold}Notice${offbold}: "
echo "        For convenience, these products are provided together on one"
echo "        disk, but you do not have to use all the products. Each of the"
echo "        products on this disk is a separate work subject to a seperate"
echo "        license agreement. You must accept the license agreement for each"
echo "        product to use it. If you don't agree with the license terms, do"
echo "        not install or use the product(s)."

while(! $exit_flag)
do
	echo
    echo "    *****************************************************************"
	echo "    * Open64 SDK v${SDK_VERSION} Installation/Uninstallation menu"
    echo "    *****************************************************************"
	echo "       Please choose an option"
	echo "    ${bold}1.${offbold} Install [Default]"
	echo "    ${bold}2.${offbold} Uninstall"
	echo "    ${bold}3.${offbold} Quit"
	last_command="Select an option [Default is 1]: "
	echo -e "    Select an option [Default is 1]: \c"
	read MAIN_OPTION
	if [ "x${MAIN_OPTION}" == "x" ]; then
		MAIN_OPTION=1
	fi
	last_command=''
	dowhat=
	case $MAIN_OPTION in
		1 ) echo -n "    Continue with Installation of SDK."
			dowhat="install"
		    ;;
		2 ) echo -n "    Continue with Un-installation of SDK."
			dowhat="uninstall"
		    ;;
		3 ) exit_flag=true
            continue
			;;
        * ) echo "    Wrong option, try again."
		    continue
			;;
	esac
	while(true) 
	do
	echo
	echo "    *************************************************************"
	echo "    Select one of the following component to ${dowhat}."
	echo "    *************************************************************"
	echo "    ${bold}1.${offbold}    Open64 compiler toolchain"
	echo "    ${bold}2.${offbold}    AMD CodeAnalyst Performance Analyzer for Linux"
	echo "    ${bold}3.${offbold}    AMD's Core Math Library (ACML)"
	echo "    ${bold}4.${offbold}    AMD's Core Math Library with GPU support (ACML_GPU)"
	echo "    ${bold}5.${offbold}    AMD's optimized Math Library with glibc functions (amdlibm)"
	echo "    ${bold}7.${offbold}    All"
	echo "    ${bold}8.${offbold}    Quit"
	last_command="Select an option [Default is 1]: "
	echo -e "    Select an option [Default is 1]: \c"
	read OPTION
	if [ "x${OPTION}" == "x" ]; then
		OPTION=1
	fi

	last_command=''
	#echo
	case $OPTION in
		1 ) install_open64_toolchain
		    ;;
		2 ) install_code_analyst
		    ;;
		3 ) install_acml
		    ;;
		4 ) install_acml_gpu
		    ;;
		5 ) install_amd_libm
		    ;;
		$WHOLE_SDK ) install_complete_sdk
			exit_flag=true
		    ;;
		8 ) 
			exit_flag=true
		    ;;
        * ) echo "    Wrong option, try again."
		    continue
			;;
	esac
		break
    done
done
echo
if [ $INSTALL_STATUS -eq 1 ]; then
	install_documentation
	echo
	echo "    === Installation is complete ==== "
	echo 
	echo "    ##################################################################"
	echo "    # Your SDK root is ${INSTALL_PATH}."
	echo "    # Please read ${INSTALL_PATH}/`basename ${AMDSDK_README}`"
	echo "    #  file before using the SDK."
	echo "    # All accompanying documentation is installed in following path"
	echo "    #  $INSTALL_PATH/pdf."
	echo "    # "
	echo "    # HELP: "
	echo "    # You can contact us via one of the user forums listed in "
	echo "    # ${INSTALL_PATH}/`basename ${AMDSDK_HELPTEXT}`"
	echo "    ##################################################################"
	echo
fi
echo "    Cleaning up temporary files."
${REMOVE_CMD} $TMPDIR
echo "    Thanks for your interest in open64 SDK."
echo
