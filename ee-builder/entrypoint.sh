#!/usr/bin/env bash
set -e
[[ -n "$VAULT_PASS" && -z "$ANSIBLE_VAULT_PASSWORD_FILE" ]] \
    && export ANSIBLE_VAULT_PASSWORD_FILE=/etc/ansible/.vault_pass.sh

exec dumb-init -- /usr/bin/entrypoint "$@"
