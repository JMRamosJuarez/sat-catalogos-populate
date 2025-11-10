# Local Testing Guide

This guide explains how to test the `import-productos-servicios-only.php` script locally.

## Prerequisites

1. **PHP 8.2+** installed
2. **Composer** installed
3. **External dependencies** (for XLS conversion):
   - On Linux/Debian: `libreoffice-calc xlsx2csv`
   - On macOS: `brew install libreoffice` (or use Docker)
   - On Windows: Install LibreOffice

## Step 1: Install Dependencies

```bash
# Install PHP dependencies
composer install

# Install system dependencies (Linux/Debian)
sudo apt-get install libreoffice-calc xlsx2csv

# Or on macOS
brew install libreoffice
```

## Step 2: Download Source Files

You need to download the `cfdi_40.xls` file first. Create a test directory and download the catalogs:

```bash
# Create a test directory
mkdir -p test-catalogs

# Generate the origins.xml file
php bin/sat-catalogos-update dump-origins > test-catalogs/origins.xml

# Download the actual catalog files (this will download cfdi_40.xls and others)
php bin/sat-catalogos-update update-origins test-catalogs/
```

This will download all the catalog files including `cfdi_40.xls` to the `test-catalogs/` directory.

## Step 3: Run the Import Script

Now you can test the import script:

```bash
# Run the import script
php bin/import-productos-servicios-only.php test-catalogs/ test-catalogs/catalogos.sqlite3
```

**Parameters:**
- First argument: Source folder (where `cfdi_40.xls` is located)
- Second argument: Database path (where SQLite database will be created)

## Step 4: Verify the Import

Check if the table was created and has data:

```bash
# Using sqlite3 command line
sqlite3 test-catalogs/catalogos.sqlite3 "SELECT COUNT(*) FROM cfdi_40_productos_servicios;"

# Or view a few records
sqlite3 test-catalogs/catalogos.sqlite3 "SELECT * FROM cfdi_40_productos_servicios LIMIT 5;"
```

## Step 5: Test Re-run Prevention

Test that the script skips import if data already exists:

```bash
# Run again - it should skip the import
php bin/import-productos-servicios-only.php test-catalogs/ test-catalogs/catalogos.sqlite3
```

You should see: `"Table cfdi_40_productos_servicios already exists with X records. Skipping import."`

## Alternative: Using Docker (No Local Dependencies)

If you don't want to install LibreOffice locally, you can use Docker:

```bash
# Build the Docker image
docker build -t sat-catalogos-populate .

# Create a local directory for catalogs
mkdir -p local-catalogs

# Download catalogs using Docker
docker run -it --rm \
  -v "$(pwd)/local-catalogs:/catalogs" \
  sat-catalogos-populate \
  sh -c "sat-catalogos-update dump-origins > /catalogs/origins.xml && sat-catalogos-update update-origins /catalogs"

# Run the import script using Docker
docker run -it --rm \
  -v "$(pwd)/local-catalogs:/data/catalogs" \
  -v "$(pwd)/local-catalogs:/data" \
  sat-catalogos-populate \
  php /opt/sat-catalogos-populate/bin/import-productos-servicios-only.php /data/catalogs /data/catalogos.sqlite3
```

## Troubleshooting

### Error: "Source file not found"
Make sure `cfdi_40.xls` exists in the source folder:
```bash
ls -lh test-catalogs/cfdi_40.xls
```

### Error: LibreOffice not found
Install LibreOffice or use Docker method above.

### Error: Permission denied
Make sure the script is executable:
```bash
chmod +x bin/import-productos-servicios-only.php
```

### Test with a smaller dataset
If you want to test with a smaller dataset, you can manually create a test XLS file, but the easiest way is to use the real downloaded file.

