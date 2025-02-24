# homeassistant-ldapauth

simple bash script for integrating active directory authentication using ldap for user logins.

This script will make homeassistant username default to e-mail attribute for domain user, eg. <username>@<mydomain.com>.

1. place the script inside the homeassistant configuration directory and set correct privileges for read and execute.
3. enable the script as an auth_provider in homeassistant configuration.yaml 

```
homeassistant:
  auth_providers:
    - type: command_line
      command: /config/scripts/ldap-auth.sh
      meta: true
```

3. restart home assistant and try to login.

```
docker restart homeassistant
```
