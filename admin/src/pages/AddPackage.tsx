import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, addDoc, getDocs, serverTimestamp } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/addPackage.css";

type BillingCycle = "monthly" | "quarterly" | "yearly";

interface FeatureItem {
    id: string;
    text: string;
    included: boolean;
}

function makeId() {
    return Math.random().toString(36).slice(2, 9);
}

export default function AddPackage() {
    const navigate = useNavigate();
    const [name, setName] = useState("");
    const [price, setPrice] = useState("");
    const [billingCycle, setBillingCycle] = useState<BillingCycle>("monthly");
    const [features, setFeatures] = useState<FeatureItem[]>([
        { id: makeId(), text: "", included: true },
    ]);
    const [markMostPopular, setMarkMostPopular] = useState(false);
    const [markBestValue, setMarkBestValue] = useState(false);
    const [errors, setErrors] = useState<{ name?: string; price?: string; features?: string }>(
        {}
    );
    const [submitting, setSubmitting] = useState(false);
    const [submitError, setSubmitError] = useState<string | null>(null);

    function addFeatureRow() {
        setFeatures((prev) => [...prev, { id: makeId(), text: "", included: true }]);
    }

    function updateFeatureText(id: string, text: string) {
        setFeatures((prev) => prev.map((f) => (f.id === id ? { ...f, text } : f)));
        if (errors.features) setErrors((prev) => ({ ...prev, features: undefined }));
    }

    function toggleFeatureIncluded(id: string) {
        setFeatures((prev) =>
            prev.map((f) => (f.id === id ? { ...f, included: !f.included } : f))
        );
    }

    function removeFeatureRow(id: string) {
        setFeatures((prev) => prev.filter((f) => f.id !== id));
    }

    function validate(): boolean {
        const newErrors: typeof errors = {};
        if (!name.trim()) newErrors.name = "Package name is required.";
        if (!price.trim()) {
            newErrors.price = "Base price is required.";
        } else if (Number.isNaN(Number(price)) || Number(price) <= 0) {
            newErrors.price = "Enter a valid price.";
        }
        const nonEmptyFeatures = features.filter((f) => f.text.trim());
        if (nonEmptyFeatures.length === 0) {
            newErrors.features = "Add at least one feature.";
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    async function handleCreate() {
        if (!validate()) return;
        setSubmitting(true);
        setSubmitError(null);
        try {
            const existingSnap = await getDocs(collection(db, "packages"));
            const nextOrder = existingSnap.size + 1;

            await addDoc(collection(db, "packages"), {
                name: name.trim(),
                price: Number(price),
                billingCycle,
                features: features
                    .filter((f) => f.included && f.text.trim())
                    .map((f) => f.text.trim()),
                badge: markMostPopular
                    ? "mostPopular"
                    : markBestValue
                        ? "bestValue"
                        : null,
                order: nextOrder,
                createdAt: serverTimestamp(),
            });

            navigate("/packages");
        } catch (err) {
            console.error("Create package failed:", err);
            setSubmitError("Couldn't create this package. Try again.");
        } finally {
            setSubmitting(false);
        }
    }

    return (
        <Layout title="Packages">
            <div className="add-pkg-header">
                <div className="add-pkg-title">Add New Packages</div>
                <div className="add-pkg-subtitle">
                    Define new pricing tiers for athletes and fitness enthusiasts.
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
                        placeholder="e.g. Elite Pro Athlete"
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
                                placeholder="4,999"
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
                            <button
                                type="button"
                                className={`add-pkg-feature-toggle ${f.included ? "included" : ""
                                    }`}
                                onClick={() => toggleFeatureIncluded(f.id)}
                            >
                                <i className="bx bx-check" />
                            </button>
                            <input
                                className="add-pkg-feature-input"
                                placeholder="e.g. 24/7 Gym Access"
                                value={f.text}
                                onChange={(e) => updateFeatureText(f.id, e.target.value)}
                            />
                            {features.length > 1 && (
                                <button
                                    type="button"
                                    className="add-pkg-feature-remove"
                                    onClick={() => removeFeatureRow(f.id)}
                                >
                                    <i className="bx bx-x" />
                                </button>
                            )}
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

            <div className="add-pkg-footer">
                {submitError && <span className="add-pkg-error">{submitError}</span>}
                <div className="add-pkg-footer-actions">
                    <button
                        className="add-pkg-cancel-btn"
                        onClick={() => navigate("/packages")}
                        disabled={submitting}
                    >
                        Cancel
                    </button>
                    <button
                        className="add-pkg-create-btn"
                        onClick={handleCreate}
                        disabled={submitting}
                    >
                        {submitting ? "Creating..." : "Create Package"}
                    </button>
                </div>
            </div>
        </Layout>
    );
}