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
MODULE_BEAN=$(echo "$MODULE_NAME" | sed 's/./\L&/')

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/app/$MODULE_NAME"

mkdir -p "$JAVA_DIR"/{entity,dao,view/list,view/converter,view/filter,view/admin}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR"/view/admin
mkdir -p "$COMP_DIR"/{list,editor,detail,filter/meta}

# Determine base class and facade
FORM_CLASS=""
FORM_VAR=""

case $PARTY_TYPE in
    Person)
        BASE_ENTITY="PersonRole"
        BASE_FACADE="PersonRoleFacade"
        PARTY_VAR="person"
        EDITOR_FORM="PersonEditorForm"
        PARTY_IF="Person"
        FORM_CLASS="PersonForm"
        FORM_VAR="personForm"
        ;;
    Organization)
        BASE_ENTITY="OrganizationRole"
        BASE_FACADE="OrganizationRoleFacade"
        PARTY_VAR="organization"
        EDITOR_FORM="OrganizationEditorForm"
        PARTY_IF="Organization"
        FORM_CLASS="OrganizationForm"
        FORM_VAR="organizationForm"
        ;;
    General)
        BASE_ENTITY="PartyRole"
        BASE_FACADE="AbstractPartyRoleFacade"
        PARTY_VAR="party"
        EDITOR_FORM="PartyEditorForm"
        PARTY_IF="Party"
        # No PartyForm exists, skipping form integration for general
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
            if [[ "$NAME" != "serialVersionUID" && "$NAME" != "party" && "$NAME" != "person" && "$NAME" != "organization" ]]; then
                FIELDS_ARRAY+=("$TYPE:$NAME")
            fi
        fi
    done < "$ENTITY_FILE"
fi

# 1.3 Architectural Validation & Fixing (if entity exists)
if [ -f "$ENTITY_FILE" ]; then
    echo "Validating architectural constraints for: $ROLE_CAP..."
    
    # Ensure necessary imports
    for imp in "java.io.Serializable" "jakarta.persistence.Entity" "jakarta.persistence.Table" "java.util.ArrayList" "java.time.LocalDate" "id.my.mdn.kupu.core.base.model.EntityBuilder" "id.my.mdn.kupu.core.party.entity.${BASE_ENTITY}" "id.my.mdn.kupu.core.party.entity.${PARTY_IF}"; do
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

# 2.5 Generate Filter Content
{
    echo "package ${BASE_PACKAGE}.view.filter;"
    echo ""
    echo "import id.my.mdn.kupu.core.base.view.annotation.Bookmark;"
    echo "import id.my.mdn.kupu.core.base.view.widget.FilterContent;"
    echo "import jakarta.enterprise.context.Dependent;"
    echo "import java.io.Serializable;"
    echo "import java.time.LocalDate;"
    
    # Try to find imports for custom types
    for field in "${FIELDS_ARRAY[@]}"; do
        TYPE="${field%%:*}"
        if [[ ! "$TYPE" =~ ^(String|Long|Integer|Double|Boolean|List|Map|LocalDate)$ ]]; then
            IMPORT=$(find src/main/java -name "${TYPE}.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${TYPE}';/')
            if [ -n "$IMPORT" ]; then echo "$IMPORT"; fi
        fi
    done | sort -u
    
    echo ""
    echo "@Dependent"
    echo "public class ${ENTITY_CAP:-$ROLE_CAP}Filter extends FilterContent implements Serializable {"
    echo "    "
    echo "    @Bookmark(name = \"name\")"
    echo "    private String name;"
    for field in "${FIELDS_ARRAY[@]}"; do
        TYPE="${field%%:*}"
        NAME="${field#*:}"
        echo "    @Bookmark(name = \"$NAME\")"
        echo "    private $TYPE $NAME;"
    done
    echo ""
    echo "    public String getName() { return name; }"
    echo "    public void setName(String name) { this.name = name; }"
    for field in "${FIELDS_ARRAY[@]}"; do
        TYPE="${field%%:*}"
        NAME="${field#*:}"
        CAP_NAME=$(echo "$NAME" | sed -r 's/(^.)/\U\1/')
        echo "    public $TYPE get${CAP_NAME}() { return $NAME; }"
        echo "    public void set${CAP_NAME}($TYPE $NAME) { this.$NAME = $NAME; }"
    done
    echo "}"
} > "$JAVA_DIR/view/filter/${ROLE_CAP}Filter.java"

# 3. Generate List Bean
cat <<JAVA > "$JAVA_DIR/view/list/${ROLE_CAP}List.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;
import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import ${BASE_PACKAGE}.view.filter.${ROLE_CAP}Filter;
import id.my.mdn.kupu.core.base.dao.AbstractFacade.DefaultChecker;
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.widget.AbstractMutablePagedValueList;
import id.my.mdn.kupu.core.base.view.widget.AbstractPagedValueList.DefaultCount;
import id.my.mdn.kupu.core.base.view.widget.AbstractValueList.DefaultList;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;

@Dependent
public class ${ROLE_CAP}List extends AbstractMutablePagedValueList<${ROLE_CAP}> {

    @Inject
    private ${ROLE_CAP}Facade dao;

    @Inject
    private ${ROLE_CAP}Filter filterContent;

    public ${ROLE_CAP}List() {
        super(${ROLE_CAP}.class);
    }

    @PostConstruct
    public void init() {
        filter.setContent(filterContent);
    }

    @Override
    protected List<${ROLE_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ROLE_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }

    @Override
    protected long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }

    @Override
    protected Result<String> createInternal(${ROLE_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> editInternal(${ROLE_CAP} entity) {
        return dao.edit(entity);
    }

    @Override
    protected Result<String> deleteInternal(${ROLE_CAP} entity) {
        return dao.remove(entity);
    }

    @Override
    public String[] getCreatePermission() {
        return new String[]{"${MODULE_NAME}.${ROLE_LOWER}.create"};
    }

    @Override
    public String[] getUpdatePermission() {
        return new String[]{"${MODULE_NAME}.${ROLE_LOWER}.update"};
    }

    @Override
    public String[] getDeletePermission() {
        return new String[]{"${MODULE_NAME}.${ROLE_LOWER}.delete"};
    }
}
JAVA

# 4. Generate Page Controller
cat <<JAVA > "$JAVA_DIR/view/${ROLE_CAP}Page.java"
package ${BASE_PACKAGE}.view;

import ${BASE_PACKAGE}.view.list.${ROLE_CAP}List;
import ${BASE_PACKAGE}.view.admin.${ROLE_CAP}EditorPage;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import id.my.mdn.kupu.core.base.view.annotation.Creator;
import id.my.mdn.kupu.core.base.view.annotation.Deleter;
import id.my.mdn.kupu.core.base.view.annotation.Editor;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${ROLE_LOWER}Page")
@ViewScoped
public class ${ROLE_CAP}Page extends Page implements Serializable {

    @Inject
    @Bookmarked
    private ${ROLE_CAP}List dataView;

    @Override
    @PostConstruct
    public void init() {
        super.init();
    }

    @Creator(of = "dataView")
    public void openCreator() {
        gotoChild(${ROLE_CAP}EditorPage.class).open();
    }

    @Editor(of = "dataView")
    public void openEditor() {
        gotoChild(${ROLE_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(dataView.getSelected())
                .open();
    }
    
    public void openDetail() {
        gotoChild(${ROLE_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(dataView.getSelected())
                .addParam("readonly").withValues(true)
                .open();
    }

    @Deleter(of = "dataView")
    public void openDeleter() {
        dataView.deleteSelected();
    }

    public ${ROLE_CAP}List getDataView() {
        return dataView;
    }
}
JAVA

# 4.5. Generate Editor Page Controller
{
echo "package ${BASE_PACKAGE}.view.admin;"
echo ""
echo "import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;"
echo "import ${BASE_PACKAGE}.entity.${ROLE_CAP};"
echo "import id.my.mdn.kupu.core.base.util.Result;"
echo "import id.my.mdn.kupu.core.base.view.FormPage;"
echo "import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;"
if [ -n "$FORM_CLASS" ]; then
    echo "import id.my.mdn.kupu.core.party.view.form.${FORM_CLASS};"
fi
echo "import jakarta.annotation.PostConstruct;"
echo "import jakarta.enterprise.context.ConversationScoped;"
echo "import jakarta.inject.Inject;"
echo "import jakarta.inject.Named;"
echo "import java.io.Serializable;"
echo ""
echo "@Named(value = \"${ROLE_LOWER}EditorPage\")"
echo "@ConversationScoped"
echo "public class ${ROLE_CAP}EditorPage extends FormPage<${ROLE_CAP}> implements Serializable {"
echo ""
echo "    @Inject"
echo "    private ${ROLE_CAP}Facade dao;"
echo "    "
echo "    @Bookmarked(name = \"readonly\")"
echo "    private boolean readonly;"
if [ -n "$FORM_CLASS" ]; then
    echo "    "
    echo "    private ${FORM_CLASS} ${FORM_VAR};"
fi
echo ""
echo "    @Override"
echo "    @PostConstruct"
echo "    protected void init() {"
echo "        super.init();"
if [ -n "$FORM_CLASS" ]; then
    echo "        if (entity != null) {"
    echo "            ${FORM_VAR} = new ${FORM_CLASS}();"
    echo "            ${FORM_VAR}.setEntity(entity.get${PARTY_IF}());"
    echo "        }"
fi
echo "    }"
echo ""
echo "    @Override"
echo "    protected ${ROLE_CAP} newEntity() {"
if [ -n "$FORM_CLASS" ]; then
    echo "        ${ROLE_CAP} entity = new ${ROLE_CAP}();"
    echo "        entity.set${PARTY_IF}(id.my.mdn.kupu.core.party.entity.${PARTY_IF}.builder().get());"
    echo "        return entity;"
else
    echo "        return new ${ROLE_CAP}();"
fi
echo "    }"
echo "    "
echo "    @Override"
echo "    protected void loadEntity() {"
echo "        super.loadEntity();"
if [ -n "$FORM_CLASS" ]; then
    echo "        // Re-init form if entity changed (e.g. create vs edit)"
    echo "         if (entity != null) {"
    echo "            ${FORM_VAR} = new ${FORM_CLASS}();"
    echo "            ${FORM_VAR}.setEntity(entity.get${PARTY_IF}());"
    echo "        }"
fi
echo "    }"
echo ""
echo "    @Override"
echo "    protected Result<String> save(${ROLE_CAP} entity) {"
echo "        return dao.create(entity);"
echo "    }"
echo ""
echo "    @Override"
echo "    protected Result<String> edit(${ROLE_CAP} entity) {"
echo "        return dao.edit(entity);"
echo "    }"
echo "    "
echo "    public boolean isReadonly() {"
echo "        return readonly;"
echo "    }"
echo "    "
echo "    public void setReadonly(boolean readonly) {"
echo "        this.readonly = readonly;"
echo "    }"
if [ -n "$FORM_CLASS" ]; then
    echo "    "
    echo "    public ${FORM_CLASS} get${FORM_CLASS}() {"
    echo "        return ${FORM_VAR};"
    echo "    }"
    echo "    "
    echo "    public void set${FORM_CLASS}(${FORM_CLASS} ${FORM_VAR}) {"
    echo "        this.${FORM_VAR} = ${FORM_VAR};"
    echo "    }"
fi
echo "}"
} > "$JAVA_DIR/view/admin/${ROLE_CAP}EditorPage.java"


# 4.5 Generate Converters
cat <<JAVA > "$JAVA_DIR/view/converter/${ROLE_CAP}Converter.java"
package ${BASE_PACKAGE}.view.converter;

import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "${ROLE_CAP}Converter")
public class ${ROLE_CAP}Converter implements Converter<${ROLE_CAP}> {

    @Inject
    private ${ROLE_CAP}Facade dao;

    @Override
    public ${ROLE_CAP} getAsObject(FacesContext context, UIComponent component, String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        return dao.find(KLong.valueOf(value));
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, ${ROLE_CAP} value) {
        return value != null ? value.toString() : null;
    }
}
JAVA

cat <<JAVA > "$JAVA_DIR/view/converter/${ROLE_CAP}ListConverter.java"
package ${BASE_PACKAGE}.view.converter;

import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import id.my.mdn.kupu.core.base.view.converter.SelectionsConverter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "${ROLE_CAP}ListConverter")
public class ${ROLE_CAP}ListConverter extends SelectionsConverter<${ROLE_CAP}> {

    @Inject
    private ${ROLE_CAP}Facade service;

    @Override
    protected ${ROLE_CAP} getAsObject(String value) {
        return service.find(KLong.valueOf(value));
    }

    @Override
    protected String getAsString(${ROLE_CAP} value) {
        return value != null ? String.valueOf(value.getId()) : null;
    }
}
JAVA

# 5. Generate Admin Page XHTML
cat <<XHTML > "$WEB_DIR/view/${ROLE_LOWER}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                template="/WEB-INF/templates/page.xhtml">

    <f:metadata>
        <ui:param name="title" value="${ROLE_CAP}" />

        <ui:param name="viewPage" value="#{${ROLE_LOWER}Page}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />

        <ui:param name="dataView" value="#{viewPage.dataView}" />
        <ui:param name="contentId" value=":data-frm:#{dataView.name}" />
        <ui:param name="notool" value="true" />

        <ui:param name="filter" value="#{dataView.filter}" />
        <ui:param name="filterType" value="overlay" />
        <ui:param name="filterUi" value="/WEB-INF/resources/app/${MODULE_NAME}/filter/${ROLE_LOWER}-filterui.xhtml" />
        <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/filter/meta/${ROLE_LOWER}-filterui.xhtml" />

        <ui:param name="sorter" value="#{dataView.sorter}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/sorter.xhtml" />

        <ui:param name="pager" value="#{dataView.pager}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/pager.xhtml" />

        <f:viewParam name="s" value="#{dataView.selectionsInternal}" converter="${ROLE_CAP}ListConverter"
            transient="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/module-menu.xhtml" />
    </ui:define>

    <ui:define name="content">
        <h:form id="data-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/list/${ROLE_LOWER}list.xhtml">
                <ui:param name="value" value="#{${ROLE_LOWER}Page.dataView}" />
            </ui:include>
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 5.5. Generate Admin Editor Page XHTML
{
echo "<ui:composition xmlns=\"http://www.w3.org/1999/xhtml\""
echo "                xmlns:ui=\"jakarta.faces.facelets\""
echo "                xmlns:f=\"jakarta.faces.core\""
echo "                xmlns:p=\"primefaces\""
echo "                xmlns:p=\"primefaces\""
echo "                xmlns:k=\"jakarta.faces.composite/app/${MODULE_NAME}/editor\""
echo "                template=\"/WEB-INF/templates/editor-page.xhtml\">"
echo ""
echo "    <f:metadata>"
echo "        <ui:param name=\"viewPage\" value=\"#{${ROLE_LOWER}EditorPage}\" />"
echo "        <ui:include src=\"/WEB-INF/resources/core/base/meta/page.xhtml\" />"
echo ""
echo "        <ui:param name=\"primaryTitle\" value=\"Editor ${ROLE_CAP}\" />"
echo ""
echo "        <ui:param name=\"notool\" value=\"true\" />"
echo "        <ui:param name=\"nofilter\" value=\"true\" />"
echo ""
echo "        <f:viewParam name=\"entity\" value=\"#{viewPage.entity}\" converter=\"${ROLE_CAP}Converter\" />"
echo "        <f:viewParam name=\"readonly\" value=\"#{viewPage.readonly}\" />"
echo ""
echo "        <f:viewAction action=\"#{viewPage.load}\" />"
echo "    </f:metadata>"
echo ""
echo "    <ui:define name=\"content-header\" />"
echo ""
echo "    <ui:define name=\"form\">"
echo "        <div class=\"grid w-full p-3\">"
echo "            <div class=\"col-12\">"
echo "                <k:${ROLE_LOWER}editor value=\"#{viewPage.entity}\" "
if [ -n "$FORM_CLASS" ]; then
    echo "                        ${FORM_VAR}=\"#{viewPage.${FORM_VAR}}\" "
fi
echo "                        readonly=\"#{viewPage.readonly}\" />"
echo "            </div>"
echo "        </div>"
echo "    </ui:define>"
echo ""
echo "</ui:composition>"
} > "$WEB_DIR/view/admin/${ROLE_LOWER}editor.xhtml"

# 6. Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${ROLE_LOWER}list.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces">

    <ui:decorate template="/WEB-INF/resources/core/base/table.xhtml">
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
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "            <p:column headerText=\"$PRETTY_NAME\">"
    echo "                <h:outputText value=\"#{item.$NAME}\" />"
    echo "            </p:column>"
done)            
        </ui:define>
    </ui:decorate>

</ui:composition>
XHTML

# 6.5. Generate Editor UI Component XHTML
{
echo "<ui:composition xmlns=\"http://www.w3.org/1999/xhtml\""
echo "                xmlns:ui=\"jakarta.faces.facelets\""
echo "                xmlns:p=\"primefaces\""
echo "                xmlns:k=\"jakarta.faces.composite/app/core\""
echo "                xmlns:cc=\"jakarta.faces.composite\""
echo "                xmlns:f=\"jakarta.faces.core\">"
echo ""
echo "    <cc:interface>"
echo "        <cc:attribute name=\"value\" required=\"true\" />"
if [ -n "$FORM_CLASS" ]; then
    echo "        <cc:attribute name=\"${FORM_VAR}\" required=\"true\" />"
fi
echo "        <cc:attribute name=\"readonly\" default=\"false\" />"
echo "    </cc:interface>"
echo ""
echo "    <cc:implementation>"
echo "        <ui:decorate template=\"/WEB-INF/resources/core/base/editor.xhtml\">"
echo "            <ui:param name=\"value\" value=\"#{cc.attrs.value}\" />"
echo "            <ui:define name=\"content\">"
if [ -n "$FORM_CLASS" ]; then
    echo "                <!-- Using Core Party Editor Form via Include -->"
    echo "                <ui:include src=\"/WEB-INF/resources/core/party/${PARTY_VAR}editorform.xhtml\">"
    echo "                    <ui:param name=\"editor\" value=\"#{cc.attrs}\" />"
    echo "                </ui:include>"
    echo "                "
    echo "                <p:divider align=\"left\" type=\"dashed\">"
    echo "                    <b>${ROLE_CAP} Details</b>"
    echo "                </p:divider>"
    echo "                "
fi
echo "                <div class=\"grid grid-cols-1 md:grid-cols-2 gap-4 mt-4\">"
for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "                    <div class=\"field\">"
    echo "                        <p:outputLabel for=\"$NAME\" value=\"$PRETTY_NAME\" />"
    echo "                        <p:inputText id=\"$NAME\" value=\"#{cc.attrs.value.$NAME}\" disabled=\"#{cc.attrs.readonly}\" />"
    echo "                    </div>"
done
echo "                </div>"
echo "            </ui:define>"
echo "        </ui:decorate>"
echo "    </cc:implementation>"
echo ""
echo "</ui:composition>"
} > "$COMP_DIR/editor/${ROLE_LOWER}editor.xhtml"

# 6.6. Generate Detail UI Component XHTML
{
echo "<ui:composition xmlns=\"http://www.w3.org/1999/xhtml\""
echo "                xmlns:ui=\"jakarta.faces.facelets\""
echo "                xmlns:p=\"primefaces\""
echo "                xmlns:k=\"jakarta.faces.composite/app/core\""
echo "                xmlns:cc=\"jakarta.faces.composite\""
echo "                xmlns:f=\"jakarta.faces.core\">"
echo ""
echo "    <cc:interface>"
echo "        <cc:attribute name=\"value\" required=\"true\" />"
echo "    </cc:interface>"
echo ""
echo "    <cc:implementation>"
echo "        <div class=\"card\">"
echo "            <h5>${ROLE_CAP} Details</h5>"
echo "            "
echo "            <p:panelGrid columns=\"2\" layout=\"grid\" columnClasses=\"font-bold, empty\" contentStyleClass=\"ui-fluid\">"
echo "                <h:outputText value=\"Role ID\" />"
echo "                <h:outputText value=\"#{cc.attrs.value.id}\" />"
echo "                "
echo "                <h:outputText value=\"Party Name\" />"
echo "                <h:outputText value=\"#{cc.attrs.value.party.name}\" />"
echo ""
for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "                <h:outputText value=\"$PRETTY_NAME\" />"
    echo "                <h:outputText value=\"#{cc.attrs.value.$NAME}\" />"
done
echo "            </p:panelGrid>"
echo "            "

if [ -n "$FORM_CLASS" ]; then
    echo "            <p:divider />"
    echo "            "
    echo "            <!-- Party Detail View -->"
    echo "            <h5>${PARTY_IF} Information</h5>"
    echo "            <ui:include src=\"/WEB-INF/resources/core/party/${PARTY_VAR}detail.xhtml\">"
    echo "                 <ui:param name=\"party\" value=\"#{cc.attrs.value.${PARTY_VAR}}\" />"
    echo "            </ui:include>"
fi
echo "            "
echo "        </div>"
echo "    </cc:implementation>"
echo ""
echo "</ui:composition>"
} > "$COMP_DIR/detail/${ROLE_LOWER}detail.xhtml"

# 7. Generate Filter UI Component XHTML
cat <<XHTML > "$COMP_DIR/filter/${ROLE_LOWER}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:p="primefaces">

    <div class="filter-field">
        <p:outputLabel for="name" value="Name" />
        <p:inputText id="name" value="#{filter.content.name}" />
    </div>

$(for field in "${FIELDS_ARRAY[@]}"; do
    NAME="${field#*:}"
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "    <div class=\"filter-field\">"
    echo "        <p:outputLabel for=\"$NAME\" value=\"$PRETTY_NAME\" />"
    echo "        <p:inputText id=\"$NAME\" value=\"#{filter.content.$NAME}\" />"
    echo "    </div>"
done)

</ui:composition>
XHTML

# 8. Generate Filter Meta Component XHTML
cat <<XHTML > "$COMP_DIR/filter/meta/${ROLE_LOWER}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:f="jakarta.faces.core">

    <f:viewParam name="name" value="#{filter.content.name}" converter="QueryStringConverter" transient="true" />

$(for field in "${FIELDS_ARRAY[@]}"; do
    TYPE="${field%%:*}"
    NAME="${field#*:}"
    CONVERTER="QueryStringConverter"
    if [[ "$TYPE" == "Long" ]]; then CONVERTER="LongConverter"; fi
    if [[ "$TYPE" == "Integer" ]]; then CONVERTER="IntegerConverter"; fi
    if [[ "$TYPE" == "LocalDate" ]]; then CONVERTER="LocalDateConverter"; fi
    if [[ ! "$TYPE" =~ ^(String|Long|Integer|Double|Boolean|LocalDate)$ ]]; then
        CONVERTER="${TYPE}Converter"
    fi
    echo "    <f:viewParam name=\"$NAME\" value=\"#{filter.content.$NAME}\" converter=\"$CONVERTER\" transient=\"true\" />"
done)

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
        # Use more flexible pattern to find switch statement start
        sed -i "/switch.*(pageId).* {/a \            case \"${ROLE_CAP}\": return ${BASE_PACKAGE}.view.${ROLE_CAP}Page.class;" "$NAVIGATOR_FILE"
        echo "Registered ${ROLE_CAP} in $NAVIGATOR_FILE"
    fi
fi

# 10. Register in Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if ! grep -q "value=\"${ROLE_CAP}\"" "$MENU_FILE"; then
        # Insert before the closing tag, ensuring correct formatting
        sed -i "/<\/ui:composition>/i \    <p:menuitem value=\"${ROLE_CAP}\" icon=\"pi pi-users\" actionListener=\"#{${MODULE_BEAN}Navigator.open('${ROLE_CAP}', '')}\" immediate=\"true\" />" "$MENU_FILE"
        echo "Registered ${ROLE_CAP} in $MENU_FILE"
    fi
fi

# 11. Update security.json
SEC_FILE="$RES_DIR/security.json"
if [ ! -f "$SEC_FILE" ]; then
    echo "{\"acls\": [], \"groups\": [], \"users\": []}" > "$SEC_FILE"
fi

for opt in create update delete; do
    ACL_NAME="${MODULE_NAME}.${ROLE_LOWER}.${opt}"
    ACL_DESC="$opt $ROLE_CAP"
    
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys, os
file_path = sys.argv[1]
acl_name = sys.argv[2]
acl_desc = sys.argv[3]

with open(file_path, 'r') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        data = {\"acls\": [], \"groups\": [], \"users\": []}

if 'acls' not in data: data['acls'] = []

# Check if ACL already exists
exists = False
for item in data['acls']:
    if item.get('acl', {}).get('name') == acl_name:
        exists = True
        break

if not exists:
    data['acls'].append({
        'acl': {
            'name': acl_name,
            'description': acl_desc
        }
    })
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=4)
" "$SEC_FILE" "$ACL_NAME" "$ACL_DESC"
    fi
done

chmod +x "$0"
echo "Successfully generated and registered application role components for ${ROLE_CAP} in $BASE_PACKAGE"
