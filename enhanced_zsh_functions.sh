#!/bin/zsh
# Enhanced Steganography Functions for ~/enc directory
# Add these to your ~/.zshrc file

# Enhanced stego function with multi-format support
stegox() {
    if [ $# -lt 3 ]; then
        echo "Usage: stegox <input_file_or_dir> <carrier_image.png> <password> [options]"
        echo "Options:"
        echo "  -v, --verbose     Show detailed progress"
        echo "  -n, --no-compress Disable compression"
        echo "  -o, --output      Custom output filename (default: carrier_hidden.png)"
        echo ""
        echo "Examples:"
        echo "  stegox secret.pdf image.png mypass123"
        echo "  stegox my_folder/ large.png mypass123 -v"
        echo "  stegox data.zip photo.png mypass123 -o stealth.png"
        return 1
    fi
    
    local input_file="$1"
    local carrier_image="$2" 
    local password="$3"
    shift 3
    
    # Parse options
    local verbose=false
    local no_compress=false
    local output_image="${carrier_image%.*}_hidden.png"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                verbose=true
                ;;
            -n|--no-compress)
                no_compress=true
                ;;
            -o|--output)
                shift
                output_image="$1"
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done
    
    # Check if we're in the enc directory
    if [ "$(pwd)" != "$HOME/enc" ]; then
        echo "Error: This command must be run from ~/enc/ directory"
        echo "Please run: cd ~/enc"
        return 1
    fi
    
    # Check if input exists
    if [ ! -e "$input_file" ]; then
        echo "Error: Input '$input_file' not found"
        return 1
    fi
    
    if [ ! -f "$carrier_image" ]; then
        echo "Error: Carrier image '$carrier_image' not found"
        return 1
    fi
    
    # Create temporary files for the process
    local temp_prepared=".temp_prepared_$(date +%s)"
    local temp_encrypted=".temp_encrypted_$(date +%s).enc"
    
    echo "🔐 Processing $input_file..."
    
    # Prepare the file using enhanced steganography
    source venv/bin/activate
    
    # First embed the file without encryption to get prepared file
    local embed_opts=""
    [ "$verbose" = true ] && embed_opts="$embed_opts -v"
    [ "$no_compress" = true ] && embed_opts="$embed_opts --no-compress"
    
    # Create a temporary unencrypted embed to prepare the file
    python stego_enhanced.py embed "$input_file" "$carrier_image" ".temp_test.png" $embed_opts > /tmp/stego_prep.log 2>&1
    
    if [ $? -ne 0 ]; then
        cat /tmp/stego_prep.log
        deactivate
        rm -f .temp_test.png /tmp/stego_prep.log
        return 1
    fi
    
    # Clean up test file
    rm -f .temp_test.png
    
    # Now prepare and encrypt the actual file
    if [ -d "$input_file" ]; then
        # Directory - create archive
        echo "📁 Archiving directory..."
        if [ "$no_compress" = true ]; then
            tar -cf "$temp_prepared" "$input_file"
        else
            tar -czf "$temp_prepared" "$input_file"
        fi
    else
        # Regular file - just copy or compress
        if [ "$no_compress" = true ] || [[ "$input_file" =~ \.(zip|gz|bz2|7z|rar|jpg|jpeg|mp3|mp4)$ ]]; then
            cp "$input_file" "$temp_prepared"
        else
            # Try compression
            gzip -c "$input_file" > "$temp_prepared.gz"
            
            # Check if compression helped
            local orig_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file")
            local comp_size=$(stat -f%z "$temp_prepared.gz" 2>/dev/null || stat -c%s "$temp_prepared.gz")
            
            if [ $comp_size -lt $((orig_size * 8 / 10)) ]; then
                mv "$temp_prepared.gz" "$temp_prepared"
                [ "$verbose" = true ] && echo "✓ Compressed: $orig_size → $comp_size bytes"
            else
                rm "$temp_prepared.gz"
                cp "$input_file" "$temp_prepared"
                [ "$verbose" = true ] && echo "✓ Compression not beneficial, using original"
            fi
        fi
    fi
    
    # Encrypt the prepared file
    echo "🔒 Encrypting..."
    openssl enc -aes-256-cbc -salt -in "$temp_prepared" -out "$temp_encrypted" -pass pass:"$password" -pbkdf2
    
    if [ $? -ne 0 ]; then
        echo "Error: Encryption failed"
        rm -f "$temp_prepared" "$temp_encrypted"
        deactivate
        return 1
    fi
    
    # Embed encrypted file in image
    echo "🖼️  Embedding in image..."
    python image_binary_insert.py "$carrier_image" "$temp_encrypted" "$output_image"
    local embed_result=$?
    
    deactivate
    
    # Clean up
    rm -f "$temp_prepared" "$temp_encrypted" /tmp/stego_prep.log
    
    if [ $embed_result -eq 0 ]; then
        local final_size=$(stat -f%z "$output_image" 2>/dev/null || stat -c%s "$output_image")
        echo "✅ Success! Hidden file: $output_image ($(numfmt --to=iec $final_size 2>/dev/null || echo "$final_size bytes"))"
    else
        echo "❌ Error: Failed to embed data in image"
        return 1
    fi
}

# Enhanced unstego function
unstegox() {
    if [ $# -lt 2 ]; then
        echo "Usage: unstegox <stego_image.png> <password> [output_name]"
        echo ""
        echo "Examples:"
        echo "  unstegox image_hidden.png mypass123"
        echo "  unstegox stealth.png mypass123 recovered_folder"
        return 1
    fi
    
    local stego_image="$1"
    local password="$2"
    local output_name="$3"
    
    # Check if we're in the enc directory
    if [ "$(pwd)" != "$HOME/enc" ]; then
        echo "Error: This command must be run from ~/enc/ directory"
        echo "Please run: cd ~/enc"
        return 1
    fi
    
    # Check if stego image exists
    if [ ! -f "$stego_image" ]; then
        echo "Error: Stego image '$stego_image' not found"
        return 1
    fi
    
    local temp_extracted=".temp_extracted_$(date +%s).enc"
    local temp_decrypted=".temp_decrypted_$(date +%s)"
    
    # Extract encrypted data from image
    echo "🖼️  Extracting from image..."
    source venv/bin/activate
    python image_binary_extract.py "$stego_image" "$temp_extracted"
    local extract_result=$?
    deactivate
    
    if [ $extract_result -ne 0 ]; then
        echo "Error: Failed to extract data from image"
        rm -f "$temp_extracted"
        return 1
    fi
    
    # Decrypt the data
    echo "🔓 Decrypting..."
    openssl enc -d -aes-256-cbc -in "$temp_extracted" -out "$temp_decrypted" -pass pass:"$password" -pbkdf2
    
    if [ $? -ne 0 ]; then
        echo "Error: Decryption failed. Wrong password?"
        rm -f "$temp_extracted" "$temp_decrypted"
        return 1
    fi
    
    # Determine file type and extract accordingly
    local file_type=$(file -b "$temp_decrypted" 2>/dev/null)
    
    echo "📦 Restoring data..."
    
    if [[ "$file_type" =~ "gzip compressed" ]]; then
        # Compressed file
        if [ -n "$output_name" ]; then
            gunzip -c "$temp_decrypted" > "$output_name"
        else
            # Try to determine original name
            gunzip -c "$temp_decrypted" > "recovered_$(date +%s)"
        fi
        echo "✅ Extracted compressed file"
        
    elif [[ "$file_type" =~ "tar archive" ]]; then
        # Tar archive (directory)
        tar -tf "$temp_decrypted" | head -1 | cut -d'/' -f1 > /tmp/dirname.tmp
        local dir_name=$(cat /tmp/dirname.tmp)
        rm /tmp/dirname.tmp
        
        if [ -n "$output_name" ]; then
            mkdir -p "$output_name"
            tar -xf "$temp_decrypted" -C "$output_name" --strip-components=1
            echo "✅ Extracted directory to: $output_name"
        else
            tar -xf "$temp_decrypted"
            echo "✅ Extracted directory: $dir_name"
        fi
        
    else
        # Regular file
        if [ -n "$output_name" ]; then
            cp "$temp_decrypted" "$output_name"
            echo "✅ Extracted file to: $output_name"
        else
            cp "$temp_decrypted" "recovered_$(date +%s)"
            echo "✅ Extracted file to: recovered_$(date +%s)"
        fi
    fi
    
    # Clean up
    rm -f "$temp_extracted" "$temp_decrypted"
}

# Function to check image capacity
stego-capacity() {
    if [ $# -eq 0 ]; then
        echo "Usage: stego-capacity <file_or_size>"
        echo ""
        echo "Examples:"
        echo "  stego-capacity myfile.pdf"
        echo "  stego-capacity 10MB"
        echo "  stego-capacity my_folder/"
        return 1
    fi
    
    if [ "$(pwd)" != "$HOME/enc" ]; then
        echo "Error: This command must be run from ~/enc/ directory"
        echo "Please run: cd ~/enc"
        return 1
    fi
    
    source venv/bin/activate
    python stego_enhanced.py capacity "$1"
    deactivate
}

# Batch steganography function
stego-batch() {
    if [ $# -lt 2 ]; then
        echo "Usage: stego-batch <password> <file1> [file2] [file3] ..."
        echo ""
        echo "This will hide multiple files using appropriately sized carrier images"
        echo "Carrier images must exist as: carrier_small.png, carrier_medium.png, carrier_large.png"
        return 1
    fi
    
    if [ "$(pwd)" != "$HOME/enc" ]; then
        echo "Error: This command must be run from ~/enc/ directory"
        echo "Please run: cd ~/enc"
        return 1
    fi
    
    local password="$1"
    shift
    
    # Check for carrier images
    if [ ! -f "carrier_small.png" ] || [ ! -f "carrier_medium.png" ] || [ ! -f "carrier_large.png" ]; then
        echo "Error: Missing carrier images. Please ensure you have:"
        echo "  - carrier_small.png (for files < 100KB)"
        echo "  - carrier_medium.png (for files < 1MB)"
        echo "  - carrier_large.png (for files >= 1MB)"
        return 1
    fi
    
    local success_count=0
    local total_count=$#
    
    for input_file in "$@"; do
        if [ ! -e "$input_file" ]; then
            echo "⚠️  Skipping: $input_file (not found)"
            continue
        fi
        
        # Determine file size and choose carrier
        local file_size
        if [ -d "$input_file" ]; then
            file_size=$(du -sb "$input_file" 2>/dev/null | cut -f1 || du -sk "$input_file" | cut -f1 | awk '{print $1 * 1024}')
        else
            file_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file")
        fi
        
        local carrier
        if [ $file_size -lt 102400 ]; then  # < 100KB
            carrier="carrier_small.png"
        elif [ $file_size -lt 1048576 ]; then  # < 1MB
            carrier="carrier_medium.png"
        else
            carrier="carrier_large.png"
        fi
        
        local output_name="${input_file//\//_}_hidden.png"
        
        echo "Processing: $input_file → $output_name (using $carrier)"
        
        if stegox "$input_file" "$carrier" "$password" -o "$output_name"; then
            ((success_count++))
        fi
        echo ""
    done
    
    echo "Batch complete: $success_count/$total_count files processed successfully"
}

# Function to securely wipe original files after hiding
stego-secure() {
    if [ $# -lt 3 ]; then
        echo "Usage: stego-secure <input_file> <carrier_image.png> <password>"
        echo ""
        echo "This will hide the file and then securely delete the original"
        echo "⚠️  WARNING: This will permanently delete the original file!"
        return 1
    fi
    
    local input_file="$1"
    local carrier_image="$2"
    local password="$3"
    
    # First create the hidden file
    if stegox "$input_file" "$carrier_image" "$password"; then
        echo ""
        echo "⚠️  WARNING: About to securely delete: $input_file"
        echo -n "Are you sure? (yes/no): "
        read confirmation
        
        if [ "$confirmation" = "yes" ]; then
            if [ -d "$input_file" ]; then
                echo "🗑️  Securely removing directory..."
                find "$input_file" -type f -exec shred -vuz {} \;
                rm -rf "$input_file"
            else
                echo "🗑️  Securely wiping file..."
                shred -vuz "$input_file"
            fi
            echo "✅ Original securely deleted"
        else
            echo "ℹ️  Deletion cancelled"
        fi
    else
        echo "❌ Failed to hide file, original not deleted"
        return 1
    fi
}