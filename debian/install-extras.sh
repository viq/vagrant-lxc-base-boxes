#!/bin/bash
set -e

source common/ui.sh
source common/utils.sh

info 'Installing extra packages and upgrading'

debug 'Bringing container up'
utils.lxc.start

# Sleep for a bit so that the container can get an IP
SECS=15
log "Sleeping for $SECS seconds..."
sleep $SECS

# TODO: Support for appending to this list from outside
if [ $RELEASE != 'stretch' ] ; then
	PACKAGES=(vim curl wget man-db openssh-server bash-completion python-software-properties ca-certificates sudo less python-pip)
else
	PACKAGES=(vim curl wget man-db openssh-server bash-completion software-properties-common ca-certificates sudo less python-pip)
fi
if [ $DISTRIBUTION = 'ubuntu' ]; then
  PACKAGES+=' software-properties-common'
fi
if [ $RELEASE != 'raring' ] && [ $RELEASE != 'saucy' ] && [ $RELEASE != 'trusty' ] && [ $RELEASE != 'wily' ] ; then
  PACKAGES+=' nfs-common'
fi
utils.lxc.attach apt-get update
utils.lxc.attach apt-get install ${PACKAGES[*]} -y --force-yes
utils.lxc.attach apt-get upgrade -y --force-yes

CHEF=${CHEF:-0}
PUPPET=${PUPPET:-0}
SALT=${SALT:-0}
BABUSHKA=${BABUSHKA:-0}

if [ $DISTRIBUTION = 'debian' ]; then
  # Enable bash-completion
  sed -e '/^#if ! shopt -oq posix; then/,/^#fi/ s/^#\(.*\)/\1/g' \
    -i ${ROOTFS}/etc/bash.bashrc
fi

if [ $CHEF = 1 ]; then
  if $(lxc-attach -n ${CONTAINER} -- which chef-solo &>/dev/null); then
    log "Chef has been installed on container, skipping"
  else
    log "Installing Chef"
    cat > ${ROOTFS}/tmp/install-chef.sh << EOF
#!/bin/sh
curl -L https://www.opscode.com/chef/install.sh -k | sudo bash
EOF
    chmod +x ${ROOTFS}/tmp/install-chef.sh
    utils.lxc.attach /tmp/install-chef.sh
  fi
elif [ $CHEF = 2 ]; then
    log "Faking Chef installation"
    utils.lxc.attach mkdir -p /opt/chef
else
  log "Skipping Chef installation"
fi

if [ $PUPPET = 1 ]; then
  if $(lxc-attach -n ${CONTAINER} -- which puppet &>/dev/null); then
    log "Puppet has been installed on container, skipping"
  elif [ ${RELEASE} = 'sid' ]; then
    warn "Puppet can't be installed on Debian sid, skipping"
  else
    log "Installing Puppet"
    wget http://apt.puppetlabs.com/puppetlabs-release-stable.deb -O "${ROOTFS}/tmp/puppetlabs-release-stable.deb" &>>${LOG}
    utils.lxc.attach dpkg -i "/tmp/puppetlabs-release-stable.deb"
    utils.lxc.attach apt-get update
    utils.lxc.attach apt-get install puppet -y --force-yes
  fi
else
  log "Skipping Puppet installation"
fi

if [ $SALT = 1 ]; then
  if $(lxc-attach -n ${CONTAINER} -- which salt-minion &>/dev/null); then
    log "Salt has been installed on container, skipping"
  elif [ ${RELEASE} = 'raring' ]; then
    warn "Salt can't be installed on Ubuntu Raring 13.04, skipping"
  else
    if [ $DISTRIBUTION = 'ubuntu' ]; then
      #utils.lxc.attach add-apt-repository -y ppa:saltstack/salt
      utils.lxc.attach curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh
      utils.lxc.attach sh /tmp/install_salt.sh -P -X -d -U
    else # DEBIAN
      if [ $RELEASE == "squeeze" ]; then
        SALT_SOURCE_1="deb http://debian.saltstack.com/debian squeeze-saltstack main"
        SALT_SOURCE_2="deb http://backports.debian.org/debian-backports squeeze-backports main contrib non-free"
      elif [ $RELEASE == "wheezy" ]; then
        SALT_SOURCE_1="deb http://repo.saltstack.com/apt/debian/7/amd64/latest wheezy main"
      elif [ $RELEASE == "jessie" ]; then
        SALT_SOURCE_1="deb http://repo.saltstack.com/apt/debian/8/amd64/latest jessie main"
      else
        SALT_SOURCE_1="deb http://debian.saltstack.com/debian unstable main"
      fi
      echo $SALT_SOURCE_1 > ${ROOTFS}/etc/apt/sources.list.d/saltstack.list
      echo $SALT_SOURCE_2 >> ${ROOTFS}/etc/apt/sources.list.d/saltstack.list

      utils.lxc.attach wget -q -O /tmp/salt.key "https://repo.saltstack.com/apt/debian/8/amd64/latest/SALTSTACK-GPG-KEY.pub"
      utils.lxc.attach apt-key add /tmp/salt.key
    fi
    utils.lxc.attach apt-get update
    utils.lxc.attach apt-get install salt-minion -y --force-yes
  fi
else
  log "Skipping Salt installation"
fi

if [ $BABUSHKA = 1 ]; then
  if $(lxc-attach -n ${CONTAINER} -- which babushka &>/dev/null); then
    log "Babushka has been installed on container, skipping"
  elif [ ${RELEASE} = 'trusty' ]; then
    warn "Babushka can't be installed on Ubuntu Trusty 14.04, skipping"
  else
    log "Installing Babushka"
    cat > $ROOTFS/tmp/install-babushka.sh << EOF
#!/bin/sh
curl https://babushka.me/up | sudo bash
EOF
    chmod +x $ROOTFS/tmp/install-babushka.sh
    utils.lxc.attach /tmp/install-babushka.sh
  fi
else
  log "Skipping Babushka installation"
fi
