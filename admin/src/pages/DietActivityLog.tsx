import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, orderBy, getDocs, limit } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/dietActivityLog.css";

interface ActivityRow {
    id: string;
    clientName: string;
    clientInitials: string;
    action: string;
    protocolName: string;
    trainerName: string;
    timestamp: Date | null;
    status: string;
}

interface RawActivityDoc {
    clientName?: string;
    action?: string;
    protocolName?: string;
    trainerName?: string;
    status?: string;
    createdAt?: { toDate: () => Date };
}

const PAGE_SIZE = 10;

function fmtTimestamp(d: Date | null): string {
    if (!d) return "—";
    return d.toLocaleString("en-GB", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
    });
}

export default function DietActivityLog() {
    const navigate = useNavigate();
    const [rows, setRows] = useState<ActivityRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [dateRange, setDateRange] = useState("7");
    const [trainerFilter, setTrainerFilter] = useState("all");
    const [protocolFilter, setProtocolFilter] = useState("all");
    const [page, setPage] = useState(1);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(
                    query(
                        collection(db, "dietPlanActivity"),
                        orderBy("createdAt", "desc"),
                        limit(500)
                    )
                );
                if (cancelled) return;

                setRows(
                    snap.docs.map((d) => {
                        const data = d.data() as RawActivityDoc;
                        const name = data.clientName ?? "Unknown Client";
                        return {
                            id: d.id,
                            clientName: name,
                            clientInitials: name
                                .split(" ")
                                .map((p) => p[0])
                                .join("")
                                .slice(0, 2)
                                .toUpperCase(),
                            action: data.action ?? "—",
                            protocolName: data.protocolName ?? "—",
                            trainerName: data.trainerName ?? "—",
                            timestamp: data.createdAt?.toDate ? data.createdAt.toDate() : null,
                            status: data.status ?? "active",
                        };
                    })
                );
            } catch (err) {
                console.error("Activity log load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, []);

    const trainers = Array.from(new Set(rows.map((r) => r.trainerName)));
    const protocols = Array.from(new Set(rows.map((r) => r.protocolName)));

    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - Number(dateRange));

    const filtered = rows.filter((r) => {
        if (r.timestamp && r.timestamp < cutoff) return false;
        if (trainerFilter !== "all" && r.trainerName !== trainerFilter) return false;
        if (protocolFilter !== "all" && r.protocolName !== protocolFilter) return false;
        return true;
    });

    const newProtocolsCount = filtered.filter((r) => r.action === "Assigned Protocol").length;
    const updatedTodayCount = filtered.filter((r) => {
        if (!r.timestamp) return false;
        const now = new Date();
        return (
            r.timestamp.getDate() === now.getDate() &&
            r.timestamp.getMonth() === now.getMonth() &&
            r.timestamp.getFullYear() === now.getFullYear()
        );
    }).length;
    const activeClientsCount = new Set(filtered.map((r) => r.clientName)).size;
    const pendingCount = filtered.filter((r) => r.status === "pending").length;

    const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    const pageRows = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    function handleExport() {
        const header = ["Client", "Action", "Protocol", "Trainer", "Timestamp", "Status"];
        const csvRows = filtered.map((r) => [
            r.clientName,
            r.action,
            r.protocolName,
            r.trainerName,
            fmtTimestamp(r.timestamp),
            r.status,
        ]);
        const csv = [header, ...csvRows]
            .map((row) => row.map((c) => `"${c.replace(/"/g, '""')}"`).join(","))
            .join("\n");
        const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `diet-activity-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(url);
    }

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <p style={{ color: "#999" }}>Loading activity...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            <button className="profile-back-btn" onClick={() => navigate("/diet-plans")}>
                <i className="bx bx-arrow-back" /> Back to Diet Plan
            </button>

            <div className="activity-title">Recent Activity</div>
            <div className="activity-subtitle">
                Real-time view of your elite performance system.
            </div>

            <div className="activity-stats-row">
                <div className="activity-stat-card">
                    <div className="activity-stat-label">NEW PROTOCOLS</div>
                    <div className="activity-stat-value red">{newProtocolsCount}</div>
                </div>
                <div className="activity-stat-card">
                    <div className="activity-stat-label">UPDATED TODAY</div>
                    <div className="activity-stat-value red">{updatedTodayCount}</div>
                </div>
                <div className="activity-stat-card">
                    <div className="activity-stat-label">ACTIVE CLIENTS</div>
                    <div className="activity-stat-value red">{activeClientsCount}</div>
                </div>
                <div className="activity-stat-card">
                    <div className="activity-stat-label">PENDING TASKS</div>
                    <div className="activity-stat-value red">{pendingCount}</div>
                </div>
            </div>

            <div className="activity-filters-row">
                <div className="activity-filters-left">
                    <select
                        className="activity-filter-select"
                        value={dateRange}
                        onChange={(e) => {
                            setDateRange(e.target.value);
                            setPage(1);
                        }}
                    >
                        <option value="1">Date Range: Last 1 Day</option>
                        <option value="7">Date Range: Last 7 Days</option>
                        <option value="30">Date Range: Last 30 Days</option>
                        <option value="365">Date Range: Last Year</option>
                    </select>

                    <select
                        className="activity-filter-select"
                        value={trainerFilter}
                        onChange={(e) => {
                            setTrainerFilter(e.target.value);
                            setPage(1);
                        }}
                    >
                        <option value="all">Trainer: All Staff</option>
                        {trainers.map((t) => (
                            <option key={t} value={t}>
                                {t}
                            </option>
                        ))}
                    </select>

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
                    <i className="bx bx-export" /> Export Log
                </button>
            </div>

            <div className="activity-table-card">
                {filtered.length === 0 ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No activity matches these filters.
                    </div>
                ) : (
                    <>
                        <table className="activity-table">
                            <thead>
                                <tr>
                                    <th>Client Name</th>
                                    <th>Action/Event</th>
                                    <th>Assigned Protocol</th>
                                    <th>Trainer</th>
                                    <th>Timestamp</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {pageRows.map((r) => (
                                    <tr key={r.id}>
                                        <td>
                                            <div className="activity-client-cell">
                                                <span className="activity-client-avatar">
                                                    {r.clientInitials}
                                                </span>
                                                <span className="activity-client-name">
                                                    {r.clientName}
                                                </span>
                                            </div>
                                        </td>
                                        <td>{r.action}</td>
                                        <td>
                                            <span className="activity-protocol-pill">
                                                {r.protocolName}
                                            </span>
                                        </td>
                                        <td>{r.trainerName}</td>
                                        <td className="activity-mono">
                                            {fmtTimestamp(r.timestamp)}
                                        </td>
                                        <td>
                                            <span
                                                className={`activity-status-pill status-${r.status}`}
                                            >
                                                {r.status.toUpperCase()}
                                            </span>
                                        </td>
                                        <td>
                                            <button className="activity-view-btn">
                                                <i className="bx bx-show" />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>

                        <div className="activity-pagination">
                            <span className="activity-pagination-count">
                                Showing {(page - 1) * PAGE_SIZE + 1}-
                                {Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length}{" "}
                                events
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
                                            className={`activity-page-btn ${p === page ? "active" : ""
                                                }`}
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
        </Layout>
    );
}