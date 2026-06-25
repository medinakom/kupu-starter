#!/bin/bash

# Configuration
H2_DATA_DIR="db"
H2_PORT="9092"
H2_WEB_PORT="8082"
H2_JAR_DIR="jdbc"
PID_FILE=".h2.pid"

# Locate H2 JAR
H2_JAR=$(find "$H2_JAR_DIR" -name "h2-*.jar" | head -n 1)

if [ -z "$H2_JAR" ]; then
    echo "❌ Error: H2 JAR not found in $H2_JAR_DIR/"
    exit 1
fi

function start_server {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            echo "⚠️ H2 Server is already running (PID: $PID)"
            return
        fi
        rm "$PID_FILE"
    fi

    mkdir -p "$H2_DATA_DIR"
    
    echo "🚀 Starting H2 Database Server..."
    echo "   TCP Port: $H2_PORT"
    echo "   Web Port: $H2_WEB_PORT"
    echo "   Data Dir: $(pwd)/$H2_DATA_DIR"
    
    # Run in background
    java -cp "$H2_JAR" org.h2.tools.Server \
        -tcp -tcpAllowOthers -tcpPort "$H2_PORT" \
        -web -webAllowOthers -webPort "$H2_WEB_PORT" \
        -baseDir "$(pwd)/$H2_DATA_DIR" \
        -ifNotExists > h2_server.log 2>&1 &
    
    PID=$!
    echo $PID > "$PID_FILE"
    echo "✅ H2 Server started with PID $PID"
    echo "🔗 Web Console: http://localhost:$H2_WEB_PORT"
}

function stop_server {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        echo "🛑 Stopping H2 Server (PID: $PID)..."
        kill $PID
        rm "$PID_FILE"
        echo "✅ Stopped."
    else
        echo "⚠️ No PID file found. H2 Server might not be running."
    fi
}

function show_status {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            echo "🟢 H2 Server is running (PID: $PID)"
            echo "🔗 Web Console: http://localhost:$H2_WEB_PORT"
        else
            echo "🔴 H2 Server is NOT running (Stale PID file found)"
        fi
    else
        echo "⚪ H2 Server is NOT running."
    fi
}

case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    status)
        show_status
        ;;
    restart)
        stop_server
        sleep 1
        start_server
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
