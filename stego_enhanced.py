#!/usr/bin/env python3
"""
Enhanced Steganography Tool
Supports multiple file formats, compression, and metadata preservation
"""
import argparse
import os
import sys
import json
from PIL import Image
from file_handler import FileHandler, calculate_required_capacity

class EnhancedSteganography:
    """Enhanced steganography with multi-format support"""
    
    def __init__(self):
        self.file_handler = FileHandler()
    
    def embed_data(self, input_file, carrier_image, output_image, compress=True, verbose=False):
        """
        Embed any file type into an image with metadata preservation
        """
        if verbose:
            print(f"Processing input file: {input_file}")
        
        # Prepare the file (handles any format, compression, etc.)
        if os.path.isdir(input_file):
            prepared_file, metadata = self.file_handler.prepare_directory(input_file, compress)
            if verbose:
                print(f"Archiving directory: {metadata['file_count']} files")
        else:
            prepared_file, metadata = self.file_handler.prepare_file(input_file, compress)
        
        if verbose:
            print(f"File type: {metadata['type']}")
            print(f"Original size: {metadata.get('original_size', metadata['size'])} bytes")
            if metadata['compressed']:
                print(f"Compressed size: {metadata['size']} bytes")
                if 'compression_ratio' in metadata:
                    print(f"Compression ratio: {metadata['compression_ratio']:.2%}")
        
        # Read the prepared file
        with open(prepared_file, 'rb') as f:
            file_data = f.read()
        
        # Convert metadata to JSON and encode
        metadata_json = json.dumps(metadata).encode('utf-8')
        metadata_size = len(metadata_json)
        
        # Combine metadata size (4 bytes), metadata, and file data
        combined_data = (
            metadata_size.to_bytes(4, byteorder='big') +
            metadata_json +
            file_data
        )
        
        # Check capacity
        total_size = len(combined_data)
        capacity_info = calculate_required_capacity(total_size)
        
        # Open carrier image
        img = Image.open(carrier_image)
        img = img.convert('RGB')
        width, height = img.size
        
        max_capacity = (width * height * 3) // 8  # bytes
        if total_size > max_capacity:
            print(f"Error: Image too small!")
            print(f"Image capacity: {max_capacity:,} bytes")
            print(f"Required: {total_size:,} bytes")
            print(f"\nSuggested image dimensions:")
            for suggestion in capacity_info['suggestions'][:3]:
                print(f"  - {suggestion['aspect_ratio']}: "
                      f"{suggestion['width']}x{suggestion['height']} pixels")
            
            # Clean up
            if prepared_file != input_file:
                os.unlink(prepared_file)
            return False
        
        if verbose:
            print(f"Carrier image: {width}x{height} pixels")
            print(f"Capacity: {max_capacity:,} bytes")
            print(f"Usage: {(total_size/max_capacity)*100:.1f}%")
        
        # Convert to binary string
        binary_string = ''.join(format(byte, '08b') for byte in combined_data)
        
        # Embed data using LSB
        pixels = list(img.getdata())
        data_index = 0
        
        for i in range(len(pixels)):
            if data_index >= len(binary_string):
                break
            
            pixel = list(pixels[i])
            
            for j in range(3):  # RGB channels
                if data_index < len(binary_string):
                    if binary_string[data_index] == '1':
                        pixel[j] = pixel[j] | 1
                    else:
                        pixel[j] = pixel[j] & ~1
                    data_index += 1
            
            pixels[i] = tuple(pixel)
        
        # Create output image
        stego_img = Image.new('RGB', (width, height))
        stego_img.putdata(pixels)
        stego_img.save(output_image, 'PNG')
        
        if verbose:
            print(f"\n✅ Successfully embedded {total_size:,} bytes in {output_image}")
        
        # Clean up temporary file
        if prepared_file != input_file:
            os.unlink(prepared_file)
        
        return True
    
    def extract_data(self, stego_image, output_path=None, verbose=False):
        """
        Extract and restore file from stego image
        """
        if verbose:
            print(f"Extracting from: {stego_image}")
        
        # Open stego image
        img = Image.open(stego_image)
        img = img.convert('RGB')
        pixels = list(img.getdata())
        
        # Extract binary string from LSBs
        binary_string = ''
        for pixel in pixels:
            for value in pixel:
                binary_string += str(value & 1)
        
        # Extract metadata size (first 32 bits)
        metadata_size = int(binary_string[:32], 2)
        
        if verbose:
            print(f"Metadata size: {metadata_size} bytes")
        
        # Extract metadata
        metadata_start = 32
        metadata_end = metadata_start + (metadata_size * 8)
        metadata_bits = binary_string[metadata_start:metadata_end]
        
        metadata_bytes = bytearray()
        for i in range(0, len(metadata_bits), 8):
            byte = metadata_bits[i:i+8]
            if len(byte) == 8:
                metadata_bytes.append(int(byte, 2))
        
        metadata = json.loads(metadata_bytes.decode('utf-8'))
        
        if verbose:
            print(f"Original file: {metadata['original_name']}")
            print(f"Type: {metadata['type']}")
            print(f"Compressed: {metadata['compressed']}")
        
        # Extract file data
        file_start = metadata_end
        file_size = metadata['size']
        file_end = file_start + (file_size * 8)
        file_bits = binary_string[file_start:file_end]
        
        file_bytes = bytearray()
        for i in range(0, len(file_bits), 8):
            byte = file_bits[i:i+8]
            if len(byte) == 8:
                file_bytes.append(int(byte, 2))
        
        # Save extracted data to temporary file
        import tempfile
        temp_fd, temp_path = tempfile.mkstemp()
        os.close(temp_fd)
        
        with open(temp_path, 'wb') as f:
            f.write(file_bytes)
        
        # Determine output path
        if output_path is None:
            output_path = metadata['original_name']
        
        # Restore the file based on its type
        if metadata['type'] == 'directory':
            result = self.file_handler.restore_directory(temp_path, metadata, 
                                                       os.path.dirname(output_path) or '.')
        else:
            result = self.file_handler.restore_file(temp_path, metadata, output_path)
        
        # Clean up
        os.unlink(temp_path)
        
        if verbose:
            print(f"\n✅ Successfully extracted to: {result}")
        
        return result


def main():
    parser = argparse.ArgumentParser(
        description='Enhanced steganography tool with multi-format support',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Embed a text file
  %(prog)s embed secret.txt carrier.png output.png
  
  # Embed a directory
  %(prog)s embed my_folder/ carrier.png output.png
  
  # Embed without compression
  %(prog)s embed large.pdf carrier.png output.png --no-compress
  
  # Extract with custom output name
  %(prog)s extract output.png recovered_file.pdf
  
  # Check image capacity
  %(prog)s capacity my_file.zip
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Embed command
    embed_parser = subparsers.add_parser('embed', help='Embed file in image')
    embed_parser.add_argument('input', help='Input file or directory to hide')
    embed_parser.add_argument('carrier', help='Carrier PNG image')
    embed_parser.add_argument('output', help='Output PNG image')
    embed_parser.add_argument('--no-compress', action='store_true', 
                            help='Disable compression')
    embed_parser.add_argument('-v', '--verbose', action='store_true',
                            help='Verbose output')
    
    # Extract command
    extract_parser = subparsers.add_parser('extract', help='Extract file from image')
    extract_parser.add_argument('image', help='Stego image containing hidden data')
    extract_parser.add_argument('output', nargs='?', help='Output file path (optional)')
    extract_parser.add_argument('-v', '--verbose', action='store_true',
                              help='Verbose output')
    
    # Capacity command
    capacity_parser = subparsers.add_parser('capacity', help='Calculate required image size')
    capacity_parser.add_argument('file', help='File to check capacity for')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    stego = EnhancedSteganography()
    
    if args.command == 'embed':
        success = stego.embed_data(
            args.input, 
            args.carrier, 
            args.output,
            compress=not args.no_compress,
            verbose=args.verbose
        )
        sys.exit(0 if success else 1)
    
    elif args.command == 'extract':
        stego.extract_data(args.image, args.output, verbose=args.verbose)
    
    elif args.command == 'capacity':
        if os.path.exists(args.file):
            size = os.path.getsize(args.file)
        else:
            # Parse size string (e.g., "1MB", "500KB")
            size_str = args.file.upper()
            if size_str.endswith('KB'):
                size = int(float(size_str[:-2]) * 1024)
            elif size_str.endswith('MB'):
                size = int(float(size_str[:-2]) * 1024 * 1024)
            elif size_str.endswith('GB'):
                size = int(float(size_str[:-2]) * 1024 * 1024 * 1024)
            else:
                size = int(size_str)
        
        info = calculate_required_capacity(size)
        print(f"File size: {size:,} bytes ({size/1024/1024:.2f} MB)")
        print(f"Required pixels: {info['required_pixels']:,}")
        print("\nRecommended image dimensions:")
        for suggestion in info['suggestions']:
            print(f"  {suggestion['aspect_ratio']:>5}: "
                  f"{suggestion['width']:>5} x {suggestion['height']:<5} "
                  f"(capacity: {suggestion['capacity_bytes']/1024/1024:.2f} MB)")


if __name__ == "__main__":
    main()