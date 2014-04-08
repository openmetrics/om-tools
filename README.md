## Server installation

Checkout/download and extract the contents of 'om-tools' to a local directory on desired host.

Run this script to install openmetrics server on localhost:

```
cd /tmp
git clone https://github.com/openmetrics/om-tools.git
cd om-tools
bash ./om-install.sh
```

## Agent (client) installation

**Before doing so...**

 - you must have an operational **openmetrics server**
 - you must have a **running SSH server** on the client host
 - you must have **SSH pubkey auth** (or at least know the login credentials) for **»root« user** on the client host

Checkout/download and extract the contents of om-tools to a local directory of your choice. Run ''om-agent-install.sh'' to install the openmetrics agent on given client host.

**NOTE** before executing, substitute server_host and client_host with hostnames (or IP addresses) fitting to your environment !

```
cd /tmp
git clone https://github.com/openmetrics/om-tools.git
cd om-tools
./om-agent-install.sh server_host client_host
```