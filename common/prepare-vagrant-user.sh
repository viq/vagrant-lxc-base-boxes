#!/bin/bash
set -e

source common/ui.sh

export VAGRANT_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

info "Preparing vagrant user..."

# Create vagrant user
if $(grep -q 'vagrant' ${ROOTFS}/etc/shadow); then
  log 'Skipping vagrant user creation'
elif $(grep -q 'ubuntu' ${ROOTFS}/etc/shadow); then
  debug 'vagrant user does not exist, renaming ubuntu user...'
  mv ${ROOTFS}/home/{ubuntu,vagrant}
  chroot ${ROOTFS} usermod -l vagrant -d /home/vagrant ubuntu &>> ${LOG}
  chroot ${ROOTFS} groupmod -n vagrant ubuntu &>> ${LOG}
  echo -n 'vagrant:vagrant' | chroot ${ROOTFS} chpasswd
  log 'Renamed ubuntu user to vagrant and changed password.'
elif [ ${DISTRIBUTION} = 'centos' -o ${DISTRIBUTION} = 'fedora' ]; then
  debug 'Creating vagrant user...'
  chroot ${ROOTFS} useradd --create-home -s /bin/bash -u 1000 vagrant &>> ${LOG}
  echo -n 'vagrant:vagrant' | chroot ${ROOTFS} chpasswd
  sed -i 's/^Defaults\s\+requiretty/Defaults !requiretty/' $ROOTFS/etc/sudoers
  if [ ${RELEASE} -eq 6 ]; then
    info 'Disabling password aging for root...'
    # disable password aging (required on Centos 6)
    # pretend that password was changed today (won't fail during provisioning)
    chroot ${ROOTFS} chage -I -1 -m 0 -M 99999 -E -1 -d `date +%Y-%m-%d` root
  fi
else
  debug 'Creating vagrant user...'
  chroot ${ROOTFS} /usr/sbin/useradd --create-home -s /bin/bash vagrant &>> ${LOG}
  chroot ${ROOTFS} /usr/sbin/adduser vagrant sudo &>> ${LOG}
  echo -n 'vagrant:vagrant' | chroot ${ROOTFS} /usr/sbin/chpasswd
fi

# Configure SSH access
if [ -d ${ROOTFS}/home/vagrant/.ssh ]; then
  log 'Skipping vagrant SSH credentials configuration'
else
  debug 'SSH key has not been set'
  mkdir -p ${ROOTFS}/home/vagrant/.ssh
  echo $VAGRANT_KEY > ${ROOTFS}/home/vagrant/.ssh/authorized_keys
  chroot ${ROOTFS} /bin/chown -R vagrant: /home/vagrant/.ssh
  log 'SSH credentials configured for the vagrant user.'
fi

# Enable passwordless sudo for the vagrant user
if [ -f ${ROOTFS}/etc/sudoers.d/vagrant ]; then
  log 'Skipping sudoers file creation.'
else
  debug 'Sudoers file was not found'
  echo "vagrant ALL=(ALL) NOPASSWD:ALL" > ${ROOTFS}/etc/sudoers.d/vagrant
  chmod 0440 ${ROOTFS}/etc/sudoers.d/vagrant
  log 'Sudoers file created.'
fi
