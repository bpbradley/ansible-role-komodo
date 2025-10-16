# Outbound Connection example

This example shows the recommended setup in outbound mode for
all servers.

You can run with `ansible-playbook playbooks/komodo.yml`

You can use also it to update / uninstall, or change the version by
overriding variables with `-e`

You can also onboard a server that doesn't yet exist in komodo core
once you add it to your inventory.

`ansible-playbook playbooks/komodo.yml -e komodo_onboarding_key=O-... -l komodo_host2`
