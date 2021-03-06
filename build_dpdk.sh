#!/usr/bin/env bash
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER
#
# Copyright (c) 2018, Juniper Networks, Inc. All rights reserved.
#
#
# The contents of this file are subject to the terms of the BSD 3 clause
# License (the "License"). You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at
# https://github.com/Juniper/warp17/blob/master/LICENSE.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived from this
# software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# File name:
#     build_dpdk.sh
#
# Description:
#     Dpdk builder and configuration
#
# Author:
#     Matteo Triggiani
#
# Initial Created:
#     06/22/2018
#
# Notes:
#     Receives dpdk version as argument "xx.xx.x"

# Parse args
source common/common.sh
set -e

usage="$0 -v dpdk version you want to install -i Non-interactive"
dest="/opt"
tmp="/tmp"
kernel=`uname -r`
jobs=1

while getopts "v:n:j:i" opt; do
    case $opt in
    v)
        ver=$OPTARG
        name="dpdk-$ver"
        file="$name.tar.xz"
        url="http://fast.dpdk.org/rel/$file"
        ;;
    n)
        dry_run=1
        ;;
    i)
        interactive=1
        ;;
    j)
        jobs=$OPTARG
        ;;
    \?)
        usage $0
        ;;
    esac
done

([[ -z $ver ]]) &&
usage $0

# Getting dpdk from the repo
# $1 destination folder
# $2 temporary folder
function get {
    cd $2
    exec_cmd "Downloading the package" wget $url
    mkdir $name
    exec_cmd "Extracting the package" tar -xaf $file -C $name --strip-components=1
    mv -f $name $1
}

# Build dpdk
# $1 dpdk folder
# $2 compiler version
function build {
    cd $1
    exec_cmd "Compiling dpdk for $2 arch" make T=$2 -j $3 install
}

# Install dpdk in the local machine
# $1 dpdk folder
function install {
    if [[ -z $interactive ]]; then
        confirm "Installing the dpdk lib"
    fi
    exec_cmd "Copying igb_uio in $kernel folder" cp $1/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko /lib/modules/$kernel/kernel/drivers/uio/
    exec_cmd "Generating modules and map files." depmod -a
    exec_cmd "Add uio mod" modprobe uio
    exec_cmd "Add igb_uio mod" modprobe igb_uio
}

# Install dpdk dependecies
# ATTENTION: update at every new dpdk release supported [current state 17.11.5]
function get_deps {
    exec_cmd "Installing required dependecies" sudo apt install -y build-essential libnuma-dev python ncurses-dev linux-headers-$(uname -r)
}

function exports {
    RTE_SDK="$dest/$name"
    
    if [[ -n $SUDO_USER ]]; then
        echo "ATTENTION"
        echo "Run this script using command  \"sudo -E\" or I won't able to check your env"
        if [[ -z $interactive ]]; then
            confirm "Writing the RTE_SDK in your profile?"
        fi
    fi

    for line in $(env); do
        if [[ -n $(echo $line | grep $RTE_SDK) ]]; then
            echo "you've $RTE_SDK already exported"
            return
        fi
        if [[ -n $(cat $HOME/.bash_profile 2>/dev/null | grep $RTE_SDK) ||
              -n $(cat $HOME/.bashrc 2>/dev/null | grep $RTE_SDK) ]]; then
            echo "you've $RTE_SDK already written"
            return
        fi
    done
    exec_cmd "" "echo RTE_SDK=$RTE_SDK >> $HOME/.bash_profile"
}

# Skipping in case dpdk is already there
if [[ -d "$dest/$name/x86_64-native-linuxapp-gcc/build" ]]; then
    echo dpdk-$ver is already there
    install "$dest/$name"
    return
fi

check_root
update
get_deps
get $dest $tmp
build "$dest/$name" x86_64-native-linuxapp-gcc $jobs
install "$dest/$name"
exports
exit
