#!/bin/bash

# Kupu Module Deletion Script
# WARNING: This script permanently deletes module files and database tables

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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
    echo "Usage: ./delete-module.sh <module_name> [--dry-run] [--force]"
    echo "Example: ./delete-module.sh inventory --dry-run"
    exit 1
fi

# Define paths
JAVA_DIR="kupu-web/src/main/java/id/my/mdn/kupu/app/$MODULE_NAME"
RES_DIR="kupu-web/src/main/resources/id/my/mdn/kupu/app/$MODULE_NAME"
WEB_DIR="kupu-web/src/main/webapp/app/$MODULE_NAME"
COMP_DIR="kupu-web/src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

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

# Database cleanup instructions (DISABLED FOR NOW)
# if [ -n "$TABLE_PREFIX" ]; then
#     echo -e "${YELLOW}========================================${NC}"
#     echo -e "${YELLOW}Database Cleanup Required${NC}"
#     echo -e "${YELLOW}========================================${NC}"
#     echo ""
#     echo "To drop database tables, connect to your database and run:"
#     echo ""
#     echo -e "${YELLOW}-- List tables with prefix${NC}"
#     echo "SHOW TABLES LIKE '${TABLE_PREFIX}_%';"
#     echo ""
#     echo -e "${YELLOW}-- Drop tables (review list first!)${NC}"
#     echo "-- DROP TABLE ${TABLE_PREFIX}_PRODUCT;"
#     echo "-- DROP TABLE ${TABLE_PREFIX}_ORDER;"
#     echo "-- etc."
#     echo ""
#     echo -e "${YELLOW}-- Clean up KEYGEN entries${NC}"
#     echo "DELETE FROM KEYGEN WHERE SEQUENCE_NAME LIKE '${TABLE_PREFIX}_%';"
#     echo ""
# fi

echo -e "${GREEN}Done!${NC}"
