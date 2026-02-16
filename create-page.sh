#!/bin/bash

# Kupu Application Page Generator
# usage: ./create-page.sh <sub_module_name> <page_name> [custom_xhtml]

# 1. Load configuration
if [ -f ".generator-config" ]; then
    BASE_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found."
    exit 1
fi

MODULE_NAME=$1
if [ -z "$MODULE_NAME" ]; then read -p "Enter sub-module name: " MODULE_NAME; fi

BASE_NAME=$2
if [ -z "$BASE_NAME" ]; then read -p "Enter base page name (CamelCase): " BASE_NAME; fi

CUSTOM_XHTML=$3
PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp"
FULL_PKG="$BASE_PACKAGE.$MODULE_NAME"
VIEW_NS_PATH="/app/$MODULE_NAME"

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
