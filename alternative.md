# Arch Linux 설치 대안 가이드

> 이 저장소의 스크립트(`i.sh` + `ak.sh` 등) 외에도 Arch Linux를 설치할 수 있는 다양한 방법이 있습니다.

---

## 1. archinstall (공식 가이드 설치 프로그램)

Arch Linux ISO에 기본 포함된 공식 텍스트 기반 가이드 설치 프로그램입니다.

### 사용 방법
```bash
# Arch ISO로 부팅 후 실행
archinstall
```

### 특징
- 메뉴 방식으로 디스크, 데스크톱 환경, 언어 등을 선택 가능
- 프로파일(profile) 시스템으로 데스크톱 환경을 간편하게 설정
- JSON 설정 파일로 저장/불러오기 가능 (반복 설치에 유용)
- 한국어 로케일 설정 지원

### JSON 설정으로 반복 설치
```bash
# 설정을 파일로 저장
archinstall --save /root/my-config.json

# 저장된 설정으로 설치
archinstall --config /root/my-config.json
```

### 장점
- 공식 지원, ISO에 포함되어 별도 다운로드 불필요
- 초보자도 쉽게 사용 가능
- 커스터마이징 자유도 높음

### 단점
- 세부 설정은 수동 설치보다 제한적
- 가끔 버그가 있을 수 있음

---

## 2. 수동 설치 (ArchWiki 공식 가이드)

ArchWiki의 [Installation Guide](https://wiki.archlinux.org/title/Installation_guide)를 따라 한 단계씩 직접 설치하는 방법입니다.

### 주요 과정
```bash
# 1. 파티션 나누기
fdisk /dev/sda
# 또는
gdisk /dev/sda

# 2. 파티션 포맷
mkfs.ext4 /dev/sda3
mkfs.fat -F 32 /dev/sda1
mkswap /dev/sda2

# 3. 마운트
mount /dev/sda3 /mnt
mount --mkdir /dev/sda1 /mnt/boot
swapon /dev/sda2

# 4. 기본 시스템 설치
pacstrap -K /mnt base linux linux-firmware

# 5. fstab 생성
genfstab -U /mnt >> /mnt/etc/fstab

# 6. chroot 진입
arch-chroot /mnt

# 7. 시간대, 로케일, 호스트명 등 설정
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# 8. 부트로더 설치
bootctl install
# 또는
pacman -S grub && grub-install && grub-mkconfig -o /boot/grub/grub.cfg
```

### 장점
- 시스템의 모든 부분을 완전히 이해하고 제어 가능
- 불필요한 패키지 없이 최소 설치 가능
- 리눅스 학습에 최적

### 단점
- 시간이 오래 걸림
- 실수하면 처음부터 다시 해야 할 수 있음

---

## 3. Arch 기반 배포판

Arch Linux의 패키지와 롤링 릴리스 모델을 사용하면서 설치를 쉽게 해주는 배포판들입니다.

### EndeavourOS
- GUI 설치 프로그램(Calamares) 제공
- Arch에 가장 가까운 경험
- 다양한 데스크톱 환경 선택 가능
- 공식 사이트: https://endeavouros.com

```
# USB에 EndeavourOS ISO를 구워서 부팅하면
# 그래픽 설치 마법사가 자동으로 시작됨
```

### Manjaro
- 자체 저장소 사용 (Arch와 별개)
- 하드웨어 감지가 우수
- 안정성 중시 (패키지 업데이트 지연)
- 공식 사이트: https://manjaro.org

### CachyOS
- 성능 최적화에 중점
- x86-64-v3/v4 최적화 빌드 제공
- 게이밍 및 고성능 컴퓨팅에 적합
- 공식 사이트: https://cachyos.org

### Garuda Linux
- 게이밍 지향 배포판
- Btrfs 스냅샷으로 시스템 복구 용이
- 화려한 기본 테마
- 공식 사이트: https://garudalinux.org

---

## 4. archiso로 커스텀 ISO 만들기

자신만의 Arch Linux 설치 ISO를 만들어서 반복적으로 사용할 수 있습니다.

### 설치 및 사용
```bash
# archiso 설치
sudo pacman -S archiso

# 기본 프로파일 복사
cp -r /usr/share/archiso/configs/releng/ ~/my-archiso

# packages.x86_64 파일에 원하는 패키지 추가
echo "firefox" >> ~/my-archiso/packages.x86_64
echo "plasma-meta" >> ~/my-archiso/packages.x86_64

# 커스텀 스크립트 추가 (airootfs/root/ 에 배치)
cp my-setup.sh ~/my-archiso/airootfs/root/

# ISO 빌드
sudo mkarchiso -v -w /tmp/archiso-work -o ~/my-iso ~/my-archiso
```

### 장점
- 완전히 커스터마이징된 설치 미디어 제작 가능
- 여러 컴퓨터에 동일한 환경을 반복 설치 가능
- 오프라인 설치 가능 (패키지를 ISO에 포함)

### 단점
- 설정이 복잡
- ISO 빌드 시간이 오래 걸림

---

## 5. Docker / 가상 머신에서 실행

실제 하드웨어에 설치하지 않고 Arch Linux를 사용하는 방법입니다.

### Docker
```bash
# Arch Linux 공식 Docker 이미지 실행
docker pull archlinux:latest
docker run -it archlinux:latest /bin/bash

# 컨테이너 내부에서 pacman 사용 가능
pacman -Syu
pacman -S vim git
```

### VirtualBox
```bash
# 1. VirtualBox에서 새 가상 머신 생성
#    - 유형: Linux, 버전: Arch Linux (64-bit)
#    - 메모리: 최소 2GB 권장
#    - 디스크: 최소 20GB 권장

# 2. Arch Linux ISO를 가상 광학 드라이브에 마운트

# 3. 일반적인 Arch 설치 과정 진행
#    (이 저장소의 i.sh 스크립트도 사용 가능)
```

### QEMU/KVM
```bash
# 가상 디스크 이미지 생성
qemu-img create -f qcow2 arch.qcow2 20G

# ISO로 부팅하여 설치
qemu-system-x86_64 -enable-kvm -m 4G \
    -cdrom archlinux.iso \
    -drive file=arch.qcow2,format=qcow2 \
    -boot d

# 설치 후 디스크에서 부팅
qemu-system-x86_64 -enable-kvm -m 4G \
    -drive file=arch.qcow2,format=qcow2
```

### 장점
- 기존 OS를 유지하면서 Arch Linux 사용 가능
- 실험 및 학습에 안전
- 스냅샷으로 언제든 되돌리기 가능

### 단점
- 네이티브 대비 성능 저하
- GPU 가속 제한적 (게이밍, 그래픽 작업에 부적합)
- Docker는 데스크톱 환경 사용 불가

---

## 6. WSL (Windows Subsystem for Linux)

Windows에서 Arch Linux를 실행하는 방법입니다.

### 설치 방법
```powershell
# PowerShell (관리자 권한)에서 WSL 활성화
wsl --install

# 재부팅 후, ArchWSL 사용
# https://github.com/yuk7/ArchWSL 에서 다운로드

# 또는 wsldl 사용
# https://github.com/yuk7/wsldl
```

### ArchWSL 설치 후 초기 설정
```bash
# 루트 비밀번호 설정
passwd

# 사용자 생성
useradd -m -G wheel -s /bin/bash myuser
passwd myuser

# sudoers 설정
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# pacman 키링 초기화
pacman-key --init
pacman-key --populate archlinux

# 시스템 업데이트
pacman -Syu
```

### 장점
- Windows와 Linux를 동시에 사용 가능
- 듀얼 부팅 불필요
- 파일 시스템 상호 접근 가능

### 단점
- 완전한 리눅스 환경은 아님 (커널 제한)
- GUI 앱 실행 시 추가 설정 필요 (WSLg)
- 일부 시스템 서비스 사용 불가

---

## 7. PXE 네트워크 부팅 설치

USB 없이 네트워크를 통해 Arch Linux를 설치하는 방법입니다.

### 서버 측 설정
```bash
# TFTP 서버 설치
sudo pacman -S tftp-hpa dnsmasq

# Arch Linux ISO에서 부팅 파일 추출
mount -o loop archlinux.iso /mnt/iso
cp /mnt/iso/arch/boot/x86_64/vmlinuz-linux /srv/tftp/
cp /mnt/iso/arch/boot/x86_64/initramfs-linux.img /srv/tftp/

# dnsmasq 설정 (DHCP + TFTP)
cat > /etc/dnsmasq.conf <<EOF
interface=eth0
dhcp-range=192.168.1.100,192.168.1.200,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/srv/tftp
EOF

# 서비스 시작
sudo systemctl start dnsmasq
```

### 장점
- USB 드라이브 불필요
- 여러 컴퓨터를 동시에 설치 가능
- 서버/데이터센터 환경에 적합

### 단점
- 네트워크 인프라 설정이 필요
- 초기 구성이 복잡

---

## 방법별 비교표

| 방법 | 난이도 | 소요 시간 | 커스터마이징 | 대상 |
|------|--------|-----------|-------------|------|
| 이 저장소 스크립트 | 쉬움 | 짧음 | 중간 | 빠른 설치 원하는 사용자 |
| archinstall | 쉬움 | 짧음 | 중간 | 초보자 |
| 수동 설치 | 어려움 | 길음 | 높음 | 학습 목적 |
| Arch 기반 배포판 | 매우 쉬움 | 짧음 | 낮음 | 편의성 중시 |
| archiso 커스텀 | 어려움 | 길음 | 매우 높음 | 반복 배포 |
| Docker / VM | 쉬움 | 짧음 | 중간 | 테스트/개발 |
| WSL | 쉬움 | 짧음 | 낮음 | Windows 사용자 |
| PXE 네트워크 | 어려움 | 중간 | 높음 | 서버/대량 배포 |
