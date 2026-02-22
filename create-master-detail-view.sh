#!/bin/bash

# Kupu Master-Detail View Generator
# Generates a composite view controller and template connecting two entities via OneToMany
# Usage: ./create-master-detail-view.sh <module_name> <master_entity> <detail_entity> <mapped_by_field> [page_name]

if [ -f ".generator-config" ]; then
    APP_PACKAGE=$(cat .generator-config | head -1)
else
    echo "Error: .generator-config not found. Are you in a Kupu application directory?"
    exit 1
fi

MODULE_NAME=$1
MASTER_ENTITY=$2
DETAIL_ENTITY=$3
MAPPED_BY_FIELD=$4
CUSTOM_PAGE_NAME=$5

if [ -z "$MODULE_NAME" ] || [ -z "$MASTER_ENTITY" ] || [ -z "$DETAIL_ENTITY" ] || [ -z "$MAPPED_BY_FIELD" ]; then
    echo "Usage: ./create-master-detail-view.sh <module_name> <master_entity> <detail_entity> <mapped_by_field> [page_name]"
    exit 1
fi

MASTER_CAP=$(echo "$MASTER_ENTITY" | sed 's/./\U&/')
MASTER_LOWER_CAMEL=$(echo "$MASTER_ENTITY" | sed 's/./\L&/')
MASTER_FILE_BASE=$(echo "$MASTER_ENTITY" | tr '[:upper:]' '[:lower:]')

DETAIL_CAP=$(echo "$DETAIL_ENTITY" | sed 's/./\U&/')
DETAIL_LOWER_CAMEL=$(echo "$DETAIL_ENTITY" | sed 's/./\L&/')
DETAIL_FILE_BASE=$(echo "$DETAIL_ENTITY" | tr '[:upper:]' '[:lower:]')

MAPPED_CAP=$(echo "$MAPPED_BY_FIELD" | sed 's/./\U&/')

MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
PKG_PATH=$(echo "$APP_PACKAGE" | tr . /)

BASE_PACKAGE="$APP_PACKAGE.$MODULE_NAME"
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/WEB-INF/resources/app/$MODULE_NAME"
VIEW_BASE_DIR="src/main/webapp/$MODULE_NAME"

MASTER_LIST_SUFFIX="List"
if [ -f "$JAVA_DIR/view/list/${MASTER_CAP}Tree.java" ]; then
    MASTER_LIST_SUFFIX="Tree"
fi

DETAIL_LIST_SUFFIX="List"
if [ -f "$JAVA_DIR/view/list/${DETAIL_CAP}Tree.java" ]; then
    DETAIL_LIST_SUFFIX="Tree"
fi

MASTER_ENTITY_PKG=$(find src/main/java -name "${MASTER_CAP}.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${MASTER_CAP}';/')
DETAIL_ENTITY_PKG=$(find src/main/java -name "${DETAIL_CAP}.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${DETAIL_CAP}';/')
DETAIL_FILTER_PKG=$(find src/main/java -name "${DETAIL_CAP}Filter.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${DETAIL_CAP}Filter';/')

if [ -n "$CUSTOM_PAGE_NAME" ]; then
    PAGE_NAME="${CUSTOM_PAGE_NAME}"
    PAGE_FILE_BASE=$(echo "$PAGE_NAME" | tr '[:upper:]' '[:lower:]')
    PAGE_BEAN=$(echo "$PAGE_NAME" | sed 's/./\L&/')
else
    PAGE_NAME="${MASTER_CAP}${DETAIL_CAP}"
    PAGE_FILE_BASE="${MASTER_FILE_BASE}${DETAIL_FILE_BASE}"
    PAGE_BEAN="${MASTER_LOWER_CAMEL}${DETAIL_CAP}Page"
fi

# 1. Generate Page Controller
cat <<JAVA > "$JAVA_DIR/view/${PAGE_NAME}Page.java"
package ${BASE_PACKAGE}.view;

$MASTER_ENTITY_PKG
$DETAIL_ENTITY_PKG
$DETAIL_FILTER_PKG
import ${BASE_PACKAGE}.view.list.${MASTER_CAP}${MASTER_LIST_SUFFIX};
import ${BASE_PACKAGE}.view.list.${DETAIL_CAP}${DETAIL_LIST_SUFFIX};
import ${BASE_PACKAGE}.view.admin.${MASTER_CAP}EditorPage;
import ${BASE_PACKAGE}.view.admin.${DETAIL_CAP}EditorPage;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import id.my.mdn.kupu.core.base.view.annotation.Creator;
import id.my.mdn.kupu.core.base.view.annotation.Editor;
import id.my.mdn.kupu.core.base.view.annotation.Deleter;
import static id.my.mdn.kupu.core.base.view.widget.Selector.SINGLE;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;
import java.util.List;

@Named(value = "${PAGE_BEAN}")
@ViewScoped
public class ${PAGE_NAME}Page extends Page implements Serializable {

    @Inject
    @Bookmarked
    private ${MASTER_CAP}${MASTER_LIST_SUFFIX} masterDataView;
    
    @Inject
    @Bookmarked
    private ${DETAIL_CAP}${DETAIL_LIST_SUFFIX} detailDataView;

    @Override
    @PostConstruct
    public void init() {
        super.init();
        
        masterDataView.setSelectionMode(() -> SINGLE);
        masterDataView.getSelector().setSelectionsLabel("ms");
        masterDataView.getPager().setPageSizeLabel("mp");
        masterDataView.getPager().setOffsetLabel("mo");
        masterDataView.getSelector().addListener((s) -> onSelect${MASTER_CAP}((${MASTER_CAP}) s));
        masterDataView.getSelector().addListenerInternal((s) -> onSelect${MASTER_CAP}((${MASTER_CAP}) s));

        detailDataView.setSelectionsLabel("ds");
        detailDataView.setDefaultChecker(() -> masterDataView.getSelected() == null);
        detailDataView.setDefaultList(() -> List.of());
    }

    private void onSelect${MASTER_CAP}(${MASTER_CAP} selection) {
        detailDataView.getFilter()
                .<${DETAIL_CAP}Filter>getContent()
                .set${MAPPED_CAP}(selection);
        detailDataView.doFilter();
    }

    public ${MASTER_CAP}${MASTER_LIST_SUFFIX} getMasterDataView() { return masterDataView; }
    public ${DETAIL_CAP}${DETAIL_LIST_SUFFIX} getDetailDataView() { return detailDataView; }

    @Creator(of = "masterDataView")
    public void openMasterCreator() {
        gotoChild(${MASTER_CAP}EditorPage.class).open();
    }

    @Editor(of = "masterDataView")
    public void openMasterEditor() {
        gotoChild(${MASTER_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(masterDataView.getSelected())
                .open();
    }

    @Deleter(of = "masterDataView")
    public void openMasterDeleter() {
        masterDataView.deleteSelected();
    }
    
    @Creator(of = "detailDataView")
    public void openDetailCreator() {
        gotoChild(${DETAIL_CAP}EditorPage.class)
                .addParam("${MAPPED_BY_FIELD}")
                .withValues(masterDataView.getSelected())
                .open();
    }

    @Editor(of = "detailDataView")
    public void openDetailEditor() {
        gotoChild(${DETAIL_CAP}EditorPage.class)
                .addParam("entity")
                .withValues(detailDataView.getSelected())
                .open();
    }

    @Deleter(of = "detailDataView")
    public void openDetailDeleter() {
        detailDataView.deleteSelected();
    }
}
JAVA

# 2. Generate Explorer XHTML Layout
mkdir -p "$VIEW_BASE_DIR/view"

cat <<XHTML > "$VIEW_BASE_DIR/view/${PAGE_FILE_BASE}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:f="jakarta.faces.core"
                xmlns:h="jakarta.faces.html"
                xmlns:p="primefaces"
                template="/WEB-INF/resources/core/base/explorer.xhtml">

    <f:metadata>
        <ui:param name="viewPage" value="#{${PAGE_BEAN}}" />
        <ui:param name="title" value="${PAGE_NAME}" />
        
        <ui:param name="masterTitle" value="${MASTER_CAP}" />
        <ui:param name="masterDataView" value="#{viewPage.masterDataView}" />
        <ui:param name="masterContentId" value=":master-frm:#{masterDataView.name}" />
        <ui:param name="masterFilter" value="#{masterDataView.filter}" />
        <ui:param name="masterFilterType" value="overlay" />
        <ui:param name="masterFilterUi" value="/WEB-INF/resources/app/${MODULE_NAME}/filter/${MASTER_FILE_BASE}-filterui.xhtml" />
        <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/filter/meta/${MASTER_FILE_BASE}-filterui.xhtml">
            <ui:param name="filter" value="#{masterFilter}" />
        </ui:include>
        <ui:param name="master_notool" value="true" />
        <f:viewParam name="ms" value="#{masterDataView.selectionInternal}" converter="${MASTER_CAP}Converter" transient="true" />

        <ui:param name="masterPager" value="#{masterDataView.pager}" />
        <f:viewParam name="mp" value="#{masterPager.pageSize}" converter="LongConverter" transient="true" />
        <f:viewParam name="mo" value="#{masterPager.offset}" converter="LongConverter" transient="true" />         

        <ui:param name="detailTitle" value="${DETAIL_CAP}" />
        <ui:param name="detailDataView" value="#{viewPage.detailDataView}" />
        <ui:param name="detailContentId" value=":detail-frm:#{detailDataView.name}" />
        <ui:param name="detailFilter" value="#{detailDataView.filter}" />
        <ui:param name="detailFilterType" value="overlay" />
        <ui:param name="detailFilterUi" value="/WEB-INF/resources/app/${MODULE_NAME}/filter/${DETAIL_FILE_BASE}-filterui.xhtml" />
        <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/filter/meta/${DETAIL_FILE_BASE}-filterui.xhtml">
            <ui:param name="filter" value="#{detailFilter}" />
        </ui:include>       
        <ui:param name="detail_notool" value="true" />
$(if [ "$DETAIL_LIST_SUFFIX" = "List" ]; then echo "
        <ui:param name=\"detailPager\" value=\"#{detailDataView.pager}\" />
        <f:viewParam name=\"dp\" value=\"#{detailPager.pageSize}\" converter=\"LongConverter\" transient=\"true\" />
        <f:viewParam name=\"do\" value=\"#{detailPager.offset}\" converter=\"LongConverter\" transient=\"true\" />"; fi)

        <f:viewParam name="ds" value="#{detailDataView.selectionsInternal}" converter="${DETAIL_CAP}ListConverter" transient="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/module-menu.xhtml" />
    </ui:define>

    <ui:define name="master">
        <h:form id="master-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/list/${MASTER_FILE_BASE}$(echo "$MASTER_LIST_SUFFIX" | tr '[:upper:]' '[:lower:]').xhtml">
                <ui:param name="dataView" value="#{masterDataView}" />
                <ui:param name="selectCallback" value="refreshDetail()" />
                <ui:param name="tableStyle" value="noheader" />
            </ui:include>
        </h:form>
    </ui:define>

    <ui:define name="detail">
        <h:form id="detail-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/resources/app/${MODULE_NAME}/list/${DETAIL_FILE_BASE}$(echo "$DETAIL_LIST_SUFFIX" | tr '[:upper:]' '[:lower:]').xhtml">
                <ui:param name="dataView" value="#{detailDataView}" />
            </ui:include>
        </h:form>
    </ui:define>

$(if [ "$MASTER_LIST_SUFFIX" = "Tree" ]; then echo "    <ui:define name=\"master-pager\" />"; fi)
$(if [ "$DETAIL_LIST_SUFFIX" = "Tree" ]; then echo "    <ui:define name=\"detail-pager\" />"; fi)
</ui:composition>
XHTML

# 4. Register in Navigator
NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
if [ -f "$NAVIGATOR_FILE" ]; then
    if ! grep -q "case \"${PAGE_NAME}\":" "$NAVIGATOR_FILE"; then
        sed -i "/switch.*(pageId).* {/a \            case \"${PAGE_NAME}\": return ${BASE_PACKAGE}.view.${PAGE_NAME}Page.class;" "$NAVIGATOR_FILE"
        echo "Registered ${PAGE_NAME} in $NAVIGATOR_FILE"
    fi
fi

# 5. Register in Menu
MENU_FILE="$WEB_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if ! grep -q "value=\"${PAGE_NAME}\"" "$MENU_FILE"; then
        sed -i "/<\/ui:composition>/i \    <p:menuitem value=\"${PAGE_NAME}\" icon=\"pi pi-sitemap\" actionListener=\"#{${MODULE_NAME}Navigator.open('${PAGE_NAME}', '')}\" immediate=\"true\" />" "$MENU_FILE"
        echo "Registered ${PAGE_NAME} in $MENU_FILE"
    fi
fi

chmod +x "$0"
echo "Successfully generated master-detail view components for $PAGE_NAME in $BASE_PACKAGE"

