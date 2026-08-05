export type Language = "English" | "Malayalam";

export const translations = {
    English: {
        // Sidebar sections
        overview: "Overview",
        peoples: "Peoples",
        operations: "Operations",
        finances: "Finances",
        // Sidebar links
        dashboard: "Dashboard",
        users: "Users",
        trainers: "Trainers",
        chats: "Chats",
        sessions: "Sessions",
        packages: "Packages",
        subscription: "Subscription",
        dietPlan: "Diet Plan",
        payments: "Payments",
        reports: "Reports",
        settings: "Settings",
        // Topbar
        searchPlaceholder: "Search clients, sessions...",
        // Common actions
        edit: "Edit",
        save: "Save",
        saving: "Saving...",
        cancel: "Cancel",
        logout: "Logout",
        loading: "Loading...",
    },
    Malayalam: {
        overview: "അവലോകനം",
        peoples: "ആളുകൾ",
        operations: "പ്രവർത്തനങ്ങൾ",
        finances: "ധനകാര്യം",
        dashboard: "ഡാഷ്‌ബോർഡ്",
        users: "ഉപയോക്താക്കൾ",
        trainers: "പരിശീലകർ",
        chats: "ചാറ്റുകൾ",
        sessions: "സെഷനുകൾ",
        packages: "പാക്കേജുകൾ",
        subscription: "സബ്സ്ക്രിപ്ഷൻ",
        dietPlan: "ഡയറ്റ് പ്ലാൻ",
        payments: "പേയ്‌മെന്റുകൾ",
        reports: "റിപ്പോർട്ടുകൾ",
        settings: "ക്രമീകരണങ്ങൾ",
        searchPlaceholder: "ക്ലയന്റുകൾ, സെഷനുകൾ തിരയുക...",
        edit: "എഡിറ്റ്",
        save: "സേവ് ചെയ്യുക",
        saving: "സേവ് ചെയ്യുന്നു...",
        cancel: "റദ്ദാക്കുക",
        logout: "ലോഗ് ഔട്ട്",
        loading: "ലോഡ് ചെയ്യുന്നു...",
    },
} as const;

export type TranslationKey = keyof typeof translations.English;