import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
    doc,
    getDoc,
    setDoc,
    addDoc,
    collection,
    getDocs,
    deleteDoc,
    serverTimestamp,
} from "firebase/firestore";
import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { db, storage } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/createDietTemplate.css";

interface Meal {
    id: string;
    time: string;
    name: string;
    ingredients: string;
    protein: number;
    fat: number;
    carbs: number;
    imageFile: File | null;
    imageURL: string | null;
}

function makeId() {
    return Math.random().toString(36).slice(2, 9);
}

// ==========================================
// IMAGE COMPRESSION UTILITY
// ==========================================
const compressImage = (file: File, maxWidth = 800, quality = 0.7): Promise<File> => {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = (event) => {
            const img = new Image();
            img.src = event.target?.result as string;
            img.onload = () => {
                const canvas = document.createElement("canvas");
                let { width, height } = img;

                // Scale down if width is greater than maxWidth
                if (width > maxWidth) {
                    height = (height * maxWidth) / width;
                    width = maxWidth;
                }

                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext("2d");

                if (!ctx) {
                    resolve(file); // Fallback to original if canvas fails
                    return;
                }

                ctx.drawImage(img, 0, 0, width, height);

                // Compress to JPEG
                canvas.toBlob(
                    (blob) => {
                        if (!blob) {
                            resolve(file); // Fallback to original
                            return;
                        }
                        const newFile = new File([blob], file.name.replace(/\.[^/.]+$/, "") + ".jpeg", {
                            type: "image/jpeg",
                        });
                        resolve(newFile);
                    },
                    "image/jpeg",
                    quality
                );
            };
            img.onerror = (error) => reject(error);
        };
        reader.onerror = (error) => reject(error);
    });
};

export default function CreateDietTemplate() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();
    const isEdit = Boolean(id);

    const [loading, setLoading] = useState(isEdit);
    const [name, setName] = useState("");
    const [templateImageFile, setTemplateImageFile] = useState<File | null>(null);
    const [existingImageURL, setExistingImageURL] = useState<string | null>(null);
    const [calories, setCalories] = useState("2200");
    const [protein, setProtein] = useState("180");
    const [fastingWindow, setFastingWindow] = useState("14");
    const [netCarbsLimit, setNetCarbsLimit] = useState("30");
    const [hydrationGoal, setHydrationGoal] = useState("3.5");
    const [hydrationNote, setHydrationNote] = useState(
        "Include electrolytes (Sodium, Magnesium)"
    );
    const [prohibitions, setProhibitions] = useState<string[]>([
        "No refined sugars",
        "No seed oils",
        "No starches",
        "No high-carb fruit",
    ]);
    const [newProhibition, setNewProhibition] = useState("");
    const [meals, setMeals] = useState<Meal[]>([]);
    const [originalMealIds, setOriginalMealIds] = useState<Set<string>>(new Set());
    const [deletedMealIds, setDeletedMealIds] = useState<string[]>([]);

    // Meal form
    const [showMealForm, setShowMealForm] = useState(false);
    const [editingMealId, setEditingMealId] = useState<string | null>(null);
    const [mealTime, setMealTime] = useState("");
    const [mealName, setMealName] = useState("");
    const [mealIngredients, setMealIngredients] = useState("");
    const [mealProtein, setMealProtein] = useState("");
    const [mealFat, setMealFat] = useState("");
    const [mealCarbs, setMealCarbs] = useState("");
    const [mealImage, setMealImage] = useState<File | null>(null);
    const [mealExistingImageURL, setMealExistingImageURL] = useState<string | null>(null);

    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState<string | null>(null);

    useEffect(() => {
        if (!id) return;
        async function load() {
            try {
                const snap = await getDoc(doc(db, "dietPlanTemplates", id!));
                if (snap.exists()) {
                    const data = snap.data();
                    setName(data.name ?? "");
                    setCalories(String(data.calories ?? ""));
                    setProtein(String(data.protein ?? ""));
                    setFastingWindow(String(data.fastingWindow ?? ""));
                    setNetCarbsLimit(String(data.netCarbsLimit ?? ""));
                    setHydrationGoal(String(data.hydrationGoal ?? ""));
                    setHydrationNote(data.hydrationNote ?? "");
                    setProhibitions(data.prohibitions ?? []);
                    setExistingImageURL(data.imageURL ?? null);
                }
                const mealsSnap = await getDocs(
                    collection(db, "dietPlanTemplates", id!, "meals")
                );
                const loadedMeals = mealsSnap.docs.map((d) => {
                    const data = d.data();
                    return {
                        id: d.id,
                        time: data.time ?? "",
                        name: data.name ?? "",
                        ingredients: data.ingredients ?? "",
                        protein: data.protein ?? 0,
                        fat: data.fat ?? 0,
                        carbs: data.carbs ?? 0,
                        imageFile: null,
                        imageURL: data.imageURL ?? null,
                    };
                });
                setMeals(loadedMeals);
                setOriginalMealIds(new Set(loadedMeals.map((m) => m.id)));
            } catch (err) {
                console.error("Load template failed:", err);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, [id]);

    // --- Compression Handlers ---
    const handleTemplatePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        try {
            const compressed = await compressImage(file);
            setTemplateImageFile(compressed);
        } catch (err) {
            console.error("Compression error:", err);
            setTemplateImageFile(file); // Fallback to original
        }
    };

    const handleMealPhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        try {
            const compressed = await compressImage(file);
            setMealImage(compressed);
        } catch (err) {
            console.error("Compression error:", err);
            setMealImage(file); // Fallback to original
        }
    };
    // ----------------------------

    function addProhibition() {
        const trimmed = newProhibition.trim();
        if (!trimmed) return;
        setProhibitions((prev) => [...prev, trimmed]);
        setNewProhibition("");
    }

    function removeProhibition(idx: number) {
        setProhibitions((prev) => prev.filter((_, i) => i !== idx));
    }

    function resetMealForm() {
        setMealTime("");
        setMealName("");
        setMealIngredients("");
        setMealProtein("");
        setMealFat("");
        setMealCarbs("");
        setMealImage(null);
        setMealExistingImageURL(null);
        setEditingMealId(null);
        setShowMealForm(false);
    }

    function openAddMealSlot() {
        setEditingMealId(null);
        setMealTime("");
        setMealName("");
        setMealIngredients("");
        setMealProtein("");
        setMealFat("");
        setMealCarbs("");
        setMealImage(null);
        setMealExistingImageURL(null);
        setShowMealForm(true);
    }

    function openEditMeal(meal: Meal) {
        setEditingMealId(meal.id);
        setMealTime(meal.time);
        setMealName(meal.name);
        setMealIngredients(meal.ingredients);
        setMealProtein(String(meal.protein));
        setMealFat(String(meal.fat));
        setMealCarbs(String(meal.carbs));
        setMealImage(null);
        setMealExistingImageURL(meal.imageURL);
        setShowMealForm(true);
    }

    function handleSaveMealToPlan() {
        if (!mealName.trim()) return;

        if (editingMealId) {
            setMeals((prev) =>
                prev.map((m) =>
                    m.id === editingMealId
                        ? {
                            ...m,
                            time: mealTime,
                            name: mealName.trim(),
                            ingredients: mealIngredients.trim(),
                            protein: Number(mealProtein) || 0,
                            fat: Number(mealFat) || 0,
                            carbs: Number(mealCarbs) || 0,
                            imageFile: mealImage ?? m.imageFile,
                            imageURL: mealExistingImageURL,
                        }
                        : m
                )
            );
        } else {
            setMeals((prev) => [
                ...prev,
                {
                    id: makeId(),
                    time: mealTime,
                    name: mealName.trim(),
                    ingredients: mealIngredients.trim(),
                    protein: Number(mealProtein) || 0,
                    fat: Number(mealFat) || 0,
                    carbs: Number(mealCarbs) || 0,
                    imageFile: mealImage,
                    imageURL: null,
                },
            ]);
        }
        resetMealForm();
    }

    function removeMeal(mealId: string) {
        setMeals((prev) => prev.filter((m) => m.id !== mealId));
        if (originalMealIds.has(mealId)) {
            setDeletedMealIds((prev) => [...prev, mealId]);
        }
        if (editingMealId === mealId) resetMealForm();
    }

    async function handleSave() {
        setSaving(true);
        setSaveError(null);
        try {
            let templateId = id;

            if (!isEdit) {
                const newRef = await addDoc(collection(db, "dietPlanTemplates"), {
                    name: name.trim() || "Untitled Plan",
                    createdAt: serverTimestamp(),
                });
                templateId = newRef.id;
            }

            let imageURL = existingImageURL;
            if (templateImageFile && templateId) {
                const photoRef = ref(storage, `dietPlanTemplates/${templateId}`);
                await uploadBytes(photoRef, templateImageFile);
                imageURL = await getDownloadURL(photoRef);
            }

            const templateData = {
                name: name.trim() || "Untitled Plan",
                calories: Number(calories) || 0,
                protein: Number(protein) || 0,
                fastingWindow: fastingWindow ? `${fastingWindow}:0` : null,
                netCarbsLimit: Number(netCarbsLimit) || 0,
                hydrationGoal: Number(hydrationGoal) || 0,
                hydrationNote: hydrationNote.trim(),
                prohibitions,
                mealCount: meals.length,
                imageURL: imageURL ?? null,
                updatedAt: serverTimestamp(),
            };

            await setDoc(doc(db, "dietPlanTemplates", templateId!), templateData, {
                merge: true,
            });

            for (const meal of meals) {
                let mealImageURL = meal.imageURL;
                if (meal.imageFile) {
                    const mealPhotoRef = ref(
                        storage,
                        `dietPlanTemplates/${templateId}/meals/${meal.id}`
                    );
                    await uploadBytes(mealPhotoRef, meal.imageFile);
                    mealImageURL = await getDownloadURL(mealPhotoRef);
                }

                await setDoc(
                    doc(db, "dietPlanTemplates", templateId!, "meals", meal.id),
                    {
                        time: meal.time,
                        name: meal.name,
                        ingredients: meal.ingredients,
                        protein: meal.protein,
                        fat: meal.fat,
                        carbs: meal.carbs,
                        imageURL: mealImageURL ?? null,
                    },
                    { merge: true }
                );
            }

            for (const deletedId of deletedMealIds) {
                await deleteDoc(
                    doc(db, "dietPlanTemplates", templateId!, "meals", deletedId)
                );
            }
            setDeletedMealIds([]);

            navigate("/diet-plans");
        } catch (err) {
            console.error("Save template failed:", err);
            setSaveError("Couldn't save this template. Try again.");
        } finally {
            setSaving(false);
        }
    }

    if (loading) {
        return (
            <Layout title="Diet Plan">
                <p style={{ color: "#999" }}>Loading template...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Diet Plan">
            <div className="cdt-header">
                <button className="profile-back-btn" onClick={() => navigate("/diet-plans")}>
                    <i className="bx bx-arrow-back" /> Back to Diet Plan
                </button>
                <div className="cdt-header-actions">
                    <button className="cdt-save-btn" onClick={handleSave} disabled={saving}>
                        <i className="bx bx-save" /> {saving ? "Saving..." : "Save Changes"}
                    </button>
                    <button
                        className="cdt-cancel-btn"
                        onClick={() => navigate("/diet-plans")}
                        disabled={saving}
                    >
                        Cancel
                    </button>
                </div>
            </div>

            {saveError && <div className="cdt-save-error">{saveError}</div>}

            <div className="cdt-macro-row">
                <div className="cdt-macro-card">
                    <i className="bx bx-flame cdt-macro-icon red" />
                    <div className="cdt-macro-text">
                        <input
                            className="cdt-macro-input"
                            value={calories}
                            onChange={(e) => setCalories(e.target.value)}
                            type="text"
                            inputMode="numeric"
                        />
                        <div className="cdt-macro-label">Daily Calories</div>
                    </div>
                </div>
                <div className="cdt-macro-card">
                    <i className="bx bx-dumbbell cdt-macro-icon blue" />
                    <div className="cdt-macro-text">
                        <input
                            className="cdt-macro-input"
                            value={protein}
                            onChange={(e) => setProtein(e.target.value)}
                            type="text"
                            inputMode="numeric"
                        />
                        <div className="cdt-macro-label">Protein (g)</div>
                    </div>
                </div>
                <div className="cdt-macro-card">
                    <i className="bx bx-time cdt-macro-icon cyan" />
                    <div className="cdt-macro-text">
                        <input
                            className="cdt-macro-input"
                            value={fastingWindow}
                            onChange={(e) => setFastingWindow(e.target.value)}
                            type="text"
                            inputMode="numeric"
                        />
                        <div className="cdt-macro-label">Fasting Window (hrs)</div>
                    </div>
                </div>
                <div className="cdt-macro-card">
                    <i className="bx bx-leaf cdt-macro-icon green" />
                    <div className="cdt-macro-text">
                        <input
                            className="cdt-macro-input"
                            value={netCarbsLimit}
                            onChange={(e) => setNetCarbsLimit(e.target.value)}
                            type="text"
                            inputMode="numeric"
                        />
                        <div className="cdt-macro-label">Net Carbs (g)</div>
                    </div>
                </div>
            </div>

            <div className="cdt-layout">
                <div className="cdt-sidebar">
                    <div className="cdt-name-card">
                        <label className="cdt-label">TEMPLATE PHOTO</label>
                        <label className="cdt-template-photo-upload">
                            {templateImageFile ? (
                                <img
                                    src={URL.createObjectURL(templateImageFile)}
                                    alt="Template preview"
                                    className="cdt-template-photo-preview"
                                />
                            ) : existingImageURL ? (
                                <img
                                    src={existingImageURL}
                                    alt="Template preview"
                                    className="cdt-template-photo-preview"
                                />
                            ) : (
                                <>
                                    <i className="bx bx-image-add" />
                                    <span>Upload Photo</span>
                                </>
                            )}
                            <input
                                type="file"
                                accept="image/*"
                                style={{ display: "none" }}
                                onChange={handleTemplatePhotoUpload}
                            />
                        </label>

                        <label className="cdt-label" style={{ marginTop: 12 }}>
                            TEMPLATE NAME
                        </label>
                        <input
                            className="cdt-name-input"
                            placeholder="e.g. Maximum Ketosis"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                        />
                    </div>

                    <div className="cdt-side-card">
                        <div className="cdt-side-title">Hydration Goal</div>
                        <div className="cdt-hydration-row">
                            <input
                                className="cdt-hydration-input"
                                type="number"
                                step="0.1"
                                value={hydrationGoal}
                                onChange={(e) => setHydrationGoal(e.target.value)}
                            />
                            <span>L Daily</span>
                        </div>
                        <input
                            className="cdt-hydration-note"
                            value={hydrationNote}
                            onChange={(e) => setHydrationNote(e.target.value)}
                            placeholder="Include electrolytes (Sodium, Magnesium)"
                        />
                    </div>

                    <div className="cdt-side-card">
                        <div className="cdt-side-title">
                            <i className="bx bx-block" /> Prohibitions
                        </div>
                        {prohibitions.map((p, i) => (
                            <div key={i} className="cdt-prohibition-row">
                                <span>{p}</span>
                                <button onClick={() => removeProhibition(i)}>
                                    <i className="bx bx-x" />
                                </button>
                            </div>
                        ))}
                        <div className="cdt-add-prohibition-row">
                            <input
                                placeholder="Add restriction..."
                                value={newProhibition}
                                onChange={(e) => setNewProhibition(e.target.value)}
                                onKeyDown={(e) => e.key === "Enter" && addProhibition()}
                            />
                            <button onClick={addProhibition}>
                                <i className="bx bx-plus" />
                            </button>
                        </div>
                    </div>
                </div>

                <div className="cdt-main">
                    <div className="cdt-meal-header">
                        <div className="cdt-meal-title">
                            Meal Sequence{" "}
                            <span className="cdt-meal-count-badge">{meals.length}</span>
                        </div>
                    </div>

                    {!showMealForm && (
                        <button className="cdt-add-meal-slot-btn" onClick={openAddMealSlot}>
                            <i className="bx bx-plus-circle" /> Add Meal Slot
                        </button>
                    )}

                    {showMealForm && (
                        <div className="cdt-meal-form-card">
                            <div className="cdt-meal-form-row">
                                <label className="cdt-meal-photo-upload">
                                    {mealImage ? (
                                        <img
                                            src={URL.createObjectURL(mealImage)}
                                            alt="Meal preview"
                                            className="cdt-meal-photo-preview"
                                        />
                                    ) : mealExistingImageURL ? (
                                        <img
                                            src={mealExistingImageURL}
                                            alt="Meal preview"
                                            className="cdt-meal-photo-preview"
                                        />
                                    ) : (
                                        <>
                                            <i className="bx bx-image-add" />
                                            <span>Upload Image</span>
                                        </>
                                    )}
                                    <input
                                        type="file"
                                        accept="image/*"
                                        style={{ display: "none" }}
                                        onChange={handleMealPhotoUpload}
                                    />
                                </label>

                                <div className="cdt-meal-form-fields">
                                    <input
                                        className="cdt-meal-time-input"
                                        placeholder="HH:MM AM/PM"
                                        value={mealTime}
                                        onChange={(e) => setMealTime(e.target.value)}
                                    />
                                    <div className="cdt-meal-name-field">
                                        <label className="cdt-meal-name-label">MEAL NAME</label>
                                        <input
                                            className="cdt-meal-name-input"
                                            placeholder="e.g. Post-Workout Fuel"
                                            value={mealName}
                                            onChange={(e) => setMealName(e.target.value)}
                                        />
                                    </div>
                                </div>
                            </div>

                            <label className="cdt-label" style={{ marginTop: 16 }}>
                                INGREDIENTS &amp; PREPARATION
                            </label>
                            <textarea
                                className="cdt-ingredients-textarea"
                                placeholder="List ingredients and preparation steps..."
                                rows={4}
                                value={mealIngredients}
                                onChange={(e) => setMealIngredients(e.target.value)}
                            />

                            <div className="cdt-meal-macro-row">
                                <div>
                                    <label className="cdt-label">PRO.</label>
                                    <input
                                        className="cdt-meal-macro-input"
                                        type="number"
                                        placeholder="0.0"
                                        value={mealProtein}
                                        onChange={(e) => setMealProtein(e.target.value)}
                                    />
                                </div>
                                <div>
                                    <label className="cdt-label">FAT</label>
                                    <input
                                        className="cdt-meal-macro-input"
                                        type="number"
                                        placeholder="0.0"
                                        value={mealFat}
                                        onChange={(e) => setMealFat(e.target.value)}
                                    />
                                </div>
                                <div>
                                    <label className="cdt-label">CARBS</label>
                                    <input
                                        className="cdt-meal-macro-input"
                                        type="number"
                                        placeholder="0.0"
                                        value={mealCarbs}
                                        onChange={(e) => setMealCarbs(e.target.value)}
                                    />
                                </div>
                            </div>

                            <div className="cdt-meal-form-footer">
                                <button className="cdt-meal-cancel-btn" onClick={resetMealForm}>
                                    Cancel
                                </button>
                                <button
                                    className="cdt-meal-add-btn"
                                    onClick={handleSaveMealToPlan}
                                    disabled={!mealName.trim()}
                                >
                                    {editingMealId ? "Update Meal" : "Add to Plan"}
                                </button>
                            </div>
                        </div>
                    )}

                    {meals.length > 0 && (
                        <div className="cdt-meal-photo-list">
                            {meals.map((m, idx) => (
                                <div key={m.id} className="cdt-meal-photo-card">
                                    <span className="cdt-meal-order-badge">{idx + 1}</span>

                                    <div className="cdt-meal-photo-thumb">
                                        {m.imageFile ? (
                                            <img
                                                src={URL.createObjectURL(m.imageFile)}
                                                alt={m.name}
                                            />
                                        ) : m.imageURL ? (
                                            <img src={m.imageURL} alt={m.name} />
                                        ) : (
                                            <div className="cdt-meal-photo-fallback">
                                                <i className="bx bx-restaurant" />
                                            </div>
                                        )}
                                    </div>

                                    <div className="cdt-meal-photo-body">
                                        <div className="cdt-meal-photo-time">{m.time}</div>
                                        <div className="cdt-meal-photo-name">{m.name}</div>
                                        {m.ingredients && (
                                            <p className="cdt-meal-photo-desc">
                                                {m.ingredients}
                                            </p>
                                        )}
                                    </div>

                                    <div className="cdt-meal-photo-actions">
                                        <button onClick={() => openEditMeal(m)}>
                                            <i className="bx bx-edit" />
                                        </button>
                                        <button onClick={() => removeMeal(m.id)}>
                                            <i className="bx bx-trash" />
                                        </button>
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