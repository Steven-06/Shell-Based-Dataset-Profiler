#!/usr/bin/env bash
# lib/stats.sh : Statistics Engine

# Result arrays: populated by compute_all_stats(), read by formatter and export
declare -a COL_TYPE=()        # "numeric" or "string"
declare -a COL_MISSING=()     # count of empty or missing values
declare -a COL_UNIQUE=()      # count of distinct non-empty values
declare -a COL_MIN=()         # min (numeric) or shortest (string)
declare -a COL_MAX=()         # max (numeric) or longest (string)
declare -a COL_MEAN=()        # mean (numeric) or "N/A" (string)


# Determine if a column is numeric or string
detect_type() {
    local values="$1"
    local all_numeric=true

    IFS="|" read -ra items <<< "$values"
    for val in "${items[@]}"; do
        [[ -z "$val" ]] && continue   # skip missing values
        # Test: is it a valid integer or decimal (including negatives)?
        if ! echo "$val" | grep -qE '^-?[0-9]+([.][0-9]+)?$'; then
            all_numeric=false
            break
        fi
    done

    if $all_numeric; then
        echo "numeric"
    else
        echo "string"
    fi
}

# Count empty & blank values in a column
count_missing() {
    local values="$1"
    local count=0

    IFS="|" read -ra items <<< "$values"
    for val in "${items[@]}"; do
        [[ -z "$val" ]] && (( count++ ))
    done

    echo "$count"
}

# Count distinct non-empty values
count_unique() {
    local values="$1"
    # Replace pipes with newlines, filter empty, sort and count unique
    echo "$values" \
        | tr '|' '\n' \
        | grep -v '^$' \
        | sort \
        | uniq \
        | wc -l \
        | tr -d ' '
}

# Compute min, max, mean for a numeric column
compute_numeric_stats() {
    local values="$1"

    echo "$values" | tr '|' '\n' | grep -v '^$' | awk '
    BEGIN { min = ""; max = ""; sum = 0; count = 0 }
    {
        val = $1 + 0
        if (min == "" || val < min) min = val
        if (max == "" || val > max) max = val
        sum += val
        count++
    }
    END {
        if (count == 0) {
            print "N/A"
            print "N/A"
            print "N/A"
        } else {
            # Print cleanly: decimal for normal range, scientific for very large/small
            mean = sum / count
            fmt_min  = (min  > -1e6 && min  < 1e6) ? "%.2f" : "%.4g"
            fmt_max  = (max  > -1e6 && max  < 1e6) ? "%.2f" : "%.4g"
            fmt_mean = (mean > -1e6 && mean < 1e6) ? "%.2f" : "%.4g"
            printf fmt_min"\n",  min
            printf fmt_max"\n",  max
            printf fmt_mean"\n", mean
        }
    }'
}

# For string columns (compute the min and max length of word)
compute_string_stats() {
    local values="$1"

    echo "$values" | tr '|' '\n' | grep -v '^$' | awk '
    BEGIN { min_len = -1; max_len = -1; min_val = ""; max_val = "" }
    {
        len = length($0)
        if (min_len == -1 || len < min_len) { min_len = len; min_val = $0 }
        if (max_len == -1 || len > max_len) { max_len = len; max_val = $0 }
    }
    END {
        if (NR == 0) {
            print "N/A"
            print "N/A"
        } else {
            print min_val
            print max_val
        }
        print "N/A"
    }'
}

# This is the main entry point that processes every column
compute_all_stats() {
    for (( i=0; i<TOTAL_COLS; i++ )); do
        local data="${COL_DATA[$i]}"

        # Type detection
        COL_TYPE[$i]=$(detect_type "$data")

        # Missing & unique counts
        COL_MISSING[$i]=$(count_missing "$data")
        COL_UNIQUE[$i]=$(count_unique "$data")

        # Min / max / mean
        local stats_output
        if [[ "${COL_TYPE[$i]}" == "numeric" ]]; then
            stats_output=$(compute_numeric_stats "$data")
        else
            stats_output=$(compute_string_stats "$data")
        fi

        COL_MIN[$i]=$(echo "$stats_output" | sed -n '1p')
        COL_MAX[$i]=$(echo "$stats_output" | sed -n '2p')
        COL_MEAN[$i]=$(echo "$stats_output" | sed -n '3p')
    done
}
