#!/bin/bash
# Configuration HTTPS pour serveurs DMZ (Mininet-compatible)

echo "=== Configuration HTTPS sur $(hostname) ==="

HOSTNAME=$(hostname)

# Déterminer l'IP selon le hostname
if [ "$HOSTNAME" = "web1" ]; then
    IP="172.16.1.10"
elif [ "$HOSTNAME" = "web2" ]; then
    IP="172.16.1.11"
else
    IP=$(hostname -I | awk '{print $1}')
fi

# Créer les répertoires
mkdir -p /tmp/web /tmp/ssl

# Générer certificat SSL auto-signé
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/ssl/${HOSTNAME}.key \
  -out /tmp/ssl/${HOSTNAME}.crt \
  -subj "/C=MA/ST=Tangier/O=LSI3/CN=${IP}" 2>&1

echo "Certificats générés:"
ls -lh /tmp/ssl/

# Créer page web de test
cat > /tmp/web/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>${HOSTNAME}</title></head>
<body>
<h1>Serveur ${HOSTNAME} (${IP})</h1>
<p>HTTPS Actif - Infrastructure Zero Trust</p>
</body>
</html>
EOF

# Script Python pour serveur HTTPS
cat > /tmp/https_server_${HOSTNAME}.py <<PYEOF
import http.server
import ssl
import os
import sys

IP = '${IP}'
HOSTNAME = '${HOSTNAME}'

class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_HEAD(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
    
    def log_message(self, format, *args):
        sys.stderr.write(f"{format % args}\n")

try:
    os.chdir('/tmp/web')
    server_address = (IP, 443)
    httpd = http.server.HTTPServer(server_address, MyHandler)
    
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=f'/tmp/ssl/{HOSTNAME}.crt', 
                            keyfile=f'/tmp/ssl/{HOSTNAME}.key')
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    
    print(f'✓ Serveur HTTPS démarré sur https://{IP}:443', flush=True)
    httpd.serve_forever()
except Exception as e:
    print(f'✗ ERREUR HTTPS: {e}', flush=True)
    sys.exit(1)
PYEOF

# Script Python pour redirection HTTP
cat > /tmp/http_redirect_${HOSTNAME}.py <<PYEOF
from http.server import HTTPServer, BaseHTTPRequestHandler
import sys

IP = '${IP}'

class Redirect(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(301)
        self.send_header('Location', f'https://{IP}{self.path}')
        self.end_headers()
    
    def do_HEAD(self):
        self.send_response(301)
        self.send_header('Location', f'https://{IP}{self.path}')
        self.end_headers()
    
    def log_message(self, format, *args):
        sys.stderr.write(f"{format % args}\n")

try:
    print(f'✓ Redirection HTTP démarrée sur http://{IP}:80', flush=True)
    HTTPServer((IP, 80), Redirect).serve_forever()
except Exception as e:
    print(f'✗ ERREUR HTTP: {e}', flush=True)
    sys.exit(1)
PYEOF

# Arrêter les anciens processus
pkill -f "https_server_${HOSTNAME}.py" 2>/dev/null
pkill -f "http_redirect_${HOSTNAME}.py" 2>/dev/null
sleep 1

# Lancer les serveurs avec nohup
nohup python3 /tmp/https_server_${HOSTNAME}.py > /tmp/https_${HOSTNAME}.log 2>&1 &
HTTPS_PID=$!
sleep 2

nohup python3 /tmp/http_redirect_${HOSTNAME}.py > /tmp/http_${HOSTNAME}.log 2>&1 &
HTTP_PID=$!
sleep 2

# Vérifier les processus
echo "Processus lancés: HTTPS=$HTTPS_PID, HTTP=$HTTP_PID"

if ps -p $HTTPS_PID > /dev/null; then
    echo "✓ Processus HTTPS actif (PID: $HTTPS_PID)"
    cat /tmp/https_${HOSTNAME}.log
else
    echo "✗ Processus HTTPS mort"
    cat /tmp/https_${HOSTNAME}.log
fi

if ps -p $HTTP_PID > /dev/null; then
    echo "✓ Processus HTTP actif (PID: $HTTP_PID)"
    cat /tmp/http_${HOSTNAME}.log
else
    echo "✗ Processus HTTP mort"
    cat /tmp/http_${HOSTNAME}.log
fi

# Vérifier les ports
sleep 1
netstat -tlnp | grep "${IP}:"