import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    getDocs,
    getCountFromServer,
    query,
    where,
    orderBy,
    limit,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/dietPlans.css";

// --- TYPES ---
interface TemplateCard {
    id: string;
    name: string;
    description: string;
    imageURL: string | null;
    tag: string;
    protein: number;
    fat: number;
    carbs: number;
    createdAt: Date | null;
    assignedCount: number;
}

interface AssignmentRow {
    id: string;
    clientName: string;
    clientPhoto: string | null;
    clientInitials: string;
    templateName: string;
    assignedDate: string;
    duration: string;
    status: string;
}

// Replaces the "any" type to fix the ESLint error
interface UserData {
    fullName?: string;
    name?: string;
    photoURL?: string | null;
}

function startOfMonth() {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
}

export default function DietPlans() {
    const navigate = useNavigate();
    const [templates, setTemplates] = useState<TemplateCard[]>([]);
    const [assignments, setAssignments] = useState<AssignmentRow[]>([]);
    const [totalAssignedCount, setTotalAssignedCount] = useState(0);
    const [newThisMonth, setNewThisMonth] = useState(0);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                // 1. Fetch Templates, Assignments, and Users concurrently
                const [snap, assignSnap, usersSnap] = await Promise.all([
                    getDocs(collection(db, "dietPlanTemplates")),
                    getDocs(query(collection(db, "clientDietPlans"), orderBy("assignedAt", "desc"), limit(5))),
                    getDocs(collection(db, "users"))
                ]);

                if (cancelled) return;

                // 2. Build User Map for Avatars (Using strict UserData type)
                const userMap: Record<string, UserData> = {};
                usersSnap.docs.forEach((doc) => {
                    userMap[doc.id] = doc.data() as UserData;
                });

                const monthStart = startOfMonth();

                // 3. Process Templates
                const rows = await Promise.all(
                    snap.docs.map(async (d) => {
                        const data = d.data();
                        const assignedSnap = await getCountFromServer(
                            query(
                                collection(db, "clientDietPlans"),
                                where("templateId", "==", d.id),
                                where("status", "==", "active")
                            )
                        );
                        const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : null;

                        return {
                            id: d.id,
                            name: data.name ?? "Untitled Plan",
                            description: data.description ?? "",
                            imageURL: data.imageURL ?? null,
                            tag: data.tag ?? data.category ?? "DIET PLAN",
                            protein: data.protein ?? 0,
                            fat: data.fat ?? data.fats ?? 0,
                            carbs: data.netCarbsLimit ?? data.carbs ?? 0,
                            createdAt,
                            assignedCount: assignedSnap.data().count,
                        };
                    })
                );

                if (cancelled) return;

                setTemplates(rows);
                setTotalAssignedCount(rows.reduce((sum, r) => sum + r.assignedCount, 0));
                setNewThisMonth(rows.filter((r) => r.createdAt && r.createdAt >= monthStart).length);

                // 4. Process Assignments for Table
                setAssignments(
                    assignSnap.docs.map((d) => {
                        const data = d.data();
                        const assignedAt = data.assignedAt?.toDate ? data.assignedAt.toDate() : null;

                        // Extract Client Data
                        const userMatch = userMap[data.clientId];
                        const cName = userMatch?.fullName || userMatch?.name || data.clientName || "Unknown Client";
                        const cPhoto = userMatch?.photoURL || null;
                        const cInitials = cName.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase();

                        return {
                            id: d.id,
                            clientName: cName,
                            clientPhoto: cPhoto,
                            clientInitials: cInitials,
                            templateName: data.templateName ?? "Custom Plan",
                            assignedDate: assignedAt
                                ? assignedAt.toLocaleDateString("en-GB", {
                                    day: "2-digit",
                                    month: "short",
                                    year: "numeric",
                                })
                                : "—",
                            duration: data.durationWeeks ? `${data.durationWeeks} Weeks` : "—",
                            status: data.status ?? "active",
                        };
                    })
                );
            } catch (err) {
                console.error("Diet plans load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => { cancelled = true; };
    }, []);

    const featured = templates.slice(0, 3);
    const growthPercent = templates.length > 0 ? Math.round((newThisMonth / templates.length) * 100) : 0;

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <div className="empty-state">Loading diet plans...</div>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            {/* HEADER */}
            <div className="dm-header">
                <div>
                    <h1 className="dm-title">Diet Manage</h1>
                    <p className="dm-subtitle">
                        Design, manage, and assign high-performance nutrition protocols for elite athletes and transformation clients.
                    </p>
                </div>
                <div className="dm-header-actions">
                    <button className="dm-browse-btn" onClick={() => navigate("/diet-plans/library")}>
                        <i className="bx bx-book-bookmark" /> Browse Library
                    </button>
                    <button className="dm-create-btn" onClick={() => navigate("/diet-plans/add")}>
                        <i className="bx bx-plus" /> Create New Template
                    </button>
                </div>
            </div>

            {/* STATS ROW */}
            <div className="dm-stats-row">
                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">TOTAL ITEMS</span>
                        <div className="dm-stat-icon-wrapper blue">
                            <i className="bx bx-file" />
                        </div>
                    </div>
                    <div className="dm-stat-value">{templates.length}</div>
                    <div className="dm-stat-footnote">Active Templates</div>
                </div>

                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">ENGAGEMENT</span>
                        <div className="dm-stat-icon-wrapper purple">
                            <i className="bx bx-group" />
                        </div>
                    </div>
                    <div className="dm-stat-value">{totalAssignedCount}</div>
                    <div className="dm-stat-footnote">Client Assignments</div>
                </div>

                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">GROWTH</span>
                        <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                            <span className="dm-stat-pill-green">+{growthPercent}%</span>
                            <div className="dm-stat-icon-wrapper light-blue">
                                <i className="bx bx-trending-up" />
                            </div>
                        </div>
                    </div>
                    <div className="dm-stat-value">+{newThisMonth}</div>
                    <div className="dm-stat-footnote">New Plans This Month</div>
                </div>
            </div>

            {/* FEATURED PROTOCOLS DIVIDER */}
            <div className="dm-section-divider-container">
                <h2 className="dm-section-title">Featured Protocols</h2>
                <div className="dm-divider-line"></div>
            </div>

            {/* FEATURED PROTOCOLS GRID */}
            {featured.length === 0 ? (
                <div className="empty-state">No templates created yet.</div>
            ) : (
                <div className="dm-featured-grid">
                    {featured.map((t) => {
                        // Calculate Macro Percentages
                        const totalMacros = t.protein + t.fat + t.carbs;
                        const pPct = totalMacros > 0 ? Math.round((t.protein / totalMacros) * 100) : 0;
                        const fPct = totalMacros > 0 ? Math.round((t.fat / totalMacros) * 100) : 0;
                        const cPct = totalMacros > 0 ? Math.round((t.carbs / totalMacros) * 100) : 0;

                        return (
                            <div key={t.id} className="dm-featured-card">
                                <div className="dm-featured-image">
                                    {t.imageURL ? (
                                        <img src={t.imageURL} alt={t.name} />
                                    ) : (
                                        <div className="dm-featured-image-fallback">
                                            <i className="bx bx-restaurant" />
                                        </div>
                                    )}
                                    {/* Tag Badge */}
                                    <div className={`dm-image-badge ${t.tag.toLowerCase().includes("protein") ? "blue" : "red"}`}>
                                        {t.tag.toUpperCase()}
                                    </div>
                                </div>
                                <div className="dm-featured-body">
                                    <h3 className="dm-featured-name">{t.name}</h3>
                                    <p className="dm-featured-desc">{t.description || "Optimized nutritional protocol for peak performance and recovery."}</p>

                                    <div className="dm-featured-macro-row">
                                        <div className="dm-featured-macro-cell">
                                            <div className="dm-featured-macro-label">P</div>
                                            <div className="dm-featured-macro-value">{pPct}%</div>
                                        </div>
                                        <div className="dm-featured-macro-cell">
                                            <div className="dm-featured-macro-label">F</div>
                                            <div className="dm-featured-macro-value">{fPct}%</div>
                                        </div>
                                        <div className="dm-featured-macro-cell">
                                            <div className="dm-featured-macro-label">C</div>
                                            <div className="dm-featured-macro-value">{cPct}%</div>
                                        </div>
                                    </div>

                                    <div className="dm-featured-actions">
                                        <button className="dm-btn-outline" onClick={() => navigate(`/diet-plans/edit/${t.id}`)}>
                                            Edit Template
                                        </button>
                                        <button className="dm-btn-filled" onClick={() => navigate(`/diet-plans/view/${t.id}`)}>
                                            View Details
                                        </button>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {/* RECENT ASSIGNMENTS TABLE */}
            <div className="dm-assignments-card">
                <div className="dm-assignments-header">
                    <h3 className="dm-table-title">Recent Plan Assignments</h3>
                    <button className="dm-view-all-btn" onClick={() => navigate("/diet-plans/activity")}>
                        View All Activity
                    </button>
                </div>

                <div className="table-responsive">
                    <table className="dm-assignments-table">
                        <thead>
                            <tr>
                                <th>CLIENT NAME</th>
                                <th>ASSIGNED PROTOCOL</th>
                                <th>ASSIGNED DATE</th>
                                <th>DURATION</th>
                                <th>STATUS</th>
                            </tr>
                        </thead>
                        <tbody>
                            {assignments.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="empty-state" style={{ padding: "32px" }}>
                                        No plans assigned yet.
                                    </td>
                                </tr>
                            ) : (
                                assignments.map((a) => (
                                    <tr key={a.id}>
                                        <td>
                                            <div className="dm-client-cell">
                                                <div className="dm-client-avatar">
                                                    {a.clientPhoto ? (
                                                        <img src={a.clientPhoto} alt={a.clientName} />
                                                    ) : (
                                                        a.clientInitials
                                                    )}
                                                </div>
                                                <span className="dm-client-name">{a.clientName}</span>
                                            </div>
                                        </td>
                                        <td>
                                            <div className="dm-protocol-cell">
                                                <i className="bx bxs-flame dm-protocol-icon" />
                                                <span className="dm-protocol-name">{a.templateName}</span>
                                            </div>
                                        </td>
                                        <td className="dm-text-gray">{a.assignedDate}</td>
                                        <td className="dm-text-gray">{a.duration}</td>
                                        <td>
                                            <span className={`dm-status-pill ${a.status.toLowerCase() === "active" ? "active" : ""}`}>
                                                {a.status.toUpperCase()}
                                            </span>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </Layout>
    );
}