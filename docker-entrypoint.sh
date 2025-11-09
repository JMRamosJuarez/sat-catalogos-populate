#!/bin/bash
set -e

run_import() {
    local source_folder="${1:-/data/catalogs}"
    local database="${2:-/data/catalogos.sqlite3}"
    
    echo "Starting import of cfdi_40_productos_servicios..."
    php /opt/sat-catalogos-populate/bin/import-productos-servicios-only.php "$source_folder" "$database"
}

# Explicit request: run the import and exit (for Scheduled Tasks)
if [ "$1" = "generate" ] || [ "$1" = "import" ]; then
    run_import "${2:-/data/catalogs}" "${3:-/data/catalogos.sqlite3}"
    exit 0
fi

# Default behavior: run once per deploy, then keep container idle
DATABASE="/data/catalogos.sqlite3"
TABLE_NAME="cfdi_40_productos_servicios"
SOURCE_FOLDER="/data/catalogs"

# Check if database exists and table has data
if [ -f "$DATABASE" ]; then
    # Use sqlite3 to check if table exists and has records
    RECORD_COUNT=$(sqlite3 "$DATABASE" "SELECT COUNT(*) FROM $TABLE_NAME;" 2>/dev/null || echo "0")
    
    if [ "$RECORD_COUNT" -gt 0 ]; then
        echo "Database already exists with $RECORD_COUNT records in $TABLE_NAME. Skipping import."
        echo "Container will stay idle. Use 'generate' or 'import' command to re-run."
    else
        echo "Database exists but table is empty. Running import..."
        run_import "$SOURCE_FOLDER" "$DATABASE"
    fi
else
    echo "Database does not exist. Running initial import..."
    # First, we need to ensure the catalogs are downloaded
    if [ ! -f "$SOURCE_FOLDER/cfdi_40.xls" ]; then
        echo "Downloading catalogs first..."
        mkdir -p "$SOURCE_FOLDER"
        /opt/sat-catalogos-populate/bin/sat-catalogos-update dump-origins > "$SOURCE_FOLDER/origins.xml" || true
        /opt/sat-catalogos-populate/bin/sat-catalogos-update update-origins "$SOURCE_FOLDER"
    fi
    run_import "$SOURCE_FOLDER" "$DATABASE"
fi

echo "Container will stay idle to prevent Coolify restarts."
echo "To re-run import, use: docker exec <container> /usr/local/bin/docker-entrypoint.sh generate"

# Stay alive to avoid restart loops (Coolify expects long-running containers)
tail -f /dev/null
