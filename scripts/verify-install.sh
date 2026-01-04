#!/bin/bash

################################################################################
# Script de vérification de l'installation
# Infrastructure Réseau Sécurisée
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

check_pass() {
    echo -e "${GREEN}✅ PASS${NC} - $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC} - $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC} - $1"
    ((WARN_COUNT++))
}

check_info() {
    echo -e "${BLUE}ℹ️  INFO${NC} - $1"
}

################################################################################
# VÉRIFICATION 1 : SYSTÈME
################################################################################

check_system() {
    print_header "1. VÉRIFICATION DU SYSTÈME"

    # OS
    if [ -f /etc/debian_version ]; then
        check_pass "OS Debian détecté : $(cat /etc/debian_version)"
    else
        check_warn "Système non-Debian détecté"
    fi

    # Kernel
    check_info "Kernel : $(uname -r)"

    # RAM
    total_ram=$(free -h | awk '/^Mem:/ {print $2}')
    check_info "RAM totale : $total_ram"

    # Espace disque
    disk_space=$(df -h / | awk 'NR==2 {print $4}')
    check_info "Espace disque disponible : $disk_space"

    # Droits root
    if [ "$EUID" -eq 0 ]; then
        check_pass "Script exécuté avec les droits root"
    else
        check_warn "Script non exécuté avec sudo (nécessaire pour certains tests)"
    fi
}

################################################################################
# VÉRIFICATION 2 : OUTILS RÉSEAU
################################################################################

check_network_tools() {
    print_header "2. VÉRIFICATION DES OUTILS RÉSEAU"

    tools=(
        "ip:iproute2"
        "ping:iputils-ping"
        "tcpdump:tcpdump"
        "nmap:nmap"
        "curl:curl"
        "wget:wget"
        "nc:netcat"
        "iperf3:iperf3"
    )

    for tool_info in "${tools[@]}"; do
        IFS=':' read -r cmd pkg <<< "$tool_info"
        if command -v "$cmd" &> /dev/null; then
            version=$(timeout 2s $cmd --version 2>&1 | head -1 || echo "installé")
            check_pass "$cmd ($pkg) : $version"
        else
            check_fail "$cmd ($pkg) NON INSTALLÉ"
        fi
    done
}

################################################################################
# VÉRIFICATION 3 : MININET
################################################################################

check_mininet() {
    print_header "3. VÉRIFICATION DE MININET (CRITIQUE)"

    if command -v mn &> /dev/null; then
        version=$(mn --version 2>&1)
        check_pass "Mininet installé : $version"

        # Test de base Mininet
        check_info "Test de connectivité Mininet (peut prendre 30 secondes)..."
        if timeout 60s mn --test pingall &> /tmp/mn_test.log; then
            result=$(grep "Results:" /tmp/mn_test.log)
            check_pass "Test Mininet réussi : $result"
        else
            check_fail "Test Mininet échoué (voir /tmp/mn_test.log)"
        fi

        # Vérifier les modules OVS
        if command -v ovs-vsctl &> /dev/null; then
            check_pass "Open vSwitch installé"
        else
            check_warn "Open vSwitch non détecté (optionnel)"
        fi

    else
        check_fail "Mininet NON INSTALLÉ - CRITIQUE"
    fi
}

################################################################################
# VÉRIFICATION 4 : PARE-FEU
################################################################################

check_firewall() {
    print_header "4. VÉRIFICATION DU PARE-FEU"

    if command -v iptables &> /dev/null; then
        version=$(iptables --version)
        check_pass "iptables installé : $version"

        # Vérifier si on peut lister les règles
        if [ "$EUID" -eq 0 ]; then
            rule_count=$(iptables -L -n | wc -l)
            check_info "Nombre de lignes de règles : $rule_count"
        else
            check_warn "Exécuter avec sudo pour voir les règles iptables"
        fi
    else
        check_fail "iptables NON INSTALLÉ"
    fi

    # Vérifier ip_forward
    if [ -f /proc/sys/net/ipv4/ip_forward ]; then
        ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
        if [ "$ip_forward" -eq 1 ]; then
            check_pass "IP forwarding activé"
        else
            check_warn "IP forwarding désactivé (sera activé dans le script)"
        fi
    fi
}

################################################################################
# VÉRIFICATION 5 : SERVEUR WEB
################################################################################

check_web_server() {
    print_header "5. VÉRIFICATION DU SERVEUR WEB"

    if command -v apache2 &> /dev/null; then
        version=$(apache2 -v | head -1)
        check_pass "Apache installé : $version"
    else
        check_fail "Apache NON INSTALLÉ"
    fi

    if command -v openssl &> /dev/null; then
        version=$(openssl version)
        check_pass "OpenSSL installé : $version"
    else
        check_fail "OpenSSL NON INSTALLÉ"
    fi
}

################################################################################
# VÉRIFICATION 6 : VPN
################################################################################

check_vpn() {
    print_header "6. VÉRIFICATION D'OPENVPN"

    if command -v openvpn &> /dev/null; then
        version=$(openvpn --version | head -1)
        check_pass "OpenVPN installé : $version"

        # Vérifier easy-rsa
        if [ -d /usr/share/easy-rsa ]; then
            check_pass "Easy-RSA installé"
        else
            check_warn "Easy-RSA non trouvé dans /usr/share/easy-rsa"
        fi
    else
        check_fail "OpenVPN NON INSTALLÉ"
    fi
}

################################################################################
# VÉRIFICATION 7 : SSH
################################################################################

check_ssh() {
    print_header "7. VÉRIFICATION D'OPENSSH"

    if command -v ssh &> /dev/null; then
        version=$(ssh -V 2>&1)
        check_pass "SSH client installé : $version"
    else
        check_fail "SSH client NON INSTALLÉ"
    fi

    if command -v sshd &> /dev/null; then
        check_pass "SSH serveur installé"

        if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
            check_pass "SSH serveur actif"
        else
            check_warn "SSH serveur non actif (normal pour Mininet)"
        fi
    else
        check_fail "SSH serveur NON INSTALLÉ"
    fi
}

################################################################################
# VÉRIFICATION 8 : IDS (SNORT)
################################################################################

check_ids() {
    print_header "8. VÉRIFICATION DE SNORT (IDS)"

    if command -v snort &> /dev/null; then
        version=$(snort -V 2>&1 | head -1)
        check_pass "Snort installé : $version"

        # Vérifier les règles
        if [ -d /etc/snort/rules ]; then
            rule_files=$(ls /etc/snort/rules/*.rules 2>/dev/null | wc -l)
            check_info "Fichiers de règles trouvés : $rule_files"
        else
            check_warn "Répertoire de règles Snort non trouvé"
        fi
    else
        check_fail "Snort NON INSTALLÉ"
    fi
}

################################################################################
# VÉRIFICATION 9 : HAUTE DISPONIBILITÉ
################################################################################

check_ha() {
    print_header "9. VÉRIFICATION HAUTE DISPONIBILITÉ"

    if command -v keepalived &> /dev/null; then
        version=$(keepalived --version 2>&1 | head -1)
        check_pass "Keepalived installé : $version"
    else
        check_warn "Keepalived non installé (Heartbeat sera utilisé)"
    fi

    if command -v heartbeat &> /dev/null; then
        check_pass "Heartbeat installé"
    else
        check_warn "Heartbeat non installé"
    fi
}

################################################################################
# VÉRIFICATION 10 : PYTHON ET DÉPENDANCES
################################################################################

check_python() {
    print_header "10. VÉRIFICATION DE PYTHON"

    if command -v python3 &> /dev/null; then
        version=$(python3 --version)
        check_pass "Python3 installé : $version"

        # Vérifier pip
        if command -v pip3 &> /dev/null; then
            check_pass "pip3 installé"

            # Vérifier les modules Python importants
            modules=("scapy" "pytest" "requests" "paramiko")
            for module in "${modules[@]}"; do
                if python3 -c "import $module" 2>/dev/null; then
                    check_pass "Module Python '$module' installé"
                else
                    check_warn "Module Python '$module' NON installé"
                fi
            done
        else
            check_fail "pip3 NON INSTALLÉ"
        fi
    else
        check_fail "Python3 NON INSTALLÉ"
    fi
}

################################################################################
# VÉRIFICATION 11 : STRUCTURE DU PROJET
################################################################################

check_project_structure() {
    print_header "11. VÉRIFICATION DE LA STRUCTURE DU PROJET"

    PROJECT_DIR="$HOME/secured-network-infrastructure"

    if [ -d "$PROJECT_DIR" ]; then
        check_pass "Répertoire du projet existe : $PROJECT_DIR"

        # Vérifier les sous-répertoires
        subdirs=("mininet" "configs" "tests" "logs" "docs" "scripts" "evidence")
        for dir in "${subdirs[@]}"; do
            if [ -d "$PROJECT_DIR/$dir" ]; then
                check_pass "Répertoire '$dir' existe"
            else
                check_fail "Répertoire '$dir' MANQUANT"
            fi
        done

        # Vérifier les fichiers importants
        if [ -f "$PROJECT_DIR/README.md" ]; then
            check_pass "README.md existe"
        else
            check_warn "README.md manquant"
        fi

        if [ -f "$PROJECT_DIR/.gitignore" ]; then
            check_pass ".gitignore existe"
        else
            check_warn ".gitignore manquant"
        fi

        # Vérifier Git
        if [ -d "$PROJECT_DIR/.git" ]; then
            check_pass "Dépôt Git initialisé"
        else
            check_warn "Dépôt Git non initialisé"
        fi

    else
        check_fail "Répertoire du projet N'EXISTE PAS : $PROJECT_DIR"
    fi
}

################################################################################
# VÉRIFICATION 12 : RÉSEAU
################################################################################

check_network() {
    print_header "12. VÉRIFICATION DU RÉSEAU"

    # Lister les interfaces
    check_info "Interfaces réseau détectées :"
    ip -br addr show | while read line; do
        check_info "  $line"
    done

    # Test de connectivité Internet
    if ping -c 2 -W 3 8.8.8.8 &> /dev/null; then
        check_pass "Connectivité Internet (ping 8.8.8.8)"
    else
        check_fail "Pas de connectivité Internet"
    fi

    if ping -c 2 -W 3 google.com &> /dev/null; then
        check_pass "Résolution DNS fonctionnelle"
    else
        check_warn "Résolution DNS échouée"
    fi
}

################################################################################
# VÉRIFICATION 13 : PERMISSIONS
################################################################################

check_permissions() {
    print_header "13. VÉRIFICATION DES PERMISSIONS"

    # Vérifier les groupes de l'utilisateur
    current_user=${SUDO_USER:-$USER}
    user_groups=$(groups $current_user)

    check_info "Groupes de $current_user : $user_groups"

    if echo "$user_groups" | grep -q "sudo"; then
        check_pass "Utilisateur dans le groupe 'sudo'"
    else
        check_warn "Utilisateur PAS dans le groupe 'sudo'"
    fi

    if echo "$user_groups" | grep -q "wireshark"; then
        check_pass "Utilisateur dans le groupe 'wireshark'"
    else
        check_warn "Utilisateur PAS dans le groupe 'wireshark' (redémarrage nécessaire)"
    fi
}

################################################################################
# RÉSUMÉ FINAL
################################################################################

print_summary() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} RÉSUMÉ DE LA VÉRIFICATION${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo -e "${GREEN}✅ Tests réussis    : $PASS_COUNT${NC}"
    echo -e "${YELLOW}⚠️  Avertissements   : $WARN_COUNT${NC}"
    echo -e "${RED}❌ Tests échoués    : $FAIL_COUNT${NC}"
    echo ""

    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}🎉 PARFAIT ! Tous les tests sont passés !${NC}"
        echo -e "${GREEN}Vous pouvez commencer le projet.${NC}"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${YELLOW}✓ BIEN ! Installation OK avec quelques avertissements mineurs.${NC}"
        echo -e "${YELLOW}Vous pouvez commencer le projet.${NC}"
    else
        echo -e "${RED}⚠️  ATTENTION ! Certains composants critiques sont manquants.${NC}"
        echo -e "${RED}Réexécutez le script d'installation.${NC}"
    fi

    echo ""
    echo -e "${BLUE}PROCHAINES ÉTAPES :${NC}"
    echo "1. cd ~/secured-network-infrastructure"
    echo "2. sudo mn --test pingall  (test Mininet)"
    echo "3. Commencer le développement de la topologie"
    echo ""
}

################################################################################
# PROGRAMME PRINCIPAL
################################################################################

main() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
 _____ _               _
/  __ \ |             | |
| /  \/ |__   ___  ___| | __
| |   | '_ \ / _ \/ __| |/ /
| \__/\ | | |  __/ (__|   <
 \____/_| |_|\___|\___|_|\_\

Infrastructure Réseau Sécurisée
Vérification de l'installation
EOF
    echo -e "${NC}"

    check_system
    check_network_tools
    check_mininet
    check_firewall
    check_web_server
    check_vpn
    check_ssh
    check_ids
    check_ha
    check_python
    check_project_structure
    check_network
    check_permissions

    print_summary
}

# Exécution
main "$@"