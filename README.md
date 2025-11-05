# TuxKeep 🐧
**Professional Backup & Restore Tool for Termux**

<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/4e0f5a79-9b89-46e2-adfd-31b7d072caf1" />


TuxKeep is a powerful, encrypted backup solution for Termux that offers full system backups, home directory backups, and package-level backup/restore capabilities.

## ✨ Features

- 🔐 **AES-256 Encryption** - Military-grade security for your backups
- 🗜️ **Ultra Compression** - Efficient pigz compression
- 📦 **Package-Level Backups** - Backup and restore individual packages
- 🎯 **Custom Named Backups** - Organize backups with custom names
- 📂 **Flexible Storage** - Backup to internal storage or current directory
- ⚡ **Fast & Efficient** - Optimized for speed and minimal resource usage

## 🚀 Quick Installation

### One-Line Install
```bash
pkg install -y curl openssl-tool && curl -fsSL https://raw.githubusercontent.com/Tazhossain/Tuxkeep/main/tuxkeep.sh -o tuxkeep && chmod u+x tuxkeep && mv tuxkeep $PREFIX/bin/ && tuxkeep
```

### Manual Installation
```bash
pkg install -y curl openssl-tool pigz tar
curl -fsSL https://raw.githubusercontent.com/Tazhossain/Tuxkeep/main/Tuxkeep.sh -o tuxkeep
chmod u+x tuxkeep
mv tuxkeep $PREFIX/bin/
tuxkeep
```

### Alternative Install (Short URL)
```bash
pkg install -y curl openssl-tool && curl -fsSL https://bit.ly/Tuxkeep -o tuxkeep && chmod u+x tuxkeep && mv tuxkeep $PREFIX/bin/ && tuxkeep
```

## 📖 Usage

### Basic Commands

**Backup Commands:**
```bash
.backup              # Interactive backup menu
.b                   # Quick backup (alias)
.backup mydata       # Create custom named backup
.backup here         # Backup to current directory
.backup here mydata  # Custom backup in current directory
```

**Restore Commands:**
```bash
.restore             # Interactive restore menu
.r                   # Quick restore (alias)
.restore mydata      # Restore specific backup
.restore here        # Restore from current directory
```

**Package Commands:**
```bash
.backup pkg          # Interactive package selection
.backup pkg python   # Backup specific package
.restore pkg         # Interactive package restore
.restore pkg python  # Restore specific package
```

**Maintenance:**
```bash
.clean               # Delete all backups
.tuxkeep             # Show help
.tuxremove           # Uninstall TuxKeep
```

## 📋 Backup Types

### Full Backup
Backs up entire Termux environment including:
- Home directory (`/data/data/com.termux/files/home`)
- Prefix directory (`/data/data/com.termux/files/usr`)

### Home Backup
Backs up only your home directory:
- Personal files and configurations
- Faster than full backup

## 🔒 Security

- All backups are encrypted with **AES-256-CBC**
- Each backup has a unique encryption key stored in `.tkb.key` file
- Keys are auto-managed - keep them safe!

## 📁 Storage Locations

**Default:** `/storage/emulated/0/TuxKeep/`

**Custom:** Use `here` parameter to backup to current directory

## 🛠️ Requirements

- Termux (Android terminal emulator)
- Storage permission (auto-requested)
- Dependencies: `tar`, `pigz`, `openssl-tool` (auto-installed)

## 📝 Examples

```bash
# Create a backup before major changes
.backup before-update

# Quick backup to external storage
.b here emergency

# Backup specific package
.backup pkg nodejs

# Restore from specific backup
.restore before-update

# View all commands
.tuxkeep
```

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 📄 License

MIT License - feel free to use and modify!

## 👨‍💻 Author

**Taz Hossain**

---

⭐ Star this repo if TuxKeep helped you!
