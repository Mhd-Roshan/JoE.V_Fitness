import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { doc, getDoc, updateDoc, deleteDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/addPackage.css";

type BillingCycle = "monthly" | "quarterly" | "yearly";

interface FeatureItem {
    id: string;
    text: string;
}

function makeId() {
    return Math.random().toString(36).slice(2, 9);
}

export default function EditPackage() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();

    const [loading, setLoading] = useState(true);
    const [name, setName] = useState("");
    const [price, setPrice] = useState("");
    const [billingCycle, setBillingCycle] = useState<BillingCycle>("monthly");
    const [features, setFeatures] = useState<FeatureItem[]>([]);
    const [markMostPopular, setMarkMostPopular] = useState(false);
    const [markBestValue, setMarkBestValue] = useState(false);
    const [errors, setErrors] = useState<{ name?: string; price?: string; features?: string }>(
        {}
    );
    const [submitting, setSubmitting] = useState(false);
    const [submitError, setSubmitError] = useState<string | null>(null);
    const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
    const [deleting, setDeleting] = useState(false);

    useEffect(() => {
        if (!id) return;
        async function load() {
            try {
                const snap = await getDoc(doc(db, "packages", id!));
                if (snap.exists()) {
                    const data = snap.data();
                    setName(data.name ?? "");
                    setPrice(String(data.price ?? ""));
                    setBillingCycle(data.billingCycle ?? "monthly");
                    setFeatures(
                        (data.features ?? []).map((f: string) => ({ id: makeId(), text: f }))
                    );
                    setMarkMostPopular(data.badge === "mostPopular");
                    setMarkBestValue(data.badge === "bestValue");
                }
            } catch (err) {
                console.error("Load package failed:", err);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, [id]);

    function addFeatureRow() {
        setFeatures((prev) => [...prev, { id: makeId(), text: "" }]);
    }

    function updateFeatureText(fid: string, text: string) {
        setFeatures((prev) => prev.map((f) => (f.id === fid ? { ...f, text } : f)));
        if (errors.features) setErrors((prev) => ({ ...prev, features: undefined }));
    }

    function removeFeatureRow(fid: string) {
        setFeatures((prev) => prev.filter((f) => f.id !== fid));
    }

    function validate(): boolean {
        const newErrors: typeof errors = {};
        if (!name.trim()) newErrors.name = "Package name is required.";
        if (!price.trim()) {
            newErrors.price = "Base price is required.";
        } else if (Number.isNaN(Number(price)) || Number(price) <= 0) {
            newErrors.price = "Enter a valid price.";
        }
        if (features.filter((f) => f.text.trim()).length === 0) {
            newErrors.features = "Add at least one feature.";
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    async function handleSave() {
        if (!id || !validate()) return;
        setSubmitting(true);
        setSubmitError(null);
        try {
            await updateDoc(doc(db, "packages", id), {
                name: name.trim(),
                price: Number(price),
                billingCycle,
                features: features.filter((f) => f.text.trim()).map((f) => f.text.trim()),
                badge: markMostPopular ? "mostPopular" : markBestValue ? "bestValue" : null,
            });
            navigate("/packages");
        } catch (err) {
            console.error("Update package failed:", err);
            setSubmitError("Couldn't save changes. Try again.");
        } finally {
            setSubmitting(false);
        }
    }

    async function handleDelete() {
        if (!id) return;
        setDeleting(true);
        try {
            await deleteDoc(doc(db, "packages", id));
            navigate("/packages");
        } catch (err) {
            console.error("Delete package failed:", err);
            setSubmitError("Couldn't delete this package. Try again.");
            setDeleting(false);
        }
    }

    if (loading) {
        return (
            <Layout title="Packages">
                <p style={{ color: "#999" }}>Loading package...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Packages">
            <button className="back-btn-outlined" onClick={() => navigate("/packages")}>
                <i className="bx bx-arrow-back" /> Back to Packages
            </button>

            <div className="add-pkg-header">
                <div className="add-pkg-title">Edit Package</div>
                <div className="add-pkg-subtitle">
                    Update pricing, features, and highlight badges for this tier.
                </div>
            </div>

            <div className="add-pkg-card">
                <div className="add-pkg-card-heading">
                    <i className="bx bx-detail" /> Basic Details
                </div>

                <div className="add-pkg-field">
                    <label className="add-pkg-label">Package Name</label>
                    <input
                        className={`add-pkg-input ${errors.name ? "input-error" : ""}`}
                        value={name}
                        onChange={(e) => {
                            setName(e.target.value);
                            if (errors.name) setErrors((prev) => ({ ...prev, name: undefined }));
                        }}
                    />
                    {errors.name && <span className="add-pkg-error">{errors.name}</span>}
                </div>

                <div className="add-pkg-row">
                    <div className="add-pkg-field" style={{ flex: 1 }}>
                        <label className="add-pkg-label">Base Price (₹)</label>
                        <div className="add-pkg-price-input-group">
                            <span className="add-pkg-price-prefix">₹</span>
                            <input
                                className={`add-pkg-price-input ${errors.price ? "input-error" : ""}`}
                                type="number"
                                min={0}
                                value={price}
                                onChange={(e) => {
                                    setPrice(e.target.value);
                                    if (errors.price)
                                        setErrors((prev) => ({ ...prev, price: undefined }));
                                }}
                            />
                        </div>
                        {errors.price && <span className="add-pkg-error">{errors.price}</span>}
                    </div>

                    <div className="add-pkg-field" style={{ flex: 1 }}>
                        <label className="add-pkg-label">Billing Cycle</label>
                        <div className="add-pkg-cycle-row">
                            {(["monthly", "quarterly", "yearly"] as BillingCycle[]).map((c) => (
                                <button
                                    key={c}
                                    type="button"
                                    className={`add-pkg-cycle-btn ${billingCycle === c ? "active" : ""
                                        }`}
                                    onClick={() => setBillingCycle(c)}
                                >
                                    {c[0].toUpperCase() + c.slice(1)}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            </div>

            <div className="add-pkg-card">
                <div className="add-pkg-card-header-row">
                    <div className="add-pkg-card-heading">
                        <i className="bx bx-list-check" /> Features List
                    </div>
                    <button className="add-pkg-add-feature-btn" onClick={addFeatureRow}>
                        <i className="bx bx-plus" /> Add Feature
                    </button>
                </div>

                <div className="add-pkg-features-grid">
                    {features.map((f) => (
                        <div key={f.id} className="add-pkg-feature-row">
                            <span className="add-pkg-feature-toggle included">
                                <i className="bx bx-check" />
                            </span>
                            <input
                                className="add-pkg-feature-input"
                                value={f.text}
                                onChange={(e) => updateFeatureText(f.id, e.target.value)}
                            />
                            <button
                                type="button"
                                className="add-pkg-feature-remove"
                                onClick={() => removeFeatureRow(f.id)}
                            >
                                <i className="bx bx-x" />
                            </button>
                        </div>
                    ))}
                </div>
                {errors.features && <span className="add-pkg-error">{errors.features}</span>}

                <div className="add-pkg-highlight-section">
                    <div className="add-pkg-card-heading" style={{ marginBottom: 16 }}>
                        <i className="bx bx-badge-check" /> Package Highlight
                    </div>

                    <div className="add-pkg-toggle-row">
                        <div>
                            <div className="add-pkg-toggle-title">Mark as Most Popular</div>
                            <div className="add-pkg-toggle-desc">
                                Adds a 'Popular' badge to this package on the pricing screen.
                            </div>
                        </div>
                        <button
                            type="button"
                            className={`add-pkg-switch ${markMostPopular ? "on" : ""}`}
                            onClick={() => {
                                setMarkMostPopular((v) => !v);
                                if (!markMostPopular) setMarkBestValue(false);
                            }}
                        >
                            <span className="add-pkg-switch-knob" />
                        </button>
                    </div>

                    <div className="add-pkg-toggle-row">
                        <div>
                            <div className="add-pkg-toggle-title">Add Best Value Badge</div>
                            <div className="add-pkg-toggle-desc">
                                Recommended for quarterly or yearly plans to drive conversions.
                            </div>
                        </div>
                        <button
                            type="button"
                            className={`add-pkg-switch ${markBestValue ? "on" : ""}`}
                            onClick={() => {
                                setMarkBestValue((v) => !v);
                                if (!markBestValue) setMarkMostPopular(false);
                            }}
                        >
                            <span className="add-pkg-switch-knob" />
                        </button>
                    </div>
                </div>
            </div>

            <div className="add-pkg-footer" style={{ justifyContent: "space-between" }}>
                <button
                    className="edit-pkg-delete-btn"
                    onClick={() => setShowDeleteConfirm(true)}
                    disabled={submitting}
                >
                    <i className="bx bx-trash" /> Delete Package
                </button>

                <div className="add-pkg-footer-actions">
                    {submitError && <span className="add-pkg-error">{submitError}</span>}
                    <button
                        className="add-pkg-cancel-btn"
                        onClick={() => navigate("/packages")}
                        disabled={submitting}
                    >
                        Cancel
                    </button>
                    <button
                        className="add-pkg-create-btn"
                        onClick={handleSave}
                        disabled={submitting}
                    >
                        {submitting ? "Saving..." : "Save Changes"}
                    </button>
                </div>
            </div>

            {showDeleteConfirm && (
                <div
                    className="delete-modal-overlay"
                    onClick={() => !deleting && setShowDeleteConfirm(false)}
                >
                    <div className="delete-modal" onClick={(e) => e.stopPropagation()}>
                        <div className="delete-modal-icon">
                            <i className="bx bx-error-circle" />
                        </div>
                        <div className="delete-modal-title">Delete "{name}"?</div>
                        <p className="delete-modal-text">
                            This removes the package permanently. Existing subscribers on this
                            plan are not affected, but no new signups can choose it.
                        </p>
                        <div className="delete-modal-actions">
                            <button
                                className="delete-modal-cancel"
                                onClick={() => setShowDeleteConfirm(false)}
                                disabled={deleting}
                            >
                                Cancel
                            </button>
                            <button
                                className="delete-modal-confirm"
                                onClick={handleDelete}
                                disabled={deleting}
                            >
                                {deleting ? "Deleting..." : "Delete Package"}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}