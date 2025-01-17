#!/bin/bash
set -ex

KWT_VERSION="${KWT_VERSION:-v0.0.5}"
KWT_OS_TYPE="${KWT_OS_TYPE:-linux-amd64}"

. scripts/include/common.sh

wget https://github.com/k14s/kwt/releases/download/$KWT_VERSION/kwt-$KWT_OS_TYPE -O bin/kwt
chmod +x bin/kwt