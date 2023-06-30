#!/bin/bash

SWIFTLINT_RULES=$(swiftlint rules | awk -F "|" 'NR>2 && $0 ~ /warning/ { gsub(/^[[:blank:]]+|[[:blank:]]+$/, "", $2); print "- " $2 }')

CONFIG_FILE=".swiftlint.yml"

# Append DISABLED_RULES to the config file
# echo -e "disabled_rules:" >> "$CONFIG_FILE"
# echo -e "$SWIFTLINT_RULES" >> "$CONFIG_FILE"

# Append DISABLED_RULES to the config file
echo -e "disabled_rules:" >> "$CONFIG_FILE"
while IFS= read -r line; do
  echo -e "  $line" >> "$CONFIG_FILE"
done <<< "$SWIFTLINT_RULES"
