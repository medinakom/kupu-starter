#!/bin/bash

# Kupu Application Entity with Editor View Deletion Script
# Usage: ./delete-entity-with-editor.sh <module_name> <entity_name> [--force]

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

MODULE_NAME=""
ENTITY_NAME=""
FORCE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --force) FORCE=true ;;
        -h|--help)
            echo "Kupu Application Entity & Editor View Deletion Script"
            echo "Deletes a generated JPA Entity, Facade, Converter, conversation-scoped EditorPage,"
            echo "and XHTML editor view, and cleans up the properties files."
            echo ""
            echo "Usage: $(basename "$0") <module_name> <entity_name> [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help           Display this help message"
            echo "  --force              Force deletion without asking for confirmation"
            echo ""
            echo "Arguments:"
            echo "  module_name          Name of the target sub-module (lowercase, e.g. 'pelanggan')"
            echo "  entity_name          Name of the Entity class to delete (CamelCase, e.g. 'StatusPelanggan')"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") pelanggan StatusPelanggan"
            echo "  $(basename "$0") pelanggan StatusPelanggan --force"
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
    echo "Usage: $(basename "$0") <module_name> <entity_name> [options]"
    echo "Run '$(basename "$0") --help' for details and examples."
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"

FILES=(
    "$JAVA_DIR/entity/${ENTITY_CAP}.java"
    "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
    "$JAVA_DIR/view/converter/${ENTITY_CAP}Converter.java"
    "$JAVA_DIR/view/admin/${ENTITY_CAP}EditorPage.java"
    "$WEB_DIR/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
)

if [ "$FORCE" = false ]; then
    echo "Deleting files for $ENTITY_NAME in module $MODULE_NAME..."
    for f in "${FILES[@]}"; do [ -f "$f" ] && echo "  - $f"; done
    read -p "Continue? (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" ]] && exit 0
fi

for f in "${FILES[@]}"; do
    [ -f "$f" ] && rm "$f" && echo "Deleted: $f"
done

# Remove entity entries from i18n properties files
for PROPS_FILE in "$RES_DIR/string_en.properties" "$RES_DIR/string_id.properties"; do
    if [ -f "$PROPS_FILE" ]; then
        BEFORE=$(grep -c "^${ENTITY_LOWER_CAMEL}\." "$PROPS_FILE" 2>/dev/null || echo 0)
        if [ "$BEFORE" -gt 0 ]; then
            sed -i "/^${ENTITY_LOWER_CAMEL}\./d" "$PROPS_FILE"
            echo "Removed $BEFORE entries with prefix '${ENTITY_LOWER_CAMEL}.' from $PROPS_FILE"
        fi
    fi
done

# Cleanup Empty Directories
rmdir "$JAVA_DIR/entity" 2>/dev/null
rmdir "$JAVA_DIR/dao" 2>/dev/null
rmdir "$JAVA_DIR/view/converter" 2>/dev/null
rmdir "$JAVA_DIR/view/admin" 2>/dev/null
rmdir "$JAVA_DIR/view" 2>/dev/null
rmdir "$JAVA_DIR" 2>/dev/null
rmdir "$WEB_DIR/view/admin" 2>/dev/null
rmdir "$WEB_DIR/view" 2>/dev/null
rmdir "$WEB_DIR" 2>/dev/null

# Run generate-persistence.sh
if [ -f "$SCRIPT_DIR/generate-persistence.sh" ]; then
    echo "Running generate-persistence.sh to update persistence context..."
    "$SCRIPT_DIR/generate-persistence.sh"
else
    echo "Warning: generate-persistence.sh not found at $SCRIPT_DIR/generate-persistence.sh"
fi

echo "Entity '$ENTITY_NAME' deletion complete."
