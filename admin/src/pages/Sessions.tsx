import { useEffect, useState, useMemo } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/sessions.css";

interface SessionRow {
    id: string;
    clientId: string;
    userId: string;
    dateObj: Date | null;
    formattedDate: string;
    time: string;
    trainer: string;
    client: string;
    service: string;
    status: string;
    notes: string;
}

const PAGE_SIZE = 10;

function parseDateFlexible(val: unknown): Date | null {
    if (!val) return null;
    if (typeof (val as { toDate?: () => Date }).toDate === "function") {
        return (val as { toDate: () => Date }).toDate();
    }
    if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
    if (typeof val === "number") {
        const ms = val < 10000000000 ? val * 1000 : val;
        const d = new Date(ms);
        return isNaN(d.getTime()) ? null : d;
    }
    if (typeof val === "string") {
        const s = val.trim();
        if (!s || s === "—") return null;

        const parsed = new Date(s);
        if (!isNaN(parsed.getTime())) return parsed;

        const isoMatch = s.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/);
        if (isoMatch) {
            const y = parseInt(isoMatch[1], 10);
            const m = parseInt(isoMatch[2], 10) - 1;
            const d = parseInt(isoMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }

        const dmyMatch = s.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})/);
        if (dmyMatch) {
            const d = parseInt(dmyMatch[1], 10);
            const m = parseInt(dmyMatch[2], 10) - 1;
            const y = parseInt(dmyMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }
    }
    return null;
}

export default function Sessions() {
    const { id: clientIdParam } = useParams<{ id?: string }>();
    const navigate = useNavigate();

    const [allSessions, setAllSessions] = useState<SessionRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [page, setPage] = useState(1);
    const [activeTab, setActiveTab] = useState<"Today" | "This Week" | "All" | "Rescheduled">(
        clientIdParam ? "All" : "Today"
    );
    const [filteredClientName, setFilteredClientName] = useState<string>("");

    // 1. Fetch Real Data from Firebase (both 'sessions' & 'bookings' collections)
    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const [sessionsSnap, bookingsSnap, usersSnap] = await Promise.all([
                    getDocs(collection(db, "sessions")),
                    getDocs(collection(db, "bookings")),
                    getDocs(collection(db, "users")),
                ]);

                if (cancelled) return;

                // Build client names map
                const userNamesMap: Record<string, string> = {};
                usersSnap.docs.forEach((uDoc) => {
                    const uData = uDoc.data();
                    const name = (uData.fullName || uData.name || "").toString().trim();
                    if (name) userNamesMap[uDoc.id] = name;
                });

                if (clientIdParam && userNamesMap[clientIdParam]) {
                    setFilteredClientName(userNamesMap[clientIdParam]);
                }

                // Merge & deduplicate
                const uniqueMap = new Map<string, Record<string, unknown>>();
                [...sessionsSnap.docs, ...bookingsSnap.docs].forEach((docSnap) => {
                    const data = docSnap.data() as Record<string, unknown>;
                    const key = (data.bookingId || data.sessionId || docSnap.id) as string;
                    if (!uniqueMap.has(key)) {
                        uniqueMap.set(key, { id: docSnap.id, ...data });
                    }
                });

                const rows: SessionRow[] = Array.from(uniqueMap.values()).map((data) => {
                    const rawDate = (data.scheduledDate ||
                        data.date ||
                        data.sessionDate ||
                        data.bookingDate ||
                        data.createdAt ||
                        data.timestamp) as unknown;

                    const dateObj = parseDateFlexible(rawDate);

                    const clientId = (data.clientId || data.userId || data.client_id || data.user_id || "") as string;
                    const userId = (data.userId || data.clientId || "") as string;

                    const client = (data.clientName ||
                        data.client ||
                        data.userName ||
                        data.name ||
                        (clientId ? userNamesMap[clientId] : "") ||
                        "—") as string;

                    const trainer = (data.trainerName ||
                        data.trainer ||
                        data.assignedTrainerName ||
                        "—") as string;

                    const service = (data.serviceType ||
                        data.sessionType ||
                        data.service ||
                        data.plan ||
                        "Personal Training") as string;

                    const status = (data.status || "Upcoming") as string;
                    const notes = (data.notes || data.trainerNotes || data.sessionNotes || "") as string;
                    const time = (data.time || data.startTime || data.scheduledTime || "—") as string;

                    const formattedDate = dateObj
                        ? dateObj.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })
                        : rawDate ? rawDate.toString() : "—";

                    return {
                        id: data.id as string,
                        clientId,
                        userId,
                        dateObj,
                        formattedDate,
                        time,
                        trainer,
                        client,
                        service,
                        status,
                        notes,
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
    }, [clientIdParam]);

    // 2. Filter Data based on Active Tab & optional Client Param
    const filteredSessions = useMemo(() => {
        const now = new Date();

        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000 - 1);

        const dayOfWeek = now.getDay();
        const weekStart = new Date(todayStart);
        weekStart.setDate(weekStart.getDate() - dayOfWeek);
        const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000 - 1);

        const filtered = allSessions.filter((session) => {
            // If viewing for a specific client
            if (clientIdParam) {
                const matchClient = session.clientId === clientIdParam || session.userId === clientIdParam;
                if (!matchClient) return false;
            }

            if (activeTab === "Rescheduled") {
                return session.status.toLowerCase() === "rescheduled";
            }

            if (activeTab === "All") {
                return true;
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

        // Sort: newest first for All/Rescheduled, chronological for Today/This Week
        return filtered.sort((a, b) => {
            const timeA = a.dateObj ? a.dateObj.getTime() : 0;
            const timeB = b.dateObj ? b.dateObj.getTime() : 0;
            if (activeTab === "Today" || activeTab === "This Week") {
                return timeA - timeB;
            }
            return timeB - timeA;
        });
    }, [allSessions, activeTab, clientIdParam]);

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
                    <h2 className="sessions-title">
                        {clientIdParam ? "Client Sessions" : "Sessions Management"}
                    </h2>
                    <p className="sessions-subtitle">
                        {clientIdParam
                            ? `Viewing all scheduled training sessions for ${filteredClientName || "client"}.`
                            : "Monitor real-time training activity, booked sessions, and trainer notes."}
                    </p>
                </div>

                {/* TABS */}
                <div className="sessions-tabs">
                    {(["Today", "This Week", "All", "Rescheduled"] as const).map((tab) => (
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

            {/* CLIENT FILTER BANNER */}
            {clientIdParam && (
                <div
                    style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        backgroundColor: "#f1f5f9",
                        border: "1px solid #cbd5e1",
                        borderRadius: "8px",
                        padding: "10px 16px",
                        marginBottom: "20px",
                    }}
                >
                    <span style={{ color: "#00225d", fontWeight: "600", fontSize: "14px", display: "flex", alignItems: "center", gap: "8px" }}>
                        <i className="bx bx-user-pin" style={{ fontSize: "18px", color: "#bb0013" }} />
                        Filtered for Client: <strong>{filteredClientName || clientIdParam}</strong>
                    </span>
                    <button
                        onClick={() => navigate("/sessions")}
                        style={{
                            background: "none",
                            border: "none",
                            color: "#bb0013",
                            fontWeight: "700",
                            fontSize: "13px",
                            cursor: "pointer",
                            display: "flex",
                            alignItems: "center",
                            gap: "4px",
                        }}
                    >
                        <i className="bx bx-x" style={{ fontSize: "18px" }} /> View All Clients
                    </button>
                </div>
            )}

            {/* TABLE CARD */}
            <div className="sessions-table-card">
                {/* TABLE HEADER */}
                <div className="sessions-table-header">
                    <h3 className="sessions-table-title">
                        {activeTab} Sessions ({filteredSessions.length})
                    </h3>
                </div>

                {/* TABLE */}
                <div style={{ overflowX: "auto" }}>
                    <table className="sessions-table">
                        <thead>
                            <tr>
                                <th>DATE & TIME</th>
                                <th>TRAINER</th>
                                <th>CLIENT</th>
                                <th>SERVICE</th>
                                <th>STATUS</th>
                                <th>NOTES</th>
                            </tr>
                        </thead>
                        <tbody>
                            {pageRows.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ textAlign: "center", color: "#94a3b8", padding: "30px 0" }}>
                                        No sessions found for {activeTab.toLowerCase()}.
                                    </td>
                                </tr>
                            ) : (
                                pageRows.map((row) => {
                                    const statusLower = row.status.toLowerCase();
                                    const statusClass =
                                        statusLower === "done" || statusLower === "completed"
                                            ? "done"
                                            : statusLower === "live"
                                            ? "live"
                                            : statusLower === "rescheduled"
                                            ? "rescheduled"
                                            : "upcoming";

                                    return (
                                        <tr key={row.id}>
                                            <td
                                                className="sessions-mono"
                                                style={{
                                                    color: statusLower === "live" ? "#bb0013" : "inherit",
                                                }}
                                            >
                                                <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                                                    <span style={{ fontSize: "11px", color: "#64748b", fontWeight: "600" }}>
                                                        {row.formattedDate}
                                                    </span>
                                                    <span style={{ fontWeight: "700" }}>{row.time}</span>
                                                </div>
                                            </td>
                                            <td>{row.trainer}</td>
                                            <td className="sessions-bold">{row.client}</td>
                                            <td>
                                                <span className="sessions-service-pill">{row.service}</span>
                                            </td>
                                            <td>
                                                <span className={`sessions-status-pill ${statusClass}`}>
                                                    {statusLower === "live" && <div className="live-dot"></div>}
                                                    {row.status}
                                                </span>
                                            </td>
                                            <td style={{ color: "#808080", fontSize: "13px" }}>
                                                {row.notes || "—"}
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>

                {/* CARD FOOTER (PAGINATION) */}
                <div
                    className="sessions-table-footer"
                    style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}
                >
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
                            <i className="bx bx-chevron-left" style={{ fontSize: "16px", verticalAlign: "middle" }} />
                        </button>
                        <button
                            disabled={page === totalPages || filteredSessions.length === 0}
                            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                            className="sessions-action-btn"
                            style={{ opacity: page === totalPages || filteredSessions.length === 0 ? 0.5 : 1 }}
                        >
                            <i className="bx bx-chevron-right" style={{ fontSize: "16px", verticalAlign: "middle" }} />
                        </button>
                    </div>
                </div>
            </div>
        </Layout>
    );
}