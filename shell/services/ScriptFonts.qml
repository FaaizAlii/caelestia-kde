pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    readonly property list<string> families: Qt.fontFamilies()
    readonly property string urduFamily: urduFont.status === FontLoader.Ready ? urduFont.name : firstAvailable(["Jameel Noori Nastaleeq", "Noto Nastaliq Urdu", "Gulzar", "Noto Naskh Arabic"])
    readonly property string devanagariFamily: firstAvailable(["Noto Sans Devanagari", "Noto Serif Devanagari"])
    readonly property string gurmukhiFamily: firstAvailable(["Noto Sans Gurmukhi", "Noto Serif Gurmukhi"])

    function firstAvailable(preferred: list<string>): string {
        return preferred.find(family => families.includes(family)) ?? "";
    }

    function isArabic(text: string): bool {
        return /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]/.test(text);
    }

    function familyForText(text: string, fallback: string): string {
        if (isArabic(text))
            return urduFamily || fallback;
        if (/[\u0900-\u097f]/.test(text))
            return devanagariFamily || fallback;
        if (/[\u0a00-\u0a7f]/.test(text))
            return gurmukhiFamily || fallback;
        return fallback;
    }

    // An explicit file also works when the shell filters large system fonts.
    FontLoader {
        id: urduFont

        source: GlobalConfig.services.urduFontFile
    }
}
