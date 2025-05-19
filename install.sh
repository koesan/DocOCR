#!/bin/bash

# Hata durumunda betiği sonlandır
set -e

echo "OCR Projesi Kurulum Betiği Başlatılıyor..."
echo "----------------------------------------------------"

# İşletim sistemi ve paket yöneticisi tespiti
PACKAGE_MANAGER=""
UPDATE_CMD=""
INSTALL_CMD=""
SYSTEM_PACKAGES_DEBIAN="python3-dev python3-pip python3-venv gcc g++ make cmake tesseract-ocr tesseract-ocr-tur libopencv-dev libjpeg-dev libpng-dev zlib1g-dev libtiff5-dev liblcms2-dev libwebp-dev libopenjp2-7-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev"
SYSTEM_PACKAGES_FEDORA="python3-devel python3-pip gcc-c++ make cmake tesseract tesseract-langpack-tur opencv-devel libjpeg-turbo-devel libpng-devel zlib-devel libtiff-devel lcms2-devel libwebp-devel openjpeg2-devel freetype-devel harfbuzz-devel fribidi-devel"
SYSTEM_PACKAGES_ARCH="python python-pip python-virtualenv gcc make cmake tesseract tesseract-data-tur opencv libjpeg-turbo libpng zlib libtiff lcms2 libwebp openjpeg2 freetype2 harfbuzz fribidi"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "İşletim sistemi ID'si: $OS_ID"

    if [[ "$OS_ID" == "fedora" ]]; then
        PACKAGE_MANAGER="dnf"
        UPDATE_CMD="sudo dnf check-update"
        INSTALL_CMD="sudo dnf install -y"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_FEDORA"
        echo "Fedora tabanlı sistem algılandı. Paket yöneticisi: dnf"
    elif [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID" == "linuxmint" || "$OS_ID_LIKE" == *"debian"* ]]; then
        PACKAGE_MANAGER="apt-get"
        UPDATE_CMD="sudo apt-get update"
        INSTALL_CMD="sudo apt-get install -y"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_DEBIAN"
        echo "Debian/Ubuntu tabanlı sistem algılandı. Paket yöneticisi: apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PACKAGE_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Syyu --noconfirm"
        INSTALL_CMD="sudo pacman -S --noconfirm --needed"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_ARCH"
        echo "Arch tabanlı sistem algılandı. Paket yöneticisi: pacman"
    else
        echo "Desteklenmeyen işletim sistemi: $OS_ID. Lütfen gerekli sistem bağımlılıklarını manuel olarak kurun."
    fi
elif command -v dnf &> /dev/null; then
    PACKAGE_MANAGER="dnf"
    UPDATE_CMD="sudo dnf check-update"
    INSTALL_CMD="sudo dnf install -y"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_FEDORA"
    echo "Paket yöneticisi 'dnf' bulundu (Muhtemelen Fedora tabanlı)."
elif command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt-get"
    UPDATE_CMD="sudo apt-get update"
    INSTALL_CMD="sudo apt-get install -y"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_DEBIAN"
    echo "Paket yöneticisi 'apt-get' bulundu (Muhtemelen Debian/Ubuntu tabanlı)."
elif command -v pacman &> /dev/null; then
    PACKAGE_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Syyu --noconfirm"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_ARCH"
    echo "Paket yöneticisi 'pacman' bulundu (Muhtemelen Arch tabanlı)."
else
    echo "Uygun paket yöneticisi (dnf, apt, pacman) bulunamadı."
    echo "Lütfen gerekli sistem bağımlılıklarını manuel olarak kurun."
fi

echo "----------------------------------------------------"

# 1. Sistem Bağımlılıklarını Kurma
if [ -n "$PACKAGE_MANAGER" ] && [ -n "$INSTALL_CMD" ] && [ -n "$SYSTEM_PACKAGES" ]; then
    echo "[1/5] Gerekli sistem paketleri kuruluyor (sudo şifreniz gerekebilir)..."
    if [ -n "$UPDATE_CMD" ]; then
        echo "Paket listesi güncelleniyor..."
        eval $UPDATE_CMD
    fi
    echo "Paketler kuruluyor: $SYSTEM_PACKAGES"
    eval $INSTALL_CMD $SYSTEM_PACKAGES
    echo "Sistem paketleri başarıyla kuruldu veya zaten kuruluydu."
else
    echo "[1/5] Sistem paketleri kurulumu atlanıyor (paket yöneticisi veya paket listesi belirlenemedi)."
    echo "Lütfen gerekli bağımlılıkların manuel olarak kurulu olduğundan emin olun."
fi
echo "----------------------------------------------------"

# 2. Python Sanal Ortamı Oluşturma
VENV_NAME="ocr_env"
# Sistemdeki varsayılan python3 kullanılacak (bu sizin için Python 3.13 olabilir)
PYTHON_EXECUTABLE="python3"

if ! command -v $PYTHON_EXECUTABLE &> /dev/null; then
    echo "HATA: '$PYTHON_EXECUTABLE' komutu bulunamadı. Lütfen Python 3'ün kurulu olduğundan emin olun."
    exit 1
fi

echo "[2/5] Python sanal ortamı '$VENV_NAME', '$PYTHON_EXECUTABLE' kullanılarak oluşturuluyor..."
if [ -d "$VENV_NAME" ]; then
    echo "Sanal ortam '$VENV_NAME' zaten mevcut. Yeniden oluşturulmayacak."
else
    $PYTHON_EXECUTABLE -m venv "$VENV_NAME"
    echo "Sanal ortam '$VENV_NAME' başarıyla oluşturuldu."
fi
echo "----------------------------------------------------"

# 3. Sanal Ortamı Aktifleştirme
echo "[3/5] Sanal ortam '$VENV_NAME' aktifleştiriliyor..."
source "$VENV_NAME/bin/activate"
echo "Sanal ortam aktif."
echo "----------------------------------------------------"

# 4. Python Paketlerini Kurma (pip ile)
echo "[4/5] Gerekli Python kütüphaneleri sanal ortama kuruluyor..."
pip install --upgrade pip

pip install Pillow
pip install pytesseract
pip install easyocr
pip install opencv-python
pip install paddlepaddle # CPU için. GPU için: paddlepaddle-gpu -U
pip install paddleocr
pip install numpy

echo "Python kütüphaneleri başarıyla kuruldu (TensorFlow ve Keras-OCR hariç)."
echo "----------------------------------------------------"

# 5. Kurulum Tamamlandı Bilgisi
echo "[5/5] Kurulum tamamlandı!"
echo ""
echo "Kullanmaya başlamak için:"
echo "1. Bu terminal penceresi açıkken sanal ortam zaten aktif."
echo "2. Yeni bir terminal açarsanız, sanal ortamı tekrar aktifleştirin:"
echo "   source $VENV_NAME/bin/activate"
echo "3. Ardından Python betiğinizi (örneğin main.py) çalıştırabilirsiniz:"
echo "   python main.py"
echo "4. İşiniz bittiğinde sanal ortamı devre dışı bırakmak için:"
echo "   deactivate"
echo "----------------------------------------------------"

exit 0