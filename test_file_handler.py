#!/usr/bin/env python3
"""
Test script for file_handler.py
Tests various file operations on macOS
"""
import os
import sys
import tempfile
import shutil
from pathlib import Path
from file_handler import FileHandler, calculate_required_capacity

def print_test(name, passed, details=""):
    """Print test result"""
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"{status}: {name}")
    if details:
        print(f"       {details}")

def test_file_operations():
    """Test file preparation and restoration"""
    handler = FileHandler()
    test_results = []
    
    # Create test directory
    test_dir = Path("test_temp")
    test_dir.mkdir(exist_ok=True)
    
    try:
        # Test 1: Text file compression
        print("\n1. Testing text file compression...")
        test_file = test_dir / "test_document.txt"
        test_content = "This is a test document.\n" * 100  # Make it compressible
        test_file.write_text(test_content)
        
        prepared_path, metadata = handler.prepare_file(str(test_file), compress=True)
        
        test_results.append(("Text file compression", 
                           metadata['compressed'] == True,
                           f"Original: {metadata.get('original_size', 0)} bytes, "
                           f"Compressed: {metadata['size']} bytes"))
        
        # Clean up temp file if created
        if prepared_path != str(test_file):
            os.unlink(prepared_path)
        
        # Test 2: Binary file (should not compress well)
        print("\n2. Testing binary file (random data)...")
        binary_file = test_dir / "random.bin"
        with open(binary_file, 'wb') as f:
            f.write(os.urandom(1024))  # 1KB of random data
        
        prepared_path, metadata = handler.prepare_file(str(binary_file), compress=True)
        
        test_results.append(("Binary file compression", 
                           metadata['compressed'] == False,
                           "Random data should not compress"))
        
        if prepared_path != str(binary_file):
            os.unlink(prepared_path)
        
        # Test 3: Small file (should not compress)
        print("\n3. Testing small file...")
        small_file = test_dir / "small.txt"
        small_file.write_text("Small file")
        
        prepared_path, metadata = handler.prepare_file(str(small_file), compress=True)
        
        test_results.append(("Small file handling", 
                           metadata['compressed'] == False,
                           f"Size: {metadata['size']} bytes (< 1KB threshold)"))
        
        # Test 4: Directory archiving
        print("\n4. Testing directory archiving...")
        test_subdir = test_dir / "test_directory"
        test_subdir.mkdir(exist_ok=True)
        (test_subdir / "file1.txt").write_text("File 1")
        (test_subdir / "file2.txt").write_text("File 2")
        
        tar_path, dir_metadata = handler.prepare_directory(str(test_subdir), compress=True)
        
        test_results.append(("Directory archiving", 
                           os.path.exists(tar_path) and tar_path.endswith('.tar.gz'),
                           f"Archive size: {dir_metadata['size']} bytes, "
                           f"Files: {dir_metadata['file_count']}"))
        
        os.unlink(tar_path)
        
        # Test 5: File restoration
        print("\n5. Testing file restoration...")
        # Create a compressed file
        restore_test = test_dir / "restore_test.txt"
        restore_content = "This file will be compressed and restored.\n" * 50
        restore_test.write_text(restore_content)
        
        prepared_path, metadata = handler.prepare_file(str(restore_test), compress=True)
        
        # Simulate restoration
        restored_path = test_dir / "restored.txt"
        handler.restore_file(prepared_path, metadata, str(restored_path))
        
        restored_content = restored_path.read_text()
        test_results.append(("File restoration", 
                           restored_content == restore_content,
                           "Compressed file restored correctly"))
        
        if prepared_path != str(restore_test):
            os.unlink(prepared_path)
        
        # Test 6: Metadata save/load
        print("\n6. Testing metadata save/load...")
        test_metadata = {
            'original_name': 'test.txt',
            'size': 1024,
            'type': 'text',
            'compressed': True
        }
        
        meta_path = handler.save_metadata(test_metadata, str(test_dir / "test"))
        loaded_metadata = handler.load_metadata(meta_path)
        
        test_results.append(("Metadata save/load", 
                           loaded_metadata == test_metadata,
                           "Metadata preserved correctly"))
        
        os.unlink(meta_path)
        
        # Test 7: Capacity calculation
        print("\n7. Testing capacity calculation...")
        file_sizes = [
            (1024, "1 KB"),
            (1024 * 100, "100 KB"),
            (1024 * 1024, "1 MB"),
            (1024 * 1024 * 10, "10 MB")
        ]
        
        capacity_passed = True
        for size, label in file_sizes:
            info = calculate_required_capacity(size)
            if not info['suggestions']:
                capacity_passed = False
                break
        
        test_results.append(("Capacity calculation", 
                           capacity_passed,
                           "All file sizes calculated successfully"))
        
    finally:
        # Clean up
        shutil.rmtree(test_dir, ignore_errors=True)
    
    # Print summary
    print("\n" + "="*50)
    print("TEST SUMMARY:")
    print("="*50)
    
    for test_name, passed, details in test_results:
        print_test(test_name, passed, details)
    
    passed_count = sum(1 for _, passed, _ in test_results if passed)
    total_count = len(test_results)
    
    print(f"\nTotal: {passed_count}/{total_count} tests passed")
    
    return passed_count == total_count

def test_file_type_detection():
    """Test file type detection for various formats"""
    print("\n" + "="*50)
    print("FILE TYPE DETECTION TEST")
    print("="*50)
    
    handler = FileHandler()
    
    test_files = {
        'document.txt': ('text', 'text/plain'),
        'script.py': ('text', 'text/x-python'),
        'data.json': ('text', 'application/json'),
        'image.png': ('image', 'image/png'),
        'photo.jpg': ('image', 'image/jpeg'),
        'document.pdf': ('document', 'application/pdf'),
        'archive.zip': ('archive', 'application/zip'),
        'video.mp4': ('media', 'video/mp4'),
        'database.sqlite': ('binary', 'application/x-sqlite3'),
        'unknown.xyz': ('binary', 'application/octet-stream')
    }
    
    all_passed = True
    for filename, (expected_type, _) in test_files.items():
        detected_type, mime = handler.identify_file_type(filename)
        passed = detected_type == expected_type
        if not passed:
            all_passed = False
        print_test(f"Detect {filename}", passed, f"Type: {detected_type}, MIME: {mime}")
    
    return all_passed

if __name__ == "__main__":
    print("Testing File Handler on macOS...")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")
    
    # Run tests
    type_test_passed = test_file_type_detection()
    ops_test_passed = test_file_operations()
    
    # Overall result
    if type_test_passed and ops_test_passed:
        print("\n✅ All tests passed! File handler is working correctly.")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed. Please check the output above.")
        sys.exit(1)