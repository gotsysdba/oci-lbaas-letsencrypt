#!/usr/bin/env ksh
#
# This script is called by certbot to automatically update the LoadBalancer
# during renewals; it is set by: certbot renew --deploy-hook ./oci_lb_cert_renewal.ksh 
# To avoid dynamic lookup of the LBaas, especially if 1+ in use, set the LB_OCID manually
typeset LB_OCID=""
#------------------------------------------------------------------------------
# GLOBAL/DEFAULT VARS
#------------------------------------------------------------------------------
typeset -i  RC=0
typeset -r  IFS_ORIG=$IFS
typeset -rx SCRIPT_NAME="${0##*/}"
typeset -r  LE_DIR="/etc/letsencrypt"

#------------------------------------------------------------------------------
# LOCAL FUNCTIONS
#------------------------------------------------------------------------------
function usage {
        print "${SCRIPT_NAME} Usage"
        print "${SCRIPT_NAME} MUST be run by root"
        return 0
}
#------------------------------------------------------------------------------
# INIT
#------------------------------------------------------------------------------
if [[ $(whoami) != "root" ]]; then
        usage && exit 1
fi

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
cert_number=$(ls ${LE_DIR}/csr/|tail -1|sed s/_.*//)
cert_name=$RENEWED_DOMAINS-$cert_number

print -- "Cert Name:   $cert_name"

# Lookup the LB OCID if not specified
if [[ -z ${LB_OCID} ]]; then
        oci search resource structured-search \
                --query-text "QUERY LoadBalancer resources where lifeCycleState == 'ACTIVE'" --query 'data.items[*].{ocid:"identifier"}' |
        while IFS=":" read KEY VALUE; do
                if [[ ${KEY} == *\"ocid\"* ]]; then
                        LB_OCID="${VALUE//\"/}"
                fi
        done
fi
print -- "Load Balancer OCID: ${LB_OCID}"
# Lookup the Listener Name and Backend Set Name
oci lb backend-set list --load-balancer-id ${LB_OCID} --query 'data[*].{name:"name"}' | 
while IFS=":" read KEY VALUE; do
        if [[ ${KEY} == *\"name\"* ]]; then
                LB_SET="${VALUE//\"/}"
        fi
done
print -- "Load Balancer Backend Set: ${LB_SET}"
oci lb load-balancer get --load-balancer-id ${LB_OCID} --query 'data.listeners.*|[?"ssl-configuration" != null].{name:name}' |
while IFS=":" read KEY VALUE; do
        if [[ ${KEY} == *\"name\"* ]]; then
                LIST_NAME="${VALUE//\"/}"
        fi
done
print -- "Load Balancer SSL Listener: ${LIST_NAME}"

print -- "Loading SSL Certificate into OCI"
oci lb certificate create --load-balancer-id $LB_OCID --certificate-name $cert_name \
        --public-certificate-file /etc/letsencrypt/live/$RENEWED_DOMAINS/cert.pem \
        --private-key-file /etc/letsencrypt/live/$RENEWED_DOMAINS/privkey.pem

sleep 30
print -- "Updating Listener ${LIST_NAME} to use Certificate"
oci lb listener update --force --listener-name ${LIST_NAME} --default-backend-set-name ${LB_SET} \
        --port 443 --protocol HTTP --load-balancer-id $LB_OCID --ssl-certificate-name $cert_name

exit $RC