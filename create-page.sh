#!/bin/bash

# Kupu Web Page Generator Script
# Usage: ./create-page.sh [SUB_MODULE_NAME] [PAGE_NAME] [CUSTOM_XHTML]

if [ -z "$1" ]; then
    read -p "Enter sub-module name (lowercase): " MODULE_NAME
else
    MODULE_NAME=$1
fi

if [ -z "$2" ]; then
    read -p "Enter base page name (CamelCase): " BASE_NAME
else
    BASE_NAME=$2
fi

CUSTOM_XHTML=$3

# Paths for kupu-web
MODULE_ROOT="."
JAVA_DIR="$MODULE_ROOT/src/main/java/id/my/mdn/kupu/app/$MODULE_NAME"
VIEW_BASE_DIR="$MODULE_ROOT/src/main/webapp"
BASE_PACKAGE="id.my.mdn.kupu.app.$MODULE_NAME"
VIEW_NS_PATH="/app/$MODULE_NAME"

if [ ! -d "$JAVA_DIR" ]; then
    echo "Error: Sub-module '$MODULE_NAME' not found in kupu-web/src/main/java/id/my/mdn/kupu/app/"
    exit 1
fi

PAGE_CAP=$(echo "$BASE_NAME" | sed 's/./\U&/')
PAGE_CLASS_NAME="${PAGE_CAP}Page"

if [ -n "$CUSTOM_XHTML" ]; then
    XHTML_NAME=$(echo "$CUSTOM_XHTML" | tr '[:upper:]' '[:lower:]')
else
    XHTML_NAME=$(echo "$BASE_NAME" | tr '[:upper:]' '[:lower:]')
fi

VIEW_DIR="$JAVA_DIR/view"
XHTML_DIR="$VIEW_BASE_DIR$VIEW_NS_PATH/view"

mkdir -p "$VIEW_DIR"
mkdir -p "$XHTML_DIR"

echo "Generating Web Page: $PAGE_CLASS_NAME"

# 1. Generate Java Page Class
cat <<JAVA > "$VIEW_DIR/${PAGE_CLASS_NAME}.java"
package ${BASE_PACKAGE}.view;

import id.my.mdn.kupu.core.base.view.Page;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${XHTML_NAME}Page")
@ViewScoped
JAVA

if [ -n "$CUSTOM_XHTML" ]; then
cat <<JAVA >> "$VIEW_DIR/${PAGE_CLASS_NAME}.java"
import id.my.mdn.kupu.core.base.view.annotation.View;

@View("$VIEW_NS_PATH/view/${XHTML_NAME}.xhtml")
JAVA
fi

cat <<JAVA >> "$VIEW_DIR/${PAGE_CLASS_NAME}.java"
public class ${PAGE_CLASS_NAME} extends Page implements Serializable {

    @Override
    @PostConstruct
    public void init() {
        super.init();
    }
}
JAVA

# 2. Generate XHTML View
cat <<HTML > "$XHTML_DIR/${XHTML_NAME}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                template="/WEB-INF/templates/page.xhtml"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:p="primefaces">

    <f:metadata>
        <ui:param name="title" value="$PAGE_CAP" />
        <ui:param name="viewPage" value="#{${XHTML_NAME}Page}" />
        <ui:include src="/WEB-INF/components/core/base/meta/page.xhtml"/>
    </f:metadata>

    <ui:define name="content">
        <div class="card">
            <h1>$PAGE_CAP (Web)</h1>
            <p>Welcome to the $PAGE_CAP page in $MODULE_NAME web application.</p>
        </div>
    </ui:define>

</ui:composition>
HTML

echo "--------------------------------------------------"
echo "Success! File created in web module."
echo "--------------------------------------------------"
