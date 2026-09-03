#!/usr/bin/env bash
#
# setup-nrpe-client.sh
#
# Automates the NRPE client-side setup used on each monitored Linux host
# (WebServer2-13) in this project: installs NRPE + the Nagios plugins,
# defines the check_load / check_mem commands, opens the NRPE port in the
# local firewall, and restarts the service.
#
# This script codifies the manual steps documented in docs/troubleshooting.md
# (in particular, the "NRPE: Command 'check_mem' not defined" fix).
#
# Usage:
#   sudo ./setup-nrpe-client.sh <nagios-server-ip>
#
# Tested on Ubuntu 22.04/24.04. Adjust package/service names for other
# distributions (e.g. yum/dnf + nrpe on RHEL-based systems).

set -euo pipefail

NAGIOS_SERVER_IP="${1:-}"
NRPE_CFG="/etc/nagios/nrpe.cfg"
PLUGIN_DIR="/usr/lib/nagios/plugins"

if [[ -z "$NAGIOS_SERVER_IP" ]]; then
    echo "Usage: sudo $0 <nagios-server-ip>" >&2
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

echo "==> Installing NRPE server and Nagios plugins..."
apt-get update -y
apt-get install -y nagios-nrpe-server nagios-plugins nagios-plugins-contrib

echo "==> Allowing the Nagios server (${NAGIOS_SERVER_IP}) in nrpe.cfg..."
if grep -q "^allowed_hosts=" "$NRPE_CFG"; then
    sed -i "s/^allowed_hosts=.*/allowed_hosts=127.0.0.1,${NAGIOS_SERVER_IP}/" "$NRPE_CFG"
else
    echo "allowed_hosts=127.0.0.1,${NAGIOS_SERVER_IP}" >> "$NRPE_CFG"
fi

echo "==> Defining check_load and check_mem commands..."
if ! grep -q "^command\[check_load\]" "$NRPE_CFG"; then
    echo "command[check_load]=${PLUGIN_DIR}/check_load -r -w .15,.10,.05 -c .30,.25,.20" >> "$NRPE_CFG"
fi
if ! grep -q "^command\[check_mem\]" "$NRPE_CFG"; then
    echo "command[check_mem]=${PLUGIN_DIR}/check_mem -w 20 -c 10" >> "$NRPE_CFG"
fi

echo "==> Making sure check_mem plugin is present and executable..."
if [[ ! -f "${PLUGIN_DIR}/check_mem" ]]; then
    echo "WARNING: ${PLUGIN_DIR}/check_mem not found." >&2
    echo "Install a check_mem plugin (e.g. from nagios-plugins-contrib) before continuing." >&2
else
    chmod 755 "${PLUGIN_DIR}/check_mem"
fi

echo "==> Opening NRPE port 5666 in the firewall (ufw)..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow from "${NAGIOS_SERVER_IP}" to any port 5666 proto tcp || true
fi

echo "==> Restarting nagios-nrpe-server..."
systemctl restart nagios-nrpe-server
systemctl enable nagios-nrpe-server

echo "==> Verifying locally..."
"${PLUGIN_DIR}/check_load" -r -w .15,.10,.05 -c .30,.25,.20 || true
"${PLUGIN_DIR}/check_mem" -w 20 -c 10 || true

echo "==> Done. From the Nagios server, verify with:"
echo "    /usr/local/nagios/libexec/check_nrpe -H <this-host-ip> -c check_load"
echo "    /usr/local/nagios/libexec/check_nrpe -H <this-host-ip> -c check_mem"
