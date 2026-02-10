#!/bin/bash

# Configuration
SKIP_INTERACTIVE=false

# Default Values
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="kupu"
DB_USER="postgres"
DB_PASS="postgres"
DB_URL=""
WELCOME_FILE="index.xhtml"
OUTPUT_JAR="kupu-config.jar"
DATA_SOURCE_NAME="java:global/KupuDataSource"
DRIVER_CLASS=""
CREATE_DS="true"

# DBMS Definitions
declare -A DBMS_DRIVERS
declare -A DBMS_DEFAULT_PORTS
declare -A DBMS_URL_PREFIXES

DBMS_DRIVERS=(
    ["PostgreSQL"]="org.postgresql.ds.PGConnectionPoolDataSource"
    ["MySQL"]="com.mysql.cj.jdbc.MysqlDataSource"
    ["MariaDB"]="org.mariadb.jdbc.MariaDbDataSource"
    ["HSQLDB"]="org.hsqldb.jdbc.JDBCDataSource"
    ["H2"]="org.h2.jdbcx.JdbcDataSource"
    ["SQLServer"]="com.microsoft.sqlserver.jdbc.SQLServerDataSource"
    ["Oracle"]="oracle.jdbc.pool.OracleDataSource"
)

DBMS_DEFAULT_PORTS=(
    ["PostgreSQL"]="5432"
    ["MySQL"]="3306"
    ["MariaDB"]="3306"
    ["HSQLDB"]="9001"
    ["H2"]="9092"
    ["SQLServer"]="1433"
    ["Oracle"]="1521"
)

DBMS_URL_PREFIXES=(
    ["PostgreSQL"]="jdbc:postgresql://"
    ["MySQL"]="jdbc:mysql://"
    ["MariaDB"]="jdbc:mariadb://"
    ["HSQLDB"]="jdbc:hsqldb:hsql://"
    ["H2"]="jdbc:h2:tcp://"
    ["SQLServer"]="jdbc:sqlserver://"
    ["Oracle"]="jdbc:oracle:thin:@"
)

function show_help {
    echo "Usage: ./create-config-jar.sh [options]"
    echo "Options:"
    echo "  --host <host>          Database host"
    echo "  --port <port>          Database port"
    echo "  --db <name>            Database name"
    echo "  --user <user>          Database user"
    echo "  --pass <pass>          Database password"
    echo "  --url <jdbc-url>       Full JDBC URL (overrides host/port/name)"
    echo "  --welcome <file>       Welcome file (default: index.xhtml)"
    echo "  --output <file>        Output JAR file path (default: kupu-config.jar)"
    echo "  --driver <class>       DataSource Class Name"
    echo "  --no-interactive       Skip interactive prompts (use defaults/flags)"
    echo "  --no-ds                Do not create a data source"
    echo "  --help                 Show this help message"
}

# Parse Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --host) DB_HOST="$2"; shift ;;
        --port) DB_PORT="$2"; shift ;;
        --db) DB_NAME="$2"; shift ;;
        --user) DB_USER="$2"; shift ;;
        --pass) DB_PASS="$2"; shift ;;
        --url) DB_URL="$2"; shift ;;
        --welcome) WELCOME_FILE="$2"; shift ;;
        --output) OUTPUT_JAR="$2"; shift ;;
        --driver) DRIVER_CLASS="$2"; shift ;;
        --no-interactive) SKIP_INTERACTIVE=true ;;
        --no-ds) CREATE_DS="false" ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Interactive Mode
if [ "$SKIP_INTERACTIVE" = false ]; then
    echo "=== Kupu Configuration Wizard ==="
    
    # 1. Ask regarding Data Source
    if [ -z "$CREATE_DS" ] || [ "$CREATE_DS" = "true" ]; then
        read -p "Do you want to configure a Data Source? [Y/n] " confirm_ds
        confirm_ds=${confirm_ds:-Y}
        if [[ "$confirm_ds" =~ ^[Nn]$ ]]; then
            CREATE_DS="false"
        else
            CREATE_DS="true"
        fi
    fi

    if [ "$CREATE_DS" = "true" ]; then
        echo "Select Database Management System to use:"
        PS3="Enter choice: "
        options=("PostgreSQL" "MySQL" "MariaDB" "HSQLDB" "H2" "SQLServer" "Oracle" "Custom")
        select opt in "${options[@]}"; do
            case $opt in
                "PostgreSQL"|"MySQL"|"MariaDB"|"HSQLDB"|"H2"|"SQLServer"|"Oracle")
                    DBMS_TYPE=$opt
                    DRIVER_CLASS=${DBMS_DRIVERS[$opt]}
                    DEFAULT_PORT=${DBMS_DEFAULT_PORTS[$opt]}
                    URL_PREFIX=${DBMS_URL_PREFIXES[$opt]}
                    break
                    ;;
                "Custom")
                    read -p "Enter Driver Class Name: " DRIVER_CLASS
                    read -p "Enter JDBC URL Prefix (e.g., jdbc:postgresql://): " URL_PREFIX
                    DEFAULT_PORT="5432"
                    break
                    ;;
                *) echo "Invalid option $REPLY";;
            esac
        done

        read -p "Database Host [$DB_HOST]: " input_host
        DB_HOST=${input_host:-$DB_HOST}

        read -p "Database Port [$DEFAULT_PORT]: " input_port
        DB_PORT=${input_port:-$DEFAULT_PORT}

        read -p "Database Name [$DB_NAME]: " input_name
        DB_NAME=${input_name:-$DB_NAME}

        read -p "Database User [$DB_USER]: " input_user
        DB_USER=${input_user:-$DB_USER}

        read -p "Database Password [$DB_PASS]: " input_pass
        DB_PASS=${input_pass:-$DB_PASS}

        # Auto-construct URL if empty
        if [ -z "$DB_URL" ]; then
            if [ "$DBMS_TYPE" = "SQLServer" ]; then
                 DB_URL="${URL_PREFIX}${DB_HOST}:${DB_PORT};databaseName=${DB_NAME}"
            elif [ "$DBMS_TYPE" = "Oracle" ]; then
                 DB_URL="${URL_PREFIX}${DB_HOST}:${DB_PORT}:${DB_NAME}"
            else
                 DB_URL="${URL_PREFIX}${DB_HOST}:${DB_PORT}/${DB_NAME}"
            fi
        fi
    fi 
    
    echo "---"
    read -p "Welcome File [$WELCOME_FILE]: " input_welcome
    WELCOME_FILE=${input_welcome:-$WELCOME_FILE}
    
    read -p "Output JAR [$OUTPUT_JAR]: " input_output
    OUTPUT_JAR=${input_output:-$OUTPUT_JAR}
fi

# Final Validation
if [ "$CREATE_DS" = "true" ] && [ -z "$DRIVER_CLASS" ]; then
    # Fallback default if running non-interactive without specific driver
    DRIVER_CLASS="org.postgresql.ds.PGConnectionPoolDataSource"
    if [ -z "$DB_URL" ]; then
        DB_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
    fi
fi

echo "Generating configuration JAR..."
echo "Output: $OUTPUT_JAR"
if [ "$CREATE_DS" = "true" ]; then
    echo "Data Source: ENABLED"
    echo "  Driver: $DRIVER_CLASS"
    echo "  URL: $DB_URL"
    echo "  User: $DB_USER"
else
    echo "Data Source: DISABLED"
fi
echo "Welcome File: $WELCOME_FILE"

# Create temp directory
WORK_DIR=$(mktemp -d)
mkdir -p "$WORK_DIR/META-INF"

# Generate XML
cat <<XML > "$WORK_DIR/META-INF/web-fragment.xml"
<?xml version="1.0" encoding="UTF-8"?>
<web-fragment xmlns="https://jakarta.ee/xml/ns/jakartaee"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/web-fragment_3_0.xsd"
              version="3.0">
              
    <name>kupu_config</name>
XML

if [ "$CREATE_DS" = "true" ]; then
cat <<XML >> "$WORK_DIR/META-INF/web-fragment.xml"

    <data-source>
        <name>${DATA_SOURCE_NAME}</name>
        <class-name>${DRIVER_CLASS}</class-name>
        <url>${DB_URL}</url>
        <user>${DB_USER}</user>
        <password>${DB_PASS}</password>
        <max-pool-size>32</max-pool-size>
        <min-pool-size>8</min-pool-size>
    </data-source>
XML
fi

cat <<XML >> "$WORK_DIR/META-INF/web-fragment.xml"
    
    <welcome-file-list>
        <welcome-file>${WELCOME_FILE}</welcome-file>
    </welcome-file-list>
    
</web-fragment>
XML

# Create JAR
jar cvf "$OUTPUT_JAR" -C "$WORK_DIR" . > /dev/null

# Cleanup
rm -rf "$WORK_DIR"

echo "--------------------------------------------------"
echo "Success! Created $OUTPUT_JAR"
echo "Place this in WEB-INF/lib/ to apply configuration."
echo "--------------------------------------------------"
