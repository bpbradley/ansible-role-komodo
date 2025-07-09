# Basic Usage Example

This example shows how to use the most basic features, with a simple
inventory file and a straightforward playbook, to mostly allow the 
role and periphery to deploy with default settings.

It does not have any host specific setting, and just configures a few
override values in the playbook.

You can run this with `ansible-playbook playbooks/komodo.yml`

You can use also it to update / uninstall, or change the version by
overriding variables with `-e`

```sh
# Update to v1.18.4
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=update" \
    -e "komodo_version=v1.18.4" 

# Uninstall and delete komodo service user
ansible-playbook playbooks/komodo.yml \
    -e "komodo_action=uninstall" \
    -e "komodo_delete_user=true" \
```

