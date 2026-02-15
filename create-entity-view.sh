#!/bin/bash

# Kupu Application Entity View Generator
# Generates JPA Entity (if missing), Facade, List Bean, Page Controller, and XHTMLs

# Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package> [--no-acl]

# 1. Load configuration
if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found. Are you in a Kupu application directory?"
    exit 1
fi

SUB_MODULE=""
ENTITY_NAME=""
ENTITY_PKG=""
SKIP_ACL=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-acl) SKIP_ACL=true ;;
        *) 
            if [ -z "$SUB_MODULE" ]; then SUB_MODULE=$1
            elif [ -z "$ENTITY_NAME" ]; then ENTITY_NAME=$1
            elif [ -z "$ENTITY_PKG" ]; then ENTITY_PKG=$1
            fi
            ;;
    esac
    shift
done

if [ -z "$SUB_MODULE" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Usage: ./create-entity-view.sh <sub_module_name> <entity_name> [entity_package] [--no-acl]"
    exit 1
fi

MODULE_NAME=$SUB_MODULE

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
ENTITY_UPPER=$(echo "$ENTITY_NAME" | tr '[:lower:]' '[:upper:]')
MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp"
VIEW_NS_PATH="/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

ENTITY_PKG_PATH=$(echo "$ENTITY_PKG" | tr . /)
ENTITY_FILE="src/main/java/${ENTITY_PKG_PATH}/${ENTITY_CAP}.java"

# 1.1 Discover Entity if package is missing or file not found
if [ -z "$ENTITY_PKG" ] || [ ! -f "$ENTITY_FILE" ]; then
    FOUND_ENTITY=$(find src/main/java -name "$MODULE_NAME" -type d -exec find {} -name "${ENTITY_CAP}.java" \; | head -n 1)
    
    if [ -n "$FOUND_ENTITY" ]; then
        ENTITY_FILE="$FOUND_ENTITY"
        ENTITY_PKG=$(grep "^package " "$ENTITY_FILE" | head -n 1 | sed 's/package \(.*\);/\1/')
        echo "Found existing entity at $ENTITY_FILE ($ENTITY_PKG)"
    elif [ -z "$ENTITY_PKG" ]; then
        echo "Error: Entity $ENTITY_NAME not found in module $MODULE_NAME and no package specified."
        echo "Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package> [--no-acl]"
        exit 1
    fi
fi

mkdir -p "$(dirname "$ENTITY_FILE")"
mkdir -p "$JAVA_DIR"/{dao,view/filter,view/list,view/admin,view/converter}
mkdir -p "$RES_DIR"
mkdir -p "$VIEW_BASE_DIR$VIEW_NS_PATH/view/admin"
mkdir -p "$COMP_DIR"/{list,filter/meta}

# Get Table Prefix
TABLE_PREFIX=""
CONFIG_FILE="$RES_DIR/.generator-config"
if [ -f "$CONFIG_FILE" ]; then
    TABLE_PREFIX=$(grep "^TABLE_PREFIX=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
TABLE_PREFIX=${TABLE_PREFIX:-$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')}

# 1.5 Generate Entity if missing
if [ ! -f "$ENTITY_FILE" ]; then
    echo "Entity $ENTITY_NAME not found. Generating default architecture-compliant entity..."
    cat <<JAVA > "$ENTITY_FILE"
package ${ENTITY_PKG};

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.TableGenerator;
import java.io.Serializable;
import java.util.Objects;

@Entity
@Table(name = "${TABLE_PREFIX}_${ENTITY_UPPER}")
public class ${ENTITY_CAP} implements Serializable {

    @Id
    @TableGenerator(name = "${MODULE_CAP}_${ENTITY_CAP}", table = "KEYGEN", allocationSize = 1)
    @GeneratedValue(generator = "${MODULE_CAP}_${ENTITY_CAP}", strategy = GenerationType.TABLE)
    private Long id;

    private String name;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    @Override
    public int hashCode() {
        int hash = 7;
        hash = 97 * hash + Objects.hashCode(this.id);
        return hash;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        final ${ENTITY_CAP} other = (${ENTITY_CAP}) obj;
        return Objects.equals(this.id, other.id);
    }

    @Override
    public String toString() {
        return id != null ? String.valueOf(id) : null;
    }
}
JAVA
    # Register new entity in persistence.xml
    if [ -f "./generate-persistence.sh" ]; then
        ./generate-persistence.sh
    fi
fi

# 2. Generate Facade (DAO)
cat <<JAVA > "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
package ${BASE_PACKAGE}.dao;

import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.dao.AbstractFacade;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@ApplicationScoped
public class ${ENTITY_CAP}Facade extends AbstractFacade<${ENTITY_CAP}> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    @Override protected EntityManager getEntityManager() { return em; }
    public ${ENTITY_CAP}Facade() { super(${ENTITY_CAP}.class); }
}
JAVA

# 3. Generate Filter Content
cat <<JAVA > "$JAVA_DIR/view/filter/${ENTITY_CAP}Filter.java"
package ${BASE_PACKAGE}.view.filter;

import id.my.mdn.kupu.core.base.view.annotation.Bookmark;
import id.my.mdn.kupu.core.base.view.widget.FilterContent;
import jakarta.enterprise.context.Dependent;
import java.io.Serializable;

@Dependent
public class ${ENTITY_CAP}Filter extends FilterContent implements Serializable {
    
    @Bookmark(name = "name")
    private String name;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
JAVA

# 4. Generate List Bean
cat <<JAVA > "$JAVA_DIR/view/list/${ENTITY_CAP}List.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import ${ENTITY_PKG}.${ENTITY_CAP};
import ${BASE_PACKAGE}.view.filter.${ENTITY_CAP}Filter;
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
public class ${ENTITY_CAP}List extends AbstractMutablePagedValueList<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade dao;

    @Inject
    private ${ENTITY_CAP}Filter filterContent;

    public ${ENTITY_CAP}List() {
        super(${ENTITY_CAP}.class);
    }

    @PostConstruct
    public void init() {
        filter.setContent(filterContent);
    }

    @Override
    protected List<${ENTITY_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ENTITY_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }

    @Override
    protected long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }

    @Override
    protected Result<String> createInternal(${ENTITY_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> editInternal(${ENTITY_CAP} entity) {
        return dao.edit(entity);
    }

    @Override
    protected Result<String> deleteInternal(${ENTITY_CAP} entity) {
        return dao.remove(entity);
    }
$(if [ "$SKIP_ACL" = false ]; then echo -ne "
    @Override
    public String[] getCreatePermission() {
        return new String[]{\"${MODULE_NAME}.${ENTITY_LOWER_CAMEL}.create\"};
    }

    @Override
    public String[] getUpdatePermission() {
        return new String[]{\"${MODULE_NAME}.${ENTITY_LOWER_CAMEL}.update\"};
    }

    @Override
    public String[] getDeletePermission() {
        return new String[]{\"${MODULE_NAME}.${ENTITY_LOWER_CAMEL}.delete\"};
    }"; fi)
}
JAVA

# 5. Generate Editor Page Controller
cat <<JAVA > "$JAVA_DIR/view/admin/${ENTITY_CAP}EditorPage.java"
package ${BASE_PACKAGE}.view.admin;

import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.FormPage;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@Named
@ConversationScoped
public class ${ENTITY_CAP}EditorPage extends FormPage<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade dao;

    @PostConstruct
    @Override
    protected void init() {
        super.init();
    }

    @Override
    protected ${ENTITY_CAP} newEntity() {
        return new ${ENTITY_CAP}();
    }

    @Override
    protected Result<String> save(${ENTITY_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> edit(${ENTITY_CAP} entity) {
        return dao.edit(entity);
    }
}
JAVA

# 6. Generate Main Page Controller
cat <<JAVA > "$JAVA_DIR/view/${ENTITY_CAP}Page.java"
package ${BASE_PACKAGE}.view;

import ${BASE_PACKAGE}.view.list.${ENTITY_CAP}List;
import ${BASE_PACKAGE}.view.admin.${ENTITY_CAP}EditorPage;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import id.my.mdn.kupu.core.base.view.annotation.Creator;
import id.my.mdn.kupu.core.base.view.annotation.Editor;
import id.my.mdn.kupu.core.base.view.annotation.Deleter;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${ENTITY_LOWER_CAMEL}Page")
@ViewScoped
public class ${ENTITY_CAP}Page extends Page implements Serializable {

    @Inject
    @Bookmarked
    private ${ENTITY_CAP}List dataView;
    
    @Override
    @PostConstruct
    public void init() {
        super.init();
    }

    public ${ENTITY_CAP}List getDataView() {
        return dataView;
    }

    @Creator(of = "dataView")
    public void openCreator() {
        gotoChild(${ENTITY_CAP}EditorPage.class).open();
    }

    @Editor(of = "dataView")
    public void openEditor() {
        gotoChild(${ENTITY_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(dataView.getSelected())
                .open();
    }

    @Deleter(of = "dataView")
    public void openDeleter() {
        dataView.deleteSelected();
    }
}
JAVA

# 5. Generate Converter
cat <<JAVA > "$JAVA_DIR/view/converter/${ENTITY_CAP}Converter.java"
package ${BASE_PACKAGE}.view.converter;

import ${ENTITY_PKG}.${ENTITY_CAP};
import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "${ENTITY_CAP}Converter")
public class ${ENTITY_CAP}Converter implements Converter<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade dao;

    @Override
    public ${ENTITY_CAP} getAsObject(FacesContext context, UIComponent component, String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        return dao.find(KLong.valueOf(value));
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, ${ENTITY_CAP} value) {
        return value != null ? value.toString() : null;
    }
}
JAVA

# 6. Generate List Converter
cat <<JAVA > "$JAVA_DIR/view/converter/${ENTITY_CAP}ListConverter.java"
package ${BASE_PACKAGE}.view.converter;

import ${ENTITY_PKG}.${ENTITY_CAP};
import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import id.my.mdn.kupu.core.base.view.converter.SelectionsConverter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "${ENTITY_CAP}ListConverter")
public class ${ENTITY_CAP}ListConverter extends SelectionsConverter<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade service;

    @Override
    protected ${ENTITY_CAP} getAsObject(String value) {
        return service.find(KLong.valueOf(value));
    }

    @Override
    protected String getAsString(${ENTITY_CAP} value) {
        return value != null ? String.valueOf(value.getId()) : null;
    }
}
JAVA

# 7. Generate Main Page XHTML
cat <<XHTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/${ENTITY_FILE_BASE}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" template="/WEB-INF/templates/page.xhtml"
    xmlns:h="jakarta.faces.html" xmlns:f="jakarta.faces.core" xmlns:ui="jakarta.faces.facelets" xmlns:p="primefaces">

    <f:metadata>
        <ui:param name="title" value="${ENTITY_NAME}" />

        <ui:param name="viewPage" value="#{${ENTITY_LOWER_CAMEL}Page}" />
        <ui:include src="/WEB-INF/components/core/base/meta/page.xhtml" />

        <ui:param name="dataView" value="#{viewPage.dataView}" />
        <ui:param name="contentId" value=":data-frm:#{dataView.name}" />
        <ui:param name="notool" value="true" />

        <ui:param name="filter" value="#{dataView.filter}" />
        <ui:param name="filterType" value="overlay" />
        <ui:param name="filterUi" value="/WEB-INF/components/app/${MODULE_NAME}/filter/${ENTITY_FILE_BASE}-filterui.xhtml" />
        <ui:include src="/WEB-INF/components/app/${MODULE_NAME}/filter/meta/${ENTITY_FILE_BASE}-filterui.xhtml" />

        <ui:param name="sorter" value="#{dataView.sorter}" />
        <ui:include src="/WEB-INF/components/core/base/meta/sorter.xhtml" />

        <ui:param name="pager" value="#{dataView.pager}" />
        <ui:include src="/WEB-INF/components/core/base/meta/pager.xhtml" />

        <f:viewParam name="s" value="#{dataView.selectionsInternal}" converter="${ENTITY_CAP}ListConverter"
            transient="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/components/app/${MODULE_NAME}/module-menu.xhtml" />
    </ui:define>

    <ui:define name="content">
        <h:form id="data-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/components/app/${MODULE_NAME}/list/${ENTITY_FILE_BASE}list.xhtml" />
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 8. Generate Editor Page XHTML
cat <<XHTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
<ui:composition template="/WEB-INF/templates/editor-page.xhtml" xmlns="http://www.w3.org/1999/xhtml"
    xmlns:ui="jakarta.faces.facelets" xmlns:f="jakarta.faces.core" xmlns:p="primefaces">

    <f:metadata>
        <ui:param name="viewPage" value="#{${ENTITY_LOWER_CAMEL}EditorPage}" />
        <ui:include src="/WEB-INF/components/core/base/meta/page.xhtml" />

        <ui:param name="primaryTitle" value="Editor $(echo "${ENTITY_NAME}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')" />

        <ui:param name="notool" value="true" />
        <ui:param name="nofilter" value="true" />

        <f:viewParam name="entity" value="#{viewPage.entity}" converter="${ENTITY_CAP}Converter" />

        <f:viewAction action="#{viewPage.load}" />
    </f:metadata>

    <ui:define name="content-header" />

    <ui:define name="form">
        <div class="grid w-full p-3">
            <div class="col-12 md:col-6 md:col-offset-3">
                <ui:decorate template="/WEB-INF/components/core/base/formlet.xhtml">
                    <ui:define name="fields">
                        <div class="form-field">
                            <p:outputLabel for="name" value="Name" />
                            <p:inputText id="name" value="#{viewPage.entity.name}" class="block w-full" />
                            <p:message for="name" />
                        </div>
                    </ui:define>
                </ui:decorate>
            </div>
        </div>
    </ui:define>

</ui:composition>
XHTML

# 9. Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${ENTITY_FILE_BASE}list.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:p="primefaces"
                xmlns:h="jakarta.faces.html">

    <ui:decorate template="/WEB-INF/components/core/base/table.xhtml">
        <ui:define name="columns">
            <p:column headerText="Name">
                <h:outputText value="#{data.name}" />
            </p:column>
        </ui:define>
    </ui:decorate>

</ui:composition>
XHTML

# 10. Generate Filter UI Component XHTML
cat <<XHTML > "$COMP_DIR/filter/${ENTITY_FILE_BASE}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:p="primefaces">

    <div class="filter-field">
        <p:outputLabel for="name" value="Name" />
        <p:inputText id="name" value="#{filter.content.name}" />
    </div>

</ui:composition>
XHTML

# 11. Generate Filter Meta Component XHTML
cat <<XHTML > "$COMP_DIR/filter/meta/${ENTITY_FILE_BASE}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:f="jakarta.faces.core">

    <f:viewParam name="name" value="#{filter.content.name}" converter="QueryStringConverter" transient="true" />

</ui:composition>
XHTML

# 10. Update security.json if not skipped
if [ "$SKIP_ACL" = false ]; then
    SEC_FILE="$RES_DIR/security.json"
    if [ ! -f "$SEC_FILE" ]; then
        echo "{\"acls\": [], \"groups\": [], \"users\": []}" > "$SEC_FILE"
    fi
    
    for opt in create update delete; do
        ACL_NAME="${MODULE_NAME}.${ENTITY_LOWER_CAMEL}.${opt}"
        ACL_DESC="$opt $ENTITY_NAME"
        
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
        else
            # Fallback to simple append if python is not available
            if ! grep -q "\"$ACL_NAME\"" "$SEC_FILE"; then
                sed -i "/\"acls\": \[/a \        {\n            \"acl\": {\n                \"name\": \"$ACL_NAME\",\n                \"description\": \"$ACL_DESC\"\n            }\n        }," "$SEC_FILE"
            fi
        fi
    done
fi

chmod +x "$0"
echo "Successfully generated application entity components in $BASE_PACKAGE"
