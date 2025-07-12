#!/usr/bin/env bash
[[ -z "$VAULT_PASS" ]] && { echo "VAULT_PASS unset" >&2; exit 1; }
printf '%s' "$VAULT_PASS"