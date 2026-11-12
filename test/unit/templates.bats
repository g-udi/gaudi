#!/usr/bin/env bats
# bin/templates.sh: the one definition of what a templates directory holds,
# shared by setup, `gaudi check`, `gaudi backup`, `gaudi doctor` and the fake brew.

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
}

template() {
    write_file "$GAUDI_TEMPLATES_LOCATION/$1"
}

# entry <Brewfile line>: prints "type|name|rest", or fails
entry() {
    ENTRY_LINE="$1" call eval 'gaudi::brewfile_entry "$ENTRY_LINE" && printf "%s|%s|%s" "$gaudi_entry_type" "$gaudi_entry_name" "$gaudi_entry_rest"'
}

# --- Brewfile lines -----------------------------------------------------------------

@test "brewfile_entry reads a package line written with double or single quotes" {
    run entry 'brew "jq"'
    assert_output_equals "brew|jq|"
    run entry "brew 'wget'"
    assert_output_equals "brew|wget|"
    run entry '  mas "Amphetamine", id: 937984704'
    assert_output_equals "mas|Amphetamine|, id: 937984704"
    run entry "cask 'kitty' if OS.mac?"
    assert_output_equals "cask|kitty| if OS.mac?"
}

@test "brewfile_entry knows every entry type Homebrew Bundle installs" {
    for type in tap brew cask mas vscode npm go cargo uv flatpak winget krew; do
        run entry "$type \"x\""
        assert_output_equals "$type|x|"
    done
}

@test "brewfile_entry refuses everything that is not a package line" {
    for line in '# brew "jq"' 'cask_args appdir: "/Applications"' 'if OS.mac?' 'end' 'brew jq' 'whalebrew "x"' ''; do
        run entry "$line"
        assert_failure
    done
}

@test "brewfile_other_line accepts blank lines, comments, cask_args and the keywords of a Ruby block" {
    for line in '' '   ' '# a comment' 'cask_args appdir: "/Applications"' 'if OS.mac?' '  unless OS.linux?' 'elsif OS.linux?' 'else' 'end' 'end # mac only'; do
        OTHER_LINE="$line" run call eval 'gaudi::brewfile_other_line "$OTHER_LINE"'
        assert_success
    done
    for line in 'brew "jq"' 'endless' 'install everything' 'iffy "x"'; do
        OTHER_LINE="$line" run call eval 'gaudi::brewfile_other_line "$OTHER_LINE"'
        assert_failure
    done
}

# --- finding files ------------------------------------------------------------------

@test "brewfiles lists Brewfile and <name>.Brewfile anywhere, sorted, for the given or the configured directory" {
    printf 'brew "jq"\n' | template "lists/core.Brewfile"
    printf 'brew "jq"\n' | template "Brewfile"
    printf 'brew "jq"\n' | template "lists/Brewfile.bak"
    run call gaudi::brewfiles
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/Brewfile
$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
    run call gaudi::brewfiles "$GAUDI_TEMPLATES_LOCATION/lists"
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
    run call gaudi::brewfiles "$SANDBOX/nowhere"
    assert_success
    assert_output_equals ""
}

@test "brewfile_name is the file name without .Brewfile, or default" {
    run call gaudi::brewfile_name "/x/lists/core.Brewfile"
    assert_output_equals "core"
    run call gaudi::brewfile_name "/x/Brewfile"
    assert_output_equals "default"
    run call gaudi::brewfile_name "/x/dev.tools.Brewfile"
    assert_output_equals "dev.tools"
}

@test "hook_files lists every hook, or only those matching a name pattern" {
    printf 'true\n' | template "hooks/pre.apt.hooks.sh"
    printf 'true\n' | template "hooks/bundle/post.bundle-core.hooks.sh"
    printf 'true\n' | template "hooks/notes.sh"
    run call gaudi::hook_files
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/hooks/bundle/post.bundle-core.hooks.sh
$GAUDI_TEMPLATES_LOCATION/hooks/pre.apt.hooks.sh"
    run call gaudi::hook_files "pre.apt*.hooks.sh"
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/hooks/pre.apt.hooks.sh"
}

@test "bundle_hook_owner gives a hook to the Brewfile with the longest matching name" {
    printf 'brew "a"\n' | template "lists/dev.Brewfile"
    printf 'brew "b"\n' | template "lists/dev.tools.Brewfile"
    run call gaudi::bundle_hook_owner "pre.bundle-dev.hooks.sh"
    assert_output_equals "dev"
    run call gaudi::bundle_hook_owner "/somewhere/pre.bundle-dev.asdf.hooks.sh"
    assert_output_equals "dev"
    run call gaudi::bundle_hook_owner "pre.bundle-dev.tools.hooks.sh"
    assert_output_equals "dev.tools"
    run call gaudi::bundle_hook_owner "post.bundle-dev.tools.extra.hooks.sh"
    assert_output_equals "dev.tools"
    run call gaudi::bundle_hook_owner "post.bundle-apps.hooks.sh"
    assert_output_equals ""
}

# --- the list engine ----------------------------------------------------------------

@test "os_list_type, list_tool and list_install_command describe each package manager once" {
    for pair in debian:apt fedora:dnf arch:pacman opensuse:zypper osx:; do
        run call gaudi::os_list_type "${pair%%:*}"
        assert_output_equals "${pair#*:}"
    done
    OS=fedora run call gaudi::os_list_type
    assert_output_equals "dnf"

    run call gaudi::list_tool apt
    assert_output_equals "apt-get"
    run call gaudi::list_tool gem
    assert_output_equals "gem"

    run call gaudi::list_install_command apt
    assert_output_equals "sudo apt-get install -y"
    run call gaudi::list_install_command dnf
    assert_output_equals "sudo dnf install -y"
    run call gaudi::list_install_command pacman
    assert_output_equals "sudo pacman -S --noconfirm --needed"
    run call gaudi::list_install_command zypper
    assert_output_equals "sudo zypper --non-interactive install"
    run call gaudi::list_install_command gem
    assert_output_equals "gaudi::gem_install"
    run call gaudi::list_install_command brew
    assert_failure
}

@test "every list type has an install command, and every OS but macOS a list type" {
    run call eval 'for t in $gaudi_list_types; do gaudi::list_install_command "$t" >/dev/null || exit 1; done; for o in $gaudi_known_oses; do [[ "$o" == "osx" || " $gaudi_list_types " == *" $(gaudi::os_list_type "$o") "* ]] || exit 1; done'
    assert_success
}

@test "supported_os accepts exactly the known operating systems" {
    for os in osx debian fedora arch opensuse; do
        OS="$os" run call gaudi::supported_os
        assert_success
    done
    for os in centos linux unknown ""; do
        OS="$os" run call gaudi::supported_os
        assert_failure
    done
}

@test "list_items prints the array of a list file, one item per line" {
    printf '# @List: aptList\naptList=(\n  "tree::Directory listing"\n  "htop"\n)\n' | template "lists/default.apt.list.sh"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh" aptList
    assert_success
    assert_output_equals "ok
tree::Directory listing
htop"
}

@test "list_items sees an array made with declare -a or local" {
    printf 'declare -a aptList=( "tree" "htop" )\n' | template "lists/a.apt.list.sh"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "ok
tree
htop"

    printf 'local -a gemList=( "rake" )\n' | template "lists/a.gem.list.sh"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.gem.list.sh" gemList
    assert_success
    assert_output_equals "ok
rake"
}

@test "list_items: an empty array is ok without items, a missing array is missing" {
    printf 'aptList=()\n' | template "lists/a.apt.list.sh"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "ok"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" otherList
    assert_success
    assert_output_equals "missing"
    run call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" 'x; touch PWNED'
    assert_output_equals "missing"
    refute_file_exists "$WORK/PWNED"
}

@test "list_items: a list file that fails or calls exit gives the reason instead of items" {
    printf 'aptList=( "tree" )\nfalse\n' | template "lists/a.apt.list.sh"
    run stdout_of call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "failed line 2 failed with status 1"

    printf 'false\naptList=( "tree" )\n' | template "lists/c.apt.list.sh"
    run stdout_of call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/c.apt.list.sh" aptList
    assert_output_equals "failed line 1 failed with status 1"

    printf 'aptList=( "tree" )\nexit 5\n' | template "lists/b.apt.list.sh"
    run stdout_of call gaudi::list_items "$GAUDI_TEMPLATES_LOCATION/lists/b.apt.list.sh" aptList
    assert_output_equals "failed it called exit: use return to stop early"
}

@test "list_items reports the failing line when its output is captured, as setup and check capture it" {
    printf 'aptList=( "tree" )\nfalse\n' | template "lists/a.apt.list.sh"
    export LIST="$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh"
    run stdout_of call eval 'captured="$(gaudi::list_items "$LIST" aptList)"; printf "%s" "$captured"'
    assert_output_equals "failed line 2 failed with status 1"
}

stdout_of() { "$@" 2>/dev/null; }

@test "list_items: what the list file prints stays out of the items, and nothing it sets reaches the caller" {
    printf 'printf "noise\\n"\nLEAKED=yes\naptList=( "tree" )\n' | template "lists/a.apt.list.sh"
    export LIST="$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh"
    run stdout_of call eval 'items="$(gaudi::list_items "$LIST" aptList)"; printf "[%s][%s][%s]" "$items" "${LEAKED:-}" "${aptList[*]:-}"'
    assert_success
    assert_output_equals "[ok
tree][][]"
}

@test "list_items leaves the caller's EXIT trap alone" {
    printf 'aptList=( "tree" )\n' | template "lists/a.apt.list.sh"
    export LIST="$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh"
    run stdout_of call eval 'trap "printf trap-ran" EXIT; gaudi::list_items "$LIST" aptList; printf "|after|"'
    assert_output_equals "ok
tree
|after|trap-ran"
}

@test "list_items_static reads an array that is written out, without running the file" {
    template "lists/a.apt.list.sh" <<'LIST'
# @List: aptList
touch "$MACHINE/list-code-ran"
aptList=(
  "tree::Directory listing (small)"
  "htop"
)
touch "$MACHINE/list-code-ran-too"
LIST
    run call gaudi::list_items_static "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "ok
tree::Directory listing (small)
htop"
    refute_file_exists "$MACHINE/list-code-ran"
    refute_file_exists "$MACHINE/list-code-ran-too"

    printf 'declare -a gemList=( "rake" "pry" )\n' | template "lists/a.gem.list.sh"
    run call gaudi::list_items_static "$GAUDI_TEMPLATES_LOCATION/lists/a.gem.list.sh" gemList
    assert_output_equals "ok
rake
pry"
}

@test "list_items_static: a comment inside the array that ends in ) does not end the array" {
    template "lists/a.apt.list.sh" <<'LIST'
# @List: aptList
aptList=(
  # Editors (terminal)
  "vim"
  # Monitors (terminal)
  "htop"
)
LIST
    run call gaudi::list_items_static "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "ok
vim
htop"
}

@test "list_files leaves out configuration scripts whose name contains .<type>-" {
    printf 'aptList=( "tree" )\n' | template "lists/default.apt-get.sh"
    printf '_command() { true; }\n' | template "configs/tune.apt-cache.configs.debian.sh"
    run call gaudi::list_files apt
    assert_success
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/lists/default.apt-get.sh"
}

@test "list_items_static: an array built by code is missing" {
    printf 'for name in tree htop; do aptList+=("$name"); done\n' | template "lists/a.apt.list.sh"
    run call gaudi::list_items_static "$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh" aptList
    assert_success
    assert_output_equals "missing"
}

# --- configuration scripts ---------------------------------------------------------

@test "config_defines_command accepts every way of writing the function, brace on the next line included" {
    for definition in '_command() {' '_command ()' '_command()' 'function _command {' 'function _command()' '  function _command' '_command(){ true; }'; do
        printf '_info="x"\n%s\n' "$definition" | template "configs/a.configs.sh"
        run call gaudi::config_defines_command "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
        assert_success
    done
    for other in '_command_helper() {' '# _command() {' 'run _command' 'my_command() {'; do
        printf '%s\n' "$other" | template "configs/a.configs.sh"
        run call gaudi::config_defines_command "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
        assert_failure
    done
}

@test "config_info reads _info from the text of a config" {
    printf '_info="Show the path bar"\n_command() { true; }\n' | template "configs/a.configs.sh"
    run call gaudi::config_info "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
    assert_output_equals "Show the path bar"
    printf "_info='Single quoted'\n" | template "configs/a.configs.sh"
    run call gaudi::config_info "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
    assert_output_equals "Single quoted"
    printf '_command() { true; }\n' | template "configs/a.configs.sh"
    run call gaudi::config_info "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
    assert_output_equals ""
}

# --- dotfiles.list -------------------------------------------------------------------

@test "dotfiles_lists finds every dotfiles.list, sorted" {
    printf '.zshrc\n' | template "dotfiles.list"
    printf '.vimrc\n' | template "more/dotfiles.list"
    run call gaudi::dotfiles_lists
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/dotfiles.list
$GAUDI_TEMPLATES_LOCATION/more/dotfiles.list"
}

@test "dotfiles_list_entries numbers the entries, without comments, blanks or surrounding spaces" {
    printf '# mine\n.zshrc\n\n  .config/kitty   # all of it\n\t.vimrc\t\n~/.ssh' | template "dotfiles.list"
    run call gaudi::dotfiles_list_entries "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    assert_success
    assert_output_equals "2	.zshrc
4	.config/kitty
5	.vimrc
6	~/.ssh"
}

@test "the fake brew installs what Gaudi's own definition calls a package line" {
    grep -q 'gaudi::brewfile_entry' "$GAUDI_ROOT/test/fakes/brew"
    template "Brewfile" <<'BREW'
brew 'wget'
if OS.mac?
  cask "kitty"
end
BREW
    run brew bundle install "--file=$GAUDI_TEMPLATES_LOCATION/Brewfile"
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "wget"
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
}

@test "print_list_items, run by gaudi::guarded, writes ok and the items to descriptor 9" {
    printf 'printf "noise\\n"\ndeclare -a aptList=( "tree" "htop" )\n' | template "lists/a.apt.list.sh"
    export LIST="$GAUDI_TEMPLATES_LOCATION/lists/a.apt.list.sh"
    run call eval 'gaudi_list_file="$LIST"; gaudi_list_name="aptList"; gaudi::guarded "$LIST" gaudi::print_list_items 9>&1 >/dev/null; printf "[%s]" "$gaudi_guarded_failure"'
    assert_success
    assert_output_equals "ok
tree
htop
[]"
}
