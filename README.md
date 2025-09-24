# Steganography Encryption Tool

A command-line tool that combines AES-256-CBC encryption with LSB (Least Significant Bit) image steganography to securely hide encrypted data within PNG images.

## Features

- **Strong Encryption**: Uses OpenSSL AES-256-CBC with PBKDF2 for secure encryption
- **Image Steganography**: Hides encrypted data in the least significant bits of PNG images
- **Simple CLI**: Easy-to-use command-line interface via zsh aliases
- **Self-contained**: All operations confined to the `~/enc/` directory for security

## Installation

### Prerequisites

- macOS (tested) or Linux
- Python 3.x
- zsh shell
- OpenSSL (usually pre-installed)

### Setup

1. Clone this repository to `~/enc/`:
```bash
cd ~
git clone [repository-url] enc
cd enc
```

2. Create and activate Python virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

3. Install required Python package:
```bash
pip install pillow
```

4. Make the Python scripts executable:
```bash
chmod +x image_binary_insert.py image_binary_extract.py
```

5. Add the shell functions to your `.zshrc`:
```bash
cat .zshrc.example >> ~/.zshrc
source ~/.zshrc
```

## Usage

All commands must be run from the `~/enc/` directory:

```bash
cd ~/enc
```

### Hiding Data (stego)

To encrypt and hide a text file within an image:

```bash
stego <input_file> <carrier_image.png> <password>
```

**Example:**
```bash
stego secret.txt image.png "myStr0ngP@ssw0rd!"
```

This will create `image_hidden.png` containing your encrypted data.

### Extracting Data (unstego)

To extract and decrypt hidden data from an image:

```bash
unstego <stego_image.png> <output_file> <password>
```

**Example:**
```bash
unstego image_hidden.png recovered.txt "myStr0ngP@ssw0rd!"
```

## How It Works

1. **Encryption**: Your input file is first encrypted using AES-256-CBC with your password
2. **Embedding**: The encrypted data is then hidden in the least significant bits of the carrier image's RGB values
3. **Size Header**: The file size is stored in the first 32 bits to ensure accurate extraction
4. **Extraction**: The process reverses - data is extracted from the image and then decrypted

## File Structure

```
~/enc/
├── image_binary_insert.py    # Python script for embedding data
├── image_binary_extract.py   # Python script for extracting data
├── .zshrc.example           # Shell functions to add to ~/.zshrc
├── venv/                    # Python virtual environment
├── .gitignore              # Git ignore file (excludes venv)
└── README.md               # This file
```

## Security Notes

- All operations are confined to the `~/enc/` directory
- Temporary files are automatically cleaned up
- Use strong passwords - the security depends on your password strength
- The steganography provides obscurity, not security - the encryption provides security
- Original files are not modified

## Limitations

- Only works with PNG images (carrier and output)
- Image must be large enough to hold the encrypted data (3 bits per pixel)
- Maximum file size depends on carrier image dimensions

## Example Workflow

```bash
# 1. Navigate to the enc directory
cd ~/enc

# 2. Place your secret file and a PNG image in the directory
echo "This is my secret data" > mysecret.txt
# (copy any PNG image to the directory)

# 3. Hide the data
stego mysecret.txt carrier.png "SuperSecretPassword123!"
# Creates: carrier_hidden.png

# 4. Delete the original files (optional)
rm mysecret.txt

# 5. Later, recover the data
unstego carrier_hidden.png recovered.txt "SuperSecretPassword123!"

# 6. Verify
cat recovered.txt
```

## Troubleshooting

- **"Error: This command must be run from ~/enc/ directory"**: Run `cd ~/enc` first
- **"Image too small"**: Use a larger carrier image
- **"Wrong password?"**: Ensure you're using the exact same password for extraction
- **Command not found**: Run `source ~/.zshrc` or restart your terminal

## Contributing

Feel free to add your ideas to this repo for more open source compatibility!

## License

Free-Use!

## Disclaimer

This tool is for educational and legitimate privacy purposes only.