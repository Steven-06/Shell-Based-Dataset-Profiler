#!/usr/bin/env bash
# This is the main entry point : sources all modules and orchestrates the pipeline

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules

source "${SCRIPT_DIR}/lib/parser.sh"
source "${SCRIPT_DIR}/lib/stats.sh"
source "${SCRIPT_DIR}/lib/formatter.sh"
source "${SCRIPT_DIR}/lib/export.sh"

# Pipeline : execute all stages in order

main() {
    # Stage 1: Parse & validate CLI arguments 
    parse_arguments "$@"

    # Stage 2: Load CSV into memory 
    load_csv

    # Stage 3: Compute statistics for every column 
    compute_all_stats

    # Stage 4: Print the full formatted report to terminal 
    print_full_report

    # Stage 5: Optional: export summary to CSV 
    if [[ "$DO_EXPORT" == true ]]; then
        export_summary_csv
    fi

    # Stage 6: Optional: print ASCII histograms
    if [[ "$DO_HISTOGRAM" == true ]]; then
        print_all_histograms
    fi
}

main "$@"
