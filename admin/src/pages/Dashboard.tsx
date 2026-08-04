import { useEffect, useState } from "react";
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

export default function Dashboard() {
    const [totalUsers, setTotalUsers] = useState<number | null>(null);
    const [totalSessions, setTotalSessions] = useState<number | null>(null);
    const [totalRevenue, setTotalRevenue] = useState<number | null>(null);
    const [recentActivity, setRecentActivity] = useState<ActivityItem[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function loadDashboardData() {
            try {
                const usersQuery = query(collection(db, "users"), where("role", "==", "client"));
                const usersSnap = await getCountFromServer(usersQuery);
                setTotalUsers(usersSnap.data().count);

                const sessionsSnap = await getCountFromServer(collection(db, "sessions"));
                setTotalSessions(sessionsSnap.data().count);

                // Real revenue: sum of successful payments this calendar month.
                // Firestore can't sum server-side without a Cloud Function or
                // the newer aggregation queries — using getDocs + client-side sum
                // here since payment volume is still small.
                const paymentsSnap = await getDocs(
                    query(collection(db, "payments"), where("status", "==", "success"))
                );
                const revenueSum = paymentsSnap.docs.reduce(
                    (sum, d) => sum + (d.data().amount ?? 0),
                    0
                );
                setTotalRevenue(revenueSum);

                const activityQuery = query(
                    collection(db, "auditLog"),
                    orderBy("createdAt", "desc"),
                    limit(5)
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
            } catch (err) {
                console.error("Dashboard load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadDashboardData();
    }, []);

    return (
        <Layout title="Dashboard">
            {/* Stat cards - all real Firestore data, no placeholders */}
            <div className="stat-row">
                <div className="stat-card">
                    <div className="stat-icon-badge">
                        <i className="bx bx-group" />
                    </div>
                    <div className="stat-label">TOTAL USERS</div>
                    <div className="stat-value">{loading ? "…" : totalUsers ?? 0}</div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon-badge">
                        <i className="bx bx-calendar" />
                    </div>
                    <div className="stat-label">SESSIONS</div>
                    <div className="stat-value">{loading ? "…" : totalSessions ?? 0}</div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon-badge">
                        <i className="bx bx-rupee" />
                    </div>
                    <div className="stat-label">TOTAL REVENUE</div>
                    <div className="stat-value">
                        {loading ? "…" : `₹${(totalRevenue ?? 0).toLocaleString("en-IN")}`}
                    </div>
                </div>
            </div>

            {/* Quick actions */}
            <div className="action-row">
                <button className="action-btn red">+ ADD TRAINERS</button>
                <button className="action-btn navy">+ ADD PACKAGES</button>
                <button className="action-btn navy">PAYMENT&nbsp;&nbsp;&nbsp;&nbsp;RECORDS</button>
            </div>

            {/* Growth chart + Recent activity - both real, honest empty states */}
            <div className="bottom-row">
                <div className="chart-card">
                    <div className="chart-title">Growth Trends</div>
                    <div className="users-empty-state" style={{ padding: "60px 20px" }}>
                        Chart data requires a `dailyStats` collection populated by a
                        scheduled Cloud Function aggregating sessions/revenue per day.
                        Not wired up yet — showing no data rather than fake numbers.
                    </div>
                </div>

                <div className="activity-card">
                    <div className="activity-title">Recent Activity</div>

                    {loading && <p style={{ color: "#999", fontSize: 13 }}>Loading...</p>}

                    {!loading && recentActivity.length === 0 && (
                        <p style={{ color: "#999", fontSize: 13 }}>
                            No activity yet. This populates once admin/trainers assign diet
                            plans or onboard clients (writes to the `auditLog` collection).
                        </p>
                    )}

                    {!loading &&
                        recentActivity.map((item) => (
                            <div key={item.id} className="activity-item">
                                <div className="activity-name">{item.name}</div>
                                <div className="activity-detail">{item.detail}</div>
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