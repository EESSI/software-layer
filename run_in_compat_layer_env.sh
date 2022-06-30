#!/bin/bash
if [ -z $EESSI_PILOT_VERSION ]; then
    echo "ERROR: \$EESSI_PILOT_VERSION must be set!" >&2
    exit 1
fi
EESSI_COMPAT_LAYER_DIR="/cvmfs/pilot.nessi.uiocloud.no/versions/${EESSI_PILOT_VERSION}/compat/linux/$(uname -m)"
if [ ! -d ${EESSI_COMPAT_LAYER_DIR} ]; then
    echo "ERROR: ${EESSI_COMPAT_LAYER_DIR} does not exist!" >&2
    exit 1
fi
echo "Running '$@' in EESSI ${EESSI_PILOT_VERSION} compatibility layer environment..."
${EESSI_COMPAT_LAYER_DIR}/startprefix <<< "$@"
