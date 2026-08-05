import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
    doc,
    getDoc,
    collection,
    query,
    where,
    orderBy,
    limit,
    getDocs,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/userProfile.css";

interface ClientInfo {
    fullName: string;
    initials: string;
}

interface ClientProfileData {
    primaryGoal?: string;
    location?: string;
}

interface SubscriptionInfo {
    trainerName: string;
    status: string;
}

interface MeasurementEntry {
    id: string;
    date: string;
    weightKg?: number;
    sleepHours?: number;
    waterL?: number;
    steps?: number;
}

interface HealthCondition {
    id: string;
    conditionName: string;
}

interface Procedure {
    id: string;
    procedureName: string;
    procedureDate?: string;
    recoveryStatus?: string;
}

interface Medication {
    id: string;
    name: string;
}

interface SessionEntry {
    id: string;
    serviceType: string;
    trainerName: string;
    scheduledDate: string;
}

interface DietPlanSummary {
    templateId?: string;
    templateName?: string;
    weekNumber?: number;
    netCarbsG?: number;
    fastingWindow?: string;
}

export default function UserProfile() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();

    const [client, setClient] = useState<ClientInfo | null>(null);
    const [profile, setProfile] = useState<ClientProfileData>({});
    const [subscription, setSubscription] = useState<SubscriptionInfo | null>(null);
    const [measurements, setMeasurements] = useState<MeasurementEntry[]>([]);
    const [conditions, setConditions] = useState<HealthCondition[]>([]);
    const [procedures, setProcedures] = useState<Procedure[]>([]);
    const [medications, setMedications] = useState<Medication[]>([]);
    const [sessions, setSessions] = useState<SessionEntry[]>([]);
    const [totalSessions, setTotalSessions] = useState<number>(0);
    const [dietPlan, setDietPlan] = useState<DietPlanSummary | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!id) return;

        async function loadProfile() {
            try {
                // Base user doc
                const userSnap = await getDoc(doc(db, "users", id!));
                if (userSnap.exists()) {
                    const data = userSnap.data();
                    const name: string = data.fullName ?? "Unknown Client";
                    setClient({
                        fullName: name,
                        initials: name
                            .split(" ")
                            .map((p: string) => p[0])
                            .join("")
                            .slice(0, 2)
                            .toUpperCase(),
                    });
                }

                // clientProfile subcollection doc (same id)
                const profileSnap = await getDoc(
                    doc(db, "users", id!, "clientProfile", id!)
                );
                if (profileSnap.exists()) {
                    setProfile(profileSnap.data() as ClientProfileData);
                }

                // Active subscription -> trainer name
                const subQuery = query(
                    collection(db, "subscriptions"),
                    where("clientId", "==", id),
                    where("status", "==", "active"),
                    limit(1)
                );
                const subSnap = await getDocs(subQuery);
                if (!subSnap.empty) {
                    const sub = subSnap.docs[0].data();
                    let trainerName = "—";
                    if (sub.trainerId) {
                        const trainerSnap = await getDoc(doc(db, "users", sub.trainerId));
                        trainerName = trainerSnap.exists()
                            ? trainerSnap.data().fullName
                            : "—";
                    }
                    setSubscription({ trainerName, status: sub.status });
                }

                // Measurement history (progress logs)
                const progressSnap = await getDocs(
                    query(
                        collection(db, "progressLogs", id!, "entries"),
                        orderBy("createdAt", "desc"),
                        limit(3)
                    )
                );
                setMeasurements(
                    progressSnap.docs.map((d) => {
                        const data = d.data();
                        return {
                            id: d.id,
                            date: d.id,
                            weightKg: data.weightKg,
                            sleepHours: data.sleepHours,
                            waterL: data.waterL,
                            steps: data.steps,
                        };
                    })
                );

                // Health conditions
                const conditionsSnap = await getDocs(
                    collection(db, "users", id!, "healthConditions")
                );
                setConditions(
                    conditionsSnap.docs.map((d) => ({
                        id: d.id,
                        conditionName: d.data().conditionName,
                    }))
                );

                // Procedures & surgeries
                const proceduresSnap = await getDocs(
                    collection(db, "users", id!, "proceduresSurgeries")
                );
                setProcedures(
                    proceduresSnap.docs.map((d) => ({
                        id: d.id,
                        procedureName: d.data().procedureName,
                        procedureDate: d.data().procedureDate,
                        recoveryStatus: d.data().recoveryStatus,
                    }))
                );

                // Medications
                const medsSnap = await getDocs(
                    collection(db, "users", id!, "medications")
                );
                setMedications(
                    medsSnap.docs.map((d) => ({ id: d.id, name: d.data().name }))
                );

                // Recent sessions (last 3) + total count
                const sessionsQuery = query(
                    collection(db, "sessions"),
                    where("clientId", "==", id),
                    orderBy("scheduledDate", "desc"),
                    limit(3)
                );
                const sessionsSnap = await getDocs(sessionsQuery);
                const sessionRows = await Promise.all(
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
                        };
                    })
                );
                setSessions(sessionRows);

                const allSessionsSnap = await getDocs(
                    query(collection(db, "sessions"), where("clientId", "==", id))
                );
                setTotalSessions(allSessionsSnap.size);

                // Active diet plan
                const dietQuery = query(
                    collection(db, "clientDietPlans"),
                    where("clientId", "==", id),
                    where("status", "==", "active"),
                    limit(1)
                );
                const dietSnap = await getDocs(dietQuery);
                if (!dietSnap.empty) {
                    const d = dietSnap.docs[0].data();
                    setDietPlan({
                        templateId: d.templateId,
                        templateName: d.templateName,
                        weekNumber: d.weekNumber,
                        netCarbsG: d.netCarbsG,
                        fastingWindow: d.fastingWindow,
                    });
                }
            } catch (err) {
                console.error("Profile load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadProfile();
    }, [id]);

    if (loading) {
        return (
            <Layout title="Users Managements">
                <p style={{ color: "#999" }}>Loading client profile...</p>
            </Layout>
        );
    }

    if (!client) {
        return (
            <Layout title="Users Managements">
                <p style={{ color: "#999" }}>Client not found.</p>
            </Layout>
        );
    }

    return (
        <Layout title="Users Managements">
            <button className="profile-back-btn" onClick={() => navigate("/users")}>
                <i className="bx bx-arrow-back" /> Back to Users
            </button>

            <div className="profile-header-card">
                <div className="profile-avatar-circle">{client.initials}</div>
                <div className="profile-header-info">
                    <div className="profile-name">{client.fullName.toUpperCase()}</div>
                    <div className="profile-meta-row">
                        <span>🎯 Primary Goal: {profile.primaryGoal ?? "Not set"}</span>
                        <span>📍 Location: {profile.location ?? "Not set"}</span>
                        <span>🏋 Trainer: {subscription?.trainerName ?? "Unassigned"}</span>
                    </div>
                </div>
                {subscription && (
                    <div className="profile-status-badge">{subscription.status}</div>
                )}
            </div>

            <div className="profile-grid">
                <div className="profile-card">
                    <div className="profile-card-title">Measurement History</div>
                    <div className="profile-card-subtitle">Track your progress over time</div>

                    {measurements.length === 0 ? (
                        <div className="profile-empty">
                            No progress logs recorded yet for this client.
                        </div>
                    ) : (
                        <table className="profile-measure-table">
                            <thead>
                                <tr>
                                    <th>Date</th>
                                    <th>Weight (Kg)</th>
                                    <th>Sleep (Hrs)</th>
                                    <th>Hydration (L)</th>
                                    <th>Steps</th>
                                </tr>
                            </thead>
                            <tbody>
                                {measurements.map((m) => (
                                    <tr key={m.id}>
                                        <td>{m.date}</td>
                                        <td>{m.weightKg ?? "—"}</td>
                                        <td>{m.sleepHours ?? "—"}</td>
                                        <td>{m.waterL ?? "—"}</td>
                                        <td>{m.steps?.toLocaleString() ?? "—"}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}

                    <div className="profile-card-title" style={{ marginTop: 24 }}>
                        Session History ({totalSessions} Total)
                    </div>
                    {sessions.length === 0 ? (
                        <div className="profile-empty">No sessions recorded yet.</div>
                    ) : (
                        <>
                            {sessions.map((s) => (
                                <div key={s.id} className="session-item">
                                    <div className="session-title">{s.serviceType}</div>
                                    <div className="session-meta">
                                        Trainer: {s.trainerName} · {s.scheduledDate}
                                    </div>
                                </div>
                            ))}
                            <button
                                className="profile-view-all"
                                onClick={() => navigate(`/users/${id}/sessions`)}
                            >
                                View all sessions
                            </button>
                        </>
                    )}
                </div>

                <div>
                    <div className="profile-card profile-card-navy" style={{ marginBottom: 20 }}>
                        <div className="profile-card-title">Physical Conditions Profile</div>

                        <div className="profile-subsection-title">Procedures &amp; Surgeries</div>
                        {procedures.length === 0 ? (
                            <div className="profile-empty" style={{ color: "#bbb" }}>None recorded.</div>
                        ) : (
                            <div className="profile-pill-list">
                                {procedures.map((p) => (
                                    <span key={p.id} className="profile-pill">
                                        {p.procedureName}
                                        {p.procedureDate ? ` · ${p.procedureDate}` : ""}
                                    </span>
                                ))}
                            </div>
                        )}

                        <div className="profile-subsection-title">Medications</div>
                        {medications.length === 0 ? (
                            <div className="profile-empty" style={{ color: "#bbb" }}>None recorded.</div>
                        ) : (
                            <div className="profile-pill-list">
                                {medications.map((m) => (
                                    <span key={m.id} className="profile-pill">{m.name}</span>
                                ))}
                            </div>
                        )}

                        <div className="profile-subsection-title">Health Conditions</div>
                        {conditions.length === 0 ? (
                            <div className="profile-empty" style={{ color: "#bbb" }}>None recorded.</div>
                        ) : (
                            <div className="profile-pill-list">
                                {conditions.map((c) => (
                                    <span key={c.id} className="profile-pill">
                                        {c.conditionName}
                                        <button className="profile-manage-btn">Manage</button>
                                    </span>
                                ))}
                            </div>
                        )}
                    </div>

                    <div className="profile-card profile-card-navy">
                        <div className="profile-card-title">Active Diet Plan</div>
                        {dietPlan ? (
                            <>
                                <p style={{ fontSize: 13, opacity: 0.85 }}>
                                    {dietPlan.templateName ?? "Custom Plan"}
                                    {dietPlan.weekNumber ? ` — Week ${dietPlan.weekNumber}` : ""}
                                </p>
                                {dietPlan.netCarbsG != null && (
                                    <div className="diet-tag">Target: under {dietPlan.netCarbsG}g carbs</div>
                                )}
                                {dietPlan.fastingWindow && (
                                    <div className="diet-tag">Fast Window: {dietPlan.fastingWindow}</div>
                                )}
                                <button
                                    className="profile-btn-outline"
                                    onClick={() =>
                                        dietPlan?.templateId &&
                                        navigate(`/diet-plans/view/${dietPlan.templateId}`)
                                    }
                                    disabled={!dietPlan?.templateId}
                                >
                                    View Full Menu
                                </button>
                            </>
                        ) : (
                            <div className="profile-empty" style={{ color: "#bbb" }}>
                                No active diet plan assigned yet.
                            </div>
                        )}
                        <button
                            className="profile-btn-primary"
                            onClick={() => navigate(`/users/${id}/assign-diet`)}
                        >
                            Assign New Plan
                        </button>
                    </div>
                </div>
            </div>
        </Layout>
    );
}