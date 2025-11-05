#!/data/data/com.termux/files/usr/bin/bash

CREDIT="Taz"
BACKUP_DIR="TuxKeep"
INSTALL_MARKER="$PREFIX/bin/.tuxkeep_installed"
TUXKEEP_BIN="$PREFIX/bin/tuxkeep"

log() { echo -e "\033[1;36m[🐧 TuxKeep]\033[0m $1"; }
success() { echo -e "\033[1;32m✅\033[0m $1"; }
error() { echo -e "\033[1;31m❌\033[0m $1" >&2; }
info() { echo -e "\033[1;36m[i]\033[0m $1"; }

detect_storage() {
    [ -d "/storage/emulated/0" ] && [ -w "/storage/emulated/0" ] && echo "/storage/emulated/0" && return
    [ -d "/sdcard" ] && [ -w "/sdcard" ] && echo "/sdcard" && return
    echo ""
}

get_timestamp() { date +"%Y%m%d_%H%M%S"; }

check_deps() {
    command -v openssl >/dev/null 2>&1 && command -v pigz >/dev/null 2>&1 && return 0
    error "Required tools not found!"
    info "Run: pkg install -y openssl-tool pigz"
    sleep 3
    return 1
}

get_backup_path() {
    local location="$1"
    [ "$location" = "here" ] && echo "$(pwd)" && return
    local storage=$(detect_storage)
    [ -z "$storage" ] && error "Internal storage not detected!" && sleep 2 && return 1
    echo "$storage/$BACKUP_DIR"
}

create_archive() {
    local backup_file="$1"
    local source_path="$2"
    local temp_archive="${backup_file%.*}.tmp.tar.gz"
    
    check_deps || return 1
    
    local password=$(openssl rand -base64 32 2>/dev/null)
    [ -z "$password" ] && error "Failed to generate encryption key" && sleep 2 && return 1
    
    if tar -I "pigz -9" -cf "$temp_archive" -C "$source_path" . 2>/dev/null; then
        if openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass pass:"$password" -in "$temp_archive" -out "$backup_file" 2>/dev/null; then
            echo "$password" > "${backup_file}.key"
            chmod 600 "${backup_file}.key"
            rm -f "$temp_archive"
            [ -f "$backup_file" ] && [ -s "$backup_file" ] && return 0
        fi
        rm -f "$temp_archive"
    fi
    return 1
}

restore_archive() {
    local backup_file="$1"
    local dest_path="$2"
    local keyfile="${backup_file}.key"
    
    [ ! -f "$keyfile" ] && error "Key file not found: ${backup_file}.key" && sleep 2 && return 1
    
    local password=$(cat "$keyfile")
    local temp_archive="${backup_file%.*}.tmp.tar.gz"
    
    if openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -pass pass:"$password" -in "$backup_file" -out "$temp_archive" 2>/dev/null; then
        if tar -I pigz -xf "$temp_archive" -C "$dest_path" 2>/dev/null; then
            rm -f "$temp_archive"
            return 0
        fi
        rm -f "$temp_archive"
    fi
    return 1
}

perform_backup() {
    local custom_name="$1"
    local backup_location="$2"
    local backup_type="$3"
    
    local backup_path=$(get_backup_path "$backup_location")
    [ $? -ne 0 ] && return 1
    
    local backup_name="${custom_name:-${backup_type^}}.tkb"
    local backup_file="$backup_path/$backup_name"
    local source_path="$HOME"
    
    mkdir -p "$backup_path" 2>/dev/null
    
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "       ${backup_type^^} BACKUP IN PROGRESS"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Creating ${backup_type^} Backup: $backup_name"
    info "Compressing... This might take a moment"
    echo ""
    
    if [ "$backup_type" = "full" ]; then
        source_path="/data/data/com.termux/files"
        local temp_archive="$backup_path/.tuxkeep_temp_$.tar.gz"
        local password=$(openssl rand -base64 32 2>/dev/null)
        [ -z "$password" ] && error "Failed to generate encryption key" && sleep 2 && return 1

        if tar -I "pigz -9" -cf "$temp_archive" -C "$source_path" home usr 2>/dev/null; then
            if openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass pass:"$password" -in "$temp_archive" -out "$backup_file" 2>/dev/null; then
                echo "$password" > "${backup_file}.key"
                chmod 600 "${backup_file}.key"
                rm -f "$temp_archive"
            else
                rm -f "$temp_archive"
                error "Encryption failed"
                read -p "Press Enter to continue..."
                return 1
            fi
        else
            rm -f "$temp_archive"
            error "Backup failed"
            read -p "Press Enter to continue..."
            return 1
        fi
    else
        create_archive "$backup_file" "$source_path" || {
            error "Backup failed"
            read -p "Press Enter to continue..."
            return 1
        }
    fi
    
    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
        local size=$(ls -lh "$backup_file" | awk '{print $5}')
        echo ""
        success "${backup_type^} backup completed!"
        echo ""
        echo "  📂 Location: $backup_file"
        echo "  📊 Size: $size"
        echo ""
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        success "Backup secured with AES-256 encryption"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        error "Backup file creation failed"
    fi
    
    read -p "Press Enter to continue..."
}

perform_restore() {
    local custom_name="$1"
    local backup_location="$2"
    local backup_type="$3"
    
    local backup_path=$(get_backup_path "$backup_location")
    [ $? -ne 0 ] && return 1
    
    [ ! -d "$backup_path" ] && error "No backups found in: $backup_path" && sleep 2 && return 1
    
    local backups=()
    if [ -n "$custom_name" ]; then
        local backup_file="$backup_path/${custom_name}.tkb"
        [ ! -f "$backup_file" ] && error "Backup '${custom_name}.tkb' not found!" && sleep 2 && return 1
        backups=("$backup_file")
    else
        while IFS= read -r backup; do
            backups+=("$backup")
        done < <(find "$backup_path" -name "*.tkb" -type f 2>/dev/null | sort -r)
    fi
    
    [ ${#backups[@]} -eq 0 ] && error "No backups found!" && sleep 2 && return 1
    
    local selected="${backups[0]}"
    
    if [ ${#backups[@]} -gt 1 ] || [ -z "$custom_name" ]; then
        clear
        log "Select ${backup_type^} Backup to Restore"
        echo ""
        local count=1
        for backup in "${backups[@]}"; do
            local size=$(ls -lh "$backup" | awk '{print $5}')
            local date=$(date -r "$backup" "+%Y-%m-%d %H:%M")
            echo -e "\033[1;36m$count.\033[0m $(basename "$backup") [$size] - $date"
            ((count++))
        done
        echo ""
        echo "  0. Exit"
        echo ""
        read -p "Select [0-${#backups[@]}]: " selection
        echo ""
        [ "$selection" -eq 0 ] && return 0
        if [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
            selected="${backups[$((selection-1))]}"
        else
            error "Invalid selection!"
            sleep 2
            return 1
        fi
    fi
    
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "        ${backup_type^^} RESTORE IN PROGRESS"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Decrypting and restoring..."
    info "Almost there... Be patient!"
    echo ""
    
    local dest_path="$HOME"
    [ "$backup_type" = "full" ] && dest_path="/data/data/com.termux/files"
    
    if restore_archive "$selected" "$dest_path"; then
        echo ""
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        success "${backup_type^} restore completed!"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        info "Termux is Restarting..."
        sleep 3
        pkill -9 -f com.termux
    else
        error "Restore failed"
    fi
    sleep 2
}

show_backup_menu() {
    clear
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "           BACKUP OPTIONS"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Full Backup"
    echo "  2. Backup Home"
    echo "  0. Exit"
    echo ""
    read -n 1 -p "Select option [0-2]: " choice
    echo ""
    case "$choice" in
        0) return 0 ;;
        1) perform_backup "$1" "$2" "full" ;;
        2) perform_backup "$1" "$2" "home" ;;
        *) error "Invalid option!" && sleep 1 ;;
    esac
}

show_restore_menu() {
    clear
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "          RESTORE OPTIONS"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Full Restore"
    echo "  2. Restore Home"
    echo "  0. Exit"
    echo ""
    read -n 1 -p "Select option [0-2]: " choice
    echo ""
    case "$choice" in
        0) return 0 ;;
        1) perform_restore "$1" "$2" "full" ;;
        2) perform_restore "$1" "$2" "home" ;;
        *) error "Invalid option!" && sleep 1 ;;
    esac
}

package_backup() {
    local package_name="$1"
    [ -z "$package_name" ] && error "Package name required!" && return 1
    pkg list-installed 2>/dev/null | grep -q "^$package_name/" || {
        error "Package '$package_name' not installed!"
        sleep 2
        return 1
    }
    
    local storage=$(detect_storage)
    [ -z "$storage" ] && error "Internal storage not detected!" && sleep 2 && return 1
    
    local timestamp=$(get_timestamp)
    local backup_name="${package_name}_${timestamp}.tar.gz"
    
    clear
    log "Backing up: $package_name 🐧"
    echo ""
    
    local pkg_files=()
    if [ -f "$PREFIX/var/lib/dpkg/info/${package_name}.list" ]; then
        while IFS= read -r file; do
            [ -f "$file" ] && pkg_files+=("$file")
        done < "$PREFIX/var/lib/dpkg/info/${package_name}.list"
    fi
    
    [ ${#pkg_files[@]} -eq 0 ] && error "No files found for package: $package_name" && sleep 2 && return 1
    
    local backup_path="$storage/$BACKUP_DIR/packages"
    mkdir -p "$backup_path" 2>/dev/null
    local backup_file="$backup_path/$backup_name"
    
    if tar -I "pigz -9" --absolute-names -cf "$backup_file" "${pkg_files[@]}" 2>/dev/null; then
        if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
            local size=$(ls -lh "$backup_file" | awk '{print $5}')
            success "Backup complete! 🎉"
            echo "  📁 File: $backup_file"
            echo "  📊 Size: $size"
            echo "  🐧 Files: ${#pkg_files[@]}"
            echo ""
            info "Restore: .restore pkg $package_name"
            echo ""
        else
            error "Backup file is empty!"
        fi
    else
        error "Backup failed! Check if package files exist"
    fi
    sleep 2
}

package_restore() {
    local package_name="$1"
    [ -z "$package_name" ] && error "Package name required!" && return 1
    
    local storage=$(detect_storage)
    [ -z "$storage" ] && error "Internal storage not detected!" && sleep 2 && return 1
    
    local backups=()
    while IFS= read -r backup; do
        backups+=("$backup")
    done < <(find "$storage/$BACKUP_DIR/packages" -name "${package_name}_*.tar.gz" -type f 2>/dev/null | sort -r)
    
    [ ${#backups[@]} -eq 0 ] && error "No backup for: $package_name" && sleep 2 && return 1
    
    local selected="${backups[0]}"
    clear
    log "Restoring: $package_name 🔄"
    echo ""
    info "Using: $(basename "$selected")"
    echo ""
    
    local temp="$PREFIX/.restore_pkg_$$"
    mkdir -p "$temp"
    cd "$temp"
    tar -I pigz -xf "$selected" 2>/dev/null
    cp -rf * "$PREFIX/" 2>/dev/null
    rm -rf "$temp"
    echo ""
    success "Restore complete! 🎉"
    echo "  🐧 Package: $package_name"
    sleep 2
}

select_package_interactive() {
    local packages=($(pkg list-installed 2>/dev/null | awk -F'/' '{print $1}' | grep -v '^$' | sort -u))
    [ ${#packages[@]} -eq 0 ] && error "No packages found!" && sleep 2 && return 1
    
    clear
    log "Select Package to Backup"
    echo ""
    local count=1
    for pkg in "${packages[@]}"; do
        echo -e "\033[1;36m$count.\033[0m $pkg"
        ((count++))
    done
    echo ""
    echo "  0. Exit"
    echo ""
    read -p "Enter number [0-${#packages[@]}]: " selection
    echo ""
    [ "$selection" -eq 0 ] && return 0
    [ "$selection" -ge 1 ] && [ "$selection" -le ${#packages[@]} ] && package_backup "${packages[$((selection-1))]}" || {
        error "Invalid selection!"
        sleep 1
    }
}

select_package_restore() {
    local storage=$(detect_storage)
    [ -z "$storage" ] && error "Internal storage not detected!" && sleep 2 && return 1
    
    local pkg_backup_dir="$storage/$BACKUP_DIR/packages"
    [ ! -d "$pkg_backup_dir" ] && error "No package backups found!" && sleep 2 && return 1
    
    local pkg_names=()
    while IFS= read -r backup; do
        local pkg_name=$(basename "$backup" | sed 's/_[0-9]*\.tar\.gz$//')
        [[ ! " ${pkg_names[@]} " =~ " ${pkg_name} " ]] && pkg_names+=("$pkg_name")
    done < <(find "$pkg_backup_dir" -name "*.tar.gz" -type f 2>/dev/null | sort)
    
    [ ${#pkg_names[@]} -eq 0 ] && error "No package backups found!" && sleep 2 && return 1
    
    clear
    log "Select Package to Restore"
    echo ""
    local count=1
    for pkg in "${pkg_names[@]}"; do
        echo -e "\033[1;36m$count.\033[0m $pkg"
        ((count++))
    done
    echo ""
    echo "  0. Exit"
    echo ""
    read -p "Enter number [0-${#pkg_names[@]}]: " selection
    echo ""
    [ "$selection" -eq 0 ] && return 0
    [ "$selection" -ge 1 ] && [ "$selection" -le ${#pkg_names[@]} ] && package_restore "${pkg_names[$((selection-1))]}" || {
        error "Invalid selection!"
        sleep 1
    }
}

clean_backups() {
    clear
    log "Cleaning all backups..."
    echo ""
    read -n 1 -p "Delete ALL backups from internal storage? (y/N): " confirm
    echo ""
    [[ ! $confirm =~ ^[yY]$ ]] && echo "" && log "Cancelled." && sleep 1 && return 0
    echo ""
    
    local storage=$(detect_storage)
    [ -z "$storage" ] && error "Internal storage not detected!" && sleep 2 && return 1
    
    local backup_path="$storage/$BACKUP_DIR"
    if [ -d "$backup_path" ]; then
        rm -rf "$backup_path" 2>/dev/null
        [ ! -d "$backup_path" ] && success "Deleted: $backup_path" || error "Failed to delete backups"
    else
        info "No backups found"
    fi
    echo ""
    sleep 2
}

show_usage() {
    clear
    cat << 'EOF'
╔════════════════════════════════════════════════════╗
║                     TuxKeep                        ║
║              Crafted with ❤️  by Taz                ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║  QUICK COMMANDS:                                   ║
║                                                    ║
║  .backup / .b [name]     Backup with custom name   ║
║  .restore / .r [name]    Restore custom backup     ║
║  .backup here / .b here  Backup to current dir     ║
║  .restore here / .r here Restore from current dir  ║
║  .clean                  Delete all backups        ║
║                                                    ║
║  EXAMPLES:                                         ║
║                                                    ║
║  .backup termuxai        Creates termuxai.tkb      ║
║  .restore termuxai       Restores termuxai.tkb     ║
║  .backup                 Creates Full.tkb          ║
║  .b here                 Backup to current folder  ║
║                                                    ║
║  PACKAGE BACKUP/RESTORE:                           ║
║                                                    ║
║  .backup pkg             Select package backup     ║
║  .backup pkg <name>      Backup specific package   ║
║  .restore pkg            Select package restore    ║
║  .restore pkg <name>     Restore specific package  ║
║                                                    ║
║  FEATURES:                                         ║
║                                                    ║
║  > Custom named backups (auto-replaces old ones)   ║
║  > Separate key file for security (.tkb.key)       ║
║  > Full Backup or Home only                        ║
║  > AES-256 encryption for security                 ║
║  > Ultra compression with pigz                     ║
║  > Package-level backup/restore                    ║
║  > Backup to any directory                         ║
║                                                    ║
║  UNINSTALL:                                        ║
║                                                    ║
║  .tuxremove              Remove TuxKeep            ║
║                                                    ║
╚════════════════════════════════════════════════════╝
EOF
    echo ""
}

uninstall_tuxkeep() {
    clear
    log "Uninstalling TuxKeep..."
    echo ""
    rm -f "$TUXKEEP_BIN" "$INSTALL_MARKER" 2>/dev/null
    
    local shellrc="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && shellrc="$HOME/.zshrc"
    
    [ -f "$shellrc" ] && sed -i '/alias \.backup=/d;/alias \.b=/d;/alias \.restore=/d;/alias \.r=/d;/alias \.tuxkeep=/d;/alias \.clean=/d;/alias \.tuxremove=/d' "$shellrc" 2>/dev/null
    
    echo ""
    success "TuxKeep uninstalled!"
    echo ""
    info "Your backups are safe in TuxKeep folder"
    info "Termux is Restarting..."
    echo ""
    sleep 3
    pkill -9 -f com.termux
    exit 0
}

install_dependencies() {
    echo "► Checking dependencies..."
    local missing=()
    
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v pigz >/dev/null 2>&1 || missing+=("pigz")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl-tool")
    
    if [ ${#missing[@]} -eq 0 ]; then
        echo "► All dependencies already installed!"
        return 0
    fi
    
    echo "► Installing missing dependencies: ${missing[*]}"
    if pkg install -y ${missing[*]} 2>&1 | grep -q "Unable to locate package\|E:"; then
        echo ""
        error "Failed to install: ${missing[*]}"
        info "Please run manually: pkg install -y ${missing[*]}"
        return 1
    fi
    
    source $PREFIX/etc/bash.bashrc 2>/dev/null
    export PATH="$PREFIX/bin:$PATH"
    
    local still_missing=()
    command -v tar >/dev/null 2>&1 || still_missing+=("tar")
    command -v pigz >/dev/null 2>&1 || still_missing+=("pigz")
    command -v openssl >/dev/null 2>&1 || still_missing+=("openssl")
    
    if [ ${#still_missing[@]} -eq 0 ]; then
        echo "► Dependencies installed successfully!"
        return 0
    else
        echo ""
        error "Installation incomplete: ${still_missing[*]}"
        info "Please restart Termux and run: pkg install -y ${still_missing[*]}"
        return 1
    fi
}

install_tuxkeep() {
    clear
    echo ""
    cat << 'EOF'
╔════════════════════════════════════════════╗
║                                            ║
║      ░▀█▀░█░█░█░█░█░█░█▀▀░█▀▀░█▀█          ║
║      ░░█░░█░█░▄▀▄░█▀▄░█▀▀░█▀▀░█▀▀          ║
║      ░░▀░░▀▀▀░▀░▀░▀░▀▀▀░▀▀▀░▀░░            ║
║                                            ║
║         Architected by Taz 🚀              ║
║      Your Data's New Best Friend           ║
║                                            ║
╚════════════════════════════════════════════╝
EOF
    echo ""
}
    command -v tar >/dev/null 2>&1 && command -v pigz >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1 || {
        install_dependencies || { echo ""; sleep 2; exit 1; }
    }
    
    echo "► Initializing installation sequence..."
    echo "► Requesting storage permissions..."
    echo ""
    
    rm -f "$INSTALL_MARKER" 2>/dev/null
    
    local shellrc="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && shellrc="$HOME/.zshrc"
    
    [ -f "$shellrc" ] && sed -i '/alias \.backup=/d;/alias \.b=/d;/alias \.restore=/d;/alias \.r=/d;/alias \.tuxkeep=/d;/alias \.clean=/d;/alias \.tuxremove=/d' "$shellrc" 2>/dev/null
    
    [ ! -f "$TUXKEEP_BIN" ] && cp "$0" "$TUXKEEP_BIN" 2>/dev/null && chmod 755 "$TUXKEEP_BIN" 2>/dev/null
    
    cat >> "$shellrc" << 'ALIASES'

alias .backup='tuxkeep .backup'
alias .b='tuxkeep .b'
alias .restore='tuxkeep .restore'
alias .r='tuxkeep .r'
alias .tuxkeep='tuxkeep --help'
alias .clean='tuxkeep .clean'
alias .tuxremove='tuxkeep .tuxremove'
ALIASES
    
    echo "installed" > "$INSTALL_MARKER"
    
    echo "► Compiling magic spells..."
    echo "► Deploying backup ninjas..."
    sleep 1
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Installation successful! 🎊"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "TuxKeep is ready to guard your data like a boss! 💪"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Quick Start Commands:"
    echo ""
    echo "  .backup mydata       Create custom backup"
    echo "  .restore mydata      Restore your backup"
    echo "  .backup here         Backup to current folder"
    echo "  .b                   Quick backup menu"
    echo "  .r                   Quick restore menu"
    echo "  .tuxkeep             Show full help"
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Termux is Restarting..."
    echo ""
    sleep 3
    pkill -9 -f com.termux
    exit 0
}

main() {
    [ ! -f "$INSTALL_MARKER" ] || [ ! -f "$TUXKEEP_BIN" ] && {
        [ ! -d "$HOME/storage/shared" ] && termux-setup-storage 2>/dev/null & sleep 2
        install_tuxkeep
        exit 0
    }
    
    case "${1:-}" in
        .backup|backup|.b)
            [ "$2" = "here" ] && show_backup_menu "$3" "here" && return
            [ "$2" = "pkg" ] && { [ -n "${3:-}" ] && package_backup "$3" || select_package_interactive; return; }
            show_backup_menu "${2:-}"
            ;;
        .restore|restore|.r)
            [ "$2" = "here" ] && show_restore_menu "$3" "here" && return
            [ "$2" = "pkg" ] && { [ -n "${3:-}" ] && package_restore "$3" || select_package_restore; return; }
            show_restore_menu "${2:-}"
            ;;
        --help|-h|help) show_usage ;;
        .tuxremove|uninstall|remove) uninstall_tuxkeep ;;
        .clean|clean) clean_backups ;;
        *) show_usage ;;
    esac
}

main "$@"
