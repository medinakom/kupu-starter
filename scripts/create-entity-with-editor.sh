#!/bin/bash

# Kupu Application Entity with Editor View Generator
# Usage: ./create-entity-with-editor.sh <module_name> <entity_name>

# 1. Load configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/.generator-config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: .generator-config not found at $CONFIG_FILE. Are you in a Kupu application directory?"
    exit 1
fi

BASE_PACKAGE=$(cat "$CONFIG_FILE" | head -1)

cd "$PROJECT_ROOT"

MODULE_NAME=""
ENTITY_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Kupu Application Entity & Editor View Generator"
            echo "Generates a JPA Entity, its Facade, Faces Converter, conversation-scoped EditorPage,"
            echo "and XHTML editor view, and registers/saves matching localized labels."
            echo ""
            echo "Usage: $(basename "$0") <module_name> <entity_name>"
            echo ""
            echo "Options:"
            echo "  -h, --help           Display this help message"
            echo ""
            echo "Arguments:"
            echo "  module_name          Name of the target sub-module (lowercase, e.g. 'pelanggan')"
            echo "  entity_name          Name of the Entity class (CamelCase, e.g. 'StatusPelanggan')"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") pelanggan StatusPelanggan"
            exit 0
            ;;
        *)
            if [ -z "$MODULE_NAME" ]; then MODULE_NAME=$1
            elif [ -z "$ENTITY_NAME" ]; then ENTITY_NAME=$1
            fi
            ;;
    esac
    shift
done

if [ -z "$MODULE_NAME" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Error: Both module_name and entity_name are required."
    echo "Usage: $(basename "$0") <module_name> <entity_name>"
    echo "Run '$(basename "$0") --help' for details and examples."
    exit 1
fi

# Define naming variables
ENTITY_LABEL=$(echo "${ENTITY_NAME}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')
ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
ENTITY_UPPER=$(echo "$ENTITY_NAME" | tr '[:lower:]' '[:upper:]')
MODULE_UPPERCASE=$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')
MODULE_CAPITALIZED=$(echo "$MODULE_NAME" | sed 's/./\U&/')

PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Define paths
JAVA_DIR="src/main/java/$PKG_PATH/$MODULE_NAME"
RES_DIR="src/main/resources/$PKG_PATH/$MODULE_NAME"
WEB_DIR="src/main/webapp/$MODULE_NAME"

# Check if module exists
if [ ! -d "$JAVA_DIR" ]; then
    echo "Error: Sub-module directory '$JAVA_DIR' does not exist."
    echo "Please create the module first using: ./scripts/create-module.sh $MODULE_NAME"
    exit 1
fi

# Discover table prefix
TABLE_PREFIX=""
SUB_CONFIG_FILE="$RES_DIR/.generator-config"
if [ -f "$SUB_CONFIG_FILE" ]; then
    TABLE_PREFIX=$(grep "^TABLE_PREFIX=" "$SUB_CONFIG_FILE" | cut -d'=' -f2)
fi
TABLE_PREFIX=${TABLE_PREFIX:-$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')}

if command -v python3 &>/dev/null; then
    TABLE_PREFIX_CAP=$(python3 -c "print('${TABLE_PREFIX}'.title())" 2>/dev/null || echo "${TABLE_PREFIX}")
else
    TABLE_PREFIX_CAP=$(echo "${TABLE_PREFIX}" | tr '[:upper:]' '[:lower:]' | sed 's/\(.\).*/\1/' | tr '[:lower:]' '[:upper:]')$(echo "${TABLE_PREFIX}" | tr '[:upper:]' '[:lower:]' | sed 's/.\(.*\)/\1/')
fi

echo "Generating files for ${ENTITY_NAME} in module ${MODULE_NAME}..."

# Create target directories
mkdir -p "$JAVA_DIR/entity"
mkdir -p "$JAVA_DIR/dao"
mkdir -p "$JAVA_DIR/view/converter"
mkdir -p "$JAVA_DIR/view/admin"
mkdir -p "$WEB_DIR/view/admin"
mkdir -p "$RES_DIR"

# 1. Generate Entity Java class
cat <<EOF > "$JAVA_DIR/entity/${ENTITY_NAME}.java"
package ${BASE_PACKAGE}.${MODULE_NAME}.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.TableGenerator;
import java.io.Serializable;

@Entity
@Table(name = "${TABLE_PREFIX}_${ENTITY_UPPER}")
public class ${ENTITY_NAME} implements Serializable {

    private static final long serialVersionUID = 1L;
    
    @Id
    @TableGenerator(name = "${TABLE_PREFIX_CAP}_${ENTITY_NAME}", table = "KEYGEN", allocationSize = 1)
    @GeneratedValue(generator = "${TABLE_PREFIX_CAP}_${ENTITY_NAME}", strategy = GenerationType.TABLE)
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
        int hash = 0;
        hash += (id != null ? id.hashCode() : 0);
        return hash;
    }

    @Override
    public boolean equals(Object object) {
        if (!(object instanceof ${ENTITY_NAME})) {
            return false;
        }
        ${ENTITY_NAME} other = (${ENTITY_NAME}) object;
        return !((this.id == null && other.id != null) || (this.id != null && !this.id.equals(other.id)));
    }

    @Override
    public String toString() {
        return id != null ? id.toString() : null;
    }
    
}
EOF
echo "Generated Entity at: $JAVA_DIR/entity/${ENTITY_NAME}.java"

# 2. Generate Facade Java class
cat <<EOF > "$JAVA_DIR/dao/${ENTITY_NAME}Facade.java"
package ${BASE_PACKAGE}.${MODULE_NAME}.dao;

import id.my.mdn.kupu.core.base.dao.AbstractFacade;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.From;
import jakarta.persistence.criteria.Predicate;
import ${BASE_PACKAGE}.${MODULE_NAME}.entity.${ENTITY_NAME};

@ApplicationScoped
public class ${ENTITY_NAME}Facade extends AbstractFacade<${ENTITY_NAME}> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    public ${ENTITY_NAME}Facade() {
        super(${ENTITY_NAME}.class);
    }

    @Override
    protected EntityManager getEntityManager() {
        return em;
    }

    @Override
    protected Predicate applyFilter(String filterName, Object filterValue, CriteriaQuery cq, From... froms) {

        switch (filterName) {
            default:
                return super.applyFilter(filterName, filterValue, cq, froms);
        }
    }

    @Override
    protected Expression orderExpression(String field, From... froms) {
        switch (field) {
            default:
                return super.orderExpression(field, froms);
        }
    }
    
}
EOF
echo "Generated Facade at: $JAVA_DIR/dao/${ENTITY_NAME}Facade.java"

# 3. Generate Converter Java class
cat <<EOF > "$JAVA_DIR/view/converter/${ENTITY_NAME}Converter.java"
package ${BASE_PACKAGE}.${MODULE_NAME}.view.converter;

import id.my.mdn.kupu.core.base.util.K.KLong;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import ${BASE_PACKAGE}.${MODULE_NAME}.dao.${ENTITY_NAME}Facade;
import ${BASE_PACKAGE}.${MODULE_NAME}.entity.${ENTITY_NAME};

@Singleton
@FacesConverter(managed = true, value = "${ENTITY_NAME}Converter")
public class ${ENTITY_NAME}Converter implements Converter<${ENTITY_NAME}> {

    @Inject
    private ${ENTITY_NAME}Facade dao;

    @Override
    public ${ENTITY_NAME} getAsObject(FacesContext context, UIComponent component, String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        return dao.find(KLong.valueOf(value));
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, ${ENTITY_NAME} value) {
        return value != null ? value.toString() : null;
    }
}
EOF
echo "Generated Converter at: $JAVA_DIR/view/converter/${ENTITY_NAME}Converter.java"

# 4. Generate EditorPage Java class
cat <<EOF > "$JAVA_DIR/view/admin/${ENTITY_NAME}EditorPage.java"
package ${BASE_PACKAGE}.${MODULE_NAME}.view.admin;

import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.FormPage;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import ${BASE_PACKAGE}.${MODULE_NAME}.dao.${ENTITY_NAME}Facade;
import ${BASE_PACKAGE}.${MODULE_NAME}.entity.${ENTITY_NAME};

@Named
@ConversationScoped
public class ${ENTITY_NAME}EditorPage extends FormPage<${ENTITY_NAME}> {

    @Inject
    private ${ENTITY_NAME}Facade dao;

    @PostConstruct
    @Override
    protected void init() {
        super.init();
    }

    @Override
    protected ${ENTITY_NAME} newEntity() {        
        ${ENTITY_NAME} newEntity = new ${ENTITY_NAME}();
        
        return newEntity;
    }

    @Override
    protected Result<String> save(${ENTITY_NAME} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> edit(${ENTITY_NAME} entity) {
        return dao.edit(entity);
    }
}
EOF
echo "Generated EditorPage at: $JAVA_DIR/view/admin/${ENTITY_NAME}EditorPage.java"

# 5. Generate Editor XHTML
cat <<EOF > "$WEB_DIR/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
<ui:composition template="/WEB-INF/templates/editor-page.xhtml" 
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:f="jakarta.faces.core"
                xmlns:p="primefaces"
                xmlns:k="http://xmlns.jcp.org/jsf/composite/kupu" 
                xmlns:h="jakarta.faces.html">

    <f:metadata>
        <ui:param name="viewPage" value="#{${ENTITY_LOWER_CAMEL}EditorPage}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />

        <ui:param name="primaryTitle" value="#{string['${ENTITY_LOWER_CAMEL}.editor.page.title']}" />

        <ui:param name="notool" value="true" />
        <ui:param name="nofilter" value="true" />

        <f:viewParam name="entity" value="#{viewPage.entity}" converter="${ENTITY_NAME}Converter" transient="true" />

        <f:viewAction action="#{viewPage.load}" />
    </f:metadata>

    <ui:define name="content-header" />

    <ui:define name="form">
        <div class="grid w-full p-3">
            <div class="col-12 md:col-6 md:col-offset-3">
                <ui:decorate template="/WEB-INF/resources/core/base/formlet.xhtml">
                    <ui:define name="fields">
                        <div class="form-field">
                            <p:outputLabel for="name" value="#{string['${ENTITY_LOWER_CAMEL}.name.label']}" />
                            <p:inputText id="name" value="#{viewPage.entity.name}" class="block w-full" />
                            <p:message for="name" />
                        </div>
                    </ui:define>
                </ui:decorate>
            </div>
        </div>
    </ui:define>

</ui:composition>
EOF
echo "Generated Editor XHTML at: $WEB_DIR/view/admin/${ENTITY_FILE_BASE}editor.xhtml"

# 6. Update localized properties files
if [ -f "$RES_DIR/string_en.properties" ]; then
    if ! grep -q "^${ENTITY_LOWER_CAMEL}.editor.page.title=" "$RES_DIR/string_en.properties"; then
        echo "" >> "$RES_DIR/string_en.properties"
        echo "${ENTITY_LOWER_CAMEL}.editor.page.title=${ENTITY_LABEL} Editor" >> "$RES_DIR/string_en.properties"
        echo "${ENTITY_LOWER_CAMEL}.name.label=Name" >> "$RES_DIR/string_en.properties"
        echo "Updated string_en.properties"
    fi
else
    echo "${ENTITY_LOWER_CAMEL}.editor.page.title=${ENTITY_LABEL} Editor" > "$RES_DIR/string_en.properties"
    echo "${ENTITY_LOWER_CAMEL}.name.label=Name" >> "$RES_DIR/string_en.properties"
    echo "Created string_en.properties"
fi

if [ -f "$RES_DIR/string_id.properties" ]; then
    if ! grep -q "^${ENTITY_LOWER_CAMEL}.editor.page.title=" "$RES_DIR/string_id.properties"; then
        echo "" >> "$RES_DIR/string_id.properties"
        echo "${ENTITY_LOWER_CAMEL}.editor.page.title=Editor ${ENTITY_LABEL}" >> "$RES_DIR/string_id.properties"
        echo "${ENTITY_LOWER_CAMEL}.name.label=Nama" >> "$RES_DIR/string_id.properties"
        echo "Updated string_id.properties"
    fi
else
    echo "${ENTITY_LOWER_CAMEL}.editor.page.title=Editor ${ENTITY_LABEL}" > "$RES_DIR/string_id.properties"
    echo "${ENTITY_LOWER_CAMEL}.name.label=Nama" >> "$RES_DIR/string_id.properties"
    echo "Created string_id.properties"
fi

# 7. Run generate-persistence.sh
if [ -f "$SCRIPT_DIR/generate-persistence.sh" ]; then
    echo "Running generate-persistence.sh to register the entity..."
    "$SCRIPT_DIR/generate-persistence.sh"
else
    echo "Warning: generate-persistence.sh not found at $SCRIPT_DIR/generate-persistence.sh"
fi

echo "Success! Entity ${ENTITY_NAME} and its editor page created."
