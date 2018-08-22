# @Name: Default
# @List: brewList
export brewList=(

  # Core Modules

  "coreutils::GNU File, Shell, and Text utilities"
  "autoconf@2.13::Automatic configure script builder"
  "grep::GNU grep, egrep and fgrep"
  "ack::Search tool like grep, but optimized for programmers https://beyondgrep.com/"
  "gawk::GNU awk utility"
  "gnu-sed::GNU implementation of the famous stream editor"
  "openssl@1.1::Cryptography and SSL/TLS Toolkit"
  "findutils::Collection of GNU find, xargs, and locate https://www.gnu.org/software/findutils/"
  "wget::Internet file retriever"
  "bash::Bourne-Again SHell, a UNIX command interpreter"
  "zsh::UNIX shell (command interpreter)"
  "git::Distributed version control system designed to handle everything from small to very large projects with speed and efficiency"
  "wxmac::Cross-platform C++ GUI toolkit (wxWidgets for macOS)"
  "libxslt::C XSLT library for GNOME"
  "readline::Library for command-line editing"
  "libffi::Portable Foreign Function Interface library"
  "libyaml::A C library for parsing and emitting YAML https://github.com/yaml/libyaml"
  "gpg::GnuPG is a complete and free implementation of the OpenPGP standard https://www.gnupg.org/"

  # Development
  "asdf::Extendable version manager with support for Ruby, Node.js, Elixir, Erlang & more https://github.com/asdf-vm/asdf"
  "heroku::Command-line client for the cloud PaaS https://devcenter.heroku.com/articles/heroku-cli"
  "shellcheck::Static analysis and lint tool, for bash scripts https://www.shellcheck.net/"
  "yarn::JavaScript package manager https://yarnpkg.com/en/"
  "ctags::Ctags generates an index (or tag) file of language objects found in source files that allows these items to be quickly and easily located by a text editor or other utility http://ctags.sourceforge.net/"

    ### Git speific addons

    "git-extras::GIT utilities -- repo summary, repl, changelog population, author commit percentages and more https://github.com/tj/git-extras"
    "git-crypt::git-crypt enables transparent encryption and decryption of files in a git repository https://www.agwa.name/projects/git-crypt/"
    "git-fresh::Keep your Git repo fresh https://github.com/imsky/git-fresh"
    "git-sizer::Compute various size metrics for a Git repository, flagging those that might cause problems https://github.com/github/git-sizer"
    "git-standup::Recall what you did on the last working day. Psst! or be nosy and find what someone else in your team did https://github.com/kamranahmedse/git-standup"
    "git-town::Generic, high-level Git workflow support https://github.com/Originate/git-town"
    "git-lfs::Git extension for versioning large files https://github.com/git-lfs/git-lfs"
    "tig::Text interface for Git repositories https://jonas.github.io/tig/"
    "bfg::Remove large files or passwords from Git history like git-filter-branch https://rtyley.github.io/bfg-repo-cleaner/"
    "git-cal::github like contributions calendar on terminal https://github.com/k4rthik/git-cal"
    "github-keygen::Easy creation of secure SSH configuration for your GitHub accounts https://github.com/dolmen/github-keygen"
    "github-markdown-toc::Easy TOC creation for GitHub README.md https://github.com/ekalinin/github-markdown-toc.go"
    "github-release::Commandline app to create and edit releases on Github and upload artifacts https://github.com/aktau/github-release"
    "hub::hub is a command-line wrapper for git that makes you better at GitHub https://hub.github.com/"
    "ghi::GitHub Issues on the command line. Use your $EDITOR, not your browser https://github.com/stephencelis/ghi"
  
  # Utilities
  
  "tmux::Terminal multiplexer https://tmux.github.io/"
  "clipper::Clipper is a macOS launch agent — or Linux daemon — that runs in the background providing a service that exposes the local clipboard to tmux sessions and other processes running both locally and remotely https://github.com/wincent/clipper"
  "micro::A modern and intuitive terminal-based text editor https://micro-editor.github.io"
  "osquery::SQL powered operating system instrumentation and analytics https://osquery.io/"
  "screen::Terminal multiplexer with VT100/ANSI terminal emulation"
  "automake::Tool for generating GNU Standards-compliant Makefiles https://www.gnu.org/software/automake/"
  "bash-completion@2::Programmable completion for Bash 4.1+ https://github.com/scop/bash-completion"
  "binutils::FSF/GNU ld, ar, readelf, etc. for native development"
  "moreutils::Collection of tools that nobody wrote when UNIX was young https://joeyh.name/code/moreutils/"
  "chrome-cli::Control Google Chrome from the command-line https://github.com/prasmussen/chrome-cli"
  "emacs::GNU Emacs text editor https://www.gnu.org/software/emacs/"
  "grc::Colorize logfiles and command output https://github.com/garabik/grc"
  "jq::Lightweight and flexible command-line JSON processor https://stedolan.github.io/jq/"
  "thefuck::Magnificent app which corrects your previous console command https://github.com/nvbn/thefuck "
  "sshrc::bring your .bashrc, .vimrc, etc. with you when you ssh https://github.com/Russell91/sshrc"
  "tmate::Instant terminal sharing https://tmate.io/"
  "tree::Display directories as trees with optional color/HTML output http://mama.indstate.edu/users/ice/tree/"
  "tmux-xpanes::Awesome tmux-based terminal divider https://github.com/greymd/tmux-xpanes"
  "bash-snippets::A collection of small bash scripts for heavy terminal users https://github.com/alexanderepstein/Bash-Snippets"
  "fpp::PathPicker accepts a wide range of input -- output from git commands, grep results, searches https://facebook.github.io/PathPicker/"
  "hh::Bash and Zsh shell history suggest box - easily view, navigate, search and manage your command history https://github.com/dvorka/hstr"
  "imagemagick::Tools and libraries to manipulate images in many formats https://www.imagemagick.org/script/index.php"
  "m-cli:: Swiss Army Knife for macOS https://github.com/rgcr/m-cli"
  "mackup::Keep your application settings in sync https://github.com/lra/mackup"
  "macvim::Vim - the text editor - for Mac OS X http://macvim-dev.github.io/macvim"
  "mas::📦 Mac App Store command line interface https://github.com/mas-cli/mas"
  "nmap::Port scanning utility for large networks https://nmap.org/"
  "the_silver_searcher::A code-searching tool similar to ack, but faster https://github.com/ggreer/the_silver_searcher"
  "qrencode::QR Code generation https://fukuchi.org/works/qrencode/index.html.en"
  "watchman::Watchman exists to watch files and record when they change https://facebook.github.io/watchman/"
  "archey::An archey script clone for OS X http://obihann.github.io/archey-osx"

      ## Network
      "nmap::Port scanning utility for large networks https://nmap.org/"
      "traefik::A reverse proxy / load balancer that's easy, dynamic, automatic, fast, full-featured, open source, production proven, provides metrics, and integrates with every major cluster technologies https://traefik.io/"

  
)