#!/bin/bash

# Kupu Web Entity View Generator
# Generates Facade, Filter, List Bean, Page Controller, and XHTMLs

# Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package>

MODULE_NAME=$1
ENTITY_NAME=$2
ENTITY_PKG=$3

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ] || [ -z "$ENTITY_PKG" ]; then
    echo "Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package>"
    exit 1
fi

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LOWER=$(echo "$ENTITY_NAME" | sed 's/./\L&/')

# Paths for kupu-web
MODULE_ROOT="."
JAVA_DIR="$MODULE_ROOT/src/main/java/id/my/mdn/kupu/app/$MODULE_NAME"
VIEW_BASE_DIR="$MODULE_ROOT/src/main/webapp"
BASE_PACKAGE="id.my.mdn.kupu.app.$MODULE_NAME"
VIEW_NS_PATH="/app/$MODULE_NAME"

# Directories
JAVA_SUBDIR="$JAVA_DIR"
RES_DIR="$MODULE_ROOT/src/main/resources/$(echo "$BASE_PACKAGE" | tr '.' '/')"
WEB_DIR="$VIEW_BASE_DIR$VIEW_NS_PATH"

mkdir -p "$JAVA_SUBDIR"/{dao,view/filter,view/list,view/admin,view/converter}
mkdir -p "$RES_DIR"
mkdir -p "$WEB_DIR/view/admin"

# 1. Generate Facade
cat <<JAVA > "$JAVA_SUBDIR/dao/${ENTITY_CAP}Facade.java"
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

    @Inject
    private EntityManager em;

    @Override
    protected EntityManager getEntityManager() { return em; }

    public ${ENTITY_CAP}Facade() { super(${ENTITY_CAP}.class); }
}
JAVA

# 2. Generate List Bean (IValueList)
cat <<JAVA > "$JAVA_SUBDIR/view/list/${ENTITY_CAP}List.java"
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

    @Inject
    private ${ENTITY_CAP}Facade dao;

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

# 3. Generate Page
cat <<JAVA > "$JAVA_SUBDIR/view/admin/${ENTITY_CAP}Page.java"
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

    @Inject @Bookmarked
    private ${ENTITY_CAP}List dataView;

    public ${ENTITY_CAP}List getDataView() { return dataView; }
}
JAVA

echo "Successfully generated web entity components"
