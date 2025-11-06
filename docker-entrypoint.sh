#!/bin/bash
set -e

# If first argument is "generate", run the full pipeline
if [ "$1" = "generate" ]; then
    # Create catalogs directory if it doesn't exist
    mkdir -p /data/catalogs

    # Run the full pipeline to generate the database
    echo "Starting SAT catalogos database generation..."

    # Step 1: Dump origins
    echo "Step 1/3: Dumping origins..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update dump-origins > /data/catalogs/origins.xml || true

    # Step 2: Update origins
    echo "Step 2/3: Updating origins..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update update-origins /data/catalogs

    # Step 3: Update database
    echo "Step 3/3: Generating database..."
    /opt/sat-catalogos-populate/bin/sat-catalogos-update update-database /data/catalogs /data/catalogos.sqlite3

    echo "Database generation completed successfully!"
    echo "Database location: /data/catalogos.sqlite3"

    # List files in /data for verification
    echo "Files in /data:"
    ls -lh /data/ || true

    exit 0
fi

# If first argument is not "generate", pass all arguments to the original entrypoint
# This allows using the container normally: docker run image dump-origins, etc.
exec /opt/sat-catalogos-populate/bin/sat-catalogos-update "$@"

