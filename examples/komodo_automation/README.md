# Automating Deployment with Komodo and Docker

I am maintaining an Ansible Execution Environment with this role,
so that it is possible to easily trigger deployment of periphery
using Docker. This means we can setup Komodo to update its own
periphery when needed.

## Step 0: Familiarize Yourself

In case anything goes wrong, it is likely wise that you know
how to deploy periphery using this role in a more typical
manner first, from a proper ansible host. This way, if something goes wrong,
you can very quickly remedy it with a redeploy from your working 
environment.

## Step 1:  Generate API credentials

This example will use the server management and automatic
versioning features, so API credentials are needed.

If you don't want to enable those features, this can be skipped.

Navigate to **Settings > Profile > New Api Key +**. Take note
of the API Key and the API secret.

```
Test API Key: K-IOD8sYx9zbED5SHbI13X84138gh2uEXNldgeU8ng
Test API Secret: S-7zs7EXQZchnieSsL82fze1YpvwPGdIM76PuiZDqD
```

Now, ideally you should encrypt these variables with the vault

```sh
# Generate a vault passphrase, or provide your own.
openssl rand -base64 32 > vault-pass.txt
ansible-vault encrypt_string --vault-password-file vault-pass.txt "K-IOD8sYx9zbED5SHbI13X84138gh2uEXNldgeU8ng" --name "komodo_core_api_key"
ansible-vault encrypt_string --vault-password-file vault-pass.txt "S-7zs7EXQZchnieSsL82fze1YpvwPGdIM76PuiZDqD" --name "komodo_core_api_secret"
```

Example output

```
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

You can now safely paste these directly into your inventory file and keep it
in version control. **Make sure to store the contents of `vault-pass.txt`
somewhere safe. In my case, the output was `Ia8x7B9pxxjuhVt9syaj5U9YFU5PM0TVGlUmX9WsYHc=`

## Step 2: Update your inventory file

Update inventory/all.yml with the variables created above, and change the core URL as needed. *Note* if you are updating existing servers with this, make sure to add a `server_name` to the specific server that matches that name, otherwise it is going to create a new server with the `ansible_inventory_name` instead.

```
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

Update all of your host specific settings as needed for each server. This means
making sure you have the correct `ansible_host` (and ssh credentials), `komodo_allowed_ips`, and any additional passkeys, as well as any additional settings as needed for each host.

## Step 3: Create the Deployment stack in Komodo

Here we will use the Ansible Execution Environment in a Komodo hosted
Docker stack. 

In Komodo, navigate to **Stacks > New Stack** and create a stack with
your preferred settings.

Here is the compose.yaml we will be using.

```
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
And here would be my accompanying `.env`

```
VAULT_PASS=Ia8x7B9pxxjuhVt9syaj5U9YFU5PM0TVGlUmX9WsYHc=
KOMODO_ACTION=update
KOMODO_VERSION=core
```
Take careful note of a few key points.

1. I made the default action update and version core. This is assuming that you've already installed periphery on the necessary server. You can safely change this to install if needed instead. The default version is core, because I want to always version it to match Komodo core, but you can set it to any release tag.
1. The vault password can be stored as a
secret in **Komodo > Settings > New Variable** and then referenced in your
`.env` with `VAULT_PASS=[[VAULT_SECRET_VAR]]`
1. My stack has all config files colocated with the stack (in revision control)
so I am using relative paths with my bind mounts. Make sure the `./ansible` folder from this example is mounted to `/ansible` is all that matters
1. I also have my ssh keys local to the stack (stored safely in 1password, so I can keep the ssh key as a secret reference in revision control). If you are connecting by ssh key, make sure it is mounted to the location that your ansible inventory file expects it.
1. Speaking of SSH keys, make sure that the user you run the stack as is the owner of the SSH key, as SSH keys cant be world readable.
1. If you don't want `ANSIBLE_HOST_KEY_CHECKING: false` you will need to pass in a known_host file. Perhaps something like `ssh-keyscan -H <target_ip> >> ~/.ssh/known_hosts` for each host, and then mount that to the service with `- ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro`

## Step 4: Run the stack

If you want to be cautious, you can first ammend the command with `-l komodo_host2`, or some specific host that is non-critical so that you
can test it is working. If you do so, it will only run on that host.

Otherwise, hit `Deploy` and see what happens. You will likely get kicked momentarily as the periphery which ran the deploy command will be lost during update. But it should pop back up in a few seconds, and you can check the logs to see everything is working.

## Step 5: Add an Action for Improved  Automation

We can easily create an action that checks the current versions of all periphery
servers, and if any of them mismatch with Core, we can deploy an update.

Here is the basic Action script

```ts
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

## Beyond

You can setup renovate on a GitHub repository to create a PR 
when a new version of komodo is available. This repository has
an example of how you could might that in `.github/renovate.json`
You could then setup the stack to deploy with a webhook, so that
merging update PRs from renovate would trigger a periphery update.