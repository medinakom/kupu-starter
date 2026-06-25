#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Configuration
DEFAULT_JAR="$PROJECT_ROOT/src/main/webapp/WEB-INF/lib/kupu-config.jar"
CONFIG_FILE="META-INF/web-fragment.xml"
DRIVER_POOL_DIR="$PROJECT_ROOT/jdbc"
WEB_INF_LIB="$PROJECT_ROOT/src/main/webapp/WEB-INF/lib"

# Default Values for Creation
DB_HOST="localhost"
DB_PORT=""
DB_NAME="kupu"
DB_USER=""
DB_PASS=""
DB_URL=""
MAX_POOL_SIZE="32"
MIN_POOL_SIZE="8"
WELCOME_FILE="index.xhtml"
OUTPUT_JAR="$DEFAULT_JAR"
DRIVER_CLASS=""
CREATE_DS="true"
SKIP_INTERACTIVE=false
DRY_RUN=false

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
)

DBMS_DEFAULT_PORTS=(
    ["PostgreSQL"]="5432"
    ["MySQL"]="3306"
    ["MariaDB"]="3306"
    ["HSQLDB"]="9001"
    ["H2"]="9092"
)

DBMS_URL_PREFIXES=(
    ["PostgreSQL"]="jdbc:postgresql://"
    ["MySQL"]="jdbc:mysql://"
    ["MariaDB"]="jdbc:mariadb://"
    ["HSQLDB"]="jdbc:hsqldb:hsql://"
    ["H2"]="jdbc:h2:tcp://"
)

declare -A DBMS_JAR_PATTERNS
DBMS_JAR_PATTERNS=(
    ["PostgreSQL"]="postgresql-*.jar"
    ["MySQL"]="mysql-connector-j-*.jar"
    ["MariaDB"]="mariadb-java-client-*.jar"
    ["HSQLDB"]="hsqldb-*.jar"
    ["H2"]="h2-*.jar"
)

function show_help {
    echo "Kupu Configuration Management Tool"
    echo ""
    echo "Usage: ./manage-config-jar.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create               Generate a new configuration JAR (interactive wizard or flags)"
    echo "  testdb               Test database connection with current parameters"
    echo "  extract [jar] [out]  Extract $CONFIG_FILE from the JAR for manual editing"
    echo "  repack  [jar] [in]   Repack the config file back into the JAR"
    echo ""
    echo "Defaults:"
    echo "  JAR path:    $DEFAULT_JAR"
    echo "  Config file: [JAR-DIR]/web-fragment.xml"
    echo "  --host <host>          Database host"
    echo "  --port <port>          Database port"
    echo "  --db <name>            Database name"
    echo "  --user <user>          Database user"
    echo "  --pass <pass>          Database password"
    echo "  --url <jdbc-url>       Full JDBC URL (overrides host/port/name)"
    echo "  --dry-run              Skip connection test after creation"
    echo "  --welcome <file>       Welcome file (default: index.xhtml)"
    echo "  --output <file>        Output JAR file path (default: $DEFAULT_JAR)"
    echo "  --driver <class>       DataSource Class Name"
    echo "  --max-pool <size>      Maximum Pool Size (default: 32)"
    echo "  --min-pool <size>      Minimum Pool Size (default: 8)"
    echo "  --no-interactive       Skip interactive prompts"
    echo "  --no-ds                Do not create a data source"
}

function run_create {
    # Parse Arguments (starting from the second parameter)
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --host) DB_HOST="$2"; shift ;;
            --port) DB_PORT="$2"; shift ;;
            --db) DB_NAME="$2"; shift ;;
            --user) DB_USER="$2"; shift ;;
            --pass) DB_PASS="$2"; shift ;;
            --url) DB_URL="$2"; shift ;;
            --dry-run) DRY_RUN=true ;;
            --welcome) WELCOME_FILE="$2"; shift ;;
            --output) OUTPUT_JAR="$2"; shift ;;
            --driver) DRIVER_CLASS="$2"; shift ;;
            --dbms) DBMS_TYPE="$2"; shift ;;
            --max-pool) MAX_POOL_SIZE="$2"; shift ;;
            --min-pool) MIN_POOL_SIZE="$2"; shift ;;
            --no-interactive) SKIP_INTERACTIVE=true ;;
            --no-ds) CREATE_DS="false" ;;
        esac
        shift
    done

    # Interactive Mode
    if [ "$SKIP_INTERACTIVE" = false ]; then
        echo "=== Kupu Configuration Wizard ==="
        
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
            options=("PostgreSQL" "MySQL" "MariaDB" "HSQLDB" "H2" "Custom")
            select opt in "${options[@]}"; do
                case $opt in
                    "PostgreSQL"|"MySQL"|"MariaDB"|"HSQLDB"|"H2")
                        DBMS_TYPE=$opt
                        DRIVER_CLASS=${DBMS_DRIVERS[$opt]}
                        DEFAULT_PORT=${DBMS_DEFAULT_PORTS[$opt]}
                        URL_PREFIX=${DBMS_URL_PREFIXES[$opt]}
                        if [ "$opt" = "H2" ]; then
                            DB_USER="sa"
                            DB_PASS=""
                        fi
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

            if [ "$DBMS_TYPE" = "H2" ]; then
                 CONSTRUCTED_URL="${URL_PREFIX}${DB_HOST}:${DB_PORT}/./${DB_NAME}"
            else
                 CONSTRUCTED_URL="${URL_PREFIX}${DB_HOST}:${DB_PORT}/${DB_NAME}"
            fi
            
            read -p "Database URL [$CONSTRUCTED_URL]: " input_url
            DB_URL=${input_url:-$CONSTRUCTED_URL}

            read -p "Max Pool Size [$MAX_POOL_SIZE]: " input_max
            MAX_POOL_SIZE=${input_max:-$MAX_POOL_SIZE}

            read -p "Min Pool Size [$MIN_POOL_SIZE]: " input_min
            MIN_POOL_SIZE=${input_min:-$MIN_POOL_SIZE}
        fi 
        
        echo "---"
        read -p "Welcome File [$WELCOME_FILE]: " input_welcome
        WELCOME_FILE=${input_welcome:-$WELCOME_FILE}
        read -p "Output JAR [$OUTPUT_JAR]: " input_output
        OUTPUT_JAR=${input_output:-$OUTPUT_JAR}
    fi

    # Final Validation
    if [ "$CREATE_DS" = "true" ] && [ -z "$DRIVER_CLASS" ]; then
        DBMS_TYPE=${DBMS_TYPE:-H2}
        DRIVER_CLASS=${DBMS_DRIVERS[$DBMS_TYPE]}
        [ -z "$DB_URL" ] && [ "$DBMS_TYPE" = "H2" ] && DB_URL="jdbc:h2:tcp://localhost:9092/./${DB_NAME}"
        [ -z "$DB_USER" ] && [ "$DBMS_TYPE" = "H2" ] && DB_USER="sa"
        [ -z "$DB_PASS" ] && [ "$DBMS_TYPE" = "H2" ] && DB_PASS=""
    fi

    # Automated Driver Injection
    if [ "$CREATE_DS" = "true" ] && [ -n "$DBMS_TYPE" ] && [ "$DBMS_TYPE" != "Custom" ]; then
        local pattern=${DBMS_JAR_PATTERNS[$DBMS_TYPE]}
        local source_jar=""
        if [ -d "$DRIVER_POOL_DIR" ]; then
            source_jar=$(find "$DRIVER_POOL_DIR" -name "$pattern" | head -n 1)
        fi
        
        if [ -n "$source_jar" ]; then
            echo "🚚 Injecting JDBC Driver for $DBMS_TYPE..."
            mkdir -p "$WEB_INF_LIB"
            # Remove existing drivers from LIB folder
            for p in "${DBMS_JAR_PATTERNS[@]}"; do
                rm -f "$WEB_INF_LIB"/$p
            done
            cp "$source_jar" "$WEB_INF_LIB/"
            echo "✅ Driver synced to $WEB_INF_LIB/"
        else
            echo "⚠️ Warning: Driver for $DBMS_TYPE not found in $DRIVER_POOL_DIR folder."
        fi
    fi

    echo "Generating configuration JAR..."
    echo "Output: $OUTPUT_JAR"
    
    WORK_DIR=$(mktemp -d)
    mkdir -p "$WORK_DIR/META-INF"

    cat <<XML > "$WORK_DIR/$CONFIG_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<web-fragment xmlns="https://jakarta.ee/xml/ns/jakartaee"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/web-fragment_6_0.xsd"
              version="6.0">
              
    <name>kupu_config</name>
XML

    if [ "$CREATE_DS" = "true" ]; then
    cat <<XML >> "$WORK_DIR/$CONFIG_FILE"
    <data-source>
        <name>java:global/KupuDataSource</name>
        <class-name>${DRIVER_CLASS}</class-name>
        <url>${DB_URL}</url>
        <user>${DB_USER}</user>
        <password>${DB_PASS}</password>
        <max-pool-size>${MAX_POOL_SIZE}</max-pool-size>
        <min-pool-size>${MIN_POOL_SIZE}</min-pool-size>
    </data-source>
XML
    fi

    cat <<XML >> "$WORK_DIR/$CONFIG_FILE"
    <welcome-file-list>
        <welcome-file>${WELCOME_FILE}</welcome-file>
    </welcome-file-list>
</web-fragment>
XML

    jar cvf "$OUTPUT_JAR" -C "$WORK_DIR" . > /dev/null
    rm -rf "$WORK_DIR"
    echo "✅ Success! Created $OUTPUT_JAR"

    if [ "$CREATE_DS" = "true" ] && [ "$DRY_RUN" = false ]; then
        echo ""
        echo "🔄 Automatically verifying connection..."
        run_testdb "$OUTPUT_JAR"
    fi
}

function run_extract {
    local jar_path=${1:-$DEFAULT_JAR}
    local output_path=${2}
    
    if [ ! -f "$jar_path" ]; then
        echo "❌ Error: JAR file not found at $jar_path"
        exit 1
    fi
    
    local jar_dir=$(dirname "$jar_path")
    if [ -z "$output_path" ]; then
        output_path="${jar_dir}/web-fragment.xml"
    fi

    # Ensure output_path is absolute if we're going to change directory
    local abs_output=$(mkdir -p "$(dirname "$output_path")" && cd "$(dirname "$output_path")" && pwd)/$(basename "$output_path")
    local abs_jar=$(cd "$(dirname "$jar_path")" && pwd)/$(basename "$jar_path")

    echo "📂 Extracting $CONFIG_FILE from $(basename "$jar_path")..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    jar xf "$abs_jar" "$CONFIG_FILE"
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$abs_output"
        cd - > /dev/null
        rm -rf "$temp_dir"
        echo "✅ Extracted to $output_path"
    else
        echo "❌ Error: $CONFIG_FILE not found in $(basename "$jar_path")"
        cd - > /dev/null
        rm -rf "$temp_dir"
        exit 1
    fi
}

function run_repack {
    local jar_path=${1:-$DEFAULT_JAR}
    local input_path=${2}
    
    if [ ! -f "$jar_path" ]; then
        echo "❌ Error: Target JAR not found at $jar_path"
        exit 1
    fi
    
    local jar_dir=$(dirname "$jar_path")
    if [ -z "$input_path" ]; then
        input_path="${jar_dir}/web-fragment.xml"
    fi

    if [ ! -f "$input_path" ]; then
        echo "❌ Error: Configuration file not found at $input_path"
        exit 1
    fi

    local abs_jar=$(cd "$(dirname "$jar_path")" && pwd)/$(basename "$jar_path")
    local abs_input=$(cd "$(dirname "$input_path")" && pwd)/$(basename "$input_path")

    echo "📦 Repacking $input_path into $(basename "$jar_path")..."
    
    local temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/META-INF"
    cp "$abs_input" "$temp_dir/$CONFIG_FILE"
    
    cd "$temp_dir" || exit 1
    jar uf "$abs_jar" "$CONFIG_FILE"
    local status=$?
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    if [ $status -eq 0 ]; then
        echo "✅ Successfully updated $(basename "$jar_path")"
    else
        echo "❌ Repacking failed."
        exit 1
    fi
}

function run_testdb {
    local jar_path=${1:-$DEFAULT_JAR}
    
    if [ ! -f "$jar_path" ]; then
        echo "❌ Error: JAR file not found at $jar_path"
        exit 1
    fi

    echo "📂 Reading configuration from $(basename "$jar_path")..."
    
    local temp_dir=$(mktemp -d)
    local abs_jar=$(cd "$(dirname "$jar_path")" && pwd)/$(basename "$jar_path")
    
    # Extract web-fragment.xml
    (cd "$temp_dir" && jar xf "$abs_jar" "$CONFIG_FILE" 2>/dev/null)
    
    if [ ! -f "$temp_dir/$CONFIG_FILE" ]; then
        echo "❌ Error: $CONFIG_FILE not found in $(basename "$jar_path")"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Parse Parameters from XML
    local xml_content=$(cat "$temp_dir/$CONFIG_FILE")
    
    # Simple extraction using grep and sed
    local jar_url=$(echo "$xml_content" | grep "<url>" | sed -e 's/.*<url>\(.*\)<\/url>.*/\1/')
    local jar_user=$(echo "$xml_content" | grep "<user>" | sed -e 's/.*<user>\(.*\)<\/user>.*/\1/')
    local jar_pass=$(echo "$xml_content" | grep "<password>" | sed -e 's/.*<password>\(.*\)<\/password>.*/\1/')
    local jar_driver=$(echo "$xml_content" | grep "<class-name>" | sed -e 's/.*<class-name>\(.*\)<\/class-name>.*/\1/')

    if [ -z "$jar_url" ] || [ -z "$jar_driver" ]; then
        echo "❌ Error: Could not parse Data Source configuration from $jar_path"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Identify DBMS Type from Driver Class to find the correct JAR
    local dbms_found=""
    for k in "${!DBMS_DRIVERS[@]}"; do
        if [ "${DBMS_DRIVERS[$k]}" == "$jar_driver" ]; then
            dbms_found=$k
            break
        fi
    done

    if [ -z "$dbms_found" ]; then
        echo "❓ Unknown Driver Class: $jar_driver. Attempting to match by URL prefix..."
        for k in "${!DBMS_URL_PREFIXES[@]}"; do
            if [[ "$jar_url" == ${DBMS_URL_PREFIXES[$k]}* ]]; then
                dbms_found=$k
                break
            fi
        done
    fi

    if [ -z "$dbms_found" ]; then
        echo "❌ Error: Could not identify DBMS type for driver $jar_driver"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Find Driver JAR (Check Pool first, then Lib)
    local pattern=${DBMS_JAR_PATTERNS[$dbms_found]}
    local driver_jar=""
    if [ -d "$DRIVER_POOL_DIR" ]; then
        driver_jar=$(find "$DRIVER_POOL_DIR" -name "$pattern" | head -n 1)
    fi
    if [ -z "$driver_jar" ] && [ -d "$WEB_INF_LIB" ]; then
        driver_jar=$(find "$WEB_INF_LIB" -name "$pattern" | head -n 1)
    fi

    if [ -z "$driver_jar" ]; then
        echo "❌ Error: Driver JAR for $dbms_found not found in $DRIVER_POOL_DIR or $WEB_INF_LIB (Pattern: $pattern)"
        rm -rf "$temp_dir"
        exit 1
    fi

    echo "🔍 Testing Connection to $dbms_found..."
    echo "   URL:    $jar_url"
    echo "   User:   $jar_user"
    echo "   Driver: $jar_driver"
    echo "   JAR:    $driver_jar"
    echo "---"

    local java_file="$temp_dir/TestConn.java"
    cat <<JAVA > "$java_file"
import java.sql.Connection;
import java.sql.DriverManager;

public class TestConn {
    public static void main(String[] args) {
        String url = args[0];
        String user = args[1];
        String pass = args[2];
        String driver = args[3];

        try {
            Class.forName(driver);
            DriverManager.setLoginTimeout(5);
            try (Connection conn = DriverManager.getConnection(url, user, pass)) {
                System.out.println("✅ Connection successful!");
            }
        } catch (Exception e) {
            System.err.println("❌ Connection failed: " + e.getMessage());
            System.exit(1);
        }
    }
}
JAVA

    # Compile and run
    javac -cp "$driver_jar" "$java_file"
    if [ $? -eq 0 ]; then
        java -cp "$temp_dir:$driver_jar" TestConn "$jar_url" "$jar_user" "$jar_pass" "$jar_driver"
        status=$?
    else
        echo "❌ Failed to compile connection tester."
        status=1
    fi

    rm -rf "$temp_dir"
    return $status
}

# Command Dispatcher
COMMAND=$1
shift # remove the command from args

case $COMMAND in
    create|wizard)
        run_create "$@"
        ;;
    testdb)
        run_testdb "$@"
        exit $?
        ;;
    extract)
        run_extract "$@"
        ;;
    repack)
        run_repack "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [ -n "$COMMAND" ]; then
            echo "❌ Unknown command: $COMMAND"
        fi
        show_help
        exit 1
        ;;
esac
