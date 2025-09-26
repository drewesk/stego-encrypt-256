#!/usr/bin/env python3
"""Generate test images for steganography testing"""
from PIL import Image
import numpy as np

def create_gradient_image(width, height, filename):
    """Create a gradient test image"""
    # Create gradient
    img_array = np.zeros((height, width, 3), dtype=np.uint8)
    
    for y in range(height):
        for x in range(width):
            img_array[y, x] = [
                int(255 * x / width),
                int(255 * y / height),
                int(255 * (x + y) / (width + height))
            ]
    
    img = Image.fromarray(img_array, 'RGB')
    img.save(filename, 'PNG')
    print(f"Created {filename} ({width}x{height})")

# Generate test images
create_gradient_image(1024, 1024, "test_carrier_1024.png")
create_gradient_image(2048, 2048, "test_carrier_2048.png")
create_gradient_image(512, 512, "test_carrier_512.png")