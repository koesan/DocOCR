import os
import json
import re
import cv2
from PIL import Image
import pytesseract
import easyocr
import numpy as np
import google.generativeai as genai 

# Gemini API Yapılandırması 
GOOGLE_API_KEY = "API-KEY" #--> APİ anahtarını girin
USE_GEMINI = False 

if GOOGLE_API_KEY:
    try:
        genai.configure(api_key=GOOGLE_API_KEY)

        safety_settings = [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
        ]
        gemini_model = genai.GenerativeModel('gemini-1.5-flash-latest', safety_settings=safety_settings)
        USE_GEMINI = True
        print("Google Gemini API başarıyla yapılandırıldı ve model yüklendi.")
    except Exception as e:
        print(f"Hata: Google Gemini API yapılandırılamadı: {e}. LLM özelliği devre dışı bırakılacak.")
        gemini_model = None
        USE_GEMINI = False
else:
    print("Bilgi: GOOGLE_API_KEY ortam değişkeni bulunamadı. LLM özelliği devre dışı bırakılacak.")
    gemini_model = None
    USE_GEMINI = False

try:
    import keras_ocr
    KERAS_OCR_AVAILABLE = True
except ImportError:
    keras_ocr = None
    KERAS_OCR_AVAILABLE = False
    print("Bilgi: keras-ocr kütüphanesi bulunamadı veya TensorFlow/PyTorch kurulu değil. Keras-OCR motoru atlanacaktır.")

PADDLEOCR_AVAILABLE = False
PaddleOCR = None
try:
    from paddleocr import PaddleOCR
    PADDLEOCR_AVAILABLE = True
except ImportError:
    print("Bilgi: paddleocr kütüphanesi bulunamadı veya paddlepaddle kurulu değil. PaddleOCR motoru atlanacaktır.")


# Konfigürasyon
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_IMAGE_DIR = os.path.join(BASE_DIR, "input")
OUTPUT_ANNOTATED_DIR = os.path.join(BASE_DIR, "output") 
OUTPUT_DATA_DIR = os.path.join(BASE_DIR, "output")         #
OUTPUT_JSON_FILE = os.path.join(OUTPUT_DATA_DIR, "extracted_data.json")

TESSERACT_LANG = 'tur'
EASYOCR_LANG = ['tr']
PADDLEOCR_LANG = 'tr'

keras_ocr_pipeline = None
if KERAS_OCR_AVAILABLE:
    try:
        keras_ocr_pipeline = keras_ocr.pipeline.Pipeline()
        print("Keras-OCR pipeline başarıyla başlatıldı.")
    except Exception as e:
        print(f"Keras-OCR pipeline başlatılırken hata: {e}. Bu motor devre dışı bırakılıyor.")
        KERAS_OCR_AVAILABLE = False
else:
    keras_ocr_pipeline = None

paddle_ocr_instance = None

def get_paddleocr_instance():
    global paddle_ocr_instance
    if PADDLEOCR_AVAILABLE and paddle_ocr_instance is None:
        try:
            paddle_ocr_instance = PaddleOCR(use_angle_cls=True, lang=PADDLEOCR_LANG, use_gpu=False, show_log=False)
            print(f"PaddleOCR instance başarıyla başlatıldı (Dil: {PADDLEOCR_LANG}).")
        except Exception as e:
            print(f"PaddleOCR başlatılırken hata: {e}. Bu motor devre dışı bırakılıyor.")
            pass 
    return paddle_ocr_instance


# yardımcı Fonksiyonlar
def preprocess_image_for_ocr(image_path):
    img = cv2.imread(image_path)
    if img is None:
        print(f"Hata: {image_path} yüklenemedi (preprocess_image_for_ocr).")
        return None
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return gray

def draw_boxes_on_image(original_image_path, detections, output_path, engine_name):
    try:
        image = cv2.imread(original_image_path)
        if image is None:
            print(f"Hata: {original_image_path} yüklenemedi (draw_boxes_on_image).")
            return

        color_map = {
            "tesseract": (0, 0, 255),
            "easyocr": (0, 255, 0),
            "keras_ocr": (255, 0, 0),
            "paddleocr": (255, 165, 0)
        }
        color = color_map.get(engine_name.lower(), (128, 128, 128))

        for det in detections:
            bbox_data = det.get('bbox')
            if not bbox_data: continue

            try:
                if engine_name == "tesseract" and isinstance(bbox_data, tuple) and len(bbox_data) == 4:
                    x, y, w, h = bbox_data
                    cv2.rectangle(image, (x, y), (x + w, y + h), color, 2)
                elif engine_name == "easyocr" and isinstance(bbox_data, list) and len(bbox_data) == 4 and all(isinstance(n, (int, float)) for n in bbox_data):
                    cv2.rectangle(image, (int(bbox_data[0]), int(bbox_data[1])), (int(bbox_data[2]), int(bbox_data[3])), color, 2)
                elif (engine_name == "keras_ocr" or engine_name == "paddleocr") and \
                     isinstance(bbox_data, list) and len(bbox_data) == 4 and \
                     all(isinstance(coord_pair, list) and len(coord_pair) == 2 for coord_pair in bbox_data):
                    box_points = np.array(bbox_data, dtype=np.int32).reshape((-1, 1, 2))
                    cv2.polylines(image, [box_points], isClosed=True, color=color, thickness=2)
            except Exception as draw_err:
                print(f"    Hata: {engine_name} için kutu çizilirken sorun oluştu: {bbox_data} - {draw_err}")
                continue
        cv2.imwrite(output_path, image)
    except Exception as e:
        print(f"Hata: Görüntü üzerine kutu çizilirken genel bir hata ({original_image_path}, {engine_name}): {e}")


def extract_info_from_text_regex(text): 
    extracted = {"tarih": None, "tutar": None, "belge_no": None, "satici_adi": None} 
    if not text or not isinstance(text, str):
        return extracted

    date_patterns = [
        r'\b(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b',
        r'\b(\d{2,4}[./-]\d{1,2}[./-]\d{1,2})\b',
        r'\b(\d{1,2}\s+(?:Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+\d{2,4})\b'
    ]
    for pattern in date_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            extracted["tarih"] = match.group(1)
            break

    amount_patterns = [
        r'(?:toplam|tutar|yek[üu]n|total|ara\s*toplam|genel\s*toplam)\s*[:\s]*([0-9.,]+)\s*(?:tl|try|eur|usd|€|\$)?',
        r'([0-9.,]+)\s*(?:tl|try|eur|usd|€|\$)\s*(?:toplam|tutar|yek[üu]n|total|genel\s*toplam)',
        r'\b([0-9.,]+)\s*(?:tl|try|eur|usd|€|\$)\b',
        r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+[.,]\d{1,2})\b(?!\s*\d)'
    ]
    best_amount_str = None
    max_numeric_value = 0.0
    for idx, pattern in enumerate(amount_patterns):
        if idx == len(amount_patterns) - 1 and best_amount_str: continue
        matches = re.finditer(pattern, text, re.IGNORECASE)
        for match in matches:
            amount_candidate_str = match.group(1)
            try:
                normalized_amount_str = amount_candidate_str.replace(' ', '').strip()
                normalized_amount_str = re.sub(r'[^\d.,]', '', normalized_amount_str)

                if not normalized_amount_str: continue

                # Ondalık ve binlik ayırıcı normalizasyonu
                if '.' in normalized_amount_str and ',' in normalized_amount_str:
                    if normalized_amount_str.rfind('.') > normalized_amount_str.rfind(','): # 1.234,56 formatı
                        normalized_amount_str = normalized_amount_str.replace('.', '').replace(',', '.')
                    else: # 1,234.56 formatı
                        normalized_amount_str = normalized_amount_str.replace(',', '')
                elif ',' in normalized_amount_str: # Sadece virgül varsa ondalıktır: 123,45
                    normalized_amount_str = normalized_amount_str.replace(',', '.')
                
                # Son nokta/virgülü kontrol et, eğer sondaysa ve tekse kaldır (örneğin "1.250." gibi)
                if normalized_amount_str.endswith('.') or normalized_amount_str.endswith(','):
                    normalized_amount_str = normalized_amount_str[:-1]

                # Çoklu nokta/virgül varsa ve float'a çevrilemiyorsa atla
                if normalized_amount_str.count('.') > 1 :
                     parts = normalized_amount_str.split('.')
                     if len(parts[-1]) != 2 and len(parts) > 2: # 1.2.345 gibi bir durumu yakalamak için
                         normalized_amount_str = "".join(parts[:-1]) + "." + parts[-1] # 12.345 -> 12.345


                if not re.match(r'^\d+(\.\d+)?$', normalized_amount_str): 
                    continue

                numeric_value = float(normalized_amount_str)

                is_keyword_pattern = any(kw in pattern.lower() for kw in ["toplam", "tutar", "yekun", "total"])
                if is_keyword_pattern:
                    if numeric_value > max_numeric_value: 
                        max_numeric_value = numeric_value
                        best_amount_str = amount_candidate_str.strip()
                elif not best_amount_str and 0.01 < numeric_value < 100000000: 
                     if numeric_value > max_numeric_value: 
                        max_numeric_value = numeric_value
                        best_amount_str = amount_candidate_str.strip()
            except ValueError:
                continue
    extracted["tutar"] = best_amount_str

    doc_no_patterns = [
        r'(?:fatura\s*(?:no|numarası)|belge\s*no|fiş\s*no|seri\s*no|işlem\s*no|sipariş\s*no|doküman\s*no|invoice\s*n[o\.]?\.?|receipt\s*no)\s*[:\s]*([a-z0-9\-/]{5,30})',
        r'\b([A-Z]{1,4}[-/]?\s?\d{6,25})\b', 
        r'\b([A-Z0-9]{8,25})\b' 
    ]
    for pattern in doc_no_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            potential_no = match.group(1).upper().strip()
            if "belge_no" not in extracted or not extracted["belge_no"]:
                if not (potential_no.isdigit() and (len(potential_no) > 18 or len(potential_no) < 6)): 
                    if re.search(r'[A-Z]', potential_no) or len(potential_no) >= 7 : 
                        extracted["belge_no"] = potential_no
                        break
            elif len(potential_no) > len(extracted.get("belge_no", "")): 
                 extracted["belge_no"] = potential_no
                 break

    seller_patterns = [
        r'^([A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü\s.,&-]+(?:A\.Ş\.|LTD\.|ŞTİ\.|ANONİM ŞİRKETİ|LİMİTED ŞİRKETİ|CO\.|INC\.))\s*$',
        r'([A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü\s.,&-]{5,50}(?:A\.Ş\.|LTD\.|ŞTİ\.))',
        r'MERKEZİ|ŞUBESİ' 
    ]
    lines = text.split('\n')
    for i, line in enumerate(lines[:5]):
        if extracted["satici_adi"]: break
        if any(skip_kw in line.upper() for skip_kw in ['MERKEZİ', 'ŞUBESİ', 'VERGİ DAİRESİ', 'V.D.']):
            continue
        for pattern in seller_patterns[:-1]:
            match = re.search(pattern, line)
            if match:
                candidate_seller = match.group(1).strip()
                if len(candidate_seller) > 4 and not re.match(r'^\d+\s|NO:|CAD\.|SOK\.', candidate_seller.upper()):
                    extracted["satici_adi"] = candidate_seller
                    break
    return extracted

def extract_info_with_gemini(full_text, regex_extractions):
    if not USE_GEMINI or not gemini_model or not full_text.strip():
        return {"hata": "Gemini kullanılabilir değil veya metin boş."}

    prompt = f"""
    Bir OCR çıktısından Türkçe olarak bilgi çıkarımı yapacaksın. Bu metin bir fatura, fiş veya benzeri bir belgeye ait olabilir.
    Projenin amacı belge üzerindeki şu temel bilgileri doğru bir şekilde tespit etmektir:
    1. Tarih (Belgenin düzenlenme tarihi, GG.AA.YYYY formatına yakın olmalı)
    2. Toplam Tutar (Belgenin KDV dahil veya genel toplam tutarı, sayısal bir değer olmalı, para birimi belirtilirse iyi olur)
    3. Belge Numarası (Fatura No, Fiş No, Seri No gibi benzersiz tanımlayıcı)
    4. Satıcı Adı/Ünvanı (Belgeyi düzenleyen firma veya şahsın adı/ünvanı)
    5. Önemli olabilecek farklı bilgileride çıkar

    Daha önce Regex ile bazı çıkarımlar denendi ve sonuçlar şunlar:
    Tarih (Regex): {regex_extractions.get('tarih', 'Bulunamadı')}
    Tutar (Regex): {regex_extractions.get('tutar', 'Bulunamadı')}
    Belge No (Regex): {regex_extractions.get('belge_no', 'Bulunamadı')}
    Satıcı Adı (Regex): {regex_extractions.get('satici_adi', 'Bulunamadı')}

    Aşağıda OCR ile çıkarılmış tam metin bulunmaktadır:
    --- METIN BAŞLANGICI ---
    {full_text}
    --- METIN SONU ---

    Lütfen yukarıdaki metni dikkatlice incele. Regex sonuçlarını da dikkate alarak, ancak öncelikle metne odaklanarak, aşağıdaki bilgileri JSON formatında çıkar:
    {{
        "tarih": "...",
        "tutar": "...",
        "belge_no": "...",
        "satici_adi": "..."
        Önemli olan farklı bilgiler
    }}
    Eğer bir bilgi metinde kesin olarak bulunamıyorsa, değerini "Bulunamadı" olarak belirt.
    Özellikle tutar alanında, metindeki en olası "Toplam Tutar" değerini bulmaya çalış.
    Satıcı adı genellikle belgenin üst kısımlarında yer alır ve A.Ş., LTD., ŞTİ. gibi ifadeler içerebilir.
    Belge numarası genellikle "Fatura No", "Seri No", "Fiş No" gibi anahtar kelimelerle birlikte bulunur.
    Tarih için GG.AA.YYYY veya benzeri formatları ara.
    JSON çıktısı dışında hiçbir açıklama yapma. Sadece JSON verisini döndür.
    """
    try:
        print("    Gemini'ye istek gönderiliyor...")
        response = gemini_model.generate_content(prompt)
        
        match = re.search(r"```json\s*([\s\S]*?)\s*```", response.text)
        if match:
            json_str = match.group(1)
        else:
            json_str = response.text 

        llm_result = json.loads(json_str)
        print(f"    Gemini Yanıtı (işlenmiş): {llm_result}")
        return llm_result
    except json.JSONDecodeError as e:
        print(f"    Gemini Yanıtı JSON olarak ayrıştırılamadı: {e}")
        print(f"    Ham Yanıt: {response.text if 'response' in locals() else 'Yanıt alınamadı.'}")
        return {"hata": "LLM yanıtı JSON formatında değil", "tarih": "Bulunamadı", "tutar": "Bulunamadı", "belge_no": "Bulunamadı", "satici_adi": "Bulunamadı"}
    except Exception as e:

        if hasattr(response, 'prompt_feedback') and response.prompt_feedback.block_reason:
            print(f"    Gemini isteği engellendi: {response.prompt_feedback.block_reason}")
            print(f"    Engellenme detayları: {response.prompt_feedback.safety_ratings}")
            return {"hata": f"LLM isteği engellendi: {response.prompt_feedback.block_reason}", "tarih": "Bulunamadı", "tutar": "Bulunamadı", "belge_no": "Bulunamadı", "satici_adi": "Bulunamadı"}
        print(f"    Gemini ile bilgi çıkarılırken hata: {e}")
        return {"hata": str(e), "tarih": "Bulunamadı", "tutar": "Bulunamadı", "belge_no": "Bulunamadı", "satici_adi": "Bulunamadı"}

#  OCR Fonksiyonları
def ocr_with_tesseract(image_array_gray, lang='tur'):
    try:
        full_text = pytesseract.image_to_string(image_array_gray, lang=lang)
        data = pytesseract.image_to_data(image_array_gray, lang=lang, output_type=pytesseract.Output.DICT)
        detections = []
        for i in range(len(data['level'])):
            if int(data['conf'][i]) > 20: 
                (x, y, w, h) = (data['left'][i], data['top'][i], data['width'][i], data['height'][i])
                text_segment = data['text'][i]
                if text_segment.strip():
                    detections.append({'text': text_segment, 'bbox': (x, y, w, h), 'confidence': float(data['conf'][i])/100})
        return full_text, detections
    except pytesseract.TesseractNotFoundError:
        print("    Hata: Tesseract kurulu değil veya PATH'e eklenmemiş. Tesseract OCR atlanacak.")
        return "", [] 
    except Exception as e:
        print(f"    Tesseract OCR Hatası: {e}")
        return "", []

def ocr_with_easyocr(image_path_or_array, lang_list=['tr']):
    try:

        reader = easyocr.Reader(lang_list, gpu=False)
        result = reader.readtext(image_path_or_array, detail=1, paragraph=False)
        full_text_parts = []
        detections = []
        for (bbox_coords, text_segment, prob) in result:
            if prob > 0.15: 
                full_text_parts.append(text_segment)
                x_coords = [int(p[0]) for p in bbox_coords]
                y_coords = [int(p[1]) for p in bbox_coords]

                simple_bbox = [min(x_coords), min(y_coords), max(x_coords), max(y_coords)]
                detections.append({'text': text_segment, 'bbox': simple_bbox, 'confidence': prob})
        full_text = "\n".join(full_text_parts)
        return full_text, detections
    except Exception as e:
        print(f"    EasyOCR Hatası: {e}")
        return "", []

def ocr_with_keras_ocr(image_path):
    if not KERAS_OCR_AVAILABLE or keras_ocr_pipeline is None:
        print("    Keras-OCR atlanıyor (kullanılamıyor veya pipeline başlatılamadı).")
        return "", []
    try:
        images_to_process = [keras_ocr.tools.read(image_path)] 
        prediction_groups = keras_ocr_pipeline.recognize(images_to_process)
        full_text_parts = []
        detections = []
        if prediction_groups and prediction_groups[0]: 
            for text_segment, box in prediction_groups[0]:
                full_text_parts.append(text_segment)
                detections.append({'text': text_segment, 'bbox': box.astype(int).tolist()}) 
        full_text = "\n".join(full_text_parts)
        return full_text, detections
    except Exception as e:
        print(f"    Keras-OCR Hatası: {e}")
        return "", []

def ocr_with_paddleocr(image_path_or_array):
    ocr_instance = get_paddleocr_instance()
    if not PADDLEOCR_AVAILABLE or ocr_instance is None:
        print("    PaddleOCR atlanıyor (kullanılamıyor veya instance başlatılamadı).")
        return "", []
    try:
        result = ocr_instance.ocr(image_path_or_array, cls=True)
        full_text_parts = []
        detections = []

        if result and result[0] is not None: 
            actual_results = result[0] 
            for line_info in actual_results:

                if line_info and len(line_info) == 2:
                    box_points_float = line_info[0]
                    text_data = line_info[1]      
                    
                    text_segment = text_data[0]
                    confidence = text_data[1]

                    if confidence > 0.3: 
                        full_text_parts.append(text_segment)
                        box_points_int = [[int(p[0]), int(p[1])] for p in box_points_float]
                        detections.append({'text': text_segment, 'bbox': box_points_int, 'confidence': confidence})
        full_text = "\n".join(full_text_parts)
        return full_text, detections
    except Exception as e:
        print(f"    PaddleOCR Hatası: {e}")
        return "", []

# Ana İşlem
def main():
    all_extracted_data = {}
    if os.path.exists(OUTPUT_JSON_FILE):
        try:
            with open(OUTPUT_JSON_FILE, 'r', encoding='utf-8') as f:
                all_extracted_data = json.load(f)
            print(f"Mevcut veriler {OUTPUT_JSON_FILE} dosyasından yüklendi.")
        except json.JSONDecodeError:
            print(f"Uyarı: {OUTPUT_JSON_FILE} dosyası okunamadı veya bozuk, sıfırdan oluşturulacak.")
            all_extracted_data = {}

    ocr_engine_configs = {
        "tesseract": {"function": ocr_with_tesseract, "input_type": "gray_array", "args": [TESSERACT_LANG]},
        "easyocr": {"function": ocr_with_easyocr, "input_type": "path_or_bgr_array", "args": [EASYOCR_LANG]},
    }

    if PADDLEOCR_AVAILABLE:
        ocr_engine_configs["paddleocr"] = {"function": ocr_with_paddleocr, "input_type": "path_or_bgr_array", "args": []}
    else:
        print("Bilgi: PaddleOCR motoru kullanılamadığı için yapılandırmaya eklenmedi.")

    if KERAS_OCR_AVAILABLE and keras_ocr_pipeline is not None:
        ocr_engine_configs["keras_ocr"] = {"function": ocr_with_keras_ocr, "input_type": "path", "args": []}
    else:
        print("Bilgi: Keras-OCR motoru kullanılamadığı için yapılandırmaya eklenmedi.")


    image_files = [f for f in os.listdir(INPUT_IMAGE_DIR) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
    if not image_files:
        print(f"'{INPUT_IMAGE_DIR}' klasöründe işlenecek resim bulunamadı.")
        print(f"Lütfen fatura/fiş görsellerinizi '{INPUT_IMAGE_DIR}' klasörüne ekleyin.")
        return

    print(f"\nToplam {len(image_files)} adet resim işlenecek...")

    for image_file in image_files:
        image_path = os.path.join(INPUT_IMAGE_DIR, image_file)
        base_filename = os.path.splitext(image_file)[0]
        print(f"\n--- {image_file} İşleniyor ---")

        original_cv_image = cv2.imread(image_path)
        if original_cv_image is None:
            print(f"    Hata: {image_file} yüklenemedi, atlanıyor.")
            continue
        gray_cv_image = cv2.cvtColor(original_cv_image, cv2.COLOR_BGR2GRAY)

        for engine_name, config in ocr_engine_configs.items():
            print(f"  Motor: {engine_name.upper()}")
            ocr_function = config["function"]
            input_type = config["input_type"]
            additional_args = config["args"]

            ocr_input = None
            if input_type == "path":
                ocr_input = image_path
            elif input_type == "gray_array":
                ocr_input = gray_cv_image
            elif input_type == "path_or_bgr_array":
                ocr_input = image_path

            full_text, detections = "", []
            try:
                full_text, detections = ocr_function(ocr_input, *additional_args)
            except Exception as e_ocr:
                print(f"    {engine_name.upper()} OCR sırasında genel hata: {e_ocr}")
                full_text, detections = "", [] 

            entry_key = f"{base_filename}_{engine_name}"
            
            if not full_text or not full_text.strip():
                print(f"    -> {engine_name.upper()} metin çıkaramadı.")
                regex_extracted_fields = extract_info_from_text_regex("")
            else:
                print(f"    -> {engine_name.upper()} tarafından çıkarılan metin ({len(full_text)} karakter).")
                regex_extracted_fields = extract_info_from_text_regex(full_text)
                print(f"    -> Regex Çıkarılan Alanlar: {regex_extracted_fields}")

            # LLM ile çıkarım 
            llm_extracted_fields = {"hata": "LLM kullanılmadı veya hata oluştu."} 
            if USE_GEMINI and full_text and full_text.strip():
                print(f"    -> Gemini ile ek bilgi çıkarımı deneniyor...")
                llm_extracted_fields = extract_info_with_gemini(full_text, regex_extracted_fields)
                print(f"    -> LLM Çıkarılan Alanlar: {llm_extracted_fields}")
            elif not USE_GEMINI:
                 print(f"    -> LLM (Gemini) atlandı (yapılandırılmadı).")
            elif not full_text or not full_text.strip():
                 print(f"    -> LLM (Gemini) atlandı (OCR metni boş).")


            all_extracted_data[entry_key] = {
                "kaynak_dosya": image_file,
                "ocr_motoru": engine_name,
                "tam_metin": full_text.strip() if full_text else "",
                "cikarilan_alanlar_regex": regex_extracted_fields,
                "cikarilan_alanlar_llm": llm_extracted_fields, 
                "detections_count": len(detections),
                "annotated_image": None
            }

            if detections:
                annotated_image_filename = f"{base_filename}_{engine_name}_annotated.png"
                annotated_image_path = os.path.join(OUTPUT_ANNOTATED_DIR, annotated_image_filename)
                draw_boxes_on_image(image_path, detections, annotated_image_path, engine_name)
                all_extracted_data[entry_key]["annotated_image"] = annotated_image_filename
                print(f"    -> İşaretlenmiş resim: {annotated_image_path}")
            else:
                print(f"    -> {engine_name.upper()} için kutucuk bilgisi bulunamadı.")

    try:
        with open(OUTPUT_JSON_FILE, 'w', encoding='utf-8') as f:
            json.dump(all_extracted_data, f, ensure_ascii=False, indent=4)
        print(f"\n== Tüm çıkarılan veriler başarıyla {OUTPUT_JSON_FILE} dosyasına kaydedildi. ==")
    except Exception as e:
        print(f"Hata: JSON dosyası yazılırken sorun oluştu: {e}")

if __name__ == "__main__":
    if PADDLEOCR_AVAILABLE:
        get_paddleocr_instance() 

    main()