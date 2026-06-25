#!/bin/bash

# Kupu Application Entity View Deletion Script
# Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]

# 1. Load configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/.generator-config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: .generator-config not found at $CONFIG_FILE. Are you in a Kupu application directory?"
    exit 1
fi

APP_PACKAGE=$(cat "$CONFIG_FILE" | head -1)

cd "$PROJECT_ROOT"

MODULE_NAME=$1
ENTITY_NAME=$2
FORCE=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]"
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LABEL=$(echo "${ENTITY_CAP}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')
ENTITY_LOWER=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

# Detect hierarchical entity (same logic as create-entity-view.sh)
LIST_SUFFIX="List"
ENTITY_FILE=$(find src/main/java -name "${ENTITY_CAP}.java" | head -n 1)
if [ -n "$ENTITY_FILE" ] && grep -q "HierarchicalEntity" "$ENTITY_FILE"; then
    LIST_SUFFIX="Tree"
    echo "Auto-detected HierarchicalEntity — using '${LIST_SUFFIX}' suffix."
fi

FILES=(
    # Entity file
    "$JAVA_DIR/entity/${ENTITY_CAP}.java"
    # Java files
    "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
    "$JAVA_DIR/view/${ENTITY_CAP}Page.java"
    "$JAVA_DIR/view/admin/${ENTITY_CAP}EditorPage.java"
    "$JAVA_DIR/view/filter/${ENTITY_CAP}Filter.java"
    "$JAVA_DIR/view/converter/${ENTITY_CAP}Converter.java"
    "$JAVA_DIR/view/converter/${ENTITY_CAP}ListConverter.java"
    "$JAVA_DIR/view/list/${ENTITY_CAP}${LIST_SUFFIX}.java"
    # Main XHTML pages
    "$VIEW_BASE_DIR/view/${ENTITY_FILE_BASE}.xhtml"
    "$VIEW_BASE_DIR/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
    # Component XHTML files
    "$COMP_DIR/list/${ENTITY_FILE_BASE}$(echo "$LIST_SUFFIX" | tr '[:upper:]' '[:lower:]').xhtml"
    "$COMP_DIR/filter/${ENTITY_FILE_BASE}-filterui.xhtml"
    "$COMP_DIR/filter/meta/${ENTITY_FILE_BASE}-filterui.xhtml"
)

if [ "$FORCE" != "--force" ]; then
    echo "Deleting files for $ENTITY_NAME in module $MODULE_NAME..."
    for f in "${FILES[@]}"; do [ -f "$f" ] && echo "  - $f"; done
    read -p "Continue? (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" ]] && exit 0
fi

for f in "${FILES[@]}"; do
    [ -f "$f" ] && rm "$f" && echo "Deleted: $f"
done

# Remove from Navigator
NAVIGATOR_FILE="$JAVA_DIR/view/${ENTITY_CAP}Navigator.java"
if [ ! -f "$NAVIGATOR_FILE" ]; then
    MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
    NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
fi

if [ -f "$NAVIGATOR_FILE" ]; then
    if grep -q "case \"${ENTITY_LABEL}\":" "$NAVIGATOR_FILE"; then
        sed -i "/case \"${ENTITY_LABEL}\":/d" "$NAVIGATOR_FILE"
        echo "Removed ${ENTITY_LABEL} from $NAVIGATOR_FILE"
    fi
    if grep -q "case \"${ENTITY_CAP}\":" "$NAVIGATOR_FILE"; then
        sed -i "/case \"${ENTITY_CAP}\":/d" "$NAVIGATOR_FILE"
        echo "Removed ${ENTITY_CAP} from $NAVIGATOR_FILE"
    fi
    # Clean up double blank lines that might have been left behind
    sed -i '/^$/N;/^\n$/D' "$NAVIGATOR_FILE"
fi

# Remove from Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if grep -q "value=\"${ENTITY_LABEL}\"" "$MENU_FILE"; then
        sed -i "/value=\"${ENTITY_LABEL}\"/d" "$MENU_FILE"
        echo "Removed ${ENTITY_LABEL} from $MENU_FILE"
    fi
    if grep -q "value=\"${ENTITY_CAP}\"" "$MENU_FILE"; then
        sed -i "/value=\"${ENTITY_CAP}\"/d" "$MENU_FILE"
        echo "Removed ${ENTITY_CAP} from $MENU_FILE"
    fi
fi

# Clean up ACL entries from security.json
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
SEC_FILE="$RES_DIR/security.json"

if [ -f "$SEC_FILE" ]; then
    ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
    
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys

file_path = sys.argv[1]
entity_lower = sys.argv[2]
module_name = sys.argv[3]

with open(file_path, 'r') as f:
    data = json.load(f)

if 'acls' in data:
    # Remove ACLs matching the pattern: module.entity.{create,update,delete}
    original_count = len(data['acls'])
    data['acls'] = [
        item for item in data['acls']
        if not (item.get('acl', {}).get('name', '').startswith(f'{module_name}.{entity_lower}.'))
    ]
    removed_count = original_count - len(data['acls'])
    
    if removed_count > 0:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=4)
        print(f'Removed {removed_count} ACL entries from security.json')
" "$SEC_FILE" "$ENTITY_LOWER_CAMEL" "$MODULE_NAME"
    else
        echo "Warning: python3 not found. ACL entries in security.json were not cleaned up."
        echo "Please manually remove ACL entries for: $MODULE_NAME.$ENTITY_LOWER_CAMEL.*"
    fi
fi

# Remove entity entries from i18n properties files
PROPS_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
for PROPS_FILE in "$PROPS_DIR/string_en.properties" "$PROPS_DIR/string_id.properties"; do
    if [ -f "$PROPS_FILE" ]; then
        BEFORE=$(grep -c "^${ENTITY_LOWER}\." "$PROPS_FILE" 2>/dev/null || echo 0)
        if [ "$BEFORE" -gt 0 ]; then
            sed -i "/^${ENTITY_LOWER}\./d" "$PROPS_FILE"
            echo "Removed $BEFORE entries with prefix '${ENTITY_LOWER}.' from $PROPS_FILE"
        fi
    fi
done
