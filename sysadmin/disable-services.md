# Disable or Remove CUPS

[Cupsd](http://manpages.ubuntu.com/manpages/bionic/man8/cups-browsed.8.html) is a scheduler for CUPS, a service used by applications to interface with printers. There are several [Nmap NSE scripts](https://null-byte.wonderhowto.com/how-to/hack-like-pro-using-nmap-scripting-engine-nse-for-reconnaissance-0158681/) designed to pull information from CUPS services and pose a very minor security risk. However, if you very rarely need to interact with printers, CUPS can be disabled using the below [systemctl ](http://manpages.ubuntu.com/manpages/bionic/man1/systemctl.1.html) disable cups-browsed command. The changes will take effect after a reboot.

```bash
systemctl disable cups-browsed
```

_If you're never going to use a printer, CUPS can be removed entirely with sudo apt autoremove cups-daemon._

```bash
sudo apt autoremove cups-daemon
```

# Disable or Remove Avahi

The [Avahi daemon](http://manpages.ubuntu.com/manpages/bionic/man8/avahi-daemon.8.html) implements Apple's [Zeroconf](https://developer.apple.com/bonjour/) architecture (also known as "Rendezvous" or "Bonjour"). The daemon registers local IP addresses and static services using [mDNS/DNS-SD](https://en.wikipedia.org/wiki/Multicast_DNS).

In 2011, a [denial of service vulnerability](https://nvd.nist.gov/vuln/detail/CVE-2011-1002) was discovered in the avahi-daemon. While this CVE is quite old and low in severity, it illustrates how attackers on a local network find vulnerabilities in networking protocols and manipulate running services on a target's device.

If you don't plan on interacting with Apple products or services on other devices, avahi-daemon can be disabled using the following sudo systemctl disable avahi-daemon command.

```bash
sudo systemctl disable avahi-daemon
```

_Avahi can also be completely removed with sudo apt purge avahi-daemon._

```bash
sudo apt purge avahi-daemon
```

