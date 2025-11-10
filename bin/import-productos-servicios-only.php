#!/usr/bin/env php
<?php

declare(strict_types=1);

use PhpCfdi\SatCatalogosPopulate\Commands\TerminalLogger;
use PhpCfdi\SatCatalogosPopulate\Database\Repository;
use PhpCfdi\SatCatalogosPopulate\Importers\Cfdi40Catalogs;
use PhpCfdi\SatCatalogosPopulate\Importers\Cfdi40\Injectors\ProductosServicios;
use PhpCfdi\SatCatalogosPopulate\Injectors;
use PhpCfdi\SatCatalogosPopulate\Converters\XlsToCsvFolderConverter;

require __DIR__ . '/../vendor/autoload.php';

// Configuration
$sourceFolder = $argv[1] ?? '/data/catalogs';
$databasePath = $argv[2] ?? '/data/catalogos.sqlite3';
$xlsFile = $sourceFolder . '/cfdi_40.xls';
$csvFile = $sourceFolder . '/c_ClaveProdServ.csv'; // Pre-converted CSV (optional)
$lockFile = dirname($databasePath) . '/.import_lock';
$failureFile = dirname($databasePath) . '/.import_failed';

$logger = new TerminalLogger();

// Check for lock file (import in progress)
if (file_exists($lockFile)) {
    $lockAge = time() - filemtime($lockFile);
    // If lock is older than 1 hour, assume previous process died
    if ($lockAge > 3600) {
        $logger->warning("Stale lock file found (older than 1 hour). Removing it.");
        @unlink($lockFile);
    } else {
        $logger->error("Import already in progress (lock file exists). Exiting.");
        exit(1);
    }
}

// Check for recent failure (prevent immediate retries)
if (file_exists($failureFile)) {
    $failureAge = time() - filemtime($failureFile);
    // If failure was less than 1 hour ago, don't retry
    if ($failureAge < 3600) {
        $logger->warning("Recent import failure detected (less than 1 hour ago). Skipping to prevent OOM issues.");
        $logger->warning("To force retry, delete: {$failureFile}");
        exit(1);
    } else {
        // Old failure, remove it and allow retry
        @unlink($failureFile);
    }
}

// Check if database exists and table already has data
$repository = new Repository($databasePath);
$tableName = 'cfdi_40_productos_servicios';

if ($repository->hasTable($tableName)) {
    $recordCount = $repository->getRecordCount($tableName);
    if ($recordCount > 0) {
        $logger->info("Table {$tableName} already exists with {$recordCount} records. Skipping import.");
        exit(0);
    }
}

// Create lock file
file_put_contents($lockFile, date('c') . "\n" . getmypid() . "\n");
register_shutdown_function(function () use ($lockFile) {
    @unlink($lockFile);
});

// Check if pre-converted CSV exists (preferred - no memory-intensive conversion)
$usePreConvertedCsv = false;
$csvFolder = '';
$finalCsvFile = '';

if (file_exists($csvFile)) {
    $logger->info("Found pre-converted CSV file. Using it directly (skipping XLS conversion).");
    $usePreConvertedCsv = true;
    $finalCsvFile = $csvFile;
} elseif (file_exists($xlsFile)) {
    $logger->info("XLS file found. Will convert to CSV (this may require significant memory).");
    $usePreConvertedCsv = false;
    // Create temporary CSV folder for conversion
    $csvFolder = sys_get_temp_dir() . '/sat-catalogos-' . uniqid();
    mkdir($csvFolder, 0755, true);
} else {
    $logger->error("Neither CSV nor XLS source file found!");
    $logger->error("Expected one of:");
    $logger->error("  - Pre-converted CSV: {$csvFile}");
    $logger->error("  - XLS file: {$xlsFile}");
    @unlink($lockFile);
    exit(1);
}

$logger->info("Starting import of {$tableName}...");

try {
    if (!$usePreConvertedCsv) {
        // Convert XLS to CSV (memory-intensive - may fail with OOM)
        $logger->info("Converting XLS to CSV (this may take a while and use significant memory)...");
        $converter = new XlsToCsvFolderConverter();
        $converter->convert($xlsFile, $csvFolder);
        
        // Get the converted CSV file
        $finalCsvFile = $csvFolder . '/c_ClaveProdServ.csv';
        if (!file_exists($finalCsvFile)) {
            throw new RuntimeException("CSV file not found after conversion: {$finalCsvFile}");
        }
    }
    // If using pre-converted CSV, $finalCsvFile is already set above
    
    $injector = new ProductosServicios($finalCsvFile);
    $injector->validate();
    
    // Import into database
    $logger->info("Importing data into database...");
    $repository->pdo()->beginTransaction();
    $injector->inject($repository, $logger);
    $repository->pdo()->commit();
    
    $recordCount = $repository->getRecordCount($tableName);
    $logger->info("Import completed successfully! {$recordCount} records in {$tableName}.");
    
    // Remove failure file on success
    @unlink($failureFile);
    
} catch (Throwable $e) {
    if ($repository->pdo()->inTransaction()) {
        $repository->pdo()->rollBack();
    }
    
    // Mark as failed (especially for OOM errors - exit code 137)
    $exitCode = 1;
    if (strpos($e->getMessage(), '137') !== false || strpos($e->getMessage(), 'SIGKILL') !== false) {
        file_put_contents($failureFile, date('c') . "\n" . $e->getMessage() . "\n");
        $logger->error("Import failed due to memory issue (OOM). Marked as failed to prevent immediate retry.");
        $logger->error("The system likely ran out of memory during LibreOffice conversion.");
        $logger->error("Wait at least 1 hour before retrying, or increase server resources.");
    }
    
    $logger->error("Error: " . $e->getMessage());
    exit($exitCode);
} finally {
    // Remove lock file
    @unlink($lockFile);
    
    // Clean up temporary CSV files (only if we converted)
    if (!$usePreConvertedCsv && is_dir($csvFolder)) {
        array_map('unlink', glob($csvFolder . '/*.csv') ?: []);
        @rmdir($csvFolder);
    }
}

exit(0);

