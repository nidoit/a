#!/bin/bash

# Salir del script si algún comando falla
# set -e

# Definición de colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AZUL='\033[0;34m'
NC='\033[0m'

# Verificar usuario no root
if [ "$EUID" = 0 ]; then
    echo -e "${ROJO}Por favor, ejecute como usuario normal (no use sudo).${NC}"
    exit 1
fi

# Detección y Configuración de GPU
echo -e "${AZUL}Detectando y configurando GPU...${NC}"

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
        echo "1"  # Básica/Desconocida
        return
    fi
    
    if [[ " ${gpu_types[@]} " =~ " nvidia " ]]; then
        echo "4"  # NVIDIA
    elif [[ " ${gpu_types[@]} " =~ " amd " ]]; then
        echo "3"  # AMD
    elif [[ " ${gpu_types[@]} " =~ " intel " ]]; then
        echo "2"  # Intel
    else
        echo "1"  # Básica/Desconocida
    fi
}

GPU_CHOICE=$(detect_gpu)
case $GPU_CHOICE in
    1) 
        GPU_FXE="xf86-video-vesa"
        GPU_TYPE="Gráficos Básicos"
        GPU_CONFIG=""
        ;;
    2)
        GPU_FXE="xf86-video-intel vulkan-intel intel-media-driver libva-intel-driver intel-gpu-tools"
        GPU_TYPE="Gráficos Intel"
        GPU_CONFIG="options i915 enable_fbc=1 enable_psr=2 fastboot=1"
        ;;
    3)
        GPU_FXE="xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau"
        GPU_TYPE="Gráficos AMD"
        GPU_CONFIG="options amdgpu si_support=1 cik_support=1"
        ;;
    4)
        GPU_FXE="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
        GPU_TYPE="Gráficos NVIDIA"
        GPU_CONFIG="options nvidia-drm modeset=1"
        ;;
esac

# Configurar teclado español
echo -e "${AZUL}Configurando teclado español...${NC}"
sudo localectl set-x11-keymap es
sudo localectl set-keymap es

# Crear configuración XKB
echo -e "${AZUL}Configurando XKB...${NC}"
sudo mkdir -p /etc/X11/xorg.conf.d
cat << EOF | sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "es"
        Option "XkbModel" "pc105"
        Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
EOF

# Instalar controladores de GPU
echo -e "${AZUL}Instalando controladores de GPU: ${GPU_TYPE}...${NC}"
sudo pacman -S --noconfirm ${GPU_FXE} ${GPU_COMMON}

# Aplicar configuración de GPU
if [ -n "$GPU_CONFIG" ]; then
    case $GPU_TYPE in
        "Gráficos Intel")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/i915.conf > /dev/null
            ;;
        "Gráficos AMD")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null
            ;;
        "Gráficos NVIDIA")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
            sudo sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            sudo mkinitcpio -P
            ;;
    esac
fi

# Actualización del sistema
echo -e "${AZUL}Actualizando el sistema...${NC}"
sudo pacman -Syu --noconfirm

# Instalar dependencias
echo -e "${AZUL}Instalando dependencias...${NC}"
sudo pacman -S --needed --noconfirm \
    aspell-es firefox-i18n-es-es hunspell-es_es \
    cairo cmake extra-cmake-modules pkg-config dbus gtk3 gtk4 libxcb qt5-base \
    qt6-base base-devel fontconfig freetype2 gcc-libs glibc glu harfbuzz \
    harfbuzz-icu libcups libcurl-gnutls openssl-1.1 qt5-x11extras zlib \
    xdg-utils libxkbcommon-x11 qt5-tools transmission-remote-gtk \
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd nodejs npm cronie \
    obs-studio v4l2loopback-dkms virtualbox virtualbox-host-modules-arch \
    nano conky samba net-tools bluez bluez-utils bluedevil 

# Instalar Rust si no está presente
if ! command -v rustc &> /dev/null; then
    echo -e "${AZUL}Instalando Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Instalar yay si no está presente
if ! command -v yay &> /dev/null; then
    echo -e "${AZUL}Instalando yay...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo -e "${VERDE}¡Instalación de yay completada!${NC}"
fi

# Instalar Julia
clear
echo -e "${AZUL}Instalando Julia...${NC}"
curl -fsSL https://install.julialang.org | sh

# Instalar herramientas de desarrollo y productividad
clear
echo -e "${AZUL}Instalando software adicional...${NC}"
yay -S sublime-text-4 visual-studio-code-bin teams teams-for-linux realvnc-vnc-server p3x-onenote-bin unciv-bin snes9x-git freetube github-cli \
        whatsapp-for-linux \
        --noconfirm

# Configurar Virtualbox
sudo modprobe vboxdrv
sudo usermod -aG vboxusers $USER

# Activar bluetooth
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

echo -e "${VERDE}¡Instalación completada!${NC}"
echo -e "${VERDE}Por favor, reinicie el sistema o cierre sesión y vuelva a iniciarla para aplicar los cambios.${NC}"
echo -e "${VERDE}Para usar Julia, reinicie su terminal o ejecute 'source ~/.bashrc'${NC}"
