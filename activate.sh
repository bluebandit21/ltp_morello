#!/bin/bash
if [[ $0 == $BASH_SOURCE ]]; then
    echo "This script should be sourced and never run directly!"
else
    if [[ -z ${ENV_ACTIVATED} ]]; then
        curr_dir=`pwd`
        script_dir=$(dirname $(readlink -f "$BASH_SOURCE"))
        cd ${script_dir}


        #TODO: Stuff here :)
        export PATH="${script_dir}/toolchain/bin":"${PATH}"
        export LD_LIBRARY_PATH="${script_dir}/toolchain/lib":"${LD_LIBRARY_PATH}"

        cd ${curr_dir}

        export ENV_ACTIVATED=1
        echo "Activated environment"
    else
        echo "Environment already activated; doing nothing..."
    fi
fi