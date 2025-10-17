#!/bin/bash
# Concurrent JAR processes measurement
# Tests memory usage when running multiple JAR processes simultaneously

JAR_PATH="vendor/css-validator.jar"

# Test CSS content
TEST_CSS='body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
.container { max-width: 1200px; margin: 0 auto; }
.header { background: #333; color: white; padding: 20px; }
.content { padding: 40px 20px; }
.footer { background: #f5f5f5; padding: 20px; text-align: center; }'

[ ! -f "$JAR_PATH" ] && echo "Error: JAR not found at $JAR_PATH" && exit 1

# Cleanup
pkill -f css-validator 2>/dev/null
sleep 1

echo "=== Concurrent JAR Processes ==="
echo ""

# Function to test concurrent processes
test_concurrent() {
    local count=$1
    local java_opts="-Xmx32m -Xms16m -XX:+UseSerialGC"

    echo "$count concurrent process(es):"

    # Create temp files
    local temp_files=()
    for ((i=1; i<=count; i++)); do
        local tmp=$(mktemp --suffix=.css)
        echo "$TEST_CSS" > "$tmp"
        temp_files+=("$tmp")
    done

    # Start all processes
    local pids=()
    for tmp in "${temp_files[@]}"; do
        java $java_opts -jar "$JAR_PATH" --output=text --profile=css3svg "file://$tmp" > /dev/null 2>&1 &
        pids+=($!)
    done

    sleep 0.05

    # Monitor total memory
    local peak_total=0
    local samples=0

    while true; do
        local all_done=true
        local current_total=0

        for pid in "${pids[@]}"; do
            if kill -0 $pid 2>/dev/null; then
                all_done=false
                if [ -f "/proc/$pid/status" ]; then
                    local rss=$(grep VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}')
                    if [ -n "$rss" ]; then
                        current_total=$((current_total + rss))
                    fi
                fi
            fi
        done

        if [ $current_total -gt 0 ]; then
            samples=$((samples + 1))
            if [ $current_total -gt $peak_total ]; then
                peak_total=$current_total
            fi
        fi

        [ "$all_done" = true ] && break
        sleep 0.01
    done

    # Wait for all to finish
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null
    done

    # Cleanup temp files
    for tmp in "${temp_files[@]}"; do
        rm -f "$tmp"
    done

    # Calculate and display results
    if [ $samples -gt 0 ]; then
        local peak_mb=$(echo "scale=0; $peak_total / 1024" | bc)
        local avg_per_process=$(echo "scale=0; $peak_mb / $count" | bc)
        echo "  Peak total: ${peak_mb} MB"
        echo "  Average per process: ${avg_per_process} MB"
        echo "  Samples: $samples"
    else
        echo "  (No samples captured)"
    fi

    echo ""
    sleep 2  # Let processes fully cleanup
}

# Test with different concurrency levels
test_concurrent 1
test_concurrent 2
test_concurrent 5
test_concurrent 10

echo "Done!"
