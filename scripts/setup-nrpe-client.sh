# Configure the NRPE memory check

echo 'command[check_mem]=/usr/lib/nagios/plugins/check_mem -w 20 -c 10' | sudo tee -a /etc/nagios/nrpe.cfg

sudo systemctl restart nagios-nrpe-server

grep "^command\[check_mem\]" /etc/nagios/nrpe.cfg