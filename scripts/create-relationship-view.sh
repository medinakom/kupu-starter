#!/bin/bash

# Kupu Application Relationship Component Generator
# usage: ./create-relationship-view.sh <module_name> <relationship_name> <from_role> <to_role>

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

if [ "$#" -lt 4 ]; then
    echo "Usage: ./create-relationship-view.sh <module_name> <relationship_name> <from_role> <to_role>"
    echo "Example: ./create-relationship-view.sh santri SantriEnrollment Santri KelompokPengasuhan"
    exit 1
fi

MODULE_NAME=$1
RELATIONSHIP_NAME=$2
FROM_ROLE=$3
TO_ROLE=$4

REL_CAP=$(echo "$RELATIONSHIP_NAME" | sed 's/./\U&/')
REL_LOWER=$(echo "$RELATIONSHIP_NAME" | tr '[:upper:]' '[:lower:]')
REL_UPPER=$(echo "$RELATIONSHIP_NAME" | tr '[:lower:]' '[:upper:]')
MODULE_BEAN=$(echo "$MODULE_NAME" | sed 's/./\L&/')

FROM_ROLE_CAP=$(echo "$FROM_ROLE" | sed 's/./\U&/')
FROM_ROLE_LOWER=$(echo "$FROM_ROLE" | sed 's/./\L&/')
TO_ROLE_CAP=$(echo "$TO_ROLE" | sed 's/./\U&/')
TO_ROLE_LOWER=$(echo "$TO_ROLE" | sed 's/./\L&/')

PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

mkdir -p "$JAVA_DIR"/{entity,dao,view/list,view/converter,view/filter,view/admin}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR"/view
mkdir -p "$WEB_DIR"/view/admin
mkdir -p "$COMP_DIR"/{list,filter/meta}
mkdir -p "$JAVA_DIR"/view/misc

# Function to generate LazyList and LazyChooser
generate_lazy_components() {
    local ROLE_NAME=$1
    local ROLE_CAP=$(echo "$ROLE_NAME" | sed 's/./\U&/')
    local ROLE_LOWER=$(echo "$ROLE_NAME" | sed 's/./\L&/')
    
    local LAZY_LIST_FILE="$JAVA_DIR/view/misc/${ROLE_CAP}LazyList.java"
    local LAZY_CHOOSER_FILE="$JAVA_DIR/view/misc/${ROLE_CAP}LazyChooser.java"

    # Generate LazyList
    if [ ! -f "$LAZY_LIST_FILE" ]; then
        echo "Generating ${ROLE_CAP}LazyList..."
        cat <<JAVA > "$LAZY_LIST_FILE"
package ${BASE_PACKAGE}.view.misc;

import ${BASE_PACKAGE}.dao.${ROLE_CAP}Facade;
import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import ${BASE_PACKAGE}.view.filter.${ROLE_CAP}Filter;
import id.my.mdn.kupu.core.base.dao.AbstractFacade;
import id.my.mdn.kupu.core.base.util.FilterTypes;
import id.my.mdn.kupu.core.base.view.widget.AbstractLazyList;
import id.my.mdn.kupu.core.base.view.widget.Filter;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;

@Dependent
public class ${ROLE_CAP}LazyList extends AbstractLazyList<${ROLE_CAP}> {

    @Inject
    private ${ROLE_CAP}Facade dao;

    @Inject
    private ${ROLE_CAP}Filter filterContent;

    public ${ROLE_CAP}LazyList() {
        super(${ROLE_CAP}.class);
        this.filter = new Filter(filterContent);
    }

    @Override
    protected List<${ROLE_CAP}> findAllInternal(Integer startPosition, Integer maxResult, Map<String, Object> parameters, List<FilterTypes.FilterData> filters, List<SorterData> sorters, List<${ROLE_CAP}> defaultReturn, AbstractFacade.DefaultChecker defaultChecker) {
        return dao.findAll(startPosition, maxResult,
                parameters, filter.getValues(), getSorters(),
                defaultList.get(), defaultChecker);
    }

    @Override
    protected Long countAllInternal(Map<String, Object> parameters, List<FilterTypes.FilterData> filters, Long defaultCount, AbstractFacade.DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filter.getValues(), defaultCount, defaultChecker);
    }

}
JAVA
    fi

    # Generate LazyChooser
    if [ ! -f "$LAZY_CHOOSER_FILE" ]; then
        echo "Generating ${ROLE_CAP}LazyChooser..."
        cat <<JAVA > "$LAZY_CHOOSER_FILE"
package ${BASE_PACKAGE}.view.misc;

import ${BASE_PACKAGE}.entity.${ROLE_CAP};
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.view.widget.InlineEditor;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

@Dependent
public class ${ROLE_CAP}LazyChooser extends InlineEditor<${ROLE_CAP}> implements Serializable {

    @Inject
    private ${ROLE_CAP}LazyList list;

    private String searchTerm;

    @Override
    protected void reload(Context ctx) {   
        list.getFilter().setStaticFilter(this::getFilters);    
        list.init();
    }

    private List<FilterData> getFilters() {
        List<FilterData> filters = new ArrayList<>();

        if (searchTerm != null && !searchTerm.isBlank()) {
            filters.add(FilterData.by("name", searchTerm));
        }

        return filters;
    }

    public ${ROLE_CAP}LazyList getList() {
        return list;
    }

    public String getSearchTerm() {
        return searchTerm;
    }

    public void setSearchTerm(String searchTerm) {
        this.searchTerm = searchTerm;
    }
    
}
JAVA
    fi
}

# Generate Lazy Components for both roles
generate_lazy_components "$FROM_ROLE"
generate_lazy_components "$TO_ROLE"


# 1.0 Get Table Prefix
TABLE_PREFIX=""
CONFIG_FILE="$RES_DIR/.generator-config"
if [ -f "$CONFIG_FILE" ]; then
    TABLE_PREFIX=$(grep "^TABLE_PREFIX=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
TABLE_PREFIX=${TABLE_PREFIX:-$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')}

if command -v python3 &>/dev/null; then
    TABLE_PREFIX_CAP=$(python3 -c "print('${TABLE_PREFIX}'.title())" 2>/dev/null || echo "${TABLE_PREFIX}")
else
    TABLE_PREFIX_CAP=$(echo "${TABLE_PREFIX}" | tr '[:upper:]' '[:lower:]' | sed 's/\(.\).*/\1/' | tr '[:lower:]' '[:upper:]')$(echo "${TABLE_PREFIX}" | tr '[:upper:]' '[:lower:]' | sed 's/.\(.*\)/\1/')
fi

# 1.1 Generate Entity
ENTITY_FILE="$JAVA_DIR/entity/${REL_CAP}.java"
if [ ! -f "$ENTITY_FILE" ]; then
cat <<JAVA > "$ENTITY_FILE"
package ${BASE_PACKAGE}.entity;

import id.my.mdn.kupu.core.base.model.EntityBuilder;
import id.my.mdn.kupu.core.party.entity.PartyRelationship;
import id.my.mdn.kupu.core.party.entity.PartyRelationshipId;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.LocalDate;
import java.util.ArrayList;

@Entity
@Table(name = "${TABLE_PREFIX}_${REL_UPPER}")
@DiscriminatorValue("${REL_UPPER}")
public class ${REL_CAP} extends PartyRelationship implements Serializable {

    private static final long serialVersionUID = 1L;

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder extends EntityBuilder<${REL_CAP}> {

        public Builder() {
            super(new ${REL_CAP}());
            entity.setId(new PartyRelationshipId());
            entity.setFromDate(LocalDate.now());
        }
        
        public Builder from(${FROM_ROLE_CAP} from) {
            if (from != null) {
                entity.setFromRole(from);
                if (from.getSourceRelationships() == null) {
                    from.setSourceRelationships(new ArrayList<>());
                }
                from.getSourceRelationships().add(entity);
            }
            return this;
        }

        public Builder to(${TO_ROLE_CAP} to) {
            if (to != null) {
                entity.setToRole(to);
                if (to.getTargetRelationships() == null) {
                    to.setTargetRelationships(new ArrayList<>());
                }
                to.getTargetRelationships().add(entity);
            }
            return this;
        }
    }

    public ${FROM_ROLE_CAP} get${FROM_ROLE_CAP}() {
        return (${FROM_ROLE_CAP}) getFromRole();
    }

    public void set${FROM_ROLE_CAP}(${FROM_ROLE_CAP} val) {
        setFromRole(val);
    }

    public ${TO_ROLE_CAP} get${TO_ROLE_CAP}() {
        return (${TO_ROLE_CAP}) getToRole();
    }

    public void set${TO_ROLE_CAP}(${TO_ROLE_CAP} val) {
        setToRole(val);
    }
}
JAVA
fi

# 2. Generate Facade
cat <<JAVA > "$JAVA_DIR/dao/${REL_CAP}Facade.java"
package ${BASE_PACKAGE}.dao;

import ${BASE_PACKAGE}.entity.${REL_CAP};
import id.my.mdn.kupu.core.party.dao.PartyRelationshipFacade;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.From;
import jakarta.persistence.criteria.Predicate;

@ApplicationScoped
public class ${REL_CAP}Facade extends PartyRelationshipFacade<${REL_CAP}> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    public ${REL_CAP}Facade() {
        super(${REL_CAP}.class);
    }

    @Override
    protected EntityManager getEntityManager() {
        return em;
    }

    @Override
    protected Predicate applyFilter(String filterName, Object filterValue, CriteriaQuery cq, From... from) {
        switch (filterName) {
            case "${FROM_ROLE_LOWER}":
                return super.applyFilter("fromRole", filterValue, cq, from);
            case "${TO_ROLE_LOWER}":
                return super.applyFilter("toRole", filterValue, cq, from);
            default:
                return super.applyFilter(filterName, filterValue, cq, from);
        }
    }
}
JAVA

# 2.5 Generate Filter Content
cat <<JAVA > "$JAVA_DIR/view/filter/${REL_CAP}Filter.java"
package ${BASE_PACKAGE}.view.filter;

import ${BASE_PACKAGE}.entity.${FROM_ROLE_CAP};
import ${BASE_PACKAGE}.entity.${TO_ROLE_CAP};
import id.my.mdn.kupu.core.base.view.annotation.Bookmark;
import id.my.mdn.kupu.core.base.view.widget.FilterContent;
import jakarta.enterprise.context.Dependent;
import java.io.Serializable;

@Dependent
public class ${REL_CAP}Filter extends FilterContent implements Serializable {
    
    @Bookmark(name = "${FROM_ROLE_LOWER}")
    private ${FROM_ROLE_CAP} ${FROM_ROLE_LOWER};
    
    @Bookmark(name = "${TO_ROLE_LOWER}")
    private ${TO_ROLE_CAP} ${TO_ROLE_LOWER};

    public ${FROM_ROLE_CAP} get${FROM_ROLE_CAP}() { return ${FROM_ROLE_LOWER}; }
    public void set${FROM_ROLE_CAP}(${FROM_ROLE_CAP} val) { this.${FROM_ROLE_LOWER} = val; }

    public ${TO_ROLE_CAP} get${TO_ROLE_CAP}() { return ${TO_ROLE_LOWER}; }
    public void set${TO_ROLE_CAP}(${TO_ROLE_CAP} val) { this.${TO_ROLE_LOWER} = val; }
}
JAVA

# 3. Generate List Bean
cat <<JAVA > "$JAVA_DIR/view/list/${REL_CAP}List.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${REL_CAP}Facade;
import ${BASE_PACKAGE}.entity.${REL_CAP};
import ${BASE_PACKAGE}.view.filter.${REL_CAP}Filter;
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
public class ${REL_CAP}List extends AbstractMutablePagedValueList<${REL_CAP}> {

    @Inject
    private ${REL_CAP}Facade dao;

    @Inject
    private ${REL_CAP}Filter filterContent;

    public ${REL_CAP}List() {
        super(${REL_CAP}.class);
    }

    @PostConstruct
    public void init() {
        filter.setContent(filterContent);
    }

    @Override
    protected List<${REL_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${REL_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }

    @Override
    protected long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }

    @Override
    protected Result<String> createInternal(${REL_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> editInternal(${REL_CAP} entity) {
        return dao.edit(entity);
    }

    @Override
    protected Result<String> deleteInternal(${REL_CAP} entity) {
        return dao.remove(entity);
    }
    @Override
    public String[] getCreatePermission() {
        return new String[]{"${MODULE_NAME}.${REL_LOWER}.create"};
    }

    @Override
    public String[] getUpdatePermission() {
        return new String[]{"${MODULE_NAME}.${REL_LOWER}.update"};
    }

    @Override
    public String[] getDeletePermission() {
        return new String[]{"${MODULE_NAME}.${REL_LOWER}.delete"};
    }
}
JAVA

# 4. Generate Page Controller
cat <<JAVA > "$JAVA_DIR/view/${REL_CAP}Page.java"
package ${BASE_PACKAGE}.view;

import ${BASE_PACKAGE}.view.list.${REL_CAP}List;
import ${BASE_PACKAGE}.view.admin.${REL_CAP}EditorPage;
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

@Named(value = "${REL_LOWER}Page")
@ViewScoped
public class ${REL_CAP}Page extends Page implements Serializable {

    @Inject
    @Bookmarked
    private ${REL_CAP}List dataView;

    @Override
    @PostConstruct
    public void init() {
        super.init();
    }

    @Creator(of = "dataView")
    public void openCreator() {
        gotoChild(${REL_CAP}EditorPage.class).open();
    }

    @Editor(of = "dataView")
    public void openEditor() {
         gotoChild(${REL_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(dataView.getSelected())
                .open();
    }

    @Deleter(of = "dataView")
    public void openDeleter() {
        dataView.deleteSelected();
    }

    public ${REL_CAP}List getDataView() {
        return dataView;
    }
}
JAVA

# 4.5. Generate Editor Page Controller
cat <<JAVA > "$JAVA_DIR/view/admin/${REL_CAP}EditorPage.java"
package ${BASE_PACKAGE}.view.admin;

import ${BASE_PACKAGE}.dao.${REL_CAP}Facade;
import ${BASE_PACKAGE}.entity.${REL_CAP};
import ${BASE_PACKAGE}.entity.${FROM_ROLE_CAP};
import ${BASE_PACKAGE}.entity.${TO_ROLE_CAP};
import ${BASE_PACKAGE}.view.misc.${FROM_ROLE_CAP}LazyChooser;
import ${BASE_PACKAGE}.view.misc.${TO_ROLE_CAP}LazyChooser;
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.FormPage;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.faces.event.ActionEvent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

@Named(value = "${REL_LOWER}EditorPage")
@ConversationScoped
public class ${REL_CAP}EditorPage extends FormPage<${REL_CAP}> implements Serializable {

    @Inject
    private ${REL_CAP}Facade dao;

    @Bookmarked(name = "fromRole")
    private ${FROM_ROLE_CAP} fromRole;

    @Inject
    private ${FROM_ROLE_CAP}LazyChooser fromRoleChooser;

    @Bookmarked(name = "toRole")
    private ${TO_ROLE_CAP} toRole;

    @Inject
    private ${TO_ROLE_CAP}LazyChooser toRoleChooser;

    public ${FROM_ROLE_CAP}LazyChooser getFromRoleChooser() {
        return fromRoleChooser;
    }

    public ${TO_ROLE_CAP}LazyChooser getToRoleChooser() {
        return toRoleChooser;
    }

    @Override
    @PostConstruct
    protected void init() {
        super.init();
        
        fromRoleChooser.setContext(this::ctxFromRoleChooser);
        fromRoleChooser.setSaveListener(this::onSelectFromRole);

        toRoleChooser.setContext(this::ctxToRoleChooser);
        toRoleChooser.setSaveListener(this::onSelectToRole);
    }

    private Map<String, Object> ctxFromRoleChooser() {
        Map<String, Object> context = new HashMap<>();
        return context;
    }

    public void onSelectFromRole(${FROM_ROLE_CAP} selection) {
        getEntity().setFromRole(selection);
    }

    private Map<String, Object> ctxToRoleChooser() {
        Map<String, Object> context = new HashMap<>();
        return context;
    }

    public void onSelectToRole(${TO_ROLE_CAP} selection) {
        getEntity().setToRole(selection);
    }

    @Override
    protected ${REL_CAP} newEntity() {
        return ${REL_CAP}.builder()
                .from(fromRole)
                .to(toRole)
                .get();
    }
    
    public void resetThruDate(ActionEvent evt) {
        entity.setThruDate(null);
    }

    @Override
    protected Result<String> save(${REL_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> edit(${REL_CAP} entity) {
        return dao.edit(entity);
    }
}
JAVA

# 4.5 Generate Converters (Reuse if possible, otherwise generate specifically for relationship?)
# For now, Relationship usually doesn't need a converter unless we select it, which we might in list
# But since ID is composite, generic converter might fail.
# For this iteration, we skip RelationshipConverter unless explicitly needed (ListConverter handled by SelectionsConverter potentially if we implemented toString/fromString correctly in entity/ID)
# The ID is Embedded, so we need a converter that handles the composite ID.
# Let's generate a basic Converter for now.

cat <<JAVA > "$JAVA_DIR/view/converter/${REL_CAP}Converter.java"
package ${BASE_PACKAGE}.view.converter;

import ${BASE_PACKAGE}.entity.${REL_CAP};
import ${BASE_PACKAGE}.dao.${REL_CAP}Facade;
import id.my.mdn.kupu.core.party.entity.PartyRelationshipId;
import id.my.mdn.kupu.core.base.util.EntityUtil;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;

@Singleton
@FacesConverter(managed = true, value = "${REL_CAP}Converter")
public class ${REL_CAP}Converter implements Converter<${REL_CAP}> {

    @Inject
    private ${REL_CAP}Facade dao;

    @Override
    public ${REL_CAP} getAsObject(FacesContext context, UIComponent component, String value) {
        return dao.find(new PartyRelationshipId(EntityUtil.parseCompositeId(value))); 
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, ${REL_CAP} value) {
        return value != null ? value.toString() : null;
    }
}
JAVA

cat <<JAVA > "$JAVA_DIR/view/converter/${REL_CAP}ListConverter.java"
package ${BASE_PACKAGE}.view.converter;

import ${BASE_PACKAGE}.dao.${REL_CAP}Facade;
import ${BASE_PACKAGE}.entity.${REL_CAP};
import id.my.mdn.kupu.core.base.util.EntityUtil;
import id.my.mdn.kupu.core.base.view.converter.SelectionsConverter;
import id.my.mdn.kupu.core.party.entity.PartyRelationshipId;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;

@Singleton
@FacesConverter(managed = true, value = "${REL_CAP}ListConverter")
public class ${REL_CAP}ListConverter extends SelectionsConverter<${REL_CAP}> {

    @Inject
    private ${REL_CAP}Facade service;

    @Override
    protected ${REL_CAP} getAsObject(String value) {
        return service.find(new PartyRelationshipId(EntityUtil.parseCompositeId(value)));
    }

    @Override
    protected String getAsString(${REL_CAP} value) {
        return value != null ? EntityUtil.createStringId(value.getId()) : null;
    }
}
JAVA

# 5. Generate Admin Page XHTML (List)
cat <<XHTML > "$WEB_DIR/view/${REL_LOWER}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                template="/WEB-INF/templates/page.xhtml">

    <f:metadata>
        <ui:param name="title" value="#{string['${REL_LOWER}.page.title']}" />

        <ui:param name="viewPage" value="#{${REL_LOWER}Page}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />

        <ui:param name="dataView" value="#{viewPage.dataView}" />
        <ui:param name="contentId" value=":data-frm:#{dataView.name}" />
        <ui:param name="notool" value="true" />

        <ui:param name="filter" value="#{dataView.filter}" />
        <ui:param name="filterType" value="overlay" />
        <ui:param name="filterUi" value="/WEB-INF/resources/${MODULE_NAME}/filter/${REL_LOWER}-filterui.xhtml" />
        <ui:include src="/WEB-INF/resources/${MODULE_NAME}/filter/meta/${REL_LOWER}-filterui.xhtml" />

        <ui:param name="sorter" value="#{dataView.sorter}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/sorter.xhtml" />

        <ui:param name="pager" value="#{dataView.pager}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/pager.xhtml" />

        <f:viewParam name="s" value="#{dataView.selectionsInternal}" converter="${REL_CAP}ListConverter"
            transient="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/resources/${MODULE_NAME}/module-menu.xhtml" />
    </ui:define>

    <ui:define name="content">
        <h:form id="data-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/resources/${MODULE_NAME}/list/${REL_LOWER}list.xhtml">
                <ui:param name="dataView" value="#{viewPage.dataView}" />
            </ui:include>
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 5.1 Generate Filter UI Component XHTML
cat <<XHTML > "$COMP_DIR/filter/${REL_LOWER}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:p="primefaces">

    <div class="filter-field">
        <p:outputLabel for="${FROM_ROLE_LOWER}" value="${FROM_ROLE_CAP}" />
        <p:autoComplete id="${FROM_ROLE_LOWER}" value="#{filter.content.${FROM_ROLE_LOWER}}"
                        completeMethod="#{${FROM_ROLE_LOWER}Page.dataView.complete}"
                        var="item" itemLabel="#{item.party.name}" itemValue="#{item}"
                        converter="${FROM_ROLE_CAP}Converter"
                        dropdown="true" forceSelection="true" />
    </div>

    <div class="filter-field">
        <p:outputLabel for="${TO_ROLE_LOWER}" value="${TO_ROLE_CAP}" />
        <p:autoComplete id="${TO_ROLE_LOWER}" value="#{filter.content.${TO_ROLE_LOWER}}"
                        completeMethod="#{${TO_ROLE_LOWER}Page.dataView.complete}"
                        var="item" itemLabel="#{item.party.name}" itemValue="#{item}"
                        converter="${TO_ROLE_CAP}Converter"
                        dropdown="true" forceSelection="true" />
    </div>

</ui:composition>
XHTML

# 5.2 Generate Filter Meta Component XHTML
cat <<XHTML > "$COMP_DIR/filter/meta/${REL_LOWER}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:f="jakarta.faces.core">

    <f:viewParam name="${FROM_ROLE_LOWER}" value="#{filter.content.${FROM_ROLE_LOWER}}" converter="${FROM_ROLE_CAP}Converter" transient="true" />
    <f:viewParam name="${TO_ROLE_LOWER}" value="#{filter.content.${TO_ROLE_LOWER}}" converter="${TO_ROLE_CAP}Converter" transient="true" />

</ui:composition>
XHTML

# 5.3 Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${REL_LOWER}list.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces">

    <ui:decorate template="/WEB-INF/resources/core/base/table.xhtml">
        <ui:define name="columns">
            <p:column headerText="${FROM_ROLE_CAP}">
                <h:outputText value="#{data.fromRole.party.name}" />
            </p:column>
            <p:column headerText="${TO_ROLE_CAP}">
                <h:outputText value="#{data.toRole.party.name}" />
            </p:column>
            <p:column headerText="Since">
                <h:outputText value="#{data.fromDate}" />
            </p:column>
            <p:column headerText="Until">
                <h:outputText value="#{data.thruDate}" />
            </p:column>
        </ui:define>
    </ui:decorate>

</ui:composition>
XHTML
# 5.5. Generate Admin Editor Page XHTML
cat <<XHTML > "$WEB_DIR/view/admin/${REL_LOWER}editor.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:f="jakarta.faces.core"
                xmlns:h="jakarta.faces.html"
                xmlns:p="primefaces"
                xmlns:k="http://xmlns.jcp.org/jsf/composite/kupu"
                template="/WEB-INF/templates/editor-page.xhtml">

    <f:metadata>
        <ui:param name="primaryTitle" value="#{string['${REL_LOWER}.editor.page.title']}" />

        <ui:param name="viewPage" value="#{${REL_LOWER}EditorPage}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />
        
        <f:viewParam name="entity" value="#{viewPage.entity}" converter="${REL_CAP}Converter" transient="true" />

        <f:viewAction action="#{viewPage.load}" />
    </f:metadata>

    <ui:define name="content-header" />

    <ui:define name="form">
        <div class="grid w-full p-3">

            <div class="col-12 md:col-6 md:col-offset-3">
                <ui:decorate template="/WEB-INF/resources/core/base/formlet.xhtml">
                    <ui:define name="fields">

                        <div class="form-field">
                            <p:outputLabel for="fromRole" value="#{string['${REL_LOWER}.fromRole.label']}" />
                            <k:lazySelector id="fromRole"
                                            value="#{viewPage.entity.fromRole ne null ? viewPage.entity.fromRole.party.name : ''}"
                                            selector="${FROM_ROLE_CAP}Selector" required="true"
                                            rendered="#{viewPage.createNew}" />
                            <p:inputText value="#{viewPage.entity.fromRole ne null ? viewPage.entity.fromRole.party.name : ''}"
                                         readonly="true" styleClass="w-full" rendered="#{not viewPage.createNew}" />
                        </div>

                        <div class="form-field">
                            <p:outputLabel for="toRole" value="#{string['${REL_LOWER}.toRole.label']}" />
                            <k:lazySelector id="toRole"
                                            value="#{viewPage.entity.toRole ne null ? viewPage.entity.toRole.party.name : ''}"
                                            selector="${TO_ROLE_CAP}Selector" required="true"
                                            rendered="#{viewPage.createNew}" />
                            <p:inputText value="#{viewPage.entity.toRole ne null ? viewPage.entity.toRole.party.name : ''}"
                                         readonly="true" styleClass="w-full" rendered="#{not viewPage.createNew}" />
                        </div>

                        <div class="form-field">
                            <p:outputLabel for="fromDate" value="#{string['${REL_LOWER}.fromDate.label']}" />
                            <p:datePicker id="fromDate" value="#{viewPage.entity.fromDate}"
                                          flex="true" inputStyleClass="w-full"
                                          readonly="#{not viewPage.createNew}"
                                          pattern="dd/MM/yyyy" showTime="false" monthNavigator="true" yearNavigator="true"
                                          required="true" >
                                <p:ajax />
                            </p:datePicker>
                        </div>

                        <div class="form-field">
                            <p:outputLabel for="thruDate" value="#{string['${REL_LOWER}.thruDate.label']}" />
                            <div class="flex">
                                <p:datePicker id="thruDate" value="#{viewPage.entity.thruDate}"
                                              flex="true" inputStyleClass="w-full"
                                              pattern="dd/MM/yyyy" showTime="false"
                                              monthNavigator="true" yearNavigator="true"
                                              class="flex-grow-1" />
                                <p:commandButton icon="pi pi-refresh" actionListener="#{viewPage.resetThruDate}"
                                                 rendered="#{not (viewPage.entity.thruDate eq null)}" update="thruDate" />
                            </div>
                        </div>

                    </ui:define>
                </ui:decorate>
            </div>

        </div>
    </ui:define>

    <ui:define name="util">
        <h:form>
            <k:selectorDialog selector="${FROM_ROLE_CAP}Selector" widgetVar="${FROM_ROLE_LOWER}Selector" chooser="#{viewPage.fromRoleChooser}"
                              styleClass="w-5">
                <p:dataTable var="data" value="#{viewPage.fromRoleChooser.list.model}" selectionMode="single"
                             selection="#{viewPage.fromRoleChooser.selected}" scrollRows="10" scrollable="true" liveScroll="true"
                             scrollHeight="200">

                    <p:ajax event="rowSelect" listener="#{viewPage.fromRoleChooser.onSave}"
                            oncomplete="PF('${FROM_ROLE_LOWER}Selector').hide()" />

                    <f:facet name="header">
                        <span class="ui-input-icon-left w-full">
                            <i class="pi pi-search" />
                            <p:inputText value="#{viewPage.fromRoleChooser.searchTerm}" immediate="true" class="w-full">
                                <p:ajax event="keyup" update="@parent:@parent" delay="300" />
                            </p:inputText>
                        </span>
                    </f:facet>
                    <p:column headerText="Id">
                        <h:outputText value="#{data.id}" />
                    </p:column>
                    <p:column headerText="Name">
                        <h:outputText value="#{data.party.name}" />
                    </p:column>
                </p:dataTable>
            </k:selectorDialog>
        </h:form>

        <h:form>
            <k:selectorDialog selector="${TO_ROLE_CAP}Selector" widgetVar="${TO_ROLE_LOWER}Selector" chooser="#{viewPage.toRoleChooser}"
                              styleClass="w-5">
                <p:dataTable var="data" value="#{viewPage.toRoleChooser.list.model}" selectionMode="single"
                             selection="#{viewPage.toRoleChooser.selected}" scrollRows="10" scrollable="true" liveScroll="true"
                             scrollHeight="200">

                    <p:ajax event="rowSelect" listener="#{viewPage.toRoleChooser.onSave}"
                            oncomplete="PF('${TO_ROLE_LOWER}Selector').hide()" />

                    <f:facet name="header">
                        <span class="ui-input-icon-left w-full">
                            <i class="pi pi-search" />
                            <p:inputText value="#{viewPage.toRoleChooser.searchTerm}" immediate="true" class="w-full">
                                <p:ajax event="keyup" update="@parent:@parent" delay="300" />
                            </p:inputText>
                        </span>
                    </f:facet>
                    <p:column headerText="Id">
                        <h:outputText value="#{data.id}" />
                    </p:column>
                    <p:column headerText="Name">
                        <h:outputText value="#{data.party.name}" />
                    </p:column>
                </p:dataTable>
            </k:selectorDialog>
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 6. Register in Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if ! grep -q "Navigator\.open('${REL_CAP}'," "$MENU_FILE"; then
        sed -i "/<\/ui:composition>/i \    <p:menuitem value=\"#{string['${REL_LOWER}.page.title']}\" icon=\"pi pi-link\" actionListener=\"#{${MODULE_NAME}Navigator.open('${REL_CAP}', '')}\" immediate=\"true\" />" "$MENU_FILE"
        echo "Registered ${REL_CAP} in $MENU_FILE"
    fi
fi

# 7. Register in Navigator
NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_NAME^}Navigator.java"
if [ -f "$NAVIGATOR_FILE" ]; then
    if ! grep -q "case \"${REL_CAP}\"" "$NAVIGATOR_FILE"; then
         sed -i "/switch.*(pageId).* {/a \\            case \"${REL_CAP}\": return ${BASE_PACKAGE}.view.${REL_CAP}Page.class;" "$NAVIGATOR_FILE"
         echo "Registered ${REL_CAP} in $NAVIGATOR_FILE"
    fi
fi

# 8. Register Module Type
MODULE_FILE="$JAVA_DIR/${MODULE_NAME^}Module.java"
if [ -f "$MODULE_FILE" ]; then
    # Inject PartyRelationshipTypeFacade if not present
    if ! grep -q "PartyRelationshipTypeFacade" "$MODULE_FILE"; then
        sed -i "/package ${BASE_PACKAGE};/a import id.my.mdn.kupu.core.party.dao.PartyRelationshipTypeFacade;" "$MODULE_FILE"
        sed -i "/public class/a \    @Inject\n    private PartyRelationshipTypeFacade partyRelationshipTypeFacade;" "$MODULE_FILE"
    fi
    
    # Add creation in postInit
    if ! grep -q "\"${REL_UPPER}\"" "$MODULE_FILE"; then
        if grep -q "protected void postInit().*{}" "$MODULE_FILE"; then
            sed -i "s/.*protected void postInit().*{}.*/    @Override\n    protected void postInit() {\n        partyRelationshipTypeFacade.createTypeIfNotExist(\"${REL_UPPER}\", \"${REL_CAP}\");\n    }/" "$MODULE_FILE"
        elif ! grep -q "protected void postInit()" "$MODULE_FILE"; then
             sed -i "\$ d" "$MODULE_FILE"
             cat <<JAVA >> "$MODULE_FILE"

    @Override
    protected void postInit() {
        partyRelationshipTypeFacade.createTypeIfNotExist("${REL_UPPER}", "${REL_CAP}");
    }
}
JAVA
        else
            sed -i "/protected void postInit().*{/a \\        partyRelationshipTypeFacade.createTypeIfNotExist(\"${REL_UPPER}\", \"${REL_CAP}\");" "$MODULE_FILE"
        fi
        echo "Registered RelationshipType registration in $MODULE_FILE"
    fi
fi

# 9. Update persistence.xml (handled by start script or checking?)
# Assuming standard build process updates persistence.xml or we trigger it.
# mvn clean package usually triggers persistence generation if configured.

chmod +x "$WEB_DIR/view/${REL_LOWER}.xhtml"
chmod +x "$WEB_DIR/view/admin/${REL_LOWER}editor.xhtml"

# 10. Update i18n properties
REL_LABEL=$(echo "${RELATIONSHIP_NAME}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')
FROM_ROLE_LABEL=$(echo "${FROM_ROLE}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')
TO_ROLE_LABEL=$(echo "${TO_ROLE}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')

for PROPS_FILE in "$RES_DIR/string_en.properties" "$RES_DIR/string_id.properties"; do
    if [ -f "$PROPS_FILE" ]; then
        if ! grep -q "^${REL_LOWER}.page.title=" "$PROPS_FILE"; then
            echo "${REL_LOWER}.page.title=${REL_LABEL}" >> "$PROPS_FILE"
            echo "${REL_LOWER}.editor.page.title=${REL_LABEL} Editor" >> "$PROPS_FILE"
            echo "${REL_LOWER}.fromRole.label=${FROM_ROLE_LABEL}" >> "$PROPS_FILE"
            echo "${REL_LOWER}.toRole.label=${TO_ROLE_LABEL}" >> "$PROPS_FILE"
            echo "${REL_LOWER}.fromDate.label=From Date" >> "$PROPS_FILE"
            echo "${REL_LOWER}.thruDate.label=Thru Date" >> "$PROPS_FILE"
            echo "Updated i18n keys in $PROPS_FILE"
        fi
    fi
done

echo "Relationship ${REL_CAP} created successfully." 
