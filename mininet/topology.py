#!/usr/bin/env python3
from mininet.net import Mininet
from mininet.node import Node, OVSKernelSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import os
import time

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')
    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def createTopology():
    net = Mininet(link=TCLink, switch=OVSKernelSwitch)
    firewall = net.addHost('firewall', cls=LinuxRouter)

    # Zones
    swWAN = net.addSwitch('s1', failMode='standalone')
    wanclient = net.addHost('wanclient', ip='203.0.113.10/24', defaultRoute='via 203.0.113.1')
    attacker = net.addHost('attacker', ip='203.0.113.50/24', defaultRoute='via 203.0.113.1')

    swDMZ = net.addSwitch('s2', failMode='standalone')
    web1 = net.addHost('web1', ip='172.16.1.10/24', defaultRoute='via 172.16.1.1')
    web2 = net.addHost('web2', ip='172.16.1.11/24', defaultRoute='via 172.16.1.1')

    swVPN = net.addSwitch('s3', failMode='standalone')
    vpnserver = net.addHost('vpnserver', ip='10.8.0.1/24', defaultRoute='via 10.8.0.254')

    swLAN = net.addSwitch('s4', failMode='standalone')
    lanclient1 = net.addHost('lanclient1', ip='192.168.10.10/24', defaultRoute='via 192.168.10.1')

    swADMIN = net.addSwitch('s5', failMode='standalone')
    admin = net.addHost('admin', ip='192.168.100.10/24', defaultRoute='via 192.168.100.1')

    for h, s in [(wanclient, swWAN), (attacker, swWAN), (web1, swDMZ), (web2, swDMZ), (vpnserver, swVPN), (lanclient1, swLAN), (admin, swADMIN)]:
        net.addLink(h, s)

    net.addLink(swWAN, firewall, intfName2='fwwan', params2={'ip': '203.0.113.1/24'})
    net.addLink(swDMZ, firewall, intfName2='fwdmz', params2={'ip': '172.16.1.1/24'})
    net.addLink(swVPN, firewall, intfName2='fwvpn', params2={'ip': '10.8.0.254/24'})
    net.addLink(swLAN, firewall, intfName2='fwlan', params2={'ip': '192.168.10.1/24'})
    net.addLink(swADMIN, firewall, intfName2='fwadmin', params2={'ip': '192.168.100.1/24'})

    info('*** Demarrage du reseau\n')
    net.start()

    # 1. FIREWALL
    info('*** Application des regles Firewall...\n')
    config_path = "/home/vboxuser/secured-network-infrastructure/configs/firewall_config.sh"
    if os.path.exists(config_path):
        firewall.cmd(f'bash {config_path}')
        info('[OK] Regles de securite appliquees.\n')

    # 2. DMZ
    info('*** Configuration HTTPS sur serveurs DMZ...\n')
    dmz_script = "/home/vboxuser/secured-network-infrastructure/configs/dmz_web_config.sh"
    if os.path.exists(dmz_script):
        for webhost in [web1, web2]:
            webhost.cmd(f'bash {dmz_script}')
            info(f'[OK] HTTPS configure sur {webhost.name}\n')
        time.sleep(2)

    # 3. ADMIN SSH
    info('*** Configuration SSH sur Admin...\n')
    admin.cmd('mkdir -p /run/sshd /root/.ssh')
    admin.cmd('ssh-keygen -A')

    sshd_config = "/home/vboxuser/secured-network-infrastructure/configs/sshd_hardened_config"
    if os.path.exists(sshd_config):
        admin.cmd(f'cp {sshd_config} /etc/ssh/sshd_config')
        admin.cmd('/usr/sbin/sshd -f /etc/ssh/sshd_config')
        info('[OK] SSH Admin actif sur port 2222.\n')
    else:
        info('[ERROR] Configuration SSH introuvable\n')

    # 4. VPN
    info('*** Lancement OpenVPN...\n')
    vpn_conf = "/home/vboxuser/secured-network-infrastructure/configs/vpn/server.conf"
    if os.path.exists(vpn_conf):
        vpnserver.cmd('mkdir -p /etc/openvpn/server')
        vpnserver.cmd(f'cp /home/vboxuser/secured-network-infrastructure/pki-export/* /etc/openvpn/server/')
        vpnserver.cmd(f'openvpn --config {vpn_conf} --daemon')
        time.sleep(2)
        info('[OK] OpenVPN demarre.\n')

    info('\n=== INFRASTRUCTURE PRETE ===\n')
    # --- 5. CONFIGURATION SNORT IDS ---
    info('*** Démarrage du système de détection d\'intrusion (Snort)...\n')
    snort_script = "/home/vboxuser/secured-network-infrastructure/configs/snort_setup.sh"

    if os.path.exists(snort_script):
        # Lancer Snort sur l'interface WAN du firewall
        firewall.cmd(f'bash {snort_script} fwwan')
        time.sleep(2)

        # Vérifier
        check_snort = firewall.cmd('pgrep snort')
        if check_snort.strip():
            info('✓ Snort IDS actif (interface fwwan)\n')
        else:
            info('⚠ ERREUR: Snort n\'a pas démarré\n')
    else:
        info('⚠ Script Snort introuvable\n')
    # --- 6. CONFIGURATION HEARTBEAT (HAUTE DISPONIBILITÉ) ---
    info('*** Configuration du cluster Haute Disponibilité (Heartbeat)...\n')
    ha_script = "/home/vboxuser/secured-network-infrastructure/configs/heartbeat_setup.sh"

    if os.path.exists(ha_script):
        # Configurer web1 (nœud actif)
        web1.cmd(f'bash {ha_script}')
        time.sleep(2)

        # Configurer web2 (nœud passif)
        web2.cmd(f'bash {ha_script}')
        time.sleep(2)

        # Vérifier la VIP
        check_vip = web1.cmd('ip addr show | grep 172.16.1.100')
        if '172.16.1.100' in check_vip:
            info('✓ Cluster HA actif - web1 est ACTIF (VIP: 172.16.1.100)\n')
        else:
            check_vip2 = web2.cmd('ip addr show | grep 172.16.1.100')
            if '172.16.1.100' in check_vip2:
                info('✓ Cluster HA actif - web2 est ACTIF (VIP: 172.16.1.100)\n')
            else:
                info('⚠ Cluster HA configuré (VIP en initialisation)\n')
    else:
        info('⚠ Script Heartbeat introuvable\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    createTopology()