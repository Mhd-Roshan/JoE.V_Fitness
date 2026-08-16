import { useEffect, useState, useMemo } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";

interface SessionRow {
    id: string;
    dateObj: Date | null;
    time: string;
    trainer: string;
    client: string;
    service: string;
    status: string;
    notes: string;
}

const PAGE_SIZE = 5;

export default function Sessions() {
    const [allSessions, setAllSessions] = useState<SessionRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [page, setPage] = useState(1);
    const [activeTab, setActiveTab] = useState<"Today" | "This Week" | "Rescheduled">("Today");

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(collection(db, "sessions"));
                if (cancelled) return;

                const rows: SessionRow[] = snap.docs.map((d) => {
                    const data = d.data();

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
                        status: data.status || "",
                        notes: data.notes || data.trainerNotes || data.sessionNotes || "",
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

    const totalPages = Math.max(1, Math.ceil(filteredSessions.length / PAGE_SIZE));
    const pageRows = filteredSessions.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    if (loading) {
        return (
            <Layout title="All Sessions">
                <p style={{ color: "#999", padding: "24px" }}>Loading sessions...</p>
            </Layout>
        );
    }

    return (
        <Layout title="All Sessions">
            {/* TOP HEADER SECTION */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "24px" }}>
                <div>
                    <h2 style={{ margin: 0, fontSize: "1.25rem", color: "#1e293b", fontWeight: 700 }}>
                        Sessions Management
                    </h2>
                    <p style={{ margin: "4px 0 0 0", color: "#64748b", fontSize: "0.875rem" }}>
                        Monitor real-time training activity and trainer notes.
                    </p>
                </div>

                {/* UPDATED SEGMENTED CONTROL TO MATCH DESIGN */}
                <div style={{
                    display: "flex",
                    border: "1px solid #cbd5e1", // Light border
                    borderRadius: "10px",        // Rounded outer container
                    padding: "4px",              // Padding creates the gap between border and active tab
                    backgroundColor: "#ffffff",
                    gap: "4px"                   // Small gap between buttons
                }}>
                    {(["Today", "This Week", "Rescheduled"] as const).map((tab) => (
                        <button
                            key={tab}
                            onClick={() => {
                                setActiveTab(tab);
                                setPage(1);
                            }}
                            style={{
                                padding: "6px 16px",
                                border: "none",
                                outline: "none",
                                cursor: "pointer",
                                fontSize: "0.875rem",
                                fontWeight: 500,
                                borderRadius: "6px", // Inner button rounding
                                // Dark navy for active background, transparent for inactive
                                backgroundColor: activeTab === tab ? "#0a1930" : "transparent",
                                // White text for active, dark navy text for inactive
                                color: activeTab === tab ? "#ffffff" : "#0a1930",
                                transition: "all 0.2s ease"
                            }}
                        >
                            {tab}
                        </button>
                    ))}
                </div>
            </div>

            {/* TABLE CARD */}
            <div style={{
                backgroundColor: "#fff",
                border: "1px solid #e2e8f0",
                borderRadius: "12px",
                boxShadow: "0 1px 3px rgba(0,0,0,0.05)",
                overflow: "hidden"
            }}>
                {/* CARD HEADER */}
                <div style={{
                    padding: "16px 24px",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    borderBottom: "1px solid #e2e8f0"
                }}>
                    <h3 style={{ margin: 0, fontSize: "1.1rem", color: "#002069ff", fontWeight: 700 }}>
                        {activeTab} Sessions
                    </h3>
                    <button style={{
                        background: "none",
                        border: "none",
                        color: "#ef4444",
                        fontSize: "0.875rem",
                        fontWeight: 600,
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "6px"
                    }}>
                        <i className="bx bx-filter-alt" /> Filter View
                    </button>
                </div>

                {/* TABLE */}
                <div style={{ overflowX: "auto" }}>
                    <table style={{ width: "100%", borderCollapse: "collapse", minWidth: "800px" }}>
                        <thead>
                            <tr style={{ borderBottom: "1px solid #e2e8f0" }}>
                                {["TIME", "TRAINER", "CLIENT", "SERVICE", "STATUS", "NOTES"].map((header) => (
                                    <th key={header} style={{
                                        padding: "16px 24px",
                                        textAlign: "left",
                                        fontSize: "0.75rem",
                                        fontWeight: 700,
                                        color: "#475569",
                                        textTransform: "uppercase",
                                        letterSpacing: "0.05em"
                                    }}>
                                        {header}
                                    </th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {pageRows.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ padding: "32px", textAlign: "center", color: "#94a3b8", fontSize: "0.875rem" }}>
                                        No sessions found for {activeTab.toLowerCase()}.
                                    </td>
                                </tr>
                            ) : (
                                pageRows.map((row) => (
                                    <tr key={row.id} style={{ borderBottom: "1px solid #f1f5f9" }}>
                                        <td style={{
                                            padding: "16px 24px",
                                            fontSize: "0.875rem",
                                            fontWeight: 600,
                                            color: "#475569"
                                        }}>
                                            {activeTab === "This Week" && row.dateObj ? (
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                                                    <span style={{ fontSize: '0.7rem', color: '#94a3b8', textTransform: 'uppercase' }}>
                                                        {row.dateObj.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                                                    </span>
                                                    <span>{row.time}</span>
                                                </div>
                                            ) : (
                                                row.time
                                            )}
                                        </td>
                                        <td style={{ padding: "16px 24px", fontSize: "0.875rem", color: "#475569" }}>
                                            {row.trainer}
                                        </td>
                                        <td style={{ padding: "16px 24px", fontSize: "0.875rem", color: "#1e3a8a", fontWeight: 600 }}>
                                            {row.client}
                                        </td>
                                        <td style={{ padding: "16px 24px" }}>
                                            <span style={{
                                                backgroundColor: "#e0e7ff",
                                                color: "#6366f1",
                                                padding: "4px 10px",
                                                borderRadius: "50px",
                                                fontSize: "0.7rem",
                                                fontWeight: 700,
                                                textTransform: "uppercase"
                                            }}>
                                                {row.service}
                                            </span>
                                        </td>
                                        <td style={{ padding: "16px 24px" }}>
                                            {row.status && (
                                                <span style={{
                                                    backgroundColor: row.status.toLowerCase() === "done" ? "#dcfce7" :
                                                        row.status.toLowerCase() === "rescheduled" ? "#ffedd5" : "#f1f5f9",
                                                    color: row.status.toLowerCase() === "done" ? "#22c55e" :
                                                        row.status.toLowerCase() === "rescheduled" ? "#f97316" : "#475569",
                                                    padding: "4px 10px",
                                                    borderRadius: "4px",
                                                    fontSize: "0.75rem",
                                                    fontWeight: 600
                                                }}>
                                                    {row.status}
                                                </span>
                                            )}
                                        </td>
                                        <td style={{ padding: "16px 24px", fontSize: "0.875rem", color: "#64748b" }}>
                                            {row.notes}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>

                {/* CARD FOOTER (PAGINATION) */}
                <div style={{
                    padding: "16px 24px",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    borderTop: "1px solid #e2e8f0"
                }}>
                    <span style={{ fontSize: "0.875rem", color: "#64748b" }}>
                        Showing {pageRows.length} of {filteredSessions.length} sessions
                    </span>

                    <div style={{ display: "flex", gap: "8px" }}>
                        <button
                            disabled={page === 1}
                            onClick={() => setPage((p) => Math.max(1, p - 1))}
                            style={{
                                width: "32px",
                                height: "32px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                border: "1px solid #e2e8f0",
                                borderRadius: "6px",
                                backgroundColor: "#fff",
                                cursor: page === 1 ? "not-allowed" : "pointer",
                                color: "#64748b"
                            }}
                        >
                            <i className="bx bx-chevron-left" />
                        </button>
                        <button
                            disabled={page === totalPages || filteredSessions.length === 0}
                            onClick={() => setPage((p) => Math.max(totalPages, p + 1))}
                            style={{
                                width: "32px",
                                height: "32px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                border: "1px solid #e2e8f0",
                                borderRadius: "6px",
                                backgroundColor: "#fff",
                                cursor: (page === totalPages || filteredSessions.length === 0) ? "not-allowed" : "pointer",
                                color: "#64748b"
                            }}
                        >
                            <i className="bx bx-chevron-right" />
                        </button>
                    </div>
                </div>
            </div>
        </Layout>
    );
}