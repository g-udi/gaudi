# Gaudi

Gaudi is a **bash** command line tool that helps installing/setting-up machines by defining lists of software packages to be installed.

The main motivation behind gaudi is:
 - Have a clean reproducible way to set up a machine from scratch by installing all the software/packaged needed
 - A way to share machine setups between users with [templates](https://github.com/g-udi/gaudi-templates)

> Note: Gaudi has been designed to serve both Linux and OSX but have been optimised and tested on OSX

## Installation

gaudi is installed by running the following commands in your terminal. You can install this via the command-line with either `curl` or `wget`, whichever is installed on your machine.

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)"
```

You can also manually clone the repo and then run the `setup.sh`

> gaudi has been also designed mainly to work with `bash` so running the setup with `bash` rather than `.` or `sh` is advised


## Behind the Scenes

What gaudi does behind the scenes is executing a group of bash scripts which are:
