#!/bin/bash

# Kupu Application Module Deletion Script
# WARNING: This script permanently deletes module files and database tables

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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

# Help flag check
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Kupu Application Module Deletion Script"
    echo "Usage: $(basename "$0") <module_name> [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Display this help message"
    echo "  --dry-run     Show files that would be deleted without deleting them"
    echo "  --force       Skip the confirmation prompt"
    echo ""
    echo "Arguments:"
    echo "  module_name   Name of the module to delete (lowercase)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") inventory           # Prompt and delete the 'inventory' module"
    echo "  $(basename "$0") inventory --dry-run # Show what would be deleted for 'inventory'"
    echo "  $(basename "$0") inventory --force   # Delete 'inventory' module without prompting"
    exit 0
fi

# Parse arguments
MODULE_NAME=$1
DRY_RUN=false
FORCE=false

if [ "$2" == "--dry-run" ] || [ "$3" == "--dry-run" ]; then
    DRY_RUN=true
fi

if [ "$2" == "--force" ] || [ "$3" == "--force" ]; then
    FORCE=true
fi

if [ -z "$MODULE_NAME" ]; then
    echo "Usage: $(basename "$0") <module_name> [--dry-run] [--force]"
    echo "Run '$(basename "$0") --help' for details and examples."
    exit 1
fi

PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

# Check if module exists
if [ ! -d "$JAVA_DIR" ]; then
    echo -e "${RED}Error: Module '$MODULE_NAME' not found!${NC}"
    exit 1
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Module Deletion Tool${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Read table prefix from config
TABLE_PREFIX=""
CONFIG_FILE="$RES_DIR/.generator-config"
if [ -f "$CONFIG_FILE" ]; then
    TABLE_PREFIX=$(grep "^TABLE_PREFIX=" "$CONFIG_FILE" | cut -d'=' -f2)
fi

# List files to be deleted
echo -e "${YELLOW}Files to be deleted:${NC}"
echo "  - $JAVA_DIR"
echo "  - $RES_DIR"
echo "  - $WEB_DIR"
echo "  - $COMP_DIR"
echo ""

# List database tables
if [ -n "$TABLE_PREFIX" ]; then
    echo -e "${YELLOW}Database tables with prefix '$TABLE_PREFIX':${NC}"
    echo "  Note: Tables matching pattern '${TABLE_PREFIX}_*' will be identified"
    echo "  You will need to manually drop these tables or provide DB credentials"
    echo ""
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}DRY RUN MODE - No changes will be made${NC}"
    exit 0
fi

# Confirmation
if [ "$FORCE" = false ]; then
    echo -e "${RED}WARNING: This action cannot be undone!${NC}"
    echo -e "${YELLOW}Please type the module name '$MODULE_NAME' to confirm deletion:${NC}"
    read -p "> " CONFIRMATION
    
    if [ "$CONFIRMATION" != "$MODULE_NAME" ]; then
        echo -e "${RED}Confirmation failed. Aborting.${NC}"
        exit 1
    fi
fi

# Delete files
echo ""
echo -e "${YELLOW}Deleting module files...${NC}"

if [ -d "$JAVA_DIR" ]; then
    rm -rf "$JAVA_DIR"
    echo -e "${GREEN}✓ Deleted $JAVA_DIR${NC}"
fi

if [ -d "$RES_DIR" ]; then
    rm -rf "$RES_DIR"
    echo -e "${GREEN}✓ Deleted $RES_DIR${NC}"
fi

if [ -d "$WEB_DIR" ]; then
    rm -rf "$WEB_DIR"
    echo -e "${GREEN}✓ Deleted $WEB_DIR${NC}"
fi

if [ -d "$COMP_DIR" ]; then
    rm -rf "$COMP_DIR"
    echo -e "${GREEN}✓ Deleted $COMP_DIR${NC}"
fi

echo ""
echo -e "${GREEN}Module '$MODULE_NAME' files deleted successfully!${NC}"
echo ""

echo -e "${GREEN}Done!${NC}"
