# oci-lbaas-letsencrypt

Oracle Cloud Infrastructure (OCI) Load Balancer as a Service - Automatic Certificate Management with LetsEncrypt/CertBot

## Introduction
Using [LetsEncrypt](https://letsencrypt.org/) and [CertBot](https://certbot.eff.org/) a valid, *free* SSL certificate can be generated, automatically renewed, and attached to an OCI Load Balancer.   This is especially useful when deploying an [OCI Highly Available (HA) APEX architecture fronted by Oracle Rest Data Services (ORDS)](https://github.com/ukjola/oci-arch-apex-ords)

## Recommendations
To avoid tying the automatic update to a human's OCI account, it is recommended to create an OCI Service User account with least privilege and use its API Keys for connectivity.

## Prerequisites
The Load Balancer's IP Address must be registered as the "A" record in DNS for the domain.  To verify, a nslookup/dig of the domain should resolve back to the Load Balancers IP.

## Installation
1. In OCI, generate an API Key and copy the configuration to be used later.  If generating the keys from the console, save the private key.

2. Connect to the OCI Compute Instance that will update the Load Balancer's certificate.  If you are here from the [oci-arch-apex-ords](https://github.com/ukjola/oci-arch-apex-ords) IaC repository, create a Bastion Session to the "core" OCI Compute instance for connectivity.

3. As the root user, create the `~/.oci` directory and store the API configuration generated in step 1 into a file called `config`.  Update the `key_file=<path to your private keyfile>` to point to a file that contains the private key specified in Step 1 (i.e. `~/.ssh/api_key`).

4. Copy/Clone the [config_letsencrypt.ksh](config_letsencrypt.ksh) scripts to the OCI Compute Instance.

5. Update [config_letsencrypt.ksh](config_letsencrypt.ksh) to indicate your WEB_ROOT directory.  If you are here from the [oci-arch-apex-ords](https://github.com/ukjola/oci-arch-apex-ords) IaC repository this is already set appropriately.

6. Run: `ksh config_letsencrypt.ksh -d <domain> -e email.address@valid.com` 
    * You should see output similar to the following:
    ```
    .
    .
    .
    These files will be updated when the certificate renews.
    Certbot has set up a scheduled task to automatically renew this certificate in the background.

    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    If you like Certbot, please consider supporting our work by:
     * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
     * Donating to EFF:                    https://eff.org/donate-le
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ```

## Automatic Renewals
1. Copy/Clone the [oci_lb_cert_renewal.ksh].  If you have more than one Load Balancer in OCI, update the script and specify the OCID of the Load Balancer for `LB_OCID`; otherwise the script will attempt to dynamically find it.

2. Set the RENEWED_DOMAINS environment from the CLI: `export RENEWED_DOMAINS=<your domain>`

3. Run `chmod u+x oci_lb_cert_renewal.ksh && ./oci_lb_cert_renewal.ksh`
    * You should see output similar to the following:
```
    .
    .
    .
    Updating Listener  lb-listener-443 to use Certificate
    {
    "opc-work-request-id": "ocid1.loadbalancerworkrequest...."
    }
```

At this point, your Load Balancer should be using a valid Certificate for your domain.  

To have it be automatically updated on renewals, run the following:
`/var/lib/snapd/snap/bin/certbot renew --deploy-hook <path_to_script>/oci_lb_cert_renewal.ksh`

You should see output similar to the following:
```
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/<domain>.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Certificate not yet due for renewal

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
The following certificates are not due for renewal yet:
  /etc/letsencrypt/live/<domain>/fullchain.pem expires on 2021-12-08 (skipped)
No renewals were attempted.
No hooks were run.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```