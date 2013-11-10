#!/bin/bash

WORKING_DIR=`pwd`
HOSTNAME=`hostname -f`
DOMAIN=`hostname -d`
LOG="/tmp/ilabcm.log"


function usage
{
    echo ""
    echo $1
    echo ""
    echo "Usage: ilabcm.run -- [OPTION]...                                           "
    echo "Perform the installation of the ilab puppet configuration management engine"
    echo "                                                                           "
    echo "Mandatory arguments:                                                       "
    echo "  -g name     global repository name                                       "
    echo "  -r name     environmentrepo repository name                              "
    echo "                                                                           "
    echo ""
}


function detect_distro
{
	OS=`uname -s | tr -d '\n' | tr '[:upper:]' '[:lower:]'`
	
	# freebsd
	if [ "${OS}" = "FreeBSD" ] ; then	
		KERNEL=''
		DIST='freebsd'
		PSUEDONAME=""
		REV=`uname -r | sed 's/\-.*//' | tr -d '\n'`

	# linux
	elif [ "${OS}" = "linux" ] ; then
		KERNEL=`uname -r`
		
		# centos
		if [ -f /etc/centos-release ] ; then
			DIST='centos'
			PSUEDONAME=`cat /etc/centos-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/centos-release | sed s/.*release\ // | sed s/\ .*//`
			
		# fedora
		elif [ -f /etc/fedora-release ] ; then
			DIST='fedora'
			PSUEDONAME=`cat /etc/fedora-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/fedora-release | sed s/.*release\ // | sed s/\ .*//`
		
		# redhat
		elif [ -f /etc/redhat-release ] ; then
			DIST='redhat'
			PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
		
		# arch
		elif [ -f /etc/arch-release ] ; then
			DIST='arch'
			PSUEDONAME=''
			REV=""
			
		# suse
		elif [ -f /etc/SuSE-release ] ; then
			DIST='suse'
			PSUEDONAME=''
			REV=`cat /etc/SuSE-release | grep VERSION | sed 's/VERSION = //'`
		
		# ubuntu		
		elif [ -f /etc/lsb-release ] ; then
			DIST=`cat /etc/lsb-release | grep ID | sed 's/.*=//'`
			PSUEDONAME=`cat /etc/lsb-release | grep CODE | sed 's/.*=//'`
			REV=`cat /etc/lsb-release | grep REL | sed 's/.*=//'`
			
		# debian
		elif [ -f /etc/debian_version ] ; then
			DIST='debian'
			PSUEDONAME=`lsb_release -a | grep -i description | sed s/.*\(// | sed s/\)//`
			REV=`lsb_release -a | grep -i release | sed 's/.*:\s\+//'`
		
		# gentoo
		elif [ -f /etc/gentoo-release ] ; then
			DIST='gentoo'
			PSUEDONAME=''
			REV=''
		
		# slackware
		elif [ -f /etc/os-release ] ; then
			DIST=`cat /etc/os-release | grep ^NAME | sed 's/.*=//'`
			PSUEDONAME=''
			REV=`cat /etc/os-release | grep ^VERSION_ID | sed 's/.*=//'`
		
		# unknown distro
		else
			DIST=''
			PSUEDONAME=''
			REV=''
		fi
	
	# unknown os
	else
		KERNEL=''
		DIST=''
		PSUEDONAME=''
		REV=''
		
	fi
	
	MACH=`uname -m | tr -d '\n' | tr '[:upper:]' '[:lower:]'`
	DIST=`echo $DIST | tr -d '\n' | tr '[:upper:]' '[:lower:]'`
	PSUEDONAME=`echo $PSUEDONAME | tr -d '\n' | tr '[:upper:]' '[:lower:]'`
	REV=`echo $REV | tr -d '\n' | tr '[:upper:]' '[:lower:]'`
}


function check_requirements
{
    echo "Checking prerequisites..."

    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root"
        exit 1
    fi
	
	puppet=`which puppet`
	if [ "$?" = "0" ]; then
        echo "Puppet is already installed"
        exit 1
    fi
}


function configure_proxy
{
	proxy="http://proxy.$DOMAIN:911"
	export http_proxy=$proxy
	export http_proxy=$proxy
	echo "proxy=$proxy" > /root/.wgetrc
	
	if [ -f /etc/yum.conf ]; then
		if grep --quiet proxy /etc/yum.conf; then
			sed -i 's/^proxy.*/proxy=http:\/\/proxy.$DOMAIN:911/g' /etc/yum.conf
		else
			echo "proxy=http://proxy.$DOMAIN:911" >> /etc/yum.conf
		fi
	fi
}


function attempt_puppetlabs_install
{
	PKGMRSUCCESS=0
	
	echo "Attempting install from puppetlabs..."
	
	if [[ "$DIST" = "redhat" || "$DIST" = "centos" ]]; then
	
		if [[ "$REV" == *"6."* ]]; then
			rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
			yum install -y puppet facter
			PKGMRSUCCESS=$?
			
		elif [[ "$REV" == *"5."* ]]; then
			rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-5.noarch.rpm
			yum install -y puppet facter
			PKGMRSUCCESS=$?
			
		else
			echo "Currently there is no puppetlabs install for $OS - $DIST"
			PKGMRSUCCESS=1
			
		fi
		
	elif [[ "$DIST" = "fedora" ]]; then
		rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-fedora-$REV.noarch.rpm
		yum install -y puppet facter
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "ubuntu" || "$DIST" = "debian" ]]; then
		wget http://apt.puppetlabs.com/puppetlabs-release-$PSUEDONAME.deb
		dpkg -i puppetlabs-release-$PSUEDONAME.deb
		apt-get update -y
		apt-get install -y facter puppet
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "gentoo" ]]; then
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1
	
	elif [[ "$DIST" = "suse" ]]; then
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1

	elif [[ "$DIST" = "freebsd" ]]; then
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1
		
	elif [[ "$DIST" = "slackware" ]]; then
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1
	
	elif [[ "$DIST" = "arch" ]]; then
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1
	
	else
		echo "Currently there is no puppetlabs install for $OS - $DIST"
		PKGMRSUCCESS=1
		
	fi
	
	return $PKGMRSUCCESS
}


function attempt_rubygem_install
{
	PKGMRSUCCESS=0
	
	echo "Attempting install from ruby gem..."
	
	if [[ "$DIST" = "redhat" || "$DIST" = "centos" || "$DIST" = "fedora" ]]; then
		yum install -y rubygems
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "ubuntu" || "$DIST" = "debian" ]]; then
		apt-get -y update
		apt-get install -y rubygems
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "gentoo" ]]; then
		emerge-webrsync
		emerge rubygems
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "suse" ]]; then
		apt-get -y update
		apt-get install -y rubygems
		PKGMRSUCCESS=$?

	elif [[ "$DIST" = "freebsd" ]]; then
		setenv BATCH yes >> $LOG 2>&1
		/usr/ports/devel/ruby-gems
		make install
		PKGMRSUCCESS=1	
		
	elif [[ "$DIST" = "slackware" ]]; then
		echo "Currently there is no rubygems install for $OS - $DIST"
		PKGMRSUCCESS=1	
	
	elif [[ "$DIST" = "arch" ]]; then
		echo "Currently there is no rubygems install for $OS - $DIST"
		PKGMRSUCCESS=1	
	
	else
		echo "Currently there is no rubygems install for $OS - $DIST"
		PKGMRSUCCESS=1	
		
	fi
	
	if [ "$PKGMRSUCCESS" = "0" ]; then
		gem install puppet
		PKGMRSUCCESS=$?
	fi
	
	return $PKGMRSUCCESS
}


function attempt_osrepository_install
{
	PKGMRSUCCESS=0
	
	echo "Attempting install from os repositories..."
	
	if [[ "$DIST" = "redhat" || "$DIST" = "centos" || "$DIST" = "fedora" ]]; then
		yum install -y puppet facter >> $LOG 2>&1
		PKGMRSUCCESS=$?
		
	elif [[ "$DIST" = "ubuntu" || "$DIST" = "debian" ]]; then
		apt-get update -y >> $LOG 2>&1
		apt-get install -y facter puppet >> $LOG 2>&1
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "gentoo" ]]; then
		emerge-webrsync >> $LOG 2>&1
		emerge facter puppet >> $LOG 2>&1
		PKGMRSUCCESS=$?
	
	elif [[ "$DIST" = "suse" ]]; then
		zypper -y -f install puppet factor >> $LOG 2>&1
		PKGMRSUCCESS=$?

	elif [[ "$DIST" = "freebsd" ]]; then
		setenv BATCH yes >> $LOG 2>&1
		pkg_add -r facter puppet >> $LOG 2>&1
		PKGMRSUCCESS=$?	
		
	elif [[ "$DIST" = "slackware" ]]; then
		echo "There is no package manager install for $OS - $DIST"
		PKGMRSUCCESS=1	
	
	elif [[ "$DIST" = "arch" ]]; then
		echo "There is no package manager install for $OS - $DIST"
		PKGMRSUCCESS=1	
	
	else
		echo "There is no package manager install for $OS - $DIST"
		PKGMRSUCCESS=1
		
	fi
	
	return $PKGMRSUCCESS
}


function attempt_source_install
{	
	echo "Attempting installing from source..."

    openssl_ver="openssl-1.0.1e"
    ruby_ver="ruby-1.9.3-p448"
    puppet_ver="puppet-3.3.1"
    facter_ver="facter-2.0.0rc4"
    yaml_ver="yaml-0.1.4"
    zlib_ver="zlib-1.2.8"
    hiera_ver="hiera-master"
    
    openssl_tar="${openssl_ver}.tar.gz"
    ruby_tar="${ruby_ver}.tar.gz"
    puppet_tar="${puppet_ver}.tar.gz"
    facter_tar="${facter_ver}.tar.gz"
    yaml_tar="${yaml_ver}.tar.gz"
    zlib_tar="${zlib_ver}.tar.gz"
    hiera_tar="${hiera_ver}.tar.gz"


    tar zxvf $WORKING_DIR/src/$openssl_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$zlib_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$ruby_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$puppet_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$facter_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$yaml_tar -C $WORKING_DIR >> $LOG 2>&1
    tar zxvf $WORKING_DIR/src/$hiera_tar -C $WORKING_DIR >> $LOG 2>&1

    # openssl
    echo "Installing openssl..."
    cd $WORKING_DIR/$openssl_ver
    ./config --prefix=/usr -fPIC >> $LOG 2>&1
    make >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    make install >> $LOG 2>&1

    # zlib
    echo "Installing zlib..."
    cd $WORKING_DIR/$zlib_ver
    ./configure --prefix=/usr >> $LOG 2>&1
    make >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    make install >> $LOG 2>&1

    # yaml
    echo "Installing yaml..."
    cd $WORKING_DIR/$yaml_ver
    ./configure --prefix=/usr >> $LOG 2>&1
    make >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    make install >> $LOG 2>&1

    # ruby
    echo "Installing ruby..."
    cd $WORKING_DIR/$ruby_ver
    ./configure --prefix=/usr --with-opt-dir=/usr --disable-install-doc --enable-shared >> $LOG 2>&1
    make >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    make install >> $LOG 2>&1

    # facter
    echo "Installing facter..."
    cd $WORKING_DIR/$facter_ver
    /usr/bin/ruby install.rb >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    # puppet
    echo "Installing puppet..."
    cd $WORKING_DIR/$puppet_ver
    /usr/bin/ruby install.rb >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi

    # hiera
    echo "Installing hiera..."
    cd $WORKING_DIR/$hiera_ver
    /usr/bin/ruby install.rb >> $LOG 2>&1

    if [[ $? -ne 0 ]]; then
        echo "Build failed.."
        exit 1;
    fi
}


function install
{
	configure_proxy
	
	attempt_puppetlabs_install
	if [[ $? -ne 0 ]]; then
		attempt_rubygem_install
		
		if [[ $? -ne 0 ]]; then
			attempt_osrepository_install
			
			if [[ $? -ne 0 ]]; then
				attempt_source_install
			fi
		fi
	fi
	
	if [[ $? -eq 0 ]]; then
		configure
	fi
}


function configure
{
    echo "Configuring..."
	
	if [ -f /etc/default/puppet ]; then
		sed -i 's/START=no/START=yes/g' /etc/default/puppet
		
	fi
	
    mkdir -vp /var/log >> $LOG 2>&1
    mkdir -vp /var/lib/ssl >> $LOG 2>&1
    mkdir -vp /var/run >> $LOG 2>&1
    mkdir -vp /var/facter >> $LOG 2>&1
    mkdir -vp /var/puppet >> $LOG 2>&1
    mkdir -vp /etc/puppet >> $LOG 2>&1
   
    cp -v $WORKING_DIR/conf/auth.conf /etc/puppet/ >> $LOG 2>&1
    cp -v $WORKING_DIR/conf/puppet.conf /etc/puppet/ >> $LOG 2>&1
    cp -v $WORKING_DIR/conf/hiera.yaml /etc/puppet/ >> $LOG 2>&1

    /usr/bin/ruby -p -i -e "gsub(/HOSTNAME/, '${HOSTNAME}')" /etc/puppet/puppet.conf 
	/usr/bin/ruby -p -i -e "gsub(/SERVER/, 'puppet.${DOMAIN}')" /etc/puppet/puppet.conf 

    echo "Puppet first run..."
    /usr/bin/puppet apply --verbose --debug /etc/puppet/manifests/site.pp --logdest=/var/log/puppet.log
}


function setup
{
    local globalrepo=""
    local environmentrepo=""
	
	detect_distro

    echo "" > $LOG 2>&1

    while getopts ":g:r" opt; do
        
        if [[ ${OPTARG} = -* ]]; then 
            usage "Invalid argument '${OPTARG}' for option -${opt}"
            exit 1
        fi

        case "${opt}" in

            g)
                globalrepo="${OPTARG}" 
                ;;
            r)
                environmentrepo="${OPTARG}" 
                ;;
            \?)
                usage "Invalid option: -${OPTARG}" >&2
                exit 1
                ;;
            :)
                usage "Option -${OPTARG} requires an argument"
                exit 1
                ;;

        esac

    done

	read -p "Press enter to continue with Ilab Configuration Management Installation"
	check_requirements
	install
	exit 0
}


setup $@
