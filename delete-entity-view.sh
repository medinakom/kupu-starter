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
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp/app/$MODULE_NAME"

FILES=(
    "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
    "$JAVA_DIR/view/filter/${ENTITY_CAP}Filter.java"
    "$JAVA_DIR/view/converter/${ENTITY_CAP}Converter.java"
    "$JAVA_DIR/view/converter/${ENTITY_CAP}ListConverter.java"
    "$JAVA_DIR/view/list/${ENTITY_CAP}List.java"
    "$JAVA_DIR/view/admin/${ENTITY_CAP}Page.java"
    "$VIEW_BASE_DIR/view/admin/${ENTITY_LOWER}.xhtml"
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
