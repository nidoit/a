# Arch Linux 네트워크 설치 가이드 (ISO 없이 설치하기)

> USB나 CD/DVD 없이 네트워크만으로 Arch Linux를 설치하는 방법을 초보자도 따라할 수 있도록 자세히 설명합니다.

---

## 목차

1. [방법 1: 기존 리눅스에서 Arch Linux 설치 (Bootstrap)](#방법-1-기존-리눅스에서-arch-linux-설치-bootstrap)
2. [방법 2: netboot.xyz를 이용한 네트워크 부팅](#방법-2-netbootxyz를-이용한-네트워크-부팅)
3. [방법 3: PXE 서버를 이용한 네트워크 설치](#방법-3-pxe-서버를-이용한-네트워크-설치)

---

## 사전 준비

어떤 방법이든 아래 사항을 먼저 확인하세요.

- **유선 인터넷 연결** (설치 중 대용량 다운로드가 필요합니다)
- **UEFI 모드** 가 BIOS에서 활성화되어 있는지 확인
- **중요 데이터 백업 완료**

---

## 방법 1: 기존 리눅스에서 Arch Linux 설치 (Bootstrap)

> 이미 Ubuntu, Fedora 등 다른 리눅스가 설치되어 있을 때, 그 안에서 Arch Linux를 설치하는 방법입니다. USB가 전혀 필요 없습니다.

### 1단계: 설치 대상 디스크 확인

현재 사용 중인 리눅스에서 터미널을 엽니다.

```bash
lsblk
```

출력 예시:
```
NAME   SIZE TYPE MOUNTPOINTS
sda    500G disk
├─sda1   1G part /boot/efi
├─sda2   4G part [SWAP]
└─sda3 495G part /
sdb    250G disk              ← Arch를 설치할 디스크
```

> **주의**: Arch를 설치할 디스크(`sdb`)와 현재 OS가 있는 디스크(`sda`)가 **다른 디스크**여야 합니다. 같은 디스크에 설치하려면 별도의 파티션이 필요합니다.

### 2단계: Bootstrap 파일 다운로드

```bash
# 작업 디렉토리 생성
cd /tmp

# Arch Linux Bootstrap 파일 다운로드
# 미러 목록: https://archlinux.org/download/
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst
```

> **미러 선택 팁**: 한국에서는 아래 미러가 빠릅니다.
> - `https://mirror.premi.st/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst`
> - `https://ftp.lanet.kr/pub/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst`

### 3단계: Bootstrap 압축 해제

```bash
# zstd 설치 (Ubuntu/Debian의 경우)
sudo apt install zstd

# Fedora의 경우
# sudo dnf install zstd

# 압축 해제
sudo tar xf archlinux-bootstrap-x86_64.tar.zst -C /tmp
```

### 4단계: 미러 설정

```bash
# 미러 목록 편집
sudo nano /tmp/root.x86_64/etc/pacman.d/mirrorlist
```

아래 내용을 파일 맨 위에 추가하세요 (한국 미러):
```
Server = https://mirror.premi.st/archlinux/$repo/os/$arch
Server = https://ftp.lanet.kr/pub/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
```

> **nano 편집기 사용법**: 화살표 키로 이동, 텍스트 입력 후 `Ctrl+O`로 저장, `Ctrl+X`로 종료

### 5단계: Bootstrap 환경 진입

```bash
# Bootstrap 환경으로 진입
sudo /tmp/root.x86_64/bin/arch-chroot /tmp/root.x86_64/
```

성공하면 프롬프트가 바뀝니다:
```
[root@yourhostname /]#
```

### 6단계: pacman 키링 초기화

```bash
pacman-key --init
pacman-key --populate archlinux
```

> 이 과정이 1~2분 걸릴 수 있습니다. 끝날 때까지 기다려주세요.

### 7단계: 설치 대상 디스크 파티션 나누기

```bash
# 디스크 목록 확인
lsblk
```

설치할 디스크를 확인한 뒤 (예: `/dev/sdb`):

```bash
# 기존 파티션 테이블 삭제하고 새로 만들기
# ⚠️ 경고: 해당 디스크의 모든 데이터가 삭제됩니다!
sgdisk -Z /dev/sdb
sgdisk -o /dev/sdb
```

파티션 3개를 생성합니다:

```bash
# 1번: EFI 파티션 (1GB)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" /dev/sdb

# 2번: 스왑 파티션 (RAM 크기에 맞게 조절, 예: 4GB)
sgdisk -n 2:0:+4G -t 2:8200 -c 2:"Swap" /dev/sdb

# 3번: 루트 파티션 (나머지 전체)
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" /dev/sdb
```

> **스왑 크기 가이드**:
> - RAM 8GB 이하 → RAM과 동일한 크기
> - RAM 8~64GB → RAM의 절반
> - RAM 64GB 이상 → 32GB

생성된 파티션을 확인합니다:

```bash
lsblk /dev/sdb
```

출력 예시:
```
NAME   SIZE TYPE
sdb    250G disk
├─sdb1   1G part    ← EFI
├─sdb2   4G part    ← Swap
└─sdb3 245G part    ← Root
```

### 8단계: 파티션 포맷

```bash
# EFI 파티션 (FAT32)
mkfs.fat -F 32 /dev/sdb1

# 스왑 파티션
mkswap /dev/sdb2

# 루트 파티션 (ext4)
mkfs.ext4 /dev/sdb3
```

### 9단계: 파티션 마운트

```bash
# 루트 파티션 마운트
mount /dev/sdb3 /mnt

# EFI 파티션 마운트
mkdir -p /mnt/boot
mount /dev/sdb1 /mnt/boot

# 스왑 활성화
swapon /dev/sdb2
```

### 10단계: 기본 시스템 설치

```bash
# pacman 데이터베이스 동기화
pacman -Sy

# 기본 시스템 설치
pacstrap /mnt base linux linux-firmware base-devel \
    networkmanager vim sudo bash-completion \
    git curl wget man-db openssh
```

> 이 과정은 인터넷 속도에 따라 5~15분 정도 걸립니다.

#### CPU에 맞는 마이크로코드도 함께 설치하세요:

```bash
# Intel CPU인 경우
pacstrap /mnt intel-ucode

# AMD CPU인 경우
pacstrap /mnt amd-ucode
```

> **내 CPU 확인 방법**: `cat /proc/cpuinfo | grep "model name" | head -1`

### 11단계: fstab 생성

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

제대로 생성되었는지 확인:

```bash
cat /mnt/etc/fstab
```

3개의 파티션(root, boot, swap)이 보여야 합니다.

### 12단계: 새 시스템으로 진입

```bash
arch-chroot /mnt
```

### 13단계: 시간대 설정

```bash
# 한국 시간대 설정
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# 하드웨어 시계 동기화
hwclock --systohc

# 시간 자동 동기화 활성화
systemctl enable systemd-timesyncd
```

### 14단계: 한국어 로케일 설정

```bash
# locale.gen 파일 편집
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

# 로케일 생성
locale-gen

# 기본 언어 설정
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
```

### 15단계: 호스트명 설정

원하는 컴퓨터 이름을 정합니다 (예: `myarch`):

```bash
# 호스트명 설정
echo "myarch" > /etc/hostname

# hosts 파일 설정
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   myarch.localdomain myarch
EOF
```

### 16단계: 사용자 설정

```bash
# 루트 비밀번호 설정
passwd
# → 비밀번호를 두 번 입력하세요 (화면에 표시되지 않습니다)

# 일반 사용자 생성 (예: myuser)
useradd -m -G wheel,audio,video,storage -s /bin/bash myuser

# 사용자 비밀번호 설정
passwd myuser

# sudo 권한 부여
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
```

### 17단계: 부트로더 설치

```bash
# systemd-boot 설치
bootctl install

# 로더 설정
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

# 부트 엔트리 생성
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/sdb3) rw quiet
EOF
```

> **AMD CPU 사용자**: `initrd  /intel-ucode.img` 줄을 `initrd  /amd-ucode.img` 로 바꾸세요.

### 18단계: 네트워크 활성화

```bash
systemctl enable NetworkManager
```

### 19단계: 데스크톱 환경 설치 (선택)

원하는 데스크톱 환경을 선택하여 설치합니다:

```bash
# KDE Plasma (추천)
pacman -S --noconfirm plasma-meta konsole dolphin sddm
systemctl enable sddm

# 또는 GNOME
# pacman -S --noconfirm gnome gnome-tweaks gdm
# systemctl enable gdm

# 또는 XFCE (가벼움)
# pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
# systemctl enable lightdm
```

### 20단계: 한국어 입력기 설치

```bash
# Xorg 설치 (그래픽 환경에 필요)
pacman -S --noconfirm xorg xorg-server

# 한국어 폰트 설치
pacman -S --noconfirm noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts
```

### 21단계: 설치 완료 및 재부팅

```bash
# initramfs 생성
mkinitcpio -P

# chroot 환경 나가기
exit

# 파티션 마운트 해제
umount -R /mnt

# 재부팅
reboot
```

> **재부팅 전 BIOS 설정**:
> 1. 재부팅 시 BIOS 진입 (보통 F2, F12, DEL 키)
> 2. Secure Boot 비활성화
> 3. UEFI 모드 확인
> 4. 부팅 순서에서 Arch를 설치한 디스크를 1순위로 설정

---

## 방법 2: netboot.xyz를 이용한 네트워크 부팅

> netboot.xyz는 아주 작은 부팅 파일(약 1MB)만으로 네트워크에서 다양한 OS를 설치할 수 있는 도구입니다.

### 1단계: netboot.xyz 부팅 파일 다운로드

다른 컴퓨터에서 아래 파일을 USB에 복사합니다:

| BIOS 유형 | 다운로드 파일 |
|-----------|-------------|
| UEFI | `netboot.xyz.efi` |
| Legacy BIOS | `netboot.xyz.kpxe` |

공식 사이트: https://netboot.xyz/downloads/

> USB에 전체 ISO를 넣는 게 아니라 **1MB짜리 파일 하나만** 복사하면 됩니다.

### 2단계: UEFI 쉘에서 부팅

#### 방법 A: USB에서 직접 실행

```
1. USB를 FAT32로 포맷합니다
2. USB에 EFI/BOOT/ 폴더를 만듭니다
3. netboot.xyz.efi 파일을 EFI/BOOT/BOOTX64.EFI 로 이름을 바꿔서 복사합니다
4. USB로 부팅합니다
```

#### 방법 B: 기존 EFI 파티션에 복사

이미 리눅스나 Windows가 있다면:

```bash
# 리눅스에서
sudo cp netboot.xyz.efi /boot/EFI/netboot/netboot.xyz.efi

# BIOS에서 부팅 항목에 netboot.xyz.efi 를 추가
sudo efibootmgr --create --disk /dev/sda --part 1 \
    --label "netboot.xyz" --loader '\EFI\netboot\netboot.xyz.efi'
```

### 3단계: Arch Linux 선택

netboot.xyz가 부팅되면 메뉴가 나타납니다:

```
1. "Linux Network Installs" 선택
2. "Arch Linux" 선택
3. 자동으로 Arch Linux 설치 환경이 네트워크에서 다운로드됩니다
4. 이후 일반적인 Arch 설치 과정 진행 (방법 1의 7단계부터)
```

> **유선 인터넷이 반드시 연결되어 있어야 합니다.** WiFi는 이 단계에서 사용할 수 없습니다.

---

## 방법 3: PXE 서버를 이용한 네트워크 설치

> 같은 네트워크에 있는 다른 컴퓨터를 서버로 사용하여, 설치 대상 컴퓨터에 USB 없이 Arch Linux를 설치합니다.

### 필요한 것

- **서버 컴퓨터**: 리눅스가 설치된 컴퓨터 (Ubuntu, Fedora, 기존 Arch 등)
- **클라이언트 컴퓨터**: Arch를 설치할 컴퓨터
- **유선 네트워크**: 두 컴퓨터가 같은 네트워크에 연결

### 서버 설정

#### 1단계: 필요한 패키지 설치

```bash
# Ubuntu/Debian
sudo apt install dnsmasq nfs-kernel-server

# Arch Linux
sudo pacman -S dnsmasq nfs-utils

# Fedora
sudo dnf install dnsmasq nfs-utils
```

#### 2단계: Arch Linux ISO 다운로드 및 마운트

```bash
cd /tmp

# ISO 다운로드
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# 마운트 디렉토리 생성
sudo mkdir -p /srv/arch

# ISO 마운트
sudo mount -o loop archlinux-x86_64.iso /srv/arch
```

#### 3단계: TFTP 디렉토리 준비

```bash
# TFTP 루트 디렉토리 생성
sudo mkdir -p /srv/tftp

# 부팅에 필요한 파일 복사
sudo cp /srv/arch/arch/boot/x86_64/vmlinuz-linux /srv/tftp/
sudo cp /srv/arch/arch/boot/x86_64/initramfs-linux.img /srv/tftp/
```

#### 4단계: dnsmasq 설정

먼저 서버의 IP 주소를 확인합니다:

```bash
ip addr show
# eth0 또는 enp0s3 등의 인터페이스에서 inet 뒤의 주소를 확인
# 예: 192.168.1.10
```

설정 파일을 만듭니다:

```bash
sudo cat > /etc/dnsmasq.d/pxe.conf <<EOF
# 네트워크 인터페이스 (ip addr show 에서 확인한 인터페이스 이름)
interface=eth0

# DHCP 범위 설정
dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,12h

# UEFI 부팅 설정
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,netboot.xyz.efi

# TFTP 서버 활성화
enable-tftp
tftp-root=/srv/tftp

# NFS 서버 주소 (서버의 IP 주소로 변경하세요)
dhcp-option=17,/srv/arch
EOF
```

> **중요**: `interface=eth0` 부분을 실제 네트워크 인터페이스 이름으로 바꾸세요. `ip addr show` 명령어로 확인할 수 있습니다.

#### 5단계: NFS 공유 설정

```bash
# NFS 공유 추가
echo "/srv/arch *(ro,sync,no_subtree_check)" | sudo tee -a /etc/exports

# NFS 서버 시작
sudo systemctl restart nfs-server
sudo exportfs -a
```

#### 6단계: 기존 DHCP 서버 비활성화

> **⚠️ 매우 중요**: 공유기(라우터)의 DHCP 서버가 켜져 있으면 충돌합니다.
> 1. 공유기 관리 페이지 접속 (보통 192.168.1.1)
> 2. DHCP 서버 비활성화
> 3. 또는 dnsmasq에서 `dhcp-range` 대신 `dhcp-host` 로 특정 MAC만 지정

#### 7단계: dnsmasq 시작

```bash
# 기존 dnsmasq 중지 후 재시작
sudo systemctl stop dnsmasq
sudo systemctl start dnsmasq

# 상태 확인
sudo systemctl status dnsmasq
```

### 클라이언트 설정 (Arch를 설치할 컴퓨터)

#### 8단계: 네트워크 부팅

```
1. 컴퓨터를 켭니다
2. BIOS/UEFI 설정 진입 (보통 F2, F12, DEL)
3. 부팅 순서에서 "Network Boot" 또는 "PXE Boot" 를 1순위로 설정
4. 저장하고 재부팅
5. 네트워크에서 자동으로 Arch Linux 설치 환경이 로드됩니다
```

> 화면에 `DHCP...` 또는 `PXE boot` 메시지가 나타나면 정상입니다. 잠시 기다려주세요.

#### 9단계: Arch Linux 설치 진행

네트워크 부팅이 성공하면 Arch Linux 라이브 환경이 로드됩니다.
이후 **방법 1의 7단계(파티션 나누기)**부터 동일하게 진행하면 됩니다.

---

## 설치 후 한국어 환경 마무리

어떤 방법으로 설치하든, 재부팅 후 이 저장소의 한국어 스크립트로 나머지 설정을 완료할 수 있습니다:

```bash
# 로그인 후 터미널에서 실행
curl -O https://nidoit.github.io/a/ak.sh && chmod +x ak.sh && bash ak.sh
```

이 스크립트가 자동으로 처리하는 것:
- GPU 드라이버 설치 (Intel / AMD / NVIDIA 자동 감지)
- 한국어 입력기(Kime) 설치 및 설정
- 한국어 폰트 설치
- 개발 도구 설치

---

## 문제 해결

### "부팅이 안 돼요"

| 증상 | 해결 방법 |
|------|----------|
| 검은 화면만 나옴 | BIOS에서 Secure Boot 비활성화 |
| "No bootable device" | BIOS에서 부팅 순서 확인, UEFI 모드 확인 |
| GRUB 에러 | `bootctl install` 다시 실행 |
| 커널 패닉 | fstab의 UUID/PARTUUID 확인 |

### "인터넷이 안 돼요"

```bash
# NetworkManager 상태 확인
systemctl status NetworkManager

# 활성화되지 않았다면
sudo systemctl enable --now NetworkManager

# 유선 연결 확인
nmcli device status

# WiFi 연결
nmcli device wifi list
nmcli device wifi connect "WiFi이름" password "비밀번호"
```

### "한글이 깨져요"

```bash
# 로케일 확인
locale

# ko_KR.UTF-8이 아니면 다시 설정
sudo echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
sudo locale-gen
echo "LANG=ko_KR.UTF-8" | sudo tee /etc/locale.conf

# 재부팅
reboot
```

### "pacman이 작동하지 않아요"

```bash
# 키링 재초기화
sudo pacman-key --init
sudo pacman-key --populate archlinux

# 미러 갱신
sudo pacman -Sy archlinux-keyring
sudo pacman -Syu
```

---

## 방법별 비교

| | Bootstrap (방법 1) | netboot.xyz (방법 2) | PXE (방법 3) |
|---|---|---|---|
| USB 필요 여부 | 불필요 (기존 리눅스 필요) | 최소 USB (1MB) | 완전 불필요 |
| 난이도 | 중간 | 쉬움 | 어려움 |
| 필요 장비 | 현재 리눅스 PC | 유선 인터넷 | 서버 PC + 유선 네트워크 |
| 인터넷 | 필수 | 필수 | 필수 |
| 적합한 상황 | 듀얼 부팅, 교체 설치 | USB가 거의 없을 때 | 여러 대 동시 설치 |
