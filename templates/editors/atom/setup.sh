read -p "Would you like to install Atom now ? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        sudo add-apt-repository ppa:webupd8team/atom
        sudo apt-get update
        sudo apt-get install atom
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew cask install atom
    fi
fi

# Install brew modules
apm_install_packages() {
    read -p "Would you like to install all the recommended Atom packages [Type N to select what you want to install one by one]? [Y/N] " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
    for package in "${packages[@]}"; do
        apm install $package
    done
    else
        for package in "${packages[@]}"; do
            read -p "Would you like to install $package? [Y/N] " -n 1;
            echo "";
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                apm install $package
            fi;
        done
    fi
}

packages=(
    MagicPython
    atom-beautify
    atom-format
    atom-material-ui
    auto-detect-indentation
    autoclose-html
    autocomplete-paths
    autocomplete-python
    clipboard-plus
    dash
    expose
    file-icons
    fizzy
    highlight-selected
    linter
    set-syntax
    editorconfig
)

# Start the actual installation of the recipes
apm_install_packages
