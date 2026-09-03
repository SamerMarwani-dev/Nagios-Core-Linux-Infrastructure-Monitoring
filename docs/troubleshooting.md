# Troubleshooting Notes

## 1. Missing NRPE command

Symptom:

```text
NRPE: Command 'check_mem' not defined
```

Resolution used during the lab:

- Define `check_mem` in the monitored server's NRPE configuration.
- Restart `nagios-nrpe-server`.
- Verify the command locally and from the Nagios server.

## 2. NRPE socket timeout

Symptom:

```text
CHECK_NRPE STATE CRITICAL: Socket timeout after 10 seconds.
```

Validation steps included:

```bash
sudo systemctl status nagios-nrpe-server
sudo ss -lntp | grep 5666
sudo ufw status verbose
sudo iptables -L -n
nc -vz -w 5 <target-ip> 5666
```

Packet-level verification was also performed with `tcpdump` on the monitored server.

For the public-addressed servers, SSH/22 and HTTP/80 were reachable while NRPE/5666 timed out. This isolated the remaining problem to network/firewall access rather than the local NRPE daemon.
