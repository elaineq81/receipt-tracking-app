from pathlib import Path


CATALOGS = (
    Path("ReceiptArchive/Resources/Localizable.xcstrings"),
    Path("ReceiptArchive/Resources/InfoPlist.xcstrings"),
)

# English is the source language and covers Apple's English storefront variants.
REQUIRED_LANGUAGES = {
    "ar", "bn", "ca", "zh-Hans", "zh-Hant", "hr", "cs", "da", "nl",
    "fi", "fr", "fr-CA", "de", "el", "gu", "he", "hi", "hu", "id",
    "it", "ja", "kn", "ko", "ms", "ml", "mr", "nb", "or", "pl",
    "pt-BR", "pt-PT", "pa", "ro", "ru", "sk", "sl", "es-MX", "es-ES",
    "sv", "ta", "te", "th", "tr", "uk", "ur", "vi",
}
