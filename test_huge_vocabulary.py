#!/usr/bin/env python3
"""
HeSwitch Massive Corpus Stress & Behavioral Test Suite
Tests layout conversion and decision engine against huge real-world vocabularies:
- 10,000 top frequency English words
- 59,276 comprehensive English lexicon words
- 129,574 authentic Hebrew words from Hspell
Simulates thousands of randomized typing events in both languages,
analyzing accuracy, false positive rate, recall, and W/Geresh resilience.
"""

import json
import os
import random
import sys
import time
from dataclasses import dataclass
from typing import Optional, List, Tuple, Dict, Set

# --- Physical Layout Mappings (SI-1452 / macOS Hebrew vs US QWERTY) ---

ENGLISH_BASE = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./"
HEBREW_BASE  = ";1234567890-=/'קראטוןםפ][\\שדגכעיחלךף,זסבהנמצתץ."

EN_TO_HE = dict(zip(ENGLISH_BASE, HEBREW_BASE))
for e, h in zip(ENGLISH_BASE, HEBREW_BASE):
    if e.isalpha():
        EN_TO_HE[e.upper()] = h
EN_TO_HE['w'] = '׳'
EN_TO_HE['W'] = '׳'

HE_TO_EN = dict(zip(HEBREW_BASE, ENGLISH_BASE))
HE_TO_EN['׳'] = 'w'
HE_TO_EN["'"] = 'w'
HE_TO_EN['’'] = 'w'

AMBIGUOUS_COLLISIONS = {
    "to", "do", "go", "so", "no", "an", "ha", "as", "re", "bang", "nut", "bar", "car", "in",
    "אם", "גם", "עם", "דם", "נם", "שם", "יש", "שד", "רק", "נשמע", "הוא", "נשר", "בשר", "ןמ",
    "md", "צג", "tbh", "אני"
}

COMMON_CONTRACTIONS = {
    "don't", "can't", "won't", "it's", "i'm", "you're", "they're", "we're",
    "that's", "what's", "there's", "he's", "she's", "let's", "didn't",
    "doesn't", "isn't", "aren't", "wasn't", "weren't", "haven't", "hasn't",
    "hadn't", "couldn't", "shouldn't", "wouldn't"
}

# Top high frequency words bundled inside HeSwitch for morphology bypass
BUNDLED_HIGH_FREQ_EN = {
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
    "grow", "draw", "view", "window", "between", "power", "tower", "allow", "follow",
    "below", "own", "down", "town", "code", "test", "hello", "world", "true", "false",
    "add", "are", "app", "ask", "all", "key", "pay", "set", "put", "run", "log", "fix",
    "bug", "dev", "prod", "api", "url", "id", "cmd", "dir", "save", "load", "init", "info",
    "edit", "list", "item", "menu", "icon", "port", "host", "link", "path", "send", "auth",
    "type", "call", "sync", "done", "task", "date", "card", "page", "clean", "build", "start",
    "stop", "error", "debug", "release", "version", "install", "update", "upgrade", "delete",
    "remove", "create", "select", "insert", "search", "replace", "change", "switch", "toggle",
    "enable", "disable", "input", "output", "import", "export", "upload", "download",
    "md", "tbh"
}

BUNDLED_HIGH_FREQ_HE = {
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
    "לפי", "לפיו", "לפיה", "לפיכך", "לפני", "אחרי", "בין", "מאוד", "הרבה", "קצת", "יותר", "פחות", "אחר",
    "הייתי", "היית", "היינו", "תהיה", "יהיו", "עושה", "מבין", "חושב", "אומר",
    "צג", "מסך", "טלפון", "חלון", "קובץ", "שורה", "מילה"
}

def is_hebrew_char(ch: str) -> bool:
    return any(0x0590 <= ord(c) <= 0x05FF for c in ch)

def type_on_hebrew_layout(en_word: str) -> str:
    """Simulates physical typing of an English word while macOS Hebrew layout is active."""
    return "".join(EN_TO_HE.get(c, c) for c in en_word)

def type_on_english_layout(he_word: str) -> str:
    """Simulates physical typing of a Hebrew word while macOS English layout is active."""
    return "".join(HE_TO_EN.get(c, c) for c in he_word)

@dataclass
class ConversionResult:
    input_text: str
    output_text: str
    source_lang: str
    target_lang: str

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

class DecisionEngineSimulator:
    def __init__(self, en_vocab: Set[str], he_vocab: Set[str]):
        self.en_vocab = en_vocab
        self.he_vocab = he_vocab

    def candidate(self, word: str) -> Optional[ConversionResult]:
        if len(word) < 2 or len(word) > 40:
            return None

        # Guard against ambiguous 2-letter collisions (to, do, go, אם, גם)
        if word.lower() in AMBIGUOUS_COLLISIONS:
            return None

        conversion = convert_layout(word)
        if not conversion:
            return None

        source_lower = word.lower()
        target_lower = conversion.output_text.lower()
        contains_hebrew_punct_keys = any(c in ",.;'" for c in word)

        # Special fast-path for kph -> לפי (kph is km/h in English, practically never typed standalone)
        if source_lower == "kph":
            return conversion

        # 1. English words that are already correctly spelled without Hebrew punctuation keys must NEVER be converted!
        if conversion.source_lang == "EN":
            if (source_lower in self.en_vocab or source_lower in COMMON_CONTRACTIONS) and not contains_hebrew_punct_keys:
                return None

        # 2. High-frequency vocabulary fast-path:
        if conversion.target_lang == "EN" and target_lower in BUNDLED_HIGH_FREQ_EN:
            return conversion
        if conversion.target_lang == "HE" and (target_lower in BUNDLED_HIGH_FREQ_HE or conversion.output_text in BUNDLED_HIGH_FREQ_HE):
            return conversion

        # 3. Source already correct check for Hebrew:
        if conversion.source_lang == "HE":
            if source_lower in self.he_vocab and not contains_hebrew_punct_keys:
                return None

        # 4. Target valid spelling check:
        if conversion.target_lang == "EN":
            if target_lower in self.en_vocab:
                return conversion
        elif conversion.target_lang == "HE":
            if target_lower in self.he_vocab or conversion.output_text in self.he_vocab:
                return conversion

        return None

# --- Large Corpus Loader ---

def load_vocabularies() -> Tuple[Set[str], Set[str], List[str], List[str]]:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    vocab_dir = os.path.join(base_dir, "tests", "vocabularies")

    en_10k_path = os.path.join(vocab_dir, "words_en_10k.txt")
    en_59k_path = os.path.join(vocab_dir, "words_en_59k.json")
    he_path = os.path.join(vocab_dir, "words_he_hspell.txt")

    en_vocab: Set[str] = set()
    he_vocab: Set[str] = set()
    en_frequent_list: List[str] = []
    he_frequent_list: List[str] = []

    # 1. Load English
    if os.path.exists(en_10k_path):
        with open(en_10k_path, "r", encoding="utf-8") as f:
            for line in f:
                w = line.strip().lower()
                if len(w) >= 2 and w.isalpha():
                    en_vocab.add(w)
                    en_frequent_list.append(w)

    if os.path.exists(en_59k_path):
        with open(en_59k_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                for w in data:
                    if len(w) >= 2 and w.isalpha():
                        en_vocab.add(w.lower())
            elif isinstance(data, dict):
                for w in data.keys():
                    if len(w) >= 2 and w.isalpha():
                        en_vocab.add(w.lower())

    # Add bundled high frequency English words
    en_vocab.update(BUNDLED_HIGH_FREQ_EN)

    # 2. Load Hebrew
    if os.path.exists(he_path):
        with open(he_path, "r", encoding="utf-8") as f:
            for line in f:
                w = line.strip()
                if len(w) >= 2 and is_hebrew_char(w):
                    he_vocab.add(w)
                    if len(he_frequent_list) < 15000:
                        he_frequent_list.append(w)

    # Add bundled high frequency Hebrew words
    he_vocab.update(BUNDLED_HIGH_FREQ_HE)

    return en_vocab, he_vocab, en_frequent_list, he_frequent_list

@dataclass
class TestItem:
    category: str
    intended_word: str
    typed_token: str
    expected_switch: bool
    expected_result: str

def build_massive_test_suite(
    en_vocab: Set[str],
    he_vocab: Set[str],
    en_frequent: List[str],
    he_frequent: List[str],
    sample_size: int = 10000
) -> List[TestItem]:
    random.seed(42)
    suite: List[TestItem] = []

    # 1. English words mistyped on physical Hebrew keyboard (Intended EN, typed in HE layout)
    en_sample = random.sample(en_frequent, min(len(en_frequent), sample_size // 4))
    for w in en_sample:
        typed = type_on_hebrew_layout(w)
        suite.append(TestItem("English mistyped in Hebrew layout", w, typed, True, w))

    # 2. Hebrew words mistyped on physical English keyboard (Intended HE, typed in EN layout)
    he_sample = random.sample(he_frequent, min(len(he_frequent), sample_size // 4))
    for h in he_sample:
        typed = type_on_english_layout(h)
        suite.append(TestItem("Hebrew mistyped in English layout", h, typed, True, h))

    # 3. Mixed Geresh Letter 'W' words
    # Words starting or containing W where W was typed as '׳' or "'"
    w_words = [w for w in en_frequent if 'w' in w and len(w) >= 3][:1000]
    for w in random.sample(w_words, min(len(w_words), sample_size // 8)):
        mixed_token = w.replace('w', '׳')
        suite.append(TestItem("Mixed Geresh 'W' tokens", w, mixed_token, True, w))

    # 4. Hebrew words featuring punctuation keys (Tav on ',', Tsadi Sofit on '.', Pe Sofit on ';')
    he_punct = [h for h in he_frequent if any(c in "תץף" for c in h) and len(h) >= 3][:1000]
    for h in random.sample(he_punct, min(len(he_punct), sample_size // 8)):
        typed = type_on_english_layout(h)
        suite.append(TestItem("Hebrew punctuation key words", h, typed, True, h))

    # 5. Correctly typed English words (Negative control - MUST NOT SWITCH)
    correct_en = random.sample(en_frequent, min(len(en_frequent), sample_size // 8))
    for w in correct_en:
        suite.append(TestItem("Correct English words (Negative control)", w, w, False, w))

    # 6. Correctly typed Hebrew words (Negative control - MUST NOT SWITCH)
    correct_he = random.sample(he_frequent, min(len(he_frequent), sample_size // 8))
    for h in correct_he:
        suite.append(TestItem("Correct Hebrew words (Negative control)", h, h, False, h))

    # 7. Ambiguous 2-letter collisions (Negative control - MUST NOT SWITCH)
    for w in AMBIGUOUS_COLLISIONS:
        suite.append(TestItem("Ambiguous collisions (Protected)", w, w, False, w))

    # 8. English Contractions (Negative control - MUST NOT SWITCH)
    for c in COMMON_CONTRACTIONS:
        suite.append(TestItem("English Contractions (Protected)", c, c, False, c))

    # 9. Decimals and numbers (Negative control - MUST NOT SWITCH)
    numerics = ["3.14", "1,000", "2026", "42.0", "99.99", "10,500.50", "0.001", "3.14159"]
    for num in numerics:
        suite.append(TestItem("Decimals & Numbers (Protected)", num, num, False, num))

    # Shuffle for realistic interleaved stream
    random.shuffle(suite)
    return suite

def run_evaluation(engine: DecisionEngineSimulator, suite: List[TestItem]) -> Dict[str, any]:
    total = len(suite)
    passed = 0
    failed = 0

    tp = 0  # Needed switch and switched correctly
    tn = 0  # Did not need switch and remained untouched
    fp = 0  # Did not need switch but was converted (Corrupted user typing)
    fn = 0  # Needed switch but was ignored or wrong output

    category_stats: Dict[str, Dict[str, int]] = {}
    failures: List[Tuple[TestItem, str]] = []

    start_time = time.time()

    for item in suite:
        cat = item.category
        if cat not in category_stats:
            category_stats[cat] = {"total": 0, "passed": 0, "failed": 0}
        category_stats[cat]["total"] += 1

        candidate = engine.candidate(item.typed_token)
        actual_switched = candidate is not None
        actual_output = candidate.output_text if candidate else item.typed_token

        success = False
        if item.expected_switch:
            if actual_switched and actual_output.lower() == item.expected_result.lower():
                success = True
                tp += 1
            else:
                fn += 1
                failures.append((item, f"Expected switch to '{item.expected_result}', got '{actual_output}' (switched={actual_switched})"))
        else:
            if not actual_switched:
                success = True
                tn += 1
            else:
                fp += 1
                failures.append((item, f"False Positive: '{item.typed_token}' was mistakenly converted to '{actual_output}'"))

        if success:
            passed += 1
            category_stats[cat]["passed"] += 1
        else:
            failed += 1
            category_stats[cat]["failed"] += 1

    elapsed = time.time() - start_time
    accuracy = (passed / total) * 100 if total > 0 else 0
    precision = (tp / (tp + fp)) * 100 if (tp + fp) > 0 else 0
    recall = (tp / (tp + fn)) * 100 if (tp + fn) > 0 else 0
    f1 = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    specificity = (tn / (tn + fp)) * 100 if (tn + fp) > 0 else 0

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "elapsed": elapsed,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "specificity": specificity,
        "f1": f1,
        "tp": tp,
        "tn": tn,
        "fp": fp,
        "fn": fn,
        "category_stats": category_stats,
        "failures": failures
    }

def print_detailed_report(res: Dict[str, any], en_count: int, he_count: int):
    print("=" * 85)
    print("        HeSwitch Massive Vocabulary & Stress Evaluation Report")
    print("=" * 85)
    print(f"Loaded English Vocabulary:     {en_count:,} words")
    print(f"Loaded Hebrew Vocabulary:      {he_count:,} words (Hspell)")
    print(f"Total Corpus Size:             {en_count + he_count:,} words")
    print(f"Executed Typing Trials:        {res['total']:,}")
    print(f"Execution Duration:            {res['elapsed']:.2f} seconds ({res['total'] / res['elapsed']:.0f} words/sec)")
    print("-" * 85)
    print(f"Accuracy:                      {res['accuracy']:.2f}%")
    print(f"Precision:                     {res['precision']:.2f}% (Integrity of conversions)")
    print(f"Recall:                        {res['recall']:.2f}% (Mistyped words detected)")
    print(f"Specificity:                   {res['specificity']:.2f}% (Valid words preserved)")
    print(f"F1 Score:                      {res['f1']:.2f}%")
    print("-" * 85)
    print(f"True Positives  (TP):          {res['tp']:<8} (Correctly switched wrong layout)")
    print(f"True Negatives  (TN):          {res['tn']:<8} (Correctly kept legitimate words)")
    print(f"False Positives (FP):          {res['fp']:<8} (CORRUPTIONS: Legitimate words mistakenly changed)")
    print(f"False Negatives (FN):          {res['fn']:<8} (Missed switches)")
    print("=" * 85)
    print(f"{'Test Category':<45} | {'Total':<8} | {'Passed':<8} | {'Success Rate'}")
    print("-" * 85)
    for cat, stats in res["category_stats"].items():
        rate = (stats["passed"] / stats["total"]) * 100 if stats["total"] > 0 else 0
        print(f"{cat:<45} | {stats['total']:<8} | {stats['passed']:<8} | {rate:6.2f}%")
    print("=" * 85)

    if res["failures"]:
        print(f"\n[!] Sample Edge-Case Discrepancies ({min(len(res['failures']), 10)} of {len(res['failures'])}):")
        for item, reason in res["failures"][:10]:
            print(f"  - [{item.category}] Typed: '{item.typed_token}' | {reason}")
    else:
        print("\n[✓] ZERO FAILURES! 100% SUCCESS ACROSS ENTIRE MASSIVE VOCABULARY.")
    print("=" * 85)

if __name__ == "__main__":
    trials = 10000
    if len(sys.argv) > 1:
        try:
            trials = int(sys.argv[1])
        except ValueError:
            pass

    print(f"==> Loading massive vocabularies from disk...")
    en_vocab, he_vocab, en_freq, he_freq = load_vocabularies()
    print(f"==> Loaded {len(en_vocab):,} English words and {len(he_vocab):,} Hebrew words.")
    print(f"==> Generating {trials:,} randomized typing stress test cases...")

    suite = build_massive_test_suite(en_vocab, he_vocab, en_freq, he_freq, sample_size=trials)
    engine = DecisionEngineSimulator(en_vocab, he_vocab)

    print(f"==> Running evaluation across {len(suite):,} test cases...")
    report = run_evaluation(engine, suite)
    print_detailed_report(report, len(en_vocab), len(he_vocab))

    if report["fp"] > 0:
        print("\nCRITICAL FAILURE: False positives detected! Valid words were corrupted.")
        sys.exit(1)
    sys.exit(0)
