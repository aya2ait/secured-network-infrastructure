#!/bin/bash
# Configuration Heartbeat - Haute Disponibilité Web

echo "=== Configuration Heartbeat sur $(hostname) ==="

HOSTNAME=$(hostname)
HA_DIR="/etc/ha.d"
CONFIG_DIR="/home/vboxuser/secured-network-infrastructure/configs/heartbeat"

# Créer les répertoires
mkdir -p $HA_DIR/resource.d

# Déterminer l'IP du partenaire
if [ "$HOSTNAME" = "web1" ]; then
    PARTNER_IP="172.16.1.11"
    THIS_IP="172.16.1.10"
elif [ "$HOSTNAME" = "web2" ]; then
    PARTNER_IP="172.16.1.10"
    THIS_IP="172.16.1.11"
else
    echo "✗ Hostname inconnu"
    exit 1
fi

# Configuration ha.cf
cat > $HA_DIR/ha.cf <<EOF
debugfile /var/log/ha-debug
logfile /var/log/ha-log
logfacility local0
keepalive 2
deadtime 10
warntime 5
initdead 30
udpport 694
ucast eth0 $PARTNER_IP
node web1
node web2
auto_failback on
EOF

# Ressources (haresources)
cat > $HA_DIR/haresources <<EOF
web1 IPaddr::172.16.1.100/24/eth0
EOF

# Clés d'authentification
cat > $HA_DIR/authkeys <<EOF
auth 2
2 sha1 SecureClusterKey2025LSI3
EOF

chmod 600 $HA_DIR/authkeys

echo "✓ Fichiers de configuration créés"

# Vérifier si heartbeat est installé
if ! command -v heartbeat &> /dev/null; then
    echo "⚠ Heartbeat non installé - Installation simulation"
    # Créer un script de simulation
    cat > /tmp/heartbeat_sim.sh <<'SIMEOF'
#!/bin/bash
# Simulation Heartbeat pour Mininet
while true; do
    echo "[$(date '+%H:%M:%S')] Heartbeat: nœud $(hostname) actif"
    sleep 5
done
SIMEOF
    chmod +x /tmp/heartbeat_sim.sh
    nohup /tmp/heartbeat_sim.sh > /var/log/ha-log 2>&1 &
    echo "✓ Simulation Heartbeat lancée"
    exit 0
fi

# Lancer Heartbeat
pkill -9 heartbeat 2>/dev/null
sleep 1

heartbeat -d 2>&1 | head -20 &

sleep 3

# Vérification
if pgrep heartbeat > /dev/null; then
    echo "✓ Heartbeat actif sur $HOSTNAME"
    echo "  - Partenaire: $PARTNER_IP"
    echo "  - VIP: 172.16.1.100"

    # Vérifier si on a la VIP
    if ip addr show | grep -q "172.16.1.100"; then
        echo "  - Statut: ACTIF (VIP présente)"
    else
        echo "  - Statut: PASSIF (en attente)"
    fi
else
    echo "✗ Heartbeat non démarré"
fi

echo "📁 Logs: /var/log/ha-log"