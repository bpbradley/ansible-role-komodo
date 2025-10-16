# Inbound Connection Example

In some cases, connection to komodo core cannot be achieved in outbound mode,
so it is still possible for periphery to host an inbound server for core
to connect to.

There are some key differences to consider when setting up that are outlined here.

## Core Public Key

In Inbound mode, the core public key is crucial for authentication and should be set.
You can copy this by clicking the key icon in the header.

Consider encrypting with ansible-vault: `ansible-vault encrypt_string "<pubkey>"`

## Allowed IPs

In inbound mode, you can configure periphery to deny certain connecting IPs, to try to filter out
just the intended komodo core. In this example, the inventory has some host-specific settings describing what IPs are allowed to authenticate with periphery.

For example, in one of the deployments, periphery is deployed on the same system as core.
In this case, it is binding to the docker network directly,
and is specifying only the komodo core internal docker IP
for authentication.

## Usage

You can run this with `ansible-playbook playbooks/komodo.yml`

You can use also it to update / uninstall, or change the version by
overriding variables with `-e`

```sh
# Use latest instead of core
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=update" \
    -e "komodo_version=latest" 

# Uninstall and delete komodo service user
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=uninstall" \
    -e "komodo_delete_user=true" \
```
