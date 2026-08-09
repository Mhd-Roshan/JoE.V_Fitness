import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    query,
    where,
    getDocs,
    getCountFromServer,
    doc,
    getDoc,
    deleteDoc,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/trainers.css";

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

function todayDateStr() {
    return new Date().toISOString().slice(0, 10);
}

export default function Trainers() {
    const navigate = useNavigate();
    const [trainers, setTrainers] = useState<TrainerCard[]>([]);
    const [schedule, setSchedule] = useState<ScheduleRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);
    const [deleting, setDeleting] = useState(false);
    const [deleteError, setDeleteError] = useState<string | null>(null);

    useEffect(() => {
        let isMounted = true; // Prevents memory leaks if component unmounts early

        async function load() {
            try {
                const today = todayDateStr();

                // 1. Fetch Trainer profiles
                const usersSnap = await getDocs(
                    query(collection(db, "users"), where("role", "==", "trainer"))
                );

                const trainerRows = await Promise.all(
                    usersSnap.docs.map(async (u) => {
                        const userData = u.data();
                        const trainerId = u.id;

                        const trainerDoc = await getDocs(
                            query(collection(db, "trainers"), where("trainerId", "==", trainerId))
                        );
                        const trainerData = trainerDoc.docs[0]?.data() ?? {};

                        const clientCountSnap = await getCountFromServer(
                            query(
                                collection(db, "subscriptions"),
                                where("trainerId", "==", trainerId),
                                where("status", "==", "active")
                            )
                        );

                        const todaySessionsSnap = await getDocs(
                            query(
                                collection(db, "sessions"),
                                where("trainerId", "==", trainerId),
                                where("scheduledDate", "==", today)
                            )
                        );
                        const todayCount = todaySessionsSnap.size;
                        const completedCount = todaySessionsSnap.docs.filter(
                            (d) => d.data().status === "completed"
                        ).length;

                        const name: string = userData.fullName ?? "Unknown Trainer";

                        return {
                            id: trainerId,
                            fullName: name,
                            initials: name.split(" ").map((p: string) => p[0]).join("").slice(0, 2).toUpperCase(),
                            designation: trainerData.designation ?? "Senior Trainer",
                            yearsExperience: trainerData.yearsExperience ?? 4,
                            status: trainerData.status ?? "Active",
                            clientCount: clientCountSnap.data().count,
                            todaySessions: todayCount,
                            completionPct: todayCount === 0 ? 0 : Math.round((completedCount / todayCount) * 100),
                        };
                    })
                );

                // 2. Fetch Today's full schedule across all trainers
                const sessionsSnap = await getDocs(
                    query(collection(db, "sessions"), where("scheduledDate", "==", today))
                );

                const scheduleRows = await Promise.all(
                    sessionsSnap.docs.map(async (d) => {
                        const data = d.data();
                        let clientName = data.clientName;
                        if (!clientName && data.clientId) {
                            const clientMatch = usersSnap.docs.find((u) => u.id === data.clientId);
                            if (clientMatch) {
                                clientName = clientMatch.data().fullName;
                            } else {
                                const clientSnap = await getDoc(doc(db, "users", data.clientId));
                                clientName = clientSnap.exists() ? clientSnap.data().fullName : undefined;
                            }
                        }

                        let trainerName = data.trainerName;
                        if (!trainerName && data.trainerId) {
                            const trainerMatch = usersSnap.docs.find((u) => u.id === data.trainerId);
                            if (trainerMatch) {
                                trainerName = trainerMatch.data().fullName;
                            } else {
                                const trainerSnap = await getDoc(doc(db, "users", data.trainerId));
                                trainerName = trainerSnap.exists() ? trainerSnap.data().fullName : undefined;
                            }
                        }

                        return {
                            id: d.id,
                            time: data.scheduledTime ?? "—",
                            clientName: clientName ?? "—",
                            area: data.area ?? "—",
                            service: data.serviceType ?? "—",
                            notes: data.notes ?? "",
                            trainerName: trainerName ?? "—",
                            status: data.status ?? "scheduled",
                        };
                    })
                );

                if (isMounted) {
                    setTrainers(trainerRows);
                    setSchedule(scheduleRows.sort((a, b) => a.time.localeCompare(b.time)));
                }
            } catch (err) {
                console.error("Trainers load error:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        load();

        return () => {
            isMounted = false;
        };
    }, []);

    async function handleConfirmDelete() {
        if (!deleteTarget) return;
        setDeleting(true);
        setDeleteError(null);

        try {
            const availSnap = await getDocs(
                collection(db, "trainers", deleteTarget.id, "availability")
            );
            await Promise.all(
                availSnap.docs.map((d) =>
                    deleteDoc(doc(db, "trainers", deleteTarget.id, "availability", d.id))
                )
            );

            await deleteDoc(doc(db, "trainers", deleteTarget.id));
            await deleteDoc(doc(db, "users", deleteTarget.id));

            setTrainers((prev) => prev.filter((t) => t.id !== deleteTarget.id));
            setDeleteTarget(null);
        } catch (err) {
            console.error("Delete trainer failed:", err);
            setDeleteError("Couldn't remove this trainer. Try again.");
        } finally {
            setDeleting(false);
        }
    }

    const formattedDate = new Date().toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
    });

    if (loading) {
        return (
            <Layout title="Trainers">
                <p style={{ color: "#999", padding: "20px" }}>Loading trainers...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Trainers">
            {/* PAGE HEADER */}
            <div className="trainers-page-header">
                <div>
                    <h1 className="trainers-page-title">Trainers Management</h1>
                    <p className="trainers-page-subtitle">
                        Add trainers and view the details to their scheduling.
                    </p>
                </div>
                <button className="trainers-add-btn" onClick={() => navigate("/trainers/add")}>
                    <i className="bx bx-plus" style={{ marginRight: '5px' }}></i> Add Trainers
                </button>
            </div>

            {/* TRAINERS GRID */}
            {trainers.length === 0 ? (
                <div className="profile-empty">No trainers added yet.</div>
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
                                <span className="trainer-status-pill">{t.status}</span>
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

                            <div className="trainer-card-actions">
                                {/* GOES TO TRAINER PROFILE -> /trainers/:id */}
                                <button
                                    className="trainer-action-btn-outline"
                                    onClick={() => navigate(`/trainers/${t.id}`)}
                                >
                                    <i className="bx bx-user-circle"></i> View Profile
                                </button>

                                {/* GOES TO ASSIGN DUTIES -> /trainers/assign */}
                                <button
                                    className="trainer-action-btn-outline"
                                    onClick={() => navigate("/trainers/assign")}
                                >
                                    <i className="bx bx-user-plus"></i> Assign
                                </button>

                                <button
                                    className="trainer-delete-btn"
                                    onClick={() =>
                                        setDeleteTarget({ id: t.id, name: t.fullName })
                                    }
                                    title="Remove trainer"
                                >
                                    <i className="bx bx-trash" />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* SCHEDULE SECTION */}
            <div className="schedule-section">
                <div className="schedule-header">
                    <h2 className="schedule-title">
                        Full Schedule - Today, {formattedDate}
                    </h2>
                    <button className="schedule-all-btn">
                        <i className="bx bx-calendar"></i> All Sessions
                    </button>
                </div>

                {schedule.length === 0 ? (
                    <div className="profile-empty">No sessions scheduled for today.</div>
                ) : (
                    <div className="schedule-table-container">
                        <table className="schedule-table">
                            <thead>
                                <tr>
                                    <th>Time</th>
                                    <th>Trainer</th>
                                    <th>Users</th>
                                    <th>Area</th>
                                    <th>Service</th>
                                    <th>Status</th>
                                    <th>Notes</th>
                                </tr>
                            </thead>
                            <tbody>
                                {schedule.map((s) => (
                                    <tr key={s.id}>
                                        <td className="fw-500">{s.time}</td>
                                        <td className="fw-700 text-dark">{s.trainerName}</td>
                                        <td>{s.clientName}</td>
                                        <td>{s.area}</td>
                                        <td>{s.service}</td>
                                        <td>
                                            <span className={`table-status-pill ${s.status === 'completed' ? 'status-done' : 'status-upcoming'}`}>
                                                {s.status === "completed" ? "Complete" : "Incomplete"}
                                            </span>
                                        </td>
                                        <td className="schedule-notes-text">
                                            {s.notes ? s.notes : <span className="empty-line"></span>}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* DELETE CONFIRMATION MODAL */}
            {deleteTarget && (
                <div
                    className="delete-modal-overlay"
                    onClick={() => !deleting && setDeleteTarget(null)}
                >
                    <div className="delete-modal" onClick={(e) => e.stopPropagation()}>
                        <div className="delete-modal-icon">
                            <i className="bx bx-error-circle" />
                        </div>
                        <div className="delete-modal-title">
                            Remove {deleteTarget.name}?
                        </div>
                        <p className="delete-modal-text">
                            This permanently removes their profile, availability, and
                            certification records. This can't be undone.
                        </p>
                        {deleteError && (
                            <div className="delete-modal-error">{deleteError}</div>
                        )}
                        <div className="delete-modal-actions">
                            <button
                                className="delete-modal-cancel"
                                onClick={() => setDeleteTarget(null)}
                                disabled={deleting}
                            >
                                Cancel
                            </button>
                            <button
                                className="delete-modal-confirm"
                                onClick={handleConfirmDelete}
                                disabled={deleting}
                            >
                                {deleting ? "Removing..." : "Remove Trainer"}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}