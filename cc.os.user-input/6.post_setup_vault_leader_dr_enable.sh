if [[ ${VAULT_TOKEN} == "" ]] ; then
	# // VAULT_TOKEN ought to exist by now from either init or copy from vault1:
	VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ;
fi ;

if [[ ${VAULT_TOKEN} == "" ]] ; then printf 'VAULT ERROR: No Token Found.\n' ; exit 1 ; fi ;

vault write -f sys/replication/dr/primary/enable > /dev/null 2>&1 ;
if (($? == 0)) ; then printf 'VAULT: DR Successfully set "sys/replication/dr/primary/enable"\n' ;
else printf 'VAULT ERROR: Setting "sys/replication/dr/primary/enable"\n' ; fi ;

vault write sys/replication/dr/primary/secondary-token -format=json id=hsm2 2>/dev/null > vault_token_dr.json
if (($? == 0)) ; then printf 'VAULT: DR Replication "secondory-Token" generated.\n' ;
else printf 'VAULT ERROR: Generating DR Replication "secondory-Token"\n' ; fi ;

vault policy write dr2promotion >/dev/null - <<EOF
path "sys/replication/dr/secondary/promote" {
	capabilities = [ "update" ]
}
EOF
if (($? == 0)) ; then printf 'VAULT: DR Successfully writen "promote" policy write.\n' ;
else printf 'VAULT ERROR: Unable to write policy "promote"\n' ; fi ;

vault write auth/token/roles/failsafe allowed_policies=dr2promotion orphan=true renewable=false token_type=batch >/dev/null ;
if (($? == 0)) ; then printf 'VAULT: DR "auth/token/roles/failsafe" writen.\n' ;
else printf 'VAULT ERROR: Unable to write  "auth/token/roles/failsafe"\n' ; fi ;

vault token create -format=json -role=failsafe > vault_token_dr_batch.json ;
if (($? == 0)) ; then printf 'VAULT: DR Successfully created dr-token.\n' ;
else printf 'VAULT ERROR: Unable to create dr-token"\n' ; fi ;
