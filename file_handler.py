#!/usr/bin/env python3
"""
Enhanced file handler for multi-format support
Supports: text, images, PDFs, documents, archives, and more
"""
import os
import mimetypes
import tempfile
import shutil
import tarfile
import gzip
import json
from pathlib import Path
from typing import Tuple, Dict, Any

class FileHandler:
    """Handle various file formats for encryption/steganography"""
    
    # Define supported formats and their handling
    SUPPORTED_FORMATS = {
        'text': ['.txt', '.md', '.log', '.csv', '.json', '.xml', '.html', '.css', '.js', '.py', '.sh', '.c', '.cpp', '.java'],
        'document': ['.pdf', '.doc', '.docx', '.odt', '.rtf', '.tex'],
        'image': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.svg', '.webp'],
        'archive': ['.zip', '.tar', '.gz', '.bz2', '.7z', '.rar'],
        'media': ['.mp3', '.mp4', '.avi', '.mkv', '.wav', '.flac'],
        'binary': ['.exe', '.bin', '.dat', '.db', '.sqlite']
    }
    
    def __init__(self):
        mimetypes.init()
    
    def identify_file_type(self, file_path: str) -> Tuple[str, str]:
        """Identify file type and extension"""
        ext = Path(file_path).suffix.lower()
        mime_type = mimetypes.guess_type(file_path)[0] or 'application/octet-stream'
        
        # Determine category
        category = 'binary'  # default
        for cat, extensions in self.SUPPORTED_FORMATS.items():
            if ext in extensions:
                category = cat
                break
        
        return category, mime_type
    
    def prepare_file(self, file_path: str, compress: bool = True) -> Tuple[str, Dict[str, Any]]:
        """
        Prepare file for encryption. Returns path to prepared file and metadata.
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        file_info = {
            'original_name': os.path.basename(file_path),
            'original_path': os.path.abspath(file_path),
            'size': os.path.getsize(file_path),
            'type': self.identify_file_type(file_path)[0],
            'mime': self.identify_file_type(file_path)[1],
            'compressed': False
        }
        
        # For small files or already compressed formats, skip compression
        already_compressed = file_path.lower().endswith(('.zip', '.gz', '.bz2', '.7z', '.rar', '.jpg', '.jpeg', '.mp3', '.mp4'))
        
        if compress and not already_compressed and file_info['size'] > 1024:  # Only compress files > 1KB
            # Create temporary compressed file
            temp_fd, temp_path = tempfile.mkstemp(suffix='.gz')
            
            try:
                with open(file_path, 'rb') as f_in:
                    with gzip.open(temp_path, 'wb', compresslevel=9) as f_out:
                        shutil.copyfileobj(f_in, f_out)
                
                compressed_size = os.path.getsize(temp_path)
                
                # Only use compressed version if it's significantly smaller (>20% reduction)
                if compressed_size < file_info['size'] * 0.8:
                    file_info['compressed'] = True
                    file_info['original_size'] = file_info['size']
                    file_info['size'] = compressed_size
                    file_info['compression_ratio'] = compressed_size / file_info['original_size']
                    return temp_path, file_info
                else:
                    os.close(temp_fd)
                    os.unlink(temp_path)
            except Exception:
                os.close(temp_fd)
                os.unlink(temp_path)
                raise
        
        return file_path, file_info
    
    def prepare_directory(self, dir_path: str, compress: bool = True) -> Tuple[str, Dict[str, Any]]:
        """
        Prepare directory for encryption by creating a tar archive.
        """
        if not os.path.isdir(dir_path):
            raise NotADirectoryError(f"Not a directory: {dir_path}")
        
        # Create temporary tar file
        temp_fd, temp_path = tempfile.mkstemp(suffix='.tar.gz' if compress else '.tar')
        os.close(temp_fd)
        
        try:
            # Create tar archive
            mode = 'w:gz' if compress else 'w'
            with tarfile.open(temp_path, mode) as tar:
                tar.add(dir_path, arcname=os.path.basename(dir_path))
            
            dir_info = {
                'original_name': os.path.basename(dir_path),
                'original_path': os.path.abspath(dir_path),
                'size': os.path.getsize(temp_path),
                'type': 'directory',
                'mime': 'application/x-tar',
                'compressed': compress,
                'file_count': sum(len(files) for _, _, files in os.walk(dir_path))
            }
            
            return temp_path, dir_info
        except Exception:
            os.unlink(temp_path)
            raise
    
    def save_metadata(self, metadata: Dict[str, Any], output_path: str):
        """Save metadata to a JSON file"""
        meta_path = output_path + '.meta'
        with open(meta_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        return meta_path
    
    def load_metadata(self, meta_path: str) -> Dict[str, Any]:
        """Load metadata from JSON file"""
        with open(meta_path, 'r') as f:
            return json.load(f)
    
    def restore_file(self, encrypted_path: str, metadata: Dict[str, Any], output_path: str = None):
        """
        Restore file to its original format using metadata.
        """
        if output_path is None:
            output_path = metadata['original_name']
        
        # Handle compressed files
        if metadata.get('compressed', False):
            # Decompress first
            temp_fd, temp_path = tempfile.mkstemp()
            os.close(temp_fd)
            
            try:
                with gzip.open(encrypted_path, 'rb') as f_in:
                    with open(temp_path, 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)
                
                shutil.move(temp_path, output_path)
            finally:
                if os.path.exists(temp_path):
                    os.unlink(temp_path)
        else:
            shutil.copy2(encrypted_path, output_path)
        
        return output_path
    
    def restore_directory(self, tar_path: str, metadata: Dict[str, Any], output_dir: str = None):
        """
        Restore directory from tar archive.
        """
        if output_dir is None:
            output_dir = '.'
        
        # Extract tar archive
        mode = 'r:gz' if metadata.get('compressed', False) else 'r'
        with tarfile.open(tar_path, mode) as tar:
            tar.extractall(path=output_dir)
        
        return os.path.join(output_dir, metadata['original_name'])


def calculate_required_capacity(file_size: int) -> Dict[str, Any]:
    """
    Calculate required image dimensions for given file size.
    """
    # Add overhead for size header (4 bytes) and potential metadata
    total_bytes = file_size + 4 + 1024  # 1KB for metadata
    total_bits = total_bytes * 8
    
    # 3 bits per pixel (RGB)
    required_pixels = (total_bits + 2) // 3  # Round up
    
    # Calculate dimensions
    suggestions = []
    
    # Common aspect ratios
    aspect_ratios = [
        (1, 1),    # Square
        (4, 3),    # Classic
        (16, 9),   # Widescreen
        (3, 2),    # Photo
    ]
    
    for ratio_w, ratio_h in aspect_ratios:
        # Calculate width based on aspect ratio
        width = int((required_pixels * ratio_w / ratio_h) ** 0.5)
        height = int(width * ratio_h / ratio_w)
        
        # Ensure we have enough pixels
        while width * height < required_pixels:
            width += 1
            height = int(width * ratio_h / ratio_w)
        
        suggestions.append({
            'width': width,
            'height': height,
            'pixels': width * height,
            'aspect_ratio': f"{ratio_w}:{ratio_h}",
            'capacity_bytes': (width * height * 3) // 8
        })
    
    return {
        'file_size': file_size,
        'required_pixels': required_pixels,
        'suggestions': sorted(suggestions, key=lambda x: x['pixels'])
    }


if __name__ == "__main__":
    # Test the file handler
    handler = FileHandler()
    
    # Test file type identification
    test_files = ['test.txt', 'image.png', 'document.pdf', 'archive.zip']
    print("File Type Identification:")
    for filename in test_files:
        print(f"  {filename}: {handler.identify_file_type(filename)}")
    
    # Test capacity calculation
    print("\nCapacity Calculation for 1MB file:")
    capacity_info = calculate_required_capacity(1024 * 1024)  # 1MB
    for suggestion in capacity_info['suggestions']:
        print(f"  {suggestion['aspect_ratio']}: {suggestion['width']}x{suggestion['height']} " +
              f"({suggestion['capacity_bytes'] / 1024 / 1024:.2f} MB capacity)")