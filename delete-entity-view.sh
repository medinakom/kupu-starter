#!/bin/bash

# Kupu Web Entity View Deletion Script
# Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]

MODULE_NAME=$1
ENTITY_NAME=$2
FORCE=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Usage: ./delete-entity-view.sh <sub_module_name> <entity_name> [--force]"
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER=$(echo "$ENTITY_NAME" | sed 's/./\L&/')

# Paths for kupu-web
MODULE_ROOT="."
JAVA_DIR="$MODULE_ROOT/src/main/java/id/my/mdn/kupu/app/$MODULE_NAME"
VIEW_BASE_DIR="$MODULE_ROOT/src/main/webapp/app/$MODULE_NAME"

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
    echo "Deleting files for $ENTITY_NAME in web module $MODULE_NAME..."
    for f in "${FILES[@]}"; do [ -f "$f" ] && echo "  - $f"; done
    read -p "Continue? (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" ]] && exit 0
fi

for f in "${FILES[@]}"; do
    [ -f "$f" ] && rm "$f" && echo "Deleted: $f"
done
