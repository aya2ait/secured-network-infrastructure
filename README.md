# Secured Network Infrastructure 
Mini Projet : Infrastructure Réseau Sécurisée (Zero Trust)

Module : Sécurité des systèmes informatiques (LSI3 s5)
Realise en Trinome : Aya Ait Sidi Abdelkrim /Fatima Zahraa Ait Hssaine /Oumaima Boughdad

Année Universitaire : 2025/2026

📋 Description
Ce projet implémente une infrastructure réseau sécurisée simulée sous Mininet, respectant les principes du modèle Zero Trust (aucune confiance par défaut). L'architecture est segmentée en plusieurs zones de sécurité protégées par un pare-feu centralisé faisant office de sonde IDS.

Fonctionnalités principales :
Segmentation Stricte : Zones WAN, LAN, DMZ, ADMIN et VPN isolées par des interfaces réseau distinctes.

Pare-feu Stateful : Filtrage rigoureux via iptables avec une politique par défaut DROP.

Haute Disponibilité (HA) : Cluster de serveurs Web en DMZ avec gestion d'IP Virtuelle (VIP) via Heartbeat.

Accès Distant Sécurisé : Tunnel OpenVPN pour l'administration et accès SSH durci (Port 2222, clés asymétriques).

Sécurité Web : Serveurs configurés en HTTPS (TLS) avec certificats auto-signés via OpenSSL.

Détection d'Intrusion : Sonde Snort configurée sur l'interface WAN pour détecter les scans de ports et attaques réseau.

Automatisation : Script de validation globale exécutant l'intégralité de la checklist de sécurité.

⚙️ Prérequis
Machine virtuelle Ubuntu (20.04 ou 22.04).

Mininet installé (sudo apt install mininet).

Outils réseau : snort, iptables, openvpn, heartbeat, curl, nmap.

🚀 Installation et Démarrage
Étape 1 : verification des installations 
Le script de verification nous assure que toutes les dependance en ete installe.

Bash

chmod +x setup_environment.sh
sudo ./setup_environment.sh
Étape 2 : Lancement de l'Infrastructure
Le script Python orchestre la topologie, configure le routage entre les zones et active les services de sécurité.

Bash

sudo python3 topology.py
✅ Validation et Tests
Test de Validation Automatique


mininet> lanclient1 /home/vboxuser/secured-network-infrastructure/scripts/test.sh
Rapport : Un fichier rapport_final.txt est généré, contenant le succès ou l'échec de chaque test de sécurité.

Exemples de tests manuels (CLI Mininet)
Vérification du Pare-feu :

Bash

mininet> attacker ping -c 1 192.168.10.10   # Échec (Isolation WAN/LAN)
Vérification de la Haute Disponibilité :

Bash

mininet> web1 ip addr del 172.16.1.100/24 dev web1-eth0
mininet> web2 ip addr add 172.16.1.100/24 dev web2-eth0
mininet> lanclient1 ping -c 1 172.16.1.100  # Succès (Basculement VIP)
