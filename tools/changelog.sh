#!/bin/bash

export LC_ALL=en_US.UTF-8
export TZ=UTC

# -------------------------------
# CONFIGURATION ARRAYS (EDIT HERE)
# -------------------------------

# Patterns to ignore in commit subjects (case-sensitive substrings)
IGNORE_PATTERNS=(
    "Automatic translation import"
    "Update translation"
)

# Directories to exclude from scanning (relative to BASE_DIR)
EXCLUDE_DIRS=(
    "out"
    ".repo"
    "out-kernel"
    "device"
)

# ---------------------------------
# END OF CONFIGURATION
# ---------------------------------

show_help() {
    cat << EOF >&2
Usage: $0 <YYYYMMDD> <BASE_DIR> <OUTPUT_FILE>

  YYYYMMDD    : date from which to show commits (e.g., 20260507)
  BASE_DIR    : root directory containing all Git repositories
  OUTPUT_FILE : file where changelog will be saved

Options are fixed: always expand merges, limit 100 commits per repo.
EOF
}

# --- Check arguments ---
if [ $# -ne 3 ]; then
    show_help
    exit 1
fi

bash $banner_script nowait $device $android_version $los_branch
echo -e "${WHITEONMAGENTA} Changelog generation... ${NOCOLOR}"
echo
echo -e "- Last public build: ${GREEN}$last_build${NOCOLOR}"

SINCE_RAW="$1"
BASE_DIR="$2"
OUTPUT_FILE="$3"

# Convert date
if [[ "$SINCE_RAW" =~ ^[0-9]{8}$ ]]; then
    SINCE_DATE="${SINCE_RAW:0:4}-${SINCE_RAW:4:2}-${SINCE_RAW:6:2}"
else
    SINCE_DATE="$SINCE_RAW"
fi

SINCE_EPOCH=$(date -u -d "$SINCE_DATE 00:00:00" +%s 2>/dev/null)
if [ -z "$SINCE_EPOCH" ]; then
    echo -e "${RED}Invalid date: $SINCE_DATE${NOCOLOR}" >&2
    exit 1
fi

# Check base directory
if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}Error: Base directory '$BASE_DIR' does not exist.${NOCOLOR}" >&2
    exit 1
fi

cd "$BASE_DIR" || { echo -e "${RED}Cannot cd to $BASE_DIR${NOCOLOR}"; exit 1; }

# Build find exclusion arguments
EXCLUDE_FIND=()
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_FIND+=(! -path "./$dir/*" ! -path "./$dir")
done

echo -n "- Searching repos under $BASE_DIR... " >&2
REPO_PATHS=$(find -L . -type d -name ".git" "${EXCLUDE_FIND[@]}" ! -path "./.repo/*" -printf "%h\n" 2>/dev/null | sed 's|^\./||' | sort -u)
mapfile -t REPO_ARRAY <<< "$REPO_PATHS"
TOTAL_REPOS=${#REPO_ARRAY[@]}
echo -e "${GREEN}Found $TOTAL_REPOS repos${NOCOLOR}" >&2

# Build grep pattern for ignoring subjects
if [ ${#IGNORE_PATTERNS[@]} -gt 0 ]; then
    GREP_PATTERN=$(printf "|%s" "${IGNORE_PATTERNS[@]}")
    GREP_PATTERN="(${GREP_PATTERN:1})"
else
    GREP_PATTERN=""
fi

# Fixed limit
LIMIT=100
OUTPUT=""
REPO_COUNT=0
PROCESSED=0
# BARWIDTH=20

echo "- Analyzing repos..."
for REPO in "${REPO_ARRAY[@]}"; do
    PROCESSED=$((PROCESSED+1))
    PERCENT=$(( PROCESSED * 100 / TOTAL_REPOS ))
    # FILLED=$(( PERCENT * BARWIDTH / 2 ))
    # EMPTY=$(( BARWIDTH - FILLED ))
    # BAR=""
    # for ((i=0; i<FILLED; i++)); do BAR="${BAR}▒"; done
    # for ((i=0; i<EMPTY; i++)); do BAR="${BAR} "; done
    echo -ne ${YELLOW}$PERCENT"%"${NOCOLOR} ${BLUE}"["$PROCESSED"/"$TOTAL_REPOS"]"${NOCOLOR} $REPO "                                  "\\r
    # printf "\r▕%s▏ %3d%%  [%d/%d] %s\033[K" "$BAR" "$PERCENT" "$PROCESSED" "$TOTAL_REPOS" "$REPO" >&2

    COMMITS=$(git -C "$REPO" log -n "$LIMIT" --format="%at%x1F%ad%x1F%h%x1F%P%x1F%s" --date=short --no-patch 2>/dev/null)

    if [ -n "$COMMITS" ]; then
        FILTERED_BY_DATE=$(echo "$COMMITS" | awk -v since="$SINCE_EPOCH" -F'\x1f' '{ if ($1 >= since) print }')

        if [ -n "$FILTERED_BY_DATE" ]; then
            if [ -n "$GREP_PATTERN" ]; then
                FILTERED=$(echo "$FILTERED_BY_DATE" | grep -vE "$GREP_PATTERN")
            else
                FILTERED="$FILTERED_BY_DATE"
            fi

            if [ -n "$FILTERED" ]; then
                REPO_COUNT=$((REPO_COUNT+1))
                OUTPUT="${OUTPUT}[$REPO_COUNT] >>> Repository: $REPO\n"

                while IFS= read -r line; do
                    IFS=$'\x1f' read -r ts date hash parents subject <<< "$line"
                    OUTPUT="${OUTPUT}[$date] $hash - $subject\n"

                    # Always expand merges
                    if [ -n "$parents" ]; then
                        parent_count=$(echo "$parents" | wc -w)
                        if [ $parent_count -ge 2 ]; then
                            merge_commit_hash="$hash"
                            expanded_raw=$(git -C "$REPO" log --no-merges \
                                --format="%ad %h %s" \
                                --date=short \
                                "${merge_commit_hash}^1..${merge_commit_hash}^2" 2>/dev/null)
                            if [ -n "$expanded_raw" ]; then
                                if [ -n "$GREP_PATTERN" ]; then
                                    expanded_filtered=$(echo "$expanded_raw" | grep -vE "$GREP_PATTERN")
                                else
                                    expanded_filtered="$expanded_raw"
                                fi
                                if [ -n "$expanded_filtered" ]; then
                                    expanded_indented=$(echo "$expanded_filtered" | sed 's/^/        /')
                                    OUTPUT="${OUTPUT}    └─ Merged from:\n"
                                    OUTPUT="${OUTPUT}${expanded_indented}\n"
                                fi
                            fi
                        fi
                    fi
                done <<< "$FILTERED"

                OUTPUT="${OUTPUT}----------------------------------------\n"
            fi
        fi
    fi
done

printf "\n" >&2
echo -e "${GREEN}Done.${NOCOLOR} ${BLUE}$REPO_COUNT${NOCOLOR} repos with commits on or after $SINCE_DATE." >&2

# Write output to file
printf "%b" "$OUTPUT" > "$OUTPUT_FILE"
echo "- Changelog written to: $OUTPUT_FILE" >&2
