#!/bin/bash

# Kupu Application String Resource Generator
# Usage: ./scripts/create-string-resource.sh <module_name> <entity_name>

# 1. Load configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/.generator-config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: .generator-config not found at $CONFIG_FILE. Are you in a Kupu application directory?"
    exit 1
fi

BASE_PACKAGE=$(cat "$CONFIG_FILE" | head -1)

cd "$PROJECT_ROOT"

show_help() {
    echo "Kupu Application String Resource Generator"
    echo "Generates and appends localized field labels to string_en.properties"
    echo "based on public getters of a JPA Entity class."
    echo ""
    echo "Usage: $(basename "$0") <module_name> <entity_name>"
    echo ""
    echo "Options:"
    echo "  -h, --help           Display this help message"
    echo ""
    echo "Arguments:"
    echo "  module_name          Name of the target sub-module (lowercase, e.g. 'pelanggan')"
    echo "  entity_name          Name of the Entity class (CamelCase, e.g. 'StatusPelanggan')"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") pelanggan StatusPelanggan"
}

MODULE_NAME=""
ENTITY_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$MODULE_NAME" ]; then MODULE_NAME=$1
            elif [ -z "$ENTITY_NAME" ]; then ENTITY_NAME=$1
            fi
            ;;
    esac
    shift
done

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Error: Both module_name and entity_name are required."
    echo ""
    show_help
    exit 1
fi

PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Define paths
JAVA_FILE="src/main/java/$PKG_PATH/$MODULE_NAME/entity/$ENTITY_NAME.java"
PROP_FILE="src/main/resources/$PKG_PATH/$MODULE_NAME/string_en.properties"

if [ ! -f "$JAVA_FILE" ]; then
    echo "Error: Entity Java class file not found at: $JAVA_FILE"
    exit 1
fi

# Ensure string_en.properties folder and file exist
mkdir -p "$(dirname "$PROP_FILE")"
touch "$PROP_FILE"

ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')

# Extract public getters and process their camelization in Python
python_script=$(cat <<'EOF'
import sys
import re

java_file = sys.argv[1]
entity_camel = sys.argv[2]

try:
    with open(java_file, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    sys.stderr.write(f"Error reading file {java_file}: {e}\n")
    sys.exit(1)

# Remove comments (single line and multi line)
content = re.sub(r'//.*', '', content)
content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

# Regular expression to find public getters (get... or is...) taking no parameters
getter_pattern = re.compile(
    r'\bpublic\s+(?:[a-zA-Z0-9_<>\?\[\]\s,]+)\s+(get|is)([A-Z][a-zA-Z0-9_]*)\s*\(\s*\)'
)

getters = getter_pattern.findall(content)
seen = set()

for prefix, name_cap in getters:
    # Get standard camelCase property name
    if len(name_cap) > 1 and name_cap[0].isupper() and name_cap[1].isupper():
        field_name = name_cap
    else:
        field_name = name_cap[0].lower() + name_cap[1:]
    
    if field_name in seen:
        continue
    seen.add(field_name)
    
    # Key: entityName.fieldName.label
    key = f"{entity_camel}.{field_name}.label"
    
    # Value: Uppercase first letter + split camel case
    val = field_name[0].upper() + field_name[1:]
    val = re.sub(r'(?<=[a-z0-9])([A-Z])', r' \1', val)
    val = re.sub(r'(?<=[A-Z])([A-Z][a-z])', r' \1', val)
    
    print(f"{key}={val}")
EOF
)

tmp_props=$(mktemp)
python3 -c "$python_script" "$JAVA_FILE" "$ENTITY_LOWER_CAMEL" > "$tmp_props"

added_count=0
skipped_count=0

while IFS='=' read -r key value; do
    if [ -z "$key" ]; then
        continue
    fi
    # Check if key already exists in properties file
    if grep -q "^$key=" "$PROP_FILE"; then
        echo "Skipped: $key (already exists)"
        skipped_count=$((skipped_count + 1))
    else
        # Ensure a trailing newline if file is not empty and doesn't end with one
        if [ -s "$PROP_FILE" ] && [ "$(tail -c 1 "$PROP_FILE" | wc -l)" -eq 0 ]; then
            echo "" >> "$PROP_FILE"
        fi
        echo "$key=$value" >> "$PROP_FILE"
        echo "Added: $key=$value"
        added_count=$((added_count + 1))
    fi
done < "$tmp_props"

rm -f "$tmp_props"

echo "Success! Added $added_count resource labels, skipped $skipped_count existing labels."
