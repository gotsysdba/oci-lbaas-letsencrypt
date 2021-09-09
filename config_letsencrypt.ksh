#!/usr/bin/env ksh
#------------------------------------------------------------------------------
# GLOBAL/DEFAULT VARS
#------------------------------------------------------------------------------
typeset -i  RC=0
typeset -r  IFS_ORIG=$IFS

# Default specific to ORDS, can be overwritten
typeset WEB_ROOT="/opt/oracle/ords/config/ords/standalone/doc_root"

#------------------------------------------------------------------------------
# LOCAL FUNCTIONS
#------------------------------------------------------------------------------
function usage {
	print -- "${SCRIPT_NAME} Usage"
	print -- "${SCRIPT_NAME} MUST be run by root"
	print -- "\t\t${SCRIPT_NAME} -d <DOMAIN> [-e <email>] [-h]"
	return 0
}

#------------------------------------------------------------------------------
# INIT
#------------------------------------------------------------------------------
if [[ $(whoami) != "root" ]]; then
	usage && exit 1
fi

while getopts :d:e:h args; do
	case $args in
		d) typeset -r MYDOMAIN="${OPTARG}" ;;
		e) typeset -r MYEMAIL="${OPTARG}" ;;
		h) usage ;;
	esac
done

if [[ -z ${MYDOMAIN} ]]; then
	usage && exit 1
fi

if [[ -z ${MYEMAIL} ]]; then
	typeset -r EMAIL="--register-unsafely-without-email"
else
	typeset -r EMAIL="--email ${MYEMAIL}"
fi


if [[ ! -f ${HOME}/.oci/config ]]; then
	print -- "Error: Unable to find ${HOME}/.oci/config; Unable to continue"
	exit 1
fi

print -- "Ensuring Permissions on ${HOME}/.oci/config are correct"
oci setup repair-file-permissions --file ${HOME}/.oci/config

typeset -r KEY_FILE=$(grep key_file  ~/.oci/config |awk -F= '{print $2}')
print -- "Ensuring Permissions on ${KEY_FILE} are correct"
oci setup repair-file-permissions --file ${KEY_FILE}

if [[ ! -d ${WEB_ROOT} ]]; then
	print -- "Unable to find ${WEB_ROOT}; please create and restart web server"
	exit 1
fi
#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
print -- "Ensuring OCI Repo is enabled"
yum-config-manager --enable ol7_developer_EPEL

print -- "Updating System"
yum -y update

print -- "Installing snapd"
yum -y install snapd

print -- "Removing dependencies no longer required"
yum -y autoremove

print -- "Setting up snapd.socket"
systemctl enable --now snapd.socket
sleep 60
export PATH=$PATH:/var/lib/snapd/snap/bin

print -- "Updating snapd"
snap install core; snap refresh core

print -- "Symlinking /var/lib/snapd/snap to / for classic mode"
if [[ ! -d /snap ]]; then
	ln -s /var/lib/snapd/snap /
	print -- "Symlink'd"
else
	print -- "Symlink already exists"
fi

print -- "Installing CertBot"
snap install --classic certbot

print -- "Registering CertBot"
typeset CMD="certbot certonly --webroot --non-interactive --agree-tos"
CMD="${CMD} ${EMAIL} --webroot-path ${WEB_ROOT} --domains ${MYDOMAIN}"

print -- "Running: ${CMD}"
eval ${CMD}
RC=$?

exit $RC