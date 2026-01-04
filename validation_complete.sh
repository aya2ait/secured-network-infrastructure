#!/bin/bash

# Couleurs pour la lisibilité
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SCRIPT DE VALIDATION AUTOMATISE - PROJET LSI3 ===${NC}"
echo "Date : $(date)"
echo "-------------------------------------------------------"

# --- SECTION 2 : PARE-FEU & SEGMENTATION ---
echo "[SECTION 2 : Pare-feu]"
# T2.2 : WAN -> DMZ (Port 80)
timeout 2 curl -s --connect-timeout 2 http://172.16.1.10 > /dev/null
if [ $? -eq 0 ]; then
    echo -e "  T2.2 Accès WAN -> DMZ (HTTP) : ${GREEN}OK${NC}"
else
    echo -e "  T2.2 Accès WAN -> DMZ (HTTP) : ${RED}ECHEC${NC}"
fi

# T2.3 : WAN -> LAN (Isolation)
ping -c 1 -W 1 192.168.10.10 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  T2.3 Isolation WAN -> LAN    : ${GREEN}OK (Bloqué)${NC}"
else
    echo -e "  T2.3 Isolation WAN -> LAN    : ${RED}ECHEC (Passant)${NC}"
fi

# --- SECTION 4 : CHIFFREMENT ---
echo "[SECTION 4 : Chiffrement]"
# T4.1 : Présence Certificat HTTPS
openssl s_client -connect 172.16.1.10:443 -brief < /dev/null > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  T4.1 Certificat SSL          : ${GREEN}OK${NC}"
else
    echo -e "  T4.1 Certificat SSL          : ${RED}ECHEC${NC}"
fi

# --- SECTION 5 & 6 : VPN & SSH ---
echo "[SECTION 5 & 6 : VPN & Administration]"
# T6.3 : Accès direct Admin depuis LAN (Interdit)
nc -zv -w 1 192.168.100.10 2222 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  T6.3 Restriction Accès Admin : ${GREEN}OK (Bloqué)${NC}"
else
    echo -e "  T6.3 Restriction Accès Admin : ${RED}ECHEC (Ouvert)${NC}"
fi

# --- SECTION 9 : HAUTE DISPONIBILITE ---
echo "[SECTION 9 : Haute Disponibilité]"
# T9.1 : IP Virtuelle (VIP)
ping -c 1 -W 1 172.16.1.100 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  T9.1 État VIP (172.16.1.100) : ${GREEN}OK${NC}"
else
    echo -e "  T9.1 État VIP (172.16.1.100) : ${RED}ECHEC${NC}"
fi

echo "-------------------------------------------------------"
echo -e "${GREEN}Fin du rapport de validation.${NC}"