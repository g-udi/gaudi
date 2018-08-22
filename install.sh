# Getting the operating system of the machine
case `uname` in
Linux )
    LINUX=1
    which yum && { export OS=centos; return; }
    which zypper && { export OS=opensuse; return; }
    which apt-get && { export OS=debian; return; }
    ;;
Darwin )
    DARWIN=1
    export OS=osx
    ;;
* );;
esac    

if [ ! -n "$GAUDI" ]; then
    GAUDI=~/.gaudi
fi

# Run the installation pre-requisites based on each operating system defined in gaudi
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ahmadassaf/gaudi/tree/master/bin/${OS}/install-pre-requisits.sh)"

env git clone --depth=1 https://github.com/ahmadassaf/gaudi.git "$GAUDI" || {
    printf "Error: Cloning of gaudi into this machine failed :(\n"
    exit 1
}

. "$GAUDI/setup.sh"



