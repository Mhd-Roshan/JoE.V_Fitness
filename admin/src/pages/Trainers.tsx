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
        async function load() {
            try {
                const today = todayDateStr();

                // Trainer profiles
                const usersSnap = await getDocs(
                    query(collection(db, "users"), where("role", "==", "trainer"))
                );

                const trainerRows = await Promise.all(
                    usersSnap.docs.map(async (u) => {
                        const userData = u.data();
                        const trainerId = u.id;

                        const trainerDoc = await getDocs(
                            query(
                                collection(db, "trainers"),
                                where("trainerId", "==", trainerId)
                            )
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
                            initials: name
                                .split(" ")
                                .map((p: string) => p[0])
                                .join("")
                                .slice(0, 2)
                                .toUpperCase(),
                            designation: trainerData.designation ?? "Trainer",
                            yearsExperience: trainerData.yearsExperience ?? 0,
                            status: trainerData.status ?? "active",
                            clientCount: clientCountSnap.data().count,
                            todaySessions: todayCount,
                            completionPct:
                                todayCount === 0
                                    ? 0
                                    : Math.round((completedCount / todayCount) * 100),
                        };
                    })
                );
                setTrainers(trainerRows);

                // Today's full schedule across all trainers
                const sessionsSnap = await getDocs(
                    query(
                        collection(db, "sessions"),
                        where("scheduledDate", "==", today)
                    )
                );

                const scheduleRows = await Promise.all(
                    sessionsSnap.docs.map(async (d) => {
                        const data = d.data();
                        let clientName = data.clientName;
                        if (!clientName && data.clientId) {
                            const clientMatch = usersSnap.docs.find(
                                (u) => u.id === data.clientId
                            );
                            if (clientMatch) {
                                clientName = clientMatch.data().fullName;
                            } else {
                                const clientSnap = await getDoc(doc(db, "users", data.clientId));
                                clientName = clientSnap.exists() ? clientSnap.data().fullName : undefined;
                            }
                        }

                        let trainerName = data.trainerName;
                        if (!trainerName && data.trainerId) {
                            const trainerMatch = usersSnap.docs.find(
                                (u) => u.id === data.trainerId
                            );
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
                setSchedule(
                    scheduleRows.sort((a, b) => a.time.localeCompare(b.time))
                );
            } catch (err) {
                console.error("Trainers load error:", err);
            } finally {
                setLoading(false);
            }
        }

        load();
    }, []);

    async function handleConfirmDelete() {
        if (!deleteTarget) return;
        setDeleting(true);
        setDeleteError(null);

        try {
            // Delete the availability subcollection docs first.
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

    if (loading) {
        return (
            <Layout title="Trainers Management">
                <p style={{ color: "#999" }}>Loading trainers...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Trainers Management">
            <div className="trainers-page-header">
                <div>
                    <p className="trainers-page-subtitle">
                        Add trainers and view the details to their scheduling.
                    </p>
                </div>
                <button className="trainers-add-btn" onClick={() => navigate("/trainers/add")}>
                    + Add Trainers
                </button>
            </div>

            {trainers.length === 0 ? (
                <div className="profile-empty">No trainers added yet.</div>
            ) : (
                <div className="trainers-card-grid">
                    {trainers.map((t) => (
                        <div key={t.id} className="trainer-card">
                            <div className="trainer-card-top">
                                <div className="trainer-avatar-circle">{t.initials}</div>
                                <span className={`trainer-status-pill status-${t.status}`}>
                                    {t.status}
                                </span>
                            </div>
                            <div className="trainer-name">{t.fullName}</div>
                            <div className="trainer-designation">
                                {t.designation} · {t.yearsExperience} yrs
                            </div>

                            <div className="trainer-stats-row">
                                <div className="trainer-stat">
                                    <div className="trainer-stat-value">{t.clientCount}</div>
                                    <div className="trainer-stat-label">Client</div>
                                </div>
                                <div className="trainer-stat">
                                    <div className="trainer-stat-value">
                                        {String(t.todaySessions).padStart(2, "0")}
                                    </div>
                                    <div className="trainer-stat-label">Today's sessions</div>
                                </div>
                                <div className="trainer-stat">
                                    <div className="trainer-stat-value">{t.completionPct}%</div>
                                    <div className="trainer-stat-label">Completion</div>
                                </div>
                            </div>

                            <div className="trainer-progress-track">
                                <div
                                    className="trainer-progress-fill"
                                    style={{ width: `${t.completionPct}%` }}
                                />
                            </div>

                            <div className="trainer-card-actions">
                                <button className="trainer-action-btn">Assign</button>
                                <button
                                    className="trainer-action-btn"
                                    onClick={() => navigate(`/trainers/${t.id}/schedule`)}
                                >
                                    View Schedule
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

            <div className="schedule-card">
                <div className="schedule-card-header">
                    <div className="schedule-card-title">
                        Full Schedule — Today,{" "}
                        {new Date().toLocaleDateString("en-US", {
                            month: "long",
                            day: "numeric",
                            year: "numeric",
                        })}
                    </div>
                    <span className="schedule-live-pill">Live</span>
                </div>

                {schedule.length === 0 ? (
                    <div className="profile-empty">No sessions scheduled for today.</div>
                ) : (
                    <table className="schedule-table">
                        <thead>
                            <tr>
                                <th>Time</th>
                                <th>Client</th>
                                <th>Area</th>
                                <th>Service</th>
                                <th>Notes</th>
                                <th>Trainer</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {schedule.map((s) => (
                                <tr key={s.id}>
                                    <td>{s.time}</td>
                                    <td className="schedule-client-name">{s.clientName}</td>
                                    <td>{s.area}</td>
                                    <td>{s.service}</td>
                                    <td className="schedule-notes">{s.notes || "—"}</td>
                                    <td>{s.trainerName}</td>
                                    <td>
                                        <span className={`schedule-status-pill status-${s.status}`}>
                                            {s.status === "completed" ? "Done" : "Upcoming"}
                                        </span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

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