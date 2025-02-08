#!/bin/bash

# ------------------------------------------------------------------------------
# Copyright Notice:
#
# File Name: cert_convert.sh
# Version: 1.0
# Author: 3kk0
# Date Created: 2025-02-08
# Last Modified: 2025-02-08
# Copyright: © 3kk0, 2025. All rights reserved.
#
# Licensed under the MIT License. See LICENSE file for more details.
#
# Disclaimer:
# This script is provided for reference only. The author assumes no responsibility
# for any consequences resulting from the use of this script.
# Please modify and test the script according to your environment and needs to
# ensure its applicability and security.
# ------------------------------------------------------------------------------
# Description:
# This script automates the process of converting PEM certificates to PKCS #12 format.
# It checks for updates in the certificate, performs conversion, and updates the hash
# of the certificate for future comparisons.
#
# It is intended for use with Let's Encrypt certificates, but can be modified for other use cases.
# ------------------------------------------------------------------------------

# Constants
CERT_DIR="/path/to/your/certificate/directory"  # Path to Let's Encrypt certificate directory
DOMAIN="yourdomain.com"  # Domain name
PFX_FILE="${CERT_DIR}/${DOMAIN}.pfx"  # Output .pfx file path
CERTHASH_FILE="${CERT_DIR}/carthash"  # File to store the cert.pem hash

# Input files
CERT_FILE="${CERT_DIR}/cert.pem"  # Certificate file path
CHAIN_FILE="${CERT_DIR}/chain.pem"  # Certificate chain file path
KEY_FILE="${CERT_DIR}/privkey.pem"  # Private key file path

# PFX password
PFX_PASSWORD="your_pfx_password"  # Replace with the actual PFX password

# Log file path
LOG_FILE="${CERT_DIR}/convert.log"  # Log file path

# Temporary file for capturing openssl output
TEMP_FILE=$(mktemp)

# Function to perform certificate conversion
convert_cert() {
    # Execute conversion command
    if openssl pkcs12 -export -out "$PFX_FILE" -inkey "$KEY_FILE" -in "$CERT_FILE" -certfile "$CHAIN_FILE" -password pass:"$PFX_PASSWORD" > "$TEMP_FILE" 2>&1; then
        # Conversion successful
        CERT_VALIDITY=$(date -d "$(openssl x509 -enddate -noout -in "$CERT_FILE" | sed 's/^.*=//')" +"%Y-%m-%d")

        # Log success and display certificate expiration date
        echo "[$(date)] Certificate conversion successful. Certificate expiration date: $CERT_VALIDITY" >> "$LOG_FILE"

        # Update the cert.pem hash value
        echo "$CURRENT_HASH" > "$CERTHASH_FILE"
    else
        # Conversion failed, log the error
        ERROR_MSG=$(cat "$TEMP_FILE")
        echo "[$(date)] Certificate conversion failed, error message: $ERROR_MSG" >> "$LOG_FILE"
    fi
}

# Check if the carthash file exists
if [ ! -f "$CERTHASH_FILE" ]; then
    echo "[$(date)] Starting new PKCS #12 certificate creation." >> "$LOG_FILE"

    # Perform certificate conversion
    convert_cert
    # Save the cert.pem hash value
    openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | sed 's/^.*=//' > "$CERTHASH_FILE"
else
    # carthash file exists, check if the hash values are different
    CURRENT_HASH=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | sed 's/^.*=//')
    STORED_HASH=$(cat "$CERTHASH_FILE")

    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "[$(date)] The original certificate has been updated. Synchronizing and updating the PKCS #12 certificate." >> "$LOG_FILE"

        # Perform certificate conversion
        convert_cert

        # Update the cert.pem hash value
        echo "$CURRENT_HASH" > "$CERTHASH_FILE"
    fi
fi

# Delete the temporary file
rm -f "$TEMP_FILE"
