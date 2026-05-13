#!/usr/bin/env bash
# lib/export.sh :Enhancement & Export Module

EXPORT_DIR="output"
EXPORT_FILE="${EXPORT_DIR}/summary_output.csv"
HISTOGRAM_WIDTH=40  

# Write statistics to a CSV file
export_summary_csv() {
    # Create output directory if it doesn't exist
    mkdir -p "$EXPORT_DIR"

    {
        # Metadata header block
        echo "# Dataset Profiler Summary Export"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Source File: $INPUT_FILE"
        echo "# Rows: $TOTAL_ROWS | Columns: $TOTAL_COLS"
        echo "#"

        # Column headers for the data table
        echo "column,type,missing,missing_pct,unique,min,max,mean"

        # One row per column
        for (( i=0; i<TOTAL_COLS; i++ )); do
            local missing_pct
            missing_pct=$(awk "BEGIN { printf \"%.2f\", (${COL_MISSING[$i]} / $TOTAL_ROWS) * 100 }")

            printf '"%s","%s",%s,%s,%s,"%s","%s","%s"\n' \
                "${HEADERS[$i]}" \
                "${COL_TYPE[$i]}" \
                "${COL_MISSING[$i]}" \
                "${missing_pct}" \
                "${COL_UNIQUE[$i]}" \
                "${COL_MIN[$i]}" \
                "${COL_MAX[$i]}" \
                "${COL_MEAN[$i]}"
        done

    } > "$EXPORT_FILE"

    echo -e "  \033[1;32m Summary exported to:\033[0m \033[1;37m${EXPORT_FILE}\033[0m"
    echo ""
}

# Print ASCII bar chart for one numeric column
draw_histogram() {
    local i="$1" #column index
    local col_name="${HEADERS[$i]}"
    local values="${COL_DATA[$i]}"

    # Collect non-empty numeric values
    local nums
    nums=$(echo "$values" | tr '|' '\n' | grep -v '^$' | grep -E '^-?[0-9]+([.][0-9]+)?$')

    local count
    count=$(echo "$nums" | wc -l | tr -d ' ')
    [[ "$count" -eq 0 ]] && return

    # Compute min, max and bucket size for 8 buckets
    local stats
    stats=$(echo "$nums" | awk '
    BEGIN { min=""; max="" }
    { v=$1+0; if(min==""||v<min) min=v; if(max==""||v>max) max=v }
    END { print min; print max }')

    local col_min col_max
    col_min=$(echo "$stats" | sed -n '1p')
    col_max=$(echo "$stats" | sed -n '2p')

    # If all values are the same, skip
    if awk "BEGIN { exit ($col_max == $col_min) ? 0 : 1 }"; then
        return
    fi

    local num_buckets=8

    # Build bucket counts using awk
    local bucket_data
    bucket_data=$(echo "$nums" | awk -v min="$col_min" -v max="$col_max" -v nb="$num_buckets" '
    BEGIN {
        range = max - min
        for (b = 0; b < nb; b++) buckets[b] = 0
    }
    {
        v = $1 + 0
        idx = int((v - min) / range * nb)
        if (idx >= nb) idx = nb - 1
        buckets[idx]++
    }
    END {
        max_count = 0
        for (b = 0; b < nb; b++) if (buckets[b] > max_count) max_count = buckets[b]
        for (b = 0; b < nb; b++) print buckets[b] "|" max_count
    }')

    echo -e "  \033[1;35m▐ Histogram: ${col_name}\033[0m  \033[2m(${count} values, range: ${col_min} → ${col_max})\033[0m"
    echo -e "  \033[2m$(printf '%0.s─' $(seq 1 56))\033[0m"

    local b=0
    local bucket_width
    bucket_width=$(awk "BEGIN { printf \"%.4g\", ($col_max - $col_min) / $num_buckets }")

    while IFS='|' read -r bucket_count max_count; do
        local bar_len=0
        if [[ "$max_count" -gt 0 ]]; then
            bar_len=$(awk "BEGIN { printf \"%d\", ($bucket_count / $max_count) * $HISTOGRAM_WIDTH }")
        fi

        local range_lo range_hi
        range_lo=$(awk "BEGIN { printf \"%.4g\", $col_min + $b * $bucket_width }")
        range_hi=$(awk "BEGIN { printf \"%.4g\", $col_min + ($b + 1) * $bucket_width }")

        local bar=""
        for (( k=0; k<bar_len; k++ )); do bar+="█"; done
        for (( k=bar_len; k<HISTOGRAM_WIDTH; k++ )); do bar+=" "; done

        printf "  \033[2m[%8.4g – %8.4g]\033[0m \033[1;36m%s\033[0m \033[1;33m%3d\033[0m\n" \
            "$range_lo" "$range_hi" "$bar" "$bucket_count"

        (( b++ ))
    done <<< "$bucket_data"

    echo ""
}

# Draw histograms for every numeric column
print_all_histograms() {
    local printed_any=false

    echo -e "  \033[1;35m\033[1m ASCII Histograms\033[0m"
    echo ""

    for (( i=0; i<TOTAL_COLS; i++ )); do
        if [[ "${COL_TYPE[$i]}" == "numeric" ]]; then
            draw_histogram "$i"
            printed_any=true
        fi
    done

    if ! $printed_any; then
        echo -e "  \033[2mNo numeric columns found for histograms.\033[0m"
        echo ""
    fi
}
