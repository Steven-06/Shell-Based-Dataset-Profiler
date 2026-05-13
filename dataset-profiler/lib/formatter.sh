#!/usr/bin/env bash
# lib/formatter.sh : Output Formatter

# ANSI color codes we will use it throughout the output
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_CYAN="\033[1;36m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_RED="\033[1;31m"
CLR_BLUE="\033[1;34m"
CLR_MAGENTA="\033[1;35m"
CLR_WHITE="\033[1;37m"
CLR_DIM="\033[2m"

# Table column widths
W_COL=14    # width for each stat column
W_NAME=16   # width for column name

# Print a character N times
repeat_char() {
    local char="$1"
    local count="$2"
    printf '%0.s'"$char" $(seq 1 "$count")
}

#Print the top section with file info
print_header_banner() {
    local filename
    filename=$(basename "$INPUT_FILE")
    local total_width=$(( W_NAME + W_COL * 7 + 8 ))

    echo ""
    echo -e "${CLR_CYAN}$(repeat_char '═' $total_width)${CLR_RESET}"
    printf "${CLR_BOLD}${CLR_WHITE}  %-20s${CLR_RESET} ${CLR_DIM}Shell Dataset Profiler v1.0${CLR_RESET}\n" "DATASET SUMMARY"
    echo -e "${CLR_CYAN}$(repeat_char '─' $total_width)${CLR_RESET}"
    printf "  ${CLR_DIM}File   :${CLR_RESET}  ${CLR_WHITE}%s${CLR_RESET}\n" "$filename"
    printf "  ${CLR_DIM}Path   :${CLR_RESET}  ${CLR_DIM}%s${CLR_RESET}\n" "$INPUT_FILE"
    printf "  ${CLR_DIM}Rows   :${CLR_RESET}  ${CLR_GREEN}%s${CLR_RESET}\n" "$TOTAL_ROWS"
    printf "  ${CLR_DIM}Columns:${CLR_RESET}  ${CLR_GREEN}%s${CLR_RESET}\n" "$TOTAL_COLS"
    printf "  ${CLR_DIM}Delim  :${CLR_RESET}  ${CLR_DIM}'%s'${CLR_RESET}\n" "$DELIMITER"
    echo -e "${CLR_CYAN}$(repeat_char '═' $total_width)${CLR_RESET}"
    echo ""
}

# Print the column header row of the stats table
print_table_header() {
    local total_width=$(( W_NAME + W_COL * 7 + 8 ))

    printf "${CLR_BOLD}${CLR_BLUE}"
    printf "  %-${W_NAME}s" "Column"
    printf " %-${W_COL}s" "Type"
    printf " %-${W_COL}s" "Missing"
    printf " %-${W_COL}s" "Unique"
    printf " %-${W_COL}s" "Min"
    printf " %-${W_COL}s" "Max"
    printf " %-${W_COL}s" "Mean"
    printf "${CLR_RESET}\n"
    echo -e "${CLR_DIM}  $(repeat_char '─' $(( total_width - 2 )))${CLR_RESET}"
}

# Shorten a value to fit inside a table cell
truncate_value() {
    local val="$1"
    local max="$2" #max width
    if [[ ${#val} -gt $max ]]; then
        echo "${val:0:$(( max - 2 ))}.."
    else
        echo "$val"
    fi
}

# Print one data row for a column
print_table_row() {
    local i="$1"  #column index
    local name type missing unique min_val max_val mean_val

    name=$(truncate_value "${HEADERS[$i]}" $W_NAME)
    type="${COL_TYPE[$i]}"
    missing="${COL_MISSING[$i]}"
    unique="${COL_UNIQUE[$i]}"
    min_val=$(truncate_value "${COL_MIN[$i]}" $W_COL)
    max_val=$(truncate_value "${COL_MAX[$i]}" $W_COL)
    mean_val=$(truncate_value "${COL_MEAN[$i]}" $W_COL)

    # Color the type label
    local type_colored
    if [[ "$type" == "numeric" ]]; then
        type_colored="${CLR_GREEN}numeric${CLR_RESET}"
    else
        type_colored="${CLR_MAGENTA}string${CLR_RESET} "
    fi

    # Color missing: red if any missing, and dim green if none
    local missing_colored
    if [[ "$missing" -gt 0 ]]; then
        missing_colored="${CLR_RED}${missing} F${CLR_RESET}"
    else
        missing_colored="${CLR_GREEN}${missing} T${CLR_RESET}"
    fi

    # Alternate row shading for readability
    local row_prefix=""
    if (( i % 2 == 0 )); then
        row_prefix="${CLR_DIM}"
    fi

    printf "  ${row_prefix}%-${W_NAME}s${CLR_RESET}" "$name"
    printf " %-$((W_COL + 9))b"  "$type_colored"
    printf " %-$((W_COL + 9))b"  "$missing_colored"
    printf " ${CLR_YELLOW}%-${W_COL}s${CLR_RESET}" "$unique"
    printf " ${CLR_WHITE}%-${W_COL}s${CLR_RESET}" "$min_val"
    printf " ${CLR_WHITE}%-${W_COL}s${CLR_RESET}" "$max_val"
    printf " ${CLR_CYAN}%-${W_COL}s${CLR_RESET}" "$mean_val"
    printf "\n"
}

# Print the bottom border and legend
print_table_footer() {
    local total_width=$(( W_NAME + W_COL * 7 + 8 ))
    echo -e "${CLR_DIM}  $(repeat_char '─' $(( total_width - 2 )))${CLR_RESET}"
    echo ""
    echo -e "  ${CLR_DIM}Legend:${CLR_RESET}  ${CLR_GREEN}✓ No missing${CLR_RESET}  ${CLR_RED}✗ Has missing${CLR_RESET}  ${CLR_MAGENTA}string${CLR_RESET}  ${CLR_GREEN}numeric${CLR_RESET}  ${CLR_YELLOW}Unique count${CLR_RESET}  ${CLR_CYAN}Mean${CLR_RESET}"
    echo ""
}

# Extra block highlighting columns with missing data
print_missing_summary() {
    local found_missing=false

    for (( i=0; i<TOTAL_COLS; i++ )); do
        if [[ "${COL_MISSING[$i]}" -gt 0 ]]; then
            if ! $found_missing; then
                echo -e "  ${CLR_RED}${CLR_BOLD}Missing Value Report:${CLR_RESET}"
                echo -e "  ${CLR_DIM}$(repeat_char '─' 40)${CLR_RESET}"
                found_missing=true
            fi
            local pct
            pct=$(awk "BEGIN { printf \"%.1f\", (${COL_MISSING[$i]} / $TOTAL_ROWS) * 100 }")
            printf "  ${CLR_RED}%-18s${CLR_RESET} ${CLR_WHITE}%s / %s rows${CLR_RESET}  ${CLR_YELLOW}(%s%%)${CLR_RESET}\n" \
                "${HEADERS[$i]}" "${COL_MISSING[$i]}" "$TOTAL_ROWS" "$pct"
        fi
    done

    if $found_missing; then
        echo ""
    fi
}

# Master function: renders the complete terminal output
print_full_report() {
    print_header_banner
    print_table_header

    for (( i=0; i<TOTAL_COLS; i++ )); do
        print_table_row "$i"
    done

    print_table_footer
    print_missing_summary
}
