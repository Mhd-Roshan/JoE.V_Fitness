import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom"; // <-- IMPORT ADDED HERE
import { collection, getCountFromServer, query, where, orderBy, limit, getDocs } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/dashboard.css";

interface ActivityItem {
    id: string;
    name: string;
    detail: string;
    time: string;
}

interface ChartDay {
    label: string;
    dateStr: string;
    total: number;
    completed: number;
}

export default function Dashboard() {
    const navigate = useNavigate(); // <-- NAVIGATE HOOK INITIALIZED

    const [totalUsers, setTotalUsers] = useState<number | null>(null);
    const [totalSessions, setTotalSessions] = useState<number | null>(null);
    const [totalRevenue, setTotalRevenue] = useState<number | null>(null);
    const [recentActivity, setRecentActivity] = useState<ActivityItem[]>([]);

    // Real Chart State
    const [chartData, setChartData] = useState<ChartDay[]>([]);
    const [chartMax, setChartMax] = useState<number>(10);

    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function loadDashboardData() {
            try {
                // 1. Total Users
                const usersQuery = query(collection(db, "users"), where("role", "==", "client"));
                const usersSnap = await getCountFromServer(usersQuery);
                setTotalUsers(usersSnap.data().count);

                // 2. Total Sessions
                const sessionsSnap = await getCountFromServer(collection(db, "sessions"));
                setTotalSessions(sessionsSnap.data().count);

                // 3. Total Revenue
                const paymentsSnap = await getDocs(
                    query(collection(db, "payments"), where("status", "==", "success"))
                );
                const revenueSum = paymentsSnap.docs.reduce(
                    (sum, d) => sum + (d.data().amount ?? 0),
                    0
                );
                setTotalRevenue(revenueSum);

                // 4. Recent Activity
                const activityQuery = query(
                    collection(db, "auditLog"),
                    orderBy("createdAt", "desc"),
                    limit(4)
                );
                const activitySnap = await getDocs(activityQuery);
                const items: ActivityItem[] = activitySnap.docs.map((d) => {
                    const data = d.data();
                    return {
                        id: d.id,
                        name: data.actorId ?? "Unknown",
                        detail: data.action ?? "",
                        time: data.createdAt?.toDate ? timeAgo(data.createdAt.toDate()) : "just now",
                    };
                });
                setRecentActivity(items);

                // 5. REAL CHART DATA (Last 7 Days of Sessions)
                const today = new Date();
                const last7Days: ChartDay[] = Array.from({ length: 7 }, (_, i) => {
                    const d = new Date(today);
                    d.setDate(d.getDate() - (6 - i)); // Go back up to 6 days ago, ending on today
                    return {
                        dateStr: d.toISOString().split('T')[0],
                        label: d.toLocaleDateString("en-US", { weekday: 'short' }).substring(0, 2).toUpperCase(),
                        total: 0,
                        completed: 0
                    };
                });

                const startDateStr = last7Days[0].dateStr;
                const chartQuery = query(
                    collection(db, "sessions"),
                    where("scheduledDate", ">=", startDateStr)
                );

                const chartSnap = await getDocs(chartQuery);

                chartSnap.docs.forEach(doc => {
                    const data = doc.data();
                    const dayIndex = last7Days.findIndex(d => d.dateStr === data.scheduledDate);

                    if (dayIndex !== -1) {
                        last7Days[dayIndex].total += 1;
                        if (data.status === 'completed' || data.status === 'Complete') {
                            last7Days[dayIndex].completed += 1;
                        }
                    }
                });

                // Calculate max Y-axis for scaling (minimum 10 to avoid weird sizing)
                const maxSessions = Math.max(...last7Days.map(d => d.total));
                const dynamicMax = maxSessions < 10 ? 10 : Math.ceil(maxSessions / 5) * 5; // Rounds up to nearest 5

                setChartMax(dynamicMax);
                setChartData(last7Days);

            } catch (err) {
                console.error("Dashboard load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadDashboardData();
    }, []);

    // Format revenue (e.g. 2.7L)
    const formatRevenue = (rev: number | null) => {
        if (rev === null) return "…";
        if (rev >= 100000) return `₹ ${(rev / 100000).toFixed(1)}L`;
        return `₹ ${rev.toLocaleString("en-IN")}`;
    };

    return (
        <Layout title="Dashboard">
            {/* STATS ROW */}
            <div className="stat-row">
                <div className="stat-card shadow-cyan">
                    <div className="stat-header">
                        <div className="stat-label">TOTAL USERS</div>
                        <div className="stat-icon-badge"><i className="bx bx-group" /></div>
                    </div>
                    <div className="stat-value">{loading ? "…" : totalUsers ?? 0}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        +8 <span>This Month</span>
                    </div>
                </div>

                <div className="stat-card shadow-cyan">
                    <div className="stat-header">
                        <div className="stat-label">SESSIONS</div>
                        <div className="stat-icon-badge"><i className="bx bx-calendar" /></div>
                    </div>
                    <div className="stat-value">{loading ? "…" : totalSessions ?? 0}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        All On Track
                    </div>
                </div>

                <div className="stat-card shadow-cyan">
                    <div className="stat-header">
                        <div className="stat-label">JUNE REVENUE</div>
                        <div className="stat-icon-badge"><i className="bx bx-credit-card-front" /></div>
                    </div>
                    <div className="stat-value">{formatRevenue(totalRevenue)}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        12% <span>Vs May</span>
                    </div>
                </div>
            </div>

            {/* QUICK ACTIONS ROW (Links Added Here!) */}
            <div className="action-row">
                <button className="action-btn red" onClick={() => navigate("/trainers/add")}>
                    <i className="bx bx-group action-icon" />
                    <span>ADD<br />TRAINERS</span>
                </button>
                <button className="action-btn navy" onClick={() => navigate("/packages")}>
                    <i className="bx bx-box action-icon" />
                    <span>ADD<br />PACKAGES</span>
                </button>
                <button className="action-btn navy" onClick={() => navigate("/payments")}>
                    <i className="bx bx-credit-card action-icon" />
                    <span>PAYMENT<br />RECORDS</span>
                </button>
            </div>

            {/* CHART & ACTIVITY ROW */}
            <div className="bottom-row">

                {/* DYNAMIC FIREBASE CHART CARD */}
                <div className="chart-card">
                    <div className="chart-header">
                        <div className="chart-title">Growth Trends (Sessions)</div>
                        <div className="chart-toggles">
                            <button className="chart-toggle active">1W</button>
                            <button className="chart-toggle">1M</button>
                            <button className="chart-toggle">1Y</button>
                        </div>
                    </div>

                    <div className="mock-chart-container">
                        {/* Dynamic Y Axis based on Real Data */}
                        <div className="y-axis">
                            <span>{chartMax}</span>
                            <span>{chartMax * 0.8}</span>
                            <span>{chartMax * 0.6}</span>
                            <span>{chartMax * 0.4}</span>
                            <span>{chartMax * 0.2}</span>
                        </div>
                        <div className="grid-lines">
                            <div className="grid-line"></div><div className="grid-line"></div>
                            <div className="grid-line"></div><div className="grid-line"></div>
                            <div className="grid-line"></div>
                        </div>
                        <div className="bars-container">
                            {chartData.map((day, idx) => {
                                // Calculate percentages for heights
                                const pendingCount = day.total - day.completed;
                                const pendingHeight = chartMax > 0 ? (pendingCount / chartMax) * 100 : 0;
                                const completedHeight = chartMax > 0 ? (day.completed / chartMax) * 100 : 0;

                                return (
                                    <div className="bar-group" key={idx} title={`${day.total} Total Sessions`}>
                                        <div className="bar-top" style={{ height: `${pendingHeight}%` }}></div>
                                        <div className="bar-bottom" style={{ height: `${completedHeight}%` }}></div>
                                        <span className="x-label">{day.label}</span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>

                {/* RECENT ACTIVITY CARD */}
                <div className="activity-card">
                    <div className="activity-title">Recent Activity</div>

                    {loading && <p style={{ color: "#9ca3af", fontSize: 13 }}>Loading...</p>}

                    {!loading && recentActivity.length === 0 && (
                        <p style={{ color: "#9ca3af", fontSize: 13, marginTop: 12 }}>
                            No activity recorded in the audit log yet.
                        </p>
                    )}

                    {!loading && recentActivity.map((item) => (
                        <div key={item.id} className="activity-item">
                            <div className="activity-info">
                                <div className="activity-name">{item.name}</div>
                                <div className="activity-detail">{item.detail}</div>
                            </div>
                            <div className="activity-time">{item.time}</div>
                        </div>
                    ))}
                </div>
            </div>
        </Layout>
    );
}

function timeAgo(date: Date): string {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    if (seconds < 60) return "just now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
}