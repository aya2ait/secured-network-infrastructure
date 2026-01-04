#!/bin/bash
# Configuration Zone-Based Policy Firewall (ZPF) - Projet LSI3

echo "=== Configuration du Pare-feu Zero Trust ==="

# 1. Nettoyage complet
iptables -F
iptables -X
iptables -t nat -F

# 2. Politique par défaut : DENY ALL (Modèle Zero Trust) 
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 3. Autorisation du trafic de retour (Stateful Inspection) 
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4. Règles INTER-ZONES explicites 

# --- ZONE WAN -> DMZ (Services Web) ---
# Autoriser HTTP (80) pour la redirection et HTTPS (443) 
iptables -A FORWARD -i fwwan -o fwdmz -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i fwwan -o fwdmz -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -i fwwan -o fwdmz -j LOG --log-prefix "FW-WAN-DMZ: " [cite: 26, 41]

# --- ZONE LAN -> DMZ (Accès interne) ---
# Accès restreint aux services web de la DMZ 
iptables -A FORWARD -i fwlan -o fwdmz -p tcp --match multiport --dports 80,443 -j ACCEPT

# --- ZONE VPN -> ADMIN (Administration sécurisée) ---
# SSH autorisé UNIQUEMENT via VPN 
iptables -A FORWARD -i fwvpn -o fwadmin -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i fwvpn -o fwadmin -j LOG --log-prefix "FW-VPN-ADMIN-SSH: "

# --- ZONE LAN -> WAN (Accès Internet via NAT) ---
# Permet aux clients LAN de sortir sur Internet
iptables -A FORWARD -i fwlan -o fwwan -j ACCEPT
iptables -t nat -A POSTROUTING -o fwwan -s 192.168.10.0/24 -j MASQUERADE

# 5. ISOLATION ET SÉCURITÉ (Checklist de validation) 

# Bloquer explicitement DMZ vers LAN (Anti-mouvement latéral) 
iptables -A FORWARD -i fwdmz -o fwlan -j LOG --log-prefix "FW-BLOCK-DMZ-LAN: "
iptables -A FORWARD -i fwdmz -o fwlan -j REJECT

# Bloquer tout trafic non autorisé vers le LAN (Test T2.3)
iptables -A FORWARD -o fwlan -j LOG --log-prefix "FW-REJECT-TO-LAN: "

# 6. Journalisation finale de tout ce qui est rejeté
iptables -A FORWARD -j LOG --log-prefix "FW-FINAL-DROP: "
iptables -A INPUT -j LOG --log-prefix "FW-INPUT-DROP: "

echo "=== Pare-feu configuré avec succès ==="