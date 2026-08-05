import { createContext } from "react";
import type { Language, TranslationKey } from "../lib/translations";

export interface LanguageContextValue {
    language: Language;
    setLanguage: (lang: Language) => void;
    t: (key: TranslationKey) => string;
}

export const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);