#!/usr/bin/env bash

# Getting the operating system of the machine
getOperatingSystem () {
    case $(uname) in
    Linux )
        command -v yum && { export OS=centos; return; }
        command -v zypper && { export OS=opensuse; return; }
        command -v apt-get && { export OS=debian; return; }
        ;;
    Darwin )
        export OS=osx
        ;;
    * );;
    esac
}

if [ ! -n "$GAUDI" ]; then
    GAUDI=~/.gaudi
fi

if [ -d "$GAUDI" ]; then
    printf "You already have gaudi installed..\\n"
    printf "Setting up a fresh installation of gaudi 🌈\\n"
    rm -rf $GAUDI
fi

# Run the installation pre-requisites based on each operating system defined in gaudi
getOperatingSystem && bash -c "$(curl -kfsSL https://raw.githubusercontent.com/ahmadassaf/gaudi/master/bin/${OS}/install-pre-requisits.sh)"

# Prevent the cloned repository from having insecure permissions. Failing to do
# so causes compinit() calls to fail with "command not found: compdef" errors
# for users with insecure umasks (e.g., "002", allowing group writability). Note
# that this will be ignored under Cygwin by default, as Windows ACLs take
# precedence over umasks except for filesystems mounted with option "noacl".
umask g-w,o-w

env git clone --depth=1 https://github.com/ahmadassaf/gaudi.git "$GAUDI" || {
    printf "Error: Cloning of gaudi into this machine failed :(\\n"
    exit 1
}

. "$GAUDI/setup.sh"
