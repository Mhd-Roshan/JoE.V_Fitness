import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, getDocs, deleteDoc, doc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/browseLibrary.css";
import "../styles/trainers.css";

interface TemplateCard {
    id: string;
    name: string;
    description: string;
    imageURL: string | null;
    calories: number;
    protein: number;
    carbs: number;
    category: string;
}

const CATEGORIES = ["All Templates", "Keto/Low-Carb", "High-Protein", "Maintenance", "Vegan"];

export default function BrowseLibrary() {
    const navigate = useNavigate();
    const [templates, setTemplates] = useState<TemplateCard[]>([]);
    const [activeCategory, setActiveCategory] = useState("All Templates");
    const [loading, setLoading] = useState(true);
    const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);
    const [deleting, setDeleting] = useState(false);
    const [deleteError, setDeleteError] = useState<string | null>(null);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(collection(db, "dietPlanTemplates"));
                if (cancelled) return;

                setTemplates(
                    snap.docs.map((d) => {
                        const data = d.data();
                        return {
                            id: d.id,
                            name: data.name ?? "Untitled Plan",
                            description: data.description ?? "",
                            imageURL: data.imageURL ?? null,
                            calories: data.calories ?? 0,
                            protein: data.protein ?? 0,
                            carbs: data.netCarbsLimit ?? data.carbs ?? 0,
                            category: data.category ?? "Maintenance",
                        };
                    })
                );
            } catch (err) {
                console.error("Browse library load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, []);

    async function handleConfirmDelete() {
        if (!deleteTarget) return;
        setDeleting(true);
        setDeleteError(null);
        try {
            // Delete the meals subcollection first (Firestore doesn't cascade-delete
            // subcollections automatically when you delete a parent doc).
            const mealsSnap = await getDocs(
                collection(db, "dietPlanTemplates", deleteTarget.id, "meals")
            );
            await Promise.all(
                mealsSnap.docs.map((d) =>
                    deleteDoc(doc(db, "dietPlanTemplates", deleteTarget.id, "meals", d.id))
                )
            );

            await deleteDoc(doc(db, "dietPlanTemplates", deleteTarget.id));

            // Update local state directly so the deleted template can't reappear
            // even if a stale re-fetch happens before Firestore's write settles.
            setTemplates((prev) => prev.filter((t) => t.id !== deleteTarget.id));
            setDeleteTarget(null);
        } catch (err) {
            console.error("Delete template failed:", err);
            setDeleteError("Couldn't delete this template. Try again.");
        } finally {
            setDeleting(false);
        }
    }

    const filtered =
        activeCategory === "All Templates"
            ? templates
            : templates.filter((t) => t.category === activeCategory);

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <p style={{ color: "#999" }}>Loading template library...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            <button className="back-btn-outlined" onClick={() => navigate("/diet-plans")}>
                <i className="bx bx-arrow-back" /> Back to Diet Plans
            </button>

            <div className="library-toolbar">
                <div className="library-tabs">
                    {CATEGORIES.map((c) => (
                        <button
                            key={c}
                            className={`library-tab-btn ${activeCategory === c ? "active" : ""}`}
                            onClick={() => setActiveCategory(c)}
                        >
                            {c}
                        </button>
                    ))}
                </div>
                <button
                    className="library-create-btn"
                    onClick={() => navigate("/diet-plans/add")}
                >
                    <i className="bx bx-plus" /> Create New Template
                </button>
            </div>

            <div className="library-section-title">Featured Protocols</div>

            <div className="library-grid">
                {filtered.map((t) => (
                    <div key={t.id} className="library-card">
                        <div className="library-card-image">
                            {t.imageURL ? (
                                <img src={t.imageURL} alt={t.name} />
                            ) : (
                                <div className="library-card-image-fallback">
                                    <i className="bx bx-food-menu" />
                                </div>
                            )}
                        </div>

                        <div className="library-card-body">
                            <div className="library-card-name">{t.name}</div>
                            {t.description && (
                                <p className="library-card-desc">{t.description}</p>
                            )}

                            <div className="library-macro-row">
                                <div className="library-macro-cell">
                                    <div className="library-macro-value">{t.calories}</div>
                                    <div className="library-macro-label">KCAL</div>
                                </div>
                                <div className="library-macro-cell">
                                    <div className="library-macro-value">{t.protein}g</div>
                                    <div className="library-macro-label">PROTEIN</div>
                                </div>
                                <div className="library-macro-cell">
                                    <div className="library-macro-value">{t.carbs}g</div>
                                    <div className="library-macro-label">CARBS</div>
                                </div>
                            </div>

                            <div className="library-card-actions">
                                <button
                                    className="library-edit-link"
                                    onClick={() => navigate(`/diet-plans/edit/${t.id}`)}
                                >
                                    Edit Template <i className="bx bx-right-arrow-alt" />
                                </button>
                                <button
                                    className="library-delete-btn"
                                    onClick={() =>
                                        setDeleteTarget({ id: t.id, name: t.name })
                                    }
                                    title="Delete template"
                                >
                                    <i className="bx bx-trash" />
                                </button>
                            </div>
                        </div>
                    </div>
                ))}

                <button
                    className="library-new-plan-card"
                    onClick={() => navigate("/diet-plans/add")}
                >
                    <i className="bx bx-plus-circle" />
                    <span>New Plan</span>
                </button>
            </div>

            {filtered.length === 0 && (
                <div className="profile-empty" style={{ padding: 24 }}>
                    No templates in this category yet.
                </div>
            )}

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
                            Delete "{deleteTarget.name}"?
                        </div>
                        <p className="delete-modal-text">
                            This permanently removes the template and all its meals.
                            Clients currently assigned this plan keep their existing data,
                            but the template itself will no longer be available to assign.
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
                                {deleting ? "Deleting..." : "Delete Template"}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}