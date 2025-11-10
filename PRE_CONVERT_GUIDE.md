# Lightweight XLS to CSV Conversion

The script now uses **ssconvert (Gnumeric)** as the primary converter, which uses much less memory than LibreOffice. It will automatically try the lightweight converter first, and only fall back to LibreOffice if needed.

## Automatic Lightweight Conversion

The import script now:
1. **First tries ssconvert (Gnumeric)** - Uses ~10x less memory than LibreOffice
2. **Falls back to LibreOffice** - Only if ssconvert fails
3. **Supports pre-converted CSV** - If you have a CSV file ready, it uses that directly

This should work on your 2GB RAM server without OOM errors!

---

## Pre-Converting XLS to CSV (Optional)

If you still want to pre-convert the file (for even faster imports), this guide shows how to do it on a machine with more resources.

## What is Pre-Converting?

Instead of converting `cfdi_40.xls` to CSV inside your server (which uses a lot of memory), you:
1. Convert it on your local machine (or a machine with more RAM)
2. Upload the CSV file to your server
3. The script will use the CSV directly, skipping the memory-intensive conversion

## Step 1: Convert XLS to CSV Locally

### Option A: Using Docker (Recommended)

If you have Docker installed locally:

```bash
# Build the image
docker build -t sat-catalogos-populate .

# Create a local directory
mkdir -p local-convert

# Download the XLS file first (if you don't have it)
# You can get it from the server or download it using the update-origins command
docker run -it --rm -v "$(pwd)/local-convert:/catalogs" sat-catalogos-populate \
  sh -c "sat-catalogos-update dump-origins > /catalogs/origins.xml && sat-catalogos-update update-origins /catalogs"

# Convert only the cfdi_40.xls file
docker run -it --rm -v "$(pwd)/local-convert:/catalogs" sat-catalogos-populate \
  sh -c "cd /catalogs && soffice --headless --convert-to xlsx --outdir /tmp cfdi_40.xls && xlsx2csv --all /tmp/cfdi_40.xlsx /catalogs/ && find /catalogs -name '*.csv' -exec mv {} /catalogs/c_ClaveProdServ.csv \;"

# Or use the existing converter
docker run -it --rm -v "$(pwd)/local-convert:/catalogs" sat-catalogos-populate \
  php -r "
    require '/opt/sat-catalogos-populate/vendor/autoload.php';
    \$converter = new PhpCfdi\SatCatalogosPopulate\Converters\XlsToCsvFolderConverter();
    \$converter->convert('/catalogs/cfdi_40.xls', '/catalogs/csv-output');
    exec('find /catalogs/csv-output -name \"c_ClaveProdServ.csv\" -exec mv {} /catalogs/c_ClaveProdServ.csv \;');
  "
```

### Option B: Using LibreOffice Locally

If you have LibreOffice installed locally:

```bash
# Convert XLS to XLSX first
libreoffice --headless --convert-to xlsx --outdir /tmp cfdi_40.xls

# Then convert XLSX to CSV (if you have xlsx2csv)
xlsx2csv --all /tmp/cfdi_40.xlsx output_folder/
# Find the c_ClaveProdServ.csv file and copy it
```

### Option C: Using Python (Lightweight)

If you have Python with pandas:

```python
import pandas as pd

# Read the XLS file
df = pd.read_excel('cfdi_40.xls', sheet_name='c_ClaveProdServ')

# Save as CSV
df.to_csv('c_ClaveProdServ.csv', index=False, encoding='utf-8')
```

## Step 2: Upload CSV to Server

Once you have the `c_ClaveProdServ.csv` file, you need to place it in your Coolify volume.

### Option A: Via Coolify Terminal

1. Go to your app in Coolify
2. Open the "Terminal" tab
3. Upload the file:

```bash
# Create the catalogs directory if it doesn't exist
mkdir -p /data/catalogs

# You'll need to copy the file content or use a different method
# Since terminal doesn't support direct file upload, use Option B or C
```

### Option B: Via Docker Exec (if you have access)

```bash
# Copy the CSV file to the volume
docker cp c_ClaveProdServ.csv <container-name>:/data/catalogs/c_ClaveProdServ.csv
```

### Option C: Via SCP/SFTP (if your server allows)

```bash
# If you have SSH access to the server
scp c_ClaveProdServ.csv user@server:/path/to/volume/catalogs/
```

### Option D: Add to Git and Mount (if volume is accessible)

If your volume is accessible from the host, you could:
1. Add the CSV to a git repository
2. Clone it in the container
3. Copy to the volume

## Step 3: Verify the Script Will Use It

The script automatically detects if `/data/catalogs/c_ClaveProdServ.csv` exists and will use it instead of converting.

When you deploy, you should see in the logs:
```
Found pre-converted CSV file. Using it directly (skipping XLS conversion).
```

Instead of:
```
XLS file found. Will convert to CSV (this may require significant memory)...
```

## Quick Test Script

Here's a simple script to convert on your local machine:

```bash
#!/bin/bash
# convert-cfdi40.sh

# Download the XLS file first (if needed)
mkdir -p convert-temp
cd convert-temp

# If you have the XLS file, place it here as cfdi_40.xls
# Then run:
docker run -it --rm \
  -v "$(pwd):/work" \
  sat-catalogos-populate \
  sh -c "cd /work && soffice --headless --convert-to xlsx cfdi_40.xls && xlsx2csv --all cfdi_40.xlsx . && find . -name 'c_ClaveProdServ.csv' -exec cp {} ../c_ClaveProdServ.csv \;"

echo "Conversion complete! File: c_ClaveProdServ.csv"
```

## Important Notes

- The CSV file must be named exactly: `c_ClaveProdServ.csv`
- It must be placed in: `/data/catalogs/c_ClaveProdServ.csv` (inside your volume)
- The CSV format must match what LibreOffice would produce (the script validates headers)
- Once the CSV is in place, the script will skip XLS conversion entirely

## Benefits

✅ **No memory issues** - No LibreOffice conversion needed  
✅ **Faster import** - Skips conversion step  
✅ **More reliable** - No OOM errors  
✅ **Works on low-RAM servers** - Only needs memory for CSV parsing

