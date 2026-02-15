#!/bin/bash

# Kupu Application Role Component Generator
# usage: ./create-role-view.sh <module_name> <role_name> <party_type>

# 1. Load configuration
if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found."
    exit 1
fi

if [ "$#" -lt 3 ]; then
    echo "Usage: ./create-role-view.sh <module_name> <role_name> <Person|Organization|General>"
    echo "Example: ./create-role-view.sh pelanggan Merchant Organization"
    exit 1
fi

MODULE_NAME=$1
ROLE_NAME=$2
PARTY_TYPE=$3

ROLE_CAP=$(echo "$ROLE_NAME" | sed 's/./\U&/')
ROLE_LOWER=$(echo "$ROLE_NAME" | sed 's/./\L&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

mkdir -p "$JAVA_DIR"/{entity,dao,view/admin,view/list,view/converter}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR"/view/admin
mkdir -p "$COMP_DIR"/{list,editor,detail}

# Determine base class and facade
case $PARTY_TYPE in
    Person)
        BASE_ENTITY="PersonRole"
        BASE_FACADE="PersonRoleFacade"
        PARTY_VAR="person"
        EDITOR_FORM="PersonEditorForm"
        PARTY_IF="Person"
        ;;
    Organization)
        BASE_ENTITY="OrganizationRole"
        BASE_FACADE="OrganizationRoleFacade"
        PARTY_VAR="organization"
        EDITOR_FORM="OrganizationEditorForm"
        PARTY_IF="Organization"
        ;;
    General)
        BASE_ENTITY="PartyRole"
        BASE_FACADE="AbstractPartyRoleFacade"
        PARTY_VAR="party"
        EDITOR_FORM="PartyEditorForm"
        PARTY_IF="Party"
        ;;
    *)
        echo "Error: party_type must be Person, Organization, or General"
        exit 1
        ;;
esac

# 1.0 Get Table Prefix
TABLE_PREFIX=""
CONFIG_FILE="$RES_DIR/.generator-config"
if [ -f "$CONFIG_FILE" ]; then
    TABLE_PREFIX=$(grep "^TABLE_PREFIX=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
TABLE_PREFIX=${TABLE_PREFIX:-$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')}

# 1.1 Discover Existing Entity
ENTITY_FILE="$JAVA_DIR/entity/${ROLE_CAP}.java"
if [ ! -f "$ENTITY_FILE" ]; then
    FOUND_ENTITY=$(find src/main/java -name "$MODULE_NAME" -type d -exec find {} -name "${ROLE_CAP}.java" \; | head -n 1)
    if [ -n "$FOUND_ENTITY" ]; then
        ENTITY_FILE="$FOUND_ENTITY"
        echo "Found existing entity at $ENTITY_FILE"
    fi
fi

# 1.2 Discover Fields if entity exists
FIELDS_ARRAY=()
if [ -f "$ENTITY_FILE" ]; then
    echo "Parsing fields from existing entity: $ROLE_CAP..."
    while read -r line; do
        if [[ $line =~ private[[:space:]]+([A-Za-z0-9_<>]+)[[:space:]]+([a-z[A-Z0-9_]+)\; ]]; then
            TYPE="${BASH_REMATCH[1]}"
            NAME="${BASH_REMATCH[2]}"
            if [[ "$NAME" != "serialVersionUID" ]]; then
                FIELDS_ARRAY+=("$TYPE:$NAME")
            fi
        fi
    done < "$ENTITY_FILE"
fi

# 1.3 Architectural Validation & Fixing (if entity exists)
if [ -f "$ENTITY_FILE" ]; then
    echo "Validating architectural constraints for: $ROLE_CAP..."
    
    # Ensure necessary imports
    for imp in "java.io.Serializable" "java.util.Objects" "jakarta.persistence.Entity" "jakarta.persistence.Table"; do
        if ! grep -q "import $imp;" "$ENTITY_FILE"; then
            sed -i "/package /a \import $imp;" "$ENTITY_FILE"
        fi
    done

    # Check @Entity
    if ! grep -q "@Entity" "$ENTITY_FILE"; then
        echo "  - Missing @Entity. Injecting..."
        sed -i '/public class/i @Entity' "$ENTITY_FILE"
    fi
    
    # Check @Table
    if ! grep -q "@Table" "$ENTITY_FILE"; then
        echo "  - Missing @Table. Injecting..."
        sed -i "/@Entity/a @Table(name = \"${TABLE_PREFIX}_${ROLE_CAP^^}\")" "$ENTITY_FILE"
    elif ! grep -q "@Table(name = \"${TABLE_PREFIX}_${ROLE_CAP^^}\")" "$ENTITY_FILE"; then
        echo "  - @Table name mismatch. Updating..."
        sed -i "s/@Table(name = \".*\")/@Table(name = \"${TABLE_PREFIX}_${ROLE_CAP^^}\")/" "$ENTITY_FILE"
    fi
    
    # Check Serializable
    if ! grep -q "implements Serializable" "$ENTITY_FILE"; then
        echo "  - Missing Serializable. Injecting..."
        sed -i "s/class ${ROLE_CAP}/class ${ROLE_CAP} implements Serializable/" "$ENTITY_FILE"
    fi
fi

# 1.5 Generate Entity if missing
if [ ! -f "$ENTITY_FILE" ]; then
cat <<JAVA > "$ENTITY_FILE"
package ${BASE_PACKAGE}.entity;

import id.my.mdn.kupu.core.base.model.EntityBuilder;
import id.my.mdn.kupu.core.party.entity.${BASE_ENTITY};
import id.my.mdn.kupu.core.party.entity.${PARTY_IF};
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Objects;

@Entity
@Table(name = "${TABLE_PREFIX}_${ROLE_CAP^^}")
public class ${ROLE_CAP} extends ${BASE_ENTITY} implements Serializable {

    private static final long serialVersionUID = 1L;

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder extends EntityBuilder<${ROLE_CAP}> {

        public Builder() {
            super(new ${ROLE_CAP}());
            entity.setFromDate(LocalDate.now());
            entity.setSourceRelationships(new ArrayList<>());
            entity.setTargetRelationships(new ArrayList<>());
        }

        public Builder with${PARTY_IF}(${PARTY_IF} party) {
            if (party.getRoles() == null) {
                party.setRoles(new ArrayList<>());
            }
            entity.set${PARTY_IF}(party);
            party.getRoles().add(entity);
            return this;
        }
    }
}
JAVA
fi

# 2. Generate Facade
cat <<JAVA > "$JAVA_DIR/dao/${ROLE_CAP}Facade.java"
package ${BASE_PACKAGE}.dao;

import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import id.my.mdn.kupu.core.party.dao.${BASE_FACADE};
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@ApplicationScoped
public class ${ROLE_CAP}Facade extends ${BASE_FACADE}<${ROLE_CAP}> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    public ${ROLE_CAP}Facade() {
        super(${ROLE_CAP}.class);
    }

    @Override
    protected EntityManager getEntityManager() {
        return em;
    }
}
JAVA

# 3. Generate List Bean
cat <<JAVA > "$JAVA_DIR/view/list/${ROLE_CAP}List.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;
import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import id.my.mdn.kupu.core.base.dao.AbstractFacade.DefaultChecker;
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.view.widget.AbstractMutablePagedValueList;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.util.List;
import java.util.Map;

@Named(value = "${ROLE_LOWER}List")
@Dependent
public class ${ROLE_CAP}List extends AbstractMutablePagedValueList<${ROLE_CAP}> {

    @Inject
    private ${ROLE_CAP}Facade dao;

    public ${ROLE_CAP}List() {
        super(${ROLE_CAP}.class);
    }

    @Override
    protected List<${ROLE_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ROLE_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }

    @Override
    protected long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }
}
JAVA

# 4. Generate Page Controller
cat <<JAVA > "$JAVA_DIR/view/admin/${ROLE_CAP}Page.java"
package ${BASE_PACKAGE}.view.admin;

import ${BASE_PACKAGE}.view.list.${ROLE_CAP}List;
import id.my.mdn.kupu.core.base.view.ChildPage;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import id.my.mdn.kupu.core.base.view.annotation.Creator;
import id.my.mdn.kupu.core.base.view.annotation.Deleter;
import id.my.mdn.kupu.core.base.view.annotation.Editor;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${ROLE_LOWER}Page")
@ViewScoped
public class ${ROLE_CAP}Page extends ChildPage implements Serializable {

    @Inject
    @Bookmarked
    private ${ROLE_CAP}List dataView;

    @Creator(of = "dataView")
    public void create() {
        // Implementation for creation navigation
    }

    @Editor(of = "dataView")
    public void edit() {
        // Implementation for editor navigation
    }

    @Deleter(of = "dataView")
    public void delete() {
        dataView.deleteSelected();
    }

    public ${ROLE_CAP}List getDataView() {
        return dataView;
    }
}
JAVA

# 5. Generate Admin Page XHTML
cat <<XHTML > "$WEB_DIR/view/admin/${ROLE_LOWER}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                template="/WEB-INF/template/template.xhtml">

    <ui:define name="title">
        #{msg['${MODULE_NAME}.${ROLE_LOWER}.admin.title']}
    </ui:define>

    <ui:define name="content">
        <h:form id="${ROLE_LOWER}Form">
            <ui:include src="/WEB-INF/components/app/${MODULE_NAME}/list/${ROLE_LOWER}list.xhtml">
                <ui:param name="value" value="#{${ROLE_LOWER}Page.dataView}" />
            </ui:include>
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 6. Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${ROLE_LOWER}list.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces">

    <ui:decorate template="/WEB-INF/components/core/base/table.xhtml">
        <ui:param name="value" value="#{value}" />
        <ui:define name="columns">
            <p:column headerText="ID">
                <h:outputText value="#{item.id}" />
            </p:column>
            
            <p:column headerText="Name">
                <h:outputText value="#{item.party.name}" />
            </p:column>
$(for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    if [[ "$NAME" != "id" && "$NAME" != "party" && "$NAME" != "person" && "$NAME" != "organization" ]]; then
        PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
        echo "            <p:column headerText=\"$PRETTY_NAME\">"
        echo "                <h:outputText value=\"#{item.$NAME}\" />"
        echo "            </p:column>"
    fi
done)            
        </ui:define>
    </ui:decorate>

</ui:composition>
XHTML

# 7. Generate Editor Component XHTML
cat <<XHTML > "$COMP_DIR/editor/${ROLE_LOWER}editor.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces">

    <div class="grid w-full p-3">
        <div class="col-12">
           <h3>#{value.id == null ? 'Create' : 'Edit'} ${ROLE_CAP}</h3>
        </div>
$(for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    if [[ "$NAME" != "id" && "$NAME" != "party" && "$NAME" != "person" && "$NAME" != "organization" ]]; then
        PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
        echo "        <div class=\"col-12 md:col-6\">"
        echo "            <div class=\"form-field\">"
        echo "                <p:outputLabel for=\"$NAME\" value=\"$PRETTY_NAME\" />"
        echo "                <p:inputText id=\"$NAME\" value=\"#{value.$NAME}\" class=\"block w-full\" />"
        echo "                <p:message for=\"$NAME\" />"
        echo "            </div>"
        echo "        </div>"
    fi
done)
    </div>

</ui:composition>
XHTML

# 8. Generate Detail Component XHTML
cat <<XHTML > "$COMP_DIR/detail/${ROLE_LOWER}detail.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces">

    <div class="grid">
        <div class="col-12 md:col-6">
            <p:panel header="Party Information">
                <p:panelGrid columns="2" layout="grid" styleClass="ui-panelgrid-blank">
                    <h:outputLabel value="ID:" />
                    <h:outputText value="#{value.party.id}" />
                    
                    <h:outputLabel value="Name:" />
                    <h:outputText value="#{value.party.name}" />
                </p:panelGrid>
            </p:panel>
        </div>
        <div class="col-12 md:col-6">
            <p:panel header="Role Information">
                <p:panelGrid columns="2" layout="grid" styleClass="ui-panelgrid-blank">
$(for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    if [[ "$NAME" != "id" && "$NAME" != "party" && "$NAME" != "person" && "$NAME" != "organization" ]]; then
        PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
        echo "                    <h:outputLabel value=\"$PRETTY_NAME:\" />"
        echo "                    <h:outputText value=\"#{value.$NAME}\" />"
    fi
done)
                </p:panelGrid>
            </p:panel>
        </div>
    </div>

</ui:composition>
XHTML

# 9. Register in Navigator
NAVIGATOR_FILE="$JAVA_DIR/view/${ROLE_CAP}Navigator.java"
if [ ! -f "$NAVIGATOR_FILE" ]; then
    MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
    NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
fi

if [ -f "$NAVIGATOR_FILE" ]; then
    if ! grep -q "case \"${ROLE_CAP}\":" "$NAVIGATOR_FILE"; then
        sed -i "/switch(pageId) {/a \            case \"${ROLE_CAP}\": return ${BASE_PACKAGE}.view.admin.${ROLE_CAP}Page.class;" "$NAVIGATOR_FILE"
        echo "Registered ${ROLE_CAP} in $NAVIGATOR_FILE"
    fi
fi

# 10. Register in Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if ! grep -q "value=\"${ROLE_CAP}\"" "$MENU_FILE"; then
        # Insert before the closing tag, ensuring correct formatting
        sed -i "/<\/ui:composition>/i \    <p:menuitem value=\"${ROLE_CAP}\" icon=\"pi pi-users\" actionListener=\"#{${MODULE_NAME}Navigator.open('${ROLE_CAP}', '')}\" immediate=\"true\" />" "$MENU_FILE"
        echo "Registered ${ROLE_CAP} in $MENU_FILE"
    fi
fi

chmod +x "$0"
echo "Successfully generated and registered application role components for ${ROLE_CAP} in $BASE_PACKAGE"
