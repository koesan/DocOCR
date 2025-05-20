#!/bin/bash

# Hata durumunda betiği sonlandır
set -e

echo "OCR Projesi Kurulum Betiği Başlatılıyor (OCRopus Hariç)..."
echo "----------------------------------------------------"

# İşletim sistemi ve paket yöneticisi tespiti
PACKAGE_MANAGER=""
UPDATE_CMD=""
INSTALL_CMD=""

# Temel sistem paketleri + Tesseract + OpenCV bağımlılıkları
# OCRopus bağımlılıkları (swig, leptonica vs.) çıkarılabilir eğer başka bir şey için gerekmiyorsa,
# ancak Tesseract veya OpenCV için dolaylı olarak gerekebilecekleri için şimdilik bırakılabilirler
# veya daha dikkatli bir analizle sadece OCRopus'a özel olanlar çıkarılabilir.
# Şimdilik genel bağımlılıkları koruyalım, zararı olmaz.
SYSTEM_PACKAGES_DEBIAN_BASE="python3-dev python3-pip python3-venv gcc g++ make cmake git tesseract-ocr tesseract-ocr-tur libopencv-dev libjpeg-dev libpng-dev zlib1g-dev libtiff5-dev liblcms2-dev libwebp-dev libopenjp2-7-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev swig libleptonica-dev libicu-dev libpango1.0-dev libsm6 libxext6 libxrender-dev libscipy-dev"
SYSTEM_PACKAGES_FEDORA_BASE="python3-devel python3-pip gcc-c++ make cmake git tesseract tesseract-langpack-tur opencv-devel libjpeg-turbo-devel libpng-devel zlib-devel libtiff-devel lcms2-devel libwebp-devel openjpeg2-devel freetype-devel harfbuzz-devel fribidi-devel swig leptonica-devel libicu-devel pango-devel libSM libXext libXrender-devel"
SYSTEM_PACKAGES_ARCH_BASE="python python-pip python-virtualenv gcc make cmake git tesseract tesseract-data-tur opencv libjpeg-turbo libpng zlib libtiff lcms2 libwebp openjpeg2 freetype2 harfbuzz fribidi swig leptonica icu pango libsm libxext libxrender python-scipy"

# PyOCR için Cuneiform (isteğe bağlı ama önerilir)
CUNEIFORM_DEBIAN="cuneiform"
CUNEIFORM_FEDORA="cuneiform"
CUNEIFORM_ARCH="cuneiform"

SYSTEM_PACKAGES=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "İşletim sistemi ID'si: $OS_ID"

    if [[ "$OS_ID" == "fedora" ]]; then
        PACKAGE_MANAGER="dnf"
        UPDATE_CMD="sudo dnf check-update --quiet || true"
        INSTALL_CMD="sudo dnf install -y"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_FEDORA_BASE"
        if sudo dnf list available cuneiform &>/dev/null || sudo dnf list installed cuneiform &>/dev/null; then
            SYSTEM_PACKAGES="$SYSTEM_PACKAGES $CUNEIFORM_FEDORA"
            echo "Bilgi: Fedora için Cuneiform paketi kurulacak."
        else
            echo "Bilgi: Cuneiform, Fedora depolarında bulunamadı. PyOCR için Cuneiform motoru kullanılamayabilir."
        fi
        echo "Fedora tabanlı sistem algılandı. Paket yöneticisi: dnf"
    elif [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID" == "linuxmint" || "$OS_ID_LIKE" == *"debian"* ]]; then
        PACKAGE_MANAGER="apt-get"
        UPDATE_CMD="sudo apt-get update -qq"
        INSTALL_CMD="sudo apt-get install -y -qq --no-install-recommends"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_DEBIAN_BASE $CUNEIFORM_DEBIAN"
        echo "Debian/Ubuntu tabanlı sistem algılandı. Paket yöneticisi: apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PACKAGE_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Syyu --noconfirm"
        INSTALL_CMD="sudo pacman -S --noconfirm --needed"
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES_ARCH_BASE $CUNEIFORM_ARCH"
        echo "Arch tabanlı sistem algılandı. Paket yöneticisi: pacman"
    else
        echo "Desteklenmeyen işletim sistemi: $OS_ID."
        echo "Lütfen Tesseract, Cuneiform (isteğe bağlı) ve OpenCV bağımlılıklarını manuel olarak kurun."
    fi
elif command -v dnf &> /dev/null; then
    PACKAGE_MANAGER="dnf"
    UPDATE_CMD="sudo dnf check-update --quiet || true"
    INSTALL_CMD="sudo dnf install -y"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_FEDORA_BASE"
    if sudo dnf list available cuneiform &>/dev/null || sudo dnf list installed cuneiform &>/dev/null; then
        SYSTEM_PACKAGES="$SYSTEM_PACKAGES $CUNEIFORM_FEDORA"
    else
        echo "Bilgi: Cuneiform, Fedora depolarında bulunamadı (dnf ile kontrol edildi)."
    fi
    echo "Paket yöneticisi 'dnf' bulundu (Muhtemelen Fedora tabanlı)."
elif command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt-get"
    UPDATE_CMD="sudo apt-get update -qq"
    INSTALL_CMD="sudo apt-get install -y -qq --no-install-recommends"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_DEBIAN_BASE $CUNEIFORM_DEBIAN"
    echo "Paket yöneticisi 'apt-get' bulundu (Muhtemelen Debian/Ubuntu tabanlı)."
elif command -v pacman &> /dev/null; then
    PACKAGE_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Syyu --noconfirm"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    SYSTEM_PACKAGES="$SYSTEM_PACKAGES_ARCH_BASE $CUNEIFORM_ARCH"
    echo "Paket yöneticisi 'pacman' bulundu (Muhtemelen Arch tabanlı)."
else
    echo "Uygun paket yöneticisi (dnf, apt, pacman) bulunamadı."
    echo "Lütfen Tesseract, Cuneiform (isteğe bağlı) ve OpenCV bağımlılıklarını manuel olarak kurun."
fi

echo "----------------------------------------------------"

# 1. Sistem Bağımlılıklarını Kurma
STEP_COUNT=5 # Toplam adım sayısı OCRopus hariç
CURRENT_STEP=1
echo "[$CURRENT_STEP/$STEP_COUNT] Gerekli sistem paketleri kuruluyor (sudo şifreniz gerekebilir)..."
if [ -n "$PACKAGE_MANAGER" ] && [ -n "$INSTALL_CMD" ] && [ -n "$SYSTEM_PACKAGES" ]; then
    if [ -n "$UPDATE_CMD" ]; then
        echo "Paket listesi güncelleniyor (eğer gerekiyorsa)..."
        eval $UPDATE_CMD
    fi
    echo "Kurulacak/Kontrol Edilecek Sistem Paketleri: $SYSTEM_PACKAGES"
    if eval $INSTALL_CMD $SYSTEM_PACKAGES; then
        echo "Sistem paketleri başarıyla kuruldu veya zaten kuruluydu."
    else
        echo "UYARI: Bazı sistem paketleri kurulurken hata oluştu. Betik devam etmeye çalışacak ama sorunlar yaşanabilir."
        echo "Lütfen yukarıdaki dnf/apt/pacman çıktılarını kontrol edin."
    fi
else
    echo "Sistem paketleri kurulumu atlanıyor (paket yöneticisi veya paket listesi belirlenemedi)."
    echo "Lütfen gerekli bağımlılıkların manuel olarak kurulu olduğundan emin olun."
fi
echo "----------------------------------------------------"

# 2. Python Sanal Ortamı Oluşturma
CURRENT_STEP=$((CURRENT_STEP + 1))
VENV_NAME="ocr_env"
PYTHON_EXECUTABLE="python3"

if ! command -v $PYTHON_EXECUTABLE &> /dev/null; then
    echo "HATA: '$PYTHON_EXECUTABLE' komutu bulunamadı. Lütfen Python 3'ün kurulu olduğundan emin olun."
    exit 1
fi

echo "[$CURRENT_STEP/$STEP_COUNT] Python sanal ortamı '$VENV_NAME', '$PYTHON_EXECUTABLE' kullanılarak oluşturuluyor..."
if [ -d "$VENV_NAME" ]; then
    echo "Sanal ortam '$VENV_NAME' zaten mevcut. Yeniden oluşturulmayacak."
else
    $PYTHON_EXECUTABLE -m venv "$VENV_NAME"
    echo "Sanal ortam '$VENV_NAME' başarıyla oluşturuldu."
fi
echo "----------------------------------------------------"

# 3. Sanal Ortamı Aktifleştirme ve Pip Güncelleme
CURRENT_STEP=$((CURRENT_STEP + 1))
echo "[$CURRENT_STEP/$STEP_COUNT] Sanal ortam '$VENV_NAME' aktifleştiriliyor..."
source "$VENV_NAME/bin/activate"
echo "Sanal ortam aktif. Pip sürümü kontrol ediliyor/yükseltiliyor..."
pip install --upgrade pip
echo "----------------------------------------------------"

# 4. Temel Python Paketlerini Kurma (pip ile)
CURRENT_STEP=$((CURRENT_STEP + 1))
echo "[$CURRENT_STEP/$STEP_COUNT] Temel Python kütüphaneleri (Pillow, Pytesseract, EasyOCR, OpenCV, Numpy, Scipy, PyOCR, PaddleOCR) sanal ortama kuruluyor..."
pip install Pillow
pip install pytesseract
pip install easyocr
pip install opencv-python
pip install numpy
pip install scipy
pip install pyocr
pip install paddlepaddle # CPU için PaddlePaddle. GPU için: pip install paddlepaddle-gpu
pip install paddleocr
pip install google-generativeai
echo "Temel Python kütüphaneleri başarıyla kuruldu."
echo "----------------------------------------------------"

# 5. OCRopus Kurulumu (GitHub'dan) - ŞİMDİLİK ATLANDI / DEVRE DIŞI BIRAKILDI
# OCRopus'un Python 3 ile uyumluluk sorunları nedeniyle bu adım geçici olarak devre dışı bırakılmıştır.
# Python 3 uyumlu bir OCRopus (ocropy) fork'u bulunursa veya orijinal repo güncellenirse bu bölüm tekrar aktif edilebilir.
: <<'OCROPUS_INSTALL_COMMENT'
echo "[X/Y] OCRopus (GitHub'dan) kurulmaya çalışılıyor..."
echo "Bu işlem uzun sürebilir ve sisteminizde derleyici araçları (gcc, g++) ile"
echo "OCRopus bağımlılıklarının (swig, libleptonica, libicu, pango vb.) kurulu olmasını gerektirir."
echo "Eğer bu adımda hata alırsanız, hata mesajlarını kontrol edin ve eksik bağımlılıkları kurun."

OCROPUS_INSTALL_SUCCESS=false
if command -v git &> /dev/null; then
    echo "Geçici bir dizinde OCRopus GitHub reposu klonlanıyor..."
    TEMP_OCROPUS_DIR=$(mktemp -d -t ocropus_install-XXXXXX)
    # Python 3 uyumlu bir fork bulunursa bu URL güncellenmeli:
    if git clone --depth 1 https://github.com/ocropus/ocropy.git "$TEMP_OCROPUS_DIR"; then
        cd "$TEMP_OCROPUS_DIR"
        echo "OCRopus (ocropy) Python kütüphanesi GitHub kaynağından kuruluyor (pip install .)..."
        if pip install .; then
            OCROPUS_INSTALL_SUCCESS=true
            echo "OCRopus (ocropy) GitHub kaynağından başarıyla kuruldu."
        else
            echo "UYARI: OCRopus (ocropy) GitHub kaynağından pip install . ile kurulurken hata oluştu."
        fi
        cd - > /dev/null
    else
        echo "HATA: OCRopus GitHub reposu klonlanamadı. İnternet bağlantınızı ve git URL'sini kontrol edin."
    fi
    echo "Geçici OCRopus klonlama dizini ($TEMP_OCROPUS_DIR) temizleniyor..."
    rm -rf "$TEMP_OCROPUS_DIR"
else
    echo "HATA: 'git' komutu bulunamadı. OCRopus'u GitHub'dan kurmak için 'git' gereklidir."
    echo "Lütfen 'git' kurun (örneğin Debian/Ubuntu: sudo apt install git; Fedora: sudo dnf install git) ve betiği tekrar çalıştırın."
fi

if [ "$OCROPUS_INSTALL_SUCCESS" = false ]; then
    echo "UYARI: OCRopus (ocropy) kurulumu başarısız oldu veya atlandı. OCRopus motoru kullanılamayabilir."
    echo "Lütfen hata mesajlarını inceleyin ve eksik bağımlılıkları kurduktan sonra tekrar deneyin."
    echo "Gerekli sistem kütüphaneleri için betiğin başındaki OCROPUS_DEPS_* listelerine göz atın."
    echo "Alternatif olarak, OCRopus'u manuel olarak kendi dokümantasyonuna göre kurmayı deneyebilirsiniz."
    echo "Yaygın sorunlar Python sürümü uyumsuzlukları veya eksik derleyici/kütüphane bağımlılıkları olabilir."
fi
echo "----------------------------------------------------"
OCROPUS_INSTALL_COMMENT

# Kurulum Tamamlandı Bilgisi
CURRENT_STEP=$((CURRENT_STEP + 1))
echo "[$CURRENT_STEP/$STEP_COUNT] Kurulum tamamlandı (OCRopus hariç)!"
echo ""
echo "ÖNEMLİ NOTLAR:"
echo "----------------------------------------------------"
echo "1. TensorFlow ve Keras-OCR:"
echo "   Bu betik TensorFlow ve Keras-OCR kütüphanelerini otomatik olarak KURMAZ."
echo "   Eğer Keras-OCR motorunu kullanmak istiyorsanız, sanal ortam aktifken manuel olarak kurmanız gerekir:"
echo "   Sanal ortam aktifken: "
echo "     pip install tensorflow  # Veya tensorflow-cpu / tensorflow-gpu (sisteminize uygun olanı seçin)"
echo "     pip install keras-ocr"
echo "   TensorFlow kurulumu sisteminize ve donanımınıza (CPU/GPU) göre değişiklik gösterebilir."
echo "----------------------------------------------------"
echo "2. OCRopus Durumu:"
echo "   OCRopus (ocropy) kurulumu mevcut Python 3 uyumluluk sorunları nedeniyle bu betikte ATLANMIŞTIR."
echo "   Eğer gelecekte OCRopus kullanmak isterseniz, Python 3 uyumlu bir sürümünü/fork'unu bulup manuel olarak"
echo "   sanal ortama kurmanız ve Python kodunuzda ilgili ayarları (OCROPUS_EXECUTABLE, OCROPUS_MODEL_PATH vb.)"
echo "   yapmanız gerekecektir."
echo "----------------------------------------------------"
echo "Kullanmaya başlamak için:"
echo "1. Bu terminal penceresi açıkken sanal ortam ('$VENV_NAME') zaten aktif."
echo "2. Yeni bir terminal açarsanız, önce sanal ortamı tekrar aktifleştirmeniz gerekir:"
echo "   source $VENV_NAME/bin/activate"
echo "3. Ardından Python betiğinizi (örneğin main.py) çalıştırabilirsiniz:"
echo "   python main.py"
echo "4. İşiniz bittiğinde sanal ortamı devre dışı bırakmak için (isteğe bağlı):"
echo "   deactivate"
echo "----------------------------------------------------"

exit 0