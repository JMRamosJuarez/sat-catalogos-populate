#!/bin/bash
set -e

run_pipeline() {
    mkdir -p /data/catalogs
    echo "Starting SAT catalogos database generation..."
    echo "Step 1/3: Dumping origins..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update dump-origins > /data/catalogs/origins.xml || true
    echo "Step 2/3: Updating origins..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update update-origins /data/catalogs
    echo "Step 3/3: Generating database..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update update-database /data/catalogs /data/catalogos.sqlite3
    echo "Database generation completed successfully!"
    echo "Database location: /data/catalogos.sqlite3"
    echo "Files in /data:"
    ls -lh /data/ || true
}

# Explicit request: run the full pipeline and exit (for Scheduled Tasks)
if [ "$1" = "generate" ]; then
    run_pipeline
    exit 0
fi

# Default behavior: run once per deploy, then keep container idle
INITIAL_FLAG="/data/.initial_run_done"
if [ ! -f "$INITIAL_FLAG" ]; then
    run_pipeline
    echo "$(date -Iseconds)" > "$INITIAL_FLAG"
    echo "Initial generation done. Preventing Coolify restarts by idling."
fi

# Stay alive to avoid restart loops (Coolify expects long-running containers)
tail -f /dev/null

