> [!IMPORTANT]
> This example requires komodo core and periphery to be updated to  v1.19.2 or higher.
> You should use the deployment role in a more conventional manner first to get updated
> to at least that version before continuing

# Automating Deployment with Komodo and Docker

This provides an exhaustive example for how to use ansible-in-docker using an
ansible execution image provided by this role to have komodo update its own periphery servers automatically

The following guide will walk you through the steps, and the provided inventory file annotates a lot
of available functionality so you understand how you may need to adjust it to your own environment.
The example intentionally uses as many features as possible to be exhaustive, but a simple inventory works just fine too.

## Prerequisites

- Working Komodo Core installation
- Basic understanding of Ansible and Docker
- Komodo core and at least one periphery server updated to v1.19.2+

## Step 0: Familiarize Yourself

In case anything goes wrong, it is wise that you know
how to deploy periphery using this role in a more typical
manner first, from a proper ansible host. This way, if something goes wrong,
you can very quickly remedy it with a redeploy from your working 
environment. Trying to debug issues with ansible-in-docker is not ideal. This should be done only once you have a working setup and want to add full automation.

## Step 1: Create the komodo-ee stack

1. In Komodo, navigate to **Stacks > New Stack**
1. Create a stack with your preferred settings
1. I recommend using a git based or files on server stack, so that you can manage your config files (inventory, playbooks) within komodo directly
1. Use the following configuration files, plus the included `ansible/` folder alongside your compose.yaml:

### compose.yaml

```yaml
---

services:
  ansible:
    image: ghcr.io/bpbradley/ansible/komodo-ee:latest
    extra_hosts:
      - host.docker.internal:host-gateway
    volumes:
      - ./ansible:/ansible # Mount ansible files into container
      - /path/on/host/to/.ssh/ansible:/root/.ssh/id_ed25519:ro # Make sure the user you run the container has read access to the key
    environment:
      ANSIBLE_HOST_KEY_CHECKING: ${ANSIBLE_HOST_KEY_CHECKING:-false} # Necessary for automation, unless you manage known_hosts and map it into container
    command: "sleep 3600" # this keeps the container running by default, which will help with testing so you can exec into it temporarily
```

Here, I am providing a default command of `sleep 3600` so that we can, if needed, deploy the container and exec into it for testing. This will allow
us to do all steps in this guide from *within komodo* if we choose to.

### Configuration Notes

1. **File Mounting**: The example uses relative paths with bind mounts. Ensure the `./ansible` folder is mounted to `/ansible` in the container.

1. **SSH Keys**: Store SSH keys securely (e.g., I keep mine in 1Password) and mount them to the expected location. Ensure the container user owns the SSH key files (SSH keys cannot be world-readable).

1. **Host Key Checking**: If you enable `ANSIBLE_HOST_KEY_CHECKING=true`, create a known_hosts file:
   ```bash
   ssh-keyscan -H <target_ip> >> ~/.ssh/known_hosts
   ```
   Then mount it with:
   ```yaml
   - ~/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro
   ```

## Step 2: Generate API Credentials

This example uses server management, which require API credentials. 

> [!NOTE]
> You don't expressly need API credentials
> and so you can just skip these sections if you don't want server management. Without server management, you just need to manually create / update servers as needed.

1. Navigate to **Settings > Profile > New Api Key +**
2. Take note of the API Key and API secret

```text
Example API Key: K-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Example API Secret: S-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Encrypt Credentials with Ansible Vault

For security, encrypt these variables using Ansible Vault. There are countless ways to do this, but I am going to try to achieve *everything* in this guide from within komodo. So Deploy the stack we created earlier. **Stacks > komodo-ee > Deploy**

Because of the `sleep 3600` command used by default in the compose file, the execution environment will stay alive (for an hour), so we can shell into the container (in komodo), and use ansible tools.

Open a shell in komodo-ee by Navigating to **Stacks > komodo-ee > Services Tab > Select ansible container > Terminals > New Terminal**

```bash
# Generate a vault passphrase (or provide your own)
head /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${1:-64} > /tmp/.vaultpass
# Use env variable to inform ansible of vault password
export ANSIBLE_VAULT_PASSWORD_FILE=/tmp/.vaultpass
# Encrypt the API credentials
ansible-vault encrypt_string "K-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --name "komodo_core_api_key"
ansible-vault encrypt_string "S-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --name "komodo_core_api_secret"
# The password needed to become the sudo user with your ansible_user
ansible-vault encrypt_string "S-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --name "ansible_become_pass"
# Remember to encrypt any other variables you may need here
```

Example output:

```sh
bash-5.2$ ansible-vault encrypt_string "K-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --name "komodo_core_api_key"
Encryption successful
komodo_core_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          36623436616338363562373236366237333166303362373333613963393132626538303064616435
          3131666462663431386538643735376136613231646537340a303634383563613061633339633030
          30663939353566616464633933663636346262656564653665333032653666396264316131306539
          3036323332626666350a663537653434646236616532386463613432386539343334626638633431
          66623464326230653033336331616661663732313165626463663535316433666363313362366130
          3435323862663331666666616163653966383232623961616337
bash-5.2$ ansible-vault encrypt_string "S-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --name "komodo_core_api_secret"
Encryption successful
komodo_core_api_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          64323763383431393564393563353731646437313632396537646462313362303237623033373962
          6162346537663130616530346134303663393138323464640a646232613839303565313735373137
          35636266313039646335666138333539626165623233326564626263656339376336663133616630
          3936303933643137380a613662376662376138343233373137613363343135376332653435336638
          38643634646331336462366432626238653233383264393531303466353438383034313365656435
          6539613361393130653639633637303565633265396138353335
```

Take note of these variables, and any other variables you need to similarly encrypt.

Finally, don't forget to record your vault password.

```bash
bash-5.2$ cat ${ANSIBLE_VAULT_PASSWORD_FILE};echo
ebA2VEbBpHc6ZmA_wd1jIoxEPIS0s4BC9bHSUdXqRACAVDmN1iT7cpfw_pD_uCVu
```

For this guide, we will store the vault password as a komodo secret. **Komodo > Settings > Variables > New Variable** paste in your output `ebA2VEbBpHc6ZmA_wd1jIoxEPIS0s4BC9bHSUdXqRACAVDmN1iT7cpfw_pD_uCVu` in the example above. Save it is **VAULT_PASS** and mark the variable as secret.

> [!NOTE]
> You can destroy the stack now. It no longer needs to be running. **Stacks > komodo-ee > Destroy**

## Step 3: Update Your Inventory File

Update `ansible/inventory/komodo.yml` with the encrypted variables created above and configure the core URL:

> [!IMPORTANT]
> Review the example inventory and read the annotations. 
> In order for all of the automations to work as designed in all configurations, 
> you should ideally name all of your inventory host names exactly the same as they are in komodo.
> i.e. if you have a server in komodo with name `test_server` then you should make that servers inventory name `test_server`.
> This isn't generally necessary, as you can always set an explicit `server_name` variable,
> but in this case the automation relies on being "aware" of your inventory
> because it will attempt to only update systems that are out of date, rather than all of them.

### ansible/inventory/komodo.yml
```yaml
all:
  # Here you can have your typical inventory configurations.
  # Add additonal vars: section for ssh keyfiles, etc.
  hosts:
    # Important: for best automation, name your hosts in your inventory
    # the exact same way that they are named in komodo.
    # This way, komodo can be "aware" of your ansible hosts automatically.
    # and automation features will work seamlessly.
    internal_server:
      ansible_host: 10.1.10.4
    external_server:
      ansible_host: 10.1.10.5
    test_server:
      ansible_host: 10.1.10.6
  vars:
    ansible_user: actual_user_to_run_playbook_as #i.e. bbradley
    # This role needs elevated privileges for some tasks.
    # remember to encrypt ansible_become_pass with vault.
    ansible_become_pass: !vault |
            $ANSIBLE_VAULT;1.1;AES256
            65353234373130353539663661376563613539303866643963363830376661316638333139343366
            3563656637303235373336336131346338336634653232300a313736396336316330666237653237
            64613231323433373637313462633863613732653136366462313134393938623136326633346166
            3834333462333162310a313037306336613061313733363862633437376133316234326431633131
            35386565333538623231643433396334323132616438353839663534373030393266
    # You will need to mount any ssh keys into the container, 
    # with the correct permissions for the user the container is running as
    ansible_ssh_private_key_file: /root/.ssh/id_ed25519 # i.e. (/path/to/ssh/key/in/container)
  children:
    komodo:
      vars:
        # This example uses server management, which requires an API key and secret.
        # You do not -need- to use server management though, so long as your servers already
        # exist on system.
        komodo_core_url: "https://komodo.example.com"
        komodo_core_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          36623436616338363562373236366237333166303362373333613963393132626538303064616435
          3131666462663431386538643735376136613231646537340a303634383563613061633339633030
          30663939353566616464633933663636346262656564653665333032653666396264316131306539
          3036323332626666350a663537653434646236616532386463613432386539343334626638633431
          66623464326230653033336331616661663732313165626463663535316433666363313362366130
          3435323862663331666666616163653966383232623961616337
        komodo_core_api_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          64323763383431393564393563353731646437313632396537646462313362303237623033373962
          6162346537663130616530346134303663393138323464640a646232613839303565313735373137
          35636266313039646335666138333539626165623233326564626263656339376336663133616630
          3936303933643137380a613662376662376138343233373137613363343135376332653435336638
          38643634646331336462366432626238653233383264393531303466353438383034313365656435
          6539613361393130653639633637303565633265396138353335
        enable_server_management: true
        # We will generate a random passkey every time we run the playbook.
        # This effectively will rotate the passkey on every run.
        generate_server_passkey: true
        # I like to "inform" each server what UID/GID it is running as
        # which is useful when running containers as the komodo user.
        # The role will also populate the UID/GID env variables in the
        # systemd service file for you, but this is just a convenience.
        komodo_agent_secrets:
        - name: "KOMODO_UID"
          value: "{{ ansible_facts.getent_passwd[komodo_user].1 }}"
        - name: "KOMODO_GID"
          value: "{{ ansible_facts.getent_passwd[komodo_user].2 }}"
      children:
        # It isn't necessary to split the inventory up into core / periphery,
        # but it is useful for organization and I personally have other roles
        # which only target core or periphery exclusively.
        core:
          hosts:
            internal_server:
              # We can connect directly to the docker container IP if we bind
              # if we bind to the docker0 interface on the host (or 0.0.0.0, etc)
              komodo_allowed_ips:
                - "172.20.0.101"
              # The other servers will automatically determine their server address,
              # by detecting their route to komodo core based on the komodo_core_url.
              # This may not always work though, and so we can manually specify it like so.
              server_address: https://host.docker.internal:{{ periphery_port }}
              komodo_bind_ip: "{{ ansible_docker0.ipv4.address}}"
        periphery:
          hosts:
            external_server:
              komodo_allowed_ips:
                - "10.1.10.4"
              # Add any additional secrets you want here, This will override
              # the group vars.
              komodo_agent_secrets:
              - name: "KOMODO_UID"
                value: "{{ ansible_facts.getent_passwd[komodo_user].1 }}"
              - name: "KOMODO_GID"
                value: "{{ ansible_facts.getent_passwd[komodo_user].2 }}"
              - name: "SUPER_SECRET"
                value: !vault |
                  $ANSIBLE_VAULT;1.1;AES256
                  66386439653762316464626437653766643665373063...
            test_server:
              # not necessary, as the above server is doing the exact same thing
              # more explicitly, but you can also dynamically set the allowed IP
              # to the `internal_server` IP automatically like this
              komodo_allowed_ips:
                - "{{ hostvars['internal_server'].ansible_host }}"
              komodo_bind_ip: "{{ ansible_host }}"
```

## Step 5: Create a playbook

This is just a very basic playbook which pulls in the role, and thats all it needs to be.
We are primarily controlling execution with inventory settings and Action arguments.

### ansible/playbooks/komodo.yml
```yaml
---
- name: Manage Komodo Periphery Service
  hosts: komodo
  roles:
    - role: bpbradley.komodo
  # This task is simply to keep the container alive for a few seconds
  # to make it easier to capture logs.
  post_tasks:
    - name: Pause after run (default 10s)
      ansible.builtin.pause:
        seconds: "{{ pause_after_seconds | default(10) }}"
      run_once: true
      delegate_to: localhost
      when: pause_after | default(false) | bool
```

## Step 5: Automate with Actions

With the infrastructure in place, we can handle complex automations using the komodo API, which we can leverage to make sure that periphery always stays up to date. Here is the action script and arguments to copy in **Actions > New Action > DeployPeriphery** 

This script and the associated action arguments are fairly complex, so that as many use cases
as possible can be captured with this setup. Feel free to simplify it (potentially dramatically) to meet your specific needs.

The general concept of the script is

1. On startup, check if targeted servers are up to date
1. If they are, do nothing. If they are not, update any servers that are out of date using `docker compose run` targeting the stack we created.
1. Try to attach to the process to capture logs and extract the play recap

> [!IMPORTANT]
> Make sure you have your vault password saved as a secret variable in komodo
> called `VAULT_PASS`. I didn't include this as an action argument because
> the variable will be interpolated too early, and then be exposed in logs

### Action Arguments

```json
{
  "PLAYBOOK": "/ansible/playbooks/komodo.yml",
  "INVENTORY": "/ansible/inventory/all.yml",
  "KOMODO_ACTION": "update",
  "KOMODO_VERSION": "core",
  "STACK_NAME": "komodo-ee",
  "SERVICE_NAME": "ansible",
  "DRY_RUN": false,
  "FORCE": false,
  "LIMIT_SERVERS": [],
  "IGNORE_SERVERS": []
}
```

### Action Script

```typescript
type Server = { id: string; name: string; version: string; err?: Error };

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }
function parseContainerId(s: string): string | null { const m = s.match(/\b([0-9a-f]{12,64})\b/i); return m ? m[1] : null; }
function normalizeVersion(s: string | undefined | null): string { return String(s ?? "").trim().replace(/^v/i, ""); }

function truthy(v: unknown): boolean {
  if (typeof v === "boolean") return v;
  const s = String(v ?? "").trim().toLowerCase();
  return s === "true" || s === "1" || s === "yes" || s === "on";
}

function parseLimitServers(x: unknown): string[] {
  if (Array.isArray(x)) return x.map(String).map(s => s.trim()).filter(Boolean);
  const raw = String(x ?? "").trim();
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed.map(String).map(s => s.trim()).filter(Boolean);
  } catch {}
  return raw.split(/[,\s]+/).map(s => s.trim()).filter(Boolean);
}

function extractRecap(s: string): string | null {
  const i = s.indexOf("PLAY RECAP");
  return i >= 0 ? s.slice(i) : null;
}

function recapHasFailures(recap: string): boolean {
  const failed = [...recap.matchAll(/failed=(\d+)/g)].some(([,n]) => parseInt(n,10) > 0);
  const unreachable = [...recap.matchAll(/unreachable=(\d+)/g)].some(([,n]) => parseInt(n,10) > 0);
  return failed || unreachable;
}

async function waitForServerUpdate(server: Server, timeoutMs = 20000, intervalMs = 1000): Promise<boolean> {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const { version } = (await komodo.read("GetPeripheryVersion", { server: server.id })) as Types.GetPeripheryVersionResponse;
    if (version === server.version) { console.log(`${server.name} Updated!`); return true; }
    console.debug(`Version: ${version}`)
    await sleep(intervalMs);
  }
  console.log(`${server.name} offline during update... Waiting to come back online...`);
  return false;
}

async function followContainerLogs(server: Server, containerId: string): Promise<string> {
  const term = `periphery-follow`;
  const streamCmd = `docker logs -f ${containerId}`;

  const getRecap = async (): Promise<string | null> => {
    let recapSeen = false;
    let recapText: string | null = null;
    try {
      await komodo.write("CreateTerminal", { 
        server: server.name, 
        name: term, 
        command: "/bin/bash", 
        recreate: Types.TerminalRecreateMode.Always 
      });
      await komodo.execute_terminal({ 
        server: server.name, 
        terminal: term, 
        command: `${streamCmd}` 
        },{
          onLine: (line) => {
            if (!recapSeen) {
              const i = line.indexOf("PLAY RECAP");
              if (i >= 0) {
                recapSeen = true; 
                const first = line.slice(i); 
                recapText = first;
                console.log(first);
              }
            } else {
              console.log(line);
              if (recapText) recapText += `\n${line}`;
            }
          },
          onFinish: () => {},
        }
      );
    } catch {}
    return recapSeen ? recapText : null;
  };

  const first = await getRecap();
  if (first) return first;
  // Server likely dropped out because it is currently updating. 
  // Wait a few seconds, then try to see if it comes back up, then try again
  await sleep(15000);
  const ok = await waitForServerUpdate(server);
  if (!ok) throw new Error(`Timeout waiting for ${server.name} to report version ${server.version}`);
  const second = await getRecap();
  if (!second) throw new Error(`No Ansible recap captured from ${server.name}`);
  return second;
}

async function resolveRequiredVersion(): Promise<string> {
  const req = String(ARGS.KOMODO_VERSION || "");
  if (req.toLowerCase() === "core") {
    const { version } = (await komodo.read("GetVersion", {})) as Types.GetVersionResponse;
    return normalizeVersion(version);
  }
  return normalizeVersion(req);
}

async function isServerOnline(id: string): Promise<boolean> {
  const res = await komodo.read("GetServerState", { server: id }) as Types.GetServerStateResponse;
  return res.status === Types.ServerState.Ok;
}

async function update() {
  const DRY_RUN = truthy(ARGS.DRY_RUN);
  const FORCE = truthy(ARGS.FORCE);
  const LIMIT_SERVERS = parseLimitServers(ARGS.LIMIT_SERVERS);
  const IGNORE_SERVERS = parseLimitServers(ARGS.IGNORE_SERVERS);

  const requiredVersion = await resolveRequiredVersion();
  if (!requiredVersion) throw new Error("Missing required version");

  const base = (await komodo.read("ListServers", { query: {} })) as Types.ListServersResponse;

  const allServers: Server[] = await Promise.all(
    base.map(async ({ id, name }) => {
      try {
        const { version } = (await komodo.read("GetPeripheryVersion", { server: id })) as Types.GetPeripheryVersionResponse;
        return { id, name, version };
      } catch (err) {
        return { id, name, version: "ERROR", err: err as Error };
      }
    })
  );

  const ignoreSet = new Set(IGNORE_SERVERS);
  const unknownIgnores = IGNORE_SERVERS.filter(
    v => !allServers.some(s => s.name === v || s.id === v)
  );
  let servers = allServers.filter(s => !ignoreSet.has(s.name) && !ignoreSet.has(s.id));

  if (IGNORE_SERVERS.length) {
    console.log(`Ignoring servers: ${IGNORE_SERVERS.join(", ") || "(none)"}`);
    if (unknownIgnores.length) console.log(`No match for ignored: ${unknownIgnores.join(", ")}`);
  }

  if (servers.length === 0) {
    console.log("🦎 All servers are ignored. Nothing to do. 🦎");
    return;
  }

  const byName = new Map(servers.map(s => [s.name, s]));
  const limits = LIMIT_SERVERS;
  const unknownLimits = limits.filter(n => !byName.has(n));
  if (limits.length) console.log(`Limiting to: ${limits.join(", ") || "(none)"}`);
  if (unknownLimits.length) console.log(`Ignoring unknown servers: ${unknownLimits.join(", ")}`);

  let candidates: Server[];
  if (limits.length) {
    candidates = limits.map(n => byName.get(n)).filter((x): x is Server => !!x);
    candidates = FORCE ? candidates : candidates.filter(s => !s.err && normalizeVersion(s.version) !== requiredVersion);
  } else if (FORCE) {
    candidates = servers.filter(s => !s.err);
  } else {
    candidates = servers.filter(s => !s.err && normalizeVersion(s.version) !== requiredVersion);
  }

  const targetIds = new Set(candidates.map(s => s.id));
  const labelWidth = Math.max(...servers.map(({ id, name }) => `${name} (id=${id})`.length));

  console.log("Periphery version check:");
  servers.forEach((s) => {
    const label = `${s.name} (id=${s.id})`.padEnd(labelWidth);
    const cur = normalizeVersion(s.version);
    const inScope = targetIds.has(s.id);

    let msg: string;
    if (s.err) {
      msg = `❌  Error: ${(s.err as Error).message}`;
    } else if (inScope) {
      if (FORCE && cur === requiredVersion) {
        msg = `🔁 forcing update (currently ${cur})`;
      } else if (cur !== requiredVersion) {
        msg = `🎯 target: ${cur} → ${requiredVersion}`;
      } else {
        msg = `✅ up to date${FORCE ? " (forcing update)" : ""}`;
      }
    } else {
      if (cur !== requiredVersion) {
        msg = `⏭️  not targeted (current ${cur}, required ${requiredVersion})`;
      } else {
        msg = `✅ up to date`;
      }
    }

    console.log(`  - ${label} : ${msg}`);
  });

  if (candidates.length === 0) {
    console.log("🦎 Nothing to do. 🦎");
    return;
  }

  const stack = (await komodo.read("GetStack", { stack: ARGS.STACK_NAME })) as Types.GetStackResponse;
  const stackServerId = (stack as any).config?.server_id as string | undefined;
  const stackServer = servers.find(s => s.id === stackServerId);
  const includesStackServer = !!stackServer && candidates.some(s => s.id === stackServer.id);

  const DETACH = DRY_RUN ? false : includesStackServer;

  const allTargeted = candidates.length === servers.filter(s => !s.err).length;
  const allManaged = servers.filter(s => !s.err);
  let limitPattern: string | undefined;

  if (LIMIT_SERVERS.length || IGNORE_SERVERS.length) {
    limitPattern = candidates.map(s => s.name).join(",");
  } else {
    const allTargeted = candidates.length === allManaged.length;
    limitPattern = allTargeted ? undefined : candidates.map(s => s.name).join(",");
  }
  
  const command = [
    "ansible-playbook",
    ARGS.PLAYBOOK,
    "-i", ARGS.INVENTORY,
    "-e", `komodo_action=${ARGS.KOMODO_ACTION}`,
    "-e", `komodo_version=v${requiredVersion}`,
    "-e", "pause_after=true",
  ];
  if (limitPattern) command.push("-l", limitPattern);
  if (DRY_RUN) command.push("--check", "--diff");

  const result = (await komodo.execute_and_poll("RunStackService", {
    stack: ARGS.STACK_NAME,
    service: ARGS.SERVICE_NAME,
    command,
    detach: DETACH,
    pull: true,
    no_deps: true,
    env: { VAULT_PASS: "[[VAULT_PASS]]" },
  })) as Types.Update;

  const runLog = result.logs.find(l => l.stage === "Compose Run");
  if (!runLog) throw new Error("No 'Compose Run' stage found in logs.");

  let recapText: string | null = null;

  if (DETACH && stackServer) {
    // Detached: stdout/stderr should contain the container id; follow its logs to get the recap
    const cid = parseContainerId(`${runLog.stdout || ""}\n${runLog.stderr || ""}`);
    if (!cid) throw new Error("Could not parse container id from output; unable to follow logs.");

    console.log(`Following container logs (${cid}) on ${stackServer.name}…`);

    // we expect this host to update to requiredVersion
    stackServer.version = requiredVersion;

    recapText = await followContainerLogs(stackServer, cid);
  } else {
    // Non-detached: compose output should include the recap
    if (!runLog.success) {
      console.error(runLog.stdout);
      console.error(runLog.stderr);
      throw new Error("Periphery Update Failed");
    }
    recapText = extractRecap(runLog.stdout) ?? extractRecap(runLog.stderr || "");
    if (!recapText) throw new Error("Ansible run completed but recap was not found in output.");
    console.log(recapText);
  }

  if (recapHasFailures(recapText)) throw new Error("Ansible recap indicates failures.");

  if (!DRY_RUN) {
    const offline = await Promise.all(
      candidates.map(async s => ({ s, ok: await isServerOnline(s.id) }))
    ).then(rows => rows.filter(r => !r.ok).map(r => r.s.name));
    if (offline.length) throw new Error(`Post-update check failed: offline servers: ${offline.join(", ")}`);
  }

  console.log("🦎 Periphery Update Successful 🦎");
}

await update();

```

### Testing

Now with everything in place, testing is strongly recommended. The action includes a `DRY_RUN` and `LIMIT_SERVERS` option, and both should ideally be used to test fully before deploying across the entire inventory.

1. Use `DRY_RUN=true` and `"LIMIT_SERVERS": []` to perform a `--check --diff` with ansible. This will attempt to run the role and report what it *would* (probably) do, without actually doing it. I say probably because not all tasks can be easily dry-run. But this will catch most configuration errors.
2. Set `DRY_RUN=false` and try actually running the role on a limited set of servers -- i.e. `"LIMIT_SERVERS": ["test_server"]`. You can test changing different versions (ideally not earlier than 1.19.2) to see that it is working.

### Update Periphery

It is now time to see if the update is working. set `"LIMIT_SERVERS": []` and **Run Action**. You should observe all servers listed in your inventory go down and come back up with the new version.

> [!NOTE]
> Capturing logs from periphery here is surprisingly delicate. The
> reason being that periphery goes offline during the update, and so we lose 
> connection. The run command runs detached, so the update will happen 
> regardless, but in order to capture logs we need to open a terminal and 
> try to follow the logs before the run completes. I did my best to handle this
> without getting too hacky, but it may occasionally lose the output logs. It is
> working well in my testing though.

## Final Touches

Once everything is working correctly, you have everything you need to implement full automation of periphery redeployment without leaving komodo.

Here is just a final checklist to go through to make sure.

1. Verify `"LIMIT_SERVERS"=[]` so that your entire inventory is targeted, unless you have a specific reason to target only specific servers
1. If you have non-systemd managed servers, you should include them in `IGNORE_SERVERS` so that these servers are not considered when deciding to update.
1. Verify `"DRY_RUN": false` so that the runs actually execute
1. Verify `"FORCE": false`, or it will always update your servers when the action is run, even if it doesn't need to.
1. Verify `"KOMODO_VERSION": "core"` so that it will always update to match core when they go out of date
1. Configure action to **Run on Startup** in the action settings. This way, when komodo updates (and therefore restarts), it will immediately detect the version mismatch and begin updating before you can even finish logging back in.

## Final Notes

If you have any issues with this setup, or improvement suggestions, please raise an issue. I am sure there is plenty of room for improvement.
