import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/subscriptions.css";

interface SubRow {
    id: string;
    clientName: string;
    clientInitials: string;
    packageName: string;
    startDate: string;
    endDate: string;
    renewalType: "auto" | "manual";
    status: "active" | "paused" | "expired" | "pending";
    monthlyPrice: number;
}

const PAGE_SIZE = 5;

function fmtDate(v: unknown): string {
    if (!v) return "—";
    const d =
        typeof v === "object" && v !== null && "toDate" in v
            ? (v as { toDate: () => Date }).toDate()
            : new Date(v as string);
    return d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Subscriptions() {
    const navigate = useNavigate();
    const [subs, setSubs] = useState<SubRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [page, setPage] = useState(1);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(collection(db, "subscriptions"));
                if (cancelled) return;

                const rows: SubRow[] = snap.docs.map((d) => {
                    const data = d.data();
                    const name: string = data.clientName ?? "Unknown Client";
                    return {
                        id: d.id,
                        clientName: name,
                        clientInitials: name
                            .split(" ")
                            .map((p: string) => p[0])
                            .join("")
                            .slice(0, 2)
                            .toUpperCase(),
                        packageName: data.packageName ?? "—",
                        startDate: fmtDate(data.startDate),
                        endDate: fmtDate(data.endDate),
                        renewalType: data.renewalType ?? "manual",
                        status: data.status ?? "active",
                        monthlyPrice: data.monthlyPrice ?? 0,
                    };
                });
                setSubs(rows);
            } catch (err) {
                console.error("Subscriptions load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, []);

    const activeCount = subs.filter((s) => s.status === "active").length;
    const pendingCount = subs.filter((s) => s.status === "pending").length;
    const monthlyRevenue = subs
        .filter((s) => s.status === "active")
        .reduce((sum, s) => sum + s.monthlyPrice, 0);

    const totalPages = Math.max(1, Math.ceil(subs.length / PAGE_SIZE));
    const pageRows = subs.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    function handleExportCsv() {
        const header = [
            "Client Name",
            "Package",
            "Start Date",
            "End Date",
            "Renewal",
            "Status",
            "Monthly Price",
        ];
        const rows = subs.map((s) => [
            s.clientName,
            s.packageName,
            s.startDate,
            s.endDate,
            s.renewalType,
            s.status,
            String(s.monthlyPrice),
        ]);
        const csv = [header, ...rows]
            .map((r) => r.map((cell) => `"${cell.replace(/"/g, '""')}"`).join(","))
            .join("\n");

        const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `subscriptions-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(url);
    }

    if (loading) {
        return (
            <Layout title="Subscription">
                <p style={{ color: "#999" }}>Loading subscriptions...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Subscription">
            <div className="subs-header">
                <div>
                    <div className="subs-title">Subscription Manage</div>
                    <div className="subs-subtitle">
                        Manage active and historical client subscriptions.
                    </div>
                </div>
                <div className="subs-header-actions">
                    <button className="subs-filter-btn">
                        <i className="bx bx-filter-alt" /> Filter
                    </button>
                    <button className="subs-export-btn" onClick={handleExportCsv}>
                        <i className="bx bx-download" /> Export CSV
                    </button>
                </div>
            </div>

            <div className="subs-table-card">
                {subs.length === 0 ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No subscriptions yet.
                    </div>
                ) : (
                    <>
                        <table className="subs-table">
                            <thead>
                                <tr>
                                    <th>Client Name</th>
                                    <th>Package</th>
                                    <th>Start Date</th>
                                    <th>End Date</th>
                                    <th style={{ textAlign: "center" }}>Renewal</th>
                                    <th style={{ textAlign: "center" }}>Status</th>
                                    <th style={{ textAlign: "right" }}>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {pageRows.map((s) => (
                                    <tr key={s.id}>
                                        <td>
                                            <div className="subs-client-cell">
                                                <span className="subs-client-avatar">
                                                    {s.clientInitials}
                                                </span>
                                                <span className="subs-client-name">
                                                    {s.clientName}
                                                </span>
                                            </div>
                                        </td>
                                        <td>
                                            <span className="subs-package-pill">
                                                {s.packageName}
                                            </span>
                                        </td>
                                        <td className="subs-mono">{s.startDate}</td>
                                        <td className="subs-mono">{s.endDate}</td>
                                        <td style={{ textAlign: "center" }}>
                                            {s.renewalType === "auto" ? "Auto" : "Manual"}
                                        </td>
                                        <td style={{ textAlign: "center" }}>
                                            <span className={`subs-status-pill status-${s.status}`}>
                                                {s.status.toUpperCase()}
                                            </span>
                                        </td>
                                        <td>
                                            <div className="subs-actions-cell">
                                                <button
                                                    className="subs-action-btn"
                                                    onClick={() =>
                                                        navigate(`/subscriptions/${s.id}`)
                                                    }
                                                >
                                                    <i className="bx bx-show" />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>

                        <div className="subs-pagination">
                            <span className="subs-pagination-count">
                                Showing {pageRows.length} of {subs.length} subscriptions
                            </span>
                            <div className="subs-pagination-controls">
                                <button
                                    className="subs-page-btn"
                                    disabled={page === 1}
                                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                                >
                                    <i className="bx bx-chevron-left" />
                                </button>
                                {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
                                    <button
                                        key={p}
                                        className={`subs-page-btn ${p === page ? "active" : ""}`}
                                        onClick={() => setPage(p)}
                                    >
                                        {p}
                                    </button>
                                ))}
                                <button
                                    className="subs-page-btn"
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

            <div className="subs-stats-row">
                <div className="subs-stat-card">
                    <div className="subs-stat-label">ACTIVE SUBSCRIPTIONS</div>
                    <div className="subs-stat-value">{activeCount}</div>
                    <div className="subs-stat-footnote success">
                        <i className="bx bx-trending-up" /> Live count from active subscriptions
                    </div>
                </div>

                <div className="subs-stat-card">
                    <div className="subs-stat-label">PENDING RENEWALS</div>
                    <div className="subs-stat-value danger">{pendingCount}</div>
                    <div className="subs-stat-footnote warning">
                        <i className="bx bx-error" /> Requires manual approval
                    </div>
                </div>

                <div className="subs-stat-card dark">
                    <div className="subs-stat-label">MONTHLY REVENUE</div>
                    <div className="subs-stat-value">
                        ₹{monthlyRevenue.toLocaleString("en-IN", { minimumFractionDigits: 2 })}
                    </div>
                    <div className="subs-stat-footnote">
                        <i className="bx bx-bar-chart-alt-2" /> From active subscriptions
                    </div>
                </div>
            </div>

            <div className="subs-analytics-card">
                <div className="subs-analytics-left">
                    <span className="subs-analytics-icon">
                        <i className="bx bx-line-chart" />
                    </span>
                    <div>
                        <div className="subs-analytics-title">Subscription Analytics</div>
                        <div className="subs-analytics-desc">
                            Deep dive into churn rates, LTV, and package performance metrics.
                        </div>
                    </div>
                </div>
                <button className="subs-analytics-btn">View Reports</button>
            </div>
        </Layout>
    );
}