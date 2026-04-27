#!/bin/bash
# Archive metrics to external storage with compression and rotation
# Addresses Comment 1: Store metrics in compressed format outside main repo

set -euo pipefail

METRICS_DIR=".claude-flow/metrics"
ARCHIVE_DIR=".claude-flow/metrics/archive"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=90

# Create archive directory if it doesn't exist
mkdir -p "$ARCHIVE_DIR"

# Function to archive a metrics file
archive_metrics() {
    local file=$1
    local basename=$(basename "$file" .json)
    
    if [ -f "$file" ]; then
        echo "Archiving $file..."
        
        # Convert to NDJSON format (one record per line) and compress
        jq -c '.[]' "$file" 2>/dev/null | gzip -9 > "$ARCHIVE_DIR/${basename}_${TIMESTAMP}.ndjson.gz" || \
        jq -c '.' "$file" 2>/dev/null | gzip -9 > "$ARCHIVE_DIR/${basename}_${TIMESTAMP}.ndjson.gz"
        
        # Clear the original file but keep it for new metrics
        echo "[]" > "$file"
        echo "Archived to $ARCHIVE_DIR/${basename}_${TIMESTAMP}.ndjson.gz"
    fi
}

# Archive all metrics files
for file in "$METRICS_DIR"/*.json; do
    [ -e "$file" ] || continue
    archive_metrics "$file"
done

# Clean up old archives (older than retention period)
echo "Cleaning up archives older than $RETENTION_DAYS days..."
find "$ARCHIVE_DIR" -name "*.ndjson.gz" -mtime +$RETENTION_DAYS -delete

echo "Metrics archival complete"

# Optional: Push to external storage (uncomment and configure as needed)
# aws s3 sync "$ARCHIVE_DIR" s3://your-metrics-bucket/claude-flow/ --delete
# gsutil rsync -r "$ARCHIVE_DIR" gs://your-metrics-bucket/claude-flow/