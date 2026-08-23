import { useEffect, useState, useMemo } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/sessions.css";

interface SessionRow {
    id: string;
    dateObj: Date | null;
    time: string;
    trainer: string;
    client: string;
    service: string;
    status: string;
    notes: string; // Reverted back to notes
}

const PAGE_SIZE = 5;

export default function Sessions() {
    const [allSessions, setAllSessions] = useState<SessionRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [page, setPage] = useState(1);
    const [activeTab, setActiveTab] = useState<"Today" | "This Week" | "Rescheduled">("Today");

    // 1. Fetch Real Data from Firebase
    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(collection(db, "sessions"));
                if (cancelled) return;

                const rows: SessionRow[] = snap.docs.map((d) => {
                    const data = d.data();

                    // Parse Date correctly (handles Firebase Timestamps or string dates)
                    let dateObj: Date | null = null;
                    const rawDate = data.date || data.sessionDate || data.createdAt;
                    if (rawDate) {
                        if (typeof rawDate.toDate === "function") {
                            dateObj = rawDate.toDate();
                        } else {
                            dateObj = new Date(rawDate);
                        }
                    }

                    return {
                        id: d.id,
                        dateObj,
                        time: data.time || "—",
                        trainer: data.trainerName || data.trainer || "—",
                        client: data.clientName || data.client || "—",
                        service: data.serviceType || data.service || "—",
                        status: data.status || "Upcoming",
                        notes: data.notes || data.trainerNotes || data.sessionNotes || "", // Pulling notes
                    };
                });

                setAllSessions(rows);
            } catch (err) {
                console.error("Sessions load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, []);

    // 2. Filter Data based on Active Tab
    const filteredSessions = useMemo(() => {
        const now = new Date();

        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000 - 1);

        const dayOfWeek = now.getDay();
        const weekStart = new Date(todayStart);
        weekStart.setDate(weekStart.getDate() - dayOfWeek);
        const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000 - 1);

        return allSessions.filter(session => {
            if (activeTab === "Rescheduled") {
                return session.status.toLowerCase() === "rescheduled";
            }

            if (!session.dateObj || isNaN(session.dateObj.getTime())) {
                return false;
            }

            if (activeTab === "Today") {
                return session.dateObj >= todayStart && session.dateObj <= todayEnd;
            }

            if (activeTab === "This Week") {
                return session.dateObj >= weekStart && session.dateObj <= weekEnd;
            }

            return true;
        });
    }, [allSessions, activeTab]);

    // Pagination Logic
    const totalPages = Math.max(1, Math.ceil(filteredSessions.length / PAGE_SIZE));
    const pageRows = filteredSessions.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    if (loading) {
        return (
            <Layout title="All Sessions">
                <div className="empty-state">Loading sessions...</div>
            </Layout>
        );
    }

    return (
        <Layout title="All Sessions">

            {/* TOP HEADER SECTION */}
            <div className="sessions-header">
                <div>
                    <h2 className="sessions-title">Sessions Management</h2>
                    <p className="sessions-subtitle">
                        Monitor real-time training activity and trainer notes.
                    </p>
                </div>

                {/* TABS */}
                <div className="sessions-tabs">
                    {(["Today", "This Week", "Rescheduled"] as const).map((tab) => (
                        <button
                            key={tab}
                            onClick={() => {
                                setActiveTab(tab);
                                setPage(1);
                            }}
                            className={`sessions-tab-btn ${activeTab === tab ? "active" : ""}`}
                        >
                            {tab}
                        </button>
                    ))}
                </div>
            </div>

            {/* TABLE CARD */}
            <div className="sessions-table-card">

                {/* TABLE HEADER */}
                <div className="sessions-table-header">
                    <h3 className="sessions-table-title">All Sessions</h3>
                    <button
                        className="sessions-action-btn"
                        style={{ border: "none", color: "#bb0013", display: "flex", alignItems: "center", gap: "6px", fontWeight: "700" }}
                    >
                        <i className="bx bx-filter-alt" /> Filter View
                    </button>
                </div>

                {/* TABLE */}
                <div style={{ overflowX: "auto" }}>
                    <table className="sessions-table">
                        <thead>
                            <tr>
                                <th>TIME</th>
                                <th>TRAINER</th>
                                <th>CLIENT</th>
                                <th>SERVICE</th>
                                <th>STATUS</th>
                                <th>NOTES</th> {/* Changed back to NOTES */}
                            </tr>
                        </thead>
                        <tbody>
                            {pageRows.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ textAlign: "center", color: "#94a3b8" }}>
                                        No sessions found for {activeTab.toLowerCase()}.
                                    </td>
                                </tr>
                            ) : (
                                pageRows.map((row) => {
                                    const statusLower = row.status.toLowerCase();
                                    // Map string status to the CSS classes from your provided stylesheet
                                    const statusClass =
                                        statusLower === "done" ? "done" :
                                            statusLower === "live" ? "live" : "upcoming";

                                    return (
                                        <tr key={row.id}>
                                            <td className="sessions-mono" style={{ color: statusLower === 'live' || row.time.includes('10:00') ? '#bb0013' : 'inherit' }}>
                                                {activeTab === "This Week" && row.dateObj ? (
                                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                                                        <span style={{ fontSize: '10px', color: '#808080', textTransform: 'uppercase' }}>
                                                            {row.dateObj.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                                                        </span>
                                                        <span>{row.time}</span>
                                                    </div>
                                                ) : (
                                                    row.time
                                                )}
                                            </td>
                                            <td>{row.trainer}</td>
                                            <td className="sessions-bold">{row.client}</td>
                                            <td>
                                                <span className="sessions-service-pill">
                                                    {row.service}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`sessions-status-pill ${statusClass}`}>
                                                    {statusLower === "live" && <div className="live-dot"></div>}
                                                    {row.status}
                                                </span>
                                            </td>
                                            <td style={{ color: "#808080", fontSize: "13px" }}>
                                                {row.notes} {/* Renders Notes */}
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>

                {/* CARD FOOTER (PAGINATION) */}
                <div className="sessions-table-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>
                        Showing {pageRows.length} of {filteredSessions.length} sessions
                    </span>

                    <div style={{ display: "flex", gap: "8px" }}>
                        <button
                            disabled={page === 1}
                            onClick={() => setPage((p) => Math.max(1, p - 1))}
                            className="sessions-action-btn"
                            style={{ opacity: page === 1 ? 0.5 : 1 }}
                        >
                            <i className="bx bx-chevron-left" style={{ fontSize: '16px', verticalAlign: 'middle' }} />
                        </button>
                        <button
                            disabled={page === totalPages || filteredSessions.length === 0}
                            onClick={() => setPage((p) => Math.max(totalPages, p + 1))}
                            className="sessions-action-btn"
                            style={{ opacity: (page === totalPages || filteredSessions.length === 0) ? 0.5 : 1 }}
                        >
                            <i className="bx bx-chevron-right" style={{ fontSize: '16px', verticalAlign: 'middle' }} />
                        </button>
                    </div>
                </div>
            </div>
        </Layout>
    );
}