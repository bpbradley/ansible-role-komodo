# Ansible Role for Komodo

This role is designed for managing systemd deployments of the [komodo](https://github.com/moghtech/komodo) periphery agent,
minimizing permissions by creating a service user and running the service as that user.
The role supports both systemd **user** and **system** scopes; in both cases the service runs as the unprivileged `komodo` user.

The user will only have access to:
* Its configuration files
* The periphery agent binary
* Its SSL certificates/Authentication Keys for connection to Komodo Core
* Its repo, stacks, and build directories, located in `komodo_user` home directory by default

In this way, it should have no more access to the host system than it would running
in a docker container. But since it is running directly on the host filesystem, it should eliminate
the numerous edge cases which appear when running it as a docker container.

## Features

1. **Install** or **Update** Komodo Periphery as a systemd unit, with all available periphery configurations adjustable as role variables.
1. Can **Create a komodo service user** to run the service, unless an existing user is set as a role varaible
1. Install as a systemd **User Unit** or **System Unit**
1. Supports clean **Uninstall** of periphery agent and removal of configuration files, and *optionally* deletion of service user.

## Required Role Variables

For all role variables, see [`defaults/main.yml`](./defaults/main.yml) for more details. Below are the only required variables if you are otherwise okay with defaults.

| Variable                                  | Default               | Description                                                                       |
| ----------------------------------------- | ----------------------| --------------------------------------------------------------------------------- |
| **komodo\_action**                        | `None`                | `install`, `update`, or `uninstall`                                               |
| **komodo\_version**                       | `v1.19.5`             | Release tag, or `latest`/`core` for [automatic versioning](#automatic-versioning) |

> [!NOTE]
> `install` and `update` are almost functionally identical, except that `install`
> by default allows creation of the `komodo_user`.
> See [Komodo User Management](#komodo-user-management).

## Komodo User Management

By default, the komodo user (i.e. the user perhiphery is run as) is managed by this role, and the level of management of the `komodo_user` is influenced by the `komodo_action`

| Variable                                     | Default                                | Description                                                                                                                                             |
| -------------------------------------------- | ---------------------------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **allow\_create\_komodo\_user**              | `true` on `install`, otherwise `false` | Allows `komodo_user` to be created. Will be created as a service account with no login, unless the user exists already in which case it wont be touched |
| **allow\_modify\_komodo\_user**              | `true`                                 | Allows the role to enable or disable linger, when `komodo_service_scope=user`, and allows the role to add the user to the `docker` group                |
| **allow\_delete\_komodo\_user**              | `false`                                | Allows the role to delete the `komodo_user` on `komodo_action=uninstall`. This **must** be set explicitly, it is never defaulted true                   |

## Connection Flow Variables

Introduced in Komodo 2.0.0, connection between Komodo Core and Periphery is *highly* configurable, and far more secure than in Komodo v1. In Komodo v1, *all* communication
between Komodo Core and Periphery was **Inbound** to periphery. This means that Periphery itself must host a server, which a "server" in core is configured to reach out to
and establish connection. Then, communication was established (usually) with ssl, and authentication required setting a passkey and IP allow list to filter out connections
from clients that are not the intended Komodo Core. This worked, and still works in v2 for compatibility, but it carries several issues.

1. The periphery host must be able to host a server, and that server must be accessible by komodo core. This often required complex overlay networks and/or VPN configurations to do securely.
2. The passkey authentication method requires commununication of sensitive, static credentials over the network
3. Credential separation (and credential rotation) between servers required API based automation, which carries the risk of API credential exposure

To that end, Komodo 2.0.0 solves these issues by allowing an **Outbound Connection** flow, as well as completely changing how Core <-> Periphery authenticates by adopting the [Noise Protocol](https://noiseprotocol.org/noise.html),
and more specifically, the [Noise XX Handshake](https://noiseprotocol.org/noise.html#handshake-patterns) which allows *mutual authentication* and forward secrecy.

It also introduces a number of additional convenience and security features which make it easier to be secure by default, and largely removes the necessity of API driven [Server Management](#server-management) which was
needed in V1 for full onboarding and passkey rotation automation. **This is no longer necessary at all with outbound connections.**

>[!IMPORTANT]
> I've done my best to create sane defaults to simplify the configuration as much as possible,
> but for compatibility reasons as users migrate from V1 -> V2, I made **Inbound Connections** the
> default behavior still, but pushing users towards using the new authentication flow instead of passkeys.
> This way, users should be able to migrate to V2 safely without any configuration issues with their *existing* infrastructure
> and then migrate to the new connection flows when convenient over time.
> That said, I still **reccomend** that people migrate to **Outbound Connections** when possible,
> Which will generally be more secure, and allows greater onboarding / connection automation.

### Outbound Connection Flow

As noted, this is the **recommended** flow, but for compatibility reasons with V1, it is not the **default** flow. In outbound mode,
periphery must know how to reach komodo core, and it must know the *name* of the server on komodo core that it is connecting as.
It also must have a valid private/public key pair, but this will be *generated* by default, and so they do not need to be provided.

Setting the `komodo_core_address` will coerce the related role variables towards an outbound default, so this is the only *required* variable to
establish outbound mode. That said, a `komodo_connect_as` variable should be set for existing servers, because it will otherwise default
to `{{ansible_hostname}}`, and it doesn't hurt to explicitly set other variables rather than relying on default behavior.

### Inbound Connection Flow

### Legacy Connection Flow

## Security / Authentication Variables

These variables can be set to enforce authentication, SSL, or IP whitelists between
periphery and Komodo Core. The only feature enabled by default is ssl.

| Variable                                  | Default | Description                                                                                                                                                                                                         |
| ----------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **komodo\_passkeys**                      | `[]`    | List of passkeys the server will accept                                                                                                                                                                             |
| **komodo\_bind\_ip**                      | `[::]`  | IP address the server binds to (`0.0.0.0` to force IPv4 only)                                                                                                                                                       |
| **komodo\_allowed\_ips**                  | `[]`    | IP list allowed to access periphery (empty list means all allowed)                                                                                                                                                  |
| **komodo\_ssl\_enabled**                  | `true`  | Enable HTTPS between core/periphery when `true`. By default, certs are autogenerated, unless keys are provided with `komodo_ssl_key_file/komodo_ssl_cert_file`                                                      |
| **komodo\_ssl\_key\_file**                | `None`  | Key file used for ssl connection to core. If not provided, periphery will auto-generate in `{{ komodo_root_directory}}/ssl`. If specified, the files must exist on system already, with ownership `komodo:komodo`   |
| **komodo\_ssl\_\cert_file**               | `None`  | Cert file used for ssl connection to core. If not provided, periphery  will auto-generate in `{{ komodo_root_directory}}/ssl`. If specified, the files must exist on system already, with ownership `komodo:komodo` |
| **komodo\_agent\_secrets**                | `[]`    | List (of name/value pairs) for secrets only available to the agent. See [Adding Periphery Secrets](#adding-periphery-secrets)                                                                                       |

## Systemd Configuration

This role supports running periphery under either the systemd **user** manager (i.e. `systemctl --user start periphery`) 
or the systemd **system** manager (i.e.`systemctl start periphery`). In both cases, the service process runs as `komodo_user`.

- In **user** scope, the service is managed by the per-user systemd instance and therefore *must* run as that user. 
  To have it start at boot without a login session, **linger** will be enabled for that user (`loginctl enable-linger komodo`) if `allow_modify_komodo_user=true`,
  which is the default.
- In **system** scope, the unit is installed under the system manager and explicitly drops privileges to `komodo_user` via `User=` in the unit file.

Least-privilege is the default, so **user** scope is recommended. For a deeper comparison, see [Systemd User vs System Units](#systemd-user-vs-system-units).

>[!NOTE]
> If switching between `user` and `system` mode, you should make sure to `uninstall` with the currently installed mode set first, then `install` or `update` in the desired mode.

| Variable                    | Default | Description                                                                            |
|-----------------------------|---------|----------------------------------------------------------------------------------------|
| **komodo\_service\_scope**  | `user`  | `user` or `system`. See [Systemd User vs System Units](#systemd-user-vs-system-units). |


## Server Management

When enabled and provided with API credentials / details, the role can automatically create and update servers for you. Including the ability to 
set *per-periphery* passkeys, rather than using global ones. Currently, that ability can only be done via the API. In order to use this feature, you must provide valid API Credentials, 

>[!NOTE] 
> You must also set `komodo_core_http_address` to the core address which is reachable from the ansible local node (because API calls are delegated to localhost).
> i.e. `https://komodo.example.com`

| Variable                       | Default                    | Description                                                                                     |
| ------------------------------ | -------------------------- | ----------------------------------------------------------------------------------------------- |
| **enable\_server\_management** | `false`                    | Allows the role to create / update servers automatically in Komodo Core                         |
| **server\_name**               | `{{ inventory_hostname }}` | Name under which the server is registered in Core.                                              |
| **server\_address**            | `""`                       | Public URL advertised to Core (auto-detected when blank)                                        |
| **server\_passkey**            | `""`                       | Passkey specific to this server (merges with `komodo_passkeys` for periphery deployment.        |
| **generate\_server\_passkey**  | `false`                    | Generate a random passkey ([See below for special notes on this](#note-on-generated-passkeys) ) |
| **komodo\_core\_api\_key**     | `""`                       | API key used to authenticate to Core                                                            |
| **komodo\_core\_api\_secret**  | `""`                       | Secret paired with the API key                                                                  |

## Periphery Specific Providers

You can define providers in the periphery configuration that will only be available to that deployment

| Variable                          | Default | Description                                                                                                      |
| --------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| **komodo\_git\_providers**        | `[]`    | Configure Periphery based git providers. Example below                                                           |
| **komodo\_registry\_providers**   | `[]`    | Configure Periphery based docker registries. Example below                                                       |

Below are examples of the expected data structures

```yaml
# Define periphery specific git providers
komodo_git_providers:
  - domain: "github.com"
    accounts:
      - username: "alice"
        token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <redacted>
      - username: "bob"
        token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <redacted>
# Define periphery specific registry providers
komodo_registry_providers:
  - domain: "ghcr.io"
    organizations:
      - "MyOrg"
    accounts:
      - username: "alice"
        token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <redacted>
      - username: "bob"
        token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <redacted>
```

## Additional Variables

Some additional variables to tweak settings or override default behavior.

| Variable                                          | Default                                         | Description                                                                                                     |
| ------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **komodo\_user**                                  | `komodo`                                        | System user that owns files and runs the service                                                                |
| **komodo\_group**                                 | `komodo`                                        | Group that owns files and runs the service                                                                      |
| **komodo\_uid**                                   | `<not-set>`                                     | User ID for komodo\_user (system-chosen by default)                                                             |
| **komodo\_gid**                                   | `<not-set>`                                     | Group ID for komodo\_group (system-chosen by default)                                                           |
| **komodo\_home**                                  | `/home/{{ komodo_user }}`                       | Home directory of `komodo_user`                                                                                 |
| **komodo\_extra\_env**                            | `[]`                                            | Extra env vars available to periphery. Define in the same format as [Secrets](#adding-periphery-secrets)        |
| **komodo\_config\_dir**                           | `{{ komodo_home }}/.config/komodo`              | Directory that holds Komodo configuration files                                                                 |
| **komodo\_config\_file\_template**                | `periphery.config.toml.j2`                      | ([Refer to Note](#overriding-default-configuration-templates))                                                  |
| **komodo\_config\_path**                          | `{{ komodo_config_dir }}/periphery.config.toml` | Destination path of the rendered config file                                                                    |
| **komodo\_service\_file\_template**               | `periphery.service.j2`                          | ([Refer to Note](#overriding-default-configuration-templates))                                                  |
| **komodo\_periphery\_port**                       | `8120`                                          | TCP port the server listens on                                                                                  |
| **komodo\_root\_directory**                       | `{{ komodo_home }}/.komodo`                     | Default root directory for periphery                                                                            |
| **komodo\_repo\_dir**                             | `{{ komodo_root_directory }}/repos`             | Default root for repository check-outs                                                                          |
| **komodo\_stack\_dir**                            | `{{ komodo_root_directory }}/stacks`            | Default root for stack folders                                                                                  |
| **komodo\_build\_dir**                            | `{{ komodo_root_directory }}/build`             | Default root for builds                                                                                         |
| **komodo\_stats\_polling\_rate**                  | `5-sec`                                         | Interval at which periphery polls the stack directory                                                           |
| **komodo\_logging\_level**                        | `info`                                          | Periphery log level                                                                                             |
| **komodo\_logging\_stdio**                        | `standard`                                      | Log output format                                                                                               |
| **komodo\_logging\_opentelemetry\_service\_name** | `Komodo-Periphery`                              | Set the opentelemetry service name attached to the telemetry Periphery will send.                               |
| **komodo\_logging\_otlp\_endpoint**               | `""`                                            | Specify a opentelemetry otlp endpoint to send traces to.                                                        |
| **komodo\_logging\_pretty**                       | `false`                                         | Specify whether logging is more human readable.                                                                 |
| **komodo\_logging\_pretty\_startup\_config**      | `false`                                         | Specify whether startup config log is more human readable (multi-line)                                          |
| **komodo\_disable\_terminals**                    | `false`                                         | Disable the terminal APIs and disallow remote shell access through Periphery                                    |
| **komodo\_disable\_container\_exec**              | `false`                                         | Disable the container exec APIs and disallow remote container shell access through Periphery.                   |
| **komodo\_container\_stats\_polling\_rate**       | `30-sec`                                        | How often Periphery polls the host for container stats                                                          |
| **komodo\_legacy\_compose\_cli**                  | `false`                                         | Whether stack actions should use `docker-compose` instead of `docker compose`                                   |
| **komodo\_include\_disk\_mounts**                 | `[]`                                            | Optional. Only include mounts at specific paths in the disk report i.e. `["/mnt/include/1", "/mnt/include/2"]`  |
| **komodo\_exclude\_disk\_mounts**                 | `[]`                                            | Optional. Don't include these mounts in the disk report. i.e. `["/mnt/exclude/1", "/mnt/exclude/2"]`            |

### Systemd User vs System Units

Systemd has two distinct kinds of managers for running services.

- The **System Manager** (i.e. `systemctl`) which is directly started by the kernel as the first user-space process (PID 1).
It helps to boot the system, manages networking, other system services, etc.
- **User Managers** (i.e. `systemctl --user`) for each user on the system, which are session-scoped init systems and manages services *as the running user*

They exist side-by-side for different purposes. Some of the relevant differences for this role come down to:

- **Privilege / Isolation**: User services *must* run as the same user as the user manager. 
So privilege escalation should not be possible even with misconfiguration. Processes in user scopes should have cgroup-isolation from system services.
- **Lifecycle**: User services tie to, obviously, the users session. Running with a service account can be tricky, and it requires linger-mode to be enabled for the user
to keep the process alive after boot. It also makes debugging a little trickier, because you need to run commands from the proper runtime environment.
- **Dependency Separation**: Each manager has its *own targets and units*. So a user unit cannot (or should not) try to order after or depend on system targets.
For example, in `system` mode, we can depend on `network-online.target`, but we cannot in `user` mode.

There are many other subtle differences of course, but these are probably the main considerations when choosing which type of deployment makes the most sense for this role.

Here is a quick comparison of how exactly the services are deployed when using this role, to understand some of the implications.

|                          | **User units**                                                                                                  | **System units**                                                                      |
|--------------------------|-----------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Manager                  | `systemctl --user`                                                                                              | `systemctl`                                                                           |
| Privilege                | *Can only* run as `komodo_user`                                                                                 | Runs as `komodo_user` via privilege-drop in the Unit file with `User={{komodo_user}}` |
| Lifecycle                | User session; requires linger mode with `loginctl enable-linger komodo` (needs `allow_modify_komodo_user=true`) | Machine boot; starts via system target `multi-user.target`                            |
| Unit locations           | `{{ komodo_home }}/.config/systemd/user/…`                                                                      | `/etc/systemd/system`                                                                 |
| Capture Logs             | `sudo -u komodo journalctl --user -u periphery`                                                                 | `journalctl -u periphery`                                                             |
| Manually Control Service | `sudo -u komodo XDG_RUNTIME_DIR="/run/user/$(id -u komodo)" systemctl start --user periphery`                   | `systemctl start periphery`                                                           |
| Targets / Ordering       | Uses `default.target`, and relies on restart policy to reliably handle startup failures                         | Uses `multi-user.target` and `After=`/`Wants=network-online.target`                   |

A rule of thumb would probably be to stick with `user` mode for home use, as it is unlikely you will be impacted by any of the complications associated with it.
Otherwise, consider `system` mode when you want to minimize friction with managing the service, and have a more reliable dependency ordering.

### Automatic Versioning

Set `komodo_version` to `latest` to determine the latest release from GitHub and install that. You can also specify `komodo_version=core` and the role will
request the currently installed version on Komodo Core, and install the matching version. In order to use `core`, you must provided a valid address to reach the `/version` endpoint for core (`v2.0.0` and later only), or if using an earlier version you must provide API credentials as in [Server Management](#server-management)

| Variable                                          | Default                                         | Description                                                                                                                                                                            |
| ------------------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **komodo\_core\_http\_address**                   | Tries to derive from `komodo_core_address`      | This is the http endpoint for core, reachable by ansible localhost. If none provided, but a `komodo_core_address` is for outbound mode, attempts to derive the http endpoint from that |


### Note on Generated Passkeys

Enabling passkey generation for unique periphery passkeys with `generate_server_passkey=true` is potentially valuable, but if doing so remember to *always* enable
this feature whenever you update or install that server. The generated passkey is not saved, it is used to configure periphery at the time of install and then thrown away.

So for example, if you generated a random passkey on `install`, and then *DIDN'T* generate or set a passkey
on a future `update`, the role will not have knowledge of a server passkey at all, and it will simply delete the randomly generated one that was previously provided,
and it will not enforce passkey authentication, which is likely not the desired behavior. 

Basically, the simple advice is to *ALWAYS* have `generate_server_passkey=true` or *ALWAYS* have `generate_server_passkey=false` for each server. I recommend setting
these variables directly in an inventory file. See [`examples/server_management/inventory/all.yml`](./examples/server_management/inventory/all.yml) for an example.

If this is not preferred, you can always generate on install, and then record the generated passkeys and include that explicitly in your `komodo_passkeys` from thereon.
Or you can of course just always set your own randomly generated passkeys.

### Overriding default configuration templates

In some cases, it may be desirable to have more control over the exact service files and/or configuration files deployed to each periphery node.
In this case, the default / interpolated configurations and service files may not be ideal. These configurations can be overridden by manually providing
the config and/or service files and setting them in your playbook to `komodo_config_file_template` and `komodo_service_file_template`, for the
periphery configuration and the systemd service file, respectively.

Note that in doing so, the deployed files will be exactly as you specify, and they will always take precedence over any other specified variables.

### Adding Periphery Secrets

[Secrets](https://komo.do/docs/variables#defining-variables-and-secrets) can be bound directly to periphery agent in Komodo.
This can be achieved with this role by adding your secrets as a list of name/value pairs containing your variable name and its value.

For example, you could add this directly to the inventory for a particular host.

```yaml
komodo_agent_secrets:
  - name: "SECRET"
    value: "this-is-a-secret"
  - name: "ANOTHER_SECRET" 
    value: "also-a-secret"
  - name: "SUPER_SECRET"
    value: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653762316464626437653766643665373063...
```

## Basic Installation / Setup

> [!TIP]
> Before running the role, you can run it safely in dry-run more with `--check --diff`
> Note that a few tasks will error (and be ignored, not failed) in dry run mode, notably ones that require
> the existence of the `komodo_user` during `install`, because the roles is unable to
> actually create the user in a dry-run.

1. `ansible-galaxy role install bpbradley.komodo`
2. Create an `inventory/komodo.yml` file which specifies your komodo hosts and indicates the allowed_ips if desired
    ```yaml
    komodo:
        hosts:
            komodo_periphery1:
                ansible_host: 192.168.10.20
                komodo_allowed_ips:
                    - "127.0.0.1"
                komodo_bind_ip: 0.0.0.0
            komodo_periphery2:
                ansible_host: 192.168.10.21
                komodo_allowed_ips:
                    - "::ffff:192.168.10.20"
    ```
   
4. **Optional** but recommended. Set an encrypted passkey using `ansible-vault` which matches the passkey set in Komodo Core.

    ```sh
    ansible-vault encrypt_string 'supersecretpasskey'
    ```
    You will get an output like this, which we will use later. 

    ```
    !vault |
      $ANSIBLE_VAULT;1.1;AES256
      65353234373130353539663661376563613539303866643963363830376661316638333139343366
      3563656637303235373336336131346338336634653232300a313736396336316330666237653237
      64613231323433373637313462633863613732653136366462313134393938623136326633346166
      3834333462333162310a313037306336613061313733363862633437376133316234326431633131
      35386565333538623231643433396334323132616438353839663534373030393266
    ```

    Note that you will need to now input the password you entered every time you run this role,
    or you can create a password file for automation.

    ```sh
    echo "your password" > .vault_pass
    chmod 600 .vault_pass
    ```

    Now you can call your playbook with `--vault-password-file .vault_pass`

5. Create a playbook which selects the role. You can create multiple playbooks for install/uninstall/update, or just one
playbook and control behavior with variables. Here is an example of doing it with just one playbook.

    `playbooks/komodo.yml`

    ```yaml
    ---
    - name: Manage Komodo Service
      hosts: komodo
      roles:
          - role: bpbradley.komodo
          komodo_action: "install"
          komodo_version: "latest"
          komodo_passkeys: 
            - !vault |
                $ANSIBLE_VAULT;1.1;AES256
                65353234373130353539663661376563613539303866643963363830376661316638333139343366
                3563656637303235373336336131346338336634653232300a313736396336316330666237653237
                64613231323433373637313462633863613732653136366462313134393938623136326633346166
                3834333462333162310a313037306336613061313733363862633437376133316234326431633131
                35386565333538623231643433396334323132616438353839663534373030393266
    ```
   
6. Run the playbook

    Install using default values

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    --vault-password-file .vault_pass
    ```

    Install an older version instead

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e "komodo_version=v1.16.11" \
    --vault-password-file .vault_pass
    ```

    Update to the latest version

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e "komodo_action=update" \
    -e "komodo_version=latest" \
    --vault-password-file .vault_pass

    ```

    Uninstall the periphery agent and all installed files, and delete the user.

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e "komodo_action=uninstall" \
    -e "allow_delete_komodo_user=true" \
    --vault-password-file .vault_pass
    ```

  ## More Examples / Advanced Features

  This guide only covers the basic information to get off the ground, but you can see more thorough examples
  and explanations in the [`examples/`](./examples) section.

  1. Basic installation example with very little customization: [`examples/basic`](./examples/basic)
  2. Example using authentication with allowed IPs and global passkeys: [`examples/auth`](./examples/auth)
  3. Example showing server management functions and unique server passkeys: [`examples/server_management`](./examples/server_management)
  4. Building out full automation for komodo-managed periphery redeployment using ansible-in-docker with a custom ansible execution environment that includes this role: [`examples/komodo_automation`](./examples/komodo_automation)
