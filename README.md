# DocOCR

---

Bu proje, fatura, fiş gibi görsel belgelerden OCR (Optik Karakter Tanıma) kullanarak tarih, tutar, belge numarası gibi yapılandırılmış bilgileri çıkarmayı amaçlar. Birden fazla OCR motorunu destekleyerek ve **Büyük Dil Modeli (LLM) ile çıkarım yeteneklerini güçlendirerek** farklı senaryolarda en iyi sonucu elde etmenize yardımcı olur.

This project aims to extract structured information such as date, total amount, and document number from visual documents like invoices and receipts using OCR (Optical Character Recognition). It supports multiple OCR engines and **enhances extraction capabilities with a Large Language Model (LLM)** to help you get the best results in different scenarios.

## Özellikler (Features)

- **Çoklu OCR Motoru Desteği (Multiple OCR Engine Support):**
  - Tesseract, EasyOCR ve PaddleOCR motorlarını kullanır. İsteğe bağlı olarak Keras-OCR da kullanılabilir.
  - Uses Tesseract, EasyOCR, and PaddleOCR engines. Keras-OCR can also be used optionally.
- **Gelişmiş Bilgi Çıkarımı (Advanced Information Extraction):**
  - **Regex ile Temel Çıkarım:** Belgelerden tarih, toplam tutar ve belge numarası gibi önemli alanları düzenli ifadelerle tespit eder.
    - Detects important fields from documents like date, total amount, and document number using regular expressions.
  - **LLM (Google Gemini) ile Akıllı Çıkarım:** OCR'dan elde edilen metinleri ve regex bulgularını bir Büyük Dil Modeli'ne (Google Gemini) göndererek daha bağlamsal, doğru ve esnek bilgi çıkarımı yapar. Bu, özellikle karmaşık veya standart dışı belge formatlarında üstün sonuçlar sağlar.
    - Sends OCR-extracted text and regex findings to a Large Language Model (Google Gemini) for more contextual, accurate, and flexible information extraction. This provides superior results, especially for complex or non-standard document formats.
- **Yapılandırılmış Veri Çıkarımı (Structured Data Extraction):**
  - Belgelerden tarih, toplam tutar, belge numarası ve satıcı adı gibi önemli alanları tespit eder.
  - Detects important fields from documents like date, total amount, document number, and vendor name.
- **Esnek Çıktı Formatı (Flexible Output Format):**
  - Çıkarılan tüm verileri (hem regex hem de LLM sonuçları) ve ham metinleri merkezi bir JSON dosyasında saklar.
  - Stores all extracted data (both regex and LLM results) and raw text in a central JSON file.
- **Görsel İşaretleme (Visual Annotation):**
  - Tespit edilen metinleri kaynak görüntü üzerinde kutucuklarla işaretleyerek görselleştirir.
  - Visualizes detected text by drawing bounding boxes on the source image.
- **Platform Bağımsız Kurulum (Platform-Independent Setup):**
  - Farklı Linux dağıtımları (Debian/Ubuntu, Fedora, Arch) için otomatik kurulum betiği sunar.
  - Provides an automatic setup script for different Linux distributions (Debian/Ubuntu, Fedora, Arch).

## Kurulum (Installation)

Projeyi çalıştırmak için öncelikle gerekli bağımlılıkları kurmanız gerekmektedir.

To run the project, you first need to install the necessary dependencies.

### Otomatik Kurulum (Linux Dağıtımları için - Automatic Setup for Linux)

Proje kök dizininde bulunan `install.sh` betiği, sisteminizi algılayarak (Debian/Ubuntu, Fedora, Arch tabanlı) gerekli sistem paketlerini ve Python kütüphanelerini bir sanal ortam (`ocr_env`) içine kurmaya çalışacaktır.

The `install.sh` script in the project's root directory will try to detect your system (Debian/Ubuntu, Fedora, Arch based) and install the necessary system packages and Python libraries into a virtual environment (`ocr_env`).

1. Terminali açın ve proje dizinine gidin.
   Open a terminal and go to the project directory.
   
   ```bash
   cd /projenizin/bulundugu/dizin
   ```
2. Betiğe çalıştırma izni verin.
   Give the script execution permission.
   
   ```bash
   chmod +x install.sh
   ```
3. Betiği çalıştırın.
   Run the script.
   
   ```bash
   ./install.sh
   ```
   
   Betik, `sudo` yetkisi gerektiren sistem paketlerini kurarken sizden şifrenizi isteyebilir.
   The script may ask for your password when installing system packages that require `sudo` privileges.

**Not (Note):** Eğer `install.sh` betiği sisteminizi doğru algılayamazsa veya Fedora tabanlı bir sistemde sorun yaşarsanız, alternatif olarak `install_fedora.sh` (varsa) betiğini kullanabilirsiniz veya manuel kurulum adımlarını izleyebilirsiniz.
If the `install.sh` script cannot detect your system correctly or if you have issues on a Fedora-based system, you can alternatively use the `install_fedora.sh` script (if available) or follow the manual installation steps.

### Manuel Kurulum (Manual Installation)

Eğer `install.sh` betiğini kullanmak istemiyorsanız veya farklı bir işletim sistemi kullanıyorsanız, aşağıdaki adımları izleyerek manuel kurulum yapabilirsiniz.

If you don't want to use the `install.sh` script or if you are using a different operating system, you can follow these steps for manual installation.

**1. Sistem Bağımlılıkları (System Dependencies):**

Aşağıdaki sistem genelinde kurulu olmalıdır:
The following should be installed system-wide:

- **Python 3** (Önerilen sürüm: 3.11. Python 3.12+ ile TensorFlow/Keras-OCR uyumluluk sorunları yaşanabilir.)
  - Python 3 (Recommended version: 3.11. TensorFlow/Keras-OCR compatibility issues may occur with Python 3.12+.)
- **Tesseract OCR Engine** (ve Türkçe dil paketi - and Turkish language pack)
  - Debian/Ubuntu: `sudo apt-get install tesseract-ocr tesseract-ocr-tur`
  - Fedora: `sudo dnf install tesseract tesseract-langpack-tur`
  - Arch Linux: `sudo pacman -S tesseract tesseract-data-tur`
  - Diğer Sistemler: Tesseract OCR'ın resmi web sitesinden kurulum talimatlarını takip edin.
    Other Systems: Follow the installation instructions from the official Tesseract OCR website.
- **Geliştirme Araçları (Development Tools):**
  - C/C++ derleyicisi, make, cmake.
    C/C++ compiler, make, cmake.
  - Debian/Ubuntu: `sudo apt-get install build-essential cmake python3-dev`
  - Fedora: `sudo dnf install gcc-c++ make cmake python3-devel`
  - Arch Linux: `sudo pacman -S base-devel cmake python`
- **OpenCV Bağımlılıkları (OpenCV Dependencies):**
  - Debian/Ubuntu: `sudo apt-get install libopencv-dev libjpeg-dev libpng-dev libtiff-dev libwebp-dev libopenjp2-7-dev`
  - Fedora: `sudo dnf install opencv-devel libjpeg-turbo-devel libpng-devel libtiff-devel libwebp-devel openjpeg2-devel`
  - Arch Linux: `sudo pacman -S opencv libjpeg-turbo libpng libtiff libwebp openjpeg2`
- **Diğer Gerekli Kütüphaneler (Other Necessary Libraries):** (EasyOCR ve Pillow için - For EasyOCR and Pillow)
  - Debian/Ubuntu: `sudo apt-get install zlib1g-dev liblcms2-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev`
  - Fedora: `sudo dnf install zlib-devel lcms2-devel freetype-devel harfbuzz-devel fribidi-devel`
  - Arch Linux: `sudo pacman -S zlib lcms2 freetype2 harfbuzz fribidi`

**2. Python Sanal Ortamı (Python Virtual Environment):**

Bağımlılıkları projenize özel tutmak için bir sanal ortam oluşturmanız şiddetle tavsiye edilir.
It is highly recommended to create a virtual environment to keep dependencies specific to your project.

```bash
python3 -m venv ocr_env
```

**3. Sanal Ortamı Aktifleştirme (Activate the Virtual Environment):**

```bash
source ocr_env/bin/activate
```

**4. Python Kütüphanelerini Yükleme (Install Python Libraries):**

Sanal ortam aktifken aşağıdaki komutu çalıştırın:
With the virtual environment activated, run the following command:

```bash
pip install --upgrade pip
pip install Pillow pytesseract easyocr opencv-python numpy paddlepaddle paddleocr google-generativeai
# İsteğe bağlı Keras-OCR için (Optional for Keras-OCR):
# pip install keras-ocr tensorflow # (veya torch)
```

**5. Google Gemini API Anahtarı (Google Gemini API Key):**

LLM ile çıkarım özelliğini kullanmak için bir Google Gemini API anahtarına ihtiyacınız olacak.
To use the LLM extraction feature, you will need a Google Gemini API key.

1. Google AI Studio ([https://aistudio.google.com/](https://aistudio.google.com/)) üzerinden bir API anahtarı alın.
   Obtain an API key from Google AI Studio.

2. Anahtarı doğrudan `main.py` dosyasına ekleyin
   You can add the key directly to the `main.py` file 
   
   ****GOOGLE_API_KEY = "API-KEY"**** 

## Kullanım (Usage)

1. **Giriş Görsellerini Hazırlayın (Prepare Input Images):**
   Proje kök dizininde `input` adında bir klasör oluşturun (eğer yoksa). İşlemek istediğiniz fatura, fiş vb. görselleri (`.jpg`, `.png` formatında) bu klasörün içine kopyalayın.
   Create a folder named `input` in the project's root directory (if it doesn't exist). Copy your invoice, receipt, etc. images (in `.jpg`, `.png` format) into this folder.
2. **Sanal Ortamı Aktifleştirin (Activate the Virtual Environment):**
   Sanal ortam oluşturduysanız ve o an aktif değilse, aktifleştirin:
   If you created a virtual environment and it's not currently active, activate it:
   
   ```bash
   source ocr_env/bin/activate
   ```
3. **Ana Betiği Çalıştırın (Run the Main Script):**
   Proje kök dizinindeyken aşağıdaki komutu çalıştırın:
   While in the project's root directory, run the following command:
   
   ```bash
   python main.py
   ```
4. **Çıktıları İnceleyin (Examine the Outputs):**
   - **JSON Veri Dosyası (JSON Data File):** İşlem tamamlandığında, çıkarılan tüm bilgiler (`ham metin`, `regex sonuçları`, `LLM sonuçları`) `output_data/extracted_data.json` dosyasına kaydedilecektir.
     When processing is complete, all extracted information (`raw text`, `regex results`, `LLM results`) will be saved to the `output_data/extracted_data.json` file.
   - **İşaretlenmiş Görseller (Annotated Images):**
     Tespit edilen metinlerin etrafına kutucuklar çizilmiş görseller, `output_annotated` klasörüne `dosyaadı_ocrmodeli_annotated.png` formatında kaydedilecektir.
     Images with bounding boxes drawn around the detected text will be saved in the `output_annotated` folder in the format `filename_ocrmodel_annotated.png`.

## Yapılandırma (Configuration)

`main.py` dosyasının başındaki bazı değişkenleri projenizin ihtiyaçlarına göre düzenleyebilirsiniz:
You can edit some variables at the beginning of the `main.py` file according to your project's needs:

- `TESSERACT_LANG`, `EASYOCR_LANG`, `PADDLEOCR_LANG`: Kullanılacak OCR motorları için dil kodları.
  Language codes for the OCR engines to be used.
- `GOOGLE_API_KEY`: Eğer ortam değişkeni olarak ayarlamadıysanız, Gemini API anahtarınızı buraya doğrudan girebilirsiniz (güvenlik açısından önerilmez).
  If you haven't set it as an environment variable, you can enter your Gemini API key directly here (not recommended for security reasons).
- `USE_GEMINI`: LLM ile çıkarım özelliğini açıp kapatmak için `True` veya `False` olarak ayarlanabilir. API anahtarı yoksa otomatik olarak `False` olur.
  Can be set to `True` or `False` to enable or disable the LLM extraction feature. It will automatically be `False` if no API key is found.