#!/bin/bash

# Kupu Application Page Generator
# usage: ./create-page.sh <sub_module_name> <page_name> [custom_xhtml]

# 1. Load configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/.generator-config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: .generator-config not found at $CONFIG_FILE. Are you in a Kupu application directory?"
    exit 1
fi

BASE_PACKAGE=$(cat "$CONFIG_FILE" | head -1)

cd "$PROJECT_ROOT"

MODULE_NAME=""
BASE_NAME=""
CUSTOM_XHTML=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Kupu Application Page Generator"
            echo "Generates a ViewScoped Java page controller and a companion XHTML layout"
            echo ""
            echo "Usage: $(basename "$0") [sub_module_name] [page_name] [custom_xhtml]"
            echo "Note: If sub_module_name or page_name are omitted, you will be prompted interactively."
            echo ""
            echo "Options:"
            echo "  -h, --help           Display this help message"
            echo ""
            echo "Arguments:"
            echo "  sub_module_name      Name of the target sub-module (lowercase, e.g. 'inventory')"
            echo "  page_name            Name of the page to generate (CamelCase, e.g. 'Dashboard')"
            echo "  custom_xhtml         Optional custom file name for the XHTML view (lowercase)"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") inventory Dashboard"
            echo "  $(basename "$0") inventory Dashboard main-dashboard"
            exit 0
            ;;
        *)
            if [ -z "$MODULE_NAME" ]; then MODULE_NAME=$1
            elif [ -z "$BASE_NAME" ]; then BASE_NAME=$1
            elif [ -z "$CUSTOM_XHTML" ]; then CUSTOM_XHTML=$1
            fi
            ;;
    esac
    shift
done

if [ -z "$MODULE_NAME" ]; then read -p "Enter sub-module name: " MODULE_NAME; fi
if [ -z "$BASE_NAME" ]; then read -p "Enter base page name (CamelCase): " BASE_NAME; fi
PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp"
FULL_PKG="$BASE_PACKAGE.$MODULE_NAME"
VIEW_NS_PATH="/$MODULE_NAME"

if [ ! -d "$JAVA_DIR" ]; then
    echo "Error: Sub-module '$MODULE_NAME' not found in src/main/java/$PKG_PATH/"
    exit 1
fi

PAGE_CAP=$(echo "$BASE_NAME" | sed 's/./\U&/')
PAGE_CLASS_NAME="${PAGE_CAP}Page"
XHTML_NAME=$(echo "${CUSTOM_XHTML:-$BASE_NAME}" | tr '[:upper:]' '[:lower:]')

mkdir -p "$JAVA_DIR/view"
mkdir -p "$VIEW_BASE_DIR$VIEW_NS_PATH/view"

echo "Generating Application Page: $PAGE_CLASS_NAME"

# Java
cat <<JAVA > "$JAVA_DIR/view/${PAGE_CLASS_NAME}.java"
package ${FULL_PKG}.view;

import id.my.mdn.kupu.core.base.view.Page;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${XHTML_NAME}Page")
@ViewScoped
$(if [ -n "$CUSTOM_XHTML" ]; then echo -e "import id.my.mdn.kupu.core.base.view.annotation.View;\n\n@View(\"$VIEW_NS_PATH/view/${XHTML_NAME}.xhtml\")"; fi)
public class ${PAGE_CLASS_NAME} extends Page implements Serializable {
    @Override @PostConstruct public void init() { super.init(); }
}
JAVA

# XHTML
cat <<HTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/${XHTML_NAME}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                template="/WEB-INF/templates/page.xhtml"
                xmlns:f="jakarta.faces.core"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:p="primefaces">
    <f:metadata>
        <ui:param name="title" value="$PAGE_CAP" />
        <ui:param name="viewPage" value="#{${XHTML_NAME}Page}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml"/>
    </f:metadata>
    <ui:define name="content">
        <div class="card">
            <h1>$PAGE_CAP</h1>
            <p>Module: $MODULE_NAME</p>
        </div>
    </ui:define>
</ui:composition>
HTML

echo "Success! Page components generated in $FULL_PKG."
