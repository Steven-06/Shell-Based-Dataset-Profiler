# Shell-Based Dataset Profiler

A command-line tool that generates statistical summaries of CSV datasets, a shell-native equivalent of `pandas.describe()`.

## Features

- Detects column data types (numeric vs string)
- Computes min, max, and mean for numeric columns
- Counts missing values per column with percentage
- Counts unique values per column
- Color-coded terminal output with formatted table
- Export summary to CSV with `--export`
- ASCII histogram for numeric columns with `--histogram`

## Project Structure

```
dataset-profiler/
├── profiler.sh          # Main entry point
├── lib/
│   ├── parser.sh        # Argument parsing & CSV loading   (Steven)
│   ├── stats.sh         # Statistical computation          (Mostafa)
│   ├── formatter.sh     # Terminal output & formatting     (Pavlly)
│   └── export.sh        # CSV export & ASCII histogram     (Moamen)
├── data/
│   ├── sample.csv       # Clean test dataset
│   └── messy.csv        # Dataset with missing values
├── output/              # Auto-created; holds exported files
└── README.md
```

## Requirements

- Bash 4.0 or higher
- Standard Unix tools: `awk`, `sed`, `sort`, `uniq`, `grep`, `wc`
- No external dependencies

## Usage

```bash
# Basic profile
bash profiler.sh --file data/sample.csv

# With export to CSV
bash profiler.sh --file data/sample.csv --export

# With ASCII histogram
bash profiler.sh --file data/sample.csv --histogram

# All features at once
bash profiler.sh --file data/messy.csv --export --histogram

# Custom delimiter (semicolon)
bash profiler.sh --file data/myfile.csv --delimiter ';'

# Help
bash profiler.sh --help
```

## Output Columns

| Column   | Description                                         |
|----------|-----------------------------------------------------|
| Column   | Header name from the CSV                           |
| Type     | `numeric` or `string`                               |
| Missing  | Count of empty cells (T = none, F = some missing)  |
| Unique   | Count of distinct non-empty values                  |
| Min      | Minimum value (numeric) / shortest value (string)  |
| Max      | Maximum value (numeric) / longest value (string)   |
| Mean     | Average (numeric columns only, N/A for strings)    |

## Export Format

When `--export` is used, a file is created at `output/summary_output.csv` with columns:

```
column, type, missing, missing_pct, unique, min, max, mean
```

## Team

| Member | File | Responsibility |
|--------|------|----------------|
| Steven | `lib/parser.sh` | CLI arguments, file reading, CSV loading |
| Mostafa | `lib/stats.sh` | Type detection, min/max/mean, missing, unique |
| Pavlly | `lib/formatter.sh` | Terminal table, ANSI colors, layout |
| Moamen | `lib/export.sh` | CSV export, ASCII histogram, README |
