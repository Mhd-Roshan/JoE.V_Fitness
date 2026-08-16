import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { FirebaseError } from "firebase/app";
import {
    collection,
    query,
    where,
    getCountFromServer,
    doc,
    writeBatch,
    serverTimestamp,
} from "firebase/firestore";
import { createUserWithEmailAndPassword, signOut } from "firebase/auth";
import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { db, secondaryAuth, storage } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/addTrainer.css";

interface TimeSlot {
    id: string;
    start: string;
    end: string;
}

interface TrainerFormData {
    photoFile: File | null;
    fullName: string;
    email: string;
    phone: string;
    dob: string;
    password: string;
    confirmPassword: string;
    designation: string;
    yearsExperience: string;
    specializations: string[];
    educationBackground: string;
    certBodies: string[];
    certFiles: File[];
    timezone: string;
    availability: Record<string, TimeSlot[]>;
}

const STEPS = [
    { id: 1, label: "Personal Info" },
    { id: 2, label: "Professional Details" },
    { id: 3, label: "Availability" },
    { id: 4, label: "Review" },
];

const ROLE_OPTIONS = [
    "Personal Trainer",
    "Senior Trainer",
    "Yoga Instructor",
    "Nutrition Coach",
    "Rehab Specialist",
];

const CERT_BODY_OPTIONS = ["ISSA", "NASM", "ACE", "Other"];

const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

const TIMEZONE_OPTIONS = [
    "(GMT+5:30) India Standard Time - Kolkata",
    "(GMT-05:00) Eastern Time - New York",
    "(GMT+04:00) Gulf Standard Time - Dubai",
    "(GMT+00:00) Greenwich Mean Time - London",
    "(GMT+08:00) Singapore Standard Time",
];

function makeSlotId() {
    return Math.random().toString(36).slice(2, 9);
}

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
    return Promise.race([
        promise,
        new Promise<T>((_, reject) =>
            setTimeout(() => reject(new Error(`${label} timed out after ${ms / 1000}s`)), ms)
        ),
    ]);
}

// ==============================================================
// 12-HOUR TIME CONVERTER HELPER
// ==============================================================
function convertTo12Hour(time24: string) {
    if (!time24) return "";
    const [hours, minutes] = time24.split(":");
    let h = parseInt(hours, 10);
    const ampm = h >= 12 ? "PM" : "AM";
    h = h % 12 || 12; // Converts 17 to 5, 0 to 12, etc.
    return `${h.toString().padStart(2, "0")}:${minutes} ${ampm}`;
}

// ==============================================================
// IMAGE COMPRESSION HELPER FUNCTION (Native HTML5 Canvas)
// ==============================================================
async function compressImage(file: File): Promise<File> {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = (event) => {
            const img = new Image();
            img.src = event.target?.result as string;
            img.onload = () => {
                const canvas = document.createElement("canvas");
                const MAX_WIDTH = 800;
                const MAX_HEIGHT = 800;
                let width = img.width;
                let height = img.height;

                if (width > height) {
                    if (width > MAX_WIDTH) {
                        height = Math.round(height * (MAX_WIDTH / width));
                        width = MAX_WIDTH;
                    }
                } else {
                    if (height > MAX_HEIGHT) {
                        width = Math.round(width * (MAX_HEIGHT / height));
                        height = MAX_HEIGHT;
                    }
                }

                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext("2d");

                if (!ctx) return reject(new Error("Canvas context failed"));

                ctx.fillStyle = "#FFFFFF";
                ctx.fillRect(0, 0, width, height);
                ctx.drawImage(img, 0, 0, width, height);

                canvas.toBlob(
                    (blob) => {
                        if (blob) {
                            const newFileName = file.name.replace(/\.[^/.]+$/, ".jpg");
                            const newFile = new File([blob], newFileName, {
                                type: "image/jpeg",
                                lastModified: Date.now(),
                            });
                            resolve(newFile);
                        } else {
                            reject(new Error("Canvas to Blob failed"));
                        }
                    },
                    "image/jpeg",
                    0.7
                );
            };
            img.onerror = (error) => reject(error);
        };
        reader.onerror = (error) => reject(error);
    });
}
// ==============================================================

export default function AddTrainer() {
    const navigate = useNavigate();
    const [step, setStep] = useState(1);
    const [activeTrainerCount, setActiveTrainerCount] = useState<number | null>(null);
    const [customSpecInput, setCustomSpecInput] = useState("");
    const [showCustomSpecInput, setShowCustomSpecInput] = useState(false);
    const [confirmedOnboarding, setConfirmedOnboarding] = useState(false);
    const [submitting, setSubmitting] = useState(false);
    const [submitError, setSubmitError] = useState<string | null>(null);
    const [showPassword, setShowPassword] = useState(false);
    const [isCompressing, setIsCompressing] = useState(false);

    const [form, setForm] = useState<TrainerFormData>({
        photoFile: null,
        fullName: "",
        email: "",
        phone: "",
        dob: "",
        password: "",
        confirmPassword: "",
        designation: "",
        yearsExperience: "",
        specializations: [],
        educationBackground: "",
        certBodies: [],
        certFiles: [],
        timezone: TIMEZONE_OPTIONS[0],
        availability: DAYS.reduce((acc, day) => ({ ...acc, [day]: [] }), {} as Record<string, TimeSlot[]>),
    });
    const [errors, setErrors] = useState<Partial<Record<keyof TrainerFormData, string>>>({});

    useEffect(() => {
        async function fetchTrainerCount() {
            try {
                const snap = await getCountFromServer(
                    query(collection(db, "users"), where("role", "==", "trainer"))
                );
                setActiveTrainerCount(snap.data().count);
            } catch (err) {
                console.error("Error fetching trainer count:", err);
            }
        }
        fetchTrainerCount();
    }, []);

    function update<K extends keyof TrainerFormData>(
        key: K,
        value: TrainerFormData[K]
    ) {
        setForm((prev) => ({ ...prev, [key]: value }));
        if (errors[key]) {
            setErrors((prev) => ({ ...prev, [key]: undefined }));
        }
    }

    async function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
        const file = e.target.files?.[0] ?? null;
        if (!file) {
            update("photoFile", null);
            return;
        }

        setIsCompressing(true);
        try {
            const compressedFile = await compressImage(file);
            update("photoFile", compressedFile);
        } catch (error) {
            console.error("Image compression failed:", error);
            update("photoFile", file);
        } finally {
            setIsCompressing(false);
        }
    }

    function toggleSpecialization(spec: string) {
        setForm((prev) => {
            const has = prev.specializations.includes(spec);
            return {
                ...prev,
                specializations: has
                    ? prev.specializations.filter((s) => s !== spec)
                    : [...prev.specializations, spec],
            };
        });
        if (errors.specializations) {
            setErrors((prev) => ({ ...prev, specializations: undefined }));
        }
    }

    function addCustomSpecialization() {
        const trimmed = customSpecInput.trim();
        if (!trimmed) return;
        if (!form.specializations.includes(trimmed)) {
            update("specializations", [...form.specializations, trimmed]);
        }
        setCustomSpecInput("");
        setShowCustomSpecInput(false);
    }

    function toggleCertBody(body: string) {
        setForm((prev) => {
            const has = prev.certBodies.includes(body);
            return {
                ...prev,
                certBodies: has
                    ? prev.certBodies.filter((b) => b !== body)
                    : [...prev.certBodies, body],
            };
        });
        if (errors.certBodies) {
            setErrors((prev) => ({ ...prev, certBodies: undefined }));
        }
    }

    function handleCertFilesChange(e: React.ChangeEvent<HTMLInputElement>) {
        const files = e.target.files ? Array.from(e.target.files) : [];
        update("certFiles", [...form.certFiles, ...files]);
    }

    function removeCertFile(name: string) {
        update(
            "certFiles",
            form.certFiles.filter((f) => f.name !== name)
        );
    }

    function addSlot(day: string) {
        setForm((prev) => ({
            ...prev,
            availability: {
                ...prev.availability,
                [day]: [
                    ...prev.availability[day],
                    { id: makeSlotId(), start: "09:00", end: "17:00" },
                ],
            },
        }));
        if (errors.availability) {
            setErrors((prev) => ({ ...prev, availability: undefined }));
        }
    }

    function removeSlot(day: string, slotId: string) {
        setForm((prev) => ({
            ...prev,
            availability: {
                ...prev.availability,
                [day]: prev.availability[day].filter((s) => s.id !== slotId),
            },
        }));
    }

    function updateSlot(day: string, slotId: string, field: "start" | "end", value: string) {
        setForm((prev) => ({
            ...prev,
            availability: {
                ...prev.availability,
                [day]: prev.availability[day].map((s) =>
                    s.id === slotId ? { ...s, [field]: value } : s
                ),
            },
        }));
    }

    function slotHours(slot: TimeSlot): number {
        const [sh, sm] = slot.start.split(":").map(Number);
        const [eh, em] = slot.end.split(":").map(Number);
        const mins = eh * 60 + em - (sh * 60 + sm);
        return mins > 0 ? mins / 60 : 0;
    }

    function formatDaySlots(day: string): string {
        const slots = form.availability[day];
        if (slots.length === 0) return "";
        return slots.map((s) => `${convertTo12Hour(s.start)} - ${convertTo12Hour(s.end)}`).join(", ");
    }

    function validateStep1(): boolean {
        const newErrors: Partial<Record<keyof TrainerFormData, string>> = {};

        if (!form.fullName.trim()) newErrors.fullName = "Full name is required.";
        if (!form.email.trim()) {
            newErrors.email = "Email address is required.";
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
            newErrors.email = "Enter a valid email address.";
        }
        if (!form.phone.trim()) {
            newErrors.phone = "Phone number is required.";
        } else if (!/^[6-9]\d{9}$/.test(form.phone)) {
            newErrors.phone = "Enter a valid 10-digit Indian mobile number.";
        }
        if (!form.dob) newErrors.dob = "Date of birth is required.";

        if (!form.password) {
            newErrors.password = "Set a login password for this trainer.";
        } else if (form.password.length < 8) {
            newErrors.password = "Password must be at least 8 characters.";
        }
        if (!form.confirmPassword) {
            newErrors.confirmPassword = "Confirm the password.";
        } else if (form.confirmPassword !== form.password) {
            newErrors.confirmPassword = "Passwords don't match.";
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    function validateStep2(): boolean {
        const newErrors: Partial<Record<keyof TrainerFormData, string>> = {};

        if (!form.designation) newErrors.designation = "Select a role.";
        if (!form.yearsExperience.trim()) {
            newErrors.yearsExperience = "Years of experience is required.";
        } else if (
            Number.isNaN(Number(form.yearsExperience)) ||
            Number(form.yearsExperience) < 0
        ) {
            newErrors.yearsExperience = "Enter a valid number.";
        }
        if (form.specializations.length === 0) {
            newErrors.specializations = "Add at least one specialization.";
        }
        if (!form.educationBackground.trim()) {
            newErrors.educationBackground = "This field is required.";
        }
        if (form.certBodies.length === 0 && form.certFiles.length === 0) {
            newErrors.certBodies = "Add at least one certification.";
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    function validateStep3(): boolean {
        const newErrors: Partial<Record<keyof TrainerFormData, string>> = {};

        const hasAnySlot = DAYS.some((day) => form.availability[day].length > 0);
        if (!hasAnySlot) {
            newErrors.availability = "Set at least one available time slot.";
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    }

    function handleContinue() {
        if (step === 1 && !validateStep1()) return;
        if (step === 2 && !validateStep2()) return;
        if (step === 3 && !validateStep3()) return;

        if (step < 4) {
            setStep((s) => s + 1);
        }
    }

    function handleBack() {
        if (step === 1) {
            navigate("/trainers");
        } else {
            setErrors({});
            setStep((s) => s - 1);
        }
    }

    async function handleCompleteOnboarding() {
        if (!confirmedOnboarding) return;
        setSubmitting(true);
        setSubmitError(null);

        try {
            console.log("[onboarding] creating auth account...");

            const credential = await withTimeout(
                createUserWithEmailAndPassword(secondaryAuth, form.email, form.password),
                15000,
                "Account creation"
            );
            const trainerId = credential.user.uid;
            console.log("[onboarding] account created:", trainerId);

            await signOut(secondaryAuth);
            console.log("[onboarding] secondary session cleared");

            let photoURL: string | null = null;
            if (form.photoFile) {
                console.log("[onboarding] uploading photo...");
                const photoRef = ref(storage, `trainerPhotos/${trainerId}`);
                await withTimeout(uploadBytes(photoRef, form.photoFile), 20000, "Photo upload");
                photoURL = await withTimeout(
                    getDownloadURL(photoRef),
                    10000,
                    "Getting photo URL"
                );
                console.log("[onboarding] photo uploaded:", photoURL);
            }

            console.log("[onboarding] writing Firestore docs...");
            const batch = writeBatch(db);

            batch.set(doc(db, "users", trainerId), {
                role: "trainer",
                fullName: form.fullName,
                email: form.email,
                phone: `+91${form.phone}`,
                dob: form.dob,
                photoURL: photoURL ?? null,
                createdAt: serverTimestamp(),
            });

            batch.set(doc(db, "trainers", trainerId), {
                trainerId,
                fullName: form.fullName,
                photoURL: photoURL ?? null,
                designation: form.designation,
                yearsExperience: Number(form.yearsExperience) || 0,
                specializations: form.specializations,
                bio: form.educationBackground,
                certifications: [
                    ...form.certBodies,
                    ...form.certFiles.map((f) => f.name),
                ],
                status: "active",
                rating: 0,
                ratingCount: 0,
                createdAt: serverTimestamp(),
            });

            DAYS.forEach((day) => {
                form.availability[day].forEach((slot) => {
                    const availRef = doc(
                        collection(db, "trainers", trainerId, "availability")
                    );
                    batch.set(availRef, {
                        dayOfWeek: day,
                        startTime: convertTo12Hour(slot.start),
                        endTime: convertTo12Hour(slot.end),
                        timezone: form.timezone,
                    });
                });
            });

            await withTimeout(batch.commit(), 15000, "Saving trainer");
            console.log("[onboarding] done, navigating...");
            navigate("/trainers");
        } catch (err) {
            console.error("Onboarding submission failed:", err);
            if (err instanceof FirebaseError) {
                if (err.code === "auth/email-already-in-use") {
                    setSubmitError("This email is already registered to another account.");
                } else if (err.code === "auth/weak-password") {
                    setSubmitError("Password is too weak — use at least 8 characters.");
                } else {
                    setSubmitError(
                        "Couldn't create this trainer. Check your connection and try again."
                    );
                }
            } else if (err instanceof Error) {
                setSubmitError(err.message);
            } else {
                setSubmitError(
                    "Couldn't create this trainer. Check your connection and try again."
                );
            }
        } finally {
            setSubmitting(false);
        }
    }

    const completionFields = [
        form.fullName,
        form.email,
        form.phone,
        form.dob,
        form.designation,
        form.yearsExperience,
        form.specializations.length > 0 ? "x" : "",
        form.educationBackground,
    ];
    const completionPct = Math.round(
        (completionFields.filter((f) => f.trim?.() !== "" && f).length /
            completionFields.length) *
        100
    );

    const totalWeeklyHours = DAYS.reduce(
        (sum, day) => sum + form.availability[day].reduce((s, slot) => s + slotHours(slot), 0),
        0
    );

    return (
        <Layout title="Add New Trainers">
            <button className="profile-back-btn" onClick={() => navigate("/trainers")}>
                <i className="bx bx-arrow-back" /> Back to Trainer
            </button>

            <div className="step-indicator-card">
                {STEPS.map((s, i) => (
                    <div key={s.id} className="step-indicator-item">
                        <div
                            className={`step-indicator-node ${s.id === step ? "active" : s.id < step ? "done" : ""
                                }`}
                        >
                            {s.id < step ? <i className="bx bx-check" /> : s.id}
                        </div>
                        <span
                            className={`step-indicator-label ${s.id === step ? "active" : ""}`}
                        >
                            {s.label}
                        </span>
                        {i < STEPS.length - 1 && <div className="step-indicator-line" />}
                    </div>
                ))}
            </div>

            <div className="add-trainer-layout">
                <div className="add-trainer-form-panel">
                    {step === 1 && (
                        <>
                            <div className="form-panel-header">
                                <div className="form-panel-title">Step 1: Personal Information</div>
                                <div className="form-panel-subtitle">
                                    Enter the fundamental contact details and identification for the
                                    new trainer.
                                </div>
                            </div>

                            <div className="form-field">
                                <label className="form-label">PROFILE PHOTO</label>

                                {/* UPDATED: Removable Dropzone */}
                                <div className="photo-dropzone" style={{ padding: form.photoFile ? "20px" : undefined }}>
                                    {form.photoFile && !isCompressing ? (
                                        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "10px", width: "100%" }}>
                                            <img
                                                src={URL.createObjectURL(form.photoFile)}
                                                alt="Preview"
                                                style={{ width: "80px", height: "80px", borderRadius: "50%", objectFit: "cover" }}
                                            />
                                            <span style={{ fontSize: "0.9rem", color: "#333", fontWeight: 500 }}>
                                                {form.photoFile.name}
                                            </span>
                                            <button
                                                type="button"
                                                onClick={() => update("photoFile", null)}
                                                style={{
                                                    padding: "6px 16px",
                                                    backgroundColor: "#fee2e2",
                                                    color: "#ef4444",
                                                    border: "none",
                                                    borderRadius: "50px",
                                                    cursor: "pointer",
                                                    fontSize: "0.85rem",
                                                    fontWeight: 600,
                                                    display: "flex",
                                                    alignItems: "center",
                                                    gap: "6px",
                                                    marginTop: "5px"
                                                }}
                                            >
                                                <i className="bx bx-trash" /> Remove Photo
                                            </button>
                                        </div>
                                    ) : (
                                        <label style={{ display: "flex", flexDirection: "column", alignItems: "center", width: "100%", cursor: "pointer" }}>
                                            <i className="bx bx-user-circle photo-dropzone-icon" />
                                            <div className="photo-dropzone-text">
                                                {isCompressing
                                                    ? "Compressing image..."
                                                    : "CLICK TO UPLOAD OR DRAG AND DROP"}
                                            </div>
                                            <div className="photo-dropzone-hint">
                                                SVG, PNG, JPG OR GIF (Images are auto-compressed)
                                            </div>
                                            <span className="photo-choose-btn">
                                                <i className="bx bx-upload" /> Choose File
                                            </span>
                                            <input
                                                type="file"
                                                accept="image/*"
                                                onChange={handlePhotoChange}
                                                style={{ display: "none" }}
                                                disabled={isCompressing}
                                                onClick={(e) => {
                                                    // Allow re-selecting the same file if removed
                                                    (e.target as HTMLInputElement).value = '';
                                                }}
                                            />
                                        </label>
                                    )}
                                </div>
                            </div>

                            <div className="form-field">
                                <label className="form-label">FULL NAME</label>
                                <div className="input-with-icon">
                                    <i className="bx bx-user input-icon" />
                                    <input
                                        className={`form-input ${errors.fullName ? "input-error" : ""}`}
                                        placeholder="e.g. Marcus Thorne"
                                        value={form.fullName}
                                        onChange={(e) => update("fullName", e.target.value)}
                                    />
                                </div>
                                {errors.fullName && (
                                    <span className="form-error-text">{errors.fullName}</span>
                                )}
                            </div>

                            <div className="form-field">
                                <label className="form-label">EMAIL ADDRESS</label>
                                <div className="input-with-icon">
                                    <i className="bx bx-envelope input-icon" />
                                    <input
                                        className={`form-input ${errors.email ? "input-error" : ""}`}
                                        type="email"
                                        placeholder="m.thorne@ironpulse.com"
                                        value={form.email}
                                        onChange={(e) => update("email", e.target.value)}
                                    />
                                </div>
                                {errors.email && (
                                    <span className="form-error-text">{errors.email}</span>
                                )}
                            </div>

                            <div className="form-field">
                                <label className="form-label">PHONE NUMBER</label>
                                <div className="phone-input-group">
                                    <span className="phone-country-code">
                                        <i className="bx bx-flag" /> +91
                                    </span>
                                    <input
                                        className={`form-input-phone ${errors.phone ? "input-error" : ""}`}
                                        type="tel"
                                        placeholder="98765 43210"
                                        value={form.phone}
                                        maxLength={10}
                                        onChange={(e) => {
                                            const digitsOnly = e.target.value
                                                .replace(/\D/g, "")
                                                .slice(0, 10);
                                            update("phone", digitsOnly);
                                        }}
                                    />
                                </div>
                                {errors.phone && (
                                    <span className="form-error-text">{errors.phone}</span>
                                )}
                            </div>

                            <div className="form-field">
                                <label className="form-label">DATE OF BIRTH</label>
                                <div className="input-with-icon">
                                    <i className="bx bx-calendar input-icon" />
                                    <input
                                        className={`form-input ${errors.dob ? "input-error" : ""}`}
                                        type="date"
                                        value={form.dob}
                                        onChange={(e) => update("dob", e.target.value)}
                                    />
                                </div>
                                {errors.dob && (
                                    <span className="form-error-text">{errors.dob}</span>
                                )}
                            </div>

                            <div className="form-field">
                                <label className="form-label">LOGIN PASSWORD</label>
                                <div className="input-with-icon">
                                    <i className="bx bx-lock-alt input-icon" />
                                    <input
                                        className={`form-input ${errors.password ? "input-error" : ""}`}
                                        type={showPassword ? "text" : "password"}
                                        placeholder="Minimum 8 characters"
                                        value={form.password}
                                        onChange={(e) => update("password", e.target.value)}
                                        style={{ paddingRight: 44 }}
                                    />
                                    <button
                                        type="button"
                                        className="password-toggle-btn"
                                        onClick={() => setShowPassword((s) => !s)}
                                        tabIndex={-1}
                                    >
                                        <i className={`bx ${showPassword ? "bx-hide" : "bx-show"}`} />
                                    </button>
                                </div>
                                {errors.password && (
                                    <span className="form-error-text">{errors.password}</span>
                                )}
                                <span className="password-hint-text">
                                    This is what{" "}
                                    {form.fullName ? form.fullName.split(" ")[0] : "the trainer"} will
                                    use to sign in to the Trainer App along with their email.
                                </span>
                            </div>

                            <div className="form-field">
                                <label className="form-label">CONFIRM PASSWORD</label>
                                <div className="input-with-icon">
                                    <i className="bx bx-lock-alt input-icon" />
                                    <input
                                        className={`form-input ${errors.confirmPassword ? "input-error" : ""
                                            }`}
                                        type={showPassword ? "text" : "password"}
                                        placeholder="Re-enter password"
                                        value={form.confirmPassword}
                                        onChange={(e) => update("confirmPassword", e.target.value)}
                                    />
                                </div>
                                {errors.confirmPassword && (
                                    <span className="form-error-text">
                                        {errors.confirmPassword}
                                    </span>
                                )}
                            </div>
                        </>
                    )}

                    {step === 2 && (
                        <>
                            <div className="form-panel-header">
                                <div className="form-panel-title">Step 2: Professional Details</div>
                                <div className="form-panel-subtitle">
                                    Provide credentials, specialties, and experience for the new trainer.
                                </div>
                            </div>

                            <div className="form-row">
                                <div className="form-field" style={{ flex: 1 }}>
                                    <label className="form-label">ROLE / DESIGNATION</label>
                                    <select
                                        className={`form-select ${errors.designation ? "input-error" : ""}`}
                                        value={form.designation}
                                        onChange={(e) => update("designation", e.target.value)}
                                    >
                                        <option value="">Select a role...</option>
                                        {ROLE_OPTIONS.map((role) => (
                                            <option key={role} value={role}>
                                                {role}
                                            </option>
                                        ))}
                                    </select>
                                    {errors.designation && (
                                        <span className="form-error-text">{errors.designation}</span>
                                    )}
                                </div>

                                <div className="form-field" style={{ flex: 1 }}>
                                    <label className="form-label">YEARS OF EXPERIENCE</label>
                                    <input
                                        className={`form-input-plain ${errors.yearsExperience ? "input-error" : ""}`}
                                        type="number"
                                        min={0}
                                        placeholder="e.g. 5"
                                        value={form.yearsExperience}
                                        onChange={(e) => update("yearsExperience", e.target.value)}
                                    />
                                    {errors.yearsExperience && (
                                        <span className="form-error-text">{errors.yearsExperience}</span>
                                    )}
                                </div>
                            </div>

                            <div className="form-field">
                                <label className="form-label">SPECIALIZATIONS / WORKOUTS</label>
                                <div className="chip-row">
                                    {form.specializations.map((spec) => (
                                        <button
                                            type="button"
                                            key={spec}
                                            className="spec-chip selected"
                                            onClick={() => toggleSpecialization(spec)}
                                        >
                                            {spec} <i className="bx bx-x" />
                                        </button>
                                    ))}

                                    {showCustomSpecInput ? (
                                        <div className="spec-chip-input-wrap">
                                            <input
                                                autoFocus
                                                className="spec-chip-input"
                                                placeholder="Type and press Enter..."
                                                value={customSpecInput}
                                                onChange={(e) => setCustomSpecInput(e.target.value)}
                                                onKeyDown={(e) => {
                                                    if (e.key === "Enter") addCustomSpecialization();
                                                    if (e.key === "Escape") setShowCustomSpecInput(false);
                                                }}
                                                onBlur={addCustomSpecialization}
                                            />
                                        </div>
                                    ) : (
                                        <button
                                            type="button"
                                            className="spec-chip-add"
                                            onClick={() => setShowCustomSpecInput(true)}
                                        >
                                            <i className="bx bx-plus" /> Add Specialization
                                        </button>
                                    )}
                                </div>
                                {errors.specializations && (
                                    <span className="form-error-text">{errors.specializations}</span>
                                )}
                            </div>

                            <div className="form-field">
                                <label className="form-label">
                                    EDUCATION / PROFESSIONAL BACKGROUND
                                </label>
                                <textarea
                                    className={`form-textarea ${errors.educationBackground ? "input-error" : ""
                                        }`}
                                    placeholder="Detail the academic background and relevant past experience..."
                                    value={form.educationBackground}
                                    onChange={(e) => update("educationBackground", e.target.value)}
                                    rows={4}
                                />
                                {errors.educationBackground && (
                                    <span className="form-error-text">
                                        {errors.educationBackground}
                                    </span>
                                )}
                            </div>

                            <div className="form-field">
                                <div className="cert-upload-header">
                                    <label className="form-label" style={{ marginBottom: 0 }}>
                                        CERTIFICATION VERIFICATION
                                    </label>
                                    <span className="cert-upload-hint">
                                        Accepted: ISSA, NASM, ACE, ACSM (PDF/JPG)
                                    </span>
                                </div>

                                <label className="cert-dropzone">
                                    <i className="bx bx-cloud-upload cert-dropzone-icon" />
                                    <div className="cert-dropzone-text">
                                        Click to upload or drag and drop
                                    </div>
                                    <div className="cert-dropzone-hint">Maximum file size 10MB</div>
                                    <span className="cert-browse-btn">Browse Files</span>
                                    <input
                                        type="file"
                                        accept=".pdf,.jpg,.jpeg,.png"
                                        multiple
                                        onChange={handleCertFilesChange}
                                        style={{ display: "none" }}
                                    />
                                </label>

                                {form.certFiles.length > 0 && (
                                    <div className="cert-file-list">
                                        {form.certFiles.map((f) => (
                                            <span key={f.name} className="cert-file-pill">
                                                {f.name}
                                                <i
                                                    className="bx bx-x"
                                                    onClick={() => removeCertFile(f.name)}
                                                />
                                            </span>
                                        ))}
                                    </div>
                                )}

                                <div className="cert-body-chips">
                                    {CERT_BODY_OPTIONS.map((body) => (
                                        <button
                                            type="button"
                                            key={body}
                                            className={`cert-body-chip ${form.certBodies.includes(body) ? "selected" : ""
                                                }`}
                                            onClick={() => toggleCertBody(body)}
                                        >
                                            {body}
                                        </button>
                                    ))}
                                </div>
                                {errors.certBodies && (
                                    <span className="form-error-text">{errors.certBodies}</span>
                                )}
                            </div>
                        </>
                    )}

                    {step === 3 && (
                        <>
                            <div className="form-panel-header">
                                <div className="form-panel-title">Step 3: Define Work Schedule</div>
                                <div className="form-panel-subtitle">
                                    Set the recurring weekly hours for {form.fullName || "this trainer"}.
                                    These slots will be open for client bookings.
                                </div>
                            </div>

                            <div className="timezone-row">
                                <i className="bx bx-globe timezone-icon" />
                                <div className="timezone-field">
                                    <label className="form-label" style={{ marginBottom: 4 }}>
                                        DEFAULT TIMEZONE
                                    </label>
                                    <select
                                        className="timezone-select"
                                        value={form.timezone}
                                        onChange={(e) => update("timezone", e.target.value)}
                                    >
                                        {TIMEZONE_OPTIONS.map((tz) => (
                                            <option key={tz} value={tz}>
                                                {tz}
                                            </option>
                                        ))}
                                    </select>
                                </div>
                            </div>

                            <div className="availability-block">
                                <div className="availability-heading">WEEKLY SCHEDULE</div>

                                {DAYS.map((day) => (
                                    <div key={day} className="day-row">
                                        <div className="day-row-label">
                                            <span className="day-badge">
                                                {day.slice(0, 2).toUpperCase()}
                                            </span>
                                            <span className="day-name">{day}</span>
                                        </div>

                                        <div className="day-row-slots">
                                            {form.availability[day].length === 0 ? (
                                                <span className="day-row-empty">
                                                    No availability set for this day
                                                </span>
                                            ) : (
                                                form.availability[day].map((slot) => (
                                                    <div key={slot.id} className="slot-row">
                                                        <div className="slot-time-group">
                                                            <input
                                                                type="time"
                                                                className="slot-time-input"
                                                                value={slot.start}
                                                                onChange={(e) =>
                                                                    updateSlot(
                                                                        day,
                                                                        slot.id,
                                                                        "start",
                                                                        e.target.value
                                                                    )
                                                                }
                                                            />
                                                            <span className="slot-to">to</span>
                                                            <input
                                                                type="time"
                                                                className="slot-time-input"
                                                                value={slot.end}
                                                                onChange={(e) =>
                                                                    updateSlot(
                                                                        day,
                                                                        slot.id,
                                                                        "end",
                                                                        e.target.value
                                                                    )
                                                                }
                                                            />
                                                        </div>
                                                        <button
                                                            type="button"
                                                            className="slot-remove-btn"
                                                            onClick={() => removeSlot(day, slot.id)}
                                                        >
                                                            <i className="bx bx-trash" />
                                                        </button>
                                                    </div>
                                                ))
                                            )}

                                            <button
                                                type="button"
                                                className="add-slot-btn"
                                                onClick={() => addSlot(day)}
                                            >
                                                <i className="bx bx-plus" /> Add Slot
                                            </button>
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {errors.availability && (
                                <span className="form-error-text">{errors.availability}</span>
                            )}
                        </>
                    )}

                    {step === 4 && (
                        <>
                            <div className="review-card">
                                <div className="review-card-header">
                                    <div className="review-card-title">
                                        <i className="bx bx-user" /> Personal Information
                                    </div>
                                    {/* UPDATED: Pill-shaped Edit Button */}
                                    <button
                                        type="button"
                                        className="edit-section-btn"
                                        onClick={() => setStep(1)}
                                        style={{
                                            borderRadius: "50px",
                                            padding: "6px 16px",
                                            backgroundColor: "#e2e8f0",
                                            color: "#1e293b",
                                            border: "none",
                                            fontSize: "0.85rem",
                                            fontWeight: 600,
                                            cursor: "pointer",
                                            display: "inline-flex",
                                            alignItems: "center",
                                            gap: "6px"
                                        }}
                                    >
                                        <i className="bx bx-pencil" /> Edit Section
                                    </button>
                                </div>
                                <div className="review-personal-row">
                                    <div className="review-photo-frame">
                                        {form.photoFile ? (
                                            <img
                                                src={URL.createObjectURL(form.photoFile)}
                                                alt={form.fullName}
                                                className="review-photo-img"
                                            />
                                        ) : (
                                            <div className="review-photo-fallback">
                                                {form.fullName
                                                    ? form.fullName
                                                        .split(" ")
                                                        .map((p) => p[0])
                                                        .join("")
                                                        .slice(0, 2)
                                                        .toUpperCase()
                                                    : "—"}
                                            </div>
                                        )}
                                    </div>
                                    <div className="review-personal-name-block">
                                        <div className="review-personal-name">
                                            {form.fullName || "Unnamed Trainer"}
                                        </div>
                                        <div className="review-personal-role">
                                            {form.designation
                                                ? form.designation.toUpperCase()
                                                : "ROLE NOT SET"}
                                        </div>
                                    </div>
                                    <div className="review-contact-list">
                                        <div className="review-contact-row">
                                            <i className="bx bx-envelope" />
                                            {form.email || "—"}
                                        </div>
                                        <div className="review-contact-row">
                                            <i className="bx bx-phone" />
                                            {form.phone ? `+91 ${form.phone}` : "—"}
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="review-card">
                                <div className="review-card-header">
                                    <div className="review-card-title">
                                        <i className="bx bx-medal" /> Professional Experience
                                    </div>
                                    {/* UPDATED: Pill-shaped Edit Button */}
                                    <button
                                        type="button"
                                        className="edit-section-btn"
                                        onClick={() => setStep(2)}
                                        style={{
                                            borderRadius: "50px",
                                            padding: "6px 16px",
                                            backgroundColor: "#e2e8f0",
                                            color: "#1e293b",
                                            border: "none",
                                            fontSize: "0.85rem",
                                            fontWeight: 600,
                                            cursor: "pointer",
                                            display: "inline-flex",
                                            alignItems: "center",
                                            gap: "6px"
                                        }}
                                    >
                                        <i className="bx bx-pencil" /> Edit Section
                                    </button>
                                </div>

                                <div className="review-two-col">
                                    <div>
                                        <div className="review-subheading">SPECIALIZATIONS</div>
                                        <div className="review-spec-pills">
                                            {form.specializations.length > 0 ? (
                                                form.specializations.map((s) => (
                                                    <span key={s} className="review-spec-pill">
                                                        {s.toUpperCase()}
                                                    </span>
                                                ))
                                            ) : (
                                                <span className="review-empty">None selected</span>
                                            )}
                                        </div>

                                        <div className="review-subheading" style={{ marginTop: 16 }}>
                                            EXPERIENCE
                                        </div>
                                        <div className="review-experience-text">
                                            {form.yearsExperience
                                                ? `${form.yearsExperience} Year${form.yearsExperience === "1" ? "" : "s"
                                                } Experience`
                                                : "Not specified"}
                                            {form.educationBackground
                                                ? ` — ${form.educationBackground}`
                                                : ""}
                                        </div>
                                    </div>

                                    <div>
                                        <div className="review-subheading">CERTIFICATIONS</div>
                                        {form.certBodies.length > 0 || form.certFiles.length > 0 ? (
                                            <div className="review-cert-list">
                                                {form.certBodies.map((c) => (
                                                    <div key={c} className="review-cert-item">
                                                        <i className="bx bx-check-circle" /> {c}
                                                    </div>
                                                ))}
                                                {form.certFiles.map((f) => (
                                                    <div key={f.name} className="review-cert-item">
                                                        <i className="bx bx-check-circle" /> {f.name}
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <span className="review-empty">None added</span>
                                        )}
                                    </div>
                                </div>
                            </div>

                            <div className="review-card">
                                <div className="review-card-header">
                                    <div className="review-card-title">
                                        <i className="bx bx-calendar" /> Weekly Availability
                                    </div>
                                    {/* UPDATED: Pill-shaped Edit Button */}
                                    <button
                                        type="button"
                                        className="edit-section-btn"
                                        onClick={() => setStep(3)}
                                        style={{
                                            borderRadius: "50px",
                                            padding: "6px 16px",
                                            backgroundColor: "#e2e8f0",
                                            color: "#1e293b",
                                            border: "none",
                                            fontSize: "0.85rem",
                                            fontWeight: 600,
                                            cursor: "pointer",
                                            display: "inline-flex",
                                            alignItems: "center",
                                            gap: "6px"
                                        }}
                                    >
                                        <i className="bx bx-pencil" /> Edit Section
                                    </button>
                                </div>

                                <div className="review-day-grid">
                                    {DAYS.map((day) => {
                                        const hasSlots = form.availability[day].length > 0;
                                        return (
                                            <div
                                                key={day}
                                                className={`review-day-cell ${!hasSlots ? "off" : ""}`}
                                            >
                                                <div className="review-day-label">
                                                    {day.toUpperCase()}
                                                </div>
                                                <div className="review-day-time">
                                                    {hasSlots ? formatDaySlots(day) : "OFF"}
                                                </div>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        </>
                    )}

                    {step < 4 && (
                        <div className="form-footer">
                            <button className="form-btn-cancel" onClick={handleBack}>
                                <i className="bx bx-x" />{" "}
                                {step === 1 ? "Cancel" : "Back to Step " + (step - 1)}
                            </button>
                            <button className="form-btn-continue" onClick={handleContinue}>
                                Continue to Step {step + 1} <i className="bx bx-right-arrow-alt" />
                            </button>
                        </div>
                    )}
                </div>

                <div className="add-trainer-sidebar">
                    {step === 1 && (
                        <>
                            <div className="tip-card">
                                <div className="tip-card-header">
                                    <i className="bx bx-info-circle" />
                                    <span>Onboarding Tip</span>
                                </div>
                                <p className="tip-card-text">
                                    Ensure the trainer's email is a professional address. This will be
                                    used for their login credentials and all automated session
                                    notifications.
                                </p>
                            </div>

                            <div className="network-status-card">
                                <div className="network-status-title">Network Status</div>
                                <div className="network-status-row">
                                    <span className="network-status-label">ACTIVE TRAINERS</span>
                                    <span className="network-status-value">
                                        {activeTrainerCount ?? "..."}
                                    </span>
                                </div>
                                <div className="network-status-note">
                                    85% Capacity filled across all regional facilities.
                                </div>
                            </div>
                        </>
                    )}

                    {step === 2 && (
                        <>
                            <div className="tip-card">
                                <div className="tip-card-header">
                                    <i className="bx bx-info-circle" />
                                    <span>Onboarding Tip</span>
                                </div>
                                <p className="tip-card-text">
                                    Certification Verification: Uploading clear copies of valid
                                    certifications speeds up the background verification process by
                                    48 hours.
                                </p>
                            </div>

                            <div className="draft-profile-card">
                                <div className="draft-profile-top">
                                    <div className="draft-profile-avatar">
                                        {form.fullName
                                            ? form.fullName
                                                .split(" ")
                                                .map((p) => p[0])
                                                .join("")
                                                .slice(0, 2)
                                                .toUpperCase()
                                            : "—"}
                                    </div>
                                    <div>
                                        <div className="draft-profile-title">Draft Profile</div>
                                        <div className="draft-profile-completion">
                                            Profile completion:{" "}
                                            <span className="draft-profile-pct">{completionPct}%</span>
                                        </div>
                                        <div className="draft-progress-track">
                                            <div
                                                className="draft-progress-fill"
                                                style={{ width: `${completionPct}%` }}
                                            />
                                        </div>
                                    </div>
                                </div>

                                <div className="draft-profile-divider" />

                                <div className="draft-profile-row">
                                    <span className="draft-profile-label">NAME</span>
                                    <span className="draft-profile-value">
                                        {form.fullName || "—"}
                                    </span>
                                </div>
                                <div className="draft-profile-row">
                                    <span className="draft-profile-label">CONTACT</span>
                                    <span className="draft-profile-value">{form.email || "—"}</span>
                                </div>
                                <div className="draft-profile-row">
                                    <span className="draft-profile-label">ROLE</span>
                                    <span className="draft-profile-value dim">
                                        {form.designation || "Pending selection..."}
                                    </span>
                                </div>
                            </div>

                            <div className="security-badge">
                                <i className="bx bx-shield-quarter security-badge-icon" />
                                <p className="security-badge-text">
                                    All trainer credentials are encrypted and stored in compliance
                                    with standard security protocols.
                                </p>
                            </div>
                        </>
                    )}

                    {step === 3 && (
                        <>
                            <div className="draft-profile-card-v2">
                                <div className="draft-profile-v2-header">
                                    <div className="draft-profile-v2-title">Draft Profile</div>
                                    <span className="draft-status-pill">IN PROGRESS</span>
                                </div>

                                <div className="draft-profile-v2-identity">
                                    <div className="draft-photo-frame">
                                        {form.photoFile ? (
                                            <img
                                                src={URL.createObjectURL(form.photoFile)}
                                                alt={form.fullName}
                                                className="draft-photo-img"
                                            />
                                        ) : (
                                            <div className="draft-photo-fallback">
                                                {form.fullName
                                                    ? form.fullName
                                                        .split(" ")
                                                        .map((p) => p[0])
                                                        .join("")
                                                        .slice(0, 2)
                                                        .toUpperCase()
                                                    : "—"}
                                            </div>
                                        )}
                                    </div>
                                    <div>
                                        <div className="draft-profile-v2-name">
                                            {form.fullName || "Unnamed Trainer"}
                                        </div>
                                        <div className="draft-profile-v2-role">
                                            {form.designation || "Role not set"}
                                        </div>
                                    </div>
                                </div>

                                <div className="draft-profile-v2-section">
                                    <div className="draft-profile-v2-label">SPECIALIZATIONS</div>
                                    <div className="draft-spec-pills">
                                        {form.specializations.length > 0 ? (
                                            form.specializations.map((s) => (
                                                <span key={s} className="draft-spec-pill">
                                                    {s.toUpperCase()}
                                                </span>
                                            ))
                                        ) : (
                                            <span className="draft-profile-v2-empty">
                                                None selected
                                            </span>
                                        )}
                                    </div>
                                </div>

                                <div className="draft-profile-v2-section">
                                    <div className="draft-profile-v2-label">CERTIFICATION</div>
                                    <div className="draft-profile-v2-value">
                                        {form.certBodies.length > 0
                                            ? form.certBodies.join(", ")
                                            : form.certFiles.length > 0
                                                ? `${form.certFiles.length} file(s) uploaded`
                                                : "None added"}
                                    </div>
                                </div>

                                <button
                                    type="button"
                                    className="edit-previous-btn"
                                    onClick={() => {
                                        setErrors({});
                                        setStep(1);
                                    }}
                                >
                                    Edit Previous Steps
                                </button>
                            </div>

                            <div className="tip-card-v2">
                                <i className="bx bx-bulb tip-v2-icon" />
                                <div>
                                    <div className="tip-v2-title">Pro Onboarding Tip</div>
                                    <p className="tip-v2-text">
                                        You can sync external Google or Outlook calendars after
                                        the initial setup. For now, just define{" "}
                                        {form.fullName || "the trainer"}'s core coaching hours.
                                    </p>
                                </div>
                            </div>

                            <div className="capacity-card">
                                <div className="capacity-label">COACH CAPACITY</div>
                                <div className="capacity-value-row">
                                    <span className="capacity-value">{totalWeeklyHours}</span>
                                    <span className="capacity-unit">Hours / Week</span>
                                </div>
                                <div className="capacity-track">
                                    <div
                                        className="capacity-fill"
                                        style={{
                                            width: `${Math.min(
                                                (totalWeeklyHours / 40) * 100,
                                                100
                                            )}%`,
                                        }}
                                    />
                                </div>
                                <p className="capacity-note">
                                    New trainer — no clients assigned yet. Hours shown reflect
                                    the schedule set above.
                                </p>
                            </div>
                        </>
                    )}

                    {step === 4 && (
                        <>
                            <div className="directory-preview-card">
                                <div className="directory-preview-header">
                                    <span>DIRECTORY CARD PREVIEW</span>
                                    <span className="live-preview-pill">LIVE PREVIEW</span>
                                </div>

                                <div className="directory-card">
                                    <div className="directory-card-photo">
                                        {form.photoFile ? (
                                            <img
                                                src={URL.createObjectURL(form.photoFile)}
                                                alt={form.fullName}
                                                className="directory-card-avatar-img"
                                            />
                                        ) : (
                                            <div className="directory-card-avatar-fallback">
                                                {form.fullName
                                                    ? form.fullName
                                                        .split(" ")
                                                        .map((p) => p[0])
                                                        .join("")
                                                        .slice(0, 2)
                                                        .toUpperCase()
                                                    : "—"}
                                            </div>
                                        )}
                                    </div>
                                    <div className="directory-card-name">
                                        {form.fullName || "Unnamed Trainer"}
                                    </div>
                                    <div className="directory-card-role">
                                        {form.designation || "Role not set"}
                                    </div>
                                    {form.educationBackground && (
                                        <p className="directory-card-bio">
                                            {form.educationBackground}
                                        </p>
                                    )}
                                    <div className="directory-card-tags">
                                        {form.specializations.slice(0, 3).map((s) => (
                                            <span key={s} className="directory-card-tag">
                                                {s}
                                            </span>
                                        ))}
                                    </div>
                                    <div className="directory-card-rating">
                                        <i className="bx bx-star" /> New trainer — no ratings yet
                                    </div>
                                </div>

                                <p className="directory-preview-footnote">
                                    This is how{" "}
                                    {form.fullName ? form.fullName.split(" ")[0] : "the trainer"}{" "}
                                    will appear in the Client App search results.
                                </p>
                            </div>

                            <div className="finalize-card">
                                <div className="finalize-title">Finalize Onboarding</div>

                                <label className="finalize-checkbox-row">
                                    <input
                                        type="checkbox"
                                        checked={confirmedOnboarding}
                                        onChange={(e) => setConfirmedOnboarding(e.target.checked)}
                                    />
                                    <span>
                                        I confirm that the trainer's documentation has been
                                        verified and they agree to the{" "}
                                        <a href="#" className="finalize-link">
                                            Internal Service Agreement
                                        </a>{" "}
                                        and{" "}
                                        <a href="#" className="finalize-link">
                                            Code of Conduct
                                        </a>
                                        .
                                    </span>
                                </label>

                                <button
                                    type="button"
                                    className="complete-onboarding-btn"
                                    disabled={!confirmedOnboarding || submitting}
                                    onClick={handleCompleteOnboarding}
                                >
                                    <i className="bx bx-user-check" />{" "}
                                    {submitting ? "Submitting..." : "Complete Onboarding"}
                                </button>

                                <button
                                    type="button"
                                    className="back-to-step-btn"
                                    onClick={() => setStep(3)}
                                >
                                    Back to Step 3
                                </button>

                                <div className="finalize-warning">
                                    <i className="bx bx-error-circle" />
                                    <span>
                                        Finalizing this step will trigger an automatic welcome
                                        email and invite the trainer to their portal.
                                    </span>
                                </div>

                                {submitError && (
                                    <div className="finalize-warning" style={{ marginTop: 12 }}>
                                        <i className="bx bx-error-circle" />
                                        <span>{submitError}</span>
                                    </div>
                                )}
                            </div>
                        </>
                    )}
                </div>
            </div>
        </Layout>
    );
}