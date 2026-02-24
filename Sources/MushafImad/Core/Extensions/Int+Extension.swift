//
//  Int+Extension.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 01/11/2025.
//

import SwiftUI
extension Int {
    var arabicOrdinalWord: String {
        switch self {
        case 1: return "الأول"
        case 2: return "الثاني"
        case 3: return "الثالث"
        case 4: return "الرابع"
        case 5: return "الخامس"
        case 6: return "السادس"
        case 7: return "السابع"
        case 8: return "الثامن"
        case 9: return "التاسع"
        case 10: return "العاشر"
        case 11: return "الحادي عشر"
        case 12: return "الثاني عشر"
        case 13: return "الثالث عشر"
        case 14: return "الرابع عشر"
        case 15: return "الخامس عشر"
        case 16: return "السادس عشر"
        case 17: return "السابع عشر"
        case 18: return "الثامن عشر"
        case 19: return "التاسع عشر"
        case 20: return "العشرون"
        case 21: return "الحادي والعشرون"
        case 22: return "الثاني والعشرون"
        case 23: return "الثالث والعشرون"
        case 24: return "الرابع والعشرون"
        case 25: return "الخامس والعشرون"
        case 26: return "السادس والعشرون"
        case 27: return "السابع والعشرون"
        case 28: return "الثامن والعشرون"
        case 29: return "التاسع والعشرون"
        case 30: return "الثلاثون"
        case 31: return "الحادي والثلاثون"
        case 32: return "الثاني والثلاثون"
        case 33: return "الثالث والثلاثون"
        case 34: return "الرابع والثلاثون"
        case 35: return "الخامس والثلاثون"
        case 36: return "السادس والثلاثون"
        case 37: return "السابع والثلاثون"
        case 38: return "الثامن والثلاثون"
        case 39: return "التاسع والثلاثون"
        case 40: return "الأربعون"
        case 41: return "الحادي والأربعون"
        case 42: return "الثاني والأربعون"
        case 43: return "الثالث والأربعون"
        case 44: return "الرابع والأربعون"
        case 45: return "الخامس والأربعون"
        case 46: return "السادس والأربعون"
        case 47: return "السابع والأربعون"
        case 48: return "الثامن والأربعون"
        case 49: return "التاسع والأربعون"
        case 50: return "الخمسون"
        case 51: return "الحادي والخمسون"
        case 52: return "الثاني والخمسون"
        case 53: return "الثالث والخمسون"
        case 54: return "الرابع والخمسون"
        case 55: return "الخامس والخمسون"
        case 56: return "السادس والخمسون"
        case 57: return "السابع والخمسون"
        case 58: return "الثامن والخمسون"
        case 59: return "التاسع والخمسون"
        case 60: return "الستون"
        case 61: return "الحادي والستون"
        case 62: return "الثاني والستون"
        case 63: return "الثالث والستون"
        case 64: return "الرابع والستون"
        case 65: return "الخامس والستون"
        case 66: return "السادس والستون"
        case 67: return "السابع والستون"
        case 68: return "الثامن والستون"
        case 69: return "التاسع والستون"
        case 70: return "السبعون"
        case 71: return "الحادي والسبعون"
        case 72: return "الثاني والسبعون"
        case 73: return "الثالث والسبعون"
        case 74: return "الرابع والسبعون"
        case 75: return "الخامس والسبعون"
        case 76: return "السادس والسبعون"
        case 77: return "السابع والسبعون"
        case 78: return "الثامن والسبعون"
        case 79: return "التاسع والسبعون"
        case 80: return "الثمانون"
        case 81: return "الحادي والثمانون"
        case 82: return "الثاني والثمانون"
        case 83: return "الثالث والثمانون"
        case 84: return "الرابع والثمانون"
        case 85: return "الخامس والثمانون"
        case 86: return "السادس والثمانون"
        case 87: return "السابع والثمانون"
        case 88: return "الثامن والثمانون"
        case 89: return "التاسع والثمانون"
        case 90: return "التسعون"
        case 91: return "الحادي والتسعون"
        case 92: return "الثاني والتسعون"
        case 93: return "الثالث والتسعون"
        case 94: return "الرابع والتسعون"
        case 95: return "الخامس والتسعون"
        case 96: return "السادس والتسعون"
        case 97: return "السابع والتسعون"
        case 98: return "الثامن والتسعون"
        case 99: return "التاسع والتسعون"
        case 100: return "المائة"
        default: return "\(self)"
        }
    }
    
    var chapterTitleArabic: String {
        "الجزء \(arabicOrdinalWord)"
    }
    
    var chapterTitle: String {
        let locale = Locale.current.identifier
        if locale.starts(with: "ar") {
            return "الجزء \(arabicOrdinalWord)"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            let word = formatter.string(from: NSNumber(value: self))?.capitalized ?? "\(self)"
            return "Part \(word)"
        }
    }
    
    var quarterTitle: String {
        let locale = Locale.current.identifier
        if locale.starts(with: "ar") {
            return "الحزب \(arabicOrdinalWord)"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            let word = formatter.string(from: NSNumber(value: self))?.capitalized ?? "\(self)"
            return "Quarter \(word)"
        }
    }
    
    /// Converts an integer to Arabic (Eastern Arabic) numerals
    /// Example: 123 → "١٢٣"
    func toArabicNumerals() -> String {
        let arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        return String(self).map { char in
            if let digit = char.wholeNumberValue {
                return arabicDigits[digit]
            }
            return String(char)
        }.joined()
    }
    
    var toArabic:String {
        let arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        return String(self).map { char in
            if let digit = char.wholeNumberValue {
                return arabicDigits[digit]
            }
            return String(char)
        }.joined()
    }
}
