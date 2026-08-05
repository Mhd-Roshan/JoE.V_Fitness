import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
    collection,
    getDocs,
    doc,
    getDoc,
    query,
    where,
    addDoc,
    updateDoc,
    serverTimestamp,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/assignDietPlan.css";

interface ClientInfo {
    fullName: string;
    primaryGoal: string;
    location: string;
    trainerName: string;
    status: string;
}

interface TemplateCard {
    id: string;
    name: string;
    subtitle: string;
    goalType: string;
    badges: string[];
    calories: number;
    proteinRatioPct: number;
    icon: string;
}

const GOAL_TYPES = ["All Goal Type", "Fat Loss", "Muscle Gain", "Maintenance", "Performance"];

export default function AssignDietPlan() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();

    const [client, setClient] = useState<ClientInfo | null>(null);
    const [templates, setTemplates] = useState<TemplateCard[]>([]);
    const [currentTemplateId, setCurrentTemplateId] = useState<string | null>(null);
    const [search, setSearch] = useState("");
    const [goalFilter, setGoalFilter] = useState("All Goal Type");
    const [loading, setLoading] = useState(true);
    const [assigning, setAssigning] = useState<string | null>(null);
    const [assignError, setAssignError] = useState<string | null>(null);

    useEffect(() => {
        if (!id) return;
        let cancelled = false;

        async function load() {
            try {
                const userSnap = await getDoc(doc(db, "users", id!));
                const profileSnap = await getDocs(
                    collection(db, "users", id!, "clientProfile")
                );
                const profileData = profileSnap.docs[0]?.data();

                let trainerName = "—";
                if (profileData?.trainerId) {
                    const trainerSnap = await getDoc(doc(db, "users", profileData.trainerId));
                    trainerName = trainerSnap.exists() ? trainerSnap.data().fullName : "—";
                }

                if (!cancelled) {
                    setClient({
                        fullName: userSnap.exists() ? userSnap.data().fullName : "Unknown Client",
                        primaryGoal: profileData?.primaryGoal ?? "—",
                        location: profileData?.location ?? "—",
                        trainerName,
                        status: userSnap.exists() ? userSnap.data().status ?? "active" : "active",
                    });
                }

                const templatesSnap = await getDocs(collection(db, "dietPlanTemplates"));
                if (cancelled) return;

                setTemplates(
                    templatesSnap.docs.map((d) => {
                        const data = d.data();
                        const calories = data.calories ?? 0;
                        const protein = data.protein ?? 0;
                        const proteinRatioPct =
                            data.proteinRatioPct ??
                            (calories > 0 ? Math.round(((protein * 4) / calories) * 100) : 0);
                        return {
                            id: d.id,
                            name: data.name ?? "Untitled Plan",
                            subtitle: data.subtitle ?? data.description ?? "",
                            goalType: data.goalType ?? "Maintenance",
                            badges: data.badges ?? [],
                            calories,
                            proteinRatioPct,
                            icon: data.icon ?? "bx-food-menu",
                        };
                    })
                );

                const activeAssignSnap = await getDocs(
                    query(
                        collection(db, "clientDietPlans"),
                        where("clientId", "==", id),
                        where("status", "==", "active")
                    )
                );
                if (!cancelled && !activeAssignSnap.empty) {
                    setCurrentTemplateId(activeAssignSnap.docs[0].data().templateId ?? null);
                }
            } catch (err) {
                console.error("Assign diet plan load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, [id]);

    const filtered = useMemo(() => {
        return templates.filter((t) => {
            if (
                search &&
                !t.name.toLowerCase().includes(search.toLowerCase()) &&
                !t.subtitle.toLowerCase().includes(search.toLowerCase())
            ) {
                return false;
            }
            if (goalFilter !== "All Goal Type" && t.goalType !== goalFilter) return false;
            return true;
        });
    }, [templates, search, goalFilter]);

    async function handleSelectAndAssign(template: TemplateCard) {
        if (!id || template.id === currentTemplateId) return;
        setAssigning(template.id);
        setAssignError(null);
        try {
            const existingSnap = await getDocs(
                query(
                    collection(db, "clientDietPlans"),
                    where("clientId", "==", id),
                    where("status", "==", "active")
                )
            );
            await Promise.all(
                existingSnap.docs.map((d) =>
                    updateDoc(doc(db, "clientDietPlans", d.id), { status: "replaced" })
                )
            );

            await addDoc(collection(db, "clientDietPlans"), {
                clientId: id,
                templateId: template.id,
                templateName: template.name,
                status: "active",
                assignedAt: serverTimestamp(),
            });

            setCurrentTemplateId(template.id);
        } catch (err) {
            console.error("Assign plan failed:", err);
            setAssignError("Couldn't assign this plan. Try again.");
        } finally {
            setAssigning(null);
        }
    }

    if (loading) {
        return (
            <Layout title="Users Managements">
                <p style={{ color: "#999" }}>Loading...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Users Managements">
            <div className="adp-header">
                <button className="profile-back-btn" onClick={() => navigate(`/users/${id}`)}>
                    <i className="bx bx-arrow-back" /> Back to Profile
                </button>
                <button className="adp-custom-btn">
                    <i className="bx bx-add-to-queue" /> Create Custom Plan
                </button>
            </div>

            {assignError && <div className="adp-assign-error">{assignError}</div>}

            {client && (
                <div className="adp-client-banner">
                    <div className="adp-client-left">
                        <div className="adp-client-avatar">
                            {client.fullName
                                .split(" ")
                                .map((p) => p[0])
                                .join("")
                                .slice(0, 2)
                                .toUpperCase()}
                        </div>
                        <div>
                            <div className="adp-client-name">{client.fullName}</div>
                            <div className="adp-client-meta-row">
                                <span>
                                    <i className="bx bx-heart" /> Primary Goal: {client.primaryGoal}
                                </span>
                                <span>
                                    <i className="bx bx-map-pin" /> Location: {client.location}
                                </span>
                                <span>
                                    <i className="bx bx-user" /> Trainer: {client.trainerName}
                                </span>
                            </div>
                        </div>
                    </div>
                    <span className="adp-status-pill">{client.status}</span>
                </div>
            )}

            <div className="adp-toolbar">
                <div className="adp-search-box">
                    <i className="bx bx-search" />
                    <input
                        placeholder="Search templates (e.g., Ketosis, High Protein...)"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
                <select
                    className="adp-goal-select"
                    value={goalFilter}
                    onChange={(e) => setGoalFilter(e.target.value)}
                >
                    {GOAL_TYPES.map((g) => (
                        <option key={g} value={g}>
                            {g}
                        </option>
                    ))}
                </select>
                <button className="adp-filter-btn">
                    <i className="bx bx-filter-alt" /> Filter
                </button>
            </div>

            {filtered.length === 0 ? (
                <div className="profile-empty" style={{ padding: 24 }}>
                    No templates match your search.
                </div>
            ) : (
                <div className="adp-grid">
                    {filtered.map((t) => {
                        const isSelected = t.id === currentTemplateId;
                        return (
                            <div
                                key={t.id}
                                className={`adp-card ${isSelected ? "selected" : ""}`}
                            >
                                <div className="adp-card-top">
                                    <div className="adp-badges">
                                        {t.badges.map((b, i) => (
                                            <span key={i} className="adp-badge">
                                                {b}
                                            </span>
                                        ))}
                                    </div>
                                    <span className="adp-icon-badge">
                                        <i className={`bx ${t.icon}`} />
                                    </span>
                                </div>

                                <div className="adp-card-name">{t.name}</div>
                                {t.subtitle && (
                                    <div className="adp-card-subtitle">{t.subtitle}</div>
                                )}

                                <div className="adp-stats-row">
                                    <div className="adp-stat">
                                        <div className="adp-stat-label">AVG. DAILY CALS</div>
                                        <div className="adp-stat-value">{t.calories}</div>
                                    </div>
                                    <div className="adp-stat">
                                        <div className="adp-stat-label">PROTEIN RATIO</div>
                                        <div className="adp-stat-value">{t.proteinRatioPct}%</div>
                                    </div>
                                </div>

                                <div className="adp-card-actions">
                                    <button
                                        className="adp-preview-btn"
                                        onClick={() => navigate(`/diet-plans/view/${t.id}`)}
                                    >
                                        Preview
                                    </button>
                                    <button
                                        className={`adp-assign-btn ${isSelected ? "selected" : ""}`}
                                        onClick={() => handleSelectAndAssign(t)}
                                        disabled={isSelected || assigning === t.id}
                                    >
                                        {isSelected
                                            ? "Selected"
                                            : assigning === t.id
                                                ? "Assigning..."
                                                : "Select & Assign"}
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </Layout>
    );
}