#!/bin/bash

# Kupu Application Entity Editor XHTML Generator
# Usage: ./scripts/update-entity-editor.sh <module_name> <entity_name>

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

show_help() {
    echo "Kupu Application Entity Editor XHTML Generator"
    echo "Generates and updates JSF/PrimeFaces input elements inside the"
    echo "<ui:define name=\"fields\"> block of an editor page based on"
    echo "public getters of a JPA Entity class."
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
}

MODULE_NAME=""
ENTITY_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
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
    echo ""
    show_help
    exit 1
fi

PKG_PATH=$(echo "$BASE_PACKAGE" | tr . /)

# Define paths
JAVA_FILE="src/main/java/$PKG_PATH/$MODULE_NAME/entity/$ENTITY_NAME.java"
ENTITY_FILE_BASE=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
XHTML_FILE="src/main/webapp/$MODULE_NAME/view/admin/${ENTITY_FILE_BASE}editor.xhtml"

if [ ! -f "$JAVA_FILE" ]; then
    echo "Error: Entity Java class file not found at: $JAVA_FILE"
    exit 1
fi

if [ ! -f "$XHTML_FILE" ]; then
    echo "Error: XHTML editor page not found at: $XHTML_FILE"
    exit 1
fi

ENTITY_LOWER_CAMEL=$(echo "$ENTITY_NAME" | sed 's/./\L&/')

# Run Python helper to replace fields inside the xhtml page
python_script=$(cat <<'EOF'
import sys
import re

java_file = sys.argv[1]
entity_camel = sys.argv[2]
xhtml_file = sys.argv[3]

# 1. Parse Java Entity
try:
    with open(java_file, 'r', encoding='utf-8') as f:
        java_content = f.read()
except Exception as e:
    sys.stderr.write(f"Error reading file {java_file}: {e}\n")
    sys.exit(1)

# Remove comments
java_content = re.sub(r'//.*', '', java_content)
java_content = re.sub(r'/\*.*?\*/', '', java_content, flags=re.DOTALL)

# Find public getters/is-methods
getter_pattern = re.compile(
    r'\bpublic\s+(?:[a-zA-Z0-9_<>\?\[\]\s,]+)\s+(get|is)([A-Z][a-zA-Z0-9_]*)\s*\(\s*\)'
)
getters = getter_pattern.findall(java_content)
seen = set()
fields = []

for prefix, name_cap in getters:
    if len(name_cap) > 1 and name_cap[0].isupper() and name_cap[1].isupper():
        field_name = name_cap
    else:
        field_name = name_cap[0].lower() + name_cap[1:]
    
    if field_name not in seen:
        seen.add(field_name)
        fields.append(field_name)

# 2. Read XHTML Page
try:
    with open(xhtml_file, 'r', encoding='utf-8') as f:
        xhtml_content = f.read()
except Exception as e:
    sys.stderr.write(f"Error reading file {xhtml_file}: {e}\n")
    sys.exit(1)

# Locate <ui:define name="fields">...</ui:define>
fields_pattern = re.compile(r'(\s*<ui:define\s+name="fields">)(.*?)(\s*</ui:define>)', re.DOTALL)

if not fields_pattern.search(xhtml_content):
    sys.stderr.write(f"Error: Could not find <ui:define name=\"fields\"> in {xhtml_file}\n")
    sys.exit(1)

def replace_fields(match):
    prefix = match.group(1)
    suffix = match.group(3)
    
    # Extract leading spaces of <ui:define
    indent_match = re.search(r'([ \t]*)<ui:define', prefix)
    indent = indent_match.group(1) if indent_match else "                    "
    indent_len = len(indent)
    
    div_indent = " " * (indent_len + 4)
    child_indent = " " * (indent_len + 8)
    
    generated_fields = []
    for field_name in fields:
        field_xml = (
            f"{div_indent}<div class=\"form-field\">\n"
            f"{child_indent}<p:outputLabel for=\"{field_name}\" value=\"#{{string['{entity_camel}.{field_name}.label']}}\" />\n"
            f"{child_indent}<p:inputText id=\"{field_name}\" value=\"#{{viewPage.entity.{field_name}}}\" class=\"block w-full\" />\n"
            f"{child_indent}<p:message for=\"{field_name}\" />\n"
            f"{div_indent}</div>"
        )
        generated_fields.append(field_xml)
        
    new_inner = "\n" + "\n".join(generated_fields) + "\n" + indent
    return prefix + new_inner + suffix.lstrip()

new_xhtml = fields_pattern.sub(replace_fields, xhtml_content)

# 3. Write back XHTML Page
try:
    with open(xhtml_file, 'w', encoding='utf-8') as f:
        f.write(new_xhtml)
except Exception as e:
    sys.stderr.write(f"Error writing to file {xhtml_file}: {e}\n")
    sys.exit(1)

print(f"Successfully updated fields in {xhtml_file}")
EOF
)

python3 -c "$python_script" "$JAVA_FILE" "$ENTITY_LOWER_CAMEL" "$XHTML_FILE"
