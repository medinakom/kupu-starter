#!/bin/bash

# Kupu Application Entity View Deletion Script
# Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]

# 1. Load configuration
if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found."
    exit 1
fi

MODULE_NAME=$1
ENTITY_NAME=$2
FORCE=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]"
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

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
    "$JAVA_DIR/view/list/${ENTITY_CAP}List.java"
    # Main XHTML pages
    "$VIEW_BASE_DIR/view/${ENTITY_FILE_BASE}.xhtml"
    "$VIEW_BASE_DIR/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
    # Component XHTML files
    "$COMP_DIR/list/${ENTITY_FILE_BASE}list.xhtml"
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
