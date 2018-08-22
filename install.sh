# Getting the operating system of the machine
getOperatingSystem () {
    echo -e "\n[INFO] ${YELLOW}Getting bash version .... ${NC}\n"
    bash --version
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
}  

if [ ! -n "$GAUDI" ]; then
    GAUDI=~/.gaudi
fi

if [ -d "$GAUDI" ]; then
    printf "You already have gaudi installed..\n"
    printf "Setting up a fresh installation of gaudi 🌈\n"
    rm -rf $GAUDI
fi

echo "=======> ${OS}"
echo "================================> https://raw.githubusercontent.com/ahmadassaf/gaudi/master/bin/${OS}/install-pre-requisits.sh)"
# Run the installation pre-requisites based on each operating system defined in gaudi
getOperatingSystem && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ahmadassaf/gaudi/master/bin/${OS}/install-pre-requisits.sh)"

env git clone --depth=1 https://github.com/ahmadassaf/gaudi.git "$GAUDI" || {
    printf "Error: Cloning of gaudi into this machine failed :(\n"
    exit 1
}

. "$GAUDI/setup.sh"



