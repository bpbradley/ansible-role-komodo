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

1. **Install** or **Update** Komodo Periphery as a systemd unit
1. **Create a komodo service user** to run the service
1. Supports both systemd **User Units** and **System Units**
1. **Uninstall** of periphery agent and removal of configuration files, and *optionally* deletion of service user.

## Required Role Variables

Only the `komodo_action` variable is required, to specify the intended behavior for the play.
Relying fully on defaults will work, but will result in a less secure setup as it will choose
an [inbound connection](#inbound-connection) without authentication.

>[!TIP]
> Refer to [Basic Installation](#basic-installation--setup) for a recommended simple and secure setup

| Variable                                 | Default               | Description                                                                       |
| ---------------------------------------- | ----------------------| --------------------------------------------------------------------------------- |
| **komodo_action**                        | `None`                | `install`, `update`, or `uninstall`                                               |

> [!NOTE]
> `install` and `update` are almost functionally identical, except that `install`
> by default allows creation of the `komodo_user`.
> See [Komodo User Management](#komodo-user-management).

## Version Management

* Set `komodo_version=X.Y.Z` to install a specific version.
* Set `komodo_version=latest` to install the newest GitHub release. 
* Set `komodo_version=core` to match the version reported by Komodo Core. Must provide `komodo_core_http_address` to probe core.
  * Core must expose a reachable `/version` endpoint (Komodo Core **v2.0.0+**)
  * **OR** For earlier Core versions (v1), provide API credentials as described in [Server Management](#server-management)
  * `komodo_core_http_address` must be reachable from the **Ansible control host**

| Variable                      | Default                             | Description                                                                                |
| ----------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------ |
| **komodo_version**            | `2.0.0`                             | Release tag, or `latest`/`core` for automatic versioning                                   |
| **komodo_core_http_address**  | Derived from `komodo_core_address`  | **Required when `komodo_version=core`.** ex. `https://komodo.example.com` or `http:IP:9120`|

## Connection Flow

Periphery can connect **Outbound** (Periphery -> Core) or **Inbound** (Core -> Periphery).
For deeper background, see [Inbound vs Outbound Connections](#inbound-vs-outbound-connections). 

As a rule of thumb, choose *one* connection flow per-host (they’re not mutually exclusive, but mixing modes on one host is rarely needed).

1. Recommendation is [Outbound](#outbound-connection) (Periphery -> Core), when topology allows it (Periphery can reach Core)
2. **Otherwise** use [Inbound](#inbound-connection) (Core -> Periphery)
3. [Legacy](#legacy-connection) when using Core version < 2.0.0

### Outbound Connection

> [!NOTE]
> Setting `komodo_core_address` coerces `komodo_server_enabled=false` (i.e., outbound-only)
> and sets `komodo_core_public_key` to a file reference for automatic core pinning (recommended)

| Variable                   | Default                                          | Description                                                                                                         |
| -------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| **komodo_core_address**    | `None`                                           | **Required.** WebSocket URL of Komodo Core (`wss://komodo.example.com` or `ws://IP:9120`).                          |
| **komodo_server_enabled**  | `false` when `komodo_core_address` is set        | Disables the inbound server when outbound is configured.                                                            |
| **komodo_connect_as**      | `{{ inventory_hostname }}`                       | Name of the server in Komodo Core this Periphery authenticates *as*.                                                |
| **komodo_private_key**     | `None`                                           | Periphery private key; public is derived. Auto-generated at `{{ komodo_root_directory }}/periphery.key` if omitted. |
| **komodo_core_public_key** | `file:{{ komodo_root_directory }}/keys/core.pub` | Optional pinning. Default pins the first Core encountered and stores it.                                            |
| **komodo_onboarding_key**  | `None`                                           | Allows Core to auto-create the server in Core. Generate in **Settings > Onboarding**. Disable after use.            |

### Inbound Connection

> [!IMPORTANT]
> When running inbound, set `komodo_core_public_key` to authenticate Core. Consider encrypting it with Ansible Vault.

| Variable                   | Default | Description                                                                                      |
| -------------------------- | ------- | ------------------------------------------------------------------------------------------------ |
| **komodo_server_enabled**  | `true`  | Enables the inbound server.                                                                      |
| **komodo_core_public_key** | `None`  | **Strongly recommended.** Core public key. click the key icon in Komodo Core header to copy.     |
| **komodo_allowed_ips**     | `[]`    | CIDRs/IPs allowed to access Periphery (empty = allow all).                                       |
| **komodo_ssl_enabled**     | `true`  | HTTPS between Core/Periphery. Autogenerates certs unless files provided.                         |
| **komodo_ssl_key_file**    | `None`  | Path to an existing key with ownership `komodo:komodo`.                                          |
| **komodo_ssl_cert_file**   | `None`  | Path to an existing cert with ownership `komodo:komodo`.                                         |

### Legacy Connection

> [!WARNING]
> Supported for backwards compatibility and required for Core < 2.0.0. On Core ≥ 2.0.0 you’ll see deprecation warnings.
> Migrate by replacing `komodo_passkeys` with `komodo_core_public_key`.

| Variable                  | Default | Description                                             |
| ------------------------- | ------- | ------------------------------------------------------- |
| **komodo_passkeys**       | `[]`    | **Deprecated.** List of passkeys accepted by Periphery. |
| **komodo_server_enabled** | `true`  | Enables the inbound server.                             |
| **komodo_bind_ip**        | `[::]`  | Bind address (`0.0.0.0` to force IPv4).                 |
| **komodo_allowed_ips**    | `[]`    | CIDRs/IPs allowed to access Periphery.                  |
| **komodo_ssl_enabled**    | `true`  | HTTPS enabled by default.                               |
| **komodo_ssl_key_file**   | `None`  | Path to an existing key with ownership `komodo:komodo`. |
| **komodo_ssl_cert_file**  | `None`  | Path to an existing cert with ownership `komodo:komodo`.|

## Key Management

Every Periphery deployment will have a private/public key pair used for mutual authentication
with Komodo Core using a key exchange process. For the most part, this role (and the default behavior of periphery)
try to minimize effort to manage these keys by the end user. For example, in [Outbound](#outbound-connection),
all keys can be completely managed securely with default settings.

If however you must manually set keys (as with `komodo_core_public_key` in Inbound mode), it is
highly recommended that these keys be managed in their own *file* rather than as a raw key in the config file.

The reason for this is that when keys are managed in files, key rotation for both Core and Periphery key pairs
can be managed. If these are not written to files, then a key rotation will break connection.

For that reason, all *raw keys* provided to either `komodo_core_public_key` or `komodo_private_key` will
be materialized to a file in `{{ komodo_root_directory }}/keys` by default. This behavior can be controlled
by overriding these variables.

| Variable                       | Default | Description                                                                   |
| ------------------------------ | --------| ----------------------------------------------------------------------------- |
| **allow_write_keys_to_files**  | `true`  | Raw keys are materialized to files in `{{ komodo_root_directory }}/keys`      |
| **allow_overwrite_key_files**  | `false` | If a file already exists for this key, it will only overwrite it if allowed.  |

## Komodo User Management

By default, the komodo user (i.e. the user perhiphery is run as) is managed by this role, and the level of management of the `komodo_user` is influenced by the `komodo_action`

| Variable                                     | Default                                | Description                                                                                                                                             |
| -------------------------------------------- | ---------------------------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **allow_create_komodo_user**                 | `true` on `install`, otherwise `false` | Allows `komodo_user` to be created. Will be created as a service account with no login, unless the user exists already in which case it wont be touched |
| **allow_modify_komodo_user**                 | `true`                                 | Allows the role to enable or disable linger, when `komodo_service_scope=user`, and allows the role to add the user to the `docker` group                |
| **allow_delete_komodo_user**                 | `false`                                | Allows the role to delete the `komodo_user` on `komodo_action=uninstall`. This **must** be set explicitly, it is never defaulted true                   |

## Systemd Configuration

This role supports running periphery under either the systemd **user** manager (i.e. `systemctl --user start periphery`) 
or the systemd **system** manager (i.e.`systemctl start periphery`). In both cases, the service process runs as `komodo_user`.

- In **user** scope, the service is managed by the per-user systemd instance and therefore *must* run as that user. 
  To have it start at boot without a login session, **linger** will be enabled for that user (`loginctl enable-linger komodo`) if `allow_modify_komodo_user=true`,
  which is the default.
- In **system** scope, the unit is installed under the system manager and explicitly drops privileges to `komodo_user` via `User=` in the unit file.

Least-privilege is the default, so **user** scope is recommended. For a deeper comparison, see [Systemd User vs System Units](#systemd-user-vs-system-units).

> [!NOTE]
> If switching between `user` and `system` mode, you should make sure to `uninstall` with the currently installed mode set first, then `install` or `update` in the desired mode.

| Variable                    | Default | Description                                                                            |
|-----------------------------|---------|----------------------------------------------------------------------------------------|
| **komodo_service_scope**    | `user`  | `user` or `system`. See [Systemd User vs System Units](#systemd-user-vs-system-units). |

## Periphery Specific Providers

You can define providers in the periphery configuration that will only be available to that deployment

| Variable                          | Default | Description                                                                                                      |
| --------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| **komodo_git_providers**          | `[]`    | Configure Periphery based git providers. Example below                                                           |
| **komodo_registry_providers**     | `[]`    | Configure Periphery based docker registries. Example below                                                       |

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

## Server Management

>[!IMPORTANT]
> Server management features are not needed at all when using **Outbound** connections. This will only be relevant to **Inbound** connections where there is no onboarding mechanism.
> If using outbound connections, simply use the `komodo_onboarding_key` and skip this section.

When enabled and provided with API credentials / details, the role can automatically create and update servers for you when using **Inbound** mode

| Variable                       | Default                            | Description                                                                                 |
| ------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------- |
| **enable_server_management**   | `false`                            | Allows the role to create / update servers automatically in Komodo Core                     |
| **server_name**                | `{{ inventory_hostname }}`         | Name under which the server is registered in Core.                                          |
| **server_address**             | `""`                               | Public URL advertised to Core (auto-detected when blank)                                    |
| **server_passkey**             | `""`                               | **DEPRECATED:** Passkey specific to this server                                             |
| **generate_server_passkey**    | `false`                            | **DEPRECATED:** Generate a random passkey                                                   |
| **komodo_core_api_key**        | `""`                               | API key used to authenticate to Core                                                        |
| **komodo_core_api_secret**     | `""`                               | Secret paired with the API key                                                              |
| **komodo_core_http_address**   | Derives from `komodo_core_address` | ex. `https://komodo.example.com` or `http:IP:9120`. Must be reachable by ansible localhost. |

## Additional Variables

Some additional variables to tweak settings or override default behavior.

| Variable                                          | Default                                         | Description                                                                                                     |
| ------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **komodo_user**                                   | `komodo`                                        | System user that owns files and runs the service                                                                |
| **komodo_group**                                  | `komodo`                                        | Group that owns files and runs the service                                                                      |
| **komodo_uid**                                    | `None`                                          | User ID for komodo_user (system-chosen by default)                                                              |
| **komodo_gid**                                    | `None`                                          | Group ID for komodo_group (system-chosen by default)                                                            |
| **komodo_home**                                   | `/home/{{ komodo_user }}`                       | Home directory of `komodo_user`                                                                                 |
| **komodo_default_terminal_command**               | `bash`                                          | The default terminal command used to init the shell                                                             |
| **komodo_extra_env**                              | `[]`                                            | Extra env vars available to periphery. Define in the same format as [Secrets](#adding-periphery-secrets)        |
| **komodo_agent_secrets**                          | `[]`                                            | List (name/value pairs) for secrets only available to the agent. See [Secrets](#adding-periphery-secrets)       |
| **komodo_config_dir**                             | `{{ komodo_home }}/.config/komodo`              | Directory that holds Komodo configuration files                                                                 |
| **komodo_config_file_template**                   | `periphery.config.toml.j2`                      | ([Refer to Note](#overriding-default-configuration-templates))                                                  |
| **komodo_config_path**                            | `{{ komodo_config_dir }}/periphery.config.toml` | Destination path of the rendered config file                                                                    |
| **komodo_service_file_template**                  | `periphery.service.j2`                          | ([Refer to Note](#overriding-default-configuration-templates))                                                  |
| **komodo_periphery_port**                         | `8120`                                          | TCP port the server listens on                                                                                  |
| **komodo_root_directory**                         | `{{ komodo_home }}/.komodo`                     | Default root directory for periphery                                                                            |
| **komodo_repo_dir**                               | `{{ komodo_root_directory }}/repos`             | Default root for repository check-outs                                                                          |
| **komodo_stack_dir**                              | `{{ komodo_root_directory }}/stacks`            | Default root for stack folders                                                                                  |
| **komodo_build_dir**                              | `{{ komodo_root_directory }}/build`             | Default root for builds                                                                                         |
| **komodo_stats_polling_rate**                     | `5-sec`                                         | Interval at which periphery polls the stack directory                                                           |
| **komodo_logging_level**                          | `info`                                          | Periphery log level                                                                                             |
| **komodo_logging_stdio**                          | `standard`                                      | Log output format                                                                                               |
| **komodo_logging_opentelemetry_service_name**     | `Komodo-Periphery`                              | Set the opentelemetry service name attached to the telemetry Periphery will send.                               |
| **komodo_logging_otlp_endpoint**                  | `""`                                            | Specify a opentelemetry otlp endpoint to send traces to.                                                        |
| **komodo_logging_pretty**                         | `false`                                         | Specify whether logging is more human readable.                                                                 |
| **komodo_logging_pretty_startup_config**          | `false`                                         | Specify whether startup config log is more human readable (multi-line)                                          |
| **komodo_disable_terminals**                      | `false`                                         | Disable the terminal APIs and disallow remote shell access through Periphery                                    |
| **komodo_disable_container_exec**                 | `false`                                         | Disable the container exec APIs and disallow remote container shell access through Periphery.                   |
| **komodo_container_stats_polling_rate**           | `30-sec`                                        | How often Periphery polls the host for container stats                                                          |
| **komodo_legacy_compose_cli**                     | `false`                                         | Whether stack actions should use `docker-compose` instead of `docker compose`                                   |
| **komodo_include_disk_mounts**                    | `[]`                                            | Optional. Only include mounts at specific paths in the disk report i.e. `["/mnt/include/1", "/mnt/include/2"]`  |
| **komodo_exclude_disk_mounts**                    | `[]`                                            | Optional. Don't include these mounts in the disk report. i.e. `["/mnt/exclude/1", "/mnt/exclude/2"]`            |
| **komodo_api_delegate_to**                        | `localhost`                                     | Sets the host (from ansible inventory) which API calls/version checks delegate to. Must be able to reach core   |

### Inbound vs Outbound Connections

Komodo 2.0.0 introduces the **Outbound Connection** model.
Prior to this milestone, all communication between Komodo Core and Periphery was **Inbound** to Periphery. 
This means that Periphery itself must host a server, which a “server” in Core is configured to reach out to and establish connection. 
Communication was established (usually) with TLS/SSL, and authentication required setting a passkey and an IP allow list to filter out connections from clients that are not the intended Komodo Core.
This all still works in v2 for compatibility, but it carries several issues.

1. **Reachability**: The Periphery host must be able to host a server, and that server must be accessible by Komodo Core. This sometimes required complex overlay networks and/or VPN configurations to do securely.
1. **Credential Security**: Passkey authentication transmits sensitive, *static* credentials.
1. **Credential Separation**: Unique credentials and rotation typically required API-based automation, adding complexity and API credential exposure risk.

Komodo 2.0.0 addresses the **network reachability** problem by allowing an **Outbound** flow **and** replaces passkey authentication in both directions with the [Noise Protocol](https://noiseprotocol.org/noise.html).
Specifically, it uses the [Noise XX Handshake](https://noiseprotocol.org/noise.html#handshake-patterns) which provides *mutual authentication* and *forward secrecy* for **Inbound and Outbound** connections alike.

It also introduces a number of additional convenience and security features that make it easier to be secure by default,
and largely removes the necessity of API-driven Server Management that was needed in v1 for full onboarding and passkey rotation automation.
With outbound connections, that API automation is unnecessary.

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

### Adding Periphery Secrets

[Secrets](https://komo.do/docs/resources/variables#defining-variables-and-secrets) can be bound directly to periphery agent in Komodo.
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
1. Create an `inventory/komodo.yml` file which specifies your komodo hosts, and the required connection configurations

    ```yaml
    komodo:
        hosts:
            # Outbound connetion, recommended
            komodo_periphery1:
                ansible_host: 192.168.10.20
                komodo_core_address: "wss://komodo.example.com" # or "ws://<komodo core ip>:9120
                komodo_connect_as: "server_name"
                komodo_server_enabled: false
            # Inbound connection if necessary for an isolated host
            komodo_periphery2:
                ansible_host: 192.168.10.21
                komodo_allowed_ips:
                    - "192.168.10.22" # Komodo core IP
                komodo_core_public_key: <public key copied from komodo core> 
    ```

1. Create a playbook which selects the role.

    `playbooks/komodo.yml`

    ```yaml
    ---
    - name: Manage Komodo Service
      hosts: komodo
      roles:
          - role: bpbradley.komodo
          komodo_action: "install" # default action
          komodo_version: "core"
          komodo_core_http_address: "https://komodo.example.com" # needed to use `core` versioning
    ```

1. Run the playbook

    Install using default values

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml
    ```

    Onboard a new server

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e komodo_action=install \
    -e komodo_onboarding_key=O-... \
    -l komodo_periphery1
    ```

    Install an older version instead

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e komodo_version=v1.16.11
    ```

    Update to the latest version

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e komodo_action=update \
    -e komodo_version=latest
    ```

    Uninstall the periphery agent and all installed files, and delete the user.

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e komodo_action=uninstall \
    -e allow_delete_komodo_user=true"
    ```

  ## More Examples / Advanced Features

  This guide only covers the basic information to get off the ground, but you can see more thorough examples
  and explanations in the [`examples/`](./examples) section.

  1. Basic usage demonstrating recommended outbound connections: [`examples/outbound`](./examples/outbound)
  1. Example using inbound connections: [`examples/inbound`](./examples/inbound)
  1. Building out full automation for komodo-managed periphery redeployment using ansible-in-docker with a custom ansible execution environment that includes this role: [`examples/komodo_automation`](./examples/komodo_automation)
