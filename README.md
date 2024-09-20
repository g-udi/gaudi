# Gaudi

As a developer or tech enthusiast, you’ve probably experienced the frustration of setting up a new machine. Whether it’s for a fresh install of the operating system or a brand-new device, the process of reinstalling your go-to applications, configuring development environments, and getting everything to run smoothly can feel like a tedious chore. I know this pain all too well. That’s why I created [**Gaudi**](https://github.com/g-udi/gaudi)—a tool designed to make setting up a new machine efficient, consistent, and hassle-free.

# The Problem: Time-Consuming Setup

Anyone who's had to reconfigure a new system from scratch understands the pain. You’re faced with hours of:

- Installing software and tools ([**brew**](https://brew.sh/), [**npm**](https://www.npmjs.com/), [**mas**](https://github.com/mas-cli/mas) or others)
- Customizing system preferences
- Setting up your favorite applications
- Re-configuring settings to match your old system

It’s a repetitive, manual process, and even worse, there’s a chance you’ll forget one or two critical steps, leaving your environment not quite right. Multiply that by each new device, and you’re looking at a major time sink.

Gaudi is a **bash** command line tool that helps installing/setting-up machines by defining lists of software packages to be installed.

The main motivation behind gaudi is:

 - Have a clean reproducible way to set up a machine from scratch by installing all the software/packaged needed
 - A way to share machine setups between users with [templates](https://github.com/g-udi/gaudi-templates)

> Note: Gaudi has been designed to serve both Linux and OSX but have been optimised and tested on OSX

# Installation

gaudi is installed by running the following commands in your terminal. You can install this via the command-line with either `curl` or `wget`, whichever is installed on your machine.

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)"
```

You can also manually clone the repo and then run the `setup.sh`

> gaudi has been also designed mainly to work with `bash` so running the setup with `bash` rather than `.` or `sh` is advised

# What does gaudi do?

gaudi is a bash script that automates the installation and setup of software on a machine. It provides a way to define lists of software packages to be installed and handles the installation process for each package.

 - **Install the prerequisites for the OS** <sup>_OS detection is done automatically_</sup>: This ensures that the needed tools are installed to run gaudi. For OSX this includes: [Homebrew](https://brew.sh/), [mas](https://github.com/mas-cli/mas), [git](https://git-scm.com/).
 - **Configure SSH**: Ensure your SSH keys are set up and configured so you can clone easily from code repositories e.g., Github especially if you have your templates in a private one
 - **Configure Gaudi**: Clone the gaudi templates repository and set it up
 - **Install shell helpers**: Suggest installing shell helpers like [gaudi-bash](https://github.com/g-udi/gaudi-bash) or [oh-my-zsh](https://ohmyz.sh/)
 - **Install the software list**: Install the software list from the template files specified in the templates repository
 - **Install dotfiles**: Install the dotfiles from the template files specified in the templates repository
 - **Install extras**: Install the extras from the template files specified in the templates repository
 - **Configure the machine**: Configure the machine to your liking be it OSX or Debian specific settings


- [Configure touchID for sudo](https://github.com/g-udi/gaudi/blob/master/lib/osx/config-sudo.sh)
- Configure SSH
- Suggest installing shell helpers like [gaudi-bash](https://github.com/g-udi/gaudi-bash) or [oh-my-zsh](https://ohmyz.sh/)
- Install the software list from the template files specified in the templates repository


# Behind the Scenes

## Folder and File Structure

- **bin**
    - **colors.sh**: Variables and functions that are used to print colors to the terminal.
    - **commands.sh**: Aliases to point to different commands if they are installed in different locations e.g., brew
    - **helpers.sh**: Various helper functions that are used to perform various tasks.
    - **installer.sh**: This file contains the main logic for installing the software lists.
- **configs**
    - **configure-gaudi.sh**: Downloads the gaudi templates repository
    - **configure-ssh.sh**: Configures SSH on the machine
- **lib**
    ---
    ### _Operating System specific scripts_
    - **install-pre-requisites.sh**: Installs the software lists from the templates repository
    - **cleanup.sh**: Cleans up the machine after the software lists have been installed
    ---
    ### _Common scripts_
    - **install-shell-helpers.sh**: Installs shell helpers like [gaudi-bash](https://github.com/g-udi/gaudi-bash) or [oh-my-zsh](https://ohmyz.sh/)
    - **install-software.sh**: Installs the software lists from the templates
    - **install-configurations**: Installs the configurations from the templates repository. They can be any kind of configuration files e.g., templates, dotfiles, etc.
    - **<install-dotfile.sh>**: Installs the dotfiles from the templates repository
- **install.sh**: This file is used to install gaudi.
- **setup.sh**: This file is used to setup gaudi.

## The Installation Process

The software lists to be processed are specified in a `softwareLists` array in the `install.sh` file as below:

```sh
softwareLists=(
    "debian|apt-get::sudo apt-get -y --force-yes install"
    "*|brew::brew_install_or_upgrade"
    "osx|mas::mas install"
    "osx|cask::brew install --cask"
    "*|npm::npm install -g"
    "*|pip::pip3 install --upgrade --user --ignore-installed six"
    "*|go::go get"
    "*|gem::gem_install_or_update install"
)
```

Each line in the array is made of 3 elements:

1. The operating system to run the command on
2. The command to run
3. The arguments to pass to the command

For example, the following line:

```sh
"*|brew::brew_install_or_upgrade"
```

This will run the command `brew_install_or_upgrade` on any operating system.

```sh
"osx|mas::mas install"
```

This will run the command `mas install` on a OSX based system.

### Hooks

Hooks are scripts that are run before or after the software lists are installed. They are located in the `hooks` folder. 

Hooks must have the following name format:

```sh
pre.software-list.hooks.sh
post.software-list.hooks.sh
```

Combining hooks with template based installation allows for a high level of control over the installation process. 

### Templates

An example templates are located in the [gaudi-templates](https://github.com/g-udi/gaudi-templates) repository.

They are basically shell scripts that install/configure/setup/... whatever you want in your machine.
