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

// ------------------------------------------------------------------
// Types
// ------------------------------------------------------------------
interface ClientInfo {
    fullName: string;
    primaryGoal: string;
    location: string;
    trainerName: string;
    status: string;
    initials: string;
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

// Utility to give badges colors based on words (matches the mockup's vibrant look)
function getBadgeStyle(text: string) {
    const t = text.toLowerCase();
    if (t.includes("performance") || t.includes("steady")) return { bg: "#e0f2fe", color: "#0369a1" };
    if (t.includes("top rated")) return { bg: "#ccfbf1", color: "#0f766e" };
    if (t.includes("muscle") || t.includes("bulk")) return { bg: "#f3e8ff", color: "#7e22ce" };
    return { bg: "#f1f5f9", color: "#475569" };
}

// Utility to map icon colors
function getIconStyle(iconName: string) {
    if (iconName.includes("bolt") || iconName.includes("flash")) return { bg: "#e0f2fe", color: "#0284c7" };
    if (iconName.includes("dumbbell")) return { bg: "#ffe4e6", color: "#e11d48" };
    if (iconName.includes("scale") || iconName.includes("balance")) return { bg: "#ffedd5", color: "#d97706" };
    return { bg: "#f1f5f9", color: "#475569" };
}

// ------------------------------------------------------------------
// Main Component
// ------------------------------------------------------------------
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
        let isMounted = true;

        async function loadData() {
            try {
                // Fetch user, profile, and assessments concurrently for the aggressive extractor
                const [userSnap, profileSnapQuery, assessDocSnap, assessUserSnap, assessClientSnap] = await Promise.all([
                    getDoc(doc(db, "users", id!)),
                    getDocs(collection(db, "users", id!, "clientProfile")),
                    getDoc(doc(db, "assessments", id!)),
                    getDocs(query(collection(db, "assessments"), where("userId", "==", id!))),
                    getDocs(query(collection(db, "assessments"), where("clientId", "==", id!)))
                ]);

                if (!userSnap.exists() && isMounted) {
                    setLoading(false);
                    return;
                }

                const userData = (userSnap.data() || {}) as Record<string, unknown>;
                const profileData = (profileSnapQuery.docs[0]?.data() || {}) as Record<string, unknown>;

                let assessData: Record<string, unknown> = {};
                if (assessDocSnap.exists()) assessData = assessDocSnap.data() as Record<string, unknown>;
                else if (!assessUserSnap.empty) assessData = assessUserSnap.docs[0].data() as Record<string, unknown>;
                else if (!assessClientSnap.empty) assessData = assessClientSnap.docs[0].data() as Record<string, unknown>;

                const fullName = (userData.fullName || userData.name || "Unknown Client") as string;
                const initials = fullName.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase();

                // Aggressive Extractor Logic
                const findValue = (sources: unknown[], keys: string[]): string | undefined => {
                    for (const source of sources) {
                        if (!source || typeof source !== 'object') continue;
                        const srcObj = source as Record<string, unknown>;
                        for (const key of keys) {
                            const val = srcObj[key];
                            if (typeof val === 'string' && val.trim() !== '') return val.trim();
                            if (Array.isArray(val) && val.length > 0 && typeof val[0] === 'string') return val[0].trim();
                            if (typeof val === 'object' && val !== null) {
                                const obj = val as Record<string, unknown>;
                                if (typeof obj.city === 'string' && obj.city.trim() !== '') return obj.city.trim();
                                if (typeof obj.address === 'string' && obj.address.trim() !== '') return obj.address.trim();
                                if (typeof obj.name === 'string' && obj.name.trim() !== '') return obj.name.trim();
                                if (typeof obj.title === 'string' && obj.title.trim() !== '') return obj.title.trim();
                                if (typeof obj.value === 'string' && obj.value.trim() !== '') return obj.value.trim();
                            }
                        }
                    }
                    return undefined;
                };

                const possibleSources = [
                    userData, profileData, assessData,
                    userData.personalInfo, userData.personalDetails, userData.contactInfo, userData.address,
                    profileData.personalInfo, profileData.personalDetails, profileData.address,
                    assessData.personalInfo, assessData.fitnessGoals, assessData.personalDetails
                ];

                const extractedGoal = findValue(possibleSources, [
                    'primaryGoal', 'goal', 'fitnessGoal', 'goals', 'PrimaryGoal', 'objective', 'My Goals'
                ]) || "Not set";

                const extractedLocation = findValue(possibleSources, [
                    'location', 'address', 'city', 'Location', 'Address', 'City', 'state', 'town'
                ]) || "Not set";

                let trainerName = "—";
                const trainerId = userData.assignedTrainerId || userData.trainerId || profileData.trainerId;
                if (trainerId) {
                    try {
                        const trainerSnap = await getDoc(doc(db, "users", trainerId as string));
                        trainerName = trainerSnap.exists() ? trainerSnap.data().fullName : "—";
                    } catch (e) {
                        console.warn("Trainer fetch failed", e);
                    }
                }

                if (isMounted) {
                    setClient({
                        fullName,
                        initials,
                        primaryGoal: extractedGoal,
                        location: extractedLocation,
                        trainerName,
                        status: (userData.status as string) || "Active",
                    });
                }

                // Fetch Templates
                const templatesSnap = await getDocs(collection(db, "dietPlanTemplates"));
                if (!isMounted) return;

                const loadedTemplates = templatesSnap.docs.map((d) => {
                    const data = d.data();
                    const calories = data.calories ?? 0;
                    const protein = data.protein ?? 0;
                    const proteinRatioPct = data.proteinRatioPct ?? (calories > 0 ? Math.round(((protein * 4) / calories) * 100) : 0);

                    // Fallback icons if not set in DB
                    let icon = data.icon || "bx-food-menu";
                    if (data.name?.toLowerCase().includes("keto")) icon = "bxs-bolt";
                    else if (data.name?.toLowerCase().includes("muscle") || data.name?.toLowerCase().includes("protein")) icon = "bx-dumbbell";
                    else if (data.name?.toLowerCase().includes("maintenance") || data.name?.toLowerCase().includes("balance")) icon = "bx-test-tube";

                    // Fallback badges if not set
                    let badges = data.badges || [];
                    if (badges.length === 0) {
                        if (data.goalType === "Fat Loss") badges = ["Performance"];
                        else if (data.goalType === "Muscle Gain") badges = ["Top Rated", "Muscle"];
                        else badges = ["Steady"];
                    }

                    return {
                        id: d.id,
                        name: data.name ?? "Untitled Plan",
                        subtitle: data.subtitle ?? data.description ?? "",
                        goalType: data.goalType ?? "Maintenance",
                        badges,
                        calories,
                        proteinRatioPct,
                        icon,
                    };
                });

                // Sort to put the one matching the client's goal at the top (optional UX boost)
                loadedTemplates.sort((a, b) => {
                    if (a.goalType.toLowerCase() === extractedGoal.toLowerCase()) return -1;
                    if (b.goalType.toLowerCase() === extractedGoal.toLowerCase()) return 1;
                    return 0;
                });

                setTemplates(loadedTemplates);

                // Check Active Assigned Plan
                const activeAssignSnap = await getDocs(
                    query(collection(db, "clientDietPlans"), where("clientId", "==", id), where("status", "==", "active"))
                );
                if (isMounted && !activeAssignSnap.empty) {
                    setCurrentTemplateId(activeAssignSnap.docs[0].data().templateId ?? null);
                }

            } catch (err) {
                console.error("Assign diet plan load error:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        loadData();
        return () => { isMounted = false; };
    }, [id]);

    const filtered = useMemo(() => {
        return templates.filter((t) => {
            if (search && !t.name.toLowerCase().includes(search.toLowerCase()) && !t.subtitle.toLowerCase().includes(search.toLowerCase())) {
                return false;
            }
            if (goalFilter !== "All Goal Type" && t.goalType !== goalFilter && t.goalType !== "All Goal Type") {
                return false;
            }
            return true;
        });
    }, [templates, search, goalFilter]);

    async function handleSelectAndAssign(template: TemplateCard) {
        if (!id || template.id === currentTemplateId) return;
        setAssigning(template.id);
        setAssignError(null);
        try {
            const existingSnap = await getDocs(
                query(collection(db, "clientDietPlans"), where("clientId", "==", id), where("status", "==", "active"))
            );
            await Promise.all(
                existingSnap.docs.map((d) => updateDoc(doc(db, "clientDietPlans", d.id), { status: "replaced" }))
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

    const hasValidLocation = client?.location && client.location.toLowerCase() !== "not set";
    const googleMapsUrl = hasValidLocation
        ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(client.location as string)}`
        : undefined;

    if (loading) {
        return (
            <Layout title="Users Managements">
                <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "50vh", gap: "10px", color: "#0c2b75", fontSize: "18px", fontWeight: "bold" }}>
                    <i className='bx bx-loader-alt bx-spin' style={{ fontSize: "28px" }}></i>
                    Loading diet templates...
                </div>
            </Layout>
        );
    }

    return (
        <Layout title="Users Managements">
            <div className="adp-wrapper">

                {/* Header Row */}
                <div className="adp-header-row">
                    <button className="back-btn-outlined" onClick={() => navigate(`/users/${id}`)}>
                        <i className="bx bx-arrow-back" /> Back to Profile
                    </button>
                    <button className="btn-create-solid" onClick={() => navigate(`/diet-plans/add`)}>
                        <i className="bx bx-add-to-queue" /> Create Custom Plan
                    </button>
                </div>

                {assignError && <div className="adp-error-banner">{assignError}</div>}

                {/* Client Navy Banner */}
                {client && (
                    <div className="adp-banner">
                        <div className="adp-avatar">{client.initials}</div>
                        <div className="adp-info">
                            <h2 className="adp-name">{client.fullName}</h2>
                            <div className="adp-meta">
                                <span><i className="bx bx-target-lock adp-icon-red" /> Primary Goal : {client.primaryGoal}</span>

                                <a
                                    href={googleMapsUrl}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className={`adp-location-link ${!hasValidLocation ? 'disabled' : ''}`}
                                    onClick={(e) => !hasValidLocation && e.preventDefault()}
                                    title={hasValidLocation ? "View on Google Maps" : "No location provided"}
                                >
                                    <i className="bx bx-map adp-icon-green" /> Location : {client.location}
                                </a>

                                <span><i className="bx bx-user adp-icon-grey" /> Trainer : {client.trainerName}</span>
                            </div>
                        </div>
                        <span className="adp-status">Active</span>
                    </div>
                )}

                {/* Toolbar */}
                <div className="adp-toolbar">
                    <div className="adp-search">
                        <i className="bx bx-search" />
                        <input
                            placeholder="Search templates (e.g., Ketosis, High Protein...)"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                        />
                    </div>
                    <select
                        className="adp-select"
                        value={goalFilter}
                        onChange={(e) => setGoalFilter(e.target.value)}
                    >
                        {GOAL_TYPES.map((g) => <option key={g} value={g}>{g}</option>)}
                    </select>
                    <button className="adp-filter-btn">
                        <i className="bx bx-filter-alt" /> Filter
                    </button>
                </div>

                {/* Templates Grid */}
                {filtered.length === 0 ? (
                    <div style={{ color: "#64748b", padding: 24 }}>No templates match your search.</div>
                ) : (
                    <div className="adp-grid">
                        {filtered.map((t) => {
                            const isSelected = t.id === currentTemplateId;
                            const iconStyle = getIconStyle(t.icon);

                            return (
                                <div key={t.id} className={`adp-card ${isSelected ? "selected-card" : ""}`}>

                                    <div className="adp-card-top">
                                        <div className="adp-badges">
                                            {t.badges.map((b, i) => {
                                                const bStyle = getBadgeStyle(b);
                                                return (
                                                    <span key={i} className="adp-badge-pill" style={{ backgroundColor: bStyle.bg, color: bStyle.color }}>
                                                        {b}
                                                    </span>
                                                )
                                            })}
                                        </div>
                                        <div className="adp-icon-box" style={{ backgroundColor: iconStyle.bg, color: iconStyle.color }}>
                                            <i className={`bx ${t.icon}`} />
                                        </div>
                                    </div>

                                    <h3 className="adp-card-title">{t.name}</h3>
                                    <p className="adp-card-subtitle">{t.subtitle}</p>

                                    <div className="adp-stats-box">
                                        <div className="adp-stat-col">
                                            <span className="adp-stat-label">AVG. DAILY CALS</span>
                                            <span className="adp-val-green">{t.calories.toLocaleString()}</span>
                                        </div>
                                        <div className="adp-stat-col">
                                            <span className="adp-stat-label">PROTEIN RATIO</span>
                                            <span className="adp-val-navy">{t.proteinRatioPct}%</span>
                                        </div>
                                    </div>

                                    <div className="adp-card-actions">
                                        <button className="btn-preview" onClick={() => navigate(`/diet-plans/view/${t.id}`)}>
                                            Preview
                                        </button>
                                        <button
                                            className={`btn-assign ${isSelected ? "selected-btn" : ""}`}
                                            onClick={() => handleSelectAndAssign(t)}
                                            disabled={isSelected || assigning === t.id}
                                        >
                                            {isSelected ? "Selected" : assigning === t.id ? "Assigning..." : "Select & Assign"}
                                        </button>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>
        </Layout>
    );
}