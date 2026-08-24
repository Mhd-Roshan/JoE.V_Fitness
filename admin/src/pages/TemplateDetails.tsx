import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { doc, getDoc, collection, getDocs, orderBy, query } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/templateDetails.css";

interface TemplateData {
    name: string;
    calories: number;
    protein: number;
    fat: number;
    netCarbsLimit: number;
    fastingWindow: string | null;
    fastingProtocolLabel: string | null;
    hydrationGoal: number;
    hydrationNote: string;
    prohibitions: string[];
}

interface MealRow {
    id: string;
    time: string;
    name: string;
    ingredients: string;
    protein: number;
    fat: number;
    carbs: number;
    imageURL: string | null;
    tags: string[];
}

export default function TemplateDetails() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();
    const [template, setTemplate] = useState<TemplateData | null>(null);
    const [meals, setMeals] = useState<MealRow[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!id) return;
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDoc(doc(db, "dietPlanTemplates", id!));
                if (!cancelled && snap.exists()) {
                    const data = snap.data();
                    setTemplate({
                        name: data.name ?? "Untitled Plan",
                        calories: data.calories ?? 0,
                        protein: data.protein ?? 0,
                        fat: data.fat ?? 0,
                        netCarbsLimit: data.netCarbsLimit ?? 0,
                        fastingWindow: data.fastingWindow ?? null,
                        fastingProtocolLabel: data.fastingProtocolLabel ?? null,
                        hydrationGoal: data.hydrationGoal ?? 0,
                        hydrationNote: data.hydrationNote ?? "",
                        prohibitions: data.prohibitions ?? [],
                    });
                }

                const mealsSnap = await getDocs(
                    query(
                        collection(db, "dietPlanTemplates", id!, "meals"),
                        orderBy("time", "asc")
                    )
                );
                if (!cancelled) {
                    setMeals(
                        mealsSnap.docs.map((d) => {
                            const data = d.data();
                            return {
                                id: d.id,
                                time: data.time ?? "",
                                name: data.name ?? "Untitled Meal",
                                ingredients: data.ingredients ?? "",
                                protein: data.protein ?? 0,
                                fat: data.fat ?? 0,
                                carbs: data.carbs ?? 0,
                                imageURL: data.imageURL ?? null,
                                tags: data.tags ?? [],
                            };
                        })
                    );
                }
            } catch (err) {
                console.error("Load template details failed:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, [id]);

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <p style={{ color: "#999" }}>Loading template...</p>
            </Layout>
        );
    }

    if (!template) {
        return (
            <Layout title="Diet Plan">
                <button className="back-btn-outlined" onClick={() => navigate("/diet-plans")}>
                    <i className="bx bx-arrow-back" /> Back to Diet Plans
                </button>
                <div className="profile-empty" style={{ padding: 24 }}>
                    Template not found.
                </div>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            <div className="td-header">
                <button className="back-btn-outlined" onClick={() => navigate("/diet-plans")}>
                    <i className="bx bx-arrow-back" /> Back to Diet Plans
                </button>
                <button
                    className="td-edit-btn"
                    onClick={() => navigate(`/diet-plans/edit/${id}`)}
                >
                    <i className="bx bx-edit" /> Edit Plan
                </button>
            </div>

            <div className="td-macro-row">
                <div className="td-macro-card">
                    <i className="bx bx-flame td-macro-icon red" />
                    <div>
                        <div className="td-macro-value">
                            {template.calories}
                            <span className="td-macro-unit">kcal</span>
                        </div>
                        <div className="td-macro-label">Daily Calories</div>
                    </div>
                </div>
                <div className="td-macro-card">
                    <i className="bx bx-dumbbell td-macro-icon blue" />
                    <div>
                        <div className="td-macro-value">{template.protein}g</div>
                        <div className="td-macro-label">Protein</div>
                    </div>
                </div>
                <div className="td-macro-card">
                    <i className="bx bx-droplet td-macro-icon cyan" />
                    <div>
                        <div className="td-macro-value">{template.fat}g</div>
                        <div className="td-macro-label">Healthy Fats</div>
                    </div>
                </div>
                <div className="td-macro-card">
                    <i className="bx bx-leaf td-macro-icon green" />
                    <div>
                        <div className="td-macro-value">&lt;{template.netCarbsLimit}g</div>
                        <div className="td-macro-label">Net Carbs</div>
                    </div>
                </div>
            </div>

            <div className="td-layout">
                <div className="td-sidebar">
                    {template.fastingWindow && (
                        <div className="td-side-card">
                            <div className="td-side-title">Fasting Window</div>
                            <span className="td-fasting-badge">
                                {template.fastingProtocolLabel ?? "Fasting Protocol"}
                            </span>
                            <div className="td-fasting-time">{template.fastingWindow}</div>
                        </div>
                    )}

                    <div className="td-side-card">
                        <div className="td-side-title">Hydration Goal</div>
                        <div className="td-hydration-value">{template.hydrationGoal}L Daily</div>
                        {template.hydrationNote && (
                            <p className="td-hydration-note">{template.hydrationNote}</p>
                        )}
                    </div>

                    <div className="td-side-card">
                        <div className="td-side-title">
                            <i className="bx bx-block" /> Prohibitions
                        </div>
                        {template.prohibitions.length === 0 ? (
                            <span className="profile-empty">None specified</span>
                        ) : (
                            template.prohibitions.map((p, i) => (
                                <div key={i} className="td-prohibition-item">
                                    <i className="bx bx-x-circle" /> {p}
                                </div>
                            ))
                        )}
                    </div>
                </div>

                <div className="td-main">
                    <div className="td-meal-header">Meal Sequence</div>

                    {meals.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 24 }}>
                            No meals added to this plan yet.
                        </div>
                    ) : (
                        <div className="td-meal-list">
                            {meals.map((m) => (
                                <div key={m.id} className="td-meal-card">
                                    <div className="td-meal-image">
                                        {m.imageURL ? (
                                            <img src={m.imageURL} alt={m.name} />
                                        ) : (
                                            <div className="td-meal-image-fallback">
                                                <i className="bx bx-restaurant" />
                                            </div>
                                        )}
                                    </div>

                                    <div className="td-meal-body">
                                        <div className="td-meal-time">{m.time}</div>
                                        <div className="td-meal-name">{m.name}</div>
                                        {m.ingredients && (
                                            <p className="td-meal-desc">{m.ingredients}</p>
                                        )}
                                        {m.tags.length > 0 && (
                                            <div className="td-meal-tags">
                                                {m.tags.map((tag, i) => (
                                                    <span key={i} className="td-meal-tag">
                                                        {tag}
                                                    </span>
                                                ))}
                                            </div>
                                        )}
                                    </div>

                                    <div className="td-meal-macros">
                                        <div className="td-meal-macro protein">
                                            {m.protein}g
                                        </div>
                                        <div className="td-meal-macro fat">{m.fat}g</div>
                                        <div className="td-meal-macro carbs">{m.carbs}g</div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </Layout>
    );
}