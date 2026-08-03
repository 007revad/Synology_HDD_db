#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/syno_hdd_db.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

extract_function() {
    local function_name="$1"
    sed -n "/^${function_name}(){/,/^}/p" "$script"
}

eval "$(extract_function get_eunit_container_aliases)"
eval "$(extract_function find_eunit_db_files)"

mkdir -p "$tmpdir/runtime/sata13" "$tmpdir/db"
printf '%s\n' "RX1217-1" > "$tmpdir/runtime/sata13/container"

ebox_info=$(cat <<'EOF'
************ Disk Info ***************
>> Disk id: 1
>> Slot id: -1
>> Disk path: /dev/sata13
>> Disk model: ST4000VN006-3CW104
EOF
)

mapfile -t runtime_aliases < <(
    get_eunit_container_aliases "$ebox_info" "$tmpdir/runtime"
)

if [[ ${runtime_aliases[*]} != "RX1217" ]]; then
    echo "Expected runtime alias RX1217, got: ${runtime_aliases[*]-<none>}" >&2
    exit 1
fi

eunitlist=("RX1217rp" "${runtime_aliases[@]}")
mapfile -t eunits < <(printf '%s\n' "${eunitlist[@]}" | sort -u)

touch \
    "$tmpdir/db/rx1217.db" \
    "$tmpdir/db/rx1217 module_v7.db" \
    "$tmpdir/db/rx1217_v7.db" \
    "$tmpdir/db/rx1217rp.db" \
    "$tmpdir/db/rx1217rp_v7.db" \
    "$tmpdir/db/rx1217sas_v7.db" \
    "$tmpdir/db/rx1217.db.new" \
    "$tmpdir/db/rx1217rp.db.new" \
    "$tmpdir/db/rx1217sas_v7.db.new"

mapfile -t selected < <(
    find_eunit_db_files "$tmpdir/db" ".db" "${eunits[@]}" |
        while IFS= read -r file; do basename "$file"; done |
        sort
)

expected=(
    "rx1217 module_v7.db"
    "rx1217.db"
    "rx1217_v7.db"
    "rx1217rp.db"
    "rx1217rp_v7.db"
)

if [[ ${selected[*]} != "${expected[*]}" ]]; then
    echo "Unexpected expansion-unit database selection" >&2
    printf 'Expected: %s\n' "${expected[*]}" >&2
    printf 'Actual:   %s\n' "${selected[*]-<none>}" >&2
    exit 1
fi

mapfile -t selected_new < <(
    find_eunit_db_files "$tmpdir/db" ".db.new" "${eunits[@]}" |
        while IFS= read -r file; do basename "$file"; done |
        sort
)

expected_new=(
    "rx1217.db.new"
    "rx1217rp.db.new"
)

if [[ ${selected_new[*]} != "${expected_new[*]}" ]]; then
    echo "Unexpected expansion-unit .db.new selection" >&2
    printf 'Expected: %s\n' "${expected_new[*]}" >&2
    printf 'Actual:   %s\n' "${selected_new[*]-<none>}" >&2
    exit 1
fi

echo "PASS: runtime aliases select RX1217 and RX1217RP databases without RX1217SAS"
