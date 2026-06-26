#!/bin/bash

# Kupu Application Entity View Generator
# Generates JPA Entity (if missing), Facade, List Bean, Page Controller, and XHTMLs

# Usage: ./create-entity-view.sh <sub_module_name> <entity_name> <entity_package> [--no-acl]

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

SUB_MODULE=""
ENTITY_NAME=""
SKIP_ACL=false
IS_HIERARCHICAL=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-acl) SKIP_ACL=true ;;
        --hierarchical|-H) IS_HIERARCHICAL=true ;;
        -h|--help)
            echo "Kupu Application Entity View Generator"
            echo "Usage: $(basename "$0") <sub_module_name> <entity_name> [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help           Display this help message"
            echo "  --no-acl             Skip access control list (ACL) generation"
            echo "  --hierarchical, -H   Generate hierarchical entity views"
            echo ""
            echo "Arguments:"
            echo "  sub_module_name      Name of the target sub-module (lowercase)"
            echo "  entity_name          Name of the JPA Entity class (CamelCase)"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") inventory Product"
            echo "  $(basename "$0") inventory Product --no-acl"
            echo "  $(basename "$0") core Category --hierarchical"
            exit 0
            ;;
        *) 
            if [ -z "$SUB_MODULE" ]; then SUB_MODULE=$1
            elif [ -z "$ENTITY_NAME" ]; then ENTITY_NAME=$1
            fi
            ;;
    esac
    shift
done

if [ -z "$SUB_MODULE" ] || [ -z "$ENTITY_NAME" ]; then
    echo "Usage: $(basename "$0") <sub_module_name> <entity_name> [options]"
    echo "Run '$(basename "$0") --help' for details and examples."
    exit 1
fi

MODULE_NAME=$SUB_MODULE

ENTITY_CAP=$(echo "$ENTITY_NAME" | sed 's/./\U&/')
ENTITY_LABEL=$(echo "${ENTITY_CAP}" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')
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
VIEW_NS_PATH="/$MODULE_NAME"
COMP_DIR="src/main/webapp/WEB-INF/resources/$MODULE_NAME"

# Discover Entity or construct default package
FOUND_ENTITY=$(find src/main/java -name "$MODULE_NAME" -type d -exec find {} -name "${ENTITY_CAP}.java" \; | head -n 1)

if [ -n "$FOUND_ENTITY" ]; then
    ENTITY_FILE="$FOUND_ENTITY"
    ENTITY_PKG=$(grep "^package " "$ENTITY_FILE" | head -n 1 | sed 's/package \(.*\);/\1/')
    echo "Found existing entity at $ENTITY_FILE ($ENTITY_PKG)"
else
    ENTITY_PKG="$APP_PACKAGE.$MODULE_NAME.entity"
    ENTITY_PKG_PATH=$(echo "$ENTITY_PKG" | tr . /)
    ENTITY_FILE="src/main/java/${ENTITY_PKG_PATH}/${ENTITY_CAP}.java"
fi

echo "Creating directory structure for module: $MODULE_NAME..."
mkdir -p "$(dirname "$ENTITY_FILE")"
mkdir -p "$JAVA_DIR"/{entity,dao,view/admin,view/converter,view/event,view/filter,view/list,view/misc,service,api,event}
mkdir -p "$RES_DIR"
mkdir -p "$VIEW_BASE_DIR$VIEW_NS_PATH"/view/admin
mkdir -p "$COMP_DIR"/list "$COMP_DIR"/filter/meta

# Get Table Prefix
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

# 1.5 Discover Fields if entity exists
FIELDS_ARRAY=()
if [ -f "$ENTITY_FILE" ]; then
    # Auto-detect hierarchical status early to include parent field if needed
    if grep -q "HierarchicalEntity" "$ENTITY_FILE"; then
        IS_HIERARCHICAL=true
        echo "Auto-detected HierarchicalEntity from existing entity."
    fi

    echo "Parsing fields from existing entity: $ENTITY_CAP..."
    # Extract private fields, excluding serialVersionUID and static fields
    # Format: Type:Name:MtoFlag
    HAS_MANY_TO_ONE=false
    while read -r line; do
        if [[ $line == *"@ManyToOne"* ]]; then
            HAS_MANY_TO_ONE=true
        fi
        if [[ $line =~ private[[:space:]]+([A-Za-z0-9_<>]+)[[:space:]]+([a-z[A-Z0-9_]+)\; ]]; then
            TYPE="${BASH_REMATCH[1]}"
            NAME="${BASH_REMATCH[2]}"
            # Exclude children, serialVersionUID, and parent (unless hierarchical)
            SHOULD_INCLUDE=false
            if [[ "$NAME" != "serialVersionUID" && "$NAME" != "children" ]]; then
                if [[ "$NAME" == "parent" ]]; then
                    if [ "$IS_HIERARCHICAL" = true ]; then
                        SHOULD_INCLUDE=true
                    fi
                else
                    SHOULD_INCLUDE=true
                fi
            fi

            if [ "$SHOULD_INCLUDE" = true ]; then
                if [ "$HAS_MANY_TO_ONE" = true ]; then
                    if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then
                        FIELDS_ARRAY=("${TYPE}:${NAME}:MTO" "${FIELDS_ARRAY[@]}")
                    else
                        FIELDS_ARRAY+=("$TYPE:$NAME:MTO")
                    fi
                else
                    FIELDS_ARRAY+=("$TYPE:$NAME:STD")
                fi
            fi
            HAS_MANY_TO_ONE=false
        fi
    done < "$ENTITY_FILE"
fi

LIST_SUFFIX="List"
if [ "$IS_HIERARCHICAL" = true ]; then
    LIST_SUFFIX="Tree"
fi

# 1.5.1 Architectural Validation & Fixing (if entity exists)
if [ -f "$ENTITY_FILE" ]; then
    echo "Validating architectural constraints for: $ENTITY_CAP..."
    
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
        sed -i "/@Entity/a @Table(name = \"${TABLE_PREFIX}_${ENTITY_UPPER}\")" "$ENTITY_FILE"
    elif ! grep -q "@Table(name = \"${TABLE_PREFIX}_${ENTITY_UPPER}\")" "$ENTITY_FILE"; then
        echo "  - @Table name mismatch. Updating..."
        sed -i "s/@Table(name = \".*\")/@Table(name = \"${TABLE_PREFIX}_${ENTITY_UPPER}\")/" "$ENTITY_FILE"
    fi
    
    # Check Serializable
    if ! grep -q "implements Serializable" "$ENTITY_FILE"; then
        echo "  - Missing Serializable. Injecting..."
        sed -i "s/class ${ENTITY_CAP}/class ${ENTITY_CAP} implements Serializable/" "$ENTITY_FILE"
    fi

    # Check @Id or @EmbeddedId
    if ! grep -qE "@Id|@EmbeddedId" "$ENTITY_FILE"; then
         echo "  [WARNING] No @Id or @EmbeddedId found in $ENTITY_CAP. Manual verification required."
    fi

    # Standardize Methods (hashCode, equals, toString)
    if command -v python3 &>/dev/null; then
        python3 -c '
import sys, re, textwrap
path = sys.argv[1]
pkg = sys.argv[2]
name = sys.argv[3]

with open(path, "r") as f: content = f.read()

def replace_method(content, method_name, new_impl, signature_pattern):
    # Find matching signature
    match = re.search(r"^([ \t]*)" + signature_pattern, content, re.MULTILINE | re.DOTALL)
    if not match:
        # If not found, append to end before last brace
        indented = new_impl.replace(chr(10), chr(10) + "    ")
        return re.sub(r"\}\s*$", "\n\n    " + indented + "\n}", content)
    
    start_idx = match.start()
    indent = match.group(1)
    
    # Properly indent the new implementation
    indented_impl = textwrap.indent(new_impl, indent)
    
    # Find the first opening brace "{" after the signature
    brace_start = content.find("{", start_idx)
    if brace_start == -1: return content
    
    # Count braces to find the matching closing brace
    count = 1
    i = brace_start + 1
    while count > 0 and i < len(content):
        if content[i] == "{": count += 1
        elif content[i] == "}": count -= 1
        i += 1
    
    # Replace from start of indentation to end of matching brace
    return content[:start_idx] + indented_impl + content[i:]

# Standard toString
ts_impl = "@Override\npublic String toString() {\n    return id != null ? String.valueOf(id) : null;\n}"
content = replace_method(content, "toString", ts_impl, r"(@Override\s+)?public String toString\s*\(")

# Standard hashCode
hc_impl = "@Override\npublic int hashCode() {\n    int hash = 7;\n    hash = 97 * hash + Objects.hashCode(this.id);\n    return hash;\n}"
content = replace_method(content, "hashCode", hc_impl, r"(@Override\s+)?public int hashCode\s*\(")

# Standard equals
eq_impl = "@Override\npublic boolean equals(Object obj) {\n    if (this == obj) return true;\n    if (obj == null || getClass() != obj.getClass()) return false;\n    final " + name + " other = (" + name + ") obj;\n    return Objects.equals(this.id, other.id);\n}"
content = replace_method(content, "equals", eq_impl, r"(@Override\s+)?public boolean equals\s*\(\s*Object ")

with open(path, "w") as f: f.write(content)
' "$ENTITY_FILE" "$ENTITY_PKG" "$ENTITY_CAP"
    else
        echo "  [WARNING] python3 not found. Skipping method standardization."
    fi
fi

if [ ${#FIELDS_ARRAY[@]} -eq 0 ]; then
    if [ "$IS_HIERARCHICAL" = true ]; then
        FIELDS_ARRAY+=("${ENTITY_CAP}:parent:MTO")
    fi
    FIELDS_ARRAY+=("String:name:STD")
fi

# 1.6 Generate Entity if missing
if [ ! -f "$ENTITY_FILE" ]; then
    echo "Entity $ENTITY_NAME not found. Generating default architecture-compliant entity..."
    cat <<JAVA > "$ENTITY_FILE"
package ${ENTITY_PKG};

$(if [ "$IS_HIERARCHICAL" = true ]; then echo "import id.my.mdn.kupu.core.base.model.HierarchicalEntity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.JoinColumn;
import java.util.List;
import java.util.ArrayList;"; fi)
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.TableGenerator;
import id.my.mdn.kupu.core.base.view.annotation.SorterField;
import id.my.mdn.kupu.core.base.view.annotation.SorterFields;
import id.my.mdn.kupu.core.externable.annotation.ExternableColumn;
import id.my.mdn.kupu.core.externable.annotation.ExternableEntity;
import java.io.Serializable;
import java.util.Objects;

@Entity
@Table(name = "${TABLE_PREFIX}_${ENTITY_UPPER}")
@SorterFields({
    @SorterField(value = "name", label = "string['${ENTITY_LOWER_CAMEL}.name.label']", sort = SorterField.Sort.MANUAL)
})
@ExternableEntity(columns = {$(if [ "$IS_HIERARCHICAL" = true ]; then echo "
    @ExternableColumn(field = \"parent.name\", name = \"Parent\"),"; fi)
    @ExternableColumn(field = "name", name = "string['${ENTITY_LOWER_CAMEL}.name.label']")
})
public class ${ENTITY_CAP} implements Serializable$(if [ "$IS_HIERARCHICAL" = true ]; then echo ", HierarchicalEntity<${ENTITY_CAP}>"; fi) {

    @Id
    @TableGenerator(name = "${TABLE_PREFIX_CAP}_${ENTITY_CAP}", table = "KEYGEN", allocationSize = 1)
    @GeneratedValue(generator = "${TABLE_PREFIX_CAP}_${ENTITY_CAP}", strategy = GenerationType.TABLE)
    private Long id;

    private String name;
$(if [ "$IS_HIERARCHICAL" = true ]; then echo "
    @ManyToOne
    @JoinColumn(name = \"parent_id\")
    private ${ENTITY_CAP} parent;

    @OneToMany(mappedBy = \"parent\")
    private List<${ENTITY_CAP}> children = new ArrayList<>();

    @Override
    public ${ENTITY_CAP} getParent() { return parent; }

    @Override
    public void setParent(${ENTITY_CAP} parent) { this.parent = parent; }

    @Override
    public List<${ENTITY_CAP}> getChildren() { return children; }

    @Override
    public void setChildren(List<${ENTITY_CAP}> children) { this.children = children; }"; fi)

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
if [ "$IS_HIERARCHICAL" = true ]; then
    FACADE_BASE="id.my.mdn.kupu.core.base.dao.AbstractHierarchicalFacade"
    FACADE_BASE_CLASS="AbstractHierarchicalFacade"
else
    FACADE_BASE="id.my.mdn.kupu.core.base.dao.AbstractFacade"
    FACADE_BASE_CLASS="AbstractFacade"
fi

cat <<JAVA > "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"
package ${BASE_PACKAGE}.dao;

import ${ENTITY_PKG}.${ENTITY_CAP};
import ${FACADE_BASE};
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.From;
import jakarta.persistence.criteria.Predicate;

@ApplicationScoped
public class ${ENTITY_CAP}Facade extends ${FACADE_BASE_CLASS}<${ENTITY_CAP}> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    @Override protected EntityManager getEntityManager() { return em; }
    public ${ENTITY_CAP}Facade() { super(${ENTITY_CAP}.class); }
JAVA

# Generate applyFilter and orderExpression cases
APPLY_FILTER_CASES=""
ORDER_CASES=""
for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$NAME" = "id" ]; then continue; fi
    if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
    if [ "$MTO_FLAG" = "MTO" ]; then
        APPLY_FILTER_CASES+="            case \"$NAME\":"$'\n'"                return cb.equal(from[0].get(\"$NAME\"), filterValue);"$'\n'
    elif [ "$TYPE" = "String" ]; then
        APPLY_FILTER_CASES+="            case \"$NAME\":"$'\n'"                String ${NAME}Query = (String) filterValue;"$'\n'"                if (${NAME}Query == null || ${NAME}Query.isEmpty()) { return null; }"$'\n'"                Expression<String> ${NAME}Expr = cb.literal(\"%\" + ${NAME}Query.toUpperCase() + \"%\");"$'\n'"                return cb.like(cb.upper(from[0].get(\"$NAME\")), ${NAME}Expr);"$'\n'
        ORDER_CASES+="            case \"$NAME\":"$'\n'"                return from[0].get(\"$NAME\");"$'\n'
    else
        ORDER_CASES+="            case \"$NAME\":"$'\n'"                return from[0].get(\"$NAME\");"$'\n'
    fi
done

cat <<JAVA >> "$JAVA_DIR/dao/${ENTITY_CAP}Facade.java"

    @Override
    protected Predicate applyFilter(String filterName, Object filterValue, CriteriaQuery cq, From... from) {
        CriteriaBuilder cb = getEntityManager().getCriteriaBuilder();
        switch (filterName) {
$APPLY_FILTER_CASES            default:
                return super.applyFilter(filterName, filterValue, cq, from);
        }
    }

    @Override
    protected Expression orderExpression(String field, From... from) {
        switch (field) {
$ORDER_CASES            default:
                return super.orderExpression(field, from);
        }
    }
}
JAVA

# 3. Generate Filter Content
{
    echo "package ${BASE_PACKAGE}.view.filter;"
    echo ""
    # Collect unique imports
    # If a type is an entity (exists in its package) we might need an import
    # For now, let's keep it simple and just generate the fields
    echo "import id.my.mdn.kupu.core.base.view.annotation.Bookmark;"
    echo "import id.my.mdn.kupu.core.base.view.widget.FilterContent;"
    echo "import jakarta.annotation.PostConstruct;"
    echo "import jakarta.enterprise.context.Dependent;"
    echo "import jakarta.inject.Inject;"
    echo "import java.io.Serializable;"
    
    # Try to find imports for custom types by searching in the project
    for field in "${FIELDS_ARRAY[@]}"; do
        IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
        # If type is not primitive/common, try to find its package
        if [[ ! "$TYPE" =~ ^(String|Long|Integer|Double|Boolean|List|Map)$ ]]; then
            if [[ "$TYPE" == "LocalDate" || "$TYPE" == "LocalDateTime" || "$TYPE" == "LocalTime" ]]; then
                echo "import java.time.$TYPE;"
            elif [[ "$TYPE" == "Date" ]]; then
                echo "import java.util.Date;"
            elif [[ "$TYPE" == "BigDecimal" ]]; then
                echo "import java.math.BigDecimal;"
            else
                IMPORT=$(find src/main/java -name "${TYPE}.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${TYPE}';/')
                if [ -n "$IMPORT" ]; then echo "$IMPORT"; fi
            fi
        fi
    done | sort -u
    
    echo ""
    echo "@Dependent"
    echo "public class ${ENTITY_CAP}Filter extends FilterContent implements Serializable {"
    echo "    "
    for field in "${FIELDS_ARRAY[@]}"; do
        IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        if [ "$MTO_FLAG" = "MTO" ]; then
            echo "    @Inject"
            echo "    private ${BASE_PACKAGE}.view.misc.${TYPE}LazyChooser ${NAME}FilterChooser;"
            echo ""
        fi
        echo "    @Bookmark(name = \"$NAME\")"
        echo "    private $TYPE $NAME;"
    done
    echo ""
    echo "    @PostConstruct"
    echo "    public void init() {"
    for field in "${FIELDS_ARRAY[@]}"; do
        IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        if [ "$MTO_FLAG" = "MTO" ]; then
            CAP_NAME=$(echo "$NAME" | sed -r 's/(^.)/\U\1/')
            echo "        ${NAME}FilterChooser.setSaveListener((selection, ctx) -> set${CAP_NAME}(selection));"
        fi
    done
    echo "    }"
    echo ""
    for field in "${FIELDS_ARRAY[@]}"; do
        IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        CAP_NAME=$(echo "$NAME" | sed -r 's/(^.)/\U\1/')
        if [ "$MTO_FLAG" = "MTO" ]; then
            echo "    public ${BASE_PACKAGE}.view.misc.${TYPE}LazyChooser get${CAP_NAME}FilterChooser() {"
            echo "        return ${NAME}FilterChooser;"
            echo "    }"
        fi
        echo "    public $TYPE get${CAP_NAME}() { return $NAME; }"
        echo "    public void set${CAP_NAME}($TYPE $NAME) { this.$NAME = $NAME; }"
    done
    echo "}"
} > "$JAVA_DIR/view/filter/${ENTITY_CAP}Filter.java"

# 4. Generate List/Tree Bean
cat <<JAVA > "$JAVA_DIR/view/list/${ENTITY_CAP}${LIST_SUFFIX}.java"
package ${BASE_PACKAGE}.view.list;

import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import ${ENTITY_PKG}.${ENTITY_CAP};
import ${BASE_PACKAGE}.view.filter.${ENTITY_CAP}Filter;
import id.my.mdn.kupu.core.base.dao.AbstractFacade.DefaultChecker;
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.util.Result;
$(if [ "$IS_HIERARCHICAL" = true ]; then echo "import id.my.mdn.kupu.core.base.view.widget.AbstractMutableTree;"; else echo "import id.my.mdn.kupu.core.base.view.widget.AbstractMutablePagedValueList;"; fi)
import id.my.mdn.kupu.core.base.view.widget.AbstractPagedValueList.DefaultCount;
import id.my.mdn.kupu.core.base.view.widget.AbstractValueList.DefaultList;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;

@Dependent
public class ${ENTITY_CAP}${LIST_SUFFIX} extends $(if [ "$IS_HIERARCHICAL" = true ]; then echo "AbstractMutableTree"; else echo "AbstractMutablePagedValueList"; fi)<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade dao;

    @Inject
    private ${ENTITY_CAP}Filter filterContent;

    public ${ENTITY_CAP}${LIST_SUFFIX}() {
        super(${ENTITY_CAP}.class);
    }

    @PostConstruct
    public void init() {
        filter.setContent(filterContent);
    }

$(if [ "$IS_HIERARCHICAL" = true ]; then echo "    @Override
    protected List<${ENTITY_CAP}> getFetchedItemsInternal(Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ENTITY_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(0, 0, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }"; else echo "    @Override
    protected List<${ENTITY_CAP}> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<${ENTITY_CAP}> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }"; fi)

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
$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$MTO_FLAG" = "MTO" ]; then
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        CHOOSER_IMPORT=$(find src/main/java -name "${TYPE}LazyChooser.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${TYPE}LazyChooser';/')
        if [ -n "$CHOOSER_IMPORT" ]; then echo "$CHOOSER_IMPORT"; else echo "import ${BASE_PACKAGE}.view.misc.${TYPE}LazyChooser;"; fi
        
        ENTITY_IMPORT=$(find src/main/java -name "${TYPE}.java" -exec grep -l "^package " {} \; | head -n 1 | xargs grep "^package " | sed 's/package \(.*\);/import \1.'${TYPE}';/')
        if [ -n "$ENTITY_IMPORT" ]; then echo "$ENTITY_IMPORT"; else echo "import id.my.mdn.kupu.core.base.entity.${TYPE};"; fi
    fi
done)
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.FormPage;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.util.Map;
import java.util.HashMap;

@Named
@ConversationScoped
public class ${ENTITY_CAP}EditorPage extends FormPage<${ENTITY_CAP}> {

    @Inject
    private ${ENTITY_CAP}Facade dao;

$(if [ "$IS_HIERARCHICAL" = true ]; then echo "    private ${ENTITY_CAP} parent;
"; fi)$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$MTO_FLAG" = "MTO" ]; then
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        NAME_CAP=$(echo "${NAME}" | sed 's/./\U&/')
        echo "    @Inject"
        echo "    private ${TYPE}LazyChooser ${NAME}Chooser;"
        echo "    public ${TYPE}LazyChooser get${NAME_CAP}Chooser() { return ${NAME}Chooser; }"
    fi
done)

    @PostConstruct
    @Override
    protected void init() {
        super.init();
$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$MTO_FLAG" = "MTO" ]; then
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        echo "        ${NAME}Chooser.setContext(this::ctx${TYPE}Chooser);"
        echo "        ${NAME}Chooser.setSaveListener(this::onSelect${TYPE});"
    fi
done)
    }

$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$MTO_FLAG" = "MTO" ]; then
        if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
        echo "    private Map<String, Object> ctx${TYPE}Chooser() {"
        echo "        Map<String, Object> context = new HashMap<>();"
        echo "        return context;"
        echo "    }"
        echo "    public void onSelect${TYPE}(${TYPE} selection, Map<String, Object> context) {"
        CAP_NAME=$(echo "$NAME" | sed -r 's/(^.)/\U\1/')
        echo "        getEntity().set${CAP_NAME}(selection);"
        echo "    }"
    fi
done)

    @Override
    protected ${ENTITY_CAP} newEntity() {
        $(if [ "$IS_HIERARCHICAL" = true ]; then echo "
        ${ENTITY_CAP} newEntity = new ${ENTITY_CAP}();
        if (parent != null) {
            newEntity.setParent(parent);
            parent.getChildren().add(newEntity);
        }
        return newEntity;
        "
        else echo "
        return new ${ENTITY_CAP}();
        "
        fi)
    }

    @Override
    protected Result<String> save(${ENTITY_CAP} entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> edit(${ENTITY_CAP} entity) {
        return dao.edit(entity);
    }
$(if [ "$IS_HIERARCHICAL" = true ]; then echo "
    public ${ENTITY_CAP} getParent() {
        return parent;
    }

    public void setParent(${ENTITY_CAP} parent) {
        this.parent = parent;
    }
"; fi)}
JAVA

# 6. Generate Main Page Controller
cat <<JAVA > "$JAVA_DIR/view/${ENTITY_CAP}Page.java"
package ${BASE_PACKAGE}.view;

import ${BASE_PACKAGE}.view.list.${ENTITY_CAP}${LIST_SUFFIX};
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
    private ${ENTITY_CAP}${LIST_SUFFIX} dataView;
    
    @Override
    @PostConstruct
    public void init() {
        super.init();
    }

    public ${ENTITY_CAP}${LIST_SUFFIX} getDataView() {
        return dataView;
    }

    @Creator(of = "dataView")
    public void openCreator() {
        $(if [ "$IS_HIERARCHICAL" = true ]; then
            echo "gotoChild(${ENTITY_CAP}EditorPage.class)
                .addParam(\"parent\")
                .withValues(dataView.getSelected())
                .open();"
          else
            echo "gotoChild(${ENTITY_CAP}EditorPage.class).open();"
          fi)
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
import jakarta.inject.Singleton;

@Singleton
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

# 8. Generate List/Tree Converters
cat <<JAVA > "$JAVA_DIR/view/converter/${ENTITY_CAP}ListConverter.java"
package ${BASE_PACKAGE}.view.converter;

import ${BASE_PACKAGE}.dao.${ENTITY_CAP}Facade;
import ${ENTITY_PKG}.${ENTITY_CAP};
import id.my.mdn.kupu.core.base.util.K.KLong;
import id.my.mdn.kupu.core.base.view.converter.SelectionsConverter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;

@Singleton
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
        return value != null ? value.toString() : null;
    }
}
JAVA

# 7. Generate Main Page XHTML
cat <<XHTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/${ENTITY_FILE_BASE}.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" template="/WEB-INF/templates/page.xhtml"
    xmlns:h="jakarta.faces.html" xmlns:f="jakarta.faces.core" xmlns:ui="jakarta.faces.facelets" xmlns:p="primefaces">

    <f:metadata>
        <ui:param name="title" value="#{string['${ENTITY_LOWER_CAMEL}.page.title']}" />

        <ui:param name="viewPage" value="#{${ENTITY_LOWER_CAMEL}Page}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />

        <ui:param name="dataView" value="#{viewPage.dataView}" />
        <ui:param name="contentId" value=":data-frm:#{dataView.name}" />
        <ui:param name="notool" value="true" />

        <ui:param name="filter" value="#{dataView.filter}" />
        <ui:param name="filterType" value="overlay" />
        <ui:param name="filterUi" value="/WEB-INF/resources/${MODULE_NAME}/filter/${ENTITY_FILE_BASE}-filterui.xhtml" />
        <ui:include src="/WEB-INF/resources/${MODULE_NAME}/filter/meta/${ENTITY_FILE_BASE}-filterui.xhtml" />

        <ui:param name="sorter" value="#{dataView.sorter}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/sorter.xhtml" />

$(if [ "$IS_HIERARCHICAL" = false ]; then echo "        <ui:param name=\"pager\" value=\"#{dataView.pager}\" />
        <ui:include src=\"/WEB-INF/resources/core/base/meta/pager.xhtml\" />
"; fi)

        <f:viewParam name="s" value="#{dataView.selectionsInternal}" converter="${ENTITY_CAP}ListConverter"
            transient="true" />
    </f:metadata>

    <ui:define name="module-menu">
        <ui:include src="/WEB-INF/resources/${MODULE_NAME}/module-menu.xhtml" />
    </ui:define>

    <ui:define name="content">
        <h:form id="data-frm" class="flex-grow-1 flex align-items-stretch">
            <ui:include src="/WEB-INF/resources/${MODULE_NAME}/list/${ENTITY_FILE_BASE}$(echo "$LIST_SUFFIX" | tr '[:upper:]' '[:lower:]').xhtml" />
        </h:form>
    </ui:define>
$(if [ "$IS_HIERARCHICAL" = true ]; then echo "
    <ui:define name=\"pager\" />"; fi)

</ui:composition>
XHTML

# 8. Generate Editor Page XHTML
cat <<XHTML > "$VIEW_BASE_DIR$VIEW_NS_PATH/view/admin/${ENTITY_FILE_BASE}editor.xhtml"
<ui:composition template="/WEB-INF/templates/editor-page.xhtml" xmlns="http://www.w3.org/1999/xhtml"
    xmlns:ui="jakarta.faces.facelets" xmlns:f="jakarta.faces.core" xmlns:p="primefaces"
    xmlns:k="http://xmlns.jcp.org/jsf/composite/kupu" xmlns:h="jakarta.faces.html">

    <f:metadata>
        <ui:param name="viewPage" value="#{${ENTITY_LOWER_CAMEL}EditorPage}" />
        <ui:include src="/WEB-INF/resources/core/base/meta/page.xhtml" />

        <ui:param name="primaryTitle" value="#{string['${ENTITY_LOWER_CAMEL}.editor.page.title']}" />

        <ui:param name="notool" value="true" />
        <ui:param name="nofilter" value="true" />

        <f:viewParam name="entity" value="#{viewPage.entity}" converter="${ENTITY_CAP}Converter" transient="true" />
$(if [ "$IS_HIERARCHICAL" = true ]; then echo "        <f:viewParam name=\"parent\" value=\"#{viewPage.parent}\" converter=\"${ENTITY_CAP}Converter\" transient=\"true\" />"; fi)

        <f:viewAction action="#{viewPage.load}" />
    </f:metadata>

    <ui:define name="content-header" />

    <ui:define name="form">
        <div class="grid w-full p-3">
            <div class="col-12 md:col-6 md:col-offset-3">
                <ui:decorate template="/WEB-INF/resources/core/base/formlet.xhtml">
                        <ui:define name="fields">
$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [[ "$NAME" != "id" ]]; then
        PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
        echo "                        <div class=\"form-field\">"
        if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then
            echo "                            <p:outputLabel for=\"$NAME\" value=\"$PRETTY_NAME\" />"
        else
            echo "                            <p:outputLabel for=\"$NAME\" value=\"#{string['${ENTITY_LOWER_CAMEL}.${NAME}.label']}\" />"
        fi
        if [ "$MTO_FLAG" = "MTO" ]; then
            if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then
                echo "                            <p:inputText id=\"$NAME\" value=\"#{viewPage.entity.$NAME ne null ? viewPage.entity.$NAME.name : null}\" readonly=\"true\" class=\"block w-full\" />"
            else
                echo "                            <k:lazySelector id=\"$NAME\""
                echo "                                            value=\"#{viewPage.entity.$NAME ne null ? viewPage.entity.$NAME.name : ''}\""
                echo "                                            selector=\"${TYPE}Selector\" update=\"#{component.clientId}\" required=\"true\""
                echo "                                            rendered=\"#{viewPage.createNew}\" />"
                echo "                            <p:inputText value=\"#{viewPage.entity.$NAME ne null ? viewPage.entity.$NAME.name : ''}\""
                echo "                                         readonly=\"true\" styleClass=\"w-full\" rendered=\"#{not viewPage.createNew}\" />"
            fi
        elif [[ "$TYPE" == "LocalDate" || "$TYPE" == "LocalDateTime" ]]; then
            echo "                            <p:datePicker id=\"$NAME\" value=\"#{viewPage.entity.$NAME}\""
            if [[ "$TYPE" == "LocalDateTime" ]]; then
                echo "                                          flex=\"true\" inputStyleClass=\"w-full\" pattern=\"dd/MM/yyyy HH:mm:ss\" monthNavigator=\"true\" yearNavigator=\"true\""
                echo "                                          showTime=\"true\" />"
            else
                echo "                                          flex=\"true\" inputStyleClass=\"w-full\" pattern=\"dd/MM/yyyy\" monthNavigator=\"true\" yearNavigator=\"true\""
                echo "                                          showTime=\"false\" />"
            fi
        elif [[ "$TYPE" == "boolean" || "$TYPE" == "Boolean" ]]; then
            echo "                            <p:selectBooleanCheckbox id=\"$NAME\" value=\"#{viewPage.entity.$NAME}\" itemLabel=\"$PRETTY_NAME\""
            echo "                                                     class=\"block w-full\" />"
        else
            echo "                            <p:inputText id=\"$NAME\" value=\"#{viewPage.entity.$NAME}\" class=\"block w-full\" />"
        fi
        echo "                            <p:message for=\"$NAME\" />"
        echo "                        </div>"
    fi
done)
                    </ui:define>
                </ui:decorate>
            </div>
        </div>
    </ui:define>

    <ui:define name="util">
$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$MTO_FLAG" = "MTO" ]; then
        if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then continue; fi
        echo "        <h:form>"
        echo "            <k:selectorDialog selector=\"${TYPE}Selector\" widgetVar=\"${NAME}Selector\" chooser=\"#{viewPage.${NAME}Chooser}\""
        echo "                              styleClass=\"w-5\">"
        echo "                <p:dataTable var=\"data\" value=\"#{viewPage.${NAME}Chooser.list.model}\" selectionMode=\"single\""
        echo "                             selection=\"#{viewPage.${NAME}Chooser.selected}\" scrollRows=\"10\" scrollable=\"true\" liveScroll=\"true\""
        echo "                             scrollHeight=\"200\">"
        echo ""
        echo "                    <p:ajax event=\"rowSelect\" listener=\"#{viewPage.${NAME}Chooser.onSave}\""
        echo "                            oncomplete=\"PF('${NAME}Selector').hide()\" />"
        echo ""
        echo "                    <f:facet name=\"header\">"
        echo "                        <span class=\"ui-input-icon-left w-full\">"
        echo "                            <i class=\"pi pi-search\" />"
        echo "                            <p:inputText value=\"#{viewPage.${NAME}Chooser.searchTerm}\" immediate=\"true\" class=\"w-full\">"
        echo "                                <p:ajax event=\"keyup\" update=\"@parent:@parent\" delay=\"300\" />"
        echo "                            </p:inputText>"
        echo "                        </span>"
        echo "                    </f:facet>"
        echo "                    <p:column headerText=\"Id\">"
        echo "                        <h:outputText value=\"#{data.id}\" />"
        echo "                    </p:column>"
        echo "                    <p:column headerText=\"Name\">"
        echo "                        <h:outputText value=\"#{data.name}\" />"
        echo "                    </p:column>"
        echo "                </p:dataTable>"
        echo "            </k:selectorDialog>"
        echo "        </h:form>"
    fi
done)
    </ui:define>

</ui:composition>
XHTML

# 9. Generate List Component XHTML
cat <<XHTML > "$COMP_DIR/list/${ENTITY_FILE_BASE}$(echo "$LIST_SUFFIX" | tr '[:upper:]' '[:lower:]').xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml"
                xmlns:ui="jakarta.faces.facelets"
                xmlns:p="primefaces"
                xmlns:h="jakarta.faces.html">

    <ui:decorate template="/WEB-INF/resources/core/base/$(if [ "$IS_HIERARCHICAL" = true ]; then echo "tree-table.xhtml"; else echo "table.xhtml"; fi)">
        <ui:define name="columns">
$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then
        continue
    fi
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "            <p:column headerText=\"#{string['${ENTITY_LOWER_CAMEL}.${NAME}.label']}\">"
    if [ "$MTO_FLAG" = "MTO" ]; then
        echo "                <h:outputText value=\"#{data.$NAME.name}\" />"
    else
        echo "                <h:outputText value=\"#{data.$NAME}\" />"
    fi
    echo "            </p:column>"
done)
        </ui:define>
    </ui:decorate>

</ui:composition>
XHTML

# 10. Generate Filter UI Component XHTML
cat <<XHTML > "$COMP_DIR/filter/${ENTITY_FILE_BASE}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:k="http://xmlns.jcp.org/jsf/composite/kupu"
                xmlns:f="jakarta.faces.core"
                xmlns:h="jakarta.faces.html"
                xmlns:p="primefaces">

$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
    PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
    echo "    <div class=\"filter-field\">"
    echo "        <p:outputLabel for=\"$NAME\" value=\"#{string['${ENTITY_LOWER_CAMEL}.${NAME}.label']}\" />"
    if [ "$MTO_FLAG" = "MTO" ]; then
        echo "        <k:lazySelector id=\"$NAME\""
        echo "                        value=\"#{filter.content.$NAME ne null ? filter.content.$NAME.name : ''}\""
        echo "                        selector=\"${TYPE}Selector\" update=\"#{component.clientId}\" />"
        echo "        <k:selectorDialog selector=\"${TYPE}Selector\" widgetVar=\"${NAME}Selector\" chooser=\"#{filter.content.${NAME}FilterChooser}\""
        echo "                          styleClass=\"w-5\">"
        echo "            <p:dataTable var=\"data\" value=\"#{filter.content.${NAME}FilterChooser.list.model}\" selectionMode=\"single\""
        echo "                         selection=\"#{filter.content.${NAME}FilterChooser.selected}\" scrollRows=\"10\" scrollable=\"true\" liveScroll=\"true\""
        echo "                         scrollHeight=\"200\">"
        echo "                <p:ajax event=\"rowSelect\" listener=\"#{filter.content.${NAME}FilterChooser.onSave}\""
        echo "                        oncomplete=\"PF('${NAME}Selector').hide();refreshContent();refreshCasing()\" />"
        echo "                <f:facet name=\"header\">"
        echo "                    <span class=\"ui-input-icon-left w-full\">"
        echo "                        <i class=\"pi pi-search\" />"
        echo "                        <p:inputText value=\"#{filter.content.${NAME}FilterChooser.searchTerm}\" immediate=\"true\" class=\"w-full\">"
        echo "                            <p:ajax event=\"keyup\" update=\"@parent:@parent\" delay=\"300\" />"
        echo "                        </p:inputText>"
        echo "                    </span>"
        echo "                </f:facet>"
        echo "                <p:column headerText=\"Id\">"
        echo "                    <h:outputText value=\"#{data.id}\" />"
        echo "                </p:column>"
        echo "                <p:column headerText=\"Name\">"
        echo "                    <h:outputText value=\"#{data.name}\" />"
        echo "                </p:column>"
        echo "            </p:dataTable>"
        echo "        </k:selectorDialog>"
    else
        echo "        <p:inputText id=\"$NAME\" value=\"#{filter.content.$NAME}\" />"
    fi
    echo "    </div>"
done)

</ui:composition>
XHTML

# 11. Generate Filter Meta Component XHTML
cat <<XHTML > "$COMP_DIR/filter/meta/${ENTITY_FILE_BASE}-filterui.xhtml"
<ui:composition xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:ui="jakarta.faces.facelets" 
                xmlns:f="jakarta.faces.core">

$(for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [ "$IS_HIERARCHICAL" = true ] && [ "$NAME" = "parent" ]; then continue; fi
    CONVERTER="QueryStringConverter"
    if [[ "$TYPE" == "Long" ]]; then CONVERTER="LongConverter"; fi
    if [[ "$TYPE" == "Integer" ]]; then CONVERTER="IntegerConverter"; fi
    # For custom entities, use ${Type}Converter
    if [[ ! "$TYPE" =~ ^(String|Long|Integer|Double|Boolean)$ ]]; then
        CONVERTER="${TYPE}Converter"
    fi
    echo "    <f:viewParam name=\"$NAME\" value=\"#{filter.content.$NAME}\" converter=\"$CONVERTER\" transient=\"true\" />"
done)

</ui:composition>
XHTML

# 11. Register in Navigator
NAVIGATOR_FILE="$JAVA_DIR/view/${ENTITY_CAP}Navigator.java"
if [ ! -f "$NAVIGATOR_FILE" ]; then
    MODULE_CAP=$(echo "$MODULE_NAME" | sed 's/./\U&/')
    NAVIGATOR_FILE="$JAVA_DIR/view/${MODULE_CAP}Navigator.java"
fi

if [ -f "$NAVIGATOR_FILE" ]; then
    if ! grep -q "case \"${ENTITY_LABEL}\":" "$NAVIGATOR_FILE"; then
        # Insert directly on top of (above) the default case
        sed -i "/default:/i \            case \"${ENTITY_LABEL}\": return ${BASE_PACKAGE}.view.${ENTITY_CAP}Page.class;" "$NAVIGATOR_FILE"
        echo "Registered ${ENTITY_LABEL} in $NAVIGATOR_FILE"
    fi
fi

# 12. Register in Menu
MENU_FILE="$COMP_DIR/module-menu.xhtml"
if [ -f "$MENU_FILE" ]; then
    if ! grep -q "open('${ENTITY_LABEL}'," "$MENU_FILE"; then
        # Insert before the closing tag, ensuring correct formatting
        sed -i "/<\/ui:composition>/i \\    <p:menuitem value=\"#{string['${ENTITY_LOWER_CAMEL}.page.title']}\" icon=\"pi pi-file\" actionListener=\"#{${MODULE_NAME}Navigator.open('${ENTITY_LABEL}', '')}\" immediate=\"true\" />" "$MENU_FILE"
        echo "Registered ${ENTITY_LABEL} in $MENU_FILE"
    fi
fi

# 13. Update security.json if not skipped
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

# 12. Append Localization Properties
EN_PROPS_FILE="$RES_DIR/string_en.properties"
ID_PROPS_FILE="$RES_DIR/string_id.properties"

# Create files with module title if they don't exist yet
if [ ! -f "$EN_PROPS_FILE" ]; then
    MODULE_LABEL=$(echo "${MODULE_NAME}" | sed 's/./\U&/')
    echo "${MODULE_NAME}.module.title=${MODULE_LABEL}" > "$EN_PROPS_FILE"
    echo "Created $EN_PROPS_FILE"
fi
if [ ! -f "$ID_PROPS_FILE" ]; then
    MODULE_LABEL=$(echo "${MODULE_NAME}" | sed 's/./\U&/')
    echo "${MODULE_NAME}.module.title=${MODULE_LABEL}" > "$ID_PROPS_FILE"
    echo "Created $ID_PROPS_FILE"
fi

if ! grep -q "^${ENTITY_LOWER_CAMEL}\.page\.title=" "$EN_PROPS_FILE"; then
    echo "${ENTITY_LOWER_CAMEL}.page.title=${ENTITY_LABEL}" >> "$EN_PROPS_FILE"
fi
if ! grep -q "^${ENTITY_LOWER_CAMEL}\.editor\.page\.title=" "$EN_PROPS_FILE"; then
    echo "${ENTITY_LOWER_CAMEL}.editor.page.title=${ENTITY_LABEL} Editor" >> "$EN_PROPS_FILE"
fi

if ! grep -q "^${ENTITY_LOWER_CAMEL}\.page\.title=" "$ID_PROPS_FILE"; then
    echo "${ENTITY_LOWER_CAMEL}.page.title=${ENTITY_LABEL}" >> "$ID_PROPS_FILE"
fi
if ! grep -q "^${ENTITY_LOWER_CAMEL}\.editor\.page\.title=" "$ID_PROPS_FILE"; then
    echo "${ENTITY_LOWER_CAMEL}.editor.page.title=Editor ${ENTITY_LABEL}" >> "$ID_PROPS_FILE"
fi

for field in "${FIELDS_ARRAY[@]}"; do
    IFS=':' read -r TYPE NAME MTO_FLAG <<< "$field"
    if [[ "$NAME" != "id" ]]; then
        if [[ "$NAME" == "parent" && "$IS_HIERARCHICAL" == "true" ]]; then continue; fi
        PRETTY_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')
        KEY="${ENTITY_LOWER_CAMEL}.${NAME}.label"
        for prop_file in "$EN_PROPS_FILE" "$ID_PROPS_FILE"; do
            if [ -f "$prop_file" ]; then
                if ! grep -q "^${KEY}=" "$prop_file"; then
                    echo "${KEY}=${PRETTY_NAME}" >> "$prop_file"
                fi
            fi
        done
    fi
done

chmod +x "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
echo "Successfully generated application entity components in $BASE_PACKAGE"
