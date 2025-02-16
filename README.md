# Arch Linux Installation Guide

> ⚠️ **Warning**: Make sure you have backed up all important data before proceeding with the installation.

## Step 1: Connect to WiFi
```bash
station wlan0 connect [name of your wifi]
```

## Step 2: Download and execute the initial installation script
```bash
curl -O https://nidoit.github.io/a/i.sh && chmod +x i.sh && bash i.sh
```

## Step 3: Shutdown the system
```bash
shutdown -h now
```

## Step 4: Enable UEFI in BIOS
Access your computer's BIOS/UEFI settings and ensure UEFI mode is enabled before continuing.

## Step 5: Download and execute the final installation script based on your language

### Korean:
```bash
curl -O https://nidoit.github.io/a/ak.sh && chmod +x ak.sh && bash ak.sh
```

### Chinese:
```bash
curl -O https://nidoit.github.io/a/ac.sh && chmod +x ac.sh && bash ac.sh
```

### Swedish:
```bash
curl -O https://nidoit.github.io/a/as.sh && chmod +x as.sh && bash as.sh
```

### Spanish:
```bash
curl -O https://nidoit.github.io/a/ae.sh && chmod +x ae.sh && bash ae.sh
```
