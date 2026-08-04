import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { signOut } from "firebase/auth";
import { auth } from "../lib/firebase";
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

    async function handleSignOut() {
        await signOut(auth);
        navigate("/login");
    }

    return (
        <div className="app-shell">
            <Sidebar />
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
                <header className="topbar">
                    <h1 className="topbar-title">{title}</h1>
                    <div className="topbar-right">
                        <input className="topbar-search" placeholder="Search clients, sessions..." />
                        <div className="topbar-bell">
                            <i className="bx bx-bell" />
                            <span className="topbar-bell-dot" />
                        </div>
                        <button className="topbar-avatar" onClick={handleSignOut} title="Sign out">
                            <span className="topbar-avatar-initials">SJ</span>
                            <i className="bx bx-log-out topbar-avatar-logout" />
                        </button>
                    </div>
                </header>
                <main className="dashboard-content">{children}</main>
            </div>
        </div>
    );
}