import { useEffect, useState, type ReactNode } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import { translations, type Language, type TranslationKey } from "../lib/translations";
import { LanguageContext } from "./languageContextValue";

export function LanguageProvider({ children }: { children: ReactNode }) {
    const [language, setLanguage] = useState<Language>("English");
    const [loaded, setLoaded] = useState(false);

    useEffect(() => {
        async function loadLanguage() {
            try {
                const snap = await getDoc(doc(db, "businessSettings", "main"));
                if (snap.exists()) {
                    const data = snap.data();
                    if (data.language === "English" || data.language === "Malayalam") {
                        setLanguage(data.language);
                    }
                }
            } catch (err) {
                console.error("Failed to load language setting:", err);
            } finally {
                setLoaded(true);
            }
        }
        loadLanguage();
    }, []);

    function t(key: TranslationKey): string {
        return translations[language][key] ?? translations.English[key];
    }

    // Avoid a flash of English before the saved language loads
    if (!loaded) return null;

    return (
        <LanguageContext.Provider value={{ language, setLanguage, t }}>
            {children}
        </LanguageContext.Provider>
    );
}