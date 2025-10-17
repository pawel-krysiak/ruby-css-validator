#!/bin/bash
# Direct JAR performance measurement
# Measures memory consumption and validation speed of the CSS validator JAR

JAR_PATH="vendor/css-validator.jar"

# Test CSS content
TEST_CSS='body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
.container { max-width: 1200px; margin: 0 auto; }
.header { background: #333; color: white; padding: 20px; }
.content { padding: 40px 20px; }
.footer { background: #f5f5f5; padding: 20px; text-align: center; }'

[ ! -f "$JAR_PATH" ] && echo "Error: JAR not found at $JAR_PATH" && exit 1

# Cleanup any existing processes
pkill -f css-validator 2>/dev/null
sleep 1

echo "=== JAR Performance Test ==="
echo ""

# Create temp CSS file
TEMP_CSS=$(mktemp --suffix=.css)
echo "$TEST_CSS" > "$TEMP_CSS"

# Function to measure memory
measure_memory() {
    local java_opts="$1"
    local label="$2"

    echo "$label"

    # Start JVM
    if [ -z "$java_opts" ]; then
        java -jar "$JAR_PATH" --output=text --profile=css3svg "file://$TEMP_CSS" > /dev/null 2>&1 &
    else
        java $java_opts -jar "$JAR_PATH" --output=text --profile=css3svg "file://$TEMP_CSS" > /dev/null 2>&1 &
    fi

    local pid=$!
    sleep 0.05

    local samples=0
    local total_rss=0
    local peak_rss=0

    while kill -0 $pid 2>/dev/null; do
        if [ -f "/proc/$pid/status" ]; then
            local rss=$(grep VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}')
            if [ -n "$rss" ] && [ "$rss" -gt 0 ]; then
                local rss_mb=$(echo "scale=1; $rss / 1024" | bc)
                total_rss=$(echo "$total_rss + $rss_mb" | bc)
                samples=$((samples + 1))

                if (( $(echo "$rss_mb > $peak_rss" | bc -l) )); then
                    peak_rss=$rss_mb
                fi
            fi
        fi
        sleep 0.01
    done

    wait $pid

    if [ $samples -gt 0 ]; then
        local avg_rss=$(echo "scale=1; $total_rss / $samples" | bc)
        echo "  Peak: ${peak_rss} MB"
        echo "  Average: ${avg_rss} MB"
        echo "  Samples: $samples"
    else
        echo "  (No samples captured)"
    fi
}

# Test optimized JVM
measure_memory "-Xmx32m -Xms16m -XX:+UseSerialGC" "1. JVM Memory (-Xmx32m -Xms16m -XX:+UseSerialGC)"
echo ""

# Speed test
echo "2. Validation Speed"
for i in {1..3}; do
    TIME=$( { time java -Xmx32m -Xms16m -XX:+UseSerialGC -jar "$JAR_PATH" \
              --output=text --profile=css3svg "file://$TEMP_CSS" > /dev/null 2>&1; } 2>&1 | \
              grep real | awk '{print $2}')
    echo "  Run $i: $TIME"
done

# Cleanup
rm -f "$TEMP_CSS"

echo ""
echo "Done!"
