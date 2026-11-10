#!/usr/bin/env bats
# configs/configure-ssh.sh

load ../helper

setup() {
    gaudi_sandbox darwin
}

ssh_step() {
    step configs/configure-ssh.sh
}

@test "an existing ed25519 key is left alone" {
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAA existing\n' > "$HOME/.ssh/id_ed25519.pub"

    run ssh_step
    assert_success
    assert_output_contains "SSH key already available"
    refute_called "ssh-keygen"
}

@test "any other id_*.pub key counts as an existing key" {
    for key in id_rsa id_ecdsa id_ed25519_sk; do
        rm -rf "$HOME/.ssh"
        mkdir -p "$HOME/.ssh"
        printf 'key\n' > "$HOME/.ssh/$key.pub"
        run ssh_step
        assert_success
        assert_output_contains "SSH key already available"
    done
    refute_called "ssh-keygen"
}

@test "a key served by an SSH agent counts as an existing key" {
    export FAKE_SSH_AGENT_KEYS=1
    interactive

    run ssh_step
    assert_success
    assert_output_contains "SSH key already available"
    refute_called "ssh-keygen"
}

@test "without a terminal key generation is skipped instead of hanging" {
    run ssh_step </dev/null
    assert_success
    assert_output_contains "no terminal attached: skipping key generation"
    refute_called "ssh-keygen"
}

@test "--yes without a terminal still skips key generation" {
    export GAUDI_ASSUME_YES="true"
    run ssh_step </dev/null
    assert_success
    refute_called "ssh-keygen"
    refute_file_exists "$HOME/.ssh/id_ed25519"
}

@test "declining generates nothing" {
    interactive
    run ssh_step <<< "n"
    assert_success
    assert_output_contains "Generate an ed25519 key now? [Y/n]"
    refute_called "ssh-keygen"
}

@test "accepting generates an ed25519 key for the typed email and prints the public key" {
    interactive
    run ssh_step <<< $'\nsomeone@example.com'
    assert_success
    assert_output_contains "Email address for SSH key:"
    assert_called "ssh-keygen -t ed25519 -C someone@example.com -f $HOME/.ssh/id_ed25519"
    assert_file_exists "$HOME/.ssh/id_ed25519"
    assert_output_contains "Add this public key to GitHub"
    assert_output_contains "ssh-ed25519 AAAAFAKE someone@example.com"
}

@test "the .ssh directory is created private" {
    interactive
    run ssh_step <<< $'y\nsomeone@example.com'
    assert_success
    assert_equal "$(ls -ld "$HOME/.ssh" | cut -c1-10)" "drwx------"
}

@test "GAUDI_SSH_EMAIL skips the email prompt" {
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_success
    refute_output_contains "Email address for SSH key:"
    assert_called "ssh-keygen -t ed25519 -C preset@example.com"
}

@test "an invalid email followed by end of input skips generation" {
    interactive
    run ssh_step <<< $'y\nnot-an-email'
    assert_success
    assert_output_contains "Please enter a valid email address"
    assert_output_contains "No email provided: skipping key generation"
    refute_called "ssh-keygen"
}

@test "a failing ssh-keygen is recorded" {
    interactive
    export FAKE_SSH_KEYGEN_FAIL=1 GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_failure 1
    assert_output_contains "SSH key generation"
    refute_output_contains "Add this public key"
}

@test "macOS stores the key in the keychain" {
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_success
    assert_called "ssh-add --apple-use-keychain $HOME/.ssh/id_ed25519"
}

@test "Linux adds the key to the agent without the keychain flag" {
    gaudi_sandbox debian
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_success
    assert_called "ssh-add $HOME/.ssh/id_ed25519"
    refute_called "--apple-use-keychain"
}

@test "an agent is started only when none is running" {
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_success
    assert_called "ssh-agent -s"

    gaudi_sandbox darwin
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com" SSH_AUTH_SOCK="$SANDBOX/existing.sock"
    run ssh_step <<< "y"
    assert_success
    refute_called "ssh-agent"
}

@test "a machine without ssh-add still gets its key" {
    remove_tool ssh-add ssh-agent
    interactive
    export GAUDI_SSH_EMAIL="preset@example.com"
    run ssh_step <<< "y"
    assert_success
    assert_file_exists "$HOME/.ssh/id_ed25519.pub"
}
