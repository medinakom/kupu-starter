#!/bin/bash

# Kupu Application Module Generator
# usage: ./create-module.sh <module_name> [table_prefix]

# 1. Load configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/.generator-config"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Kupu Application Module Generator"
    echo "Usage: $(basename "$0") [module_name] [table_prefix]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Display this help message"
    echo ""
    echo "Arguments:"
    echo "  module_name   Name of the module (lowercase). If omitted, the script will prompt for it."
    echo "  table_prefix  Database table prefix. If omitted, defaults to uppercase of module_name."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") inventory        # Create 'inventory' module with table prefix 'INVENTORY'"
    echo "  $(basename "$0") accounting ACT   # Create 'accounting' module with table prefix 'ACT'"
    echo "  $(basename "$0")                  # Prompt for module name and details interactively"
    exit 0
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: .generator-config not found at $CONFIG_FILE. Are you in a Kupu application directory?"
    exit 1
fi

BASE_PACKAGE=$(cat "$CONFIG_FILE" | head -1)

cd "$PROJECT_ROOT"

MODULE_NAME=$1
if [ -z "$MODULE_NAME" ]; then
    read -p "Enter module name (lowercase): " MODULE_NAME
fi

read -p "Enter module display title: " MODULE_TITLE

# Determine display order
MAX_ORDER=0
while IFS= read -r file; do
    if grep -q "protected int getOrder()" "$file"; then
        METHOD_BODY=$(grep -A 2 "protected int getOrder()" "$file")
        ORDER=$(echo "$METHOD_BODY" | grep "return" | grep -oE '[0-9]+' | head -1)
        if [ -n "$ORDER" ] && [ "$ORDER" -gt "$MAX_ORDER" ]; then
            MAX_ORDER=$ORDER
        fi
    fi
done < <(find src/main/java -name "*Module.java" 2>/dev/null)

NEXT_ORDER=$((MAX_ORDER + 10))
if [ "$MAX_ORDER" -eq "0" ]; then NEXT_ORDER=10; fi
read -p "Enter module display order [$NEXT_ORDER]: " MODULE_ORDER
MODULE_ORDER=${MODULE_ORDER:-$NEXT_ORDER}

# Table prefix
TABLE_PREFIX=$2
if [ -z "$TABLE_PREFIX" ]; then
    TABLE_PREFIX=$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')
    echo "Using auto-generated table prefix: $TABLE_PREFIX"
fi

MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/.*/\L&/; s/./\U&/')
PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Define paths
FULL_PKG="$BASE_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

echo "Creating directory structure for module: $MODULE_NAME..."
mkdir -p "$JAVA_DIR"/{entity,dao,view/admin,view/converter,view/event,view/filter,view/list,service,api,event}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR"/view/admin
mkdir -p "$COMP_DIR"/{list,filter}

# Generate Java Files
cat <<EOF > "$JAVA_DIR/${MODULE_CAP}Module.java"
package $FULL_PKG;

import id.my.mdn.kupu.core.base.AbstractModule;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class ${MODULE_CAP}Module extends AbstractModule {
    @Override protected String getLabel() { return "$MODULE_NAME.module.title"; }
    @Override protected int getOrder() { return $MODULE_ORDER; }
    @Override protected void postInit() {}
}
EOF

cat <<EOF > "$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
package $FULL_PKG.view;

import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.widget.PageNavigator;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;
import java.io.Serializable;

@Named
@ApplicationScoped
public class ${MODULE_CAP}Navigator extends PageNavigator implements Serializable {
    @Override
    protected Class<? extends Page> pageMap(String pageId) {
        switch(pageId) {            
            default: return null;
        }
    }
}
EOF

# Config files
echo "{\"acls\": [], \"groups\": [], \"users\": []}" > "$RES_DIR/security.json"
echo "TABLE_PREFIX=$TABLE_PREFIX" > "$RES_DIR/.generator-config"
echo "{}" > "$RES_DIR/template.json"
echo "$MODULE_NAME.module.title=$MODULE_TITLE" > "$RES_DIR/string_en.properties"
echo "$MODULE_NAME.module.title=$MODULE_TITLE" > "$RES_DIR/string_id.properties"

# Menu component
cat <<EOF > "$COMP_DIR/module-menu.xhtml"
<ui:composition xmlns:ui="jakarta.faces.facelets" xmlns:p="primefaces">
</ui:composition>
EOF

# Index page
# Index page
cat <<EOF > "$WEB_DIR/index.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                template="/WEB-INF/templates/page.xhtml">

    <f:metadata>
        <ui:param name="title" value="$MODULE_TITLE Home" />
        <ui:param name="notool" value="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/resources/$MODULE_NAME/module-menu.xhtml" />
    </ui:define>

    <ui:define name="content">
        
    </ui:define>

</ui:composition>
EOF

chmod +x "$0"
echo "Module '$MODULE_NAME' created successfully in $BASE_PACKAGE."
