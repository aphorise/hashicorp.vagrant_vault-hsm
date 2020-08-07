# // VAULT_TOKEN ought to exist by now from either init or copy from vault1:
if [[ ${VAULT_TOKEN} == "" ]] ; then VAULT_TOKEN=$(grep -F VAULT_TOKEN ${HOME_PATH}/.bashrc | cut -d'=' -f2) ; fi ;
if [[ ${VAULT_TOKEN} == "" ]] ; then printf 'VAULT ERROR: No Token Found.\n' ; exit 1 ; fi ;

DR_TOKEN="$(cat vault_token_dr.json | jq -r '.wrap_info.token')" ;
if [[ ${DR_TOKEN} == "" ]] ; then printf 'VAULT ERROR: DR Token NOT Found.\n' ; exit 1 ; fi ;

vault write /sys/replication/dr/secondary/enable token=${DR_TOKEN} 2> /dev/null ;
if (($? == 0)) ; then printf 'VAULT: SECONDARY-DR Replication Token Accepted.\n' ;
else printf 'VAULT ERROR: Applying SECONDARY-DR token.\n' ; fi ;

# // invoke manually
#VAULT_TOKEN_DR_BATCH="$(cat vault_token_dr_batch.json | jq -r '.auth.client_token')" ;
#vault write /sys/replication/dr/secondary/promote dr_operation_token=${VAULT_TOKEN_DR_BATCH} ;
