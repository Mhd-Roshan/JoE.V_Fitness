import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getCountFromServer, query, where, getDocs, orderBy, limit } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/dashboard.css";

interface ActivityItem {
    id: string;
    name: string;
    detail: string;
    time: string;
    timestamp: number;
}

interface ChartDay {
    label: string;
    dateStr: string;
    total: number;
    completed: number;
}

export default function Dashboard() {
    const navigate = useNavigate();

    const [totalUsers, setTotalUsers] = useState<number | null>(null);
    const [totalSessions, setTotalSessions] = useState<number | null>(null);
    const [totalRevenue, setTotalRevenue] = useState<number | null>(null);
    const [recentActivity, setRecentActivity] = useState<ActivityItem[]>([]);

    // Chart State
    const [chartData, setChartData] = useState<ChartDay[]>([]);
    const [chartMax, setChartMax] = useState<number>(10);
    const [timeRange, setTimeRange] = useState<"1W" | "1M">("1W");

    const [loading, setLoading] = useState(true);
    const currentMonthLabel = new Date().toLocaleString('default', { month: 'long' }).toUpperCase();

    useEffect(() => {
        async function loadDashboardData() {
            try {
                // 1. REAL TOTAL USERS
                const usersQuery = query(collection(db, "users"), where("role", "==", "client"));
                const usersSnap = await getCountFromServer(usersQuery);
                setTotalUsers(usersSnap.data().count);

                // 2. REAL TOTAL BOOKINGS (Sessions)
                const bookingsSnapCount = await getCountFromServer(collection(db, "bookings"));
                setTotalSessions(bookingsSnapCount.data().count);

                // 3. REAL REVENUE (From payments collection)
                const paymentsSnap = await getDocs(query(collection(db, "payments"), where("status", "==", "success")));
                const revenueSum = paymentsSnap.docs.reduce((sum, d) => sum + (Number(d.data().amount) || 0), 0);
                setTotalRevenue(revenueSum);

                // ==========================================
                // 4. REAL CHART DATA (From 'bookings' collection)
                // ==========================================
                const daysToFetch = timeRange === "1W" ? 7 : 30;
                const today = new Date();

                // Create an empty array for the last X days
                const dateRange: ChartDay[] = Array.from({ length: daysToFetch }, (_, i) => {
                    const d = new Date(today);
                    d.setDate(d.getDate() - ((daysToFetch - 1) - i));

                    // Format as YYYY-MM-DD to match standard db formats
                    const localDateStr = d.toLocaleDateString('en-CA'); // 'en-CA' outputs YYYY-MM-DD

                    return {
                        dateStr: localDateStr,
                        label: timeRange === "1W"
                            ? d.toLocaleDateString("en-US", { weekday: 'short' }).substring(0, 2).toUpperCase()
                            : d.getDate().toString(),
                        total: 0,
                        completed: 0
                    };
                });

                // Fetch all bookings (you can add a where clause if you have indexes)
                const allBookingsSnap = await getDocs(collection(db, "bookings"));

                allBookingsSnap.docs.forEach(doc => {
                    const data = doc.data();
                    const bookingDate = data.date; // E.g., "2023-11-25"

                    const dayIndex = dateRange.findIndex(d => d.dateStr === bookingDate);
                    if (dayIndex !== -1) {
                        dateRange[dayIndex].total += 1;
                        if (data.status === 'completed' || data.status === 'Complete') {
                            dateRange[dayIndex].completed += 1;
                        }
                    }
                });

                // Dynamically scale Y-Axis based on actual data
                const maxSessions = Math.max(...dateRange.map(d => d.total));
                const dynamicMax = maxSessions < 5 ? 5 : Math.ceil(maxSessions / 5) * 5;

                setChartMax(dynamicMax);
                setChartData(dateRange);

                // ==========================================
                // 5. REAL RECENT ACTIVITY (Mixed feed from users & bookings)
                // ==========================================
                const activityFeed: ActivityItem[] = [];

                // PRE-FETCH USERS TO GET REAL NAMES FOR BOOKINGS
                const allUsersMap = new Map<string, string>();
                const allUsersSnap = await getDocs(collection(db, "users"));
                allUsersSnap.docs.forEach(doc => {
                    const d = doc.data();
                    allUsersMap.set(doc.id, d.fullName || d.name || "Unknown Client");
                });

                // Get newest users
                const recentUsersSnap = await getDocs(query(collection(db, "users"), orderBy("createdAt", "desc"), limit(3)));
                recentUsersSnap.docs.forEach(doc => {
                    const d = doc.data();
                    if (d.createdAt) {
                        const dateObj = d.createdAt.toDate ? d.createdAt.toDate() : new Date(d.createdAt);

                        // Check if the user is a trainer or client
                        const role = (d.role || "client").toLowerCase();
                        const isTrainer = role === "trainer";

                        activityFeed.push({
                            id: `u-${doc.id}`,
                            name: d.fullName || d.name || (isTrainer ? "New Trainer" : "New Client"),
                            // Display different text based on role
                            detail: isTrainer ? "Added as a new trainer" : "Registered as a new client",
                            time: timeAgo(dateObj),
                            timestamp: dateObj.getTime()
                        });
                    }
                });

                // Get newest bookings (fetch a bit more, sort by date)
                const recentBookingsSnap = await getDocs(collection(db, "bookings"));
                recentBookingsSnap.docs.forEach(doc => {
                    const d = doc.data();
                    const dateObj = d.createdAt?.toDate ? d.createdAt.toDate() : new Date(d.date + "T" + (d.time || "00:00:00"));

                    if (!isNaN(dateObj.getTime())) {

                        // Extract Name using mapping if missing
                        let resolvedName = d.clientName || d.userName;
                        if (!resolvedName && d.clientId) {
                            resolvedName = allUsersMap.get(d.clientId);
                        }
                        if (!resolvedName && d.userId) {
                            resolvedName = allUsersMap.get(d.userId);
                        }

                        activityFeed.push({
                            id: `b-${doc.id}`,
                            name: resolvedName || "Unknown Client",
                            detail: `Booked ${d.serviceType || d.sessionType || d.service || "a session"}`,
                            time: timeAgo(dateObj),
                            timestamp: dateObj.getTime()
                        });
                    }
                });

                // Sort everything by timestamp, newest first, and take top 4
                activityFeed.sort((a, b) => b.timestamp - a.timestamp);
                setRecentActivity(activityFeed.slice(0, 4));

            } catch (err) {
                console.error("Dashboard load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadDashboardData();
    }, [timeRange]); // Re-run if they toggle 1W / 1M

    const formatRevenue = (rev: number | null) => {
        if (rev === null) return "…";
        if (rev >= 100000) return `₹${(rev / 100000).toFixed(1)}L`;
        return `₹${rev.toLocaleString("en-IN")}`;
    };

    return (
        <Layout title="Dashboard">
            {/* STATS ROW */}
            <div className="stat-row">
                <div className="stat-card">
                    <div className="stat-header">
                        <div className="stat-label">TOTAL USERS</div>
                        <div className="stat-icon-badge"><i className="bx bx-group" /></div>
                    </div>
                    <div className="stat-value">{loading ? "…" : totalUsers ?? 0}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        Live Data
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-header">
                        <div className="stat-label">TOTAL SESSIONS</div>
                        <div className="stat-icon-badge"><i className="bx bx-calendar" /></div>
                    </div>
                    <div className="stat-value">{loading ? "…" : totalSessions ?? 0}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        Live Data
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-header">
                        <div className="stat-label">{currentMonthLabel} REVENUE</div>
                        <div className="stat-icon-badge"><i className="bx bx-credit-card-front" /></div>
                    </div>
                    <div className="stat-value">{formatRevenue(totalRevenue)}</div>
                    <div className="stat-trend">
                        <i className="bx bx-trending-up" />
                        Live Data
                    </div>
                </div>
            </div>

            {/* QUICK ACTIONS ROW */}
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

                {/* REAL FIREBASE DYNAMIC CHART */}
                <div className="chart-card">
                    <div className="chart-header">
                        <div className="chart-title">Growth Trends (Bookings)</div>
                        <div className="chart-toggles">
                            <button
                                className={`chart-toggle ${timeRange === "1W" ? "active" : ""}`}
                                onClick={() => setTimeRange("1W")}
                            >1W</button>
                            <button
                                className={`chart-toggle ${timeRange === "1M" ? "active" : ""}`}
                                onClick={() => setTimeRange("1M")}
                            >1M</button>
                        </div>
                    </div>

                    <div className="mock-chart-container">
                        {/* Dynamic Y Axis based on Real Data Max */}
                        <div className="y-axis">
                            <span>{chartMax}</span>
                            <span>{Math.round(chartMax * 0.8)}</span>
                            <span>{Math.round(chartMax * 0.6)}</span>
                            <span>{Math.round(chartMax * 0.4)}</span>
                            <span>{Math.round(chartMax * 0.2)}</span>
                        </div>
                        <div className="grid-lines">
                            <div className="grid-line"></div>
                            <div className="grid-line"></div>
                            <div className="grid-line"></div>
                            <div className="grid-line"></div>
                            <div className="grid-line"></div>
                        </div>

                        <div className="bars-container" style={{ gap: timeRange === "1M" ? '2px' : 'normal' }}>
                            {chartData.map((day, idx) => {
                                const pendingCount = day.total - day.completed;
                                const pendingHeight = chartMax > 0 ? (pendingCount / chartMax) * 100 : 0;
                                const completedHeight = chartMax > 0 ? (day.completed / chartMax) * 100 : 0;

                                // Hide x-labels on 1M view so it doesn't look messy
                                const showLabel = timeRange === "1W" || (idx % 3 === 0);

                                return (
                                    <div className="bar-group" key={idx} title={`${day.dateStr}: ${day.total} Total Bookings`} style={{ width: timeRange === "1M" ? '12px' : '24px' }}>
                                        <div className="bar-top" style={{ height: `${pendingHeight}%` }}></div>
                                        <div className="bar-bottom" style={{ height: `${completedHeight}%` }}></div>
                                        {showLabel && <span className="x-label" style={{ fontSize: timeRange === "1M" ? '9px' : '12px' }}>{day.label}</span>}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>

                {/* REAL RECENT ACTIVITY CARD */}
                <div className="activity-card">
                    <div className="activity-title" style={{ marginBottom: '10px' }}>Recent Activity</div>

                    {loading && <p style={{ color: "#9ca3af", fontSize: 13, marginTop: '20px' }}>Loading live data...</p>}

                    {!loading && recentActivity.length === 0 && (
                        <p style={{ color: "#9ca3af", fontSize: 13, marginTop: '20px' }}>
                            No recent activity found in database.
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
    if (seconds < 60 || seconds < 0) return "just now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
}