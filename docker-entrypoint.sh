#!/bin/bash
set -e

run_import() {
    local source_folder="${1:-/data/catalogs}"
    local database="${2:-/data/catalogos.sqlite3}"
    
    echo "Starting import of cfdi_40_productos_servicios..."
    if php /opt/sat-catalogos-populate/bin/import-productos-servicios-only.php "$source_folder" "$database"; then
        return 0
    else
        return 1
    fi
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
FAILURE_FILE="/data/.import_failed"

# Check for recent failure (prevent retries after OOM)
if [ -f "$FAILURE_FILE" ]; then
    # Get file modification time (portable)
    if command -v stat >/dev/null 2>&1; then
        if stat -c %Y "$FAILURE_FILE" >/dev/null 2>&1; then
            FAILURE_TIME=$(stat -c %Y "$FAILURE_FILE")
        elif stat -f %m "$FAILURE_FILE" >/dev/null 2>&1; then
            FAILURE_TIME=$(stat -f %m "$FAILURE_FILE")
        else
            FAILURE_TIME=$(date -r "$FAILURE_FILE" +%s 2>/dev/null || echo 0)
        fi
    else
        FAILURE_TIME=$(date -r "$FAILURE_FILE" +%s 2>/dev/null || echo 0)
    fi
    FAILURE_AGE=$(($(date +%s) - FAILURE_TIME))
    if [ "$FAILURE_AGE" -lt 3600 ]; then
        echo "Recent import failure detected (less than 1 hour ago)."
        echo "This was likely due to out-of-memory (OOM) during LibreOffice conversion."
        echo "Skipping import to prevent server crash. Container will stay idle."
        echo "To force retry, delete: $FAILURE_FILE"
        echo "Or wait at least 1 hour for automatic retry."
    else
        echo "Old failure file found. Removing it and allowing retry."
        rm -f "$FAILURE_FILE"
    fi
fi

# Check if database exists and table has data
if [ -f "$DATABASE" ]; then
    # Use sqlite3 to check if table exists and has records
    RECORD_COUNT=$(sqlite3 "$DATABASE" "SELECT COUNT(*) FROM $TABLE_NAME;" 2>/dev/null || echo "0")
    
    if [ "$RECORD_COUNT" -gt 0 ]; then
        echo "Database already exists with $RECORD_COUNT records in $TABLE_NAME. Skipping import."
        echo "Container will stay idle. Use 'generate' or 'import' command to re-run."
    elif [ -f "$FAILURE_FILE" ]; then
        # Check failure age again
        if command -v stat >/dev/null 2>&1; then
            if stat -c %Y "$FAILURE_FILE" >/dev/null 2>&1; then
                FAILURE_TIME=$(stat -c %Y "$FAILURE_FILE")
            elif stat -f %m "$FAILURE_FILE" >/dev/null 2>&1; then
                FAILURE_TIME=$(stat -f %m "$FAILURE_FILE")
            else
                FAILURE_TIME=$(date -r "$FAILURE_FILE" +%s 2>/dev/null || echo 0)
            fi
        else
            FAILURE_TIME=$(date -r "$FAILURE_FILE" +%s 2>/dev/null || echo 0)
        fi
        FAILURE_AGE=$(($(date +%s) - FAILURE_TIME))
        if [ "$FAILURE_AGE" -lt 3600 ]; then
            echo "Database exists but table is empty. However, recent failure detected - skipping import."
        else
            echo "Database exists but table is empty. Running import..."
            if run_import "$SOURCE_FOLDER" "$DATABASE"; then
                echo "Import completed successfully!"
            else
                echo "Import failed. Check logs above for details."
                echo "If it was an OOM error, the failure file was created to prevent immediate retry."
            fi
        fi
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
    if run_import "$SOURCE_FOLDER" "$DATABASE"; then
        echo "Import completed successfully!"
    else
        echo "Import failed. Check logs above for details."
    fi
fi

echo "Container will stay idle to prevent Coolify restarts."
echo "To re-run import, use: docker exec <container> /usr/local/bin/docker-entrypoint.sh generate"

# Stay alive to avoid restart loops (Coolify expects long-running containers)
tail -f /dev/null
