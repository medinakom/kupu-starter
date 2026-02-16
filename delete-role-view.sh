#!/bin/bash

# Kupu Application Role Deletion Script
# Usage: ./delete-role-view.sh <module_name> <role_name> [--force]

# 1. Load configuration
if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found."
    exit 1
fi

MODULE_NAME=$1
ROLE_NAME=$2
FORCE=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ROLE_NAME" ]; then
    echo "Usage: ./delete-role-view.sh <module_name> <role_name> [--force]"
    exit 1
fi

ROLE_CAP=$(echo "$ROLE_NAME" | sed 's/./\U&/')
ROLE_LOWER=$(echo "$ROLE_NAME" | sed 's/./\L&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)
MODULE_BEAN=$(echo "$MODULE_NAME" | sed 's/./\L&/')

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/app/$MODULE_NAME"

FILES=(
    # Java files
    "$JAVA_DIR/entity/${ROLE_CAP}.java"
    "$JAVA_DIR/dao/${ROLE_CAP}Facade.java"
    "$JAVA_DIR/view/${ROLE_CAP}Page.java"
    "$JAVA_DIR/view/admin/${ROLE_CAP}EditorPage.java"
    "$JAVA_DIR/view/filter/${ROLE_CAP}Filter.java"
    "$JAVA_DIR/view/converter/${ROLE_CAP}Converter.java"
    "$JAVA_DIR/view/converter/${ROLE_CAP}ListConverter.java"
    "$JAVA_DIR/view/list/${ROLE_CAP}List.java"
    # Web files
    "$WEB_DIR/view/${ROLE_LOWER}.xhtml"
    "$WEB_DIR/view/admin/${ROLE_LOWER}editor.xhtml"
    # Component files
    "$COMP_DIR/list/${ROLE_LOWER}list.xhtml"
    "$COMP_DIR/editor/${ROLE_LOWER}editor.xhtml"
    "$COMP_DIR/detail/${ROLE_LOWER}detail.xhtml"
    "$COMP_DIR/filter/${ROLE_LOWER}-filterui.xhtml"
    "$COMP_DIR/filter/meta/${ROLE_LOWER}-filterui.xhtml"
)

if [ "$FORCE" != "--force" ]; then
    echo "Deleting files for Role $ROLE_NAME in module $MODULE_NAME..."
    for f in "${FILES[@]}"; do [ -f "$f" ] && echo "  - $f"; done
    read -p "Continue? (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" ]] && exit 0
fi

# 1. Delete Files
for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        rm "$f"
        echo "Deleted: $f"
    fi
done

# 2. Cleanup Navigator (using Perl for multi-line regex)
NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
# Try to find Navigator if standard naming fails
if [ ! -f "$NAVIGATOR_FILE" ]; then
    MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
    NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
fi

if [ -f "$NAVIGATOR_FILE" ]; then
    echo "Cleaning up Navigator: $NAVIGATOR_FILE"
    # Perl regex to match case block: case "Role": ... return ...;
    # Handles multi-line formatting and cleans up surrounding whitespace
    perl -i -0777 -pe "s/\s*case\s+\"${ROLE_CAP}\"\s*:[\s\S]*?return\s+[\w\.]*${ROLE_CAP}Page\.class\s*;//g" "$NAVIGATOR_FILE"
    
    # Clean up potentially created double blank lines
    perl -i -0777 -pe "s/\n\s*\n(\s*\n)+/\n\n/g" "$NAVIGATOR_FILE"
fi

# 3. Cleanup Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    echo "Cleaning up Menu: $MENU_FILE"
    # Remove lines containing the actionListener for this role
    sed -i "/actionListener=.*${MODULE_BEAN}Navigator.open('${ROLE_CAP}'/d" "$MENU_FILE"
fi

# 4. Cleanup Security (Python)
SEC_FILE="$RES_DIR/security.json"
if [ -f "$SEC_FILE" ]; then
    echo "Cleaning up Security ACLs..."
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys

file_path = sys.argv[1]
role_lower = sys.argv[2]
module_name = sys.argv[3]

try:
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    if 'acls' in data:
        original_count = len(data['acls'])
        data['acls'] = [
            item for item in data['acls']
            if not (item.get('acl', {}).get('name', '').startswith(f'{module_name}.{role_lower}.'))
        ]
        
        if len(data['acls']) < original_count:
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=4)
            print(f'Removed {original_count - len(data['acls'])} ACL entries.')
except Exception as e:
    print(f'Error updating security.json: {e}')
" "$SEC_FILE" "$ROLE_LOWER" "$MODULE_NAME"
    fi
fi

echo "Role '$ROLE_NAME' deletion complete."
