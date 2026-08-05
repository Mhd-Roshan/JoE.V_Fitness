import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
    doc,
    getDoc,
    collection,
    query,
    where,
    orderBy,
    getDocs,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/sessionHistory.css";

interface ClientInfo {
    fullName: string;
}

interface SessionRow {
    id: string;
    serviceType: string;
    trainerName: string;
    scheduledDate: string;
    status: string;
    notes?: string;
}

const STATUS_FILTERS = ["all", "completed", "scheduled", "cancelled"] as const;
type StatusFilter = (typeof STATUS_FILTERS)[number];

export default function SessionHistory() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();

    const [client, setClient] = useState<ClientInfo | null>(null);
    const [sessions, setSessions] = useState<SessionRow[]>([]);
    const [filter, setFilter] = useState<StatusFilter>("all");
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!id) return;

        async function loadSessions() {
            try {
                const userSnap = await getDoc(doc(db, "users", id!));
                if (userSnap.exists()) {
                    setClient({ fullName: userSnap.data().fullName ?? "Unknown Client" });
                }

                const sessionsQuery = query(
                    collection(db, "sessions"),
                    where("clientId", "==", id),
                    orderBy("scheduledDate", "desc")
                );
                const sessionsSnap = await getDocs(sessionsQuery);

                const rows = await Promise.all(
                    sessionsSnap.docs.map(async (d) => {
                        const data = d.data();
                        let trainerName = "—";
                        if (data.trainerId) {
                            const trainerSnap = await getDoc(doc(db, "users", data.trainerId));
                            trainerName = trainerSnap.exists()
                                ? trainerSnap.data().fullName
                                : "—";
                        }
                        return {
                            id: d.id,
                            serviceType: data.serviceType ?? "Session",
                            trainerName,
                            scheduledDate: data.scheduledDate ?? "—",
                            status: data.status ?? "scheduled",
                            notes: data.notes,
                        };
                    })
                );
                setSessions(rows);
            } catch (err) {
                console.error("Session history load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadSessions();
    }, [id]);

    const filtered =
        filter === "all" ? sessions : sessions.filter((s) => s.status === filter);

    const counts = {
        all: sessions.length,
        completed: sessions.filter((s) => s.status === "completed").length,
        scheduled: sessions.filter((s) => s.status === "scheduled").length,
        cancelled: sessions.filter((s) => s.status === "cancelled").length,
    };

    if (loading) {
        return (
            <Layout title="Users Managements">
                <p style={{ color: "#999" }}>Loading session history...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Users Managements">
            <button
                className="profile-back-btn"
                onClick={() => navigate(`/users/${id}`)}
            >
                <i className="bx bx-arrow-back" /> Back to Profile
            </button>

            <div className="session-header-card">
                <div className="session-header-title">
                    {client?.fullName ?? "Client"} — Session History
                </div>
                <div className="session-header-count">{sessions.length} Total</div>
            </div>

            <div className="profile-tabs">
                {STATUS_FILTERS.map((s) => (
                    <button
                        key={s}
                        className={`profile-tab-btn ${filter === s ? "active" : ""}`}
                        onClick={() => setFilter(s)}
                    >
                        {s === "all" ? "All" : s[0].toUpperCase() + s.slice(1)} ({counts[s]})
                    </button>
                ))}
            </div>

            <div className="profile-card">
                {filtered.length === 0 ? (
                    <div className="profile-empty">
                        No {filter === "all" ? "" : filter} sessions recorded yet.
                    </div>
                ) : (
                    <table className="session-table">
                        <thead>
                            <tr>
                                <th>Date</th>
                                <th>Service</th>
                                <th>Trainer</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map((s) => (
                                <tr key={s.id}>
                                    <td>{s.scheduledDate}</td>
                                    <td>{s.serviceType}</td>
                                    <td>{s.trainerName}</td>
                                    <td>
                                        <span className={`session-status-pill status-${s.status}`}>
                                            {s.status}
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