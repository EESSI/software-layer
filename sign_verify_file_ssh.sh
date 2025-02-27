#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 sign <file> <private_key> | verify <file> <public_key> [signature_file]"
    exit 1
}

# Ensure at least two arguments are provided
if [ "$#" -lt 3 ]; then
    usage
fi

MODE="$1"
FILE_TO_SIGN="$2"

# Ensure the file exists
if [ ! -f "$FILE_TO_SIGN" ]; then
    echo "Error: File '$FILE_TO_SIGN' not found."
    exit 1
fi

# Function to securely convert PEM to OpenSSH if needed
convert_pem_to_ssh() {
    local key_file="$1"
    local output_file="$2"

    if grep -q "BEGIN RSA PRIVATE KEY" "$key_file" || grep -q "BEGIN OPENSSH PRIVATE KEY" "$key_file"; then
        # Ensure cleanup on exit
        trap 'rm -f "$output_file" "$output_file.pub"' EXIT

        # Convert PEM key to OpenSSH format
        cp "$key_file" "$output_file" && ssh-keygen -c -C "Converted from PEM" -f "$output_file" || {
            echo "Error: Failed to convert PEM key to OpenSSH."
            exit 1
        }

        # Generate the public key
        ssh-keygen -y -f "$key_file" > "$output_file.pub" || {
            echo "Error: Failed to generate public key from PEM key."
            exit 1
        }
    else
        echo "$key_file doesn't look like a PEM format key!"
        exit 1
    fi
}

# Sign mode
if [ "$MODE" == "sign" ]; then
    PRIVATE_KEY_PEM="$3"
    PRIVATE_KEY="conversion_id"
    SIG_FILE="${FILE_TO_SIGN}.sig"
    PUB_KEY="${PRIVATE_KEY}.pub"

    if [ ! -f "$PRIVATE_KEY_PEM" ]; then
        echo "Error: Private key '$PRIVATE_KEY_PEM' not found."
        exit 1
    fi

    # Convert PEM key to OpenSSH if needed
    echo "Converting SSH key to OpenSSH format..."
    convert_pem_to_ssh "$PRIVATE_KEY_PEM" "$PRIVATE_KEY"

    # Sign the file
    echo "Signing the file..."
    ssh-keygen -Y sign -f "$PRIVATE_KEY" -n file "$FILE_TO_SIGN"

    if [ ! -f "$SIG_FILE" ]; then
        echo "Error: Signing failed."
        rm -f "$PRIVATE_KEY" "$PUB_KEY"
        exit 1
    fi

    echo "Signature created: $SIG_FILE"
    echo -e "\nAn allowed signatures file for this key would have contents like:\n"
    echo -e "some_name $(cat "$PUB_KEY")\n"

    # Verify the signature
    echo -e "Validating the signature of the file..."
    if ssh-keygen -Y check-novalidate -n file -f "$PUB_KEY" -s "$SIG_FILE" < "$FILE_TO_SIGN"; then
        echo "- Signature validation successful."
    else
        echo "- Signature validation failed."
        rm -f "$PRIVATE_KEY" "$PUB_KEY"
        exit 1
    fi

    rm -f "$PRIVATE_KEY" "$PUB_KEY"

# Verify mode
elif [ "$MODE" == "verify" ]; then
    ALLOWED_SIGNERS_FILE="$3"
    SIG_FILE="${4:-${FILE_TO_SIGN}.sig}"

    if [ ! -f "$ALLOWED_SIGNERS_FILE" ]; then
        echo "Error: Allowed signers file '$ALLOWED_SIGNERS_FILE' not found."
        exit 1
    fi

    if [ ! -f "$SIG_FILE" ]; then
        echo "Error: Signature file '$SIG_FILE' not found."
        exit 1
    fi

    # Loop through each line of the allowed_signers file
    while read -r identity pub_key; do
        # Check if identity and public key are not empty
        if [[ -n "$identity" && -n "$pub_key" ]]; then
            echo "Verifying signature for identity: $identity"

            # Use ssh-keygen to verify the signature (example with RSA)
            if ssh-keygen -Y verify -f "$ALLOWED_SIGNERS_FILE" -n file -I "$identity" -s "$SIG_FILE" < "$FILE_TO_SIGN"; then
                echo "Signature is valid for identity: $identity"
                exit 0  # Exit once we find a valid signature
            else
                echo "Invalid signature for identity: $identity"
            fi
        fi
    done < "$ALLOWED_SIGNERS_FILE"

    echo "No valid signature found in allowed signers. The allowed signers file should contain entries in the format: <identity> <public key in OpenSSH format>."
    exit 1

else
    usage
fi

