#!/bin/bash

# 명령어 실행 중 오류가 발생하면 즉시 스크립트를 종료합니다
# set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 일반 사용자 확인
if [ "$EUID" = 0 ]; then
    echo -e "${RED}일반 사용자 권한으로 실행해주세요 (sudo를 사용하지 마세요).${NC}"
    exit 1
fi

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}     Arch Linux 한글 환경 설치 스크립트      ${NC}"
echo -e "${YELLOW}         Kime-git 최신 버전 포함            ${NC}"
echo -e "${YELLOW}============================================${NC}"

# GPU Detection and Configuration
echo -e "\n${BLUE}GPU를 감지하고 설정 중...${NC}"

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

# GPU 드라이버 설치
echo -e "${BLUE}GPU 드라이버를 설치 중: ${GPU_TYPE}...${NC}"
sudo pacman -S --noconfirm ${GPU_FXE} ${GPU_COMMON}

# GPU 설정 적용
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

# 시스템 업데이트
echo -e "\n${BLUE}시스템을 업데이트하고 있습니다...${NC}"
sudo pacman -Syu --noconfirm

# 필요한 의존성 패키지들을 설치합니다
echo -e "${BLUE}의존성 패키지들을 설치하고 있습니다...${NC}"
sudo pacman -S --needed --noconfirm \
    noto-fonts-cjk adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts \
    cairo cmake extra-cmake-modules pkg-config dbus gtk3 gtk4 libxcb qt5-base \
    qt6-base base-devel fontconfig freetype2 gcc-libs glibc glu harfbuzz \
    harfbuzz-icu libcups libcurl-gnutls openssl-1.1 qt5-x11extras zlib \
    xdg-utils libxkbcommon-x11 qt5-tools transmission-remote-gtk \
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd nodejs npm cronie \
    obs-studio v4l2loopback-dkms virtualbox virtualbox-host-modules-arch \
    nano conky samba net-tools bluez bluez-utils bluedevil unzip dosfstools \
    texlive-core texlive-bin texlive-latexextra texlive-fontsextra texlive-langenglish texlive-langextra texstudio \
    plasma-wayland-protocols wayland-protocols

# 폰트 설치
echo -e "\n${BLUE}추가 한글 폰트를 설치합니다...${NC}"

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# fonts.tar.gz 다운로드
echo -e "${BLUE}폰트 파일을 다운로드합니다...${NC}"
curl -L "https://github.com/JaewooJoung/a/raw/main/1737776534_fonts.tar.gz" -o fonts.tar.gz

# 압축 해제
echo -e "${BLUE}폰트 파일의 압축을 해제합니다...${NC}"
tar xzf fonts.tar.gz

# 시스템 폰트 디렉토리 생성
sudo mkdir -p /usr/share/fonts/korean-custom

# 폰트 파일 복사
echo -e "${BLUE}폰트를 시스템에 설치합니다...${NC}"
sudo cp -r ./*.ttf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.TTF /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.otf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.OTF /usr/share/fonts/korean-custom/ 2>/dev/null || true

# 폰트 캐시 업데이트
echo -e "${BLUE}폰트 캐시를 업데이트합니다...${NC}"
sudo fc-cache -f -v

# 임시 디렉토리 정리
cd
rm -rf "$TEMP_DIR"

# Rust가 설치되어 있지 않다면 설치합니다
if ! command -v rustc &> /dev/null; then
    echo -e "\n${BLUE}Rust를 설치하고 있습니다...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# yay가 설치되어 있지 않다면 설치합니다
if ! command -v yay &> /dev/null; then
    echo -e "\n${BLUE}yay를 설치하고 있습니다...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo -e "${GREEN}yay 설치가 완료되었습니다!${NC}"
fi

# Julia 설치 (juliaup을 통해)
clear
echo -e "\n${BLUE}Julia를 설치하는 중...${NC}"
curl -fsSL https://install.julialang.org | sh

# Naver Whale 설치
clear
echo -e "\n${BLUE}Naver Whale을 설치하는 중...${NC}"
yay -S naver-whale-stable --noconfirm

# 한글 오피스 설치 
clear
echo -e "\n${BLUE}한글 오피스를 설치하는 중...${NC}"
yay -S hoffice ttf-d2coding --noconfirm

# sublime visual-studio-code-bin 등 여러 프로그램 설치
clear
echo -e "\n${BLUE}내가 잘쓰는 여러가지 설치하는 중...${NC}"
yay -S sublime-text-4 visual-studio-code-bin teams teams-for-linux realvnc-vnc-server p3x-onenote-bin unciv-bin snes9x-git freetube github-cli \
        whatsapp-for-linux epson-inkjet-printer-escpr freetuxtv yt-dlp mullvad-browser-bin \
        --noconfirm

# 기존 kime 설치를 제거합니다
echo -e "\n${BLUE}기존 kime 설치를 제거하고 있습니다...${NC}"
sudo pacman -Rns kime kime-bin --noconfirm 2>/dev/null || true
yay -Rns kime-git kime-git-debug --noconfirm 2>/dev/null || true

# 충돌하는 파일 삭제
echo -e "${BLUE}충돌하는 파일을 정리합니다...${NC}"
sudo rm -f /usr/lib/debug/usr/bin/kime-*.debug 2>/dev/null || true
sudo rm -f /usr/lib/debug/usr/lib/gtk-3.0/3.0.0/immodules/im-kime.so.debug 2>/dev/null || true
sudo rm -f /usr/lib/debug/usr/lib/gtk-4.0/4.0.0/immodules/libkime-gtk4.so.debug 2>/dev/null || true
sudo rm -f /usr/lib/debug/usr/lib/libkime_engine.so.debug 2>/dev/null || true
sudo rm -f /usr/lib/debug/usr/lib/qt/plugins/platforminputcontexts/libkimeplatforminputcontextplugin.so.debug 2>/dev/null || true
sudo rm -f /usr/lib/debug/usr/lib/qt6/plugins/platforminputcontexts/libkimeplatforminputcontextplugin.so.debug 2>/dev/null || true
rm -rf ~/.config/kime 2>/dev/null || true

# kime-git을 설치합니다 (Qt6 문제 해결된 최신 버전)
echo -e "\n${BLUE}kime-git을 설치하고 있습니다 (Qt6 문제 해결 버전)...${NC}"
yay -S --noconfirm kime-git

# kime 설정 디렉토리 생성
echo -e "${BLUE}kime 설정을 준비합니다...${NC}"
mkdir -p ~/.config/kime

# KDE 최적화된 kime 설정 파일 생성
echo -e "${BLUE}KDE 최적화된 kime 설정 파일을 생성합니다...${NC}"
cat > ~/.config/kime/config.yaml << 'EOL'
# Kime Configuration for KDE Plasma
# 저장 위치: ~/.config/kime/config.yaml

daemon:
  modules:
    - Wayland      # KDE Wayland 세션용
    - Xim          # 레거시 X11 앱 지원
    - Indicator    # 시스템 트레이 아이콘

indicator:
  icon_color: Black      # Black, White, Colorful 중 선택
  icon_type: tray        # tray, panel, both
  show_animated: true    # 전환시 애니메이션 효과

log:
  global_level: INFO     # DEBUG, INFO, WARN, ERROR 중 선택

# KDE Plasma 특화 설정
plasma:
  enabled: true
  virtual_keyboard: true
  kwin_integration: true

engine:
  translation_layer: null
  default_category: Latin   # 시작시 영어 모드
  global_category_state: false
  
  # 전역 단축키 (간소화)
  global_hotkeys:
    # 한/영 키 (대부분의 키보드)
    Hangul:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    # Windows/Super + Space (맥 사용자 습관용)
    Super-Space:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    # Esc 키로 항상 영어 모드
    Esc:
      behavior: !Switch Latin
      result: Bypass

  # 한글 모드 특수 단축키
  category_hotkeys:
    Hangul:
      # 한자 변환
      ControlR:
        behavior: !Mode Hanja
        result: Consume
      HangulHanja:
        behavior: !Mode Hanja
        result: Consume
      F9:
        behavior: !Mode Hanja
        result: ConsumeIfProcessed

  # 특수 모드 단축키
  mode_hotkeys:
    Hanja:
      Enter:
        behavior: Commit
        result: ConsumeIfProcessed
      Tab:
        behavior: Commit
        result: ConsumeIfProcessed
      Up:
        behavior: !PrevPage
        result: ConsumeIfProcessed
      Down:
        behavior: !NextPage
        result: ConsumeIfProcessed

  # 폰트 설정
  candidate_font: "Noto Sans CJK KR 12"
  xim_preedit_font:
    - "Noto Sans CJK KR"
    - 15.0

  # 라틴(영문) 설정
  latin:
    layout: Qwerty
    preferred_direct: true    # 직접 입력 모드 선호
    auto_commit: true         # 자동 커밋

  # 한글 설정
  hangul:
    layout: dubeolsik          # 두벌식
    word_commit: false         # 단어 단위 커밋
    auto_reorder: true         # 자동 자소 재배열
    preedit_johab: Needed      # 조합형 프리에딧
    
    # 고급 한글 옵션
    addons:
      all:
        - ComposeChoseongSsang  # 쌍자음 합성
        - ComposeJungseongSsang # 쌍모음 합성
      
      dubeolsik:
        - TreatJongseongAsChoseong  # 종성을 초성으로 처리

# Wayland 관련 설정 (KDE Wayland 기본)
wayland:
  use_virtual_keyboard: true
  text_input_v1: true
  text_input_v3: true
  input_method_v2: true

# GTK/Qt 통합
gtk:
  im_module: true
  use_system_theme: true

qt:
  input_method: true
  use_system_theme: true

# 앱별 설정
app_profile:
  # 터미널은 항상 직접 입력 모드
  - class: ^(org\.kde\.konsole|gnome-terminal.*)$
    engine:
      default_category: Latin
      global_category_state: true
  
  # 게임은 IME 비활성화
  - class: .*(steam|game).*
    daemon:
      modules: []
EOL

# Hancom Office 관련 디렉토리 설정 (호환성 유지)
HNCDIR="/opt/hnc"
HNCCONTEXT="/opt/hnc/hoffice11/Bin/qt/plugins/platforminputcontexts"
sudo mkdir -p "${HNCCONTEXT}" 2>/dev/null || true

# kime Qt 플러그인 다운로드 및 설치 (Hoffice용)
echo -e "${BLUE}Hoffice용 kime Qt 플러그인을 설치합니다...${NC}"
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"
curl -s -o libkime-qt-5.11.3.so -fL 'https://github.com/Riey/kime/releases/latest/download/libkime-qt-5.11.3.so' 2>/dev/null || true
if [ -f "libkime-qt-5.11.3.so" ]; then
    sudo install -Dm755 libkime-qt-5.11.3.so "${HNCCONTEXT}/libkime-qt-5.11.3.so" 2>/dev/null || true
fi
cd
rm -rf "${TEMP_DIR}"

# 환경 변수 설정
echo -e "\n${BLUE}환경 변수를 설정합니다...${NC}"

# .bash_profile 설정
touch ~/.bash_profile
cat > ~/.bash_profile << 'EOL'
# Kime Input Method Settings
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime

# KDE Plasma Settings
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=KDE
export SAL_USE_VCLPLUGIN=gtk3

# Wayland/X11 Session Detection
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export WAYLAND_DISPLAY=wayland-0
    export CLUTTER_BACKEND=wayland
    export SDL_VIDEODRIVER=wayland
    export MOZ_ENABLE_WAYLAND=1
else
    export CLUTTER_BACKEND=x11
    export SDL_VIDEODRIVER=x11
fi

# Locale Settings
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Rust/Cargo
export PATH="$HOME/.cargo/bin:$PATH"

# Julia
export PATH="$HOME/.juliaup/bin:$PATH"
EOL

# .xprofile 설정 (X11 세션용)
touch ~/.xprofile
cat > ~/.xprofile << 'EOL'
# X11 Session Settings
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=KDE
export SAL_USE_VCLPLUGIN=gtk3
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
EOL

# 자동 시작에 kime를 추가합니다
echo -e "${BLUE}kime를 자동 시작 목록에 추가합니다...${NC}"
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kime.desktop << 'EOL'
[Desktop Entry]
Type=Application
Name=Kime Input Method
Comment=Korean Input Method Editor
Exec=/usr/bin/kime
Icon=input-keyboard
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOL

# KDE Plasma 가상 키보드 통합 설정
echo -e "${BLUE}KDE Plasma 가상 키보드 통합을 설정합니다...${NC}"
if command -v kwriteconfig5 &> /dev/null; then
    kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kwin.VirtualKeyboard --key Layout "org.kde.plasma.keyboard.kime" 2>/dev/null || true
fi

# systemd user 서비스 설정
echo -e "${BLUE}systemd 사용자 서비스를 설정합니다...${NC}"
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/kime.service << 'EOL'
[Unit]
Description=Korean Input Method Editor
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=dbus
BusName=im.kime.Daemon
ExecStart=/usr/bin/kime
Restart=on-failure
RestartSec=3
Environment="GTK_IM_MODULE=kime"
Environment="QT_IM_MODULE=kime"
Environment="XMODIFIERS=@im=kime"
Environment="LANG=ko_KR.UTF-8"

[Install]
WantedBy=graphical-session.target
EOL

# 설치 확인
echo -e "\n${BLUE}설치 확인 중...${NC}"
if command -v juliaup &> /dev/null; then
    echo -e "${GREEN}✓ Julia(juliaup)가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${YELLOW}⚠ Julia 설치에 문제가 있을 수 있습니다.${NC}"
fi

if yay -Qi naver-whale-stable &> /dev/null; then
    echo -e "${GREEN}✓ Naver Whale이 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${YELLOW}⚠ Naver Whale 설치에 문제가 있을 수 있습니다.${NC}"
fi

if yay -Qi hoffice &> /dev/null; then
    echo -e "${GREEN}✓ 한글 오피스가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${YELLOW}⚠ 한글 오피스 설치에 문제가 있을 수 있습니다.${NC}"
fi

if pacman -Qi kime-git &> /dev/null; then
    echo -e "${GREEN}✓ kime-git이 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${RED}✗ kime-git 설치에 실패했습니다.${NC}"
fi

# kime 서비스 활성화 및 시작
echo -e "\n${BLUE}kime 서비스를 시작합니다...${NC}"
systemctl --user daemon-reload
systemctl --user enable kime.service
systemctl --user start kime.service

# kime 확인
if command -v kime-check &> /dev/null; then
    echo -e "\n${BLUE}kime 상태 확인:${NC}"
    kime-check | head -20
fi

# Virtualbox 초기설정 
echo -e "\n${BLUE}VirtualBox 설정 중...${NC}"
sudo modprobe vboxdrv 2>/dev/null || true
sudo usermod -aG vboxusers $USER

# bluetooth 켜기
echo -e "${BLUE}Bluetooth 서비스 시작 중...${NC}"
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

# 로케일 설정
echo -e "${BLUE}한글 로케일 설정 중...${NC}"
echo "LANG=ko_KR.UTF-8" | sudo tee -a /etc/locale.conf
sudo locale-gen

# 최종 메시지
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}         설치가 완료되었습니다!              ${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "\n${YELLOW}다음 단계:${NC}"
echo -e "1. 시스템을 ${GREEN}재시작${NC}하거나 로그아웃 후 다시 로그인하세요"
echo -e "2. kime 입력기가 자동으로 시작됩니다"
echo -e "3. ${GREEN}한/영${NC} 키 또는 ${GREEN}Win+Space${NC}로 한영 전환"
echo -e "4. 시스템 트레이에 kime 아이콘이 표시됩니다"
echo -e "5. 환경 변수 적용을 위해 터미널을 재시작하세요"
echo -e "\n${YELLOW}문제 해결:${NC}"
echo -e "- kime-check 명령어로 상태 확인"
echo -e "- systemctl --user status kime 로 서비스 상태 확인"
echo -e "- ~/.config/kime/config.yaml 파일로 설정 조정"
echo -e "\n${GREEN}즐거운 한글 입력 되세요! 😊${NC}"
