# Basic Example with Authentication

This example shows how you can setup some basic authentication features.

## Allowed IPs

The inventory has some host-specific settings describing what IPs are allowed
to authenticate with periphery. In one of the hosts, no bind IP
is specified which will cause periphery to bind to the default
`[::]`. In this case, the allowed IPs must have the ipv6 prefix.

The other periphery is deployed on the same system as core.
In this case, it is binding to the docker network directly,
and is specifying only the komodo core internal docker IP
for authentication.

## Passkeys

We are directly setting the passkeys in the playbook which will
be applied to any host using this playbook.

It sets two passkeys, meaning that any core instance must be
configured to send one of those passkeys when communicating
with periphery.

## Vault

Note that you can, and should encrypt variables with ansible vault.
`ansible-vault encrypt_string "passkey1"` for example.

## Usage

You can run this with `ansible-playbook playbooks/komodo.yml`

You can use also it to update / uninstall, or change the version by
overriding variables with `-e`

```sh
# Update to latest
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=update" \
    -e "komodo_version=latest" 

# Uninstall and delete komodo service user
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=uninstall" \
    -e "komodo_delete_user=true" \
```

