#pragma once

#include <QString>
#include <memory>

#ifdef CAELESTIA_HAVE_ICU
#include <unicode/translit.h>
#include <unicode/unistr.h>
#endif

namespace caelestia::services::lyricsromanization {

inline bool available() {
#ifdef CAELESTIA_HAVE_ICU
    return true;
#else
    return false;
#endif
}

// Only transform Devanagari/Gurmukhi runs. Arabic-script Urdu/Shahmukhi and
// surrounding text are never passed to a general-purpose Latin transform.
inline QString romanize(const QString& text) {
#ifdef CAELESTIA_HAVE_ICU
    thread_local std::unique_ptr<icu::Transliterator> devanagari;
    thread_local std::unique_ptr<icu::Transliterator> gurmukhi;
    thread_local std::unique_ptr<icu::Transliterator> ascii;
    auto create = [](const char* id, std::unique_ptr<icu::Transliterator>& transliterator) {
        if (!transliterator) {
            UErrorCode status = U_ZERO_ERROR;
            transliterator.reset(icu::Transliterator::createInstance(id, UTRANS_FORWARD, status));
            if (U_FAILURE(status))
                transliterator.reset();
        }
        return bool(transliterator);
    };
    QString result;
    result.reserve(text.size());
    for (qsizetype i = 0; i < text.size();) {
        const auto script = text.at(i).script();
        if (script != QChar::Script_Devanagari && script != QChar::Script_Gurmukhi) {
            result += text.at(i++);
            continue;
        }
        const qsizetype start = i++;
        while (i < text.size() && text.at(i).script() == script)
            ++i;
        QString word = text.mid(start, i - start);
        auto& transliterator = script == QChar::Script_Devanagari ? devanagari : gurmukhi;
        const char* id = script == QChar::Script_Devanagari ? "Devanagari-Latin" : "Gurmukhi-Latin";
        if (!create(id, transliterator) || !create("Latin-ASCII", ascii)) {
            result += word;
            continue;
        }
        // ICU drops Gurmukhi tippi; retain its nasal sound in readable spelling.
        word.replace(QChar(0x0a70), QStringLiteral("n"));
        auto converted = icu::UnicodeString::fromUTF8(word.toStdString());
        transliterator->transliterate(converted);
        std::string utf8;
        converted.toUTF8String(utf8);
        word = QString::fromStdString(utf8);
        // Suppress only a final inherent schwa, before stripping diacritics so
        // an explicitly written long vowel (ā) is not removed.
        if (word.size() > 1 && word.endsWith(QLatin1Char('a')))
            word.chop(1);
        word.replace(QStringLiteral("c"), QStringLiteral("ch"));
        word.replace(QChar(0x015b), QStringLiteral("sh"));
        word.replace(QChar(0x1e63), QStringLiteral("sh"));
        word.replace(QChar(0x1e41), QStringLiteral("n"));
        converted = icu::UnicodeString::fromUTF8(word.toStdString());
        ascii->transliterate(converted);
        utf8.clear();
        converted.toUTF8String(utf8);
        result += QString::fromStdString(utf8);
    }
    return result;
#else
    return text;
#endif
}

} // namespace caelestia::services::lyricsromanization
