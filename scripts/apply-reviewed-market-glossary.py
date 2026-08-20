#!/usr/bin/env python3
"""Apply human-reviewed, high-risk ReceiptSure terminology for priority markets."""

import json
from pathlib import Path


UI = Path("ReceiptArchive/Resources/Localizable.xcstrings")
INFO = Path("ReceiptArchive/Resources/InfoPlist.xcstrings")

LANGUAGES = ("fr", "fr-CA", "de", "ja", "ko", "pt-BR", "pt-PT")
RTL_LANGUAGES = ("ar", "he", "ur")

TERMS = {
    "Settings": ("Réglages", "Réglages", "Einstellungen", "設定", "설정", "Configurações", "Definições"),
    "Merchant rules": ("Règles de commerçants", "Règles de commerçants", "Händlerregeln", "加盟店ルール", "판매처 규칙", "Regras de estabelecimentos", "Regras de comerciantes"),
    "Custom categories": ("Catégories personnalisées", "Catégories personnalisées", "Benutzerdefinierte Kategorien", "カスタムカテゴリ", "사용자 지정 카테고리", "Categorias personalizadas", "Categorias personalizadas"),
    "Capture & accuracy": ("Numérisation et précision", "Numérisation et précision", "Erfassung und Genauigkeit", "スキャンと精度", "스캔 및 정확도", "Captura e precisão", "Captura e precisão"),
    "Encrypted backup & restore": ("Sauvegarde chiffrée et restauration", "Sauvegarde chiffrée et restauration", "Verschlüsseltes Backup und Wiederherstellung", "暗号化バックアップと復元", "암호화 백업 및 복원", "Backup criptografado e restauração", "Cópia de segurança encriptada e restauro"),
    "Private iCloud sync": ("Synchronisation iCloud privée", "Synchronisation iCloud privée", "Privater iCloud-Abgleich", "プライベートiCloud同期", "비공개 iCloud 동기화", "Sincronização privada do iCloud", "Sincronização privada do iCloud"),
    "Share receipt": ("Partager le reçu", "Partager le reçu", "Beleg teilen", "レシートを共有", "영수증 공유", "Compartilhar recibo", "Partilhar recibo"),
    "Delete permanently": ("Supprimer définitivement", "Supprimer définitivement", "Dauerhaft löschen", "完全に削除", "영구 삭제", "Excluir permanentemente", "Eliminar permanentemente"),
    "Delete Permanently": ("Supprimer définitivement", "Supprimer définitivement", "Dauerhaft löschen", "完全に削除", "영구 삭제", "Excluir permanentemente", "Eliminar permanentemente"),
    "Currency": ("Devise", "Devise", "Währung", "通貨", "통화", "Moeda", "Moeda"),
    "Tax label": ("Libellé de taxe", "Libellé de taxe", "Steuerbezeichnung", "税ラベル", "세금 항목", "Descrição do imposto", "Designação do imposto"),
    "Evidence status": ("État des preuves", "État des preuves", "Nachweisstatus", "証明ステータス", "증빙 상태", "Status da comprovação", "Estado do comprovativo"),
    "ReceiptSure Proof Pack": ("Dossier de preuves ReceiptSure", "Dossier de preuves ReceiptSure", "ReceiptSure-Nachweispaket", "ReceiptSure証明パック", "ReceiptSure 증빙 패키지", "Pacote de comprovantes ReceiptSure", "Pacote de comprovativos ReceiptSure"),
    "Unlock Pro for %@": ("Débloquer Pro pour %@", "Débloquer Pro pour %@", "Pro für %@ freischalten", "%@でProを購入", "%@에 Pro 잠금 해제", "Desbloquear o Pro por %@", "Desbloquear o Pro por %@"),
    "No secure backup created": ("Aucune sauvegarde sécurisée créée", "Aucune sauvegarde sécurisée créée", "Noch kein sicheres Backup erstellt", "安全なバックアップはまだありません", "아직 보안 백업이 없습니다", "Nenhum backup seguro foi criado", "Ainda não foi criada uma cópia de segurança segura"),
    "ReceiptSure Pro has been restored.": ("ReceiptSure Pro a été restauré.", "ReceiptSure Pro a été restauré.", "ReceiptSure Pro wurde wiederhergestellt.", "ReceiptSure Proが復元されました。", "ReceiptSure Pro가 복원되었습니다.", "O ReceiptSure Pro foi restaurado.", "O ReceiptSure Pro foi restaurado."),
}

INFO_TERMS = {
    "CFBundleDisplayName": ("ReceiptSure",) * 7,
    "CFBundleName": ("ReceiptSure",) * 7,
    "ReceiptSure Secure Backup": ("Sauvegarde sécurisée ReceiptSure", "Sauvegarde sécurisée ReceiptSure", "Sicheres ReceiptSure-Backup", "ReceiptSure安全バックアップ", "ReceiptSure 보안 백업", "Backup seguro do ReceiptSure", "Cópia de segurança segura do ReceiptSure"),
    "NSCameraUsageDescription": (
        "ReceiptSure utilise l’appareil photo pour numériser, détecter et recadrer les reçus que vous choisissez d’enregistrer.",
        "ReceiptSure utilise l’appareil photo pour numériser, détecter et recadrer les reçus que vous choisissez d’enregistrer.",
        "ReceiptSure verwendet die Kamera, um Belege zu scannen, zu erkennen und zuzuschneiden, die du speichern möchtest.",
        "ReceiptSureは、保存するレシートのスキャン、検出、切り抜きにカメラを使用します。",
        "ReceiptSure는 저장할 영수증을 스캔하고 감지하며 자르기 위해 카메라를 사용합니다.",
        "O ReceiptSure usa a câmera para digitalizar, detectar e recortar os recibos que você escolher salvar.",
        "O ReceiptSure utiliza a câmara para digitalizar, detetar e recortar os recibos que optar por guardar.",
    ),
    "NSFaceIDUsageDescription": (
        "ReceiptSure utilise Face ID pour protéger vos reçus et relevés de dépenses stockés localement.",
        "ReceiptSure utilise Face ID pour protéger vos reçus et relevés de dépenses stockés localement.",
        "ReceiptSure verwendet Face ID, um deine lokal gespeicherten Belege und Ausgabendaten zu schützen.",
        "ReceiptSureは、端末内に保存されたレシートと支出記録を保護するためにFace IDを使用します。",
        "ReceiptSure는 기기에 저장된 영수증과 지출 기록을 보호하기 위해 Face ID를 사용합니다.",
        "O ReceiptSure usa o Face ID para proteger seus recibos e registros de despesas armazenados localmente.",
        "O ReceiptSure utiliza o Face ID para proteger os recibos e registos de despesas guardados localmente.",
    ),
}

RTL_TERMS = {
    "Settings": ("الإعدادات", "הגדרות", "ترتیبات"),
    "Merchant rules": ("قواعد التجار", "כללי בתי עסק", "تجارتی اداروں کے قواعد"),
    "Custom categories": ("فئات مخصصة", "קטגוריות מותאמות אישית", "حسبِ ضرورت زمرے"),
    "Capture & accuracy": ("المسح والدقة", "סריקה ודיוק", "اسکین اور درستگی"),
    "Encrypted backup & restore": ("النسخ الاحتياطي المشفر والاستعادة", "גיבוי מוצפן ושחזור", "خفیہ کردہ بیک اپ اور بحالی"),
    "Private iCloud sync": ("مزامنة iCloud الخاصة", "סנכרון iCloud פרטי", "نجی iCloud مطابقت پذیری"),
    "Share receipt": ("مشاركة الإيصال", "שיתוף קבלה", "رسید شیئر کریں"),
    "Delete permanently": ("حذف نهائيًا", "מחיקה לצמיתות", "مستقل طور پر حذف کریں"),
    "Delete Permanently": ("حذف نهائيًا", "מחיקה לצמיתות", "مستقل طور پر حذف کریں"),
    "Currency": ("العملة", "מטבע", "کرنسی"),
    "Tax label": ("تسمية الضريبة", "תווית מס", "ٹیکس کا لیبل"),
    "Evidence status": ("حالة الإثبات", "מצב הראיות", "ثبوت کی حیثیت"),
    "ReceiptSure Proof Pack": ("حزمة إثبات ReceiptSure", "חבילת הוכחות של ReceiptSure", "ReceiptSure ثبوت پیک"),
    "Unlock Pro for %@": ("فتح Pro مقابل %@", "פתיחת Pro תמורת %@", "%@ کے عوض Pro ان لاک کریں"),
    "No secure backup created": ("لم يتم إنشاء نسخة احتياطية آمنة", "טרם נוצר גיבוי מאובטח", "ابھی تک کوئی محفوظ بیک اپ نہیں بنایا گیا"),
    "ReceiptSure Pro has been restored.": ("تمت استعادة ReceiptSure Pro.", "ReceiptSure Pro שוחזר.", "ReceiptSure Pro بحال ہو گیا ہے۔"),
}

RTL_INFO_TERMS = {
    "CFBundleDisplayName": ("ReceiptSure",) * 3,
    "CFBundleName": ("ReceiptSure",) * 3,
    "ReceiptSure Secure Backup": ("نسخة احتياطية آمنة لـ ReceiptSure", "גיבוי מאובטח של ReceiptSure", "ReceiptSure محفوظ بیک اپ"),
    "NSCameraUsageDescription": (
        "يستخدم ReceiptSure الكاميرا لمسح الإيصالات التي تختار حفظها واكتشافها واقتصاصها.",
        "ReceiptSure משתמש במצלמה כדי לסרוק, לזהות ולחתוך קבלות שתבחרו לשמור.",
        "ReceiptSure آپ کی منتخب کردہ رسیدوں کو اسکین، شناخت اور تراشنے کے لیے کیمرہ استعمال کرتا ہے۔",
    ),
    "NSFaceIDUsageDescription": (
        "يستخدم ReceiptSure ‏Face ID لحماية الإيصالات وسجلات النفقات المخزنة محليًا.",
        "ReceiptSure משתמש ב-Face ID כדי להגן על קבלות ורישומי הוצאות המאוחסנים במכשיר.",
        "ReceiptSure مقامی طور پر محفوظ رسیدوں اور اخراجات کے ریکارڈ کی حفاظت کے لیے Face ID استعمال کرتا ہے۔",
    ),
}


def apply(path: Path, translations, languages=LANGUAGES) -> int:
    payload = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for key, values in translations.items():
        entry = payload["strings"][key].setdefault("localizations", {})
        for language, value in zip(languages, values):
            entry[language] = {"stringUnit": {"state": "translated", "value": value}}
            changed += 1
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return changed


changed = apply(UI, TERMS) + apply(INFO, INFO_TERMS)
changed += apply(UI, RTL_TERMS, RTL_LANGUAGES) + apply(INFO, RTL_INFO_TERMS, RTL_LANGUAGES)
print(f"Applied {changed} reviewed priority-market entries.")
