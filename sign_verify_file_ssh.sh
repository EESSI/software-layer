#!/bin/bash
# SSH Signature Signing and Verification Script
# - Generate a digital signature for a file using an SSH private key.
# - Verify the signature of a signed file using an allowed signers file.
#
# The script generates a signature file named `<file>.sig` in the same directory.

# Usage message
usage() {
    echo "This script allows you to securely sign files using an SSH private key and verify signatures using an allowed signers file."
    echo "Usage:"
    echo "  $0 sign <private_key> <file>"
    echo "  $0 verify <allowed_signers_file> <file> [signature_file]"
    echo "where"
    echo "- <private_key>: Path to the SSH private key (if a KEY_passphrase exists it can be"
    echo "                 provided via the KEY_PASSPHRASE environment variable)"
    echo "- <file>: Path to the file to be signed/verified"
    echo "- <allowed_signers_file>: Path to the allowed signers file"
    echo "- [signature_file]: (optional) Path to the signature file"
    echo "                    (defaults to '<file>.sig' if not provided)."
    echo
    exit 1
}

# Error codes
FILE_PROBLEM=1
CONVERSION_FAILURE=2
VALIDATION_FAILED=3

# Ensure at least three arguments are provided
if [ "$#" -lt 3 ]; then
    usage
fi

MODE="$1"
FILE_TO_SIGN="$3"

# Ensure the file exists
if [ ! -f "$FILE_TO_SIGN" ]; then
    echo "Error: File '$FILE_TO_SIGN' not found."
    exit 1
fi

# Function to securely convert the private key to OpenSSH format
# (which is required for signing)
convert_private_key_to_openssh_format() {
    local key_file="$1"
    local output_file="$2"

    # Convert the key to OpenSSH format (the default format hence no '-m <format>') for any input format
    # (first copy the file as it will be overwritten during the conversion)
    echo "Copying $key_file to $output_file and performing format conversion"
    cp "$key_file" "$output_file" || {
        echo "Copy failed"
        exit $FILE_PROBLEM
    }
    ssh-keygen -p -f "$output_file" -P "$KEY_PASSPHRASE" -N "$KEY_PASSPHRASE" || {
        echo "Error: Failed to convert key $key_file to OpenSSH format"
        echo "(set the environment variable KEY_PASSPHRASE to use a passphrase for the key)."
        exit $CONVERSION_FAILURE
    }

    # Generate the public key from the private key
    ssh-keygen -y -f "$key_file" -P "$KEY_PASSPHRASE"> "$output_file.pub" || {
        echo "Error: Failed to generate public key from PEM key."
        exit $CONVERSION_FAILURE
    }
}

# Sign mode
if [ "$MODE" == "sign" ]; then
    PRIVATE_KEY_ORIG="$2"
    PRIVATE_KEY="conversion_id"
    SIG_FILE="${FILE_TO_SIGN}.sig"
    PUB_KEY="${PRIVATE_KEY}.pub"
    
    # Ensure cleanup on exit of our temporary key
    trap 'rm -f "$PRIVATE_KEY" "$PUB_KEY"' EXIT
    
    if [ ! -f "$PRIVATE_KEY_ORIG" ]; then
        echo "Error: Private key '$PRIVATE_KEY_ORIG' not found."
        exit $FILE_PROBLEM
    fi
    if [ -f "$SIG_FILE" ]; then
        echo "Error: Signature file '$SIG_FILE' already exists. Please remove to re-sign!"
        exit $FILE_PROBLEM
    fi
    # Convert key to OpenSSH format
    echo "Converting SSH key to OpenSSH format..."
    convert_private_key_to_openssh_format "$PRIVATE_KEY_ORIG" "$PRIVATE_KEY"

    # Sign the file
    echo "Signing the file..."
    ssh-keygen -Y sign -f "$PRIVATE_KEY" -P "$KEY_PASSPHRASE" -n file "$FILE_TO_SIGN"

    if [ ! -f "$SIG_FILE" ]; then
        echo "Error: Signing failed, no file $SIG_FILE found."
        exit $FILE_PROBLEM
    fi

    echo "Signature created: $SIG_FILE"
    echo -e "\nAn allowed signatures file has the format:"
    echo -e "\n<principal-list> <optional options> <public-key>\n"
    echo -e "and so for the provided key could have contents like:\n"
    echo -e "identity_1 $(cat "$PUB_KEY")\n"

    # Verify the signature
    echo -e "Validating the signature of the file..."
    ssh-keygen -Y check-novalidate -n file -f "$PUB_KEY" -s "$SIG_FILE" < "$FILE_TO_SIGN" || {
        echo "- Signature validation failed."
        exit $VALIDATION_FAILED
    }

# Verify mode
elif [ "$MODE" == "verify" ]; then
    ALLOWED_SIGNERS_FILE="$2"
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
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines or comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Extract principals (field 1)
        principals=$(echo "$line" | cut -d' ' -f1)
        echo "$principals"

        # Iterate over each principal (comma-separated)
        OLD_IFS=$IFS
        IFS=',' read -ra principal_list <<< "$principals"
        IFS=$OLD_IFS

        for principal in "${principal_list[@]}"; do
            echo "Processing Principal: $principal"

            # Use ssh-keygen to verify the signature
            if ssh-keygen -Y verify -f "$ALLOWED_SIGNERS_FILE" -n file -I "$principal" -s "$SIG_FILE" < "$FILE_TO_SIGN"; then
                echo -e "\nSignature is valid for principal: $principal"
                exit 0  # Exit on first valid signature
            else
                echo "Invalid signature for principal: $principal"
            fi
        done
    done < "$ALLOWED_SIGNERS_FILE"

    echo
    echo "No valid signature found in allowed signers."
    echo "The allowed signers file should contain entries in the format:"
    echo "<principal-list> <optional options> <public-key>"
    exit $VALIDATION_FAILED

else
    usage
fi

