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

interface TemplateCard {
    id: string;
    name: string;
    description: string;
    imageURL: string | null;
    calories: number;
    protein: number;
    carbs: number;
    createdAt: Date | null;
    assignedCount: number;
}

interface AssignmentRow {
    id: string;
    clientName: string;
    templateName: string;
    assignedDate: string;
    duration: string;
    status: string;
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
                const snap = await getDocs(collection(db, "dietPlanTemplates"));
                if (cancelled) return;

                const monthStart = startOfMonth();

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
                            calories: data.calories ?? 0,
                            protein: data.protein ?? 0,
                            carbs: data.netCarbsLimit ?? data.carbs ?? 0,
                            createdAt,
                            assignedCount: assignedSnap.data().count,
                        };
                    })
                );
                if (cancelled) return;

                setTemplates(rows);
                setTotalAssignedCount(rows.reduce((sum, r) => sum + r.assignedCount, 0));
                setNewThisMonth(
                    rows.filter((r) => r.createdAt && r.createdAt >= monthStart).length
                );

                const assignSnap = await getDocs(
                    query(
                        collection(db, "clientDietPlans"),
                        orderBy("assignedAt", "desc"),
                        limit(5)
                    )
                );
                if (cancelled) return;

                setAssignments(
                    assignSnap.docs.map((d) => {
                        const data = d.data();
                        const assignedAt = data.assignedAt?.toDate ? data.assignedAt.toDate() : null;
                        return {
                            id: d.id,
                            clientName: data.clientName ?? "—",
                            templateName: data.templateName ?? "—",
                            assignedDate: assignedAt
                                ? assignedAt.toLocaleDateString("en-GB", {
                                    day: "2-digit",
                                    month: "short",
                                    year: "numeric",
                                })
                                : "—",
                            duration: data.durationWeeks
                                ? `${data.durationWeeks} weeks`
                                : "—",
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
        return () => {
            cancelled = true;
        };
    }, []);

    const featured = templates.slice(0, 3);

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <p style={{ color: "#999" }}>Loading diet plans...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            <div className="dm-header">
                <div>
                    <div className="dm-title">Diet Manage</div>
                    <div className="dm-subtitle">
                        Design, manage, and assign high-performance nutrition protocols for
                        elite athletes and transformation clients.
                    </div>
                </div>
                <div className="dm-header-actions">
                    <button
                        className="dm-browse-btn"
                        onClick={() => navigate("/diet-plans/library")}
                    >
                        <i className="bx bx-library" /> Browse Library
                    </button>
                    <button className="dm-create-btn" onClick={() => navigate("/diet-plans/add")}>
                        <i className="bx bx-plus" /> Create New Template
                    </button>
                </div>
            </div>

            <div className="dm-stats-row">
                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">TOTAL ITEMS</span>
                        <i className="bx bx-file dm-stat-icon" />
                    </div>
                    <div className="dm-stat-value">{templates.length}</div>
                    <div className="dm-stat-footnote">Active Templates</div>
                </div>

                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">ENGAGEMENT</span>
                        <i className="bx bx-group dm-stat-icon" />
                    </div>
                    <div className="dm-stat-value">{totalAssignedCount}</div>
                    <div className="dm-stat-footnote">Client Assignments</div>
                </div>

                <div className="dm-stat-card">
                    <div className="dm-stat-top">
                        <span className="dm-stat-label">GROWTH</span>
                        <span className="dm-stat-pill">
                            <i className="bx bx-trending-up" /> +{newThisMonth}
                        </span>
                    </div>
                    <div className="dm-stat-value green">+{newThisMonth}</div>
                    <div className="dm-stat-footnote">New Plans This Month</div>
                </div>
            </div>

            <div className="dm-section-title">Featured Protocols</div>

            {featured.length === 0 ? (
                <div className="profile-empty" style={{ padding: 24, marginBottom: 24 }}>
                    No templates created yet.
                </div>
            ) : (
                <div className="dm-featured-grid">
                    {featured.map((t) => (
                        <div key={t.id} className="dm-featured-card">
                            <div className="dm-featured-image">
                                {t.imageURL ? (
                                    <img src={t.imageURL} alt={t.name} />
                                ) : (
                                    <div className="dm-featured-image-fallback">
                                        <i className="bx bx-food-menu" />
                                    </div>
                                )}
                            </div>
                            <div className="dm-featured-body">
                                <div className="dm-featured-name">{t.name}</div>
                                {t.description && (
                                    <p className="dm-featured-desc">{t.description}</p>
                                )}

                                <div className="dm-featured-macro-row">
                                    <div className="dm-featured-macro-cell">
                                        <div className="dm-featured-macro-value">
                                            {t.calories}
                                        </div>
                                        <div className="dm-featured-macro-label">kcal</div>
                                    </div>
                                    <div className="dm-featured-macro-cell">
                                        <div className="dm-featured-macro-value">
                                            {t.protein}g
                                        </div>
                                        <div className="dm-featured-macro-label">protein</div>
                                    </div>
                                    <div className="dm-featured-macro-cell">
                                        <div className="dm-featured-macro-value">{t.carbs}g</div>
                                        <div className="dm-featured-macro-label">carbs</div>
                                    </div>
                                </div>

                                <div className="dm-featured-actions">
                                    <button
                                        className="dm-featured-link"
                                        onClick={() => navigate(`/diet-plans/edit/${t.id}`)}
                                    >
                                        Edit Template
                                    </button>
                                    <button
                                        className="dm-featured-link filled"
                                        onClick={() => navigate(`/diet-plans/view/${t.id}`)}
                                    >
                                        View Details
                                    </button>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            <div className="dm-assignments-card">
                <div className="dm-assignments-header">
                    <div className="dm-section-title" style={{ marginBottom: 0 }}>
                        Recent Plan Assignments
                    </div>
                    <button
                        className="dm-view-all-btn"
                        onClick={() => navigate("/diet-plans/activity")}
                    >
                        View All Activity <i className="bx bx-right-arrow-alt" />
                    </button>
                </div>

                {assignments.length === 0 ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No plans assigned yet.
                    </div>
                ) : (
                    <table className="dm-assignments-table">
                        <thead>
                            <tr>
                                <th>Client Name</th>
                                <th>Assigned Protocol</th>
                                <th>Assigned Date</th>
                                <th>Duration</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {assignments.map((a) => (
                                <tr key={a.id}>
                                    <td className="dm-client-name">{a.clientName}</td>
                                    <td>
                                        <span className="dm-protocol-pill">{a.templateName}</span>
                                    </td>
                                    <td className="dm-mono">{a.assignedDate}</td>
                                    <td>{a.duration}</td>
                                    <td>
                                        <span className={`dm-status-pill status-${a.status}`}>
                                            {a.status.toUpperCase()}
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