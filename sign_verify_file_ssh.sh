#!/bin/bash
#
# SSH Signature Signing and Verification Script
# - Sign a file using an SSH private key.
# - Verify a signed file using an allowed signers file.
#
# Generates a signature file named `<file>.sig` in the same directory.
#
# Author: Alan O'Cais
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Usage message
usage() {
    cat <<EOF
Usage:
  $0 sign <private_key> <file>
  $0 verify <allowed_signers_file> <file> [signature_file]

Options:
  sign:
    - <private_key>: Path to SSH private key (use KEY_PASSPHRASE env for passphrase)
    - <file>: File to sign

  verify:
    - <allowed_signers_file>: Path to the allowed signers file
    - <file>: File to verify
    - [signature_file]: Optional, defaults to '<file>.sig'

Example allowed signers format:
  identity_1 <public-key>
EOF
    exit 9
}

# Error codes
FILE_PROBLEM=1
CONVERSION_FAILURE=2
VALIDATION_FAILED=3

# Ensure minimum arguments
[ "$#" -lt 3 ] && usage

MODE="$1"
FILE_TO_SIGN="$3"

# Ensure the target file exists
if [ ! -f "$FILE_TO_SIGN" ]; then
    echo "Error: File '$FILE_TO_SIGN' not found."
    exit $FILE_PROBLEM
fi

# Use a very conservatuve umask throughout this script since we are dealing with sensitive things
umask 077 || { echo "Error: Failed to set 0177 umask."; exit $FILE_PROBLEM; }

# Create a restricted temporary directory and ensure cleanup on exit
TEMP_DIR=$(mktemp -d) || { echo "Error: Failed to create temporary directory."; exit $FILE_PROBLEM; }
trap 'rm -rf "$TEMP_DIR"' EXIT

# Converts the SSH private key to OpenSSH format and generates a public key
convert_private_key() {
    local input_key="$1"
    local output_key="$2"

    echo "Converting SSH key to OpenSSH format..."
    cp "$input_key" "$output_key" || { echo "Error: Failed to copy $input_key to $output_key"; exit $FILE_PROBLEM; }

    # This saves the key in the default OpenSSH format (which is required for signing)
    ssh-keygen -p -f "$output_key" -P "${KEY_PASSPHRASE:-}" -N "${KEY_PASSPHRASE:-}" || {
        echo "Error: Failed to convert key to OpenSSH format."
        exit $CONVERSION_FAILURE
    }

    # Extract the public key from the private key
    ssh-keygen -y -f "$input_key" -P "${KEY_PASSPHRASE:-}" > "${output_key}.pub" || {
        echo "Error: Failed to extract public key."
        exit $CONVERSION_FAILURE
    }
}

# Sign mode
if [ "$MODE" == "sign" ]; then
    PRIVATE_KEY="$2"
    TEMP_KEY="$TEMP_DIR/converted_key"
    SIG_FILE="${FILE_TO_SIGN}.sig"

    # Check for key and existing signature
    [ ! -f "$PRIVATE_KEY" ] && { echo "Error: Private key not found."; exit $FILE_PROBLEM; }
    [ -f "$SIG_FILE" ] && { echo "Error: Signature already exists. Remove to re-sign."; exit $FILE_PROBLEM; }

    convert_private_key "$PRIVATE_KEY" "$TEMP_KEY"

    echo "Signing the file..."
    ssh-keygen -Y sign -f "$TEMP_KEY" -P "${KEY_PASSPHRASE:-}" -n file "$FILE_TO_SIGN"

    [ ! -f "$SIG_FILE" ] && { echo "Error: Signing failed."; exit $FILE_PROBLEM; }
    echo "Signature created: $SIG_FILE"

    cat <<EOF

For verification, your allowed signers file could contain:
identity_1 $(cat "${TEMP_KEY}.pub")
EOF

    echo "Validating the signature..."
    ssh-keygen -Y check-novalidate -n file -f "${TEMP_KEY}.pub" -s "$SIG_FILE" < "$FILE_TO_SIGN" || {
        echo "Error: Signature validation failed."
        exit $VALIDATION_FAILED
    }

# Verify mode
elif [ "$MODE" == "verify" ]; then
    ALLOWED_SIGNERS_FILE="$2"
    SIG_FILE="${4:-${FILE_TO_SIGN}.sig}"

    # Ensure required files exist
    for file in "$ALLOWED_SIGNERS_FILE" "$SIG_FILE"; do
        [ ! -f "$file" ] && { echo "Error: File '$file' not found."; exit $FILE_PROBLEM; }
    done

    echo "Verifying the signature against allowed signers..."

    # Iterate through each principal in the allowed signers file
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Extract and process each principal
        principals=$(echo "$line" | cut -d' ' -f1)
        IFS=',' read -ra principal_list <<< "$principals"

        for principal in "${principal_list[@]}"; do
            echo "Checking principal: $principal"
            if ssh-keygen -Y verify -f "$ALLOWED_SIGNERS_FILE" -n file -I "$principal" -s "$SIG_FILE" < "$FILE_TO_SIGN"; then
                echo "Signature is valid for principal: $principal"
                exit 0
            fi
        done
    done < "$ALLOWED_SIGNERS_FILE"

    echo "Error: No valid signature found."
    exit $VALIDATION_FAILED

else
    usage
fi
