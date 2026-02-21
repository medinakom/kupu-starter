#!/bin/bash

# Configuration
WEB_DIR="src/main/java"
TEMPLATE="src/main/resources/META-INF/persistence.xml.template"
OUTPUT="src/main/resources/META-INF/persistence.xml"
POM_FILE="pom.xml"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT")"

echo "Discovering JPA entities..."

# Extract Kupu version from pom.xml
if [ -f "$POM_FILE" ]; then
    KUPU_VERSION=$(grep "<kupu.version>" "$POM_FILE" | sed -E 's/.*<kupu.version>(.*)<\/kupu.version>.*/\1/' | tr -d '[:space:]')
else
    echo "Error: pom.xml not found!"
    exit 1
fi

if [ -z "$KUPU_VERSION" ]; then
    echo "Error: Could not determine kupu.version from pom.xml"
    exit 1
fi

echo "Detected kupu-core version: $KUPU_VERSION"

# Locate JAR in local Maven repository
M2_REPO="${HOME}/.m2/repository"
JAR_PATH="$M2_REPO/id/my/mdn/kupu-core/$KUPU_VERSION/kupu-core-$KUPU_VERSION.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo "Error: kupu-core JAR not found at $JAR_PATH"
    echo "Please run 'mvn install' on kupu-core project first."
    exit 1
fi

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
# Trap to cleanup temp dir on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Extracting kupu-core JAR..."
unzip -q "$JAR_PATH" -d "$TEMP_DIR"

echo "Scanning for JPA entities in kupu-core..."
# Find class files containing JPA annotations
# Annotations: Entity, Embeddable, MappedSuperclass, Converter
# We look for binary signatures: Ljakarta/persistence/Entity; etc.
JAR_CLASSES=$(find "$TEMP_DIR" -name "*.class" -type f -exec grep -l -a -E "Ljakarta/persistence/(Entity|Embeddable|MappedSuperclass|Converter);" {} + | \
    sed "s|$TEMP_DIR/||" | \
    sed 's|/|.|g' | \
    sed 's|.class$||' | \
    sort -u)

echo "Scanning for JPA entities in local sources..."
# Find all classes with JPA annotations in local source
LOCAL_CLASSES=$(grep -rE "@(Entity|Embeddable|MappedSuperclass|Converter)" "$WEB_DIR" --include="*.java" | cut -d: -f1 | sort -u | xargs -I {} sh -c "grep -m 1 '^package ' {} | sed 's/package //' | sed 's/;//' | tr -d '\r' | awk '{printf \"%s.\", \$0}'; basename {} .java")

# Combine all classes
ALL_CLASSES=$(printf "%s\n%s" "$JAR_CLASSES" "$LOCAL_CLASSES" | sort -u | grep -v "^$")

# Generate XML class tags
CLASS_XML=""
for c in $ALL_CLASSES; do
    CLASS_XML="$CLASS_XML    <class>$c</class>\n"
done

# Perform substitution using a temporary file
echo "Generating final persistence.xml at $OUTPUT"
# We'll use a safer multiline replacement with awk
awk -v r="$CLASS_XML" '{gsub(/<!-- GENERATED_CLASSES -->/, r)}1' "$TEMPLATE" | sed 's/\\n/\n/g' > "$OUTPUT"

echo "Done! Discovered $(echo "$ALL_CLASSES" | wc -w) classes."
