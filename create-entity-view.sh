#!/bin/bash

# Kupu Application Entity View Generator
# Generates Facade, Filter, List Bean, Page Controller, and XHTMLs

# Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package>

# 1. Load configuration
if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found."
    exit 1
fi

MODULE_NAME=$1
ENTITY_NAME=$2
ENTITY_PKG=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ] || [ -z "$ENTITY_PKG" ]; then
    echo "Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package>"
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

# Define paths
BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp"
VIEW_NS_PATH="/app/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/components/app/$MODULE_NAME"

mkdir -p "$JAVA_DIR"/{dao,view/filter,view/list,view/admin,view/converter}
mkdir -p "$RES_DIR"
mkdir -p "$VIEW_BASE_DIR$VIEW_NS_PATH/view/admin"
mkdir -p "$COMP_DIR"/{list,editor}

# 1. Generate Facade
cat <<JAVA > "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
package ${BASE_PACKAGE}.dao;

import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.dao.AbstractFacade;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

@ApplicationScoped
@Transactional
public class ${ENTITY_CAP}Facade extends AbstractFacade<${ENTITY_CAP}> {
    @Inject private EntityManager em;
    @Override protected EntityManager getEntityManager() { return em; }
    public ${ENTITY_CAP}Facade() { super(${ENTITY_CAP}.class); }
}
JAVA

# 2. Generate List Bean (IValueList)
cat <<JAVA > "$JAVA_DIR/view/list/${ENTITY_CAP}List.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.dao.AbstractFacade.DefaultChecker;
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.view.widget.AbstractMutablePagedValueList;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.util.List;
import java.util.Map;

@Named(value = "${ENTITY_LOWER}List")
@Dependent
public class ${ENTITY_CAP}List extends AbstractMutablePagedValueList<${ENTITY_CAP}> {
    @Inject private ${ENTITY_CAP}Facade dao;
    public ${ENTITY_CAP}List() { super(${ENTITY_CAP}.class); }
    @Override
    protected List<${ENTITY_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ENTITY_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }
    @Override
    public long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }
}
JAVA

# 3. Generate Page Controller
cat <<JAVA > "$JAVA_DIR/view/admin/${ENTITY_CAP}Page.java"
package ${BASE_PACKAGE}.view.admin;

import ${BASE_PACKAGE}.view.list.${ENTITY_CAP}List;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "${ENTITY_LOWER}Page")
@ViewScoped
public class ${ENTITY_CAP}Page extends Page implements Serializable {
    @Inject @Bookmarked private ${ENTITY_CAP}List dataView;
    public ${ENTITY_CAP}List getDataView() { return dataView; }
}
JAVA

# 4. Generate Converter
cat <<JAVA > "$JAVA_DIR/view/converter/${ENTITY_CAP}Converter.java"
package ${BASE_PACKAGE}.view.converter;

import ${ENTITY_PKG}.${ENTITY_CAP};
import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
@Transactional
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

# 5. Generate List Converter
cat <<JAVA > "$JAVA_DIR/view/converter/${ENTITY_CAP}ListConverter.java"
package ${BASE_PACKAGE}.view.converter;

import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.view.converter.AbstractListConverter;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.convert.FacesConverter;

@ApplicationScoped
@FacesConverter(managed = true, value = "${ENTITY_CAP}ListConverter")
public class ${ENTITY_CAP}ListConverter extends AbstractListConverter<${ENTITY_CAP}> {

    public ${ENTITY_CAP}ListConverter() {
        super(${ENTITY_CAP}.class);
    }
}
JAVA

# 6. Generate Admin XHTML
cat <<XHTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/admin/${ENTITY_LOWER}admin.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                xmlns:k="jakarta.faces.composite/WEB-INF/components"
                template="/WEB-INF/template/template.xhtml">

    <ui:define name="title">
        #{msg['${MODULE_NAME}.${ENTITY_LOWER}.admin.title']}
    </ui:define>

    <ui:define name="content">
        <h:form id="${ENTITY_LOWER}ListForm">
            <k:app/${MODULE_NAME}/list/${ENTITY_LOWER}list id="${ENTITY_LOWER}List"
                                                    value="#{${ENTITY_LOWER}Page.dataView}" />
        </h:form>

        <h:form id="${ENTITY_LOWER}EditorForm">
            <k:app/${MODULE_NAME}/editor/${ENTITY_LOWER}editor id="${ENTITY_LOWER}Editor" />
        </h:form>
    </ui:define>

</ui:composition>
XHTML

# 7. Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${ENTITY_LOWER}list.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                xmlns:composite="jakarta.faces.composite">

    <composite:interface>
        <composite:attribute name="value" type="id.my.mdn.kupu.core.base.view.widget.IValueList" required="true" />
    </composite:interface>

    <composite:implementation>
        <p:dataTable id="table" value="#{cc.attrs.value}" var="item"
                     paginator="true" rows="10" lazy="true"
                     paginatorTemplate="{CurrentPageReport} {FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink} {RowsPerPageDropdown}"
                     currentPageReportTemplate="{startRecord}-{endRecord} of {totalRecords} records"
                     rowsPerPageTemplate="5,10,20,50">
            
            <p:column headerText="ID">
                <h:outputText value="#{item.id}" />
            </p:column>
            
            <!-- Add more columns as needed -->
            
        </p:dataTable>
    </composite:implementation>

</ui:composition>
XHTML

# 8. Generate Editor Component XHTML
cat <<XHTML > "$COMP_DIR/editor/${ENTITY_LOWER}editor.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:h="jakarta.faces.html"
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                xmlns:composite="jakarta.faces.composite">

    <composite:interface>
    </composite:interface>

    <composite:implementation>
        <p:dialog id="dialog" header="${ENTITY_CAP} Editor" widgetVar="${ENTITY_LOWER}Editor"
                  modal="true" responsive="true">
            <h:panelGroup id="panel">
                <!-- Add editor fields here -->
            </h:panelGroup>
            
            <f:facet name="footer">
                <p:commandButton value="Save" icon="pi pi-check" />
                <p:commandButton value="Cancel" icon="pi pi-times" onclick="PF('${ENTITY_LOWER}Editor').hide()" type="button" />
            </f:facet>
        </p:dialog>
    </composite:implementation>

</ui:composition>
XHTML

echo "Successfully generated application entity components in $BASE_PACKAGE"
