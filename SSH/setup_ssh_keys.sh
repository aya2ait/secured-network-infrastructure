#!/bin/bash
# Script de génération des clés SSH pour l'administrateur
# Infrastructure Zero Trust - LSI3

echo "=== Génération des clés SSH administrateur ==="

# Créer le répertoire SSH si nécessaire
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Générer une paire de clés ED25519 (plus sécurisée et rapide)
if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "admin@zerotrust-infrastructure"
    echo "✓ Clé ED25519 générée"
else
    echo "ℹ Clé ED25519 existante détectée"
fi

# Alternative RSA 4096 bits (pour compatibilité)
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -C "admin@zerotrust-infrastructure-rsa"
    echo "✓ Clé RSA 4096 générée"
else
    echo "ℹ Clé RSA existante détectée"
fi

# Permissions strictes
chmod 600 /root/.ssh/id_*
chmod 644 /root/.ssh/id_*.pub

echo ""
echo "=== Clés SSH générées avec succès ==="
echo ""
echo "Clé publique ED25519 :"
cat /root/.ssh/id_ed25519.pub
echo ""
echo "Clé publique RSA :"
cat /root/.ssh/id_rsa.pub
echo ""