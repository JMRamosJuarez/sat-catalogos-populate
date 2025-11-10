<?php

declare(strict_types=1);

namespace PhpCfdi\SatCatalogosPopulate\Converters;

use PhpCfdi\SatCatalogosPopulate\Utils\ShellExec;
use PhpCfdi\SatCatalogosPopulate\Utils\WhichTrait;
use RuntimeException;

/**
 * Lightweight XLS to CSV converter using ssconvert (Gnumeric)
 * 
 * This converter uses much less memory than LibreOffice.
 * It converts XLS directly to CSV in one step.
 */
class XlsToCsvLightweightConverter
{
    use WhichTrait;

    /** @var string Location of ssconvert executable */
    private readonly string $ssconvertPath;

    public function __construct(string $ssconvertPath = '')
    {
        if ('' === $ssconvertPath) {
            $ssconvertPath = $this->which('ssconvert');
        }
        $this->ssconvertPath = $ssconvertPath;
    }

    public function ssconvertPath(): string
    {
        return $this->ssconvertPath;
    }

    /**
     * Convert XLS file to CSV file directly
     * 
     * @param string $source XLS file path
     * @param string $destination CSV file path (will be created)
     * @param string $sheetName Optional sheet name (default: first sheet)
     */
    public function convertToCsv(string $source, string $destination, string $sheetName = ''): void
    {
        if (! file_exists($source) || is_dir($source) || ! is_readable($source)) {
            throw new RuntimeException("File $source does not exist or is not readable");
        }

        $destinationDir = dirname($destination);
        if (! is_dir($destinationDir)) {
            if (! mkdir($destinationDir, 0755, true)) {
                throw new RuntimeException("Cannot create destination directory: $destinationDir");
            }
        }
        if (! is_writable($destinationDir)) {
            throw new RuntimeException("Destination directory is not writable: $destinationDir");
        }

        // ssconvert can convert XLS directly to CSV
        // Format: ssconvert "input.xls" "output.csv"
        // For specific sheet: ssconvert -S "input.xls" "output.csv" (but this creates multiple files)
        // We'll use the first sheet by default
        
        $command = escapeshellarg($this->ssconvertPath()) . ' ' . implode(' ', array_map('escapeshellarg', [
            $source,
            $destination,
        ]));

        $execution = ShellExec::run($command);
        if (0 !== $execution->exitStatus()) {
            throw new RuntimeException(
                "Execution of ssconvert conversion returned a non-zero status code [{$execution->exitStatus()}]"
            );
        }

        if (! file_exists($destination)) {
            throw new RuntimeException("CSV file was not created: $destination");
        }
    }

    /**
     * Convert XLS file to multiple CSV files (one per sheet) in a folder
     * 
     * @param string $source XLS file path
     * @param string $destinationFolder Folder where CSV files will be created
     */
    public function convertToCsvFolder(string $source, string $destinationFolder): void
    {
        if (! file_exists($source) || is_dir($source) || ! is_readable($source)) {
            throw new RuntimeException("File $source does not exist or is not readable");
        }

        if (! is_dir($destinationFolder)) {
            if (! mkdir($destinationFolder, 0755, true)) {
                throw new RuntimeException("Cannot create destination directory: $destinationFolder");
            }
        }
        if (! is_writable($destinationFolder)) {
            throw new RuntimeException("Destination directory is not writable: $destinationFolder");
        }

        // ssconvert -S converts all sheets to separate CSV files
        // Output files will be named like: destination_folder/Sheet1.csv, Sheet2.csv, etc.
        // The %s is replaced by the sheet name
        $command = escapeshellarg($this->ssconvertPath()) . ' -S ' . escapeshellarg($source) . ' ' . escapeshellarg($destinationFolder . '/%s.csv');

        $execution = ShellExec::run($command);
        if (0 !== $execution->exitStatus()) {
            throw new RuntimeException(
                "Execution of ssconvert conversion returned a non-zero status code [{$execution->exitStatus()}]"
            );
        }

        // Check if any CSV files were created
        $csvFiles = glob($destinationFolder . '/*.csv') ?: [];
        if (empty($csvFiles)) {
            throw new RuntimeException("No CSV files were created in: $destinationFolder");
        }
    }
}

