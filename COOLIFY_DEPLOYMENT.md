# Coolify Deployment Guide

This guide explains how to deploy this PHP CLI tool to Coolify and configure it properly.

## Overview

This is a **CLI tool** that generates a SQLite database - it's **NOT a web service**. It runs, creates/updates the database, and exits.

## Configuration Steps

### 1. General Settings

**Current issues I noticed:**
- ❌ Domain configured (not needed for a CLI tool)
- ❌ Ports exposed (3000) - not needed
- ❌ Traefik/Caddy labels - configured for web service
- ❌ Pre/Post deployment: `php artisan migrate` - wrong commands

**What to change:**

#### Option A: Run as a Scheduled Task (Recommended)
Since this is a CLI tool that should run periodically:
1. **Remove or disable the domain** - this app doesn't serve HTTP requests
2. **Remove port mappings** - set to empty or remove
3. **Remove web service labels** - or use "Reset Labels to Defaults"
4. **Keep these settings:**
   - ✅ Build Pack: `Dockerfile`
   - ✅ Dockerfile Location: `/Dockerfile`
   - ✅ Custom Docker Options: Keep as is (needed for LibreOffice)

#### Option B: Run as a One-Time Job
If you want it to run once on deployment:
- Same as Option A, but you'll override the start command (see below)

### 2. Persistent Storage Configuration

**Choose: Volume Mount** ✅

**Why Volume Mount?**
- ✅ Creates a Docker named volume that persists across container restarts
- ✅ Can be shared between multiple containers (your generator app + future API app)
- ✅ Portable and managed by Docker/Coolify
- ✅ Better for SQLite databases that need to be accessed by multiple apps

**Configuration:**
- **Source**: `sat-catalogos-data` (or any name you prefer)
- **Destination**: `/data` (this is where we'll store the database and catalogs)

**Why NOT the others?**
- ❌ **File Mount**: Only for single files, less flexible
- ❌ **Directory Mount**: Host-specific paths, less portable

### 3. Start Command Override

**Good news!** The Dockerfile has been updated to automatically run the full pipeline when the container starts. The default `CMD` is set to `generate`, which will:

1. Create `/data/catalogs` directory
2. Dump origins to XML
3. Update origins from the catalog folder
4. Generate/update the SQLite database at `/data/catalogos.sqlite3`

**No configuration needed in Coolify!** Just deploy and the container will automatically generate the database.

**If you need to override the command** (for example, in Scheduled Tasks):
- You can still pass commands directly: `dump-origins`, `update-origins <folder>`, `update-database <folder> <db>`
- Or use `generate` to run the full pipeline

### 4. Pre/Post Deployment Commands

**Remove or clear:**
- Pre-deployment: Remove `php artisan migrate` (not applicable)
- Post-deployment: Remove `php artisan migrate` (not applicable)

Or leave them empty if Coolify requires a value.

### 5. Scheduled Tasks (For Daily Updates)

Once configured, go to **"Scheduled Tasks"** section and create a cron job:

**Schedule:** `0 2 * * *` (runs daily at 2 AM)

**Command:** Since the default CMD is `generate`, you can either:
- Leave it empty (will use default `generate`)
- Or explicitly set: `generate`
- Or run just the update: `/opt/sat-catalogos-populate/bin/sat-catalogos-update update-database /data/catalogs /data/catalogos.sqlite3`

This will regenerate the database daily.

## SQLite Database Location

After deployment, your SQLite database will be at:
- **Container path**: `/data/catalogos.sqlite3`
- **Volume name**: `sat-catalogos-data` (the Docker volume)

## Connection Settings for Your Future API

When you create your API app in Coolify:

**1. Mount the same volume:**
- Source: `sat-catalogos-data` (same volume name)
- Destination: `/data` (or wherever you prefer)

**2. Connect to SQLite in PHP:**
```php
$pdo = new PDO('sqlite:////data/catalogos.sqlite3', '', '', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);
```

**Important:** The DSN uses **4 slashes** (`sqlite:////`) for absolute paths.

## Summary Checklist

- [ ] Build Pack: `Dockerfile` ✅
- [ ] Dockerfile Location: `/Dockerfile` ✅
- [ ] Remove/disable domain (or leave for future API)
- [ ] Remove port mappings (or set to empty)
- [ ] Reset container labels to defaults (remove web service labels)
- [ ] **Persistent Storage**: Add Volume Mount (`sat-catalogos-data` → `/data`)
- [ ] **Start Command**: Set the full pipeline command
- [ ] Clear pre/post deployment commands
- [ ] Set up Scheduled Task for daily updates

## Next Steps

1. Configure the volume mount as described
2. Set the start command
3. Deploy and test
4. Set up the scheduled task for daily updates
5. Create your API app and mount the same volume

