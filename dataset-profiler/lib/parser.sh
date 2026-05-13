#!/usr/bin/env bash
# lib/parser.sh : Input Parser & Validator


# Global variables shared across all modules

INPUT_FILE=""
DELIMITER=","
DO_EXPORT=false
DO_HISTOGRAM=false
TOTAL_ROWS=0
TOTAL_COLS=0
declare -a HEADERS=()       # Column header names
declare -a COL_DATA=()      # Raw column values 

# Show help text when --help is passed or args are wrong
print_usage() {
    echo ""
    echo "  Usage: bash profiler.sh [OPTIONS]"
    echo ""
    echo "  Options:"
    echo "    -f, --file       <path>   Path to CSV file (required)"
    echo "    -d, --delimiter  <char>   Field delimiter (default: ,)"
    echo "    -e, --export              Export summary to output/summary_output.csv"
    echo "    -H, --histogram           Show ASCII histogram for numeric columns"
    echo "    -h, --help                Show this help message"
    echo ""
    echo "  Examples:"
    echo "    bash profiler.sh --file data/sample.csv"
    echo "    bash profiler.sh --file data/messy.csv --export --histogram"
    echo "    bash profiler.sh --file data/sample.csv --delimiter ';'"
    echo ""
}

# Read and validate CLI flags
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo "[ERROR] No arguments provided."
        print_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -d|--delimiter)
                DELIMITER="$2"
                shift 2
                ;;
            -e|--export)
                DO_EXPORT=true
                shift
                ;;
            -H|--histogram)
                DO_HISTOGRAM=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Validate that a file was provided
    if [[ -z "$INPUT_FILE" ]]; then
        echo "[ERROR] No input file specified. Use --file <path>"
        print_usage
        exit 1
    fi

    # Validate that the file exists and is readable
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "[ERROR] File not found: $INPUT_FILE"
        exit 1
    fi

    if [[ ! -r "$INPUT_FILE" ]]; then
        echo "[ERROR] File is not readable: $INPUT_FILE"
        exit 1
    fi

    # Validate the file is not empty
    if [[ ! -s "$INPUT_FILE" ]]; then
        echo "[ERROR] File is empty: $INPUT_FILE"
        exit 1
    fi
}


# load_csv Will Read the CSV into memory
# Populates: HEADERS, COL_DATA, TOTAL_ROWS, TOTAL_COLS
load_csv() {
    local line_num=0
    local IFS_BACKUP="$IFS"

    # Read header line first
    local header_line
    header_line=$(head -n 1 "$INPUT_FILE")

    # Parse header into HEADERS array
    IFS="$DELIMITER" read -ra HEADERS <<< "$header_line"
    TOTAL_COLS=${#HEADERS[@]}

    # Trim whitespace from headers
    for i in "${!HEADERS[@]}"; do
        HEADERS[$i]=$(echo "${HEADERS[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    done

    # Initialize COL_DATA array (one entry per column, pipe-separated values)
    for (( i=0; i<TOTAL_COLS; i++ )); do
        COL_DATA[$i]=""
    done

    # Read data rows (skip header)
    while IFS= read -r raw_line; do
        [[ -z "$raw_line" ]] && continue   # skip blank lines
        (( line_num++ ))

        # Split row by delimiter
        IFS="$DELIMITER" read -ra fields <<< "$raw_line"

        for (( col=0; col<TOTAL_COLS; col++ )); do
            local val="${fields[$col]:-}"
            # Trim whitespace
            val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Append to column's pipe-separated string
            if [[ -z "${COL_DATA[$col]}" ]]; then
                COL_DATA[$col]="$val"
            else
                COL_DATA[$col]="${COL_DATA[$col]}|$val"
            fi
        done
    done < <(tail -n +2 "$INPUT_FILE")

    TOTAL_ROWS=$line_num
    IFS="$IFS_BACKUP"
}
