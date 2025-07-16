# Automating Deployment with Komodo and Docker

This guide demonstrates how to use an Ansible Execution Environment to automate Komodo periphery deployments using Docker. This approach enables Komodo to update its own periphery instances when needed.

## Prerequisites

- Working Komodo Core installation
- Basic understanding of Ansible and Docker

## Step 0: Familiarize Yourself

In case anything goes wrong, it is likely wise that you know
how to deploy periphery using this role in a more typical
manner first, from a proper ansible host. This way, if something goes wrong,
you can very quickly remedy it with a redeploy from your working 
environment.

## Step 1: Generate API Credentials

This example uses server management and automatic versioning features, which require API credentials.

> **Note:** If you don't want to enable these features, you can skip this step.

1. Navigate to **Settings > Profile > New Api Key +**
2. Take note of the API Key and API secret

```text
Example API Key: K-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Example API Secret: S-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Encrypt Credentials with Ansible Vault

For security, encrypt these variables using Ansible Vault:

```bash
# Generate a vault passphrase (or provide your own)
openssl rand -base64 32 > vault-pass.txt

# Encrypt the API credentials
ansible-vault encrypt_string --vault-password-file vault-pass.txt "YOUR_ACTUAL_API_KEY" --name "komodo_core_api_key"
ansible-vault encrypt_string --vault-password-file vault-pass.txt "YOUR_ACTUAL_API_SECRET" --name "komodo_core_api_secret"
```

Example output:

```yaml
Encryption successful
komodo_core_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          63336336616364346434373939666130303930303339376530373834623661343861616132356637
          3039393463373733313439663830316261343762663336320a663437393730383433326431306161
          30343438636135363261636530666438633935303165313436373838303164336131336532323961
          3461613665303565610a656634623931396430343430643339616361396665383865643230363832
          36613836336536386534663436613663656434353833643932316135663361366330636266653734
Encryption successful
komodo_core_api_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          37633836323564313162373430633331636533616664363632363737383639336335633738633062
          6235373930366335393839326636616130633532346135620a333062353864333330643332623031
          35376362363539656636383133633536626632363535623162383537373839323239613639373463
          3035393937666435360a396566396236316437366262643137633739363637653466346666343865
          65383237356635373634656432666434303366303332343730333132373038656636656561633736
          3962636334366164626335343333323462373732373063366465
```

**Note:** Store the contents of `vault-pass.txt` securely. In this example, the vault password is: `Ia8x7B9pxxjuhVt9syaj5U9YFU5PM0TVGlUmX9WsYHc=`

## Step 2: Update Your Inventory File

Update `inventory/all.yml` with the encrypted variables created above and configure the core URL:

> **Important:** If updating existing servers, ensure you add a `server_name` that matches the existing server name. Otherwise, Ansible will create a new server using the `ansible_inventory_name`.

```yaml
    komodo:
      vars:
        komodo_core_url: "https://komodo.example.com"
        komodo_core_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          63336336616364346434373939666130303930303339376530373834623661343861616132356637
          3039393463373733313439663830316261343762663336320a663437393730383433326431306161
          30343438636135363261636530666438633935303165313436373838303164336131336532323961
          3461613665303565610a656634623931396430343430643339616361396665383865643230363832
          36613836336536386534663436613663656434353833643932316135663361366330636266653734
        komodo_core_api_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          37633836323564313162373430633331636533616664363632363737383639336335633738633062
          6235373930366335393839326636616130633532346135620a333062353864333330643332623031
          35376362363539656636383133633536626632363535623162383537373839323239613639373463
          3035393937666435360a396566396236316437366262643137633739363637653466346666343865
          65383237356635373634656432666434303366303332343730333132373038656636656561633736
          3962636334366164626335343333323462373732373063366465
        enable_server_management: true
        generate_server_passkey: true
```

### Further Host-Specific Configurations

Update all host-specific settings for each server, including:
- Correct `ansible_host` and SSH credentials
- `komodo_allowed_ips` configuration
- Additional passkeys as needed
- `server_name` as mentioned above
- Any other host-specific settings

## Step 3: Create the Deployment Stack in Komodo

We can now use the Ansible Execution Environment in a Komodo-hosted Docker stack.

1. In Komodo, navigate to **Stacks > New Stack**
2. Create a stack with your preferred settings
3. Use the following configuration files:

### compose.yaml

```yaml
---

services:
  ansible:
    image: ghcr.io/bpbradley/ansible/komodo-ee:latest
    user: ${UID}:${GID}
    restart: no
    extra_hosts:
      - host.docker.internal:host-gateway
    volumes:
      - ./ansible:/ansible
      - ./ssh:/root/.ssh:ro
    environment:
      VAULT_PASS: ${VAULT_PASS}
      ANSIBLE_HOST_KEY_CHECKING: false
    command: >
     ansible-playbook /ansible/playbooks/komodo.yml
     -i /ansible/inventory/all.yml
     -e komodo_action=${KOMODO_ACTION}
     -e komodo_version=${KOMODO_VERSION}
```

### .env

```bash
VAULT_PASS=Ia8x7B9pxxjuhVt9syaj5U9YFU5PM0TVGlUmX9WsYHc=
KOMODO_ACTION=update
KOMODO_VERSION=core
```

### Important Configuration Notes

1. **Default Actions**: The example sets `KOMODO_ACTION=update` and `KOMODO_VERSION=core`, assuming periphery is already installed. Change to `install` if needed. The `core` version ensures periphery matches Komodo core version.

2. **Vault Password Security**: Store the vault password as a secret in **Komodo > Settings > New Variable** and reference it in your `.env` with:
   ```bash
   VAULT_PASS=[[VAULT_SECRET_VAR]]
   ```

3. **File Mounting**: The example uses relative paths with bind mounts. Ensure the `./ansible` folder is mounted to `/ansible` in the container.

4. **SSH Keys**: Store SSH keys securely (e.g., I keep mine in 1Password) and mount them to the expected location. Ensure the container user owns the SSH key files (SSH keys cannot be world-readable).

5. **Host Key Checking**: If you don't want `ANSIBLE_HOST_KEY_CHECKING: false`, create a known_hosts file:
   ```bash
   ssh-keyscan -H <target_ip> >> ~/.ssh/known_hosts
   ```
   Then mount it with:
   ```yaml
   - ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro
   ```

## Step 4: Run the Stack

### Testing (Recommended)

For initial testing, limit deployment to a non-critical host:

```bash
# Add this to the command to target a specific host
-l komodo_host2
```

So for example, the stack command would be 

```yaml
    command: >
     ansible-playbook /ansible/playbooks/komodo.yml
     -i /ansible/inventory/all.yml
     -e komodo_action=${KOMODO_ACTION}
     -e komodo_version=${KOMODO_VERSION}
     -l komodo_host2
```

### Deployment

1. Click **Deploy** in the Komodo interface
2. **Expected behavior**: You may be temporarily disconnected as the periphery running the deploy command is updated
3. The periphery should restart within a few seconds
4. Check the logs to verify successful deployment

## Step 5: Add an Action for Improved Automation

Create an action that automatically checks periphery versions against Core and triggers updates when mismatches are detected.

### Action Script

```typescript
async function main() {
  const { version: coreVersion } =
    await komodo.read("GetVersion", {}) as Types.GetVersionResponse;

  const servers =
    await komodo.read("ListServers", { query: {} }) as Types.ListServersResponse;

  const checks = await Promise.all(
    servers.map(async ({ id, name }) => {
      try {
        const { version } = (await komodo.read(
          "GetPeripheryVersion",
          { server: id }
        )) as Types.GetPeripheryVersionResponse;

        return { id, name, version, match: version === coreVersion };
      } catch (err) {
        console.error(`• ${name} (${id}): Periphery Error: ${(err as Error).message}`);
        return { id, name, err: err as Error, match: false };
      }
    })
  );

  console.log(`Komodo core version: ${coreVersion}`);
  console.log("Periphery version check:");
  checks.forEach(({ id, name, version, match, err }) => {
    if (err) return;

    const label = `${name} (id=${id})`;
    if (!match) {
      console.log(`\t - ${label}: ⚠️  ${version} (expected ${coreVersion})`);
    } else {
      console.log(`\t - ${label}: ✅  ${version}`);
    }
  });

  if (checks.some(c => !c.match)) {
    console.log(
      `Periphery version mismatch detected. redeploying periphery with Ansible…`
    );

    await komodo.execute("DeployStack", {
      stack: "ansible",
    }) as Types.Update;
  } else {
    console.log("🦎 All periphery versions are in sync. Nothing to do. 🦎");
  }
}

try {
  await main();
} catch (e) {
  console.error(e);
}
```

## Beyond: Further Automation

### Automated Updates with Renovate

You can set up Renovate on a GitHub repository to automatically create pull requests when new Komodo versions are available.

1. This repository includes an example configuration in `.github/renovate.json`
2. Configure your stack to deploy via webhook
3. Merging Renovate update PRs will automatically trigger periphery updates

This creates a fully automated update pipeline for your Komodo infrastructure that is consistent with how you may deploy your other stacks.