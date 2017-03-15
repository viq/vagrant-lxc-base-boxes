#!/bin/bash

utils.lxc.attach() {
  cmd="$@"
  log "Running [${cmd}] inside '${CONTAINER}' container..."
  (lxc-attach -n ${CONTAINER} --clear-env -- $cmd) &>> ${LOG}
}

utils.lxc.start() {
  lxc-start -d -n ${CONTAINER} &>> ${LOG} || true
}

utils.lxc.stop() {
  lxc-stop -n ${CONTAINER} &>> ${LOG} || true
}

utils.lxc.destroy() {
  lxc-destroy -n ${CONTAINER} &>> ${LOG}
}

utils.lxc.create() {
  lxc-create -n ${CONTAINER} -l DEBUG "$@" &>> ${LOG}
}
