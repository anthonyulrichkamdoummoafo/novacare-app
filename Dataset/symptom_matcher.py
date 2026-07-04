"""
Natural-language symptom extraction.

The original extract_symptoms_from_text() did a literal substring check of
underscored column names (e.g. "high_fever") against raw user text. That
only works if the user happens to type the exact underscored token, which
essentially never happens in real sentences - "I have a fever" would not
match "high_fever" or "mild_fever" at all.

This module fixes that in three layers, applied in order for each column:
  1. Direct phrase match: underscores -> spaces, known typos cleaned up,
     matched with word boundaries (so "feet" doesn't match "feetball").
  2. Synonym match: common everyday phrasing mapped to the column(s) it
     should imply (e.g. "fever" -> high_fever/mild_fever, "throwing up"
     -> vomiting).
  3. Fuzzy match (optional, off by default): catches minor typos using
     difflib, useful for free-text but can over-match on short words so
     it's conservative (only single-word columns, high similarity cutoff).
"""
import re
import difflib

# Columns as they appear in Training_with_Urgency.csv, with their raw quirks
# (stray spaces, "feets" instead of "feet", etc.) already cleaned up here for
# matching purposes only - the canonical column name used to build the model
# input vector is unaffected by this module.
_TYPO_FIXES = {
    "toxic_look_(typhos)": "toxic look",
    "fluid_overload.1": "fluid overload",
}

# Common everyday phrasing -> one or more column names it should activate.
# Keys are checked as whole-word/phrase matches against the input text.
SYMPTOM_SYNONYMS = {
    "fever": ["high_fever", "mild_fever"],
    "high temperature": ["high_fever"],
    "temperature": ["high_fever", "mild_fever"],
    "throwing up": ["vomiting"],
    "vomit": ["vomiting"],
    "diarrhea": ["diarrhoea"],
    "runny tummy": ["diarrhoea"],
    "stomach ache": ["stomach_pain", "abdominal_pain", "belly_pain"],
    "tummy pain": ["stomach_pain", "abdominal_pain", "belly_pain"],
    "tummy ache": ["stomach_pain", "abdominal_pain", "belly_pain"],
    "sore throat": ["throat_irritation", "patches_in_throat"],
    "blocked nose": ["congestion", "sinus_pressure"],
    "stuffy nose": ["congestion", "sinus_pressure"],
    "cold hands": ["cold_hands_and_feets"],
    "cold feet": ["cold_hands_and_feets"],
    "tired": ["fatigue", "lethargy"],
    "exhausted": ["fatigue", "lethargy"],
    "no energy": ["fatigue", "lethargy"],
    "dizzy": ["dizziness", "spinning_movements"],
    "lightheaded": ["dizziness"],
    "can't sleep": ["restlessness"],
    "trouble sleeping": ["restlessness"],
    "yellow skin": ["yellowish_skin"],
    "yellow eyes": ["yellowing_of_eyes"],
    "dark pee": ["dark_urine"],
    "dark urine": ["dark_urine"],
    "yellow pee": ["yellow_urine"],
    "peeing a lot": ["polyuria"],
    "urinating a lot": ["polyuria"],
    "painful urination": ["burning_micturition"],
    "burning pee": ["burning_micturition"],
    "itchy": ["itching", "internal_itching"],
    "skin rash": ["skin_rash"],
    "rash": ["skin_rash"],
    "joint pain": ["joint_pain"],
    "achy joints": ["joint_pain"],
    "back ache": ["back_pain"],
    "chest pain": ["chest_pain"],
    "shortness of breath": ["breathlessness"],
    "trouble breathing": ["breathlessness"],
    "can't breathe": ["breathlessness"],
    "racing heart": ["fast_heart_rate"],
    "heart racing": ["fast_heart_rate"],
    "palpitation": ["palpitations"],
    "weight loss": ["weight_loss"],
    "losing weight": ["weight_loss"],
    "weight gain": ["weight_gain"],
    "gaining weight": ["weight_gain"],
    "loss of appetite": ["loss_of_appetite"],
    "not hungry": ["loss_of_appetite"],
    "very hungry": ["excessive_hunger", "increased_appetite"],
    "always hungry": ["excessive_hunger", "increased_appetite"],
    "blurry vision": ["blurred_and_distorted_vision", "visual_disturbances"],
    "blurred vision": ["blurred_and_distorted_vision", "visual_disturbances"],
    "can't smell": ["loss_of_smell"],
    "lost my smell": ["loss_of_smell"],
    "neck pain": ["neck_pain"],
    "stiff neck": ["stiff_neck"],
    "knee pain": ["knee_pain"],
    "muscle pain": ["muscle_pain"],
    "muscle weakness": ["muscle_weakness"],
    "swollen legs": ["swollen_legs"],
    "swollen glands": ["swelled_lymph_nodes"],
    "cough": ["cough"],
    "headache": ["headache"],
    "head ache": ["headache"],
    "nausea": ["nausea"],
    "nauseous": ["nausea"],
    "constipated": ["constipation"],
    "chills": ["chills"],
    "shivering": ["shivering"],
    "sweating": ["sweating"],
    "night sweats": ["sweating"],
    "depressed": ["depression"],
    "anxious": ["anxiety"],
    "mood swings": ["mood_swings"],
    "irritable": ["irritability"],
    "acne": ["acne"],
    "pimples": ["pus_filled_pimples", "blackheads"],
}


def _build_column_phrases(columns):
    """Map each column name to a cleaned, matchable phrase (spaces, no typos)."""
    phrases = {}
    for col in columns:
        cleaned = _TYPO_FIXES.get(col, col.replace("_", " "))
        cleaned = re.sub(r"\s+", " ", cleaned).strip().lower()
        phrases[col] = cleaned
    return phrases


def _phrase_in_text(phrase, text):
    """Whole-word/phrase match so short words don't match inside other words."""
    if not phrase:
        return False
    pattern = r"\b" + re.escape(phrase) + r"\b"
    return re.search(pattern, text) is not None


def extract_symptoms_from_text(user_text, columns, use_fuzzy=True, fuzzy_cutoff=0.85):
    """
    Extract known symptom column names from free-form user text.

    Returns a sorted list of column names (matching the model's expected
    feature names) found in the text, using direct phrase matching first,
    then synonyms, then optional conservative fuzzy matching for typos.
    """
    text = (user_text or "").lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)  # strip punctuation
    text = re.sub(r"\s+", " ", text).strip()

    found = set()
    column_phrases = _build_column_phrases(columns)

    # 1. Direct phrase match against cleaned column names
    for col, phrase in column_phrases.items():
        if _phrase_in_text(phrase, text):
            found.add(col)

    # 2. Synonym match
    for synonym, mapped_cols in SYMPTOM_SYNONYMS.items():
        if _phrase_in_text(synonym, text):
            for col in mapped_cols:
                if col in columns:
                    found.add(col)

    # 3. Conservative fuzzy match for single-word columns only (avoids
    # over-matching multi-word phrases where partial similarity is noisy).
    if use_fuzzy:
        words = text.split()
        single_word_cols = {
            col: phrase for col, phrase in column_phrases.items()
            if " " not in phrase
        }
        single_word_synonyms = {
            synonym: mapped_cols for synonym, mapped_cols in SYMPTOM_SYNONYMS.items()
            if " " not in synonym
        }
        for word in words:
            if len(word) < 4:
                continue  # too short to fuzzy match reliably
            matches = difflib.get_close_matches(
                word, single_word_cols.values(), n=1, cutoff=fuzzy_cutoff
            )
            if matches:
                for col, phrase in single_word_cols.items():
                    if phrase == matches[0]:
                        found.add(col)
                        break
            syn_matches = difflib.get_close_matches(
                word, single_word_synonyms.keys(), n=1, cutoff=fuzzy_cutoff
            )
            if syn_matches:
                for syn_col in single_word_synonyms[syn_matches[0]]:
                    if syn_col in columns:
                        found.add(syn_col)

    return sorted(found)
