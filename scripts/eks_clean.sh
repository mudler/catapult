#!/usr/bin/env bash

# Destroys an existing Caasp4 cluster on openstack
#
# Requirements:
# - Built skuba docker image
# - Sourced openrc.sh
# - Key on the ssh keyring

. scripts/include/common.sh

set -exuo pipefail


if [ -d ../"$BUILD_DIR" ]; then
    . .envrc

    pushd cap-terraform/eks
    terraform destroy
    popd

    popd
    rm -rf "$BUILD_DIR"
fi
