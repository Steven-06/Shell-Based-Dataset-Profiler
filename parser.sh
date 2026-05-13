#!/usr/bin/env bash

# Exported globals (used by stats.sh, formatter.sh, export.sh):
#   INPUT_FILE      — path to the CSV file
#   DELIMITER       — field separator character (default: ',')
#   EXPORT_FLAG     — 1 if --export was passed, 0 otherwise
#   NUM_COLS        — total number of columns
#   NUM_ROWS        — number of data rows (excluding header)
#   HEADERS[]       — array of column names
#   COL_DATA[i]     — newline-separated values for column i (0-indexed)
#   DATASET_NAME    — base filename without path/extension
# =============================================================================

# --------------------------------------------------------------------------- #
#  Default values for all shared global variables
# --------------------------------------------------------------------------- #
INPUT_FILE=""
DELIMITER=","
EXPORT_FLAG=0
NUM_COLS=0
NUM_ROWS=0
DATASET_NAME=""
declare -a HEADERS=()
declare -a COL_DATA=()      # COL_DATA[i] holds all values for column i, one per line

# --------------------------------------------------------------------------- #
#  show_usage — print help text and exit cleanly
# --------------------------------------------------------------------------- #
show_usage() {
    cat <<EOF
Usage: bash profiler.sh --file <path> [OPTIONS]

Options:
  --file       <path>   Path to the CSV (or delimited) file  [required]
  --delimiter  <char>   Field delimiter (default: ',')
  --export              Write summary to output/summary_output.csv
  --help                Show this help message

Examples:
  bash profiler.sh --file data/sample.csv
  bash profiler.sh --file data/messy.csv --delimiter ';'
  bash profiler.sh --file data/sample.csv --export
EOF
    exit 0
}

# --------------------------------------------------------------------------- #
#  parse_arguments — process all CLI flags into global variables
# --------------------------------------------------------------------------- #
parse_arguments() {
    # Require at least one argument
    if [[ $# -eq 0 ]]; then
        echo "Error: No arguments provided." >&2
        echo "Run with --help for usage information." >&2
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --file requires a path argument." >&2
                    exit 1
                fi
                INPUT_FILE="$2"
                shift 2
                ;;
            --delimiter)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --delimiter requires a character argument." >&2
                    exit 1
                fi
                DELIMITER="$2"
                shift 2
                ;;
            --export)
                EXPORT_FLAG=1
                shift
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                echo "Error: Unknown argument '$1'." >&2
                echo "Run with --help for usage information." >&2
                exit 1
                ;;
        esac
    done

    # --file is mandatory
    if [[ -z "$INPUT_FILE" ]]; then
        echo "Error: --file is required." >&2
        echo "Run with --help for usage information." >&2
        exit 1
    fi
}

# --------------------------------------------------------------------------- #
#  validate_file — confirm the file exists, is readable, and is non-empty
# --------------------------------------------------------------------------- #
validate_file() {
    if [[ ! -e "$INPUT_FILE" ]]; then
        echo "Error: File not found: '$INPUT_FILE'" >&2
        exit 1
    fi

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Error: '$INPUT_FILE' is not a regular file." >&2
        exit 1
    fi

    if [[ ! -r "$INPUT_FILE" ]]; then
        echo "Error: File is not readable: '$INPUT_FILE'" >&2
        exit 1
    fi

    if [[ ! -s "$INPUT_FILE" ]]; then
        echo "Error: File is empty: '$INPUT_FILE'" >&2
        exit 1
    fi
}

# --------------------------------------------------------------------------- #
#  auto_detect_delimiter — sniff the first line if no delimiter was given
#  by the user, checking for common separators in order of preference.
#  If the user supplied --delimiter explicitly this function is skipped.
# --------------------------------------------------------------------------- #
auto_detect_delimiter() {
    # Only auto-detect if user kept the default comma and the file is not .csv
    local ext="${INPUT_FILE##*.}"
    [[ "$ext" == "csv" ]] && return   # CSV → stay with comma

    local first_line
    first_line=$(head -n 1 "$INPUT_FILE")

    for sep in $'\t' '|' ';' ':'; do
        if [[ "$first_line" == *"$sep"* ]]; then
            DELIMITER="$sep"
            return
        fi
    done
    # Fallback: keep comma
}

# --------------------------------------------------------------------------- #
#  _split_line — split a single CSV line respecting the current DELIMITER
#  Usage:  _split_line "line_string" result_array_name
#
#  Simple splitting via IFS — sufficient for unquoted CSV.
#  Fields are trimmed of leading/trailing whitespace.
# --------------------------------------------------------------------------- #
_split_line() {
    local line="$1"
    local -n _out_array="$2"   # nameref — writes back to caller's array

    _out_array=()
    local OLD_IFS="$IFS"
    IFS="$DELIMITER"
    read -ra _out_array <<< "$line"
    IFS="$OLD_IFS"

    # Trim whitespace from each field
    local i
    for i in "${!_out_array[@]}"; do
        _out_array[$i]="${_out_array[$i]#"${_out_array[$i]%%[![:space:]]*}"}"
        _out_array[$i]="${_out_array[$i]%"${_out_array[$i]##*[![:space:]]}"}"
    done
}

# --------------------------------------------------------------------------- #
#  load_csv — read the file into HEADERS[] and COL_DATA[]
# --------------------------------------------------------------------------- #
load_csv() {
    local line
    local -a fields=()
    local row_count=0
    local first_line=1

    # Initialize COL_DATA elements after we know NUM_COLS (set from header)
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip completely blank lines
        [[ -z "${line//[$'\t\r\n ']/}" ]] && continue

        # Strip Windows-style carriage return if present
        line="${line%$'\r'}"

        _split_line "$line" fields

        if [[ $first_line -eq 1 ]]; then
            # ---- Header row ------------------------------------------------
            NUM_COLS="${#fields[@]}"

            if [[ $NUM_COLS -eq 0 ]]; then
                echo "Error: Could not detect any columns. Check the delimiter (currently: '$DELIMITER')." >&2
                exit 1
            fi

            HEADERS=("${fields[@]}")

            # Pre-initialise one empty slot per column
            local c
            for (( c=0; c<NUM_COLS; c++ )); do
                COL_DATA[$c]=""
            done

            first_line=0
        else
            # ---- Data row --------------------------------------------------

            # Warn (but continue) if column count mismatches
            if [[ "${#fields[@]}" -ne "$NUM_COLS" ]]; then
                echo "Warning: Row $((row_count+1)) has ${#fields[@]} fields (expected $NUM_COLS). Padding/truncating." >&2
            fi

            local c
            for (( c=0; c<NUM_COLS; c++ )); do
                local val="${fields[$c]-}"    # empty string if field missing
                if [[ -z "${COL_DATA[$c]}" ]]; then
                    COL_DATA[$c]="$val"
                else
                    COL_DATA[$c]+=$'\n'"$val"
                fi
            done

            (( row_count++ ))
        fi
    done < "$INPUT_FILE"

    NUM_ROWS=$row_count

    if [[ $NUM_ROWS -eq 0 ]]; then
        echo "Error: File has a header but no data rows: '$INPUT_FILE'" >&2
        exit 1
    fi

    # Derive a friendly dataset name from the filename
    DATASET_NAME=$(basename "$INPUT_FILE")
    DATASET_NAME="${DATASET_NAME%.*}"
}

# --------------------------------------------------------------------------- #
#  init_parser — public entry point called from profiler.sh
#  Usage:  init_parser "$@"
# --------------------------------------------------------------------------- #
init_parser() {
    parse_arguments "$@"
    validate_file
    auto_detect_delimiter
    load_csv
}
