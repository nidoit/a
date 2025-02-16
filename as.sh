#!/bin/bash

# Exit script if any command fails
# set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for non-root user
if [ "$EUID" = 0 ]; then
    echo -e "${RED}Please run as normal user (do not use sudo).${NC}"
    exit 1
fi

# GPU Detection and Configuration
echo -e "${BLUE}Detecting and configuring GPU...${NC}"

detect_gpu() {
    local gpu_info=$(lspci | grep -i 'vga\|3d\|display')
    local gpu_types=()
    
    if echo "$gpu_info" | grep -qi "nvidia"; then
        gpu_types+=("nvidia")
    fi
    if echo "$gpu_info" | grep -qi "intel"; then
        gpu_types+=("intel")
    fi
    if echo "$gpu_info" | grep -qi "amd\|ati"; then
        gpu_types+=("amd")
    fi
    
    if [ ${#gpu_types[@]} -eq 0 ]; then
        echo "1"  # Basic/Unknown
        return
    fi
    
    if [[ " ${gpu_types[@]} " =~ " nvidia " ]]; then
        echo "4"  # NVIDIA
    elif [[ " ${gpu_types[@]} " =~ " amd " ]]; then
        echo "3"  # AMD
    elif [[ " ${gpu_types[@]} " =~ " intel " ]]; then
        echo "2"  # Intel
    else
        echo "1"  # Basic/Unknown
    fi
}

GPU_CHOICE=$(detect_gpu)
case $GPU_CHOICE in
    1) 
        GPU_FXE="xf86-video-vesa"
        GPU_TYPE="Basic Graphics"
        GPU_CONFIG=""
        ;;
    2)
        GPU_FXE="xf86-video-intel vulkan-intel intel-media-driver libva-intel-driver intel-gpu-tools"
        GPU_TYPE="Intel Graphics"
        GPU_CONFIG="options i915 enable_fbc=1 enable_psr=2 fastboot=1"
        ;;
    3)
        GPU_FXE="xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau"
        GPU_TYPE="AMD Graphics"
        GPU_CONFIG="options amdgpu si_support=1 cik_support=1"
        ;;
    4)
        GPU_FXE="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
        GPU_TYPE="NVIDIA Graphics"
        GPU_CONFIG="options nvidia-drm modeset=1"
        ;;
esac

# Install GPU drivers
echo -e "${BLUE}Installing GPU drivers: ${GPU_TYPE}...${NC}"
sudo pacman -S --noconfirm ${GPU_FXE} ${GPU_COMMON}

# Apply GPU configuration
if [ -n "$GPU_CONFIG" ]; then
    case $GPU_TYPE in
        "Intel Graphics")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/i915.conf > /dev/null
            ;;
        "AMD Graphics")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null
            ;;
        "NVIDIA Graphics")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
            sudo sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            sudo mkinitcpio -P
            ;;
    esac
fi

# System update
echo -e "${BLUE}Updating system...${NC}"
sudo pacman -Syu --noconfirm

# Configure Swedish keyboard layout
echo -e "${BLUE}Configuring Swedish keyboard layout...${NC}"
sudo localectl set-x11-keymap se
sudo localectl set-keymap sv-latin1

# Create XKB configuration
echo -e "${BLUE}Setting up XKB configuration...${NC}"
sudo mkdir -p /etc/X11/xorg.conf.d
cat << EOF | sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "se"
        Option "XkbModel" "pc105"
        Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
EOF

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
sudo pacman -S --needed --noconfirm \
    cairo cmake extra-cmake-modules pkg-config dbus gtk3 gtk4 libxcb qt5-base \
    qt6-base base-devel fontconfig freetype2 gcc-libs glibc glu harfbuzz \
    harfbuzz-icu libcups libcurl-gnutls openssl-1.1 qt5-x11extras zlib \
    xdg-utils libxkbcommon-x11 qt5-tools transmission-remote-gtk \
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd nodejs npm cronie \
    obs-studio v4l2loopback-dkms virtualbox virtualbox-host-modules-arch \
    nano conky samba net-tools bluez bluez-utils bluedevil 

# Install Rust if not present
if ! command -v rustc &> /dev/null; then
    echo -e "${BLUE}Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Install yay if not present
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}Installing yay...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo -e "${GREEN}yay installation complete!${NC}"
fi

# Install Julia
clear
echo -e "${BLUE}Installing Julia...${NC}"
curl -fsSL https://install.julialang.org | sh

# Install development and productivity tools
clear
echo -e "${BLUE}Installing additional software...${NC}"
yay -S sublime-text-4 visual-studio-code-bin teams teams-for-linux realvnc-vnc-server p3x-onenote-bin unciv-bin snes9x-git freetube github-cli \
        whatsapp-for-linux \
        --noconfirm

# Configure Virtualbox
sudo modprobe vboxdrv
sudo usermod -aG vboxusers $USER

# Enable bluetooth
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}Please restart your system or log out and log back in to apply changes.${NC}"
echo -e "${GREEN}To use Julia, restart your terminal or run 'source ~/.bashrc'${NC}"
