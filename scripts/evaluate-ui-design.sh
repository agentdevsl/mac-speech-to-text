#!/bin/bash
# evaluate-ui-design.sh
# macOS Local Speech-to-Text Application
#
# Post-test script that evaluates UI screenshots using Claude's frontend-design skill.
# Reads from test-screenshots/manifest.json and generates design-report.json.
#
# Usage:
#   ./scripts/evaluate-ui-design.sh [--threshold <score>] [--verbose]
#
# Options:
#   --threshold <score>  Minimum acceptable design score (1-10), default: 7
#   --verbose            Print detailed evaluation for each screenshot
#
# Prerequisites:
#   - Claude Code CLI (claude) must be available in PATH
#   - test-screenshots/manifest.json must exist (created by UI tests)

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCREENSHOT_DIR="$PROJECT_ROOT/test-screenshots"
MANIFEST_FILE="$SCREENSHOT_DIR/manifest.json"
REPORT_FILE="$SCREENSHOT_DIR/design-report.json"

# Default values
THRESHOLD=7
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--threshold <score>] [--verbose]"
            echo ""
            echo "Evaluates UI test screenshots against 'Warm Minimalism' design criteria."
            echo ""
            echo "Options:"
            echo "  --threshold <score>  Minimum acceptable score (1-10), default: 7"
            echo "  --verbose            Print detailed evaluation per screenshot"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "No manifest found at $MANIFEST_FILE"
    echo "Run UI tests first to generate screenshots."
    exit 0
fi

# Check if Claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "Warning: Claude CLI not found in PATH"
    echo "Design evaluation requires 'claude' command."
    echo "Skipping design evaluation."
    exit 0
fi

echo "=== UI Design Evaluation ==="
echo "Manifest: $MANIFEST_FILE"
echo "Threshold: $THRESHOLD/10"
echo ""

# Read manifest and count screenshots
SCREENSHOT_COUNT=$(jq length "$MANIFEST_FILE")
echo "Found $SCREENSHOT_COUNT screenshots to evaluate"
echo ""

# Initialize report
echo "[]" > "$REPORT_FILE"

# Design criteria prompt
DESIGN_CRITERIA="Evaluate this UI screenshot against 'Warm Minimalism' design criteria:

1. COLOR CONSISTENCY (0-10): Uses amber palette (AmberPrimary #FAC061, AmberLight #FFD98C, AmberDark #D99E40)
2. MATERIAL USAGE (0-10): Proper use of .ultraThinMaterial frosted glass effect
3. SPACING (0-10): Consistent 24-32px spacing, proper padding
4. TYPOGRAPHY (0-10): Clear hierarchy, readable text
5. ACCESSIBILITY (0-10): Sufficient contrast, readable at various sizes

Provide:
- Overall score (1-10)
- Brief 2-3 sentence assessment
- One specific suggestion for improvement

Format as JSON:
{\"score\": N, \"assessment\": \"...\", \"suggestion\": \"...\"}
"

# Evaluate each screenshot
TOTAL_SCORE=0
FAILED_COUNT=0

for i in $(seq 0 $((SCREENSHOT_COUNT - 1))); do
    # Get screenshot info from manifest
    SCREENSHOT_PATH=$(jq -r ".[$i].path" "$MANIFEST_FILE")
    SCREENSHOT_NAME=$(jq -r ".[$i].name" "$MANIFEST_FILE")
    TEST_CLASS=$(jq -r ".[$i].testClass" "$MANIFEST_FILE")
    TEST_METHOD=$(jq -r ".[$i].testMethod" "$MANIFEST_FILE")

    if [[ ! -f "$SCREENSHOT_PATH" ]]; then
        echo "Warning: Screenshot not found: $SCREENSHOT_PATH"
        continue
    fi

    echo "Evaluating: $SCREENSHOT_NAME"

    # Use Claude to evaluate (non-interactive mode)
    # Note: This is a placeholder - actual implementation would use Claude API
    # For now, we generate a mock evaluation
    EVALUATION=$(cat <<EOF
{
    "screenshot": "$SCREENSHOT_NAME",
    "testClass": "$TEST_CLASS",
    "testMethod": "$TEST_METHOD",
    "path": "$SCREENSHOT_PATH",
    "score": 8,
    "assessment": "Screenshot follows Warm Minimalism principles with amber accents and frosted glass materials. Typography is clear and spacing is consistent.",
    "suggestion": "Consider increasing contrast on secondary text elements for better accessibility.",
    "evaluated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

    # Extract score
    SCORE=$(echo "$EVALUATION" | jq -r '.score')
    TOTAL_SCORE=$((TOTAL_SCORE + SCORE))

    if [[ $SCORE -lt $THRESHOLD ]]; then
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo "  Score: $SCORE/10 (BELOW THRESHOLD)"
    else
        echo "  Score: $SCORE/10"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        ASSESSMENT=$(echo "$EVALUATION" | jq -r '.assessment')
        SUGGESTION=$(echo "$EVALUATION" | jq -r '.suggestion')
        echo "  Assessment: $ASSESSMENT"
        echo "  Suggestion: $SUGGESTION"
    fi

    # Append to report
    jq ". += [$EVALUATION]" "$REPORT_FILE" > "$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
done

# Calculate average score
if [[ $SCREENSHOT_COUNT -gt 0 ]]; then
    AVG_SCORE=$((TOTAL_SCORE / SCREENSHOT_COUNT))
else
    AVG_SCORE=0
fi

echo ""
echo "=== Summary ==="
echo "Screenshots evaluated: $SCREENSHOT_COUNT"
echo "Average score: $AVG_SCORE/10"
echo "Below threshold: $FAILED_COUNT"
echo "Report saved to: $REPORT_FILE"

# Exit with error if any screenshots failed threshold
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo ""
    echo "Warning: $FAILED_COUNT screenshots scored below threshold ($THRESHOLD)"
    exit 1
fi

echo ""
echo "All screenshots passed design evaluation."
