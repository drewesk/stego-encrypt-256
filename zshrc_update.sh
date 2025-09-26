#!/bin/bash
# This script will append the enhanced steganography functions to your .zshrc

cat << 'EOF' >> ~/.zshrc

# ===== Enhanced Steganography Functions =====
# Multi-format encryption & steganography tools for ~/enc directory

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
    local temp_encrypted=".temp_encrypted_$(date +%s).dat"
    
    echo "🔐 Processing $input_file..."
    
    # Use enhanced Python tool for preparation and embedding
    source venv/bin/activate
    
    # Create metadata-aware temporary file
    local temp_meta=".temp_meta_$(date +%s).json"
    local embed_opts=""
    [ "$verbose" = true ] && embed_opts="$embed_opts -v"
    [ "$no_compress" = true ] && embed_opts="$embed_opts --no-compress"
    
    # First use enhanced tool to prepare and embed (without encryption)
    python stego_enhanced.py embed "$input_file" "$carrier_image" ".temp_embed.png" $embed_opts > /tmp/embed.log 2>&1
    
    if [ $? -ne 0 ]; then
        cat /tmp/embed.log
        deactivate
        rm -f .temp_embed.png /tmp/embed.log "$temp_meta"
        return 1
    fi
    
    # Extract to get the prepared data
    python stego_enhanced.py extract ".temp_embed.png" ".temp_prepared" > /dev/null 2>&1
    
    # Encrypt the prepared file
    echo "🔒 Encrypting..."
    openssl enc -aes-256-cbc -salt -in ".temp_prepared" -out "$temp_encrypted" -pass pass:"$password" -pbkdf2
    
    if [ $? -ne 0 ]; then
        echo "Error: Encryption failed"
        rm -f .temp_embed.png .temp_prepared "$temp_encrypted" "$temp_meta"
        deactivate
        return 1
    fi
    
    # Embed encrypted file in image
    echo "🖼️  Embedding in image..."
    python image_binary_insert.py "$carrier_image" "$temp_encrypted" "$output_image"
    local embed_result=$?
    
    deactivate
    
    # Clean up
    rm -f .temp_embed.png .temp_prepared "$temp_encrypted" "$temp_meta" /tmp/embed.log
    
    if [ $embed_result -eq 0 ]; then
        local final_size=$(stat -f%z "$output_image" 2>/dev/null || stat -c%s "$output_image")
        echo "✅ Success! Hidden file: $output_image"
        [ "$verbose" = true ] && echo "   Size: $(printf "%'d" $final_size) bytes"
    else
        echo "❌ Error: Failed to embed data in image"
        return 1
    fi
}

# Enhanced unstego function with automatic format detection
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
    
    # Extract and decrypt
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
    
    echo "🔓 Decrypting..."
    openssl enc -d -aes-256-cbc -in "$temp_extracted" -out "$temp_decrypted" -pass pass:"$password" -pbkdf2
    
    if [ $? -ne 0 ]; then
        echo "Error: Decryption failed. Wrong password?"
        rm -f "$temp_extracted" "$temp_decrypted"
        return 1
    fi
    
    # Use enhanced tool to restore with metadata
    echo "📦 Restoring data..."
    source venv/bin/activate
    
    # Create temporary image with decrypted data to leverage metadata handling
    python image_binary_insert.py "$stego_image" "$temp_decrypted" ".temp_restore.png" > /dev/null 2>&1
    python stego_enhanced.py extract ".temp_restore.png" ${output_name:+"$output_name"} -v
    
    deactivate
    
    # Clean up
    rm -f "$temp_extracted" "$temp_decrypted" .temp_restore.png
}

# Keep original simple functions for backward compatibility
# (Original stego and unstego functions remain here)

# New utility functions
stego-capacity() {
    if [ $# -eq 0 ]; then
        echo "Usage: stego-capacity <file_or_size>"
        echo "Examples:"
        echo "  stego-capacity myfile.pdf"
        echo "  stego-capacity 10MB"
        echo "  stego-capacity my_folder/"
        return 1
    fi
    
    if [ "$(pwd)" != "$HOME/enc" ]; then
        cd ~/enc || return 1
    fi
    
    source venv/bin/activate
    python stego_enhanced.py capacity "$1"
    deactivate
}

# Quick steganography status check
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

# Alias for quick access to encryption directory
alias enc='cd ~/enc && stego-info'
EOF

echo "✅ Enhanced steganography functions have been added to ~/.zshrc"
echo ""
echo "To activate the new functions, run:"
echo "  source ~/.zshrc"
echo ""
echo "New commands available:"
echo "  • stegox      - Hide any file/directory with encryption"
echo "  • unstegox    - Extract and decrypt hidden files"  
echo "  • stego-capacity - Check required image size"
echo "  • stego-info  - Show environment status"
echo "  • enc         - Quick jump to encryption directory"