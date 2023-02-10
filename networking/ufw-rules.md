# Create Firewall Exceptions & Configure a Secure DNS Resolver

_Allow DNS, HTTP, and HTTPS traffic out on the wireless interface using the following three commands._

```bash
sudo ufw allow out on <interface> to 1.1.1.1 proto udp port 53 comment 'allow DNS on <interface>'
sudo ufw allow out on <interface> to any proto tcp port 80 comment 'allow HTTP on <interface>'
sudo ufw allow out on <interface> to any proto tcp port 443 comment 'allow HTTPS on <interface>'
```