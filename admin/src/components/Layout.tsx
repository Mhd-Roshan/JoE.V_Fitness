import { useEffect, useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import { db } from "../lib/firebase";
import { useLanguage } from "../contexts/useLanguage";
import Sidebar from "./Sidebar";
import "../styles/dashboard.css";

export default function Layout({
    title,
    children,
}: {
    title: string;
    children: ReactNode;
}) {
    const navigate = useNavigate();
    const { t } = useLanguage();
    const [hasUnread, setHasUnread] = useState(false);

    useEffect(() => {
        const q = query(collection(db, "notifications"), where("read", "==", false));
        const unsub = onSnapshot(
            q,
            (snap) => setHasUnread(!snap.empty),
            (err) => console.error("Unread notifications check failed:", err)
        );
        return () => unsub();
    }, []);

    return (
        <div className="app-shell">
            <Sidebar />
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
                <header className="topbar">
                    <h1 className="topbar-title">{title}</h1>
                    <div className="topbar-right">
                        <input
                            className="topbar-search"
                            placeholder={t("searchPlaceholder")}
                        />
                        <button
                            className="topbar-bell"
                            onClick={() => navigate("/notifications")}
                            title="Notifications"
                        >
                            <i className="bx bx-bell" />
                            {hasUnread && <span className="topbar-bell-dot" />}
                        </button>
                        <button
                            className="topbar-avatar"
                            onClick={() => navigate("/settings")}
                            title="Settings"
                        >
                            <span className="topbar-avatar-initials">SJ</span>
                        </button>
                    </div>
                </header>
                <main className="dashboard-content">{children}</main>
            </div>
        </div>
    );
}