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

# These strings are the first screen users see in the Settings smoke test.
# They were reviewed together after visual QA exposed mixed-language labels,
# missing spaces, and malformed product copy in several machine drafts.
VISIBLE_LANGUAGES = (
    "ar", "de", "es-ES", "es-MX", "fr", "fr-CA", "he",
    "ja", "ko", "pt-BR", "pt-PT", "ur", "zh-Hans", "zh-Hant",
)

VISIBLE_TERMS = {
    "ReceiptSure Pro": (
        "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro",
        "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro",
        "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro", "ReceiptSure Pro",
        "ReceiptSure Pro", "ReceiptSure Pro",
    ),
    "Unlock Pro — one-time purchase": (
        "فتح Pro — شراء لمرة واحدة", "Pro freischalten — einmaliger Kauf",
        "Desbloquear Pro — compra única", "Desbloquear Pro — compra única",
        "Débloquer Pro — achat unique", "Débloquer Pro — achat unique",
        "פתיחת Pro — רכישה חד-פעמית", "Proを解除 — 1回限りの購入",
        "Pro 잠금 해제 — 일회성 구매", "Desbloquear Pro — compra única",
        "Desbloquear Pro — compra única", "Pro اَن لاک کریں — ایک بار کی خریداری",
        "解锁 Pro — 一次性购买", "解鎖 Pro — 一次購買",
    ),
    "Keep using the free plan, or upgrade once with no subscription.": (
        "استمر في استخدام الخطة المجانية، أو قم بالترقية مرة واحدة من دون اشتراك.",
        "Nutze weiterhin den kostenlosen Plan oder führe ein einmaliges Upgrade ohne Abonnement durch.",
        "Sigue usando el plan gratuito o mejora una sola vez, sin suscripción.",
        "Sigue usando el plan gratuito o mejora una sola vez, sin suscripción.",
        "Continuez avec l’offre gratuite ou passez à Pro une seule fois, sans abonnement.",
        "Continuez avec l’offre gratuite ou passez à Pro une seule fois, sans abonnement.",
        "המשיכו להשתמש בתוכנית החינמית, או שדרגו פעם אחת ללא מנוי.",
        "無料プランを使い続けるか、サブスクリプションなしで一度だけアップグレードできます。",
        "무료 플랜을 계속 사용하거나 구독 없이 한 번만 업그레이드하세요.",
        "Continue usando o plano gratuito ou faça um upgrade único, sem assinatura.",
        "Continue a usar o plano gratuito ou faça uma atualização única, sem subscrição.",
        "مفت پلان استعمال کرتے رہیں، یا سبسکرپشن کے بغیر ایک بار اپ گریڈ کریں۔",
        "继续使用免费计划，或一次性升级，无需订阅。", "繼續使用免費方案，或一次升級，無需訂閱。",
    ),
    "Restore Purchases": (
        "استعادة المشتريات", "Käufe wiederherstellen", "Restaurar compras", "Restaurar compras",
        "Restaurer les achats", "Restaurer les achats", "שחזור רכישות", "購入を復元",
        "구매 복원", "Restaurar compras", "Restaurar compras", "خریداری بحال کریں",
        "恢复购买", "恢復購買",
    ),
    "Your data": (
        "بياناتك", "Ihre Daten", "Tus datos", "Tus datos", "Vos données", "Vos données",
        "הנתונים שלך", "あなたのデータ", "내 데이터", "Seus dados", "Os seus dados",
        "آپ کا ڈیٹا", "你的数据", "你的資料",
    ),
    "Stored on this device": (
        "مخزّن على هذا الجهاز", "Auf diesem Gerät gespeichert", "Guardado en este dispositivo",
        "Guardado en este dispositivo", "Stocké sur cet appareil", "Stocké sur cet appareil",
        "מאוחסן במכשיר זה", "このデバイスに保存", "이 기기에 저장됨",
        "Armazenado neste dispositivo", "Guardado neste dispositivo", "اس ڈیوائس پر محفوظ",
        "存储在此设备上", "儲存在此裝置上",
    ),
    "Receipt images and expense details stay local unless you explicitly enable private iCloud sync.": (
        "تبقى صور الإيصالات وتفاصيل النفقات على الجهاز ما لم تفعّل مزامنة iCloud الخاصة صراحةً.",
        "Belegbilder und Ausgabendetails bleiben auf diesem Gerät, sofern du die private iCloud-Synchronisierung nicht ausdrücklich aktivierst.",
        "Las imágenes de recibos y los detalles de gastos permanecen en el dispositivo, salvo que actives expresamente la sincronización privada con iCloud.",
        "Las imágenes de recibos y los detalles de gastos permanecen en el dispositivo, salvo que actives expresamente la sincronización privada con iCloud.",
        "Les images des reçus et les détails des dépenses restent sur l’appareil, sauf si vous activez explicitement la synchronisation iCloud privée.",
        "Les images des reçus et les détails des dépenses restent sur l’appareil, sauf si vous activez explicitement la synchronisation iCloud privée.",
        "תמונות הקבלות ופרטי ההוצאות נשארים במכשיר, אלא אם מפעילים במפורש סנכרון iCloud פרטי.",
        "レシート画像と支出の詳細は、プライベートiCloud同期を明示的に有効にしない限り、このデバイスに保存されます。",
        "영수증 이미지와 지출 세부 정보는 비공개 iCloud 동기화를 직접 켜지 않는 한 이 기기에만 저장됩니다.",
        "As imagens dos recibos e os detalhes das despesas ficam no dispositivo, a menos que você ative explicitamente a sincronização privada do iCloud.",
        "As imagens dos recibos e os detalhes das despesas ficam no dispositivo, a menos que ative explicitamente a sincronização privada do iCloud.",
        "رسید کی تصاویر اور اخراجات کی تفصیلات اسی ڈیوائس پر رہتی ہیں، جب تک آپ نجی iCloud مطابقت پذیری واضح طور پر فعال نہ کریں۔",
        "收据图像和支出详情会保留在此设备上，除非你明确启用专用 iCloud 同步。",
        "收據影像和支出詳情會保留在此裝置上，除非你明確啟用私人 iCloud 同步。",
    ),
    "Security & continuity": (
        "الأمان والاستمرارية", "Sicherheit und Kontinuität", "Seguridad y continuidad",
        "Seguridad y continuidad", "Sécurité et continuité", "Sécurité et continuité",
        "אבטחה והמשכיות", "セキュリティと継続性", "보안 및 연속성",
        "Segurança e continuidade", "Segurança e continuidade", "سیکیورٹی اور تسلسل",
        "安全与连续性", "安全與連續性",
    ),
    "Require Face ID or passcode": (
        "طلب Face ID أو رمز الدخول", "Face ID oder Code anfordern", "Requerir Face ID o código",
        "Requerir Face ID o código", "Exiger Face ID ou un code", "Exiger Face ID ou un code",
        "דרישת Face ID או קוד גישה", "Face IDまたはパスコードを要求", "Face ID 또는 암호 요구",
        "Exigir Face ID ou código", "Exigir Face ID ou código", "Face ID یا پاس کوڈ درکار",
        "需要 Face ID 或密码", "需要 Face ID 或密碼",
    ),
    "Hide content in app switcher": (
        "إخفاء المحتوى في مبدّل التطبيقات", "Inhalte im App-Umschalter ausblenden",
        "Ocultar contenido en el selector de apps", "Ocultar contenido en el selector de apps",
        "Masquer le contenu dans le sélecteur d’apps", "Masquer le contenu dans le sélecteur d’apps",
        "הסתרת תוכן במחליף היישומים", "Appスイッチャーで内容を隠す", "앱 전환기에서 콘텐츠 가리기",
        "Ocultar conteúdo no seletor de apps", "Ocultar conteúdo no seletor de apps",
        "ایپ سوئچر میں مواد چھپائیں", "在应用切换器中隐藏内容", "在 App 切換器中隱藏內容",
    ),
    "Matters": (
        "المهام", "Vorgänge", "Asuntos", "Asuntos", "Dossiers", "Dossiers", "נושאים",
        "案件", "항목", "Assuntos", "Assuntos", "معاملات", "事项", "事項",
    ),
    "Receipts": (
        "الإيصالات", "Belege", "Recibos", "Recibos", "Reçus", "Reçus", "קבלות",
        "レシート", "영수증", "Recibos", "Recibos", "رسیدیں", "收据", "收據",
    ),
    "Reports": (
        "التقارير", "Berichte", "Informes", "Informes", "Rapports", "Rapports", "דוחות",
        "レポート", "보고서", "Relatórios", "Relatórios", "رپورٹس", "报告", "報告",
    ),
    "Settings": (
        "الإعدادات", "Einstellungen", "Ajustes", "Ajustes", "Réglages", "Réglages", "הגדרות",
        "設定", "설정", "Configurações", "Definições", "ترتیبات", "设置", "設定",
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
changed += apply(UI, VISIBLE_TERMS, VISIBLE_LANGUAGES)
print(f"Applied {changed} reviewed priority-market entries.")
