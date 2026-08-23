import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs, doc, deleteDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/trainers.css";
import "../styles/sessions.css";

// ----------------------------------------------------
// TypeScript Interfaces
// ----------------------------------------------------
interface TrainerCard {
    id: string;
    fullName: string;
    initials: string;
    designation: string;
    yearsExperience: number;
    status: string;
    clientCount: number;
    todaySessions: number;
    completionPct: number;
}

interface ScheduleRow {
    id: string;
    time: string;
    clientName: string;
    area: string;
    service: string;
    notes: string;
    trainerName: string;
    status: string;
}

// Interfaces for Firebase Documents
interface UserData {
    id: string;
    role?: string;
    fullName?: string;
    trainerId?: string;
    assignedTrainer?: string;
    assignedTrainerId?: string;
}

interface TrainerProfileData {
    trainerId?: string;
    designation?: string;
    yearsExperience?: number;
    status?: string;
}

interface SessionData {
    id: string;
    trainerId?: string;
    trainerName?: string;
    scheduledDate?: string;
    date?: string;
    status?: string;
    clientId?: string;
    clientName?: string;
    area?: string;
    service?: string;
    serviceType?: string;
    time?: string;
    scheduledTime?: string;
    notes?: string;
    sessionNotes?: string;
}

interface SubscriptionData {
    id: string;
    trainerId?: string;
    assignedTrainer?: string;
    trainerName?: string;
    status?: string;
}

// ----------------------------------------------------
// Helper Functions
// ----------------------------------------------------
function isToday(dateInput?: string) {
    if (!dateInput) return false;

    const today = new Date();
    const iso = today.toISOString().slice(0, 10);

    const d = String(today.getDate()).padStart(2, '0');
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const y = today.getFullYear();

    const formats = [
        iso,
        `${y}/${m}/${d}`,
        `${d}-${m}-${y}`,
        `${d}/${m}/${y}`,
        `${m}-${d}-${y}`,
        `${m}/${d}/${y}`
    ];

    return formats.includes(dateInput);
}

// ----------------------------------------------------
// Component
// ----------------------------------------------------
export default function Trainers() {
    const navigate = useNavigate();
    const [trainers, setTrainers] = useState<TrainerCard[]>([]);
    const [schedule, setSchedule] = useState<ScheduleRow[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let isMounted = true;

        async function loadData() {
            try {
                // 1. Fetch EVERYTHING we need first 
                const [usersSnap, trainersSnap, sessionsSnap, subsSnap] = await Promise.all([
                    getDocs(collection(db, "users")),
                    getDocs(collection(db, "trainers")),
                    getDocs(collection(db, "sessions")),
                    getDocs(collection(db, "subscriptions"))
                ]);

                const allUsers = usersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as UserData));
                const allTrainerProfiles = trainersSnap.docs.map(doc => doc.data() as TrainerProfileData);
                const allSessions = sessionsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as SessionData));
                const allSubs = subsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as SubscriptionData));

                // 2. Separate users into Trainers and Clients
                const trainersList = allUsers.filter(u => u.role?.toLowerCase() === "trainer");
                const clientsList = allUsers.filter(u => u.role?.toLowerCase() !== "trainer");

                // 3. Build Trainer Cards
                const trainerRows = trainersList.map((trainer) => {
                    const tProfile = allTrainerProfiles.find(tp => tp.trainerId === trainer.id) || {};

                    // COUNT CLIENTS
                    const clientSubs = allSubs.filter(sub =>
                        (sub.trainerId === trainer.id || sub.assignedTrainer === trainer.id || sub.trainerName === trainer.fullName) &&
                        (!sub.status || sub.status.toLowerCase() === 'active')
                    );

                    const clientUsers = clientsList.filter(c =>
                        c.trainerId === trainer.id ||
                        c.assignedTrainer === trainer.id ||
                        c.assignedTrainerId === trainer.id
                    );

                    const totalClients = Math.max(clientSubs.length, clientUsers.length);

                    // TODAY'S SESSIONS
                    const trainerSessionsToday = allSessions.filter(s =>
                        (s.trainerId === trainer.id || s.trainerName === trainer.fullName) &&
                        isToday(s.scheduledDate || s.date)
                    );

                    const todayCount = trainerSessionsToday.length;

                    // COUNT COMPLETION %
                    const completedCount = trainerSessionsToday.filter(s => {
                        const status = (s.status || "").toLowerCase();
                        return status === "completed" || status === "done";
                    }).length;

                    const name = trainer.fullName || "Unnamed Trainer";
                    const initials = name.split(" ").map((p: string) => p[0]).join("").slice(0, 2).toUpperCase();

                    return {
                        id: trainer.id,
                        fullName: name,
                        initials: initials || "TR",
                        designation: tProfile.designation || "Personal Trainer",
                        yearsExperience: tProfile.yearsExperience || 0,
                        status: tProfile.status || "Active",
                        clientCount: totalClients,
                        todaySessions: todayCount,
                        completionPct: todayCount === 0 ? 0 : Math.round((completedCount / todayCount) * 100),
                    };
                });

                // 4. Build Today's Schedule Table
                const todayAllSessions = allSessions.filter(s => isToday(s.scheduledDate || s.date));

                const scheduleRows = todayAllSessions.map(data => {
                    let clientName = data.clientName;
                    if (!clientName && data.clientId) {
                        const clientMatch = allUsers.find(u => u.id === data.clientId);
                        if (clientMatch) clientName = clientMatch.fullName;
                    }

                    let trainerName = data.trainerName;
                    if (!trainerName && data.trainerId) {
                        const trainerMatch = trainersList.find(u => u.id === data.trainerId);
                        if (trainerMatch) trainerName = trainerMatch.fullName;
                    }

                    return {
                        id: data.id,
                        time: (data.scheduledTime || data.time) ?? "—",
                        clientName: clientName ?? "Unknown Client",
                        area: data.area ?? "—",
                        service: (data.serviceType || data.service) ?? "—",
                        notes: data.notes ?? data.sessionNotes ?? "",
                        trainerName: trainerName ?? "Unknown Trainer",
                        status: data.status ?? "Scheduled",
                    };
                });

                if (isMounted) {
                    setTrainers(trainerRows);
                    setSchedule(scheduleRows.sort((a, b) => a.time.localeCompare(b.time)));
                }

            } catch (err) {
                console.error("Error fetching data from Firebase:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        loadData();

        return () => { isMounted = false; };
    }, []);

    // ----------------------------------------------------
    // Delete Trainer Function
    // ----------------------------------------------------
    const handleDeleteTrainer = async (trainerId: string) => {
        const confirmDelete = window.confirm(
            "Are you sure you want to delete this trainer? This action cannot be undone."
        );
        if (!confirmDelete) return;

        try {
            // Delete from both users and trainers collections
            await deleteDoc(doc(db, "trainers", trainerId));
            await deleteDoc(doc(db, "users", trainerId));

            // Remove from UI immediately without refreshing
            setTrainers((prev) => prev.filter((t) => t.id !== trainerId));

            alert("Trainer deleted successfully.");
        } catch (error) {
            console.error("Error deleting trainer:", error);
            alert("An error occurred while trying to delete the trainer.");
        }
    };

    const formattedDate = new Date().toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
    });

    if (loading) {
        return (
            <Layout title="Trainers">
                <p style={{ color: "#9ca3af", padding: "20px", fontSize: "14px" }}>Loading trainers...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Trainers">
            <div className="trainers-page-header">
                <div>
                    <h1 className="trainers-page-title">Trainers Management</h1>
                    <p className="trainers-page-subtitle">
                        Add trainers and view the details to there scheduling.
                    </p>
                </div>
                <button className="trainers-add-btn" onClick={() => navigate("/trainers/add")}>
                    <i className="bx bx-plus" style={{ marginRight: '5px' }}></i> Add Trainers
                </button>
            </div>

            {/* TRAINERS CARDS GRID */}
            {trainers.length === 0 ? (
                <div className="profile-empty" style={{ background: '#fff', padding: '30px', borderRadius: '12px', border: '1px solid #e5e7eb' }}>
                    No trainers added yet.
                </div>
            ) : (
                <div className="trainers-card-grid">
                    {trainers.map((t) => (
                        <div key={t.id} className="trainer-card">
                            <div className="trainer-card-top">
                                <div className="trainer-profile-section">
                                    <div className="trainer-avatar-circle">{t.initials}</div>
                                    <div className="trainer-info">
                                        <div className="trainer-name">{t.fullName}</div>
                                        <div className="trainer-designation">
                                            {t.designation} . {t.yearsExperience} yrs
                                        </div>
                                    </div>
                                </div>
                                <span className={`trainer-status-pill ${t.status.toLowerCase() === 'active' ? 'active-pill' : ''}`}>
                                    {t.status}
                                </span>
                            </div>

                            <div className="trainer-stats-list">
                                <div className="trainer-stat-row">
                                    <span className="stat-label">Client</span>
                                    <span className="stat-value">{String(t.clientCount).padStart(2, '0')}</span>
                                </div>
                                <div className="trainer-stat-row">
                                    <span className="stat-label">Today's sessions</span>
                                    <span className="stat-value">{String(t.todaySessions).padStart(2, '0')}</span>
                                </div>
                                <div className="trainer-stat-row">
                                    <span className="stat-label">Completion</span>
                                    <div className="stat-progress-wrapper">
                                        <div className="trainer-progress-track">
                                            <div
                                                className="trainer-progress-fill"
                                                style={{ width: `${t.completionPct}%` }}
                                            />
                                        </div>
                                        <span className="stat-value">{t.completionPct}%</span>
                                    </div>
                                </div>
                            </div>

                            {/* UPDATED ACTION BUTTONS */}
                            <div className="trainer-card-actions" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                <button
                                    className="trainer-action-btn-outline"
                                    onClick={() => navigate(`/trainers/${t.id}`)}
                                    style={{ flex: 1 }}
                                >
                                    <i className="bx bx-calendar"></i> View Schedule
                                </button>
                                <button
                                    className="trainer-action-btn-outline"
                                    onClick={() => navigate("/trainers/assign")}
                                    style={{ flex: 1 }}
                                >
                                    <i className="bx bx-user-plus"></i> Assign
                                </button>

                                {/* DELETE BUTTON */}
                                <button
                                    className="trainer-action-btn-outline"
                                    onClick={() => handleDeleteTrainer(t.id)}
                                    title="Delete Trainer"
                                    style={{
                                        padding: '8px 12px',
                                        color: '#d20015',
                                        borderColor: '#ffcdd2',
                                        backgroundColor: '#fef2f2'
                                    }}
                                >
                                    <i className="bx bx-trash" style={{ fontSize: '18px' }}></i>
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* SESSIONS TABLE */}
            <div className="sessions-table-card" style={{ marginTop: "32px" }}>

                {/* TABLE HEADER */}
                <div className="sessions-table-header">
                    <h3 className="sessions-table-title">Full Schedule - Today, {formattedDate}</h3>
                    <button
                        className="sessions-action-btn"
                        onClick={() => navigate('/sessions')}
                        style={{ border: "none", color: "#00225d", display: "flex", alignItems: "center", gap: "6px", fontWeight: "700" }}
                    >
                        <i className="bx bx-calendar" /> All Sessions
                    </button>
                </div>

                {/* TABLE */}
                <div style={{ overflowX: "auto" }}>
                    <table className="sessions-table">
                        <thead>
                            <tr>
                                <th>TIME</th>
                                <th>TRAINER</th>
                                <th>CLIENT</th>
                                <th>SERVICE</th>
                                <th>STATUS</th>
                                <th>NOTES</th>
                            </tr>
                        </thead>
                        <tbody>
                            {schedule.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ textAlign: "center", color: "#94a3b8", padding: "32px" }}>
                                        No sessions scheduled for today.
                                    </td>
                                </tr>
                            ) : (
                                schedule.map((row) => {
                                    const statusLower = row.status.toLowerCase();
                                    const statusClass =
                                        statusLower === "done" || statusLower === "completed" ? "done" :
                                            statusLower === "live" ? "live" : "upcoming";

                                    return (
                                        <tr key={row.id}>
                                            <td className="sessions-mono" style={{ color: statusLower === 'live' || row.time.includes('10:00') ? '#bb0013' : 'inherit' }}>
                                                {row.time}
                                            </td>
                                            <td>{row.trainerName}</td>
                                            <td className="sessions-bold">{row.clientName}</td>
                                            <td>
                                                <span className="sessions-service-pill">
                                                    {row.service}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`sessions-status-pill ${statusClass}`}>
                                                    {statusLower === "live" && <div className="live-dot"></div>}
                                                    {row.status}
                                                </span>
                                            </td>
                                            <td style={{ color: "#808080", fontSize: "13px" }}>
                                                {row.notes}
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

        </Layout>
    );
}