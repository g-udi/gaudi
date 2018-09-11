# Bash-it

**Bash-it** is a mash up of my own bash commands and scripts, other bash stuff I have found and a shameless ripoff of [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) includes autocompletion, themes, aliases, custom functions, a few stolen pieces from Steve Losh, and more.

Bash-it provides a solid framework for using, developing and maintaining shell scripts and custom commands for your daily work. If you're using the _Bourne Again Shell_ (Bash) on a regular basis and have been looking for an easy way on how to keep all of these nice little scripts and aliases under control, then Bash-it is for you! Stop polluting your `~/bin` directory and your `.bashrc` file, fork/clone Bash-it and start hacking away.

## Install

The preferred installation method is using the main script in the [main configuration repo](http://github.com/ahmadassaf/configurations). However, if you wish to do a standalone installation then you proceed with the following steps:

1. Check a clone of this repo: `git clone https://github.com/ahmadassaf/bash-it.git ~/.bash_it`
2. Run `~/.bash_it/install.sh` (it automatically backs up your `~/.bash_profile`)
3. Edit your `~/.bash_profile` file in order to customize bash-it.

**NOTE:**
The install script will also prompt you asking if you use [Jekyll](https://github.com/mojombo/jekyll).
This is to set up the `.jekyllconfig` file, which stores info necessary to use the Jekyll plugin.


**INSTALL OPTIONS:**
The install script can take the following options:

* `--interactive`: Asks the user which aliases, completions and plugins to enable.

When run without the `--interactive` switch, Bash-it only enables a sane default set of functionality to keep your shell clean and to avoid issues with missing dependencies. Feel free to enable the tools you want to use after the installation.

**NOTE**: Keep in mind how Bash load its configuration files, `.bash_profile` for login shells (and in Mac OS X in terminal emulators like [Termminal.app](http://www.apple.com/osx/apps/) or [iTerm2](https://www.iterm2.com/)) and `.bashrc` for interactive shells (default mode in most of the GNU/Linux terminal emulators), to ensure that Bash-it is loaded correctly. A good "practice" is sourcing `.bashrc` into `.bash_profile` to keep things working in all the scenarios, to achieve this, you can add this snippet in your `.bash_profile`:

```
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
```

Refer to the official [Bash documention](https://www.gnu.org/software/bash/manual/bashref.html#Bash-Startup-Files) to get more info.

## Update

To update Bash-it, simply run:

```
bash-it update
```

that's all.

## Help Screens

```shell
bash-it show aliases        # shows installed and available aliases
bash-it show completions    # shows installed and available completions
bash-it show plugins        # shows installed and available plugins
bash-it help aliases        # shows help for installed aliases
bash-it help completions    # shows help for installed completions
bash-it help plugins        # shows help for installed plugins
```

## Search

If you need to quickly find out which of the plugins, aliases or completions
are available for a specific framework, programming language, or an environment, you can _search_ for
multiple terms related to the commands you use frequently.  Search will
find and print out modules with the name or description matching the terms
provided.

#### Syntax

```bash
  bash-it search term1 [[-]term2] [[-]term3]....
```

As an example, a ruby developer might want to enable everything
related to the commands such as `ruby`, `rake`, `gem`, `bundler` and `rails`.
Search command helps you find related modules, so that you can decide which
of them you'd like to use:

```bash
❯ bash-it search ruby rake gem bundle irb rails
      aliases:  bundler rails
      plugins:  chruby chruby-auto ruby
  completions:  bundler gem rake
```

Currently enabled modules will be shown in green.

#### Search with Negations

You can prefix a search term with a "-" to exclude it from the results. In the above
example, if we wanted to hide `chruby` and `chruby-auto`, we could change the command as
follows:

```bash
❯ bash-it search ruby rake gem bundle irb rails -chruby
      aliases:  bundler rails
      plugins:  ruby
  completions:  bundler gem rake
```

#### Using Search to Enable or Disable Components

By adding a `--enable` or `--disable` to the search command, you can automatically
enable all modules that come up as a result of a search query. This could be quite
handy if you like to enable a bunch of components related to the same topic.

#### Disabling ASCII Color

To remove non-printing non-ASCII characters responsible for the coloring of the
search output, you can set environment variable `NO_COLOR`. Enabled components will
then be shown with a checkmark:

```bash
❯ NO_COLOR=1 bash-it search ruby rake gem bundle irb rails -chruby
      aliases  =>   ✓bundler ✓rails
      plugins  =>   ✓ruby
  completions  =>   bundler gem rake
```

## Your Custom scripts, aliases, themes, and functions

For custom scripts, and aliases, just create the following files (they'll be ignored by the git repo):

* `aliases/custom.aliases.bash`
* `completion/custom.completion.bash`
* `lib/custom.bash`
* `plugins/custom.plugins.bash`
* `custom/themes/<custom theme name>/<custom theme name>.theme.bash`

I recommend putting the extra bash configuration in the `lib/custom.bash`, for example my custom configuration is:

```shell
# Git credentials
# Not in the repository, to prevent people from accidentally committing under my name
GIT_AUTHOR_NAME="Ahmad Assaf"
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
git config --global user.name "$GIT_AUTHOR_NAME"
GIT_AUTHOR_EMAIL="ahmad.a.assaf@gmail.com"
GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob;

# Autocorrect typos in path names when using `cd`
shopt -s cdspell;

# Make Sublime the default editor
export EDITOR="sublime";
export GIT_EDITOR='sublime'

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=32768;
export HISTFILESIZE=$HISTSIZE;
export HISTCONTROL=ignoredups;
# Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help";

# Prefer US English and use UTF-8
export LANG="en_US.UTF-8";
export LC_ALL="en_US.UTF-8";

# Highlight section titles in manual pages
export LESS_TERMCAP_md="${yellow}";

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X";

# Link Homebrew casks in `/Applications` rather than `~/Applications`
export HOMEBREW_CASK_OPTS="--appdir=/Applications";

# Add MySQL and MAMPP to path
export PATH=$PATH:/Applications/MAMP/Library/bin

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"
```

now, if you want to change any of the main configuration and have it saved in your own fork, then i recommend you edit the `template/bash-profile.template.bash` as this is the main `bash_profile` file that will be copied and sourced in your home folder. For example, i have changed the theme and the default editors so that i will not have to change them every time i do a fresh install.

Anything in the custom directory will be ignored, with the exception of `custom/example.bash`.

## Themes

There are a few Bash-it themes. If you've created your own custom prompts, I'd love it if you shared with everyone else! Just submit a Pull Request.

You can see the theme screenshots [here](https://github.com/Bash-it/bash-it/wiki/Themes).

Alternatively, you can preview the themes in your own shell using `BASH_PREVIEW=true reload`.

**NOTE**: Bash-it and some themes use UTF-8 characters, so to avoid extrange behaviors in your terminal, set your locale to `LC_ALL=en_US.UTF-8` or the equivalent to your language if isn't American English.

## Uninstalling

To uninstall Bash-it, run the `uninstall.sh` script found in the `$BASH_IT` directory:

```
cd $BASH_IT
./uninstall.sh
```

This will restore your previous Bash profile. After the uninstall script finishes, remove the Bash-it directory from your machine (`rm -rf $BASH_IT`) and start a new shell.

## Contributing

Please take a look at the [Contribution Guidelines](CONTRIBUTING.md) before reporting a bug or providing a new feature.

## Misc

### Bash Profile Aliases

Bash-it creates a 'reload' alias that makes it convenient to reload
your bash profile when you make changes. You can use it to reflect any changes you made simply by executing `reload` in the terminal.

Additionally, if you export BASH_IT_AUTOMATIC_RELOAD_AFTER_CONFIG_CHANGE as a non-null value, Bash-it will automatically reload itself after activating or deactivating plugins, aliases, or completions.

### Prompt Version Control Check

Bash-it provides prompt themes the ability to check and display version control information for the current directory. The information is retrieved for each directory and can slow down the navigation of projects with a large number of files and folders. Turn version control checking off to prevent slow directory navigation within large projects.

Bash-it provides a flag (`SCM_CHECK`) within the `~/.bash_profile` file that turns off/on version control information checking and display within all themes. Version control checking is on by default unless explicitly turned off.


Set `SCM_CHECK` to 'false' to **turn off** version control checks for all themes:

* `export SCM_CHECK=false`

Set `SCM_CHECK` to 'true' (the default value) to **turn on** version control checks for all themes:

* `export SCM_CHECK=true`

**NOTE:**
It is possible for themes to ignore the `SCM_CHECK` flag and query specific version control information directly. For example, themes that use functions like `git_prompt_vars` skip the `SCM_CHECK` flag to retrieve and display git prompt information. If you turned version control checking off and you still see version control information within your prompt, then functions like `git_prompt_vars` are most likely the reason why.

### Git prompt

Bash-it has some nice features related to Git, continue reading to know more about these features.

#### Repository info in the prompt

## Changes from [Forked Repo](https://github.com/revans/bash-it)

Due to the fact that the original repo's maintenance is not active, i have decided to host a fork and integrate to it my additional files and also those mentioned in any pull request of the original repo that i find useful. so far the list is:

### Plugins

- **base.plugin.bash**
    + `fs` determines the size of a file or total size of a directory
    + `o` with no arguments opens the current directory, otherwise opens the given location
    + `tre` is a shorthand for `tree` with hidden files and color enabled.
    + `colors` prints the color palette in the terminal
- **compress.plugin.bash [NEW]**
    + `targz` creates a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression
    + `gz` compares original and gzipped file size
- **editors.plugin.bash [NEW]**
    + `s` with no arguments opens the current directory in Sublime Text, otherwise opens the given location
    + `a` with no arguments opens the current directory in Atom Editor, otherwise opens the given location
    + `v` with no arguments opens the current directory in Vim, otherwise opens the given location
- **encode.plugin.bash [NEW]**
    + `escape` UTF-8-encodes a string of Unicode symbols
    + `unidecode` decodes \x{ABCD}-style Unicode escape sequences
- Updated the `extract.plugin.bash` function
- **git.plugin.bash**
    + `gitio` creates a git.io short URL
- **java.plugin.bash**
    + `setjdk` changes the JAVA SDK [More info](http://www.jayway.com/2014/01/15/how-to-switch-jdk-version-on-mac-os-x-maverick/)
- **json.plugin.bash [NEW]**
    + `json` offers syntax-highlight JSON strings or files
- **pyenv.plugin.bash**
    + `mkpvenv` creates a new virtualenv for this directory
    + `mkpvbranch` creates a new virtualenv for the current branch
    + `wopvbranch` sets workon branch
    + `wopvenv` works on the virtualenv for this directory
    + `rmpvenv` removes virtualenv for this directory
    + `rmpvenvbranch` removes virtualenv for this directory

### Aliases

- **gls.aliases.bash**: Enables the better `ls` command `gls`
- Added a bunch of new aliases to `general.aliases.bash` and `osx.aliases.bash` and `git.aliases.bash`
- Added custom alias colors
- Added the ability to switch between `node` and `iojs`

### Completion

- **Bosco.completion.bash [NEW]**: Adds [Bosco](bosco.readme.io) commands completion.

## A better `ls` for Bash Terminal

The default `ls` on OS X comes from BSD and compared to the GNU/Linux alternative is slightly lacking when it comes to changing how things look – so what I like to do is replace it with the GNU `ls`

To install that in OS X you can easily do that via the `coreutils` brew recipe (it is included in my `.brefile`). The default `ls` and other tools will have a ‘g’ prefix – i.e. `ls` would be `gls`. But **why ?!**

Well i simply like to have a structured view over directories, so when i do an `ls` i would like to see things grouped by type, so files for each type are underneath each other. For example:

![bash-it structured ls](https://github.com/ahmadassaf/configurations/blob/master/screenshots/bash-it_structured_ls.png)

You can notice how folders are on top, followed by the `.pdf` files and then the `.sparql` and so on. This is done via the `gls -X` parameter.

### Activating type-based `ls`

I have created a `gls.plugin.bash` alias file. The file contains aliases that convert all of my `ls` aliases into `gls` ones. If you would like to keep them separate then simply do not activate this alias and you will have to call always `gls` instead.
This alias is located in the `aliases/available` folder as we want those aliases to **override** the ones defined in the `aliases/` folder in the `general.aliases.bash`. Activating the plugin can be done via:

```shell
bash-it enable alias gls
```

## But what about the colors?

Its true that by now, we are able only to group similar types together, but this will not really improve the readability of the result. To make things better, we need to assign different color values for groups of types. For that, we need to use [dircolors](http://github.com/ahmadassaf/dircolors).

The installation is done automatically via this script if you wish so, but go ahead to the [repo](http://github.com/ahmadassaf/dircolors) and check the readme for manual installation configuration.

## This looks cool, I want more ...

Well then, behold the [Generic Colouriser](http://kassiopeia.juls.savba.sk/~garabik/software/grc/README.txt). It is a great utility which can be used for colourising many different types of output and log files. If you installed Homebrew , installing grc is as simple as typing:

```shell
brew install grc
```

but hey, don't worry too much, it is already included in my [dotfiles](http://github.com/ahmadassaf/dotfiles).

afterwards, you need to add:

```shell
# If we have grc enabled this is used to add coloring to various commands
source "`brew --prefix grc`/etc/grc.bashrc"
```

I have included this line in `lib\appearance.bash`.

Now when you use certain commands such as `traceroute`, the output should be colourised:

![bash-it grc](https://github.com/ahmadassaf/configurations/blob/master/screenshots/bash-it_grc.png)


## What about normal `ls`

If you don't want all of those fancy settings, then at least you should consider coloring the result of `ls`. This can be done easily as there are some global variables that hold what each type color is. For example, you can specific colors for `directory` `symbolic link` `executable` ... etc.

This is done by enabling `CLICOLOR` and defining `LS_COLORS`:

```shell
export CLICOLOR=1
export LS_COLORS=Exfxcxdxbxegedabagacad
```

Enabling `ls` color can now be easily enabled with the `-color` parameter in Mac OSX and `-G` in Linux. i.e. `ls -l --color`

`grep` results can be also colored as well by having `export GREP_OPTIONS='--color=auto'`. This is also automatically done in the `lib\appearance.bash`.

**NOTE** for Mac OSX you have to replace the `e` character in color codes with `033` for the colors and styles like in [here](http://misc.flogisoft.com/bash/tip_colors_and_formatting) to work.

For more information about alias coloring, these resources are very helpful:

- [Bash tips: Colors and formatting](http://misc.flogisoft.com/bash/tip_colors_and_formatting)
- [How to Fix Colors on Mac OSX Terminal](http://it.toolbox.com/blogs/lim/how-to-fix-colors-on-mac-osx-terminal-37214)
- [Setting LS_COLORS colors of directory listings in bash terminal](http://leocharre.com/articles/setting-ls_colors-colors-of-directory-listings-in-bash-terminal/)
- [OS X Lion Terminal Colours](http://backup.noiseandheat.com/blog/2011/12/os-x-lion-terminal-colours/)
- [A better ls for Mac OS X](http://hocuspokus.net/2008/01/a-better-ls-for-mac-os-x/)

### Fancy `vim` as well ?

For `vim` i have also included the [powerline](https://github.com/Lokaltog/powerline) visual styling which will include a status line.

**Important Notes**

- I haven't included `powerline` in my main installation script, so if you wish to have it, then please proceed with installing it separately with the fonts dependency.
- The `--user` parameter should be removed if you got an error while installation especially if you have python installed via Homebrew.
- A dependency is the [powerline fonts](https://github.com/ahmadassaf/powerline-fonts) pack. Installation instructions can be found directly in the repository.

after installing powerline enable it by adding to the `.vimrc`:

```shell
set rtp+=/usr/local/lib/python2.7/site-packages/powerline/bindings/vim
```

This can be change **depending on the path to the `python` directory**

### Git repository info in the prompt

Bash it can show some information about Git repositories in the shell prompt: the current branch, tag or commit you are at, how many commits the local branch is ahead or behind from the remote branch, and if you have changes stashed.

Additionally, you can view the status of your working copy and get the count of *staged*, *unstaged* and *untracked* files. This feature is controlled through the flag `SCM_GIT_SHOW_DETAILS` as follows:

Set `SCM_GIT_SHOW_DETAILS` to 'true' (the default value) to **show** the working copy details in your prompt:

* `export SCM_GIT_SHOW_DETAILS=true`

Set `SCM_GIT_SHOW_DETAILS` to 'false' to **don't show** it:

* `export SCM_GIT_SHOW_DETAILS=false`

#### Remotes and remote branches

In some git workflows you must work with various remotes, for this reason, Bash-it can provide some useful information about your remotes and your remote branches, for example, the remote on you are working, or if your local branch is tracking a remote branch.

You can control this feature with the flag `SCM_GIT_SHOW_REMOTE_INFO` as follows:

Set `SCM_GIT_SHOW_REMOTE_INFO` to 'auto' (the default value) to activate it only when more than one remote is configured in the current repo:

* `export SCM_GIT_SHOW_REMOTE_INFO=auto`

Set `SCM_GIT_SHOW_REMOTE_INFO` to 'true' to always activate the feature:

* `export SCM_GIT_SHOW_REMOTE_INFO=true`

Set `SCM_GIT_SHOW_REMOTE_INFO` to 'false' to **disable the feature**:

* `export SCM_GIT_SHOW_REMOTE_INFO=false`

#### Untracked files

By default, `git status` command shows information about *untracked* files, this behavior can be controlled through command line flags or git configuration files, for big repositories, ignoring *untracked* files can make git faster. Bash-it uses `git status` to gather the repo information it shows in the prompt, so in some circumstances, can be useful to instruct Bash-it to ignore these files. You can control this behavior with the flag `SCM_GIT_IGNORE_UNTRACKED`:

Set `SCM_GIT_IGNORE_UNTRACKED` to 'false' (the default value) to get information about *untracked* files:

* `export SCM_GIT_IGNORE_UNTRACKED=false`

Set `SCM_GIT_IGNORE_UNTRACKED` to 'true' to **ignore** *untracked* files:

* `export SCM_GIT_IGNORE_UNTRACKED=true`

also, with this flag to false, Bash-it will not show the repository as dirty when the repo have *untracked* files, and will not display the count of *untracked* files.

**NOTE:** If you set in git configuration file the option to ignore *untracked* files, this flag has no effect, and Bash-it will ignore *untracked* files always.

#### Git user

In some environments it is useful to know the value of the current git user, which is used to mark all new commits. For example, any organization that uses the practice of pair programming will typically author each commit with a [combined names of the two authors](https://github.com/pivotal/git_scripts). When another pair uses the same pairing station, the authors are changed at the beginning of the session.

To get up and running with this technique, run `gem install pivotal_git_scripts`, and then edit your `~/.pairs` file, according to the specification on the [gem's homepage](https://github.com/pivotal/git_scripts) After that you should be able to run `git pair kg as` to set the author to, eg. "Konstantin Gredeskoul and Alex Saxby", assuming they've been added to the `~/.pairs` file. Please see gem's documentation for more information.

To enable the display of the current pair in the prompt, you must set `SCM_GIT_SHOW_CURRENT_USER` to `true`. Once set, the `SCM_CURRENT_USER` variable will be automatically populated with the initials of the git author(s). It will also be included in the default git prompt. Even if you do not have `git pair` installed, as long as your `user.name` is set, your initials will be computed from your name, and shown in the prompt.

You can control the prefix and the suffix of this component using the two variables:

* `export SCM_THEME_CURRENT_USER_PREFFIX=' ☺︎ '`

And

* `export SCM_THEME_CURRENT_USER_SUFFIX=' '``

#### Ignore repo status

When working in repos with a large code base Bash-it can slow down your prompt when checking the repo status, to avoid it, there is an option you can set via Git config to disable checking repo status in Bash-it.

To disable checking the status in the current repo:

```
$ git config --add bash-it.hide-status 1
```

But if you would like to disable it globally, and stop checking the status for all of your repos:

```
$ git config --global --add bash-it.hide-status 1
```

setting this flag globally has the same effect that `SCM_CHECK=true` but only for Git repos.

### Pass function renamed to passgen

The Bash-it `pass` function has been renamed to `passgen` in order to avoid a naming conflict with the [pass password manager]. In order to minimize the impact on users of the legacy Bash-it `pass` function, Bash-it will create the alias `pass` that calls the new `passgen` function if the `pass` password manager command is not found on the `PATH` (default behavior).

This behavior can be overridden with the `BASH_IT_LEGACY_PASS` flag as follows:

Set `BASH_IT_LEGACY_PASS` to 'true' to force Bash-it to always **create** the `pass` alias to `passgen`:

* `export BASH_IT_LEGACY_PASS=true`

Unset `BASH_IT_LEGACY_PASS` to have Bash-it **return to default behavior**:

* `unset BASH_IT_LEGACY_PASS`

### Themes

- Added **colourful** theme [screenshot below]

![bash-it Colourful Theme](https://github.com/ahmadassaf/configurations/blob/master/screenshots/bash-it_theme_colourful.png)

### Proxy Support

If you are working in a corporate environment where you have to go through a proxy server for internet access, then you know how painful it is to configure the OS proxy variables in the shell, especially if you are switching between environments, e.g. office (with proxy) and home (without proxy).

The Bash shell (and many shell tools) use the following variables to define the proxy to use:

* `HTTP_PROXY` (and `http_proxy`): Defines the proxy server for HTTP requests
* `HTTPS_PROXY` (and `https_proxy`): Defines the proxy server for HTTPS requests
* `ALL_PROXY` (and `all_proxy`): Used by some tools for the same purpose as above
* `NO_PROXY` (and `no_proxy`): Comma-separated list of hostnames that don't have to go through the proxy

Bash-it's `proxy` plugin allows to enable and disable these variables with a simple command. To start using the `proxy` plugin, run the following:

```bash
bash-it enable plugin proxy
```

Bash-it also provides support for enabling/disabling proxy settings for various shell tools. The following backends are currently supported (in addition to the shell's environment variables): Git, SVN, npm, ssh. The `proxy` plugin changes the configuration files of these tools to enable or disable the proxy settings.

Bash-it uses the following variables to set the shell's proxy settings when you call `enable-proxy`.
These variables are best defined in a custom script in Bash-it's custom script folder (`$BASH_IT/custom`), e.g. `$BASH_IT/custom/proxy.env.bash`
* `BASH_IT_HTTP_PROXY` and `BASH_IT_HTTPS_PROXY`: Define the proxy URL to be used, e.g. 'http://localhost:1234'
* `BASH_IT_NO_PROXY`: A comma-separated list of proxy exclusions, e.g. `127.0.0.1,localhost`

Once you have defined these variables (and have run `reload` to load the changes), you can use the following commands to enable or disable the proxy settings in your current shell:

* `enable-proxy`: This sets the shell's proxy environment variables and configures proxy support in your SVN, npm and SSH configuration files.
* `disable-proxy`: This unsets the shell's proxy environment variables and disables proxy support in your SVN, npm and SSH configuration files.

There are many more proxy commands, e.g. for changing the local Git project's proxy settings. Run `glossary proxy` to show the available proxy functions with a short description.

#### Using Homebrew to manage Node.js and io.js installs on OSX

Having both Node.js and io.js installed with NVM was giving me a load of problems, mainly with npm. The best way is to have them installed via `homebrew`. They are already included in my [`brewfile`](https://github.com/ahmadassaf/dotfiles/blob/master/.brewfile.sh).

So we have both Node.js and io.js installed, however iojs yis only linked to the command `iojs` in our PATH.

So, we can unlink node: `brew unlink node`, and link iojs: `brew link --force iojs` this will link io.js to `node` and other commands.

Now when we need to use Node.js rather than io.js, we can just

`$ brew unlink iojs && brew link node`

To go back to io.js

`$ brew unlink node && brew link --force iojs`

And we can alias these (add to .bashrc / .zshrc)

```bash
alias usenode='brew unlink iojs && brew link node && echo Using Node.js'
alias useio='brew unlink node && brew link --force iojs && echo Using io.js'
```
Now we can `$ usenode` when we want to use Node.js, and `$ useio` when we want to use io.js

##### References

- [Configuring IO.js with Node](https://gist.github.com/phelma/ce4eeeedb8fb9a9e8e63#file-gistfile1-md)

