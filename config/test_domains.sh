#!/bin/bash
OUTPUT_FILE="config/verification_results.txt"
echo "DNS Verification Results - $(date)" > "$OUTPUT_FILE"
echo "------------------------------------------------" >> "$OUTPUT_FILE"

domains=(
    "cmsimages.capp.bka.sh"
    "images.capp.bka.sh"
    "eventapi.capp.bka.sh"
    "api.cde.capp.bka.sh"
    "bka.sh"
    "ip-api.com"
    "connectivitycheck.gstatic.com"
    "mynagad.com"
    "api.upaysystem.com"
    "upaysystem.com"
    "bkash.com"
    "nagad.com.bd"
    "dutchbanglabank.com"
    "alaap.gov.bd"
    "app.brilliant.com.bd"
)

for domain in "${domains[@]}"; do
    echo "Testing: $domain" | tee -a "$OUTPUT_FILE"
    result=$(dig @127.0.0.1 -p 53 "$domain" +short 2>&1)
    if [ -z "$result" ]; then
        echo "  [FAIL] No resolution" | tee -a "$OUTPUT_FILE"
    else
        echo "  [PASS] Resolved to:" | tee -a "$OUTPUT_FILE"
        echo "$result" | sed 's/^/    /' | tee -a "$OUTPUT_FILE"
    fi
    echo "------------------------------------------------" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done

echo "Verification complete. Results saved to $OUTPUT_FILE"
