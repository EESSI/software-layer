export EESSI_PILOT_VERSION="2020.08"
export PS1="[EESSI pilot $EESSI_PILOT_VERSION] $ "

export EESSI_PREFIX=/cvmfs/pilot.eessi-hpc.org/$EESSI_PILOT_VERSION
if [ -d $EESSI_PREFIX ]; then
  echo "Found EESSI pilot repo @ $EESSI_PREFIX!"

  export EPREFIX=$EESSI_PREFIX/compat/$(uname -m)
  if [ -d $EPREFIX ]; then

    # determine subdirectory in software layer
    EESSI_PYTHON=$EPREFIX/usr/bin/python3
    export EESSI_SOFTWARE_SUBDIR=$($EESSI_PYTHON -c "import archspec.cpu, os; host_cpu = archspec.cpu.host(); vendors = {'GenuineIntel': 'intel'}; print(os.path.join(host_cpu.family.name, vendors.get(host_cpu.vendor), host_cpu.name))")
    unset EESSI_PYTHON

    echo "Derived subdirectory for software layer: $EESSI_SOFTWARE_SUBDIR"

    # for now, hardcoded to haswell
    export EESSI_SOFTWARE_SUBDIR=x86_64/intel/haswell
    echo "Using $EESSI_SOFTWARE_SUBDIR subdirectory for software layer (HARDCODED)"

    export EESSI_SOFTWARE_PATH=$EESSI_PREFIX/software/$EESSI_SOFTWARE_SUBDIR
    if [ -d $EESSI_SOFTWARE_PATH ]; then

      # init Lmod
      echo "Initializing Lmod..."
      source $EPREFIX/usr/lmod/*/init/bash

      # prepend location of modules for EESSI software stack to $MODULEPATH
      export EESSI_MODULEPATH=$EESSI_SOFTWARE_PATH/modules/all
      echo "Prepending $EESSI_MODULEPATH to \$MODULEPATH..."
      module use $EESSI_PREFIX/software/$EESSI_SOFTWARE_SUBDIR/modules/all

      echo "Environment set up to use EESSI pilot software stack, have fun!"

    else
      echo "ERROR: EESSI software layer at $EESSI_SOFTWARE_PATH not found!"
      false
    fi
  else
    echo "ERROR: Compatibility layer directory %s not found!"
    false
  fi
else
  echo "ERROR: EESSI pilot repository at $EESSI_PREFIX not found!"
  false
fi
