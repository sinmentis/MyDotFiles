#!/usr/bin/env bash

vm_is_dry_run() {
    [ "${DOTFILES_DRY_RUN:-0}" = "1" ]
}

vm_print_command() {
    printf '[vm-prep] DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
}

vm_run() {
    if vm_is_dry_run; then
        vm_print_command "$@"
        return 0
    fi
    "$@"
}

vm_sudo() {
    vm_run sudo "$@"
}
