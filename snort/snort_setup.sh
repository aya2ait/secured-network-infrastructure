#!/bin/bash
# Configuration Snort IDS - Version Corrigée

echo "=== Configuration Snort IDS ==="

INTERFACE=${1:-fwwan}
LOG_DIR="/var/log/snort"
RULES_FILE="/etc/snort/rules/local.rules"
CONF_FILE="/etc/snort/snort.conf"

# Créer les répertoires avec bonnes permissions
mkdir -p $LOG_DIR /etc/snort/rules
chmod 777 $LOG_DIR

# Créer les règles
cat > $RULES_FILE <<'EOF'
alert tcp any any -> any any (flags:S; msg:"[SCAN] SYN scan detected"; sid:1000001; rev:1;)
alert tcp any any -> any any (flags:0; msg:"[SCAN] NULL scan detected"; sid:1000002; rev:1;)
alert tcp any any -> any any (flags:FPU; msg:"[SCAN] XMAS scan detected"; sid:1000003; rev:1;)
alert tcp any any -> any 2222 (msg:"[SSH] Connection attempt to Admin"; sid:1000010; rev:1;)
alert tcp any any -> any 2222 (msg:"[SSH] Multiple attempts"; threshold:type threshold, track by_src, count 5, seconds 60; sid:1000011; rev:1;)
alert tcp any any -> any [80,443] (content:"union"; nocase; content:"select"; nocase; msg:"[WEB] SQL Injection detected"; sid:1000020; rev:1;)
alert tcp any any -> any [80,443] (content:"or 1=1"; nocase; msg:"[WEB] SQL Injection OR 1=1"; sid:1000021; rev:1;)
alert tcp any any -> any [80,443] (content:"../"; msg:"[WEB] Path traversal attempt"; sid:1000022; rev:1;)
alert tcp any any -> any [80,443] (content:"<script>"; nocase; msg:"[WEB] XSS attempt"; sid:1000023; rev:1;)
alert ip any any -> 192.168.10.0/24 any (msg:"[POLICY] Unauthorized LAN access"; sid:1000030; rev:1;)
alert ip 172.16.1.0/24 any -> 192.168.10.0/24 any (msg:"[POLICY] DMZ to LAN blocked"; sid:1000031; rev:1;)
alert ip 203.0.113.0/24 any -> 192.168.100.0/24 any (msg:"[POLICY] WAN to ADMIN blocked"; sid:1000032; rev:1;)
EOF

echo "✓ Règles créées: $RULES_FILE"

# Configuration Snort
cat > $CONF_FILE <<EOF
# Snort Configuration - Infrastructure Zero Trust
var HOME_NET [192.168.10.0/24,192.168.100.0/24,172.16.1.0/24,10.8.0.0/24]
var EXTERNAL_NET any

var RULE_PATH /etc/snort/rules
var LOG_PATH $LOG_DIR

# Preprocessing (minimal)
preprocessor frag3_global: max_frags 65536
preprocessor frag3_engine: policy first detect_anomalies

preprocessor stream5_global: track_tcp yes
preprocessor stream5_tcp: policy first

# Output - Mode ALERT FAST
output alert_fast: $LOG_PATH/alert

# Règles
include \$RULE_PATH/local.rules
EOF

echo "✓ Configuration créée: $CONF_FILE"

# Arrêter les instances précédentes
pkill -9 snort 2>/dev/null
sleep 1

# Tester la configuration
echo "Test de la configuration..."
snort -T -c $CONF_FILE -i $INTERFACE 2>&1 | tail -5

# Lancer Snort en mode démon
snort -D -c $CONF_FILE -i $INTERFACE -l $LOG_DIR -A fast 2>&1

sleep 3

# Vérification
if pgrep snort > /dev/null; then
    echo ""
    echo "✓ Snort IDS actif sur $INTERFACE"
    echo "📁 Fichier d'alertes: $LOG_DIR/alert"

    # Créer un lien symbolique pour faciliter l'accès
    ln -sf $LOG_DIR/alert /tmp/snort_alert.txt
    echo "📁 Lien rapide: /tmp/snort_alert.txt"
else
    echo "✗ Erreur: Snort n'a pas démarré"
    echo "Dernières lignes du log:"
    tail -10 /var/log/snort/alert 2>/dev/null || echo "Aucun log"