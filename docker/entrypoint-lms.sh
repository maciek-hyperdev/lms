#!/bin/bash
set -e

LMS_DIR=/var/www/lms
LMS_INI=/etc/lms/lms.ini

# Create LMS config
mkdir -p /etc/lms
cat > "$LMS_INI" <<EOINI
[database]
type     = ${LMS_DB_TYPE:-postgres}
host     = ${LMS_DB_HOST:-db}
user     = ${LMS_DB_USER:-lms}
password = ${LMS_DB_PASS:-lmspassword}
database = ${LMS_DB_NAME:-lms}

[directories]
sys_dir            = ${LMS_DIR}
storage_dir        = ${LMS_DIR}/storage
smarty_compile_dir = ${LMS_DIR}/templates_c

[phpui]
lang               = pl
timeout            = 600
force_ssl          = false
allow_mac_sharing  = true
EOINI

# Ensure writable dirs
mkdir -p "$LMS_DIR/templates_c" "$LMS_DIR/backups" "$LMS_DIR/documents" "$LMS_DIR/storage" "$LMS_DIR/js/xajax_js/deferred"
chown -R www-data:www-data "$LMS_DIR/templates_c" "$LMS_DIR/backups" "$LMS_DIR/documents" "$LMS_DIR/storage" "$LMS_DIR/js/xajax_js/deferred"

# Install Composer dependencies if needed
if [ ! -f "$LMS_DIR/vendor/autoload.php" ]; then
    echo "Installing Composer dependencies..."
    cd "$LMS_DIR"
    composer install --no-dev --no-interaction --prefer-dist 2>&1 || {
        echo "WARNING: Composer install had issues, trying with --ignore-platform-reqs"
        composer install --no-dev --no-interaction --prefer-dist --ignore-platform-reqs 2>&1
    }
fi

# Wait for DB and run schema upgrade
echo "Waiting for database..."
for i in $(seq 1 30); do
    if php -r "
        \$c = @pg_connect('host=${LMS_DB_HOST} dbname=${LMS_DB_NAME} user=${LMS_DB_USER} password=${LMS_DB_PASS}');
        exit(\$c ? 0 : 1);
    " 2>/dev/null; then
        echo "Database is ready."
        break
    fi
    echo "  waiting... ($i/30)"
    sleep 2
done

echo "LMS is starting at http://localhost:8080"
echo "Default login: admin / admin (set during first-run install wizard)"

exec "$@"
