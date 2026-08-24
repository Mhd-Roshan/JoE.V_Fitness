import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    getDocs,
    addDoc,
    updateDoc,
    deleteDoc,
    doc,
    serverTimestamp,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/manageAddons.css";

interface AddOn {
    id: string;
    name: string;
    price: number;
    description: string;
    active: boolean;
    conversionPct: number | null;
}

function mapAddonDoc(d: { id: string; data: () => Record<string, unknown> }): AddOn {
    const data = d.data();
    return {
        id: d.id,
        name: (data.name as string) ?? "Add-on",
        price: (data.price as number) ?? 0,
        description: (data.description as string) ?? "",
        active: (data.active as boolean) ?? true,
        conversionPct: (data.conversionPct as number) ?? null,
    };
}

export default function ManageAddons() {
    const navigate = useNavigate();
    const [addons, setAddons] = useState<AddOn[]>([]);
    const [loading, setLoading] = useState(true);
    const [editingId, setEditingId] = useState<string | null>(null);
    const [showAddForm, setShowAddForm] = useState(false);
    const [formName, setFormName] = useState("");
    const [formPrice, setFormPrice] = useState("");
    const [formDesc, setFormDesc] = useState("");
    const [errors, setErrors] = useState<{ name?: string; price?: string }>({});
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(collection(db, "addOns"));
                if (!cancelled) {
                    setAddons(snap.docs.map(mapAddonDoc));
                }
            } catch (err) {
                console.error("Load add-ons failed:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();

        return () => {
            cancelled = true;
        };
    }, []);

    async function refreshAddons() {
        try {
            const snap = await getDocs(collection(db, "addOns"));
            setAddons(snap.docs.map(mapAddonDoc));
        } catch (err) {
            console.error("Refresh add-ons failed:", err);
        }
    }

    function resetForm() {
        setFormName("");
        setFormPrice("");
        setFormDesc("");
        setErrors({});
        setShowAddForm(false);
        setEditingId(null);
    }

    function startEdit(a: AddOn) {
        setEditingId(a.id);
        setShowAddForm(true);
        setFormName(a.name);
        setFormPrice(String(a.price));
        setFormDesc(a.description);
    }

    function validate(): boolean {
        const newErrors: typeof errors = {};
        if (!formName.trim()) newErrors.name = "Name is required.";
        if (!formPrice.trim() || Number.isNaN(Number(formPrice)) || Number(formPrice) < 0) {
            newErrors.price = "Enter a valid price.";
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    async function handleSave() {
        if (!validate()) return;
        setSaving(true);
        try {
            if (editingId) {
                await updateDoc(doc(db, "addOns", editingId), {
                    name: formName.trim(),
                    price: Number(formPrice),
                    description: formDesc.trim(),
                });
            } else {
                await addDoc(collection(db, "addOns"), {
                    name: formName.trim(),
                    price: Number(formPrice),
                    description: formDesc.trim(),
                    active: true,
                    createdAt: serverTimestamp(),
                });
            }
            resetForm();
            await refreshAddons();
        } catch (err) {
            console.error("Save add-on failed:", err);
        } finally {
            setSaving(false);
        }
    }

    async function toggleActive(a: AddOn) {
        try {
            await updateDoc(doc(db, "addOns", a.id), { active: !a.active });
            setAddons((prev) =>
                prev.map((x) => (x.id === a.id ? { ...x, active: !x.active } : x))
            );
        } catch (err) {
            console.error("Toggle add-on failed:", err);
        }
    }

    async function handleDelete(id: string) {
        if (!window.confirm("Remove this add-on? This can't be undone.")) return;
        try {
            await deleteDoc(doc(db, "addOns", id));
            setAddons((prev) => prev.filter((a) => a.id !== id));
        } catch (err) {
            console.error("Delete add-on failed:", err);
        }
    }

    if (loading) {
        return (
            <Layout title="Packages">
                <p style={{ color: "#999" }}>Loading add-ons...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Packages">
            <button className="back-btn-outlined" onClick={() => navigate("/packages")}>
                <i className="bx bx-arrow-back" /> Back to Packages
            </button>

            <div className="addons-header">
                <div>
                    <div className="addons-title">Manage Add-ons</div>
                    <div className="addons-subtitle">
                        Optional extras clients can attach to any package for extra revenue.
                    </div>
                </div>
                {!showAddForm && (
                    <button
                        className="addons-new-btn"
                        onClick={() => {
                            setShowAddForm(true);
                            setEditingId(null);
                        }}
                    >
                        <i className="bx bx-plus" /> Add Add-on
                    </button>
                )}
            </div>

            {showAddForm && (
                <div className="addons-form-card">
                    <div className="addons-form-title">
                        {editingId ? "Edit Add-on" : "New Add-on"}
                    </div>

                    <div className="addons-form-row">
                        <div className="addons-form-field" style={{ flex: 2 }}>
                            <label className="add-pkg-label">Name</label>
                            <input
                                className={`add-pkg-input ${errors.name ? "input-error" : ""}`}
                                placeholder="e.g. Zumba Plus"
                                value={formName}
                                onChange={(e) => {
                                    setFormName(e.target.value);
                                    if (errors.name)
                                        setErrors((prev) => ({ ...prev, name: undefined }));
                                }}
                            />
                            {errors.name && <span className="add-pkg-error">{errors.name}</span>}
                        </div>
                        <div className="addons-form-field" style={{ flex: 1 }}>
                            <label className="add-pkg-label">Price (₹/mo)</label>
                            <input
                                className={`add-pkg-input ${errors.price ? "input-error" : ""}`}
                                type="number"
                                min={0}
                                placeholder="499"
                                value={formPrice}
                                onChange={(e) => {
                                    setFormPrice(e.target.value);
                                    if (errors.price)
                                        setErrors((prev) => ({ ...prev, price: undefined }));
                                }}
                            />
                            {errors.price && (
                                <span className="add-pkg-error">{errors.price}</span>
                            )}
                        </div>
                    </div>

                    <div className="addons-form-field">
                        <label className="add-pkg-label">Description</label>
                        <textarea
                            className="add-pkg-input"
                            rows={2}
                            placeholder="Short description shown to clients..."
                            value={formDesc}
                            onChange={(e) => setFormDesc(e.target.value)}
                        />
                    </div>

                    <div className="addons-form-actions">
                        <button
                            className="add-pkg-cancel-btn"
                            onClick={resetForm}
                            disabled={saving}
                        >
                            Cancel
                        </button>
                        <button
                            className="add-pkg-create-btn"
                            onClick={handleSave}
                            disabled={saving}
                        >
                            {saving ? "Saving..." : editingId ? "Save Changes" : "Create Add-on"}
                        </button>
                    </div>
                </div>
            )}

            {addons.length === 0 ? (
                <div className="profile-empty" style={{ padding: 24 }}>
                    No add-ons created yet.
                </div>
            ) : (
                <div className="addons-list">
                    {addons.map((a) => (
                        <div key={a.id} className="addons-row">
                            <div className="addons-row-main">
                                <div className="addons-row-name">
                                    {a.name}
                                    {!a.active && (
                                        <span className="addons-inactive-pill">Inactive</span>
                                    )}
                                </div>
                                {a.description && (
                                    <div className="addons-row-desc">{a.description}</div>
                                )}
                            </div>
                            <div className="addons-row-price">
                                ₹{a.price.toLocaleString("en-IN")}/mo
                            </div>
                            {a.conversionPct !== null && (
                                <div className="addons-row-conv">{a.conversionPct}% conv.</div>
                            )}
                            <div className="addons-row-actions">
                                <button
                                    className="addons-icon-btn"
                                    onClick={() => toggleActive(a)}
                                    title={a.active ? "Deactivate" : "Activate"}
                                >
                                    <i className={`bx ${a.active ? "bx-toggle-right" : "bx-toggle-left"}`} />
                                </button>
                                <button
                                    className="addons-icon-btn"
                                    onClick={() => startEdit(a)}
                                    title="Edit"
                                >
                                    <i className="bx bx-edit" />
                                </button>
                                <button
                                    className="addons-icon-btn danger"
                                    onClick={() => handleDelete(a.id)}
                                    title="Delete"
                                >
                                    <i className="bx bx-trash" />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </Layout>
    );
}