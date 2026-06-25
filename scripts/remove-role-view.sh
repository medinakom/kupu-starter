#!/bin/bash

# Kupu Application Role Component Remover
# usage: ./remove-role-view.sh <module_name> <role_name>

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
ROLE_NAME=$2

if [ -z "$MODULE_NAME" ] || [ -z "$ROLE_NAME" ]; then
    echo "Usage: ./remove-role-view.sh <module_name> <role_name>"
    exit 1
fi

ROLE_CAP=$(echo "$ROLE_NAME" | sed 's/./\U&/')
ROLE_LOWER=$(echo "$ROLE_NAME" | sed 's/./\L&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

echo "Removing components for role: $ROLE_NAME in module: $MODULE_NAME..."

# 1. Delete Java Files
rm -f "$JAVA_DIR/entity/${ROLE_CAP}.java"
rm -f "$JAVA_DIR/dao/${ROLE_CAP}Facade.java"
rm -f "$JAVA_DIR/view/list/${ROLE_CAP}List.java"
rm -f "$JAVA_DIR/view/admin/${ROLE_CAP}Page.java"

# 2. Delete XHTML Files
rm -f "$WEB_DIR/view/admin/${ROLE_LOWER}.xhtml"
rm -f "$COMP_DIR/list/${ROLE_LOWER}list.xhtml"
rm -f "$COMP_DIR/editor/${ROLE_LOWER}editor.xhtml"
rm -f "$COMP_DIR/detail/${ROLE_LOWER}detail.xhtml"

# 3. Clean Navigator.java
NAVIGATOR_FILE="$JAVA_DIR/view/${ROLE_CAP}Navigator.java"
if [ ! -f "$NAVIGATOR_FILE" ]; then
    # Try generic navigator name if role-specific doesn't exist (though create-role creates it)
    MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
    NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
fi

if [ -f "$NAVIGATOR_FILE" ]; then
    # Remove the case line for this role
    sed -i "/case \"${ROLE_CAP}\":/d" "$NAVIGATOR_FILE"
    echo "Cleaned $NAVIGATOR_FILE"
fi

# 4. Clean module-menu.xhtml
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    # Remove the specific line containing the role value
    sed -i "/value=\"${ROLE_CAP}\"/d" "$MENU_FILE"
    echo "Cleaned $MENU_FILE"
fi

# 5. Cleanup empty directories
find "$JAVA_DIR" -type d -empty -delete
find "$WEB_DIR" -type d -empty -delete
find "$COMP_DIR" -type d -empty -delete

chmod +x "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
echo "Role '$ROLE_NAME' components removed completely."
