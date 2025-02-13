# Move to the directory of this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

temp_file=$(mktemp)
cat test_log.txt >"$temp_file"

# Process each logcheck regex file
for logfile in rules/*; do
	grep -E -v --file "$logfile" "$temp_file" >"$temp_file.new"
	mv "$temp_file.new" "$temp_file"
done
cat "$temp_file"
