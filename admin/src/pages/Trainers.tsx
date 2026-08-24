import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs, doc, deleteDoc, writeBatch } from "firebase/firestore";
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
    photoURL: string | null; // Added photoURL
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
    clientId: string;
    clientName: string;
    area: string;
    service: string;
    notes: string;
    trainerId: string;
    trainerName: string;
    status: string;
}

// Interfaces for Firebase Documents
interface UserData {
    id: string;
    role?: string;
    fullName?: string;
    name?: string;
    email?: string;
    trainerId?: string;
    assignedTrainer?: string;
    assignedTrainerId?: string;
    photoURL?: string | null; // Added photoURL
}

interface TrainerProfileData {
    id?: string;
    trainerId?: string;
    fullName?: string;
    email?: string;
    designation?: string;
    yearsExperience?: number;
    status?: string;
    photoURL?: string | null; // Added photoURL
}

interface SessionData {
    id: string;
    trainerId?: string;
    assignedTrainerId?: string;
    assignedTrainer?: string;
    assignedTrainerName?: string;
    trainerName?: string;
    trainer?: string;
    trainerEmail?: string;
    scheduledDate?: unknown;
    date?: unknown;
    sessionDate?: unknown;
    bookingDate?: unknown;
    createdAt?: unknown;
    timestamp?: unknown;
    status?: string;
    clientId?: string;
    userId?: string;
    client_id?: string;
    user_id?: string;
    uid?: string;
    clientName?: string;
    client?: string;
    userName?: string;
    userFullName?: string;
    customerName?: string;
    name?: string;
    userEmail?: string;
    clientEmail?: string;
    email?: string;
    area?: string;
    service?: string;
    serviceType?: string;
    sessionType?: string;
    plan?: string;
    time?: string;
    startTime?: string;
    scheduledTime?: string;
    notes?: string;
    sessionNotes?: string;
    trainerNotes?: string;
    [key: string]: unknown;
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
function parseDateFlexible(val: unknown): Date | null {
    if (!val) return null;
    if (typeof (val as { toDate?: () => Date }).toDate === "function") {
        return (val as { toDate: () => Date }).toDate();
    }
    if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
    if (typeof val === "number") {
        const ms = val < 10000000000 ? val * 1000 : val;
        const d = new Date(ms);
        return isNaN(d.getTime()) ? null : d;
    }
    if (typeof val === "string") {
        const s = val.trim();
        if (!s || s === "—") return null;

        const parsed = new Date(s);
        if (!isNaN(parsed.getTime())) return parsed;

        const isoMatch = s.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/);
        if (isoMatch) {
            const y = parseInt(isoMatch[1], 10);
            const m = parseInt(isoMatch[2], 10) - 1;
            const d = parseInt(isoMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }

        const dmyMatch = s.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})/);
        if (dmyMatch) {
            const d = parseInt(dmyMatch[1], 10);
            const m = parseInt(dmyMatch[2], 10) - 1;
            const y = parseInt(dmyMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }
    }
    return null;
}

function isToday(dateInput?: unknown): boolean {
    const d = parseDateFlexible(dateInput);
    if (!d) return false;
    const today = new Date();
    return (
        d.getFullYear() === today.getFullYear() &&
        d.getMonth() === today.getMonth() &&
        d.getDate() === today.getDate()
    );
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
                // 1. Fetch EVERYTHING we need (users, trainers, sessions, bookings, subscriptions)
                const [usersSnap, trainersSnap, sessionsSnap, bookingsSnap, subsSnap] = await Promise.all([
                    getDocs(collection(db, "users")),
                    getDocs(collection(db, "trainers")),
                    getDocs(collection(db, "sessions")),
                    getDocs(collection(db, "bookings")),
                    getDocs(collection(db, "subscriptions"))
                ]);

                const allUsers = usersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as UserData));
                const allTrainerProfiles = trainersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as TrainerProfileData));
                const allSubs = subsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() } as SubscriptionData));

                // Build comprehensive map of client IDs to real names
                const userNamesMap: Record<string, string> = {};
                usersSnap.docs.forEach((uDoc) => {
                    const uData = uDoc.data();
                    const name = (uData.fullName || uData.name || uData.displayName || uData.username || uData.email || uData.phone || "").toString().trim();
                    if (name) {
                        userNamesMap[uDoc.id] = name;
                        if (uData.uid) userNamesMap[uData.uid] = name;
                        if (uData.userId) userNamesMap[uData.userId] = name;
                    }
                });

                // Merge & deduplicate sessions and bookings
                const uniqueSessionsMap = new Map<string, SessionData>();
                [...sessionsSnap.docs, ...bookingsSnap.docs].forEach(docSnap => {
                    const data = docSnap.data() as Record<string, unknown>;
                    const key = (data.bookingId || data.sessionId || docSnap.id) as string;
                    if (!uniqueSessionsMap.has(key)) {
                        uniqueSessionsMap.set(key, { id: docSnap.id, ...data } as SessionData);
                    }
                });
                const allSessions = Array.from(uniqueSessionsMap.values());

                // 2. Separate users into Trainers and Clients
                const rawTrainersList = allUsers.filter(u => u.role?.toLowerCase() === "trainer");
                const clientsList = allUsers.filter(u => u.role?.toLowerCase() !== "trainer");

                // Build client-to-trainer map for fallback matching
                const clientToTrainerMap: Record<string, string> = {};
                clientsList.forEach(c => {
                    const assigned = c.assignedTrainerId || c.assignedTrainer || c.trainerId || "";
                    if (assigned) clientToTrainerMap[c.id] = assigned.toString().trim();
                });

                // Filter out and auto-clean phantom/orphan trainer documents that have no valid name or are unnamed
                const trainersList: UserData[] = [];
                for (const trainer of rawTrainersList) {
                    const tProfile = allTrainerProfiles.find(tp => tp.trainerId === trainer.id || tp.id === trainer.id);
                    const name = (trainer.fullName || tProfile?.fullName || trainer.name || "").trim();
                    const email = (trainer.email || tProfile?.email || "").trim();

                    // If it's a completely empty or unnamed phantom doc from past incomplete deletions, purge it from Firestore
                    if (!name && !email) {
                        deleteDoc(doc(db, "users", trainer.id)).catch(() => {});
                        deleteDoc(doc(db, "trainers", trainer.id)).catch(() => {});
                        continue;
                    }

                    if (name.toLowerCase() === "unnamed trainer" || name.toLowerCase() === "unknown trainer") {
                        deleteDoc(doc(db, "users", trainer.id)).catch(() => {});
                        deleteDoc(doc(db, "trainers", trainer.id)).catch(() => {});
                        continue;
                    }

                    trainersList.push(trainer);
                }

                // 3. Build Trainer Cards
                const trainerRows = trainersList.map((trainer) => {
                    const tProfile = allTrainerProfiles.find(tp => tp.trainerId === trainer.id || tp.id === trainer.id) || {};
                    const tName = (trainer.fullName || tProfile.fullName || trainer.name || "").toLowerCase().trim();
                    const tEmail = (trainer.email || tProfile.email || "").toLowerCase().trim();

                    // COUNT CLIENTS
                    const clientSubs = allSubs.filter(sub =>
                        (sub.trainerId === trainer.id || sub.assignedTrainer === trainer.id || sub.trainerName === trainer.fullName) &&
                        (!sub.status || sub.status.toLowerCase() === 'active')
                    );

                    const clientUsers = clientsList.filter(c =>
                        c.trainerId === trainer.id ||
                        c.assignedTrainer === trainer.id ||
                        c.assignedTrainerId === trainer.id ||
                        clientToTrainerMap[c.id] === trainer.id
                    );

                    const totalClients = Math.max(clientSubs.length, clientUsers.length);

                    // TODAY'S SESSIONS (from both sessions & bookings)
                    const trainerSessionsToday = allSessions.filter(s => {
                        const rawDate = s.scheduledDate || s.date || s.sessionDate || s.bookingDate || s.createdAt || s.timestamp;
                        if (!isToday(rawDate)) return false;

                        const sTrainerId = (s.trainerId || s.assignedTrainerId || s.assignedTrainer || "").toString().trim();
                        const sTrainerName = (s.trainerName || "").toString().toLowerCase().trim();
                        const sTrainerEmail = (s.trainerEmail || "").toString().toLowerCase().trim();
                        const sClientId = (s.clientId || s.userId || "").toString().trim();

                        return (
                            sTrainerId === trainer.id ||
                            (tEmail && sTrainerEmail === tEmail) ||
                            (tName && (sTrainerName === tName || sTrainerName.includes(tName) || tName.includes(sTrainerName))) ||
                            (sClientId && clientToTrainerMap[sClientId] === trainer.id)
                        );
                    });

                    const todayCount = trainerSessionsToday.length;

                    // COUNT COMPLETION %
                    const completedCount = trainerSessionsToday.filter(s => {
                        const status = (s.status || "").toLowerCase();
                        return status === "completed" || status === "done";
                    }).length;

                    const name = trainer.fullName || tProfile.fullName || trainer.name || "Trainer";
                    const initials = name.split(" ").map((p: string) => p[0]).join("").slice(0, 2).toUpperCase();

                    // Get photo URL from either the users doc or trainers doc
                    const photoURL = trainer.photoURL || tProfile.photoURL || null;

                    return {
                        id: trainer.id,
                        fullName: name,
                        initials: initials || "TR",
                        photoURL: photoURL,
                        designation: tProfile.designation || "Personal Trainer",
                        yearsExperience: tProfile.yearsExperience || 0,
                        status: tProfile.status || "Active",
                        clientCount: totalClients,
                        todaySessions: todayCount,
                        completionPct: todayCount === 0 ? 0 : Math.round((completedCount / todayCount) * 100),
                    };
                });

                // 4. Build Today's Schedule Table (across all sessions & bookings)
                const todayAllSessions = allSessions.filter(s => {
                    const rawDate = s.scheduledDate || s.date || s.sessionDate || s.bookingDate || s.createdAt || s.timestamp;
                    return isToday(rawDate);
                });

                const scheduleRows = todayAllSessions.map(data => {
                    const clientId = (data.clientId || data.userId || data.client_id || data.user_id || data.uid || "").toString().trim();

                    let clientName = (
                        data.clientName ||
                        data.userName ||
                        data.name ||
                        data.client ||
                        data.userFullName ||
                        data.customerName ||
                        (clientId ? userNamesMap[clientId] : "") ||
                        ""
                    ).toString().trim();

                    if (!clientName || clientName.toLowerCase() === "unknown client" || clientName.toLowerCase() === "unknown") {
                        if (clientId && userNamesMap[clientId]) {
                            clientName = userNamesMap[clientId];
                        } else {
                            const clientMatch = allUsers.find(u => u.id === clientId);
                            if (clientMatch) {
                                clientName = clientMatch.fullName || clientMatch.name || clientMatch.email || "Client";
                            } else {
                                clientName = "Client";
                            }
                        }
                    }

                    const trainerId = (data.trainerId || data.assignedTrainerId || data.assignedTrainer || (clientId ? clientToTrainerMap[clientId] : "") || "").toString().trim();
                    let trainerName = (data.trainerName || data.trainer || data.assignedTrainerName || "").toString().trim();
                    if (!trainerName || trainerName.toLowerCase() === "unknown trainer") {
                        if (trainerId) {
                            const trainerMatch = trainersList.find(u => u.id === trainerId);
                            if (trainerMatch) trainerName = trainerMatch.fullName || trainerMatch.name || "Assigned Trainer";
                        }
                    }
                    if (!trainerName) trainerName = "Assigned Trainer";

                    return {
                        id: data.id,
                        time: (data.startTime || data.scheduledTime || data.time) ?? "—",
                        clientId: clientId,
                        clientName: clientName,
                        area: data.area ?? "—",
                        service: (data.serviceType || data.sessionType || data.service || data.plan) ?? "Personal Training",
                        notes: data.notes ?? data.sessionNotes ?? data.trainerNotes ?? "",
                        trainerId: trainerId,
                        trainerName: trainerName,
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
            const batch = writeBatch(db);

            // 1. Direct doc deletion from both collections
            batch.delete(doc(db, "trainers", trainerId));
            batch.delete(doc(db, "users", trainerId));

            // 2. Query any documents in trainers collection matching trainerId
            const trainersSnap = await getDocs(collection(db, "trainers"));
            trainersSnap.docs.forEach((d) => {
                const data = d.data();
                if (d.id === trainerId || data.trainerId === trainerId || data.userId === trainerId || data.uid === trainerId) {
                    batch.delete(d.ref);
                }
            });

            // 3. Delete availability subcollection
            const availSnap = await getDocs(collection(db, "trainers", trainerId, "availability")).catch(() => ({ docs: [] }));
            availSnap.docs.forEach((d) => batch.delete(d.ref));

            await batch.commit();

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
                                    {/* PHOTO OR INITIALS */}
                                    {t.photoURL ? (
                                        <img
                                            src={t.photoURL}
                                            alt={t.fullName}
                                            className="trainer-avatar-circle"
                                            style={{ objectFit: 'cover' }}
                                        />
                                    ) : (
                                        <div className="trainer-avatar-circle">{t.initials}</div>
                                    )}

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
                                        <tr 
                                            key={row.id} 
                                            onClick={() => navigate('/sessions')}
                                            style={{ cursor: "pointer", transition: "background-color 0.15s ease" }}
                                            title="Click to view in Sessions manager"
                                        >
                                            <td className="sessions-mono" style={{ color: statusLower === 'live' || row.time.includes('10:00') ? '#bb0013' : 'inherit' }}>
                                                {row.time}
                                            </td>
                                            <td>
                                                <span 
                                                    onClick={(e) => {
                                                        if (row.trainerId) {
                                                            e.stopPropagation();
                                                            navigate(`/trainers/${row.trainerId}`);
                                                        }
                                                    }}
                                                    style={{ 
                                                        cursor: row.trainerId ? 'pointer' : 'inherit',
                                                        fontWeight: 600,
                                                        color: row.trainerId ? '#00225d' : 'inherit'
                                                    }}
                                                    title={row.trainerId ? "View trainer profile" : undefined}
                                                >
                                                    {row.trainerName}
                                                </span>
                                            </td>
                                            <td className="sessions-bold">
                                                <span
                                                    onClick={(e) => {
                                                        if (row.clientId) {
                                                            e.stopPropagation();
                                                            navigate(`/users/${row.clientId}`);
                                                        }
                                                    }}
                                                    style={{
                                                        cursor: row.clientId ? 'pointer' : 'inherit',
                                                        color: row.clientId ? '#00225d' : 'inherit'
                                                    }}
                                                    title={row.clientId ? "View client profile" : undefined}
                                                >
                                                    {row.clientName}
                                                </span>
                                            </td>
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