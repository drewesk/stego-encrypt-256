# 🔐 Steganography Encryption Tool

Combine military-grade AES-256 encryption with image steganography to securely hide any file or directory within PNG images.

## ✨ Features

- **🔒 Strong Encryption** - AES-256-CBC with PBKDF2 key derivation
- **🖼️ Image Steganography** - LSB (Least Significant Bit) embedding in PNG images
- **📁 Universal File Support** - Hide any file type: documents, images, archives, or entire directories
- **📦 Smart Compression** - Automatic compression for text and uncompressed formats
- **📊 Capacity Calculator** - Check image requirements before hiding files
- **🚀 Simple Commands** - Easy-to-use shell commands for all operations

## 🔧 Quick Install

### Prerequisites
- macOS or Linux with zsh
- Python 3.x
- Git

### One-Line Install
```bash
git clone [repository-url] ~/enc && cd ~/enc && ./setup.sh
```

### Manual Setup
```bash
# 1. Clone and enter directory
cd ~ && git clone [repository-url] enc && cd enc

# 2. Set up Python environment
python3 -m venv venv
source venv/bin/activate
pip install pillow numpy

# 3. Install shell functions
cat stego_functions_simple.sh >> ~/.zshrc
source ~/.zshrc

# 4. Verify installation
stego-info
```

## 💻 Usage

All commands run from `~/enc/` directory. Use `cd ~/enc` first.

### 🆕 Enhanced Commands

#### `stegox` - Hide Any File or Directory
```bash
stegox <input> <carrier.png> <password>
```

**Examples:**
```bash
stegox document.pdf photo.png "SecurePass123!"
stegox project_folder/ image.png "FolderPass456"
stegox archive.zip carrier.png "ZipPass789"
```
➜ Creates: `<carrier>_hidden.png`

#### `unstegox` - Extract Hidden Files
```bash
unstegox <hidden.png> <password> [output_name]
```

**Examples:**
```bash
unstegox photo_hidden.png "SecurePass123!"              # Auto-detect name
unstegox image_hidden.png "FolderPass456" my_project   # Custom name
```

#### `stego-capacity` - Check Image Size Requirements
```bash
stego-capacity <file_or_size>
```

**Examples:**
```bash
stego-capacity document.pdf    # Check specific file
stego-capacity 10MB           # Check size requirement
```

### 📦 Classic Commands

#### `stego` / `unstego` - Original text-focused tools
```bash
stego secret.txt carrier.png "password"              # Hide
unstego carrier_hidden.png output.txt "password"     # Extract
```

## 🎯 How It Works

1. **Encrypt** 🔒 - AES-256-CBC encryption with your password
2. **Embed** 🖼️ - Hide encrypted data in image's least significant bits
3. **Extract** 🔓 - Reverse the process to recover your files

## 📂 Supported Formats

- **Documents**: PDF, Word, text files, code files
- **Media**: Images, videos, audio files
- **Archives**: ZIP, TAR, compressed files
- **Directories**: Entire folder structures
- **Any file**: If it exists, you can hide it!

## 📝 Examples

### Quick Start
```bash
cd ~/enc

# Hide a PDF
stegox secret.pdf photo.png "MyPassword123!"
# Creates: photo_hidden.png

# Extract it back
unstegox photo_hidden.png "MyPassword123!"
# Recovers: secret.pdf
```

### Advanced Examples
```bash
# Hide entire directory
stegox my_project/ vacation.png "ProjectPass456!"

# Check if image is large enough
stego-capacity large_file.zip

# Extract with custom name
unstegox vacation_hidden.png "ProjectPass456!" restored_project
```

## ⚠️ Important Notes

- **Security**: Password strength = your security level
- **Carrier Images**: PNG only, must be large enough
- **Directory**: All operations in `~/enc/`
- **Originals**: Not modified or deleted automatically

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Command not found | Run: `source ~/.zshrc` |
| "Wrong directory" | Run: `cd ~/enc` |
| "Image too small" | Use `stego-capacity` to check size |
| "Wrong password?" | Check password, must be exact |
| Python errors | Reinstall: `pip install pillow numpy` |

## 📝 License

MIT License - Free to use and modify

## ⚠️ Disclaimer

For legitimate privacy and security purposes only. Users responsible for legal compliance.
