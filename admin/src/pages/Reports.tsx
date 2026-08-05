import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs, query, where } from "firebase/firestore";
import {
    LineChart,
    Line,
    XAxis,
    YAxis,
    Tooltip,
    ResponsiveContainer,
    CartesianGrid,
    PieChart,
    Pie,
    Cell,
} from "recharts";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/reports.css";

type RangeKey = "7" | "30" | "90";

interface MonthPoint {
    label: string;
    revenue: number;
    users: number;
}

interface TrainerPerf {
    id: string;
    name: string;
    sessions: number;
    completionPct: number;
}

const PIE_COLORS = ["#00225d", "#01bce3", "#bb0013", "#17cc1a", "#f59e0b"];
const MONTH_LABELS = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

function daysAgo(n: number) {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return d;
}

export default function Reports() {
    const navigate = useNavigate();
    const [range, setRange] = useState<RangeKey>("30");
    const [showRangeMenu, setShowRangeMenu] = useState(false);
    const [loading, setLoading] = useState(true);

    const [totalRevenue, setTotalRevenue] = useState(0);
    const [prevRevenue, setPrevRevenue] = useState(0);
    const [activeUsers, setActiveUsers] = useState(0);
    const [prevActiveUsers, setPrevActiveUsers] = useState(0);
    const [sessionAttendancePct, setSessionAttendancePct] = useState(0);
    const [prevAttendancePct, setPrevAttendancePct] = useState(0);
    const [growthData, setGrowthData] = useState<MonthPoint[]>([]);
    const [packageMix, setPackageMix] = useState<{ name: string; value: number }[]>([]);
    const [trainerPerf, setTrainerPerf] = useState<TrainerPerf[]>([]);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            setLoading(true);
            try {
                const rangeDays = Number(range);
                const cutoff = daysAgo(rangeDays);
                const prevCutoff = daysAgo(rangeDays * 2);

                // Revenue (current vs previous period)
                const paymentsSnap = await getDocs(
                    query(collection(db, "payments"), where("status", "==", "completed"))
                );
                if (cancelled) return;

                let curRev = 0;
                let prevRev = 0;
                const monthlyRevenue = new Map<string, number>();
                const monthlyUsers = new Map<string, number>();

                paymentsSnap.docs.forEach((d) => {
                    const data = d.data();
                    const amt = data.amount ?? 0;
                    const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : null;
                    if (!createdAt) return;
                    if (createdAt >= cutoff) curRev += amt;
                    else if (createdAt >= prevCutoff && createdAt < cutoff) prevRev += amt;

                    const key = `${createdAt.getFullYear()}-${createdAt.getMonth()}`;
                    monthlyRevenue.set(key, (monthlyRevenue.get(key) ?? 0) + amt);
                });

                setTotalRevenue(curRev);
                setPrevRevenue(prevRev);

                // Users: total clients + growth by month, "active this week" = clients created/active in last 7 days
                const usersSnap = await getDocs(
                    query(collection(db, "users"), where("role", "==", "client"))
                );
                if (cancelled) return;

                let curActive = 0;
                let prevActive = 0;
                usersSnap.docs.forEach((d) => {
                    const data = d.data();
                    const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : null;
                    if (!createdAt) return;
                    const key = `${createdAt.getFullYear()}-${createdAt.getMonth()}`;
                    monthlyUsers.set(key, (monthlyUsers.get(key) ?? 0) + 1);
                });
                curActive = usersSnap.docs.filter((d) => {
                    const createdAt = d.data().createdAt?.toDate
                        ? d.data().createdAt.toDate()
                        : null;
                    return createdAt && createdAt >= daysAgo(7);
                }).length;
                prevActive = usersSnap.docs.filter((d) => {
                    const createdAt = d.data().createdAt?.toDate
                        ? d.data().createdAt.toDate()
                        : null;
                    return createdAt && createdAt >= daysAgo(14) && createdAt < daysAgo(7);
                }).length;
                setActiveUsers(usersSnap.size);
                setPrevActiveUsers(prevActive || curActive);

                // Build last 6 months of growth data (cumulative revenue + user count)
                const now = new Date();
                const points: MonthPoint[] = [];
                let cumRevenue = 0;
                let cumUsers = 0;
                for (let i = 5; i >= 0; i--) {
                    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
                    const key = `${d.getFullYear()}-${d.getMonth()}`;
                    cumRevenue += monthlyRevenue.get(key) ?? 0;
                    cumUsers += monthlyUsers.get(key) ?? 0;
                    points.push({
                        label: MONTH_LABELS[d.getMonth()],
                        revenue: cumRevenue,
                        users: cumUsers,
                    });
                }
                setGrowthData(points);

                // Session attendance
                const sessionsSnap = await getDocs(
                    query(collection(db, "sessions"))
                );
                if (cancelled) return;

                const recentSessions = sessionsSnap.docs.filter((d) => {
                    const dateStr = d.data().scheduledDate;
                    if (!dateStr) return false;
                    return new Date(dateStr) >= cutoff;
                });
                const prevSessions = sessionsSnap.docs.filter((d) => {
                    const dateStr = d.data().scheduledDate;
                    if (!dateStr) return false;
                    const dt = new Date(dateStr);
                    return dt >= prevCutoff && dt < cutoff;
                });
                const completedCur = recentSessions.filter(
                    (d) => d.data().status === "completed"
                ).length;
                const completedPrev = prevSessions.filter(
                    (d) => d.data().status === "completed"
                ).length;
                setSessionAttendancePct(
                    recentSessions.length === 0
                        ? 0
                        : Math.round((completedCur / recentSessions.length) * 100)
                );
                setPrevAttendancePct(
                    prevSessions.length === 0
                        ? 0
                        : Math.round((completedPrev / prevSessions.length) * 100)
                );

                // Package mix: active subscriptions grouped by package name
                const subsSnap = await getDocs(
                    query(collection(db, "subscriptions"), where("status", "==", "active"))
                );
                if (cancelled) return;
                const mixMap = new Map<string, number>();
                subsSnap.docs.forEach((d) => {
                    const name = d.data().packageName ?? "Other";
                    mixMap.set(name, (mixMap.get(name) ?? 0) + 1);
                });
                setPackageMix(
                    Array.from(mixMap.entries()).map(([name, value]) => ({ name, value }))
                );

                // Trainer performance
                const trainersSnap = await getDocs(
                    query(collection(db, "users"), where("role", "==", "trainer"))
                );
                if (cancelled) return;

                const perf = trainersSnap.docs.map((t) => {
                    const trainerSessions = sessionsSnap.docs.filter(
                        (s) => s.data().trainerId === t.id
                    );
                    const completed = trainerSessions.filter(
                        (s) => s.data().status === "completed"
                    ).length;
                    return {
                        id: t.id,
                        name: t.data().fullName ?? "Unknown Trainer",
                        sessions: trainerSessions.length,
                        completionPct:
                            trainerSessions.length === 0
                                ? 0
                                : Math.round((completed / trainerSessions.length) * 100),
                    };
                });
                perf.sort((a, b) => b.sessions - a.sessions);
                setTrainerPerf(perf.slice(0, 5));
            } catch (err) {
                console.error("Reports load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, [range]);

    const revenueChangePct = useMemo(() => {
        if (prevRevenue === 0) return null;
        return Math.round(((totalRevenue - prevRevenue) / prevRevenue) * 1000) / 10;
    }, [totalRevenue, prevRevenue]);

    const usersChangePct = useMemo(() => {
        if (prevActiveUsers === 0) return null;
        return Math.round(((activeUsers - prevActiveUsers) / prevActiveUsers) * 1000) / 10;
    }, [activeUsers, prevActiveUsers]);

    const attendanceChangePts =
        prevAttendancePct === 0 ? null : sessionAttendancePct - prevAttendancePct;

    function fmtCurrency(n: number) {
        return `₹${n.toLocaleString("en-IN")}`;
    }

    if (loading) {
        return (
            <Layout title="Reports">
                <p style={{ color: "#999" }}>Loading reports...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Reports">
            <div className="rp-header">
                <div>
                    <div className="rp-title">Reports &amp; Analytics</div>
                    <div className="rp-subtitle">Business performance overview for JoE.V.</div>
                </div>
                <div className="rp-range-wrap">
                    <button
                        className="rp-range-btn"
                        onClick={() => setShowRangeMenu((s) => !s)}
                    >
                        <i className="bx bx-calendar" /> Last {range} Days{" "}
                        <i className="bx bx-chevron-down" />
                    </button>
                    {showRangeMenu && (
                        <div className="rp-range-menu">
                            {(["7", "30", "90"] as RangeKey[]).map((r) => (
                                <button
                                    key={r}
                                    className={`rp-range-option ${range === r ? "active" : ""}`}
                                    onClick={() => {
                                        setRange(r);
                                        setShowRangeMenu(false);
                                    }}
                                >
                                    Last {r} Days
                                </button>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            <div className="rp-stats-row">
                <div className="rp-stat-card">
                    <div className="rp-stat-top">
                        <span className="rp-stat-icon-badge">
                            <i className="bx bx-wallet" />
                        </span>
                        {revenueChangePct !== null && (
                            <span
                                className={`rp-stat-change ${revenueChangePct >= 0 ? "up" : "down"
                                    }`}
                            >
                                <i
                                    className={`bx ${revenueChangePct >= 0
                                            ? "bx-trending-up"
                                            : "bx-trending-down"
                                        }`}
                                />{" "}
                                {revenueChangePct >= 0 ? "+" : ""}
                                {revenueChangePct}%
                            </span>
                        )}
                    </div>
                    <div className="rp-stat-label">Total Revenue</div>
                    <div className="rp-stat-value">{fmtCurrency(totalRevenue)}</div>
                    <div className="rp-stat-footnote">
                        vs. {fmtCurrency(prevRevenue)} last period
                    </div>
                </div>

                <div className="rp-stat-card">
                    <div className="rp-stat-top">
                        <span className="rp-stat-icon-badge">
                            <i className="bx bx-user-check" />
                        </span>
                        {usersChangePct !== null && (
                            <span
                                className={`rp-stat-change ${usersChangePct >= 0 ? "up" : "down"}`}
                            >
                                <i
                                    className={`bx ${usersChangePct >= 0 ? "bx-trending-up" : "bx-trending-down"
                                        }`}
                                />{" "}
                                {usersChangePct >= 0 ? "+" : ""}
                                {usersChangePct}%
                            </span>
                        )}
                    </div>
                    <div className="rp-stat-label">Active Users</div>
                    <div className="rp-stat-value">{activeUsers}</div>
                    <div className="rp-stat-footnote">Active members this week</div>
                </div>

                <div className="rp-stat-card">
                    <div className="rp-stat-top">
                        <span className="rp-stat-icon-badge">
                            <i className="bx bx-calendar-check" />
                        </span>
                        {attendanceChangePts !== null && (
                            <span
                                className={`rp-stat-change ${attendanceChangePts >= 0 ? "up" : "down"
                                    }`}
                            >
                                <i
                                    className={`bx ${attendanceChangePts >= 0
                                            ? "bx-trending-up"
                                            : "bx-trending-down"
                                        }`}
                                />{" "}
                                {attendanceChangePts >= 0 ? "+" : ""}
                                {attendanceChangePts}%
                            </span>
                        )}
                    </div>
                    <div className="rp-stat-label">Session Attendance</div>
                    <div className="rp-stat-value">{sessionAttendancePct}%</div>
                    <div className="rp-stat-footnote">Average per class slot</div>
                </div>
            </div>

            <div className="rp-growth-card">
                <div className="rp-growth-header">
                    <div>
                        <div className="rp-growth-title">Growth Trends</div>
                        <div className="rp-growth-subtitle">
                            Revenue vs User Growth over the last 6 months
                        </div>
                    </div>
                    <div className="rp-legend">
                        <span className="rp-legend-item">
                            <span className="rp-legend-dot revenue" /> Revenue
                        </span>
                        <span className="rp-legend-item">
                            <span className="rp-legend-dot users" /> User Growth
                        </span>
                    </div>
                </div>

                {growthData.every((p) => p.revenue === 0 && p.users === 0) ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No growth data available yet.
                    </div>
                ) : (
                    <ResponsiveContainer width="100%" height={280}>
                        <LineChart data={growthData} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                            <CartesianGrid vertical={false} stroke="#eee" />
                            <XAxis
                                dataKey="label"
                                axisLine={false}
                                tickLine={false}
                                tick={{ fontSize: 11, fill: "#808080" }}
                            />
                            <YAxis hide />
                            <Tooltip />
                            <Line
                                type="monotone"
                                dataKey="revenue"
                                stroke="#00225d"
                                strokeWidth={2}
                                dot={{ r: 3 }}
                            />
                            <Line
                                type="monotone"
                                dataKey="users"
                                stroke="#01bce3"
                                strokeWidth={2}
                                strokeDasharray="4 4"
                                dot={{ r: 3 }}
                            />
                        </LineChart>
                    </ResponsiveContainer>
                )}
            </div>

            <div className="rp-bottom-row">
                <div className="rp-package-card">
                    <div className="rp-card-header">
                        <div className="rp-card-title">Package Mix</div>
                    </div>
                    {packageMix.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 24 }}>
                            No active subscriptions yet.
                        </div>
                    ) : (
                        <>
                            <ResponsiveContainer width="100%" height={220}>
                                <PieChart>
                                    <Pie
                                        data={packageMix}
                                        dataKey="value"
                                        nameKey="name"
                                        innerRadius={60}
                                        outerRadius={90}
                                        paddingAngle={2}
                                    >
                                        {packageMix.map((_, i) => (
                                            <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                                        ))}
                                    </Pie>
                                    <Tooltip />
                                </PieChart>
                            </ResponsiveContainer>
                            <div className="rp-pie-legend">
                                {packageMix.map((p, i) => (
                                    <div key={p.name} className="rp-pie-legend-item">
                                        <span
                                            className="rp-pie-legend-dot"
                                            style={{
                                                backgroundColor: PIE_COLORS[i % PIE_COLORS.length],
                                            }}
                                        />
                                        {p.name} ({p.value})
                                    </div>
                                ))}
                            </div>
                        </>
                    )}
                </div>

                <div className="rp-trainer-card">
                    <div className="rp-card-header">
                        <div className="rp-card-title">Trainer Performance</div>
                        <button className="rp-view-all-btn" onClick={() => navigate("/trainers")}>
                            View All
                        </button>
                    </div>

                    {trainerPerf.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 24 }}>
                            No trainer session data yet.
                        </div>
                    ) : (
                        <table className="rp-trainer-table">
                            <thead>
                                <tr>
                                    <th>Trainer</th>
                                    <th>Sessions</th>
                                    <th>Completion</th>
                                </tr>
                            </thead>
                            <tbody>
                                {trainerPerf.map((t) => (
                                    <tr key={t.id}>
                                        <td className="rp-trainer-name">{t.name}</td>
                                        <td className="rp-mono">{t.sessions}</td>
                                        <td className="rp-mono">{t.completionPct}%</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </Layout>
    );
}