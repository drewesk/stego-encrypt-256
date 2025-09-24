#!/usr/bin/env python3
import argparse
from PIL import Image

def main():
    parser = argparse.ArgumentParser(description='Extract hidden data from image')
    parser.add_argument("stego_image", help="Image with hidden data")
    parser.add_argument("output_file", help="File to save extracted data")
    args = parser.parse_args()

    # Open the stego image
    img = Image.open(args.stego_image)
    img = img.convert('RGB')
    
    pixels = list(img.getdata())
    
    # Extract binary string from LSBs
    binary_string = ''
    for pixel in pixels:
        for value in pixel:  # RGB values
            binary_string += str(value & 1)
    
    # First, extract the file size (first 32 bits = 4 bytes)
    size_bits = binary_string[:32]
    file_size = int(size_bits, 2)
    
    # Calculate how many bits we need to extract for the actual data
    data_bits_needed = file_size * 8  # Convert bytes to bits
    total_bits_needed = 32 + data_bits_needed  # Size header + data
    
    # Extract only the required bits
    data_bits = binary_string[32:total_bits_needed]
    
    # Convert binary string to bytes
    binary_data = bytearray()
    for i in range(0, len(data_bits), 8):
        byte = data_bits[i:i+8]
        if len(byte) == 8:
            binary_data.append(int(byte, 2))
    
    # Save extracted data
    with open(args.output_file, 'wb') as f:
        f.write(binary_data)
    
    print(f"Data extracted to {args.output_file}")
    print(f"Extracted {file_size} bytes")

if __name__ == "__main__":
    main()