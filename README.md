# homeassistant-ldapauth

simple bash script for integrating active directory authentication using ldap for user logins

1. place the script inside the homeassistant configuration directory and set correct privileges for read and execute.
2. enable the script as an auth_provider in homeassistant configuration.yaml 

homeassistant:
  auth_providers:
    - type: command_line
      command: /config/scripts/ldap-auth.sh
      meta: true

restart home assistant and try to login.
