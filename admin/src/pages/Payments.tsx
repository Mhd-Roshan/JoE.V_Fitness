import { useEffect, useMemo, useState } from "react";
import { collection, getDocs, query, orderBy, limit } from "firebase/firestore";
import {
    AreaChart,
    Area,
    XAxis,
    YAxis,
    Tooltip,
    ResponsiveContainer,
    CartesianGrid,
} from "recharts";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/payments.css";

interface PaymentRow {
    id: string;
    clientName: string;
    planType: string;
    transactionId: string;
    amount: number;
    status: string;
    createdAt: Date | null;
}

type RangeKey = "7d" | "30d" | "all";

const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function startOfMonth(d = new Date()) {
    return new Date(d.getFullYear(), d.getMonth(), 1);
}

function fmtDate(d: Date | null): string {
    if (!d) return "—";
    return d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtCurrency(n: number): string {
    return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
}

export default function Payments() {
    const [payments, setPayments] = useState<PaymentRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [range, setRange] = useState<RangeKey>("7d");

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(
                    query(collection(db, "payments"), orderBy("createdAt", "desc"), limit(2000))
                );
                if (cancelled) return;

                setPayments(
                    snap.docs.map((d) => {
                        const data = d.data();
                        return {
                            id: d.id,
                            clientName: data.clientName ?? "—",
                            planType: data.planType ?? "—",
                            transactionId: data.transactionId ?? d.id,
                            amount: data.amount ?? 0,
                            status: data.status ?? "completed",
                            createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : null,
                        };
                    })
                );
            } catch (err) {
                console.error("Payments load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, []);

    const completedPayments = useMemo(
        () => payments.filter((p) => p.status === "completed"),
        [payments]
    );

    const totalRevenue = completedPayments.reduce((sum, p) => sum + p.amount, 0);

    const thisMonthRevenue = completedPayments
        .filter((p) => p.createdAt && p.createdAt >= startOfMonth())
        .reduce((sum, p) => sum + p.amount, 0);

    const lastMonthStart = startOfMonth(
        new Date(new Date().getFullYear(), new Date().getMonth() - 1, 1)
    );
    const lastMonthEnd = startOfMonth();
    const lastMonthRevenue = completedPayments
        .filter((p) => p.createdAt && p.createdAt >= lastMonthStart && p.createdAt < lastMonthEnd)
        .reduce((sum, p) => sum + p.amount, 0);

    const monthlyGrowthPct =
        lastMonthRevenue === 0
            ? null
            : Math.round(((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 1000) / 10;

    const avgTransaction =
        completedPayments.length === 0 ? 0 : totalRevenue / completedPayments.length;

    const chartData = useMemo(() => {
        const now = new Date();
        let daysBack = 7;
        if (range === "30d") daysBack = 30;
        if (range === "all") {
            const earliest = payments.reduce<Date | null>((min, p) => {
                if (!p.createdAt) return min;
                return !min || p.createdAt < min ? p.createdAt : min;
            }, null);
            daysBack = earliest
                ? Math.max(1, Math.ceil((now.getTime() - earliest.getTime()) / 86400000))
                : 7;
        }

        const buckets: { label: string; date: Date; revenue: number }[] = [];
        for (let i = daysBack - 1; i >= 0; i--) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            d.setHours(0, 0, 0, 0);
            buckets.push({
                label: daysBack <= 7 ? DAY_LABELS[d.getDay() === 0 ? 6 : d.getDay() - 1] : fmtDate(d),
                date: d,
                revenue: 0,
            });
        }

        completedPayments.forEach((p) => {
            if (!p.createdAt) return;
            const d = new Date(p.createdAt);
            d.setHours(0, 0, 0, 0);
            const bucket = buckets.find((b) => b.date.getTime() === d.getTime());
            if (bucket) bucket.revenue += p.amount;
        });

        return buckets;
    }, [payments, range, completedPayments]);

    const peakDay = chartData.reduce(
        (max, b) => (b.revenue > (max?.revenue ?? -1) ? b : max),
        null as { label: string; date: Date; revenue: number } | null
    );

    const recentTransactions = payments.slice(0, 8);

    function handleExport() {
        const header = ["Client", "Plan Type", "Transaction ID", "Amount", "Date", "Status"];
        const rows = payments.map((p) => [
            p.clientName,
            p.planType,
            p.transactionId,
            String(p.amount),
            fmtDate(p.createdAt),
            p.status,
        ]);
        const csv = [header, ...rows]
            .map((r) => r.map((c) => `"${c.replace(/"/g, '""')}"`).join(","))
            .join("\n");
        const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `payments-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(url);
    }

    if (loading) {
        return (
            <Layout title="Payment">
                <p style={{ color: "#999" }}>Loading payments...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Payment">
            <div className="pay-header">
                <div>
                    <div className="pay-title">Payment Manage</div>
                    <div className="pay-subtitle">
                        Monitor fiscal performance, transaction flows, and subscription health
                        across all global regions.
                    </div>
                </div>
                <button className="pay-export-btn" onClick={handleExport}>
                    <i className="bx bx-download" /> Export Reports
                </button>
            </div>

            <div className="pay-stats-row">
                <div className="pay-stat-card">
                    <div className="pay-stat-top">
                        <span className="pay-stat-label">TOTAL REVENUE</span>
                        <i className="bx bx-wallet pay-stat-icon" />
                    </div>
                    <div className="pay-stat-value-row">
                        <span className="pay-stat-value">{fmtCurrency(totalRevenue)}</span>
                        {monthlyGrowthPct !== null && (
                            <span className={`pay-stat-pill ${monthlyGrowthPct >= 0 ? "up" : "down"}`}>
                                {monthlyGrowthPct >= 0 ? "+" : ""}
                                {monthlyGrowthPct}%
                            </span>
                        )}
                    </div>
                    <div className="pay-stat-footnote">Fiscal year performance to date</div>
                </div>

                <div className="pay-stat-card">
                    <div className="pay-stat-top">
                        <span className="pay-stat-label">MONTHLY GROWTH</span>
                        <i className="bx bx-trending-up pay-stat-icon" />
                    </div>
                    <div className="pay-stat-value">
                        {monthlyGrowthPct === null
                            ? "—"
                            : `${monthlyGrowthPct >= 0 ? "+" : ""}${monthlyGrowthPct}%`}
                    </div>
                    <div className="pay-stat-footnote">Compared to previous month window</div>
                </div>

                <div className="pay-stat-card">
                    <div className="pay-stat-top">
                        <span className="pay-stat-label">AVG TRANSACTION</span>
                        <i className="bx bx-line-chart pay-stat-icon" />
                    </div>
                    <div className="pay-stat-value-row">
                        <span className="pay-stat-value">{fmtCurrency(avgTransaction)}</span>
                        <span className="pay-stat-baseline">Baseline</span>
                    </div>
                    <div className="pay-stat-footnote">
                        Net average across {completedPayments.length.toLocaleString()} orders
                    </div>
                </div>
            </div>

            <div className="pay-chart-card">
                <div className="pay-chart-header">
                    <div>
                        <div className="pay-chart-title">Revenue Trends</div>
                        <div className="pay-chart-subtitle">
                            Hourly telemetry of transactional volume and gross receipts.
                        </div>
                    </div>
                    <div className="pay-range-tabs">
                        {(["7d", "30d", "all"] as RangeKey[]).map((r) => (
                            <button
                                key={r}
                                className={`pay-range-btn ${range === r ? "active" : ""}`}
                                onClick={() => setRange(r)}
                            >
                                {r === "7d" ? "7 Days" : r === "30d" ? "30 Days" : "All Time"}
                            </button>
                        ))}
                    </div>
                </div>

                {chartData.every((b) => b.revenue === 0) ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No revenue recorded in this window yet.
                    </div>
                ) : (
                    <ResponsiveContainer width="100%" height={320}>
                        <AreaChart data={chartData} margin={{ top: 20, right: 20, left: 0, bottom: 0 }}>
                            <defs>
                                <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="0%" stopColor="#00225d" stopOpacity={0.35} />
                                    <stop offset="100%" stopColor="#00225d" stopOpacity={0.02} />
                                </linearGradient>
                            </defs>
                            <CartesianGrid vertical={false} stroke="#eee" />
                            <XAxis
                                dataKey="label"
                                axisLine={false}
                                tickLine={false}
                                tick={{ fontSize: 11, fill: "#808080" }}
                            />
                            <YAxis hide />
                            <Tooltip
                                formatter={(value: number) => [fmtCurrency(value), "Revenue"]}
                                labelFormatter={(label) => label}
                            />
                            <Area
                                type="monotone"
                                dataKey="revenue"
                                stroke="#00225d"
                                strokeWidth={2}
                                fill="url(#revenueFill)"
                            />
                        </AreaChart>
                    </ResponsiveContainer>
                )}

                {peakDay && peakDay.revenue > 0 && (
                    <div className="pay-peak-note">
                        Peak revenue: <strong>{fmtCurrency(peakDay.revenue)}</strong> on{" "}
                        {fmtDate(peakDay.date)}
                    </div>
                )}
            </div>

            <div className="pay-transactions-card">
                <div className="pay-transactions-header">
                    <div className="pay-transactions-title">Recent Transactions</div>
                    <span className="pay-transactions-note">
                        Showing last {recentTransactions.length} transactions
                    </span>
                </div>

                {recentTransactions.length === 0 ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No transactions recorded yet.
                    </div>
                ) : (
                    <table className="pay-table">
                        <thead>
                            <tr>
                                <th>Athlete / Client</th>
                                <th>Plan Type</th>
                                <th>Transaction ID</th>
                                <th>Amount</th>
                                <th>Date</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {recentTransactions.map((p) => (
                                <tr key={p.id}>
                                    <td className="pay-client-name">{p.clientName}</td>
                                    <td>
                                        <span className="pay-plan-pill">{p.planType}</span>
                                    </td>
                                    <td className="pay-mono">{p.transactionId}</td>
                                    <td className="pay-mono">{fmtCurrency(p.amount)}</td>
                                    <td className="pay-mono">{fmtDate(p.createdAt)}</td>
                                    <td>
                                        <span className={`pay-status-pill status-${p.status}`}>
                                            {p.status.toUpperCase()}
                                        </span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </Layout>
    );
}