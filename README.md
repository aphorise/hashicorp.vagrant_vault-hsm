# HashiCorp `vagrant` demo of **`vault`** HSM with SoftHSM.

This repo contains a `Vagrantfile` mock of a [Vault](https://www.vaultproject.io/) setup using [**HSM**](https://www.vaultproject.io/docs/enterprise/hsm) :lock_with_ink_pen: provided libs (.so) from [SoftHSM](https://www.opendnssec.org/softhsm/) that's conceptually similar to other [auto-unsealing types on offer in Vault](https://www.vaultproject.io/docs/configuration/seal). The prerequisite is that a working hsm is well configured with hardware and its dependencies (OS libs) all properly setup as per the vendor specific instructions before attempting to configure it in Vault.

Some CLI commands to consider in testing or diagnosing HSM, prior to Vault, may include:

```bash
sudo dmesg -p ;  # helpful in showing any hardware / software issue interfacing with HSM
HSM_LIB='/usr/local/lib/softhsm/libsofthsm2.so' ;  # others: '/opt/safenet/8.3.1/libIngPKCS11.so'
pkcs11-tool --module ${HSM_LIB} -L ;  # list HSM slots created or available
pkcs11-tool --module ${HSM_LIB} -l -t ;  # attempt slot use
```

:warning: **IMPORTANT**: OS & kernel level updates or changes can impair or negatively impact HSM integrations that were known to be previously working. Be cautious and careful of any level of modification being made. :warning:


## Makeup & Concept
The first Vault node (`hsm1-vault1`) is that of a primary CLUSTER_A (`hsm1`) & a similar second Vault node (`hsm2-vault1`) is a [DR Replication](https://learn.hashicorp.com/vault/operations/ops-disaster-recovery) that part of CLUSTER_B (`hsm2`).

A depiction below shows relations & the network [connectivity and overall PRC, Gossip, UDP/TCP port](https://learn.hashicorp.com/vault/operations/ops-reference-architecture#network-connectivity-details) expected to be produced. After initial setups the DR Demotion & Promotion sets can be followed to test similar flows.

```
                                 VAULT SERVERS:
                                        ▒
          (cluster: hsm1 - PRIMARY)     ▒       (cluster: hsm2 - DR)
             ._________________.253     ▒        ._________________.243
             |   hsm1-vault1   |        ▒        |   hsm2-vault1   |
 ... + other | hsm auto-unseal |◄-------▒-------►| hsm auto-unseal | ... + other
  nodes ...  |_________________|        ▒        |_________________|  nodes ...
                                        ▒
                                     NETWORK
```

Private IP Address Class D is defined in the **`Vagrantfile`** and can be adjusted to your local network if needed.
A.B.C.200 node is consider as the transit unseal node and the first raft cluster node is A.B.C.252 decrement with each higher vault node.


### Prerequisites
Ensure that you already have the following hardware & software requirements:
 
##### HARDWARE & SOFTWARE
 - **RAM** **2-5**+ Gb Free at least (ensure you're not hitting SWAP either or are < 100Mb) needing more if using Consul.
 - **CPU** **2-5**+ Cores Free at least (2 or more per instance better)  needing more if you're using Consul.
 - **Network** interface allowing IP assignment and interconnection in VirtualBox bridged mode for all instances.
 - - adjust `sNET='en0: Wi-Fi (Wireless)'` in **`Vagrantfile`** to match your system.
 - [**Virtualbox**](https://www.virtualbox.org/) with [Virtualbox Guest Additions (VBox GA)](https://download.virtualbox.org/virtualbox/) correctly installed.
 - [**Vagrant**](https://www.vagrantup.com/)
 - **Few** (**2**) **`shell`** or **`screen`** sessions to allow for multiple SSH sessions.
 - :lock: **NOTE**: An [enterprise license](https://www.hashicorp.com/products/vault/pricing/) will is needed for both [HSM Support](https://www.vaultproject.io/docs/enterprise/hsm) as well as [DR replication](https://www.vaultproject.io/docs/enterprise/replication/) features. **BY DEFAULT**: **not setting** a valid license (in `vault_license.txt`) is possible for **trail / evaluation purposes only** using older **unsupported** versions of **1.7.10** with a limit of **29 minutes** per node (warning messages should be apparent throughout before auto-sealing after). :lock:


## Usage & Workflow
Refer to the contents of **`Vagrantfile`** for the number of instances, resources, Network, IP and provisioning steps. The default Vault storage type is **Integrated Storage (Raft)** when Consul related blocks in the `Vagrantfile` are not enabled and related variables (eg: `iCLUSTERA_C`) are set to zero (0); uncomment these and set as needed. 

The provided **`4.install_vault.sh`** is an installer script with which **Inline Environment Variables** can be set for specific versions and other settings that are part of downloading Vault HSM binaries and writing a configuration as well as performing an [**init** of Vault](https://www.vaultproject.io/docs/commands/operator/init).

The **`2.install_hsm.sh`** is another that downloads the latest unstable releases of Softhsm2 libraries (using OS Package Manager) and also has commented references for building Softhsm2 from source.

Other example changes in the `Vagrantfile` include: **`Debian`** (or **`Ubuntu`**) may be set as the **OS** which have been confirmed to work the same (tested with: `Ubuntu: 18.04 - bionic` & `Debian: 10.3 - buster`).

If you wish to use the default Shamir unseal instead of HSM or any other auto-unseal then comment, remove or edit the contents of: **`vault_files/vault_seal.hcl`**. If you already have Vault HSM / Enterprise License then populate **`vault_files/vault_license.txt`** with the key that will be applied once the cluster has been initialised.


```bash
vagrant up --provider virtualbox ;
# // ... output of provisioning steps.

vagrant global-status ; # should show running nodes
  # id       name        provider   state   directory
  # -------------------------------------------------------------------------------------
  # e4e0770  hsm1-vault1 virtualbox running /home/auser/hashicorp.vagrant_vault-hsm
  # be0b162  hsm2-vault1 virtualbox running /home/auser/hashicorp.vagrant_vault-hsm

# // On a separate Terminal session check status of vault2 & cluster.
vagrant ssh hsm1-vault1 ;
  # ...

#vagrant@hsm1-vault1:~$ \
vault status ;

# // generating new HSM keys and change conf
#vagrant@hsm1-vault1:~$ \
HSM_SLOT=$(sudo softhsm2-util --init-token --slot 1 --label "hsm:v2:vault" --pin 1234 --so-pin 1234) ;
HSM_SLOT=${HSM_SLOT/*slot\ /} ;
sudo sed -i "s/slot.*/slot\t\t= \"${HSM_SLOT}\"/g" /etc/vault.d/vault.hcl ;
sudo sed -i "s/v1:vault/v2:vault/g" /etc/vault.d/vault.hcl ;
curl -H "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/sys/sealwrap/rewrap ;
  # ...
# ^^^ this will break things after restarting as I do not know how key rotations should be done.

#vagrant@hsm1-vault1:~$ \
sudo service vault restart ;

#vagrant@hsm1-vault1:~$ \
sudo journalctl -u vault.service -f --output cat ;
  # ...

# // ---------------------------------------------------------------------------
# when completely done:
vagrant destroy -f hsm1-vault1 hsm2-vault1 ; # ... destroy all - ORDER IMPORTANT
vagrant box remove -f debian/buster64 --provider virtualbox ; # ... delete box images
```


## Cluster DR Promotion & Re-Promotion

Other potential operations not covered in the context of this article may include DR Cluster activation:

```
vault read sys/replication/status -format=json ;
vault read sys/replication/dr/status -format=json ;

# // Cluster B - DR Activate
# using above token:
VAULT_TOKEN_DR_BATCH=$(cat vault_token_dr_batch.json | jq -r '.auth.client_token') ;
vault write /sys/replication/dr/secondary/promote dr_operation_token=${VAULT_TOKEN_DR_BATCH} ;
```  


## Notes
This is intended as a mere practise / training exercise.

See also:
 - [Vault Learn: HSM Integration - Seal Wrap](https://learn.hashicorp.com/vault/security/ops-seal-wrap)
 - [Vault Learn: HSM Integration - Entropy Augmentation](https://learn.hashicorp.com/vault/security/hsm-entropy)
 - [Vault Learn: Disaster Recovery Replication Setup](https://learn.hashicorp.com/vault/operations/ops-disaster-recovery)
 - [Vault API: `/sys/sealwrap/rewrap`](https://www.vaultproject.io/api-docs/system/sealwrap-rewrap)
 - [Vault DOC: Vault Enterprise HSM Support](https://www.vaultproject.io/docs/enterprise/hsm)

------
