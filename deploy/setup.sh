#!/bin/bash
# Hectic Server Setup Script
# Sets up a fresh server with Caddy, PostgreSQL client tooling, and Hectic

set -euo pipefail

echo "=== Hectic Server Setup ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./setup.sh)"
    exit 1
fi

# Resolve repository paths (script is executed from cloned repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Create hectic user with proper home dir and shell for SSH access
echo "Creating hectic user..."
if ! id hectic &>/dev/null; then
    useradd --system --home-dir /opt/hectic --shell /bin/bash hectic
fi

# Create directories
echo "Creating directories..."
mkdir -p /opt/hectic/{data,migrations,deploy,.ssh}
chmod 700 /opt/hectic/.ssh
chown -R hectic:hectic /opt/hectic

# Install Caddy
echo "Installing Caddy..."
if ! command -v caddy &>/dev/null; then
    apt-get update
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install -y caddy
fi

# Install Prometheus
echo "Installing Prometheus..."
if ! command -v prometheus &>/dev/null; then
    apt-get install -y prometheus
fi

# Configure Prometheus to listen on localhost only
echo "Configuring Prometheus..."
mkdir -p /etc/prometheus
if [ -f "${REPO_ROOT}/infrastructure/prometheus/prometheus.yml" ]; then
    cp "${REPO_ROOT}/infrastructure/prometheus/prometheus.yml" /etc/prometheus/
fi
mkdir -p /etc/default
if ! grep -q "web.listen-address=127.0.0.1:9090" /etc/default/prometheus 2>/dev/null; then
    echo 'ARGS="--web.listen-address=127.0.0.1:9090"' >> /etc/default/prometheus
fi

# Install Grafana
echo "Installing Grafana..."
if ! command -v grafana-server &>/dev/null; then
    apt-get install -y apt-transport-https software-properties-common
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update
    apt-get install -y grafana
fi

# Configure Grafana
echo "Configuring Grafana..."
# Bind to localhost only
sed -i 's/^;http_addr =.*/http_addr = 127.0.0.1/' /etc/grafana/grafana.ini
sed -i 's/^http_addr =.*/http_addr = 127.0.0.1/' /etc/grafana/grafana.ini

# Enable anonymous access for dashboard embedding
sed -i '/^\[auth.anonymous\]$/a enabled = true\norg_name = Main Org.\norg_role = Viewer' /etc/grafana/grafana.ini 2>/dev/null || true
# Allow iframe embedding
sed -i '/^\[security\]$/a allow_embedding = true' /etc/grafana/grafana.ini 2>/dev/null || true

# Setup Grafana provisioning
mkdir -p /var/lib/grafana/dashboards
if [ -d "${REPO_ROOT}/infrastructure/grafana/dashboards" ]; then
    cp "${REPO_ROOT}/infrastructure/grafana/dashboards/"*.json /var/lib/grafana/dashboards/
    chown -R grafana:grafana /var/lib/grafana/dashboards
fi
if [ -d "${REPO_ROOT}/infrastructure/grafana/provisioning" ]; then
    cp -r "${REPO_ROOT}/infrastructure/grafana/provisioning/"* /etc/grafana/provisioning/
fi

# Caddyfile is managed by demandops-shared-infra (shared host) — do not install here.

# Install blue-green service files (not the old single hectic.service)
echo "Installing blue-green service files..."
if [ -f "${SCRIPT_DIR}/hectic-blue.service" ]; then
    cp "${SCRIPT_DIR}/hectic-blue.service" /etc/systemd/system/
fi
if [ -f "${SCRIPT_DIR}/hectic-green.service" ]; then
    cp "${SCRIPT_DIR}/hectic-green.service" /etc/systemd/system/
fi
if [ -f "${SCRIPT_DIR}/prometheus.service" ]; then
    cp "${SCRIPT_DIR}/prometheus.service" /etc/systemd/system/
fi

# Initialize active slot marker (blue-green deployment starts with blue)
echo "blue" > /opt/hectic/.active-slot
chown hectic:hectic /opt/hectic/.active-slot

# Install sudoers configuration for hectic user
# Allows passwordless sudo for service management and log access (CI/CD automation)
echo "Installing sudoers configuration..."
if [ -f "${SCRIPT_DIR}/hectic-sudoers" ]; then
    cp "${SCRIPT_DIR}/hectic-sudoers" /etc/sudoers.d/hectic
    chmod 440 /etc/sudoers.d/hectic
    # Validate sudoers syntax
    visudo -c -f /etc/sudoers.d/hectic || {
        echo "ERROR: Invalid sudoers syntax"
        rm /etc/sudoers.d/hectic
        exit 1
    }
fi

# Configure firewall
echo "Configuring firewall..."
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

# Install PostgreSQL client tooling for connectivity verification and operator use
echo "Installing PostgreSQL client..."
apt-get install -y postgresql-client

# Install and configure fail2ban
echo "Installing fail2ban..."
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 30d
findtime = 10m
maxretry = 5
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 30d

[hectic-web]
enabled = true
port = http,https
filter = hectic-web
backend = systemd
journalmatch = _SYSTEMD_UNIT=hectic-blue.service + _SYSTEMD_UNIT=hectic-green.service
maxretry = 5
findtime = 10m
bantime = 30d

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
banaction = ufw
bantime = -1
findtime = 30d
maxretry = 2
EOF

# Create filter for web exploit scanners
cat > /etc/fail2ban/filter.d/hectic-web.conf << 'EOF'
[Definition]
# Match 404s from suspicious paths in hectic JSON logs
# WordPress and CMS probes
failregex = \"path\":\s*\"[^\"]*/(wp-admin|wp-login|wp-config|wp-content|wp-includes|xmlrpc)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Database admin tools
            \"path\":\s*\"[^\"]*/(phpmyadmin|pma|adminer|mysql|myadmin|dbadmin|sqladmin|phpMyAdmin)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Environment and config files
            \"path\":\s*\"[^\"]*/(\.env|\.git|\.svn|\.htaccess|\.htpasswd|config\.php|configuration\.php|settings\.php|credentials|secrets|database\.yml)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Backup and dump files
            \"path\":\s*\"[^\"]*/(backup|dump|export|database)\.(sql|zip|tar|gz|bak)\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
            \"path\":\s*\"[^\"]*\.(sql|bak|old|backup|orig|save|swp|tmp)\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Admin paths
            \"path\":\s*\"/(admin|administrator|manager|console|cpanel|webadmin|siteadmin|backend)(/|$)\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Server-side scripts (non-Go)
            \"path\":\s*\"[^\"]*\.(php|asp|aspx|jsp|cgi|pl|py|rb|sh)\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# CGI and shell exploits
            \"path\":\s*\"[^\"]*/(cgi-bin|cgi|shell|cmd|exec|eval|system)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Vendor and dependency paths
            \"path\":\s*\"[^\"]*/(vendor|node_modules|bower_components|composer\.(json|lock)|package\.json|Gemfile)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Common scanner paths
            \"path\":\s*\"[^\"]*/(test|debug|setup|install|upgrade|update|temp|tmp|log|logs|cache)[^\"]*\.(php|asp|aspx)\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
# Remote file inclusion attempts
            \"path\":\s*\"[^\"]*\?(.*=https?://|.*=//)[^\"]*\".*\"status\":\s*404.*\"ip\":\s*\"<HOST>\"
ignoreregex =
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Configure journald log limits
echo "Configuring journald size limits..."
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/size.conf << 'EOF'
[Journal]
SystemMaxUse=200M
MaxRetentionSec=7d
EOF
systemctl restart systemd-journald

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Enable services (blue-green: start with blue slot)
echo "Enabling services..."
systemctl enable caddy
systemctl enable hectic-blue  # Blue-green: start with blue slot
systemctl enable prometheus
systemctl enable grafana-server

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy your Hectic server binary to /opt/hectic/hectic-blue"
echo "2. Copy migrations to /opt/hectic/migrations/"
echo "3. Create /opt/hectic/.env with your configuration:"
echo "   # NOTE: Do NOT set PORT in .env - each slot controls its own port"
echo "   DATABASE_DSN=postgres://hectic:<password>@postgres.example.com:5432/hectic?sslmode=require"
echo "   JWT_SECRET=your-secure-secret"
echo "   COOKIE_DOMAIN=.hectic.example.com  # Required for cross-subdomain auth"
echo "   AWS_ACCESS_KEY_ID=your-access-key"
echo "   AWS_SECRET_ACCESS_KEY=your-secret-key"
echo "   AWS_REGION=us-east-1"
echo ""
echo "4. Set up SSH for hectic user (for GitHub Actions deployment):"
echo "   echo 'ssh-ed25519 AAAA... deploy@github' >> /opt/hectic/.ssh/authorized_keys"
echo "   chmod 600 /opt/hectic/.ssh/authorized_keys"
echo "   chown hectic:hectic /opt/hectic/.ssh/authorized_keys"
echo ""
echo "5. Start services:"
echo "   systemctl start prometheus"
echo "   systemctl start grafana-server"
echo "   systemctl start hectic-blue  # Blue-green deployment starts with blue"
echo "   systemctl reload caddy"
echo ""
echo "6. Check status:"
echo "   systemctl status hectic-blue caddy prometheus grafana-server"
echo ""
echo "7. Verify monitoring (should NOT be accessible externally):"
echo "   curl http://127.0.0.1:9090/-/healthy  # Prometheus"
echo "   curl http://127.0.0.1:3000/api/health  # Grafana"
echo ""
