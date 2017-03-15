#!/bin/bash
set -e

source common/ui.sh
source common/utils.sh

debug 'Bringing container up'
utils.lxc.start

info "Cleaning up '${CONTAINER}'..."

log 'Removing temporary files...'
rm -rf ${ROOTFS}/tmp/*

log 'cleaning up dhcp leases'
rm -f ${ROOTFS}/var/lib/dhcp/*

log 'Removing downloaded packages...'
utils.lxc.attach apt-get clean

log 'Removing cached Salt minion ID...'
utils.lxc.attach rm -f ${ROOTFS}/etc/salt/minion_id
