#! /bin/bash

# 
# Debian install script for sssd
#

LDAP_DEFAULT_AUTHTOK=""
LDAP_ACCESS_FILTER_MEMBEROF=""
OS=""

if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

function usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " -h --help          Display this help message"
  echo " -p, --password     REQUIRED - Password for read-only LDAP user"
  echo " -g, --group        REQUIRED - Group passed to filter that the user must be a member of"

  exit 1
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
    -h | --help)
        usage
        ;;
    -p | --password)
        shift
        LDAP_DEFAULT_AUTHTOK=$1
        ;;
    -g | --group)
        shift
        LDAP_ACCESS_FILTER_MEMBEROF=$1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

if [[ $LDAP_DEFAULT_AUTHTOK == "" ]]; then
    echo "You must provide a password";
    usage
    exit 1;
fi

if [[ $LDAP_ACCESS_FILTER_MEMBEROF == "" ]]; then
    echo "You must provide a group";
    usage
    exit 1;
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >> /dev/null 2>&1; then
    OS=$(lsb_release -si)
elif [-f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
else
    OS=$(uname -s)
fi

if [[ $OS != "Debian" && $OS != "Debian GNU/Linux" ]]; then
    echo "Script only supports Debian at the moment";
    echo "Current Detected Distro: $OS";
    exit 1;
fi

# Install sssd and required packages
apt update && apt -y install libpam-sss libnss-sss sssd-tools libsss-sudo

if [[ $? > 0 ]]; then
    echo "The installation failed, exiting script.";
    exit 1;
fi

# Create sssd config
cat > /etc/sssd/sssd.conf << EOF
[sssd]
services = nss, pam, ssh
config_file_version = 2
reconnection_retries = 3
sbus_timeout = 30
domains = ldap.goauthentik.io

[nss]
filter_groups = root,localuser,ldap,named,avahi,dbus
filter_users = root,localuser,ldap,named,avahi,dbus
reconnection_retries = 3
override_shell = /bin/bash

[pam]
reconnection_retries = 3
offline_credentials_expiration = 60

[domain/ldap.goauthentik.io]
ldap_id_use_start_tls = True
cache_credentials = True
ldap_search_base = dc=ldap,dc=goauthentik,dc=io
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://login.lan.techhaven.io
ldap_default_bind_dn = cn=ldap-readonly-user,ou=users,dc=ldap,dc=goauthentik,dc=io
ldap_default_authtok = $LDAP_DEFAULT_AUTHTOK
ldap_tls_reqcert = never
ldap_tls_cacert = /etc/ssl/openldap/certs/cacert.pem
ldap_tls_cacertdir = /etc/ssl/openldap/certs
ldap_search_timeout = 50
ldap_network_timeout = 60
ldap_schema = rfc2307bis
ldap_search_base = dc=ldap,dc=goauthentik,dc=io
ldap_user_search_base = ou=users,dc=ldap,dc=goauthentik,dc=io
ldap_group_search_base = dc=ldap,dc=goauthentik,dc=io
ldap_user_object_class = user
ldap_user_name = cn
ldap_group_object_class = group
ldap_group_name = cn
access_provider = ldap
ldap_access_order = filter
ldap_access_filter = memberOf=cn=$LDAP_ACCESS_FILTER_MEMBEROF,ou=groups,dc=ldap,dc=goauthentik,dc=io
EOF

if [[ $? > 0 ]]; then
    echo "Failed to write to /etc/sssd/sssd.conf";
    exit 1;
fi

# Create host file entry for login server
echo "100.64.0.8 login.lan.techhaven.io" >> /etc/hosts

if [[ $? > 0 ]]; then
    echo "Failed to write to /etc/hosts";
    exit 1;
fi

# Create certs directory if it doesn't exist
if [[ ! -e /etc/sssl/openldap/certs ]]; then
    mkdir -p /etc/ssl/openldap/certs;
fi

# Copy cacert to the directory
cat > /etc/ssl/openldap/certs/cacert.pem << 'EOF'
-----BEGIN CERTIFICATE-----
MIIFTzCCAzegAwIBAgIUOfbf+viL0UQ5nFgj/Y1qnJHEBvIwDQYJKoZIhvcNAQEL
BQAwNzELMAkGA1UEBhMCVVMxEzARBgNVBAgMClNvbWUtU3RhdGUxEzARBgNVBAoM
ClRlY2ggSGF2ZW4wHhcNMjMwMzA5MTYyNTMzWhcNMzMwMzA2MTYyNTMzWjA3MQsw
CQYDVQQGEwJVUzETMBEGA1UECAwKU29tZS1TdGF0ZTETMBEGA1UECgwKVGVjaCBI
YXZlbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOO8aeFpp4pIeBZH
XPTNQlbtvORcA/EFx+//kQ0sRxXpH4D7ll3KroJTgSZ/4uCHs/Z3a1bhvxrp9mOg
NIqygiPx5viTCCUXSSlVUPsBqXc9WGv54DhTuRmbCuT/qyRMhSb3cvmrmwBa7L/z
KArFH6idTCphNZxnb3rE+UF/DmJQz9/xFSsIYmyRfs0E352z+g1aKcSxv00X4ftI
quUZ7Y32tVOdU6JjRfk7ATvUGhCm7YxqLvtKQth224G5fGXwx2ia0Psj9BjPri3W
Xeo+c5cqtMymw6BAkYa0Bq0syY3l9qwp4JFLXBrXKlzQIoPTboaaLPNk2FxKWOH2
xIPwl8+QKBDGPxFOuMHJ8oZIpAKdcnyumAT+S4oY3VCGQ3l+FySHxG5dRMIj7mJP
BGwtL1M1VtIJpHIFPzvggt5QRrRStVSBkZVHWLR2GqrD1e2HkZHT0cNN8By6LTgJ
rF3wXXcMJnm4ifAKnhdYOnGCsJ5DxW+RMYdlkzNuOufiYp+6/WiBpVsQUEO3hFtD
pg5V+4MGq6m2en32xCdLGuJaqH0ssvmpUYjp50zn/omrl0hIKMKDFSES8E12SDLR
vUQgApP4y6ZCPg5j+4NTm6LQNvAMaZQeR2ZupzeqBlKGZ0CfMEcauJURmk2QCllR
DfyYNVJV708M380TVdXaJAir1HJxAgMBAAGjUzBRMB0GA1UdDgQWBBQT2ueYONYT
/pNJfELe60cUvkexNDAfBgNVHSMEGDAWgBQT2ueYONYT/pNJfELe60cUvkexNDAP
BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4ICAQA1abCLo1O41pFzBsh5
/H6dyPQhBzMslUWp1s6LkjXqG0B+J/TkIFESy8A4AwkwFdAL2tNS6Eo1JloEJkmh
Z0e0KvxFK2VhmZgZejBTToqZ7u7FZYgQMksv6JKDY/iexYIoqawvirl6TN63K3Al
54KW5FiHjUqkLoQ9VfPZwHLJmEHTc/8+CbbzU46/SQclE6z0UM+tRvCnB3roQY04
2kA5vZpNxJzUeUA2t7ATe3g8xLWRY8og8HJPBPOmlYpelsSWhFVRm0vyKJInDjdX
TkpBc/vCFta6YyEiR2VrA3UebGNJrS4Mjf6yy6KF2nR6k+9O2RVO2Xo2IR1AqiHr
AHtxnr6cv3wysrD/uqY5lOpr1wcngc4IHYTtD6Hu5UDBOpMrfEedczQsxjrn5ai4
YM2lqsLhkf9g4Ut/G0euOMGOU0E4+grbqgzLBMgx/sJ3VBeCwMbvmxwkdiGcixHO
FltgKKiIqNxRAfs+gAYQOC6Qq8fbiezo2Q73wYP+0c6/RJ9kDciMdshaCANdT7lI
EYeCuuT3KjbNGJM0aFkPpGLU8GE/gdzkeWuMdJXK0/7tjyviyKxJS8z1QYAGtmpW
C+jdZSOfrWQ4cMBfEucH1UTNo1qw51hfEelVDLoMYs+JtJ4/eAawJapj444KqIuq
zwKerEk8FxxffPG0ZFtYPQUFXQ==
-----END CERTIFICATE-----
EOF

if [[ $? > 0 ]]; then
    echo "Failed to write to /etc/ssl/openldap/certs/cacert.pem";
    exit 1;
fi

# Set TLS_CACERT location in ldap config
echo "TLS_CACERT    /etc/ssl/openldap/certs/cacert.pem" >> /etc/ldap/ldap.conf

if [[ $? > 0 ]]; then
    echo "Failed to write to /etc/ldap/ldap.conf";
    exit 1;
fi

# Change permission to /etc/sssd
chmod 600 -R /etc/sssd

# Restart sssd
systemctl restart sssd

if ! grep -q "pam_mkhomedir.so skel=/etc/skel/ umask=0022" /etc/pam.d/common-session; then
    # Automatically create home directory for authenticated users
    sed -i '/session[[:space:]]\+optional[[:space:]]\+pam_sss\.so/a session required        pam_mkhomedir.so skel=\/etc\/skel\/ umask=0022' /etc/pam.d/common-session;
fi