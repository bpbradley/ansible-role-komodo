# Server Management / Advanced Authentication

This example is fairly exhaustive on all the things you can do.
Here, periphery is deployed as normal, but when server management is enabled,
the role will automatically create (or update if already existing)
the server in Komodo Core automatically, through the Komodo API.

It extends similar concepts from the `examples/auth` example,
but also demonstrates some advanced authentication features that
are only possible (right now) via API with Komodo, such as
specifying *per-server* passkeys, and being able to randomly
generate and rotate server passkeys on every update/install.

## Server management

A new section in the inventory was added for some common vars
for komodo hosts. Here we put the defaut settings, enabling server management,
and adding the API credentials generated from Komodo Core which you can
generate in **Settings > Profile > New Api Key +**

Reminder to encrypt your API credentials with `ansible-vault`

On `komodo_host1`, the host which is on the same machine as core,
we are manually setting the server address to `https://host.docker.internal:{{ komodo_periphery_port }}`
since we are specifying a unique bind address to the docker network. In this setup,
this host does not have any passkeys configured.

All the other servers will be allowed to automatically determine their server address, if they can.
If we tried to allow `komodo_host1` to automatically detect the server address, it would fail.
That is because the detection works by getting a route to komodo core via the supplied API url.
In this case, it would likely determine that `komodo.example.com` is located at `10.1.10.4`,
but since we bound periphery to the docker network, it can't be reached at that address. It
can only be reached on the docker network directly, and so the detected route would not be valid.

So basically, the automatic detection will *usually* work fine, but may have issues in unique
circumstances/configurations. And so you can always just specify the address manually.

`komodo_host4` has overridden the default behavior, and disabled server management.
This host is defining its own `komodo_passkeys` and basically behaving the same way
that all hosts in `examples/auth` did.

## Passkeys

Now, with server management, we can set periphery-unique passkeys, so
those can be set with `server_passkey: some-secret-passkey` as `komodo_host3` does,
or you can even allow the role to automatically generate a *new* unique passkey
with every run, effectively rotating passkeys every update. This is enabled
in `komodo_host2` settings. 

The `server_passkey`, either explicitly provided or randomly generated, will
ultimately be *merged* with the `komodo_passkeys` otherwise defined.

So when periphery is deployed on `komodo_host3` for example, it will allow
access by passkeys `passkey` *and* `some-secret-passkey`. Note that neither of
these variables are required, but both will be honored if provided.

`komodo_host4` obviously does not include a `server_passkey`, because it cannot
since it disabled server_management. But it did override the default global passkeys.

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
