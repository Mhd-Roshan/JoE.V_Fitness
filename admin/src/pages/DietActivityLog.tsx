import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/dietActivityLog.css";

interface ActivityRow {
    id: string;
    clientId?: string;
    clientName: string;
    clientPhoto?: string | null;
    clientInitials: string;
    action: "Assigned Protocol" | "Template Created" | "Template Updated" | "Meal Logged" | "Status Changed";
    actionType: "assigned" | "created" | "updated" | "logged";
    protocolName: string;
    trainerName: string;
    timestamp: Date | null;
    status: string;
}

const PAGE_SIZE = 10;

function fmtTimestamp(d: Date | null): string {
    if (!d) return "—";
    return d.toLocaleString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
    });
}

export default function DietActivityLog() {
    const navigate = useNavigate();
    const [rows, setRows] = useState<ActivityRow[]>([]);
    const [loading, setLoading] = useState(true);

    // Filters
    const [searchTerm, setSearchTerm] = useState("");
    const [dateRange, setDateRange] = useState("all");
    const [trainerFilter, setTrainerFilter] = useState("all");
    const [protocolFilter, setProtocolFilter] = useState("all");
    const [page, setPage] = useState(1);

    useEffect(() => {
        let isMounted = true;

        async function loadActivityData() {
            try {
                // 1. Fetch Users, ClientDietPlans, Templates, and explicit Activity concurrently
                const [usersSnap, assignSnap, templatesSnap, directActivitySnap] = await Promise.all([
                    getDocs(collection(db, "users")),
                    getDocs(collection(db, "clientDietPlans")),
                    getDocs(collection(db, "dietPlanTemplates")),
                    getDocs(collection(db, "dietPlanActivity")),
                ]);

                if (!isMounted) return;

                // 2. Build User Map
                const usersMap = new Map<string, { name: string; photo?: string | null }>();
                usersSnap.docs.forEach((d) => {
                    const u = d.data();
                    const name = (u.fullName || u.name || u.displayName || "Client").toString();
                    usersMap.set(d.id, {
                        name,
                        photo: u.photoURL || u.profileImage || null,
                    });
                });

                const allActivities: ActivityRow[] = [];

                // 3. Process direct activities if any exist
                directActivitySnap.docs.forEach((d) => {
                    const data = d.data();
                    const cId = data.clientId || data.userId || "";
                    const uInfo = usersMap.get(cId);
                    const name = uInfo?.name || data.clientName || "Client";
                    const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : (data.timestamp?.toDate ? data.timestamp.toDate() : null);

                    allActivities.push({
                        id: `direct-${d.id}`,
                        clientId: cId || undefined,
                        clientName: name,
                        clientPhoto: uInfo?.photo || data.clientPhoto || null,
                        clientInitials: name.split(" ").map((p: string) => p[0]).join("").slice(0, 2).toUpperCase(),
                        action: (data.action || "Assigned Protocol") as ActivityRow["action"],
                        actionType: (data.actionType || "assigned") as ActivityRow["actionType"],
                        protocolName: data.protocolName || data.templateName || "Nutrition Protocol",
                        trainerName: data.trainerName || "Head Coach / Admin",
                        timestamp: createdAt,
                        status: data.status || "active",
                    });
                });

                // 4. Process Client Diet Plan Assignments
                assignSnap.docs.forEach((d) => {
                    const data = d.data();
                    const cId = data.clientId || data.userId || "";
                    const uInfo = usersMap.get(cId);
                    const name = uInfo?.name || data.clientName || "Client";
                    const assignedAt = data.assignedAt?.toDate ? data.assignedAt.toDate() : (data.createdAt?.toDate ? data.createdAt.toDate() : null);

                    allActivities.push({
                        id: `assign-${d.id}`,
                        clientId: cId || undefined,
                        clientName: name,
                        clientPhoto: uInfo?.photo || data.clientPhoto || null,
                        clientInitials: name.split(" ").map((p: string) => p[0]).join("").slice(0, 2).toUpperCase(),
                        action: "Assigned Protocol",
                        actionType: "assigned",
                        protocolName: data.templateName || data.name || "Custom Meal Plan",
                        trainerName: data.trainerName || data.assignedBy || "Head Coach / Admin",
                        timestamp: assignedAt,
                        status: data.status || "active",
                    });
                });

                // 5. Process Template Creation / Updates
                templatesSnap.docs.forEach((d) => {
                    const data = d.data();
                    const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : null;
                    const updatedAt = data.updatedAt?.toDate ? data.updatedAt.toDate() : createdAt;

                    allActivities.push({
                        id: `tpl-${d.id}`,
                        clientName: "Template Protocol",
                        clientPhoto: null,
                        clientInitials: "TP",
                        action: (updatedAt && createdAt && updatedAt.getTime() > createdAt.getTime()) ? "Template Updated" : "Template Created",
                        actionType: (updatedAt && createdAt && updatedAt.getTime() > createdAt.getTime()) ? "updated" : "created",
                        protocolName: data.name || "Meal Protocol",
                        trainerName: data.creatorName || "Head Coach / Admin",
                        timestamp: updatedAt || createdAt || new Date(),
                        status: "active",
                    });
                });

                // Sort by newest timestamp first
                allActivities.sort((a, b) => {
                    const tA = a.timestamp ? a.timestamp.getTime() : 0;
                    const tB = b.timestamp ? b.timestamp.getTime() : 0;
                    return tB - tA;
                });

                if (isMounted) {
                    setRows(allActivities);
                    setLoading(false);
                }
            } catch (err) {
                console.error("Error loading Diet Activity log:", err);
                if (isMounted) setLoading(false);
            }
        }

        loadActivityData();

        return () => {
            isMounted = false;
        };
    }, []);

    // Filter Options
    const trainers = Array.from(new Set(rows.map((r) => r.trainerName).filter((t) => Boolean(t) && t !== "—")));
    const protocols = Array.from(new Set(rows.map((r) => r.protocolName).filter(Boolean)));

    // Filtering
    const filtered = rows.filter((r) => {
        // Date Range
        if (dateRange !== "all" && r.timestamp) {
            const days = Number(dateRange);
            const cutoff = new Date();
            cutoff.setDate(cutoff.getDate() - days);
            if (r.timestamp < cutoff) return false;
        }

        // Trainer Filter
        if (trainerFilter !== "all" && r.trainerName !== trainerFilter) return false;

        // Protocol Filter
        if (protocolFilter !== "all" && r.protocolName !== protocolFilter) return false;

        // Search Term
        if (searchTerm.trim()) {
            const q = searchTerm.toLowerCase().trim();
            const matchClient = r.clientName.toLowerCase().includes(q);
            const matchProto = r.protocolName.toLowerCase().includes(q);
            const matchTrainer = r.trainerName.toLowerCase().includes(q);
            const matchAction = r.action.toLowerCase().includes(q);
            if (!matchClient && !matchProto && !matchTrainer && !matchAction) return false;
        }

        return true;
    });

    // Metric Calculations
    const newProtocolsCount = rows.filter((r) => r.actionType === "created" || r.actionType === "assigned").length;
    const now = new Date();
    const updatedTodayCount = rows.filter((r) => {
        if (!r.timestamp) return false;
        return (
            r.timestamp.getDate() === now.getDate() &&
            r.timestamp.getMonth() === now.getMonth() &&
            r.timestamp.getFullYear() === now.getFullYear()
        );
    }).length;
    const activeClientsCount = new Set(
        rows.filter((r) => r.clientId && r.status === "active").map((r) => r.clientName)
    ).size;
    const totalEventsCount = rows.length;

    // Pagination
    const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    const pageRows = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    // CSV Export
    function handleExport() {
        const header = ["Client Name", "Action", "Protocol Name", "Trainer / Author", "Timestamp", "Status"];
        const csvRows = filtered.map((r) => [
            r.clientName,
            r.action,
            r.protocolName,
            r.trainerName,
            fmtTimestamp(r.timestamp),
            r.status,
        ]);
        const csv = [header, ...csvRows]
            .map((row) => row.map((c) => `"${(c || "").replace(/"/g, '""')}"`).join(","))
            .join("\n");
        const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `diet-activity-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(url);
    }

    return (
        <Layout title="Diet Activity Log">
            <div className="activity-page">
                {/* BACK BUTTON */}
                <button className="back-btn-outlined" onClick={() => navigate("/diet-plans")}>
                    <i className="bx bx-arrow-back" /> Back to Diet Plans
                </button>

                {/* HEADER */}
                <div className="activity-header">
                    <h1 className="activity-title">Recent Nutrition &amp; Diet Activity</h1>
                    <p className="activity-subtitle">
                        Real-time audit log of nutrition assignments, template updates, and client meal progress.
                    </p>
                </div>

                {/* STATS ROW */}
                <div className="activity-stats-row">
                    <div className="activity-stat-card">
                        <div className="activity-stat-top">
                            <span className="activity-stat-label">NEW PROTOCOLS</span>
                            <div className="activity-stat-icon-badge blue">
                                <i className="bx bx-dish" />
                            </div>
                        </div>
                        <div className="activity-stat-value">{loading ? "…" : newProtocolsCount}</div>
                        <div className="activity-stat-footnote">Active templates &amp; plans</div>
                    </div>

                    <div className="activity-stat-card">
                        <div className="activity-stat-top">
                            <span className="activity-stat-label">UPDATED TODAY</span>
                            <div className="activity-stat-icon-badge emerald">
                                <i className="bx bx-check-circle" />
                            </div>
                        </div>
                        <div className="activity-stat-value">{loading ? "…" : updatedTodayCount}</div>
                        <div className="activity-stat-footnote">Live modifications today</div>
                    </div>

                    <div className="activity-stat-card">
                        <div className="activity-stat-top">
                            <span className="activity-stat-label">ACTIVE CLIENTS</span>
                            <div className="activity-stat-icon-badge purple">
                                <i className="bx bx-user-check" />
                            </div>
                        </div>
                        <div className="activity-stat-value">{loading ? "…" : activeClientsCount}</div>
                        <div className="activity-stat-footnote">Clients on active diet plans</div>
                    </div>

                    <div className="activity-stat-card">
                        <div className="activity-stat-top">
                            <span className="activity-stat-label">TOTAL EVENTS</span>
                            <div className="activity-stat-icon-badge red">
                                <i className="bx bx-pulse" />
                            </div>
                        </div>
                        <div className="activity-stat-value">{loading ? "…" : totalEventsCount}</div>
                        <div className="activity-stat-footnote">Recorded nutrition entries</div>
                    </div>
                </div>

                {/* FILTERS & SEARCH ROW */}
                <div className="activity-filters-card">
                    <div className="activity-filters-left">
                        {/* Search Input */}
                        <div className="activity-search-box">
                            <i className="bx bx-search" />
                            <input
                                type="text"
                                className="activity-search-input"
                                placeholder="Search client, protocol, trainer..."
                                value={searchTerm}
                                onChange={(e) => {
                                    setSearchTerm(e.target.value);
                                    setPage(1);
                                }}
                            />
                        </div>

                        {/* Date Range Select */}
                        <select
                            className="activity-filter-select"
                            value={dateRange}
                            onChange={(e) => {
                                setDateRange(e.target.value);
                                setPage(1);
                            }}
                        >
                            <option value="all">Date: All Time</option>
                            <option value="1">Last 24 Hours</option>
                            <option value="7">Last 7 Days</option>
                            <option value="30">Last 30 Days</option>
                            <option value="90">Last 90 Days</option>
                        </select>

                        {/* Trainer Select */}
                        <select
                            className="activity-filter-select"
                            value={trainerFilter}
                            onChange={(e) => {
                                setTrainerFilter(e.target.value);
                                setPage(1);
                            }}
                        >
                            <option value="all">Staff: All Trainers</option>
                            {trainers.map((t) => (
                                <option key={t} value={t}>
                                    {t}
                                </option>
                            ))}
                        </select>

                        {/* Protocol Select */}
                        <select
                            className="activity-filter-select"
                            value={protocolFilter}
                            onChange={(e) => {
                                setProtocolFilter(e.target.value);
                                setPage(1);
                            }}
                        >
                            <option value="all">Protocol: All Types</option>
                            {protocols.map((p) => (
                                <option key={p} value={p}>
                                    {p}
                                </option>
                            ))}
                        </select>
                    </div>

                    <button className="activity-export-btn" onClick={handleExport}>
                        <i className="bx bx-export" /> Export CSV Log
                    </button>
                </div>

                {/* TABLE CONTAINER */}
                <div className="activity-table-card">
                    {loading ? (
                        <div style={{ textAlign: "center", padding: "48px", color: "#64748b" }}>
                            <i className="bx bx-loader-alt bx-spin" style={{ fontSize: "32px", marginBottom: "12px" }} />
                            <p>Loading activity logs...</p>
                        </div>
                    ) : filtered.length === 0 ? (
                        <div style={{ textAlign: "center", padding: "48px", color: "#64748b" }}>
                            <i className="bx bx-search-alt" style={{ fontSize: "40px", color: "#94a3b8", marginBottom: "12px" }} />
                            <p style={{ fontWeight: 600, color: "#00225d", margin: "0 0 4px 0" }}>No activity matches these filters.</p>
                            <p style={{ fontSize: "13px", color: "#94a3b8", margin: 0 }}>Try adjusting your search keywords or date range.</p>
                        </div>
                    ) : (
                        <>
                            <table className="activity-table">
                                <thead>
                                    <tr>
                                        <th>CLIENT / TARGET</th>
                                        <th>ACTION / EVENT</th>
                                        <th>ASSIGNED PROTOCOL</th>
                                        <th>STAFF / COACH</th>
                                        <th>TIMESTAMP</th>
                                        <th>STATUS</th>
                                        <th>ACTION</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {pageRows.map((r) => (
                                        <tr key={r.id}>
                                            <td>
                                                <div className="activity-client-cell">
                                                    <div className="activity-client-avatar">
                                                        {r.clientPhoto ? (
                                                            <img src={r.clientPhoto} alt={r.clientName} />
                                                        ) : (
                                                            r.clientInitials
                                                        )}
                                                    </div>
                                                    <span className="activity-client-name">{r.clientName}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <span className={`activity-action-badge ${r.actionType}`}>
                                                    {r.action}
                                                </span>
                                            </td>
                                            <td>
                                                <div className="activity-protocol-cell">
                                                    <i className="bx bxs-flame" />
                                                    <span>{r.protocolName}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <div className="activity-trainer-cell">
                                                    <i className="bx bx-user" />
                                                    <span>{r.trainerName}</span>
                                                </div>
                                            </td>
                                            <td className="activity-time-cell">
                                                {fmtTimestamp(r.timestamp)}
                                            </td>
                                            <td>
                                                <span className={`activity-status-pill ${r.status.toLowerCase() === "active" ? "active" : "completed"}`}>
                                                    {r.status.toUpperCase()}
                                                </span>
                                            </td>
                                            <td>
                                                {r.clientId ? (
                                                    <button
                                                        className="activity-view-btn"
                                                        onClick={() => navigate(`/users/${r.clientId}`)}
                                                    >
                                                        Profile &rarr;
                                                    </button>
                                                ) : (
                                                    <button
                                                        className="activity-view-btn"
                                                        onClick={() => navigate("/diet-plans/library")}
                                                    >
                                                        Library &rarr;
                                                    </button>
                                                )}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>

                            {/* PAGINATION */}
                            <div className="activity-pagination">
                                <span className="activity-pagination-count">
                                    Showing {(page - 1) * PAGE_SIZE + 1}-
                                    {Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length} events
                                </span>
                                <div className="activity-pagination-controls">
                                    <button
                                        className="activity-page-btn"
                                        disabled={page === 1}
                                        onClick={() => setPage((p) => Math.max(1, p - 1))}
                                    >
                                        <i className="bx bx-chevron-left" />
                                    </button>
                                    {Array.from({ length: totalPages }, (_, i) => i + 1)
                                        .slice(0, 5)
                                        .map((p) => (
                                            <button
                                                key={p}
                                                className={`activity-page-btn ${p === page ? "active" : ""}`}
                                                onClick={() => setPage(p)}
                                            >
                                                {p}
                                            </button>
                                        ))}
                                    <button
                                        className="activity-page-btn"
                                        disabled={page === totalPages}
                                        onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                                    >
                                        <i className="bx bx-chevron-right" />
                                    </button>
                                </div>
                            </div>
                        </>
                    )}
                </div>
            </div>
        </Layout>
    );
}