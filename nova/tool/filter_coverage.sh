#!/bin/bash
# Filter .g.dart and .freezed.dart files from lcov coverage data
# Usage: bash tool/filter_coverage.sh [input_file] [output_file]
# Default: coverage/lcov.info -> coverage/lcov_filtered.info

INPUT="${1:-coverage/lcov.info}"
OUTPUT="${2:-coverage/lcov_filtered.info}"

awk '
/^SF:/ {
  skip = 0
  if ($0 ~ /\.g\.dart$/ || $0 ~ /\.freezed\.dart$/) {
    skip = 1
  }
}
skip == 0 { print }
' "$INPUT" > "$OUTPUT"

echo "Filtered coverage written to $OUTPUT"

# Calculate and display coverage
awk '
BEGIN { total_found=0; total_hit=0; }
/^LF:/ { total_found += substr($0, 4) }
/^LH:/ { total_hit += substr($0, 4) }
END {
  if (total_found > 0)
    printf "Lines found: %d\nLines hit: %d\nCoverage: %.2f%%\n", total_found, total_hit, (total_hit/total_found)*100
  else
    print "No coverage data"
}
' "$OUTPUT"
