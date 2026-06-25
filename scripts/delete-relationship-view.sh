#!/bin/bash

# Kupu Application Relationship Component Deleter
# usage: ./delete-relationship-view.sh <module_name> <relationship_name>

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


# Check for complete removal flag
COMPLETE_REMOVE=false
if [ "$1" == "-c" ]; then
    COMPLETE_REMOVE=true
    shift
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: ./delete-relationship-view.sh [-c] <module_name> <relationship_name> [from_role] [to_role]"
    echo "  -c: Complete removal (try to auto-detect and remove lazy components)"
    echo "Example: ./delete-relationship-view.sh -c santri StudentEnrollment"
    exit 1
fi

MODULE_NAME=$1
RELATIONSHIP_NAME=$2

REL_CAP=$(echo "$RELATIONSHIP_NAME" | sed 's/./\U&/')
REL_LOWER=$(echo "$RELATIONSHIP_NAME" | tr '[:upper:]' '[:lower:]')
REL_UPPER=$(echo "$RELATIONSHIP_NAME" | tr '[:lower:]' '[:upper:]')

PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

# Optional roles for lazy component cleanup (manual override)
FROM_ROLE=$3
TO_ROLE=$4

# Function to delete LazyList and LazyChooser
delete_lazy_components() {
    local ROLE_NAME=$1
    if [ -z "$ROLE_NAME" ]; then return; fi
    
    local ROLE_CAP=$(echo "$ROLE_NAME" | sed 's/./\U&/')
    
    local LAZY_LIST_FILE="$JAVA_DIR/view/list/${ROLE_CAP}LazyList.java"
    local LAZY_CHOOSER_FILE="$JAVA_DIR/view/misc/${ROLE_CAP}LazyChooser.java"

    # Check for usage in other Java files before deleting
    # We look for usage of the LazyChooser in the view directory, excluding the current relationship being deleted.
    # The current relationship files are already deleted by step 1, but let's be safe.
    # Actually, step 1 deletes the relationship files first. So any remaining usage is a real dependency.
    
    if [ -f "$LAZY_CHOOSER_FILE" ]; then
        # Exclude the file itself from the grep to avoid false "still in use" detection
        if grep -r -q "${ROLE_CAP}LazyChooser" "$JAVA_DIR/view"                 --exclude="${ROLE_CAP}LazyChooser.java"                 --exclude="${ROLE_CAP}LazyList.java"; then
            echo "Skipping removal of ${ROLE_CAP}LazyChooser.java (still in use)."
        else
            rm -f "$LAZY_CHOOSER_FILE"
            echo "Removed ${ROLE_CAP}LazyChooser.java"
        fi
    fi

    if [ -f "$LAZY_LIST_FILE" ]; then
        if [ -f "$LAZY_CHOOSER_FILE" ]; then
             echo "Skipping removal of ${ROLE_CAP}LazyList.java (Chooser still exists)."
        elif grep -r -q "${ROLE_CAP}LazyList" "$JAVA_DIR/view"                 --exclude="${ROLE_CAP}LazyList.java"; then
             echo "Skipping removal of ${ROLE_CAP}LazyList.java (still in use)."
        else
            rm -f "$LAZY_LIST_FILE"
            echo "Removed ${ROLE_CAP}LazyList.java"
        fi
    fi
}

echo "Deleting Relationship: $REL_CAP in module $MODULE_NAME..."

# 0. Parsing Entity for Roles if -c flag is used AND manual roles not provided
if [ "$COMPLETE_REMOVE" = true ]; then
    ENTITY_FILE="$JAVA_DIR/entity/${REL_CAP}.java"
    if [ -f "$ENTITY_FILE" ]; then
        echo "Parsing $ENTITY_FILE for complete removal..."
        
        # Extract FromRole type from Builder: public Builder from(Santri from)
        if [ -z "$FROM_ROLE" ]; then
            # Look for: public Builder from(Type name)
            # We want the Type.
            # grep output: public Builder from(Santri from) {
            # awk $3 is from(Santri
            # We can use sed to be more precise.
            FROM_ROLE_EXTRACTED=$(grep "public Builder from(" "$ENTITY_FILE" | sed -E 's/.*public Builder from\(([^ ]+) .*/\1/')
            if [ -n "$FROM_ROLE_EXTRACTED" ]; then
                 FROM_ROLE=$FROM_ROLE_EXTRACTED
                 echo "Detected FromRole: $FROM_ROLE"
            fi
        fi

        # Extract ToRole type from Builder: public Builder to(KelompokPengasuhan to)
        if [ -z "$TO_ROLE" ]; then
            TO_ROLE_EXTRACTED=$(grep "public Builder to(" "$ENTITY_FILE" | sed -E 's/.*public Builder to\(([^ ]+) .*/\1/')
            if [ -n "$TO_ROLE_EXTRACTED" ]; then
                 TO_ROLE=$TO_ROLE_EXTRACTED
                 echo "Detected ToRole: $TO_ROLE"
            fi
        fi
    else
        echo "Warning: Entity file not found at $ENTITY_FILE. Cannot auto-detect roles."
    fi
fi

# 1. Remove Java Files
rm -f "$JAVA_DIR/entity/${REL_CAP}.java"
rm -f "$JAVA_DIR/dao/${REL_CAP}Facade.java"
rm -f "$JAVA_DIR/view/filter/${REL_CAP}Filter.java"
rm -f "$JAVA_DIR/view/list/${REL_CAP}List.java"
rm -f "$JAVA_DIR/view/${REL_CAP}Page.java"
rm -f "$JAVA_DIR/view/admin/${REL_CAP}EditorPage.java"
rm -f "$JAVA_DIR/view/converter/${REL_CAP}Converter.java"
# ListConverter might not have been created if not in create script, but remove just in case
rm -f "$JAVA_DIR/view/converter/${REL_CAP}ListConverter.java"

# 1.1 Remove Lazy Components if roles identified (via args or auto-detect)
if [ -n "$FROM_ROLE" ]; then delete_lazy_components "$FROM_ROLE"; fi
if [ -n "$TO_ROLE" ]; then delete_lazy_components "$TO_ROLE"; fi

# 1.2 Remove misc and list directories if empty
if [ -d "$JAVA_DIR/view/misc" ]; then
    if [ -z "$(ls -A "$JAVA_DIR/view/misc")" ]; then
        rmdir "$JAVA_DIR/view/misc"
        echo "Removed empty view/misc directory."
    fi
fi

if [ -d "$JAVA_DIR/view/list" ]; then
    if [ -z "$(ls -A "$JAVA_DIR/view/list")" ]; then
        rmdir "$JAVA_DIR/view/list"
        echo "Removed empty view/list directory."
    fi
fi

echo "Removed Java files."


# 2. Remove XHTML Files
rm -f "$WEB_DIR/view/${REL_LOWER}.xhtml"
rm -f "$WEB_DIR/view/admin/${REL_LOWER}editor.xhtml"

# 2.1 Remove Component XHTML Files
rm -f "$COMP_DIR/list/${REL_LOWER}list.xhtml"
rm -f "$COMP_DIR/filter/${REL_LOWER}-filterui.xhtml"
rm -f "$COMP_DIR/filter/meta/${REL_LOWER}-filterui.xhtml"

echo "Removed XHTML files."

# 3. Remove Menu Entry
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    sed -i "/Navigator\.open('${REL_CAP}',/d" "$MENU_FILE"
    echo "Removed menu entry from $MENU_FILE"
fi

# 4. Remove Navigator Entry
NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_NAME^}Navigator.java"
if [ -f "$NAVIGATOR_FILE" ]; then
    sed -i "/case \"${REL_CAP}\":/d" "$NAVIGATOR_FILE"
    echo "Removed navigator entry from $NAVIGATOR_FILE"
fi

# 5. Remove Module Registration
MODULE_FILE="$JAVA_DIR/${MODULE_NAME^}Module.java"
if [ -f "$MODULE_FILE" ]; then
    # Remove the registration line
    sed -i "/partyRelationshipTypeFacade.createTypeIfNotExist(\"${REL_UPPER}\", \"${REL_CAP}\");/d" "$MODULE_FILE"
    
    # We do NOT remove the injection of PartyRelationshipTypeFacade because other relationships might use it.
    # It's better to leave the injection there.
    echo "Removed relationship type registration from $MODULE_FILE"
fi

# 6. Cleanup i18n properties
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
EN_PROPS_FILE="$RES_DIR/string_en.properties"
ID_PROPS_FILE="$RES_DIR/string_id.properties"

for file in "$EN_PROPS_FILE" "$ID_PROPS_FILE"; do
    if [ -f "$file" ]; then
        echo "Cleaning up i18n properties in $file"
        sed -i "/^${REL_LOWER}\./d" "$file"
    fi
done

echo "Relationship ${REL_CAP} deleted successfully." 
