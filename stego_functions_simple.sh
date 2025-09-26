#!/bin/zsh
# Simplified Enhanced Steganography Functions for ~/enc directory

# Enhanced stego function with multi-format support
stegox() {
    if [ $# -lt 3 ]; then
        echo "Usage: stegox <input_file_or_dir> <carrier_image.png> <password>"
        echo ""
        echo "Examples:"
        echo "  stegox secret.pdf image.png mypass123"
        echo "  stegox my_folder/ large.png mypass123"
        echo "  stegox data.zip photo.png mypass123"
        return 1
    fi
    
    local input_file="$1"
    local carrier_image="$2" 
    local password="$3"
    local output_image="${carrier_image%.*}_hidden.png"
    
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
    
    # Create temporary files
    local temp_prepared=".temp_prepared_$(date +%s)"
    local temp_encrypted=".temp_encrypted_$(date +%s).enc"
    
    echo "🔐 Processing $input_file..."
    
    # Prepare the file (compress if beneficial)
    if [ -d "$input_file" ]; then
        # Directory - create tar archive
        echo "📁 Archiving directory..."
        tar -czf "$temp_prepared" "$input_file"
    else
        # Regular file - check if compression helps
        local file_ext="${input_file##*.}"
        local is_compressed=false
        
        # Skip compression for already compressed formats
        for ext in zip gz bz2 7z rar jpg jpeg png mp3 mp4 pdf; do
            if [ "$file_ext" = "$ext" ]; then
                is_compressed=true
                break
            fi
        done
        
        if [ "$is_compressed" = true ]; then
            cp "$input_file" "$temp_prepared"
        else
            # Try compression for other files
            gzip -c "$input_file" > "${temp_prepared}.gz"
            local orig_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file")
            local comp_size=$(stat -f%z "${temp_prepared}.gz" 2>/dev/null || stat -c%s "${temp_prepared}.gz")
            
            if [ $comp_size -lt $((orig_size * 8 / 10)) ]; then
                mv "${temp_prepared}.gz" "$temp_prepared"
                echo "📦 Compressed: $orig_size → $comp_size bytes"
            else
                rm "${temp_prepared}.gz"
                cp "$input_file" "$temp_prepared"
            fi
        fi
    fi
    
    # Encrypt the prepared file
    echo "🔒 Encrypting..."
    openssl enc -aes-256-cbc -salt -in "$temp_prepared" -out "$temp_encrypted" -pass pass:"$password" -pbkdf2
    
    if [ $? -ne 0 ]; then
        echo "Error: Encryption failed"
        rm -f "$temp_prepared" "$temp_encrypted"
        return 1
    fi
    
    # Embed encrypted file in image
    echo "🖼️  Embedding in image..."
    source venv/bin/activate
    python image_binary_insert.py "$carrier_image" "$temp_encrypted" "$output_image"
    local embed_result=$?
    deactivate
    
    # Clean up
    rm -f "$temp_prepared" "$temp_encrypted"
    
    if [ $embed_result -eq 0 ]; then
        echo "✅ Success! Hidden file: $output_image"
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
    
    # Restore the file
    echo "📦 Restoring data..."
    
    # If output name specified, use it; otherwise use default
    if [ -n "$output_name" ]; then
        cp "$temp_decrypted" "$output_name"
        echo "✅ Successfully extracted to: $output_name"
    else
        # Try to determine file type from content
        local file_type=$(file -b "$temp_decrypted" 2>/dev/null)
        local output_file="recovered_$(date +%s)"
        
        # Add appropriate extension based on file type
        if [[ "$file_type" =~ "text" ]]; then
            output_file="${output_file}.txt"
        elif [[ "$file_type" =~ "PDF" ]]; then
            output_file="${output_file}.pdf"
        elif [[ "$file_type" =~ "gzip" ]]; then
            output_file="${output_file}.gz"
        fi
        
        cp "$temp_decrypted" "$output_file"
        echo "✅ Successfully extracted to: $output_file"
    fi
    
    # Clean up
    rm -f "$temp_extracted" "$temp_decrypted"
}

# Capacity check function  
stego-capacity() {
    if [ $# -eq 0 ]; then
        echo "Usage: stego-capacity <file_or_size>"
        echo "Examples:"
        echo "  stego-capacity myfile.pdf"
        echo "  stego-capacity 10MB"
        return 1
    fi
    
    if [ "$(pwd)" != "$HOME/enc" ]; then
        echo "Error: This command must be run from ~/enc/ directory"
        return 1
    fi
    
    source venv/bin/activate
    python stego_enhanced.py capacity "$1"
    deactivate
}

# Status check
stego-info() {
    echo "🔐 Steganography Environment Status"
    echo "=================================="
    echo "Directory: ~/enc"
    echo -n "Python venv: "
    if [ -d "$HOME/enc/venv" ]; then
        echo "✅ Installed"
    else
        echo "❌ Not found"
    fi
    
    echo -n "Enhanced tools: "
    if [ -f "$HOME/enc/stego_enhanced.py" ]; then
        echo "✅ Available"  
    else
        echo "❌ Not found"
    fi
    
    if [ "$(pwd)" = "$HOME/enc" ]; then
        echo ""
        echo "📊 Workspace Statistics:"
        echo "  Hidden images: $(find . -name "*_hidden.png" 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Carrier images: $(find . -name "*.png" ! -name "*_hidden.png" 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Total files: $(find . -type f ! -path "./venv/*" 2>/dev/null | wc -l | tr -d ' ')"
    fi
}

# Quick navigation alias
alias enc='cd ~/enc && stego-info'