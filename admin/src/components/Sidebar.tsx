import { NavLink } from "react-router-dom";
import "../styles/dashboard.css";
import documentFrom1 from "../assets/Document from محمد روشان.png";

interface NavItem {
    to: string;
    label: string;
    icon: string; // Boxicons class suffix, e.g. "bx-grid-alt"
}

interface NavGroup {
    label: string;
    items: NavItem[];
}

const navGroups: NavGroup[] = [
    {
        label: "Overview",
        items: [{ to: "/", label: "Dashboard", icon: "bx-grid-alt" }],
    },
    {
        label: "Peoples",
        items: [
            { to: "/users", label: "Users", icon: "bx-user" },
            { to: "/trainers", label: "Trainers", icon: "bx-run" },
            { to: "/chats", label: "Chats", icon: "bx-chat" },
        ],
    },
    {
        label: "Operations",
        items: [
            { to: "/sessions", label: "Sessions", icon: "bx-calendar" },
            { to: "/packages", label: "Packages", icon: "bx-package" },
            { to: "/subscriptions", label: "Subscription", icon: "bx-credit-card" },
            { to: "/diet-plans", label: "Diet Plan", icon: "bx-restaurant" },
        ],
    },
    {
        label: "Finances",
        items: [
            { to: "/payments", label: "Payments", icon: "bx-wallet" },
            { to: "/reports", label: "Reports", icon: "bx-line-chart" },
            { to: "/settings", label: "Settings", icon: "bx-cog" },
        ],
    },
];

export default function Sidebar() {
    return (
        <aside className="sidebar">
            <div className="sidebar-logo-band">
                <img className="sidebar-logo-img" src={documentFrom1} alt="JoE.V" />
                <div className="sidebar-logo-text">
                    <span className="sidebar-logo-joev">
                        JoE
                        <svg
                            className="kettlebell-icon"
                            viewBox="0 0 100 106"
                            fill="none"
                            xmlns="http://www.w3.org/2000/svg"
                            aria-hidden="true"
                        >
                            {/* Kettlebell body + handle single path */}
                            <path
                                fillRule="evenodd"
                                clipRule="evenodd"
                                d="
                                    M 50 4
                                    C 28 4 18 14 18 34
                                    C 18 44 10 56 10 72
                                    C 10 92 22 102 36 102
                                    L 64 102
                                    C 78 102 90 92 90 72
                                    C 90 56 82 44 82 34
                                    C 82 14 72 4 50 4 Z

                                    M 50 16
                                    C 63 16 68 22 68 32
                                    C 68 40 60 43 50 43
                                    C 40 43 32 40 32 32
                                    C 32 22 37 16 50 16 Z
                                "
                                fill="#00225d"
                            />
                            {/* Curved shine highlight on top-right of ball */}
                            <path
                                d="M 64 56 C 74 63 78 74 76 84"
                                stroke="#01bce3"
                                strokeWidth="4.5"
                                strokeLinecap="round"
                                fill="none"
                            />
                        </svg>
                        V
                    </span>
                    <span className="sidebar-logo-fitness">FITNESS</span>
                </div>
            </div>

            <nav className="sidebar-nav">
                {navGroups.map((group) => (
                    <div key={group.label}>
                        <div className="sidebar-group-label">{group.label}</div>
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
                                {item.label}
                            </NavLink>
                        ))}
                    </div>
                ))}
            </nav>
        </aside>
    );
}