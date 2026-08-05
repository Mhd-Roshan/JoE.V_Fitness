import { NavLink } from "react-router-dom";
import "../styles/dashboard.css";
import documentFrom1 from "../assets/Document from محمد روشان.png";
import kettlebellIcon from "../assets/kettlebell-icon.svg";
import { useLanguage } from "../contexts/useLanguage";
import type { TranslationKey } from "../lib/translations";

interface NavItem {
    to: string;
    labelKey: TranslationKey;
    icon: string; // Boxicons class suffix, e.g. "bx-grid-alt"
}

interface NavGroup {
    labelKey: TranslationKey;
    items: NavItem[];
}

const navGroups: NavGroup[] = [
    {
        labelKey: "overview",
        items: [{ to: "/", labelKey: "dashboard", icon: "bx-grid-alt" }],
    },
    {
        labelKey: "peoples",
        items: [
            { to: "/users", labelKey: "users", icon: "bx-user" },
            { to: "/trainers", labelKey: "trainers", icon: "bx-run" },
            { to: "/chats", labelKey: "chats", icon: "bx-chat" },
        ],
    },
    {
        labelKey: "operations",
        items: [
            { to: "/sessions", labelKey: "sessions", icon: "bx-calendar" },
            { to: "/packages", labelKey: "packages", icon: "bx-package" },
            { to: "/subscriptions", labelKey: "subscription", icon: "bx-credit-card" },
            { to: "/diet-plans", labelKey: "dietPlan", icon: "bx-restaurant" },
        ],
    },
    {
        labelKey: "finances",
        items: [
            { to: "/payments", labelKey: "payments", icon: "bx-wallet" },
            { to: "/reports", labelKey: "reports", icon: "bx-line-chart" },
            { to: "/settings", labelKey: "settings", icon: "bx-cog" },
        ],
    },
];

export default function Sidebar() {
    const { t } = useLanguage();

    return (
        <aside className="sidebar">
            <div className="sidebar-logo-band">
                <div className="sidebar-logo-badge">
                    <img className="sidebar-logo-img" src={documentFrom1} alt="Kettlebell" />
                </div>
                <div className="sidebar-logo-text">
                    <div className="sidebar-logo-title">
                        <span className="sidebar-logo-joe">JoE</span>
                        <img src={kettlebellIcon} className="sidebar-logo-kb-inline" alt="" />
                        <span className="sidebar-logo-v">V</span>
                    </div>
                    <span className="sidebar-logo-fitness">FITNESS</span>
                </div>
            </div>

            <nav className="sidebar-nav">
                {navGroups.map((group) => (
                    <div key={group.labelKey}>
                        <div className="sidebar-group-label">{t(group.labelKey)}</div>
                        {group.items.map((item) => (
                            <NavLink
                                key={item.to}
                                to={item.to}
                                end={item.to === "/"}
                                className={({ isActive }) =>
                                    `sidebar-item${isActive ? " active" : ""}`
                                }
                            >
                                <i className={`bx ${item.icon} sidebar-item-icon`} />
                                {t(item.labelKey)}
                            </NavLink>
                        ))}
                    </div>
                ))}
            </nav>
        </aside>
    );
}