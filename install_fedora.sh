#!/bin/bash

# Hata durumunda betiği sonlandır
set -e

echo "Fedora için OCR Projesi Kurulum Betiği Başlatılıyor..."
echo "----------------------------------------------------"

# 1. Sistem Bağımlılıklarını Kurma
echo "[1/5] Gerekli sistem paketleri kuruluyor (sudo şifreniz gerekebilir)..."
sudo dnf install -y \
    python3-devel \
    python3-pip \
    gcc-c++ \
    make \
    cmake \
    tesseract \
    tesseract-langpack-tur \
    opencv-devel \
    libjpeg-turbo-devel \
    libpng-devel \
    zlib-devel \
    libtiff-devel \
    lcms2-devel \
    libwebp-devel \
    openjpeg2-devel \
    freetype-devel \
    harfbuzz-devel \
    fribidi-devel
echo "Sistem paketleri başarıyla kuruldu veya zaten kuruluydu."
echo "----------------------------------------------------"

# 2. Python Sanal Ortamı Oluşturma
VENV_NAME="ocr_env"
echo "[2/5] Python sanal ortamı '$VENV_NAME' oluşturuluyor..."
if [ -d "$VENV_NAME" ]; then
    echo "Sanal ortam '$VENV_NAME' zaten mevcut. Yeniden oluşturulmayacak."
else
    if command -v python3 &>/dev/null; then
        # Kullandığınız mevcut Python 3 sürümüyle sanal ortam oluşturulacak (örn: Python 3.13)
        python3 -m venv "$VENV_NAME"
        echo "Sanal ortam '$VENV_NAME' başarıyla oluşturuldu."
    else
        echo "HATA: python3 komutu bulunamadı. Lütfen Python 3'ün kurulu olduğundan emin olun."
        exit 1
    fi
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

# Temel OCR ve yardımcı kütüphaneler
pip install Pillow
pip install pytesseract
pip install easyocr
pip install opencv-python

# PaddleOCR ve bağımlılığı (PaddlePaddle CPU)
pip install paddlepaddle # Sadece CPU için. GPU için: paddlepaddle-gpu -U
pip install paddleocr

# Diğerleri (numpy genellikle bağımlılık olarak gelir ama ekleyelim)
pip install numpy

# Keras-OCR ve TensorFlow kurulumu şimdilik atlandı (Python 3.13 uyumluluk sorunu nedeniyle)
# echo "Keras-OCR ve TensorFlow kurulumu Python 3.13 uyumluluk sorunları nedeniyle atlanmıştır."

echo "Python kütüphaneleri başarıyla kuruldu."
echo "----------------------------------------------------"

# 5. Kurulum Tamamlandı Bilgisi
echo "[5/5] Kurulum tamamlandı!"
echo ""
echo "Kullanmaya başlamak için:"
echo "1. Bu terminal penceresi açıkken sanal ortam zaten aktif."
echo "2. Yeni bir terminal açarsanız, sanal ortamı tekrar aktifleştirin:"
echo "   source $VENV_NAME/bin/activate"
echo "3. Ardından Python betiğinizi (örneğin ocr_extractor.py) çalıştırabilirsiniz:"
echo "   python ocr_extractor.py"
echo "4. İşiniz bittiğinde sanal ortamı devre dışı bırakmak için:"
echo "   deactivate"
echo "----------------------------------------------------"

exit 0