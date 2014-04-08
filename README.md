# Welcome to openmetrics

## Server installation

Checkout/download and extract the contents of om-tools to a local directory of your choice. Run this script to install openmetrics server:

```
cd /tmp
git clone https://github.com/openmetrics/om-tools.git
bash ./om-install.sh
```

This will start the dialog-based openmetrics server installer on localhost.

## Agent (client) installation

**Requirements**

 - you must have an operational **openmetrics server**
 - you must have a **running SSH server** on the client host
 - you must have **SSH pubkey auth** for client host (or at least know the login credentials) **for »root« user** on the client host

Checkout/download and extract the contents of om-tools. Run agent installer:

**NOTE** replace om_client_host \& om_server_host with an IP address or fully qualified domain name (FQDN)

```
cd /tmp
git clone https://github.com/openmetrics/om-tools.git
./om-agent-install.sh om_server_host <om_client_host
```

This will try to install the openmetrics agent installation on give <client_host> over SSH.