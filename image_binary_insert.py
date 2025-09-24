#!/usr/bin/env python3
import argparse
import os
from PIL import Image

def main():
    parser = argparse.ArgumentParser(description='Embed binary data in image using LSB steganography')
    parser.add_argument("carrier_image", help="Input PNG image file")
    parser.add_argument("binary_file", help="Binary file to embed")
    parser.add_argument("output_image", help="Output image file with hidden data")
    args = parser.parse_args()

    # Open the image
    img = Image.open(args.carrier_image)
    img = img.convert('RGB')
    width, height = img.size

    # Read binary file
    with open(args.binary_file, 'rb') as f:
        binary_data = f.read()

    # Add size information at the beginning (4 bytes for file size)
    file_size = len(binary_data)
    size_bytes = file_size.to_bytes(4, byteorder='big')
    binary_data = size_bytes + binary_data

    # Convert to binary string
    binary_string = ''.join(format(byte, '08b') for byte in binary_data)
    
    # Check if image can hold the data
    max_capacity = width * height * 3  # 3 bits per pixel (RGB)
    if len(binary_string) > max_capacity:
        raise ValueError(f"Image too small. Can hold {max_capacity} bits, need {len(binary_string)} bits")

    # Embed data
    pixels = list(img.getdata())
    data_index = 0
    
    for i in range(len(pixels)):
        if data_index >= len(binary_string):
            break
            
        pixel = list(pixels[i])
        
        # Modify LSB of each color channel
        for j in range(3):  # RGB channels
            if data_index < len(binary_string):
                if binary_string[data_index] == '1':
                    pixel[j] = pixel[j] | 1  # Set LSB to 1
                else:
                    pixel[j] = pixel[j] & ~1  # Set LSB to 0
                data_index += 1
        
        pixels[i] = tuple(pixel)
    
    # Create new image with embedded data
    stego_img = Image.new('RGB', (width, height))
    stego_img.putdata(pixels)
    stego_img.save(args.output_image, 'PNG')
    
    print(f"Data embedded successfully in {args.output_image}")
    print(f"Embedded {file_size} bytes")

if __name__ == "__main__":
    main()