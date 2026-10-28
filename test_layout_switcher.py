#!/usr/bin/env python3
"""
HeSwitch Layout Switcher Behavioral & Stress Test Suite
Simulates typing streams in random sequences across Hebrew and English,
validating conversion, boundary detection, ambiguity guards, and W/Geresh handling.
"""

import random
import sys
from dataclasses import dataclass
from typing import Optional, List, Tuple, Dict

# --- Engine Configuration & Mappings (Mirrors HeSwitch Swift Implementation) ---

ENGLISH_BASE = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./"
HEBREW_BASE  = ";1234567890-=/'קראטוןםפ][\\שדגכעיחלךף,זסבהנמצתץ."

# Build En -> He mapping
EN_TO_HE = dict(zip(ENGLISH_BASE, HEBREW_BASE))
for e, h in zip(ENGLISH_BASE, HEBREW_BASE):
    if e.isalpha():
        EN_TO_HE[e.upper()] = h
EN_TO_HE['w'] = '׳'
EN_TO_HE['W'] = '׳'

# Build He -> En mapping
HE_TO_EN = dict(zip(HEBREW_BASE, ENGLISH_BASE))
HE_TO_EN['׳'] = 'w'
HE_TO_EN["'"] = 'w'
HE_TO_EN['’'] = 'w'

AMBIGUOUS_COLLISIONS = {
    "to", "do", "go", "so", "no", "an", "ha", "as", "re", "bang", "nut", "bar", "car", "in",
    "אם", "גם", "עם", "דם", "נם", "שם", "יש", "שד", "רק", "נשמע", "הוא", "נשר", "בשר", "ןמ",
    "md", "צג", "tbh", "אני"
}

HIGH_FREQ_EN = {
    "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
    "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
    "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
    "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
    "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
    "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
    "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
    "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
    "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
    "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
    "where", "why", "was", "were", "went", "while", "without", "within", "water",
    "word", "words", "week", "win", "wait", "watch", "walk", "wide", "wind", "winter",
    "wish", "woman", "women", "wrong", "web", "warn", "wear", "weather", "welcome",
    "west", "western", "whose", "whole", "worth", "few", "show", "slow", "flow",
    "grow", "draw", "view", "window", "windows", "between", "power", "tower", "allow", "follow",
    "below", "own", "down", "town", "code", "test", "hello", "world", "true", "false",
    "hi", "hey", "yes", "ok", "bye", "is", "am", "are", "been", "has", "had", "did",
    "does", "got", "morning", "night", "thanks", "please", "google", "israel",
    "md", "tbh"
}

HIGH_FREQ_HE = {
    "שלום", "בוקר", "טוב", "תודה", "בבקשה", "מה", "נשמע", "איך", "אתה", "את",
    "אנחנו", "איפה", "למה", "כמה", "מתי", "רוצה", "יודע", "עכשיו", "עבודה", "הודעה",
    "מחשב", "ישראל", "עברית", "אנגלית", "בסדר", "סבבה", "מצוין", "כן", "לא", "גם",
    "הוא", "היא", "הם", "הן", "זה", "זאת", "אלה", "כל", "רק", "עוד",
    "יום", "לילה", "שבוע", "חודש", "שנה", "בית", "ספר", "דרך", "מקום", "זמן",
    "צריך", "יכול", "היה", "היו", "יהיה", "רואה", "שומע", "הולך", "בא", "יוצא",
    "צה\"ל", "ת\"א", "חו\"ל", "ארה\"ב", "מנכ\"ל", "עו\"ד", "דו\"ח", "בד\"כ", "צ'יפס", "צ׳יפס",
    "צה״ל", "ת״א", "חו״ל", "ארה״ב", "מנכ״ל", "עו״ד", "דו״ח", "בד״כ",
    "ח\"כ", "ח״כ", "ש\"ח", "ש״ח", "תנ\"ך", "תנ״ך", "רוה\"מ", "רוה״מ",
    "אני", "אנכי", "אתם", "אתן",
    "לי", "לך", "לו", "לה", "לנו", "לכם", "לכן", "להם", "להן",
    "אותי", "אותך", "אותו", "אותה", "אותנו", "אתכם", "אתכן", "אותם", "אותן",
    "שלי", "שלך", "שלו", "שלה", "שלנו", "שלכם", "שלכן", "שלהם", "שלהן",
    "בי", "בך", "בו", "בה", "בנו", "בכם", "בכן", "בהם", "בהן",
    "אלי", "אליי", "אליך", "אליו", "אליה", "אלינו", "אליכם", "אליכן", "אליהם", "אליהן",
    "עלי", "עליי", "עליך", "עליו", "עליה", "עלינו", "עליכם", "עליכן", "עליהם", "עליהן",
    "איתי", "איתך", "איתו", "איתה", "איתנו", "איתכם", "איתכן", "איתם", "איתן",
    "ממני", "ממך", "ממנו", "ממנה", "מאיתנו", "מכם", "מכן", "מהם", "מהן",
    "של", "על", "אל", "אם", "עם", "או", "אבל", "כי", "יש", "אין", "כבר",
    "תמיד", "אולי", "בטח", "כאן", "פה", "שם", "אז", "כדי", "כמו", "עד",
    "לפני", "אחרי", "בין", "מאוד", "הרבה", "קצת", "יותר", "פחות", "אחר",
    "הייתי", "היית", "היינו", "תהיה", "יהיו", "עושה", "מבין", "חושב", "אומר",
    "צג", "מסך", "טלפון", "חלון", "קובץ", "שורה", "מילה"
}

COMMON_CONTRACTIONS = {
    "don't", "can't", "won't", "it's", "i'm", "you're", "they're", "we're",
    "that's", "what's", "there's", "he's", "she's", "let's", "didn't",
    "doesn't", "isn't", "aren't", "wasn't", "weren't", "haven't", "hasn't",
    "hadn't", "couldn't", "shouldn't", "wouldn't"
}

@dataclass
class ConversionResult:
    input_text: str
    output_text: str
    source_lang: str
    target_lang: str

def is_hebrew_char(ch: str) -> bool:
    return any(0x0590 <= ord(c) <= 0x05FF for c in ch)

def type_on_hebrew_layout(en_word: str) -> str:
    """Computes exact keystrokes produced when an English word is typed on a macOS Hebrew keyboard."""
    return "".join(EN_TO_HE.get(c, c) for c in en_word)

def type_on_english_layout(he_word: str) -> str:
    """Computes exact keystrokes produced when a Hebrew word is typed on a macOS English keyboard."""
    return "".join(HE_TO_EN.get(c, c) for c in he_word)

def convert_layout(text: str) -> Optional[ConversionResult]:
    if not text:
        return None

    # Double-quote / Gershayim prefix for Shift + W typed in Hebrew layout:
    # e.g. "״ישא" -> "What", "\"ישא" -> "What", "״hat" -> "What", "\"hat" -> "What",
    #      "״יקמ" -> "When", "״יקרק" -> "Where", "״יט" -> "Why", "״ים" -> "Who"
    if (text.startswith('"') or text.startswith('״')) and len(text) > 1:
        tail = text[1:]
        candidate_en = ["W"]
        has_conv = False
        for ch in tail:
            if ch.isascii() and ch.isalpha():
                candidate_en.append(ch.lower())
                has_conv = True
            elif ch in "׳’'":
                candidate_en.append("w")
                has_conv = True
            elif ch in HE_TO_EN:
                candidate_en.append(HE_TO_EN[ch])
                has_conv = True
            else:
                candidate_en.append(ch)
        cand_str = "".join(candidate_en)
        if has_conv and all(c.isascii() and (c.isalpha() or c in "'’") for c in cand_str):
            return ConversionResult(
                input_text=text,
                output_text=cand_str,
                source_lang="HE",
                target_lang="EN"
            )

    # Mixed Geresh check: e.g. "׳hat" -> "what", "ho׳" -> "how", "to׳er" -> "tower"
    if ("׳" in text or "’" in text or "'" in text) and text.lower() not in COMMON_CONTRACTIONS:
        replaced_chars = []
        for idx, c in enumerate(text):
            if c in "׳’'":
                next_is_upper = idx < len(text) - 1 and text[idx + 1].isupper()
                replaced_chars.append('W' if idx == 0 and next_is_upper else 'w')
            else:
                replaced_chars.append(c)
        replaced = "".join(replaced_chars)
        if replaced != text and replaced.isalpha() and all(ord(c) < 128 for c in replaced):
            return ConversionResult(
                input_text=text,
                output_text=replaced,
                source_lang="HE",
                target_lang="EN"
            )

    en_count = sum(1 for c in text if c.isascii() and c.isalpha())
    he_count = sum(1 for c in text if is_hebrew_char(c) or c in "׳״")

    # Capitalized English typed in Hebrew layout (e.g. "Wישא" -> "What", "Hקךךם" -> "Hello")
    if en_count > 0 and he_count > 0:
        candidate_chars = []
        for idx, c in enumerate(text):
            if c.isascii() and c.isalpha():
                candidate_chars.append(c)
            elif c in '"״':
                candidate_chars.append('W' if idx == 0 else 'w')
            else:
                candidate_chars.append(HE_TO_EN.get(c, c))
        candidate_en = "".join(candidate_chars)
        if candidate_en != text and all(c.isascii() and (c.isalpha() or c in "'’") for c in candidate_en):
            return ConversionResult(
                input_text=text,
                output_text=candidate_en,
                source_lang="HE",
                target_lang="EN"
            )

    if (en_count > 0 and he_count > 0) or (en_count == 0 and he_count == 0):
        return None

    source_lang = "EN" if en_count > 0 else "HE"
    target_lang = "HE" if source_lang == "EN" else "EN"
    mapping = EN_TO_HE if source_lang == "EN" else HE_TO_EN

    chars = list(text)
    converted_chars = []

    for i, current in enumerate(chars):
        # Numeric separator protection (e.g. 3.14 or 1,000)
        if current in ".," and 0 < i < len(chars) - 1:
            if chars[i - 1].isdigit() and chars[i + 1].isdigit():
                converted_chars.append(current)
                continue

        # In English typing, apostrophe following a letter represents Hebrew Geresh
        if source_lang == "EN" and current == "'" and i > 0 and chars[i - 1].isalpha():
            converted_chars.append("'")
            continue

        # Gershayim inside Hebrew acronyms when converting English to Hebrew
        if source_lang == "EN" and current in '\"״':
            converted_chars.append(current)
            continue

        converted_chars.append(mapping.get(current, current))

    output_text = "".join(converted_chars)
    if output_text == text:
        return None

    return ConversionResult(
        input_text=text,
        output_text=output_text,
        source_lang=source_lang,
        target_lang=target_lang
    )

def script_of_context(context: Optional[str]) -> str:
    if not context:
        return "neutral"
    last_line = context.splitlines()[-1] if context.splitlines() else context
    trimmed = last_line.strip()
    if not trimmed:
        return "neutral"
    heb = sum(1 for c in trimmed if 0x0590 <= ord(c) <= 0x05FF or c in "״׳")
    eng = sum(1 for c in trimmed if c.isascii() and c.isalpha())
    if heb > eng:
        return "hebrew"
    elif eng > heb:
        return "english"
    return "neutral"

def is_cli_command_context(context: Optional[str]) -> bool:
    if not context:
        return False
    last_line = context.splitlines()[-1] if context.splitlines() else context
    tokens = last_line.strip().split()
    if not tokens:
        return False
    cli_commands = {
        "cat", "vim", "vi", "nano", "touch", "code", "open", "less", "more",
        "head", "tail", "echo", "grep", "mv", "cp", "rm", "git", "ls"
    }
    return tokens[0].lower() in cli_commands

def decision_engine_candidate(word: str, context: Optional[str] = None, is_terminal: bool = False) -> Optional[ConversionResult]:
    """Simulates DecisionEngine logic including high frequency fast-paths, script coherence and spellcheck validation."""
    if len(word) < 2 or len(word) > 40:
        return None

    conversion = convert_layout(word)
    if not conversion:
        return None

    # Ambiguous collisions with Line Context Script Coherence:
    is_ambiguous = (word.lower() in AMBIGUOUS_COLLISIONS) or (conversion.output_text.lower() in AMBIGUOUS_COLLISIONS)
    if is_ambiguous:
        if word.lower() == "צג":
            if (context and context.endswith(".")) or word.startswith(".") or is_cli_command_context(context) or is_terminal:
                return conversion
        script = script_of_context(context)
        if script == "hebrew":
            if conversion.source_lang == "EN":
                return conversion
            else:
                return None
        elif script == "english":
            if conversion.source_lang == "HE":
                return conversion
            else:
                return None
        else:
            return None

    target_lower = conversion.output_text.lower()
    source_lower = word.lower()

    # 1. High frequency fast-path check
    if conversion.target_lang == "EN" and target_lower in HIGH_FREQ_EN:
        return conversion
    if conversion.target_lang == "HE" and (target_lower in HIGH_FREQ_HE or conversion.output_text in HIGH_FREQ_HE):
        return conversion

    # 2. Source already correct check
    if conversion.source_lang == "EN" and source_lower in HIGH_FREQ_EN:
        return None
    if conversion.source_lang == "HE" and source_lower in HIGH_FREQ_HE:
        return None

    # 3. English Contractions protection
    if source_lower in COMMON_CONTRACTIONS:
        return None

    # 4. Valid target character validation
    if conversion.target_lang == "EN" and target_lower.isalpha():
        return conversion
    if conversion.target_lang == "HE" and all(is_hebrew_char(c) or c in "\"'״׳" for c in conversion.output_text):
        return conversion

    return None

# --- Automated Test Harness & Random Sequence Generator ---

@dataclass
class TestCase:
    category: str
    intended_word: str
    typed_token: str
    expected_switch: bool
    expected_result: str
    context: Optional[str] = None

def generate_test_corpus() -> List[TestCase]:
    cases: List[TestCase] = []

    # Category 1: English words mistyped on physical Hebrew keyboard layout
    en_sample = [
        "what", "how", "and", "world", "hello", "code", "when", "where",
        "why", "who", "with", "will", "two", "new", "show", "slow",
        "tower", "power", "between", "work", "week", "want", "water",
        "winter", "wrong", "welcome", "about", "there", "their", "people",
        "year", "good", "some", "could", "them", "look", "only", "come"
    ]
    for w in en_sample:
        typed = type_on_hebrew_layout(w)
        cases.append(TestCase("English in Hebrew Layout", w, typed, True, w))

    # Category 2: Mixed Geresh Letter 'W' (user typed '׳' or "'" for 'w' then switched or typed English)
    mixed_w = [
        ("what", "׳hat"),
        ("how", "ho׳"),
        ("world", "׳orld"),
        ("when", "׳hen"),
        ("where", "׳here"),
        ("tower", "to׳er"),
        ("power", "po׳er"),
        ("slow", "slo׳"),
        ("flow", "flo׳"),
        ("grow", "gro׳"),
        ("water", "׳ater"),
        ("winter", "׳inter"),
        ("week", "׳eek"),
        ("work", "׳ork"),
    ]
    for intended, typed in mixed_w:
        cases.append(TestCase("Mixed Geresh 'W'", intended, typed, True, intended))

    # Category 2b: Capitalized English typed in Hebrew layout (Shift + letter producing Latin capital, or Shift + W producing '"' / '״')
    cap_cases = [
        ("What", "Wישא"),
        ("What", "״ישא"),
        ("What", "\"ישא"),
        ("What", "״hat"),
        ("What", "\"hat"),
        ("When", "Wיקמ"),
        ("When", "״יקמ"),
        ("When", "\"יקמ"),
        ("When", "״hen"),
        ("Where", "Wיקרק"),
        ("Where", "״יקרק"),
        ("Where", "״here"),
        ("Why", "Wיט"),
        ("Why", "״יט"),
        ("Why", "״hy"),
        ("Who", "Wים"),
        ("Who", "״ים"),
        ("Who", "״ho"),
        ("World", "Wםרךג"),
        ("World", "״םרךג"),
        ("World", "״orld"),
        ("Will", "Wןךך"),
        ("Will", "״ןךך"),
        ("With", "Wןאי"),
        ("With", "״ןאי"),
        ("Week", "Wקקל"),
        ("Week", "״קקל"),
        ("Week", "\"קקל"),
        ("Week", "״eek"),
        ("Water", "Wשאקר"),
        ("Water", "״שאקר"),
        ("Water", "\"שאקר"),
        ("Water", "״ater"),
        ("Windows", "Wןמגם׳ד"),
        ("Windows", "״ןמגם׳ד"),
        ("Windows", "\"ןמגם׳ד"),
        ("Windows", "״indows"),
        ("Web", "Wקנ"),
        ("Web", "״קנ"),
        ("Web", "\"קנ"),
        ("Web", "״eb"),
        ("Hello", "Hקךךם"),
        ("Please", "Pךקשדק"),
        ("How", "Hם׳"),
        ("Thanks", "Tישמלד"),
        ("Israel", "Iדרשקך"),
        ("Google", "Gםםעךק"),
        ("You", "Yםו"),
        ("And", "Aמג"),
        ("Hi", "Hן"),
        ("Is", "Iד"),
        ("Yes", "Yקד"),
        ("Ok", "Oל"),
        ("Code", "Cםגק"),
        ("Test", "Tקדא"),
    ]
    for intended, typed in cap_cases:
        cases.append(TestCase("Capitalized English in Hebrew Layout", intended, typed, True, intended))

    # Category 3: Hebrew words mistyped on physical English keyboard layout
    he_sample = [
        "שלום", "בוקר", "טוב", "תודה", "בבקשה", "איך", "אנחנו", "איפה",
        "למה", "כמה", "מתי", "רוצה", "יודע", "עכשיו", "עבודה", "הודעה",
        "מחשב", "ישראל", "עברית", "אנגלית", "בסדר", "סבבה", "מצוין",
        "רואה", "שומע", "הולך", "צריך", "יכול"
    ]
    for h in he_sample:
        typed = type_on_english_layout(h)
        cases.append(TestCase("Hebrew in English Layout", h, typed, True, h))

    # Category 4: Hebrew Punctuation Keys (Tav on comma, Tsadi Sofit on dot, Pe Sofit on semicolon)
    punct_cases = [
        ("אתה", "t,v"),
        ("את", "t,"),
        ("רוץ", "ru."),
        ("סוף", "xu;"),
        ("עברית", "gcrh,"),
        ("אנגלית", "tbdkh,"),
    ]
    for intended, typed in punct_cases:
        cases.append(TestCase("Hebrew Punctuation Keys", intended, typed, True, intended))

    # Category 5: Hebrew Acronyms & Abbreviations
    acronyms = [
        ("צה\"ל", "mv\"k"),
        ("ת\"א", ",\"t"),
        ("חו\"ל", "ju\"k"),
        ("ארה\"ב", "trv\"c"),
        ("מנכ\"ל", "nbf\"k"),
        ("צ׳יפס", "mwhpx"),
    ]
    for intended, typed in acronyms:
        cases.append(TestCase("Hebrew Acronyms", intended, typed, True, intended))

    # Category 6: Correct English typed in English layout (MUST NOT SWITCH)
    correct_en = [
        ("hello", "hello"),
        ("world", "world"),
        ("what", "what"),
        ("how", "how"),
        ("code", "code"),
        ("test", "test"),
        ("don't", "don't"),
        ("it's", "it's"),
        ("can't", "can't"),
        ("good", "good"),
        ("water", "water"),
    ]
    for intended, typed in correct_en:
        cases.append(TestCase("Correct English (No Switch)", intended, typed, False, intended))

    # Category 7: Correct Hebrew typed in Hebrew layout (MUST NOT SWITCH)
    correct_he = [
        ("שלום", "שלום"),
        ("בוקר", "בוקר"),
        ("טוב", "טוב"),
        ("אתה", "אתה"),
        ("צה\"ל", "צה\"ל"),
        ("תודה", "תודה"),
        ("עבודה", "עבודה"),
    ]
    for intended, typed in correct_he:
        cases.append(TestCase("Correct Hebrew (No Switch)", intended, typed, False, intended))

    # Category 8: Ambiguous collisions in isolation (MUST NOT SWITCH)
    ambiguous = [
        ("to", "to"),
        ("do", "do"),
        ("go", "go"),
        ("so", "so"),
        ("אם", "אם"),
        ("גם", "גם"),
        ("עם", "עם"),
        ("md", "md"),
        ("צג", "צג"),
        ("tbh", "tbh"),
        ("אני", "אני"),
    ]
    for intended, typed in ambiguous:
        cases.append(TestCase("Ambiguous Collisions (No Switch)", intended, typed, False, intended))

    # Category 8b: Contextual Script Coherence
    contextual_cases = [
        # In Hebrew line context, accidental English switches to Hebrew:
        ("אני", "tbh", True, "אני", "שלום, "),
        ("צג", "md", True, "צג", "קניתי "),
        ("אם", "to", True, "אם", "אני רוצה "),
        ("גם", "do", True, "גם", "אני "),
        # In Hebrew line context, correct Hebrew stays Hebrew:
        ("אני", "אני", False, "אני", "שלום, "),
        ("צג", "צג", False, "צג", "קניתי "),
        ("אם", "אם", False, "אם", "אני רוצה "),
        ("גם", "גם", False, "גם", "אני "),
        # In English line context, accidental Hebrew switches to English:
        ("tbh", "אני", True, "tbh", "I think "),
        ("to", "אם", True, "to", "I want "),
        ("do", "גם", True, "do", "what should I "),
        # In English line context, correct English stays English:
        ("tbh", "tbh", False, "tbh", "I think "),
        ("to", "to", False, "to", "I want "),
        ("do", "do", False, "do", "what should I "),
        # Markdown & CLI conversions:
        ("md", "צג", True, "md", "cat "),
        ("md", "צג", True, "md", "vim "),
        ("md", "צג", True, "md", "README."),
    ]
    for intended, typed, expected_switch, expected_result, ctx in contextual_cases:
        cases.append(TestCase("Contextual Script Coherence", intended, typed, expected_switch, expected_result, context=ctx))

    # Category 9: Numbers and Decimals (MUST NOT SWITCH)
    numbers = [
        ("3.14", "3.14"),
        ("1,000", "1,000"),
        ("2026", "2026"),
        ("42.0", "42.0"),
    ]
    for intended, typed in numbers:
        cases.append(TestCase("Numeric & Decimals (No Switch)", intended, typed, False, intended))

    return cases

def run_simulation(num_random_trials: int = 2000) -> Dict[str, any]:
    corpus = generate_test_corpus()
    
    # Generate randomized streams of typing
    random.seed(42)  # Deterministic seed for reproducible testing
    test_stream = []
    
    # 1. Run all curated cases
    test_stream.extend(corpus)
    
    # 2. Add randomized permutations
    for _ in range(num_random_trials):
        choice = random.choice(corpus)
        test_stream.append(choice)

    # Metrics
    total = len(test_stream)
    passed = 0
    failed = 0
    
    true_positives = 0   # Needed switch and switched correctly
    true_negatives = 0   # Did not need switch and was left alone
    false_positives = 0  # Did not need switch but was converted
    false_negatives = 0  # Needed switch but was ignored or wrong output

    category_stats: Dict[str, Dict[str, int]] = {}
    failures: List[Tuple[TestCase, str]] = []

    for case in test_stream:
        cat = case.category
        if cat not in category_stats:
            category_stats[cat] = {"total": 0, "passed": 0, "failed": 0}
        category_stats[cat]["total"] += 1

        candidate = decision_engine_candidate(case.typed_token, context=case.context)
        actual_switched = candidate is not None
        actual_output = candidate.output_text if candidate else case.typed_token

        success = False
        if case.expected_switch:
            if actual_switched and actual_output.lower() == case.expected_result.lower():
                success = True
                true_positives += 1
            else:
                false_negatives += 1
                failures.append((case, f"Expected switch to '{case.expected_result}', got '{actual_output}' (switched={actual_switched})"))
        else:
            if not actual_switched:
                success = True
                true_negatives += 1
            else:
                false_positives += 1
                failures.append((case, f"Expected NO switch for '{case.typed_token}', but was switched to '{actual_output}'"))

        if success:
            passed += 1
            category_stats[cat]["passed"] += 1
        else:
            failed += 1
            category_stats[cat]["failed"] += 1

    accuracy = (passed / total) * 100 if total > 0 else 0
    precision = (true_positives / (true_positives + false_positives)) * 100 if (true_positives + false_positives) > 0 else 0
    recall = (true_positives / (true_positives + false_negatives)) * 100 if (true_positives + false_negatives) > 0 else 0
    f1 = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "true_positives": true_positives,
        "true_negatives": true_negatives,
        "false_positives": false_positives,
        "false_negatives": false_negatives,
        "category_stats": category_stats,
        "failures": failures[:10]
    }

def print_report(results: Dict[str, any]):
    print("=" * 80)
    print("       HeSwitch Automated Behavioral & Stress Test Report")
    print("=" * 80)
    print(f"Total Test Trials:        {results['total']}")
    print(f"Passed:                   {results['passed']} ({results['accuracy']:.2f}%)")
    print(f"Failed:                   {results['failed']}")
    print("-" * 80)
    print(f"True Positives  (TP):     {results['true_positives']:<6} (Correctly converted wrong layout)")
    print(f"True Negatives  (TN):     {results['true_negatives']:<6} (Correctly preserved valid input)")
    print(f"False Positives (FP):     {results['false_positives']:<6} (Accidental switch of valid words)")
    print(f"False Negatives (FN):     {results['false_negatives']:<6} (Missed switch of mistyped words)")
    print("-" * 80)
    print(f"Precision:                {results['precision']:.2f}%")
    print(f"Recall:                   {results['recall']:.2f}%")
    print(f"F1 Score:                 {results['f1']:.2f}%")
    print("=" * 80)
    print(f"{'Category':<35} | {'Total':<8} | {'Passed':<8} | {'Success Rate'}")
    print("-" * 80)
    for cat, stats in results["category_stats"].items():
        rate = (stats["passed"] / stats["total"]) * 100 if stats["total"] > 0 else 0
        print(f"{cat:<35} | {stats['total']:<8} | {stats['passed']:<8} | {rate:6.2f}%")
    print("=" * 80)

    if results["failures"]:
        print("\n[!] Sample Failures:")
        for case, reason in results["failures"]:
            print(f"  - Category: {case.category}")
            print(f"    Typed:    '{case.typed_token}'")
            print(f"    Reason:   {reason}")
    else:
        print("\n[✓] PERFECT SCORE: 100% OF ALL TEST TRIALS PASSED!")
        print("    Zero false positives (no valid typing corrupted).")
        print("    Zero false negatives (all wrong layout words successfully switched).")
    print("=" * 80)

if __name__ == "__main__":
    trials = 2000
    if len(sys.argv) > 1:
        try:
            trials = int(sys.argv[1])
        except ValueError:
            pass
    print(f"==> Running HeSwitch typing simulation with {trials} randomized trials...")
    res = run_simulation(trials)
    print_report(res)
    if res["failed"] > 0:
        sys.exit(1)
    sys.exit(0)
