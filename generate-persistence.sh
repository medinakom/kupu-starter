#!/bin/bash

# Configuration
CORE_DIR="../kupu-core/src/main/java"
WEB_DIR="src/main/java"
TEMPLATE="src/main/resources/META-INF/persistence.xml.template"
OUTPUT="src/main/resources/META-INF/persistence.xml"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT")"

echo "Discovering JPA entities..."

# Find all classes with JPA annotations
CLASSES=$(grep -rE "@(Entity|Embeddable|MappedSuperclass|Converter)" "$CORE_DIR" "$WEB_DIR" --include="*.java" | cut -d: -f1 | sort -u | xargs -I {} sh -c "grep -m 1 '^package ' {} | sed 's/package //' | sed 's/;//' | tr -d '\r' | awk '{printf \"%s.\", \$0}'; basename {} .java")

# Generate XML class tags
CLASS_XML=""
for c in $CLASSES; do
    CLASS_XML="$CLASS_XML    <class>$c</class>\n"
done

# Perform substitution using a temporary file
echo "Generating final persistence.xml at $OUTPUT"
# We'll use a safer multiline replacement with awk
awk -v r="$CLASS_XML" '{gsub(/<!-- GENERATED_CLASSES -->/, r)}1' "$TEMPLATE" | sed 's/\\n/\n/g' > "$OUTPUT"

echo "Done! Discovered $(echo "$CLASSES" | wc -w) classes."
