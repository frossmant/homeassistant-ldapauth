#!/bin/bash
#set -x

# verify that openldap is installed
which ldapsearch &>/dev/null
[[ $? -ne 0 ]] && { apk add openldap openldap-back-mdb openldap-clients &>/dev/null ;}

# LDAP Server
SERVER="ldap://127.0.0.1:389"

# Service Account Credentials
BIND_DN="cn=homeassistant-ldap,ou=users,dc=mydomain,dc=com"
BIND_PW="homeassistant-ldap-password"

# Define Base DN
BASEDN="dc=mydomain,dc=com"

# Set access group for normal users
ACCESS_GROUP="CN=access-smarthome,OU=groups,DC=mydomain,DC=com"

# Set administrative group for homeassistant users
ADMIN_GROUP="CN=smarthome-adm,OU=groups,DC=mydomain,DC=com"

# Path to to logfile for script output
__PATH_LOG="/config/authentication.log"

# Timeout in seconds
TIMEOUT=3

# Read username (email) and password from arguments
[[ -z $username ]] && username=$1
[[ -z $password ]] && password=$2
__USER_MAIL="${username}"
__USER_PASW="${password}"

# Ensure both email and password are provided
if [[ -z "$__USER_MAIL" || -z "$__USER_PASW" ]]; then
    exit 1
fi

USER_DN=$(ldapsearch -x -LLL -H "$SERVER" -D "$BIND_DN" -w "$BIND_PW" \
    -b "$BASEDN" "(&(objectClass=person)(mail=$__USER_MAIL))" dn 2>/dev/null | awk '/^dn:/ {print $2}')

ldapsearch -x -LLL -H "$SERVER" -D "$BIND_DN" -w "$BIND_PW" -b "$BASEDN" "(&(objectClass=person)(mail=$__USER_MAIL))" dn

# If no user is found, exit
if [[ -z "$USER_DN" ]]
then
	echo "ldap authentication with service account ${BIND_DN} failed to lookup user" >> "${__PATH_LOG}"
    exit 1
else
	echo "ldap authentication with service account ${BIND_DN} success" >> "${__PATH_LOG}"
	echo "found ldap user ${USER_DN}" >> "${__PATH_LOG}"
fi

# Step 2: Check if the user is a member of `access-smarthome`
ACCESS_MEMBER=$(ldapsearch -x -LLL -H "$SERVER" -D "$BIND_DN" -w "$BIND_PW" \
    -b "$ACCESS_GROUP" "(member=$USER_DN)" dn 2>/dev/null | grep -q "^dn:" && echo "yes")

ADMIN_MEMBER=$(ldapsearch -x -LLL -H "$SERVER" -D "$BIND_DN" -w "$BIND_PW" \
    -b "$ADMIN_GROUP" "(member=$USER_DN)" dn 2>/dev/null | grep -q "^dn:" && echo "yes")


# If user is not in `access-smarthome`, deny login
if [[ "$ACCESS_MEMBER" != "yes" ]]
then
	echo "ldap user account ${__USER_MAIL} is NOT member in access group, will NOT allow login to home assistant" >> "${__PATH_LOG}"
	exit 1
else
	echo "ldap user account ${__USER_MAIL} is a member in access group, will ALLOW login to home assistant" >> "${__PATH_LOG}"
fi

# Determine user role
if [[ "$ADMIN_MEMBER" == "yes" ]]
then
    __USER_ROLE="system-admin"
	echo "ldap user account ${__USER_MAIL} have administrative privileges"  >> "${__PATH_LOG}"
else
    __USER_ROLE="system-user"
	echo "ldap user account ${__USER_MAIL} have normal user privileges" >> "${__PATH_LOG}"
fi

# Step 3: Validate the user's password by binding as them
ldapsearch -x -LLL -H "$SERVER" -D "$USER_DN" -w "$__USER_PASW" -b "$USER_DN" "(objectClass=person)" dn &>/dev/null

# If authentication succeeds, print the username (email) and exit successfully
if [[ $? -eq 0 ]]
then
	echo "ldap authentication with user account ${__USER_MAIL} success" >> "${__PATH_LOG}"
	echo "  passing variables to home assistant"  >> "${__PATH_LOG}"
	echo "    name = ${__USER_MAIL}"  >> "${__PATH_LOG}"
	echo "    group = system-admin"  >> "${__PATH_LOG}"
	echo "name = ${__USER_MAIL}"
	echo "group = ${__USER_ROLE}"
    exit 0
else
	echo "ldap authentication with user account ${__USER_MAIL} fail" >> "${__PATH_LOG}"
    exit 1
fi
