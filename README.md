# Ansible Role for Komodo

This role is designed for managing systemd deployments of the [komodo](https://github.com/moghtech/komodo) periphery agent
trying to minimize the permissions available to the service by creating a service user
and running the systemd service as that user. The user will only have access to:

* It's configuration files
* The periphery agent binary
* It's ssl certificates for establishing a TLS connection with Komodo Core
* It's repo and stacks directories, located in the komodo users home directory

In this way, it should have no more access to the host system than it would running
in a docker container. But since it is running directly on the host filesystem, it should eliminate
the numerous edge cases which appear when running it as a docker container.

## Features

1. **Install** the Komodo Periphery agent, creating and sandboxing the `komodo` user.
2. **Update** the Komodo Periphery agent by specifying a new version.
3. **Uninstall** the Komodo Periphery agent, optionally removing the `komodo` user and home directories.
4. **Manage Servers** in Komodo Core directly, so that you don't have to manually add/update them in core after deployment.

## Required Role Variables

For all role variables, see [`defaults/main.yml`](./defaults/main.yml) for more details. Below are the only required variables if you are otherwise okay with defaults.

| Variable                                  | Default                                         | Description                                                       |
| ----------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| **komodo\_action**                        | `None`                                          | `install`, `update`, or `uninstall`                               |
| **komodo\_version**                       | `v1.18.4`                                       | Release tag of Komodo Periphery to deploy                         |

## Security / Authentication Variables

| Variable                                  | Default                                         | Description                                                       |
| ----------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| **komodo\_passkeys**                      | `[]`                                            | List of passkeys the server will accept                           |
| **komodo\_bind\_ip**                      | `[::]`                                          | IP address the server binds to (`0.0.0.0` to force IPv4 only)     |
| **komodo\_allowed\_ips**                  | `[]`                                            | IP list allowed to access periphery (empty list means all allowed)|
| **ssl\_enabled**                          | `true`                                          | Enable HTTPS links in generated URLs when `true`                  |

## Server Management

When enabled and provided with API credentials / details, the role can automatically create and update servers for you. Including the ability to 
set *per-periphery* passkeys, rather than using global ones. Currently, that ability can only be done via the API.

| Variable                       | Default                    | Description                                                                                     |
| ------------------------------ | -------------------------- | ----------------------------------------------------------------------------------------------- |
| **enable\_server\_management** | `false`                    | Allows the role to create / update servers automatically in Komodo Core                         |
| **komodo\_core\_url**          | `""`                       | Base URL of the Komodo Core API (e.g. `https://komodo.example.com`)                             |
| **komodo\_core\_api\_key**     | `""`                       | API key used to authenticate to Core                                                            |
| **komodo\_core\_api\_secret**  | `""`                       | Secret paired with the API key                                                                  |
| **server\_name**               | `{{ inventory_hostname }}` | Name under which the server is registered in Core.                                              |
| **server\_address**            | `""`                       | Public URL advertised to Core (auto-detected when blank)                                        |
| **server\_passkey**            | `""`                       | Passkey specific to this server (merges with `komodo_passkeys` for periphery deployment.        |
| **generate\_server\_passkey**  | `false`                    | Generate a random passkey ([See below for special notes on this](#note-on-generated-passkeys) ) |

## Additional Variables

Some additional variables to tweak settings or override default behavior.

| Variable                                  | Default                                         | Description                                                       |
| ----------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| **komodo\_user**                          | `komodo`                                        | System user that owns files and runs the service                  |
| **komodo\_group**                         | `komodo`                                        | Group that owns files and runs the service                        |
| **komodo\_home**                          | `/home/{{ komodo_user }}`                       | Home directory of `komodo_user`                                   |
| **komodo\_delete\_user**                  | `None`                                          | Only when `komodo_action=uninstall`, *deletes* `komodo_user`      |
| **komodo\_config\_dir**                   | `{{ komodo_home }}/.config/komodo`              | Directory that holds Komodo configuration files                   |
| **komodo\_config\_file\_template**        | `periphery.config.toml.j2`                      | ([Refer to Note](#overriding-default-configuration-templates))    |
| **komodo\_config\_path**                  | `{{ komodo_config_dir }}/periphery.config.toml` | Destination path of the rendered config file                      |
| **komodo\_service\_dir**                  | `{{ komodo_home }}/.config/systemd/user`        | Directory for systemd user-mode unit files                        |
| **komodo\_service\_file\_template**       | `periphery.service.j2`                          | ([Refer to Note](#overriding-default-configuration-templates))    |
| **komodo\_service\_path**                 | `{{ komodo_service_dir }}/periphery.service`    | Destination path of the rendered service file                     |
| **periphery\_port**                       | `8120`                                          | TCP port the server listens on                                    |
| **repo\_dir**                             | `{{ komodo_home }}/.komodo/repos`               | Default root for repository check-outs                            |
| **stack\_dir**                            | `{{ komodo_home }}/.komodo/stacks`              | Default root for stack folders                                    |
| **stacks\_polling\_rate**                 | `5-sec`                                         | Interval at which periphery polls the stack directory             |
| **logging\_level**                        | `info`                                          | Periphery log level                                               |
| **logging\_stdio**                        | `standard`                                      | Log output format                                                 |
| **logging\_opentelemetry\_service\_name** | `Komodo-Periphery`                              | Service name reported to OpenTelemetry exporters                  |

### Note on Generated Passkeys

Enabling passkey generation for unique periphery passkeys with `generate_server_passkey=true` is potentially valuable, but if doing so remember to *always* enable
this feature whenever you update or install that server. 

For example, if you generated a random passkey on install, and then *DIDN'T* generate a random passkey
or set a passkey on a future update, it would not have a server passkey to provide to the server, and it will update it with no passkey. 

Further, if you generated a passkey on install, and then disabled server management entirely on updates,
then the role will have no knowledge of that generated passkey and it will not include that passkey in its allowed passkeys list, meaning you may be using
no passkey at all. 

Basically, the simple advice is to *ALWAYS* have `generate_server_passkey=true` or *ALWAYS* have `generate_server_passkey=false` for each server. I recommend setting
these variables directly in an inventory file. See [`examples/server_management/inventory/all.yml`](./examples/server_management/inventory/all.yml) for an example.

If this is not preferred, you can always generate on install, and then record the generated passkeys and include that explicitly in your `komodo_passkeys` from thereon.
Or you can of course just always set your own randomly generated `server_passkey`

### Overriding default configuration templates

In some cases, it may be desirable to have more control over the exact service files and/or configuration files deployed to each periphery node.
In this case, the default / interpolated configurations and service files may not be ideal. These configurations can be overridden by manually providing
the config and/or service files and setting them in your playbook to `komodo_config_file_template` and `komodo_service_file_template`, for the
periphery configuration and the systemd service file, respectively.

Note that in doing so, the deployed files will be exactly as you specify, and they will always take precedence over any other specified variables.

## Basic Installation / Setup

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
    Note that this inventory file is for v1.17.1+ komodo versions, as it is supporting the new IPv6 translation layer, either with
    the `'::ffff:` prefix in the `komodo_allowed_ips` or with a `komodo_bind_ip` of `0.0.0.0` as described in the documentation.
   
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
          komodo_version: "v1.18.4"
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

    Update to the newer version

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e "komodo_action=update" \
    -e "komodo_version=v1.18.4" \
    --vault-password-file .vault_pass

    ```

    Uninstall the periphery agent and all installed files, and delete the user.

    ```sh
    ansible-playbook -i inventory/komodo.yaml playbooks/komodo.yml \
    -e "komodo_action=uninstall" \
    -e "komodo_delete_user=true" \
    --vault-password-file .vault_pass
    ```

  ## More Examples / Advanced Features

  This guide only covers the basic information to get off the ground, but you can see more thorough examples
  and explanations in the [`examples/`](./examples) section.

  1. Basic installation example with very little customization: [`examples/basic/README.md`](./examples/basic/README.md)
  2. Example using authentication with allowed IPs and global passkeys: [`examples/auth/README.md`](./examples/auth/README.md)
  3. Example showing server management functions and unique server passkeys: [`examples/server_management/README.md`](./examples/server_management/README.md)

    
