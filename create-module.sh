#!/bin/bash

# Kupu Module Generator Script
# Usage: ./create-module.sh [module_name] [table_prefix]
# If module_name is not provided, it will be prompted
# If table_prefix is not provided, it will be auto-generated from module name in uppercase

# Get module name from argument or prompt
if [ -n "$1" ]; then
    MODULE_NAME="$1"
    if [[ ! "$MODULE_NAME" =~ ^[a-z]+$ ]]; then
        echo "Error: Module name must be lowercase letters only."
        exit 1
    fi
else
    read -p "Enter module name (lowercase, no spaces, e.g. 'inventory'): " MODULE_NAME
    if [[ ! "$MODULE_NAME" =~ ^[a-z]+$ ]]; then
        echo "Error: Module name must be lowercase letters only."
        exit 1
    fi
fi

read -p "Enter module display title (e.g. 'Inventory Management'): " MODULE_TITLE

# Determine next module order
MAX_ORDER=0
# Scan for module files in the webapp source tree
while IFS= read -r file; do
    # Check if the file contains getOrder() method
    if grep -q "protected int getOrder()" "$file"; then
        # Extract the lines following getOrder()
        METHOD_BODY=$(grep -A 2 "protected int getOrder()" "$file")

        # Check if it uses Integer.MAX_VALUE (core module)
        if echo "$METHOD_BODY" | grep -q "Integer.MAX_VALUE"; then
            continue
        fi

        # Extract the returned integer value
        ORDER=$(echo "$METHOD_BODY" | grep "return" | grep -oE '[0-9]+' | head -1)
        
        if [ -n "$ORDER" ]; then
             if [ "$ORDER" -gt "$MAX_ORDER" ]; then
                MAX_ORDER=$ORDER
             fi
        fi
    fi
done < <(find kupu-web/src/main/java -name "*Module.java" 2>/dev/null)

NEXT_ORDER=$((MAX_ORDER + 10))
if [ "$MAX_ORDER" -eq "0" ]; then
   NEXT_ORDER=10
fi

read -p "Enter module display order (integer, default: $NEXT_ORDER): " MODULE_ORDER
MODULE_ORDER=${MODULE_ORDER:-$NEXT_ORDER}

# Table prefix: use second argument if provided, otherwise auto-generate from module name
if [ -n "$2" ]; then
    TABLE_PREFIX="$2"
    if [[ ! "$TABLE_PREFIX" =~ ^[A-Z_]+$ ]]; then
        echo "Error: Table prefix must be uppercase letters and underscores only."
        exit 1
    fi
else
    # Auto-generate table prefix from module name (uppercase)
    TABLE_PREFIX=$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')
    echo "Using auto-generated table prefix: $TABLE_PREFIX"
fi

MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/.*/\L&/; s/./\U&/')

# Define paths
CORE_PKG="id.my.mdn.kupu.app.$MODULE_NAME"
JAVA_DIR="kupu-web/src/main/java/id/my/mdn/kupu/app/$MODULE_NAME"
RES_DIR="kupu-web/src/main/resources/id/my/mdn/kupu/app/$MODULE_NAME"
WEB_DIR="kupu-web/src/main/webapp/app/$MODULE_NAME"
COMP_DIR="kupu-web/src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

echo "Creating directory structure for module: $MODULE_NAME..."

mkdir -p "$JAVA_DIR"/{entity,dao,view/admin,view/converter,view/event,view/filter,view/list,service,api,event}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR"/view/admin
mkdir -p "$COMP_DIR"/{list,filter}


echo "Generating Java files..."

# Module Class
cat <<EOF > "$JAVA_DIR/${MODULE_CAP}Module.java"
package $CORE_PKG;

import id.my.mdn.kupu.core.base.AbstractModule;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class ${MODULE_CAP}Module extends AbstractModule {

    @Override
    protected String getLabel() {
        return "$MODULE_NAME.module.title";
    }

    @Override
    protected int getOrder() {
        return $MODULE_ORDER;
    }

    @Override
    protected void postInit() {
        // Perform initialization tasks here
    }
}
EOF

# Navigator class
cat <<EOF > "$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
package $CORE_PKG.view;

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
            case "Home":
                // return ${MODULE_CAP}Page.class;
            default:
                return null;
        }
    }

    @Override
    protected String getHome() {
        return "/app/$MODULE_NAME/index.xhtml";
    }

}
EOF

# R class
cat <<EOF > "$JAVA_DIR/R.java"
package $CORE_PKG;

public final class R {
    public static final String MODULE_TITLE = "$MODULE_NAME.module.title";
}
EOF

echo "Generating resource files..."

# security.json
cat <<EOF > "$RES_DIR/security.json"
{
    "acls": [
        {
            "acl": {
                "name": "view_module_$MODULE_NAME",
                "description": "Access $MODULE_TITLE Module"
            }
        },
        {
            "acl": {
                "name": "admin_module_$MODULE_NAME",
                "description": "Administrator of $MODULE_TITLE Module"
            }
        }
    ],
    "groups": [],
    "users": []
}
EOF

# Generator Config
cat <<EOF > "$RES_DIR/.generator-config"
# Generator Configuration for $MODULE_NAME module
TABLE_PREFIX=$TABLE_PREFIX
EOF

# template.json
echo "{}" > "$RES_DIR/template.json"

# string_en.properties
cat <<EOF > "$RES_DIR/string_en.properties"
$MODULE_NAME.module.title=$MODULE_TITLE
EOF

# string_id.properties
cat <<EOF > "$RES_DIR/string_id.properties"
$MODULE_NAME.module.title=$MODULE_TITLE
EOF

echo "Generating web files..."


# module-menu.xhtml
NAV_BEAN="#{$(echo "$MODULE_NAME" | sed 's/./\L&/')Navigator"
cat <<EOF > "$COMP_DIR/module-menu.xhtml"
<ui:composition xmlns:ui="jakarta.faces.facelets" 
                xmlns:p="primefaces">

    <p:menuitem value="$MODULE_TITLE Home" icon="pi pi-home"
                actionListener="$NAV_BEAN.open('Home', '')}"
                immediate="true" />

</ui:composition>
EOF


echo "Making scripts executable..."
chmod +x "$0"

echo "--------------------------------------------------"
echo "Module '$MODULE_NAME' has been created successfully!"
echo "Next steps:"
echo "1. Run 'mvn clean install' to register entities."
echo "2. Add your JPA entities to '$JAVA_DIR/entity/'."
echo "3. Update security ACLs in '$RES_DIR/security.json'."
echo "4. Integrate the side menu if needed."
echo "--------------------------------------------------"
