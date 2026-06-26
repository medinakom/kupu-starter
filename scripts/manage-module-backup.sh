#!/bin/bash
# Kupu Module Backup and Restore Tool
# Backs up a sub-module to a ZIP file and supports restoring with optional package renaming.

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

# Ensure zip/unzip are available
if ! command -v zip &>/dev/null || ! command -v unzip &>/dev/null; then
    echo "Error: Both 'zip' and 'unzip' commands must be installed to use this script."
    exit 1
fi

# Print detailed usage help
show_help() {
    echo "Kupu Module Backup and Restore Tool"
    echo "Allows backing up a sub-module into a ZIP file and restoring it (with optional package refactoring)."
    echo ""
    echo "Usage:"
    echo "  $(basename "$0") backup <module_name> [output_zip]"
    echo "  $(basename "$0") restore <zip_file> [target_package_name]"
    echo ""
    echo "Commands:"
    echo "  backup            Backs up all files associated with a sub-module."
    echo "  restore           Restores a sub-module from a ZIP backup."
    echo ""
    echo "Options / Parameters:"
    echo "  module_name       Name of the sub-module to backup (lowercase)."
    echo "  output_zip        Path to the output ZIP file (defaults to '<module_name>-backup-<timestamp>.zip')."
    echo "  zip_file          Path to the backup ZIP file to restore."
    echo "  target_package    Optional package name (e.g. 'org.example.app'). If specified,"
    echo "                    the restored Java/resource package structures and contents"
    echo "                    will be refactored to match this new base package."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") backup pelanggan"
    echo "  $(basename "$0") backup pelanggan backups/pelanggan.zip"
    echo "  $(basename "$0") restore pelanggan.zip"
    echo "  $(basename "$0") restore pelanggan.zip org.example.app"
    exit 0
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    show_help
fi

COMMAND=$1
shift

case $COMMAND in
    backup)
        MODULE_NAME=$1
        OUTPUT_ZIP=$2

        if [ -z "$MODULE_NAME" ]; then
            echo "Error: Missing module name."
            echo "Usage: $(basename "$0") backup <module_name> [output_zip]"
            exit 1
        fi

        PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)
        
        # Verify if any directories for this module exist
        DIR_JAVA="src/main/java/$PKG_PATH/$MODULE_NAME"
        DIR_RES="src/main/resources/$PKG_PATH/$MODULE_NAME"
        DIR_WEB="src/main/webapp/$MODULE_NAME"
        DIR_COMP="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

        MODULE_EXISTS=false
        for d in "$DIR_JAVA" "$DIR_RES" "$DIR_WEB" "$DIR_COMP"; do
            if [ -d "$d" ]; then
                MODULE_EXISTS=true
                break
            fi
        done

        if [ "$MODULE_EXISTS" = false ]; then
            echo "Error: Sub-module '$MODULE_NAME' not found in this project."
            exit 1
        fi

        # Default ZIP name if not specified
        if [ -z "$OUTPUT_ZIP" ]; then
            TIMESTAMP=$(date +%Y%m%d%H%M%S)
            OUTPUT_ZIP="${MODULE_NAME}-backup-${TIMESTAMP}.zip"
        fi

        echo "Backing up sub-module '$MODULE_NAME' from package '$APP_PACKAGE'..."

        # Create temporary metadata file
        echo "MODULE_NAME=\"$MODULE_NAME\"" > .backup-metadata
        echo "BASE_PACKAGE=\"$APP_PACKAGE\"" >> .backup-metadata

        # Build list of existing directories/files to zip
        FILES_TO_ZIP=(".backup-metadata")
        [ -d "$DIR_JAVA" ] && FILES_TO_ZIP+=("$DIR_JAVA")
        [ -d "$DIR_RES" ] && FILES_TO_ZIP+=("$DIR_RES")
        [ -d "$DIR_WEB" ] && FILES_TO_ZIP+=("$DIR_WEB")
        [ -d "$DIR_COMP" ] && FILES_TO_ZIP+=("$DIR_COMP")

        # Perform ZIP
        zip -q -r "$OUTPUT_ZIP" "${FILES_TO_ZIP[@]}"
        
        # Cleanup metadata from project root
        rm -f .backup-metadata

        echo "Backup successfully created: $OUTPUT_ZIP"
        ;;

    restore)
        ZIP_FILE=$1
        NEW_BASE_PACKAGE=$2

        if [ -z "$ZIP_FILE" ]; then
            echo "Error: Missing backup ZIP file path."
            echo "Usage: $(basename "$0") restore <zip_file> [target_package_name]"
            exit 1
        fi

        if [ ! -f "$ZIP_FILE" ]; then
            echo "Error: Backup file '$ZIP_FILE' not found."
            exit 1
        fi

        # If target package is NOT specified: just extract directly
        if [ -z "$NEW_BASE_PACKAGE" ]; then
            echo "Restoring sub-module directly from backup (no package refactoring)..."
            unzip -o "$ZIP_FILE"
            rm -f .backup-metadata
            echo "Restore completed successfully."
            exit 0
        fi

        # If target package IS specified: extract, rename package structures & references
        echo "Restoring sub-module and refactoring to package '$NEW_BASE_PACKAGE'..."

        # Create temporary extraction directory
        TEMP_DIR="tmp-restore-$(date +%s)"
        mkdir -p "$TEMP_DIR"

        # Unzip into temp directory
        unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

        # Read metadata
        if [ ! -f "$TEMP_DIR/.backup-metadata" ]; then
            echo "Error: Backup file is missing Kupu backup metadata. Cannot refactor package name safely."
            rm -rf "$TEMP_DIR"
            exit 1
        fi

        source "$TEMP_DIR/.backup-metadata"
        OLD_MODULE_NAME=$MODULE_NAME
        OLD_BASE_PACKAGE=$BASE_PACKAGE
        OLD_PKG_PATH=$(echo "$OLD_BASE_PACKAGE" | tr . /)
        NEW_PKG_PATH=$(echo "$NEW_BASE_PACKAGE" | tr . /)

        # Remove metadata file so it isn't copied/refactored
        rm -f "$TEMP_DIR/.backup-metadata"

        # Refactor contents of all files
        echo "Refactoring package references from '$OLD_BASE_PACKAGE' to '$NEW_BASE_PACKAGE'..."
        find "$TEMP_DIR" -type f | while read -r file; do
            # Replace old package names with new package names
            sed -i "s/$OLD_BASE_PACKAGE/$NEW_BASE_PACKAGE/g" "$file"
        done

        # Move and copy directories to their target locations
        echo "Copying refactored files to project directories..."
        
        # 1. Java files
        if [ -d "$TEMP_DIR/src/main/java/$OLD_PKG_PATH/$OLD_MODULE_NAME" ]; then
            mkdir -p "src/main/java/$NEW_PKG_PATH"
            cp -r "$TEMP_DIR/src/main/java/$OLD_PKG_PATH/$OLD_MODULE_NAME" "src/main/java/$NEW_PKG_PATH/"
            echo "  - Restored Java files to: src/main/java/$NEW_PKG_PATH/$OLD_MODULE_NAME"
        fi

        # 2. Resources files
        if [ -d "$TEMP_DIR/src/main/resources/$OLD_PKG_PATH/$OLD_MODULE_NAME" ]; then
            mkdir -p "src/main/resources/$NEW_PKG_PATH"
            cp -r "$TEMP_DIR/src/main/resources/$OLD_PKG_PATH/$OLD_MODULE_NAME" "src/main/resources/$NEW_PKG_PATH/"
            echo "  - Restored Resource files to: src/main/resources/$NEW_PKG_PATH/$OLD_MODULE_NAME"
        fi

        # 3. Web views
        if [ -d "$TEMP_DIR/src/main/webapp/$OLD_MODULE_NAME" ]; then
            mkdir -p "src/main/webapp"
            cp -r "$TEMP_DIR/src/main/webapp/$OLD_MODULE_NAME" "src/main/webapp/"
            echo "  - Restored Web files to: src/main/webapp/$OLD_MODULE_NAME"
        fi

        # 4. Web components
        if [ -d "$TEMP_DIR/src/main/webapp/WEB-INF/resources/$OLD_MODULE_NAME" ]; then
            mkdir -p "src/main/webapp/WEB-INF/resources"
            cp -r "$TEMP_DIR/src/main/webapp/WEB-INF/resources/$OLD_MODULE_NAME" "src/main/webapp/WEB-INF/resources/"
            echo "  - Restored Web Component files to: src/main/webapp/WEB-INF/resources/$OLD_MODULE_NAME"
        fi

        # Cleanup
        rm -rf "$TEMP_DIR"
        echo "Restore and refactoring completed successfully."
        ;;

    *)
        echo "Error: Unknown command '$COMMAND'."
        show_help
        exit 1
        ;;
esac
