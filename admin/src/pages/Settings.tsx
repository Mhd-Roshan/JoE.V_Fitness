import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { doc, getDoc, setDoc, serverTimestamp } from "firebase/firestore";
import { signOut } from "firebase/auth";
import { db, auth } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/settings.css";

const LANGUAGES = ["English", "Malayalam", "Hindi", "Tamil"];
const REGIONS = ["India", "United Arab Emirates", "United States", "United Kingdom"];

export default function Settings() {
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState<string | null>(null);

    // Admin profile
    const [adminName, setAdminName] = useState("");
    const [adminEmail, setAdminEmail] = useState("");
    const [adminPhone, setAdminPhone] = useState("");
    const [adminLocation, setAdminLocation] = useState("");
    const [adminPhotoURL, setAdminPhotoURL] = useState<string | null>(null);
    const [editingProfile, setEditingProfile] = useState(false);

    // Business info
    const [businessName, setBusinessName] = useState("");
    const [tagline, setTagline] = useState("");
    const [serviceArea, setServiceArea] = useState("");
    const [language, setLanguage] = useState(LANGUAGES[0]);
    const [region, setRegion] = useState(REGIONS[0]);

    useEffect(() => {
        async function load() {
            try {
                const uid = auth.currentUser?.uid;
                if (uid) {
                    const userSnap = await getDoc(doc(db, "users", uid));
                    if (userSnap.exists()) {
                        const data = userSnap.data();
                        setAdminName(data.fullName ?? "");
                        setAdminEmail(data.email ?? auth.currentUser?.email ?? "");
                        setAdminPhone(data.phone ?? "");
                        setAdminLocation(data.location ?? "");
                        setAdminPhotoURL(data.photoURL ?? null);
                    } else {
                        setAdminEmail(auth.currentUser?.email ?? "");
                    }
                }

                const businessSnap = await getDoc(doc(db, "businessSettings", "main"));
                if (businessSnap.exists()) {
                    const data = businessSnap.data();
                    setBusinessName(data.name ?? "");
                    setTagline(data.tagline ?? "");
                    setServiceArea(data.serviceArea ?? "");
                    setLanguage(
                        LANGUAGES.includes(data.language) ? data.language : LANGUAGES[0]
                    );
                    setRegion(REGIONS.includes(data.region) ? data.region : REGIONS[0]);
                }
            } catch (err) {
                console.error("Settings load error:", err);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, []);

    async function handleSaveProfile() {
        const uid = auth.currentUser?.uid;
        if (!uid) return;
        setSaving(true);
        setSaveError(null);
        try {
            await setDoc(
                doc(db, "users", uid),
                {
                    fullName: adminName,
                    phone: adminPhone,
                    location: adminLocation,
                    updatedAt: serverTimestamp(),
                },
                { merge: true }
            );
            setEditingProfile(false);
        } catch (err) {
            console.error("Save profile failed:", err);
            setSaveError("Couldn't save your profile. Try again.");
        } finally {
            setSaving(false);
        }
    }

    async function handleSaveBusinessInfo() {
        setSaving(true);
        setSaveError(null);
        try {
            await setDoc(
                doc(db, "businessSettings", "main"),
                {
                    name: businessName,
                    tagline,
                    serviceArea,
                    language,
                    region,
                    updatedAt: serverTimestamp(),
                },
                { merge: true }
            );
        } catch (err) {
            console.error("Save business info failed:", err);
            setSaveError("Couldn't save business settings. Try again.");
        } finally {
            setSaving(false);
        }
    }

    async function handleLogout() {
        try {
            await signOut(auth);
            navigate("/login");
        } catch (err) {
            console.error("Logout failed:", err);
        }
    }

    const initials = adminName
        ? adminName
            .split(" ")
            .map((p) => p[0])
            .join("")
            .slice(0, 2)
            .toUpperCase()
        : "—";

    if (loading) {
        return (
            <Layout title="Settings">
                <p style={{ color: "#999" }}>Loading settings...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Settings">
            <div className="stg-header">
                <div className="stg-title">System Configuration</div>
                <div className="stg-subtitle">
                    Manage global parameters, security protocols, and localization settings.
                </div>
            </div>

            {saveError && <div className="stg-save-error">{saveError}</div>}

            <div className="stg-layout">
                <div className="stg-profile-card">
                    <div className="stg-profile-top">
                        <div className="stg-profile-avatar">
                            {adminPhotoURL ? (
                                <img src={adminPhotoURL} alt={adminName} />
                            ) : (
                                initials
                            )}
                        </div>
                        <div className="stg-profile-identity">
                            {editingProfile ? (
                                <input
                                    className="stg-inline-input"
                                    value={adminName}
                                    onChange={(e) => setAdminName(e.target.value)}
                                />
                            ) : (
                                <div className="stg-profile-name">{adminName || "—"}</div>
                            )}
                            <span className="stg-admin-badge">Admin</span>
                        </div>
                        <button
                            className="stg-edit-btn"
                            onClick={() =>
                                editingProfile ? handleSaveProfile() : setEditingProfile(true)
                            }
                            disabled={saving}
                        >
                            <i className={`bx ${editingProfile ? "bx-save" : "bx-pencil"}`} />{" "}
                            {editingProfile ? (saving ? "Saving..." : "Save") : "Edit"}
                        </button>
                    </div>

                    <div className="stg-profile-field">
                        <div className="stg-profile-label">Email</div>
                        <div className="stg-profile-value">{adminEmail || "—"}</div>
                    </div>

                    <div className="stg-profile-field">
                        <div className="stg-profile-label">Phone</div>
                        {editingProfile ? (
                            <input
                                className="stg-inline-input"
                                value={adminPhone}
                                onChange={(e) => setAdminPhone(e.target.value)}
                                placeholder="+91 00000 00000"
                            />
                        ) : (
                            <div className="stg-profile-value">{adminPhone || "—"}</div>
                        )}
                    </div>

                    <div className="stg-profile-field">
                        <div className="stg-profile-label">Location</div>
                        {editingProfile ? (
                            <input
                                className="stg-inline-input"
                                value={adminLocation}
                                onChange={(e) => setAdminLocation(e.target.value)}
                                placeholder="City, State"
                            />
                        ) : (
                            <div className="stg-profile-value">{adminLocation || "—"}</div>
                        )}
                    </div>

                    <button className="stg-logout-btn" onClick={handleLogout}>
                        Logout <i className="bx bx-log-out" />
                    </button>
                </div>

                <div className="stg-business-card">
                    <div className="stg-business-title">Business info</div>

                    <div className="stg-field">
                        <label className="stg-label">Name</label>
                        <input
                            className="stg-input"
                            value={businessName}
                            onChange={(e) => setBusinessName(e.target.value)}
                        />
                    </div>

                    <div className="stg-field">
                        <label className="stg-label">Tagline</label>
                        <input
                            className="stg-input"
                            value={tagline}
                            onChange={(e) => setTagline(e.target.value)}
                        />
                    </div>

                    <div className="stg-field">
                        <label className="stg-label">Service Area</label>
                        <input
                            className="stg-input"
                            value={serviceArea}
                            onChange={(e) => setServiceArea(e.target.value)}
                        />
                    </div>

                    <div className="stg-row">
                        <div className="stg-field" style={{ flex: 1 }}>
                            <label className="stg-label">Language</label>
                            <select
                                className="stg-select"
                                value={LANGUAGES.includes(language) ? language : LANGUAGES[0]}
                                onChange={(e) => setLanguage(e.target.value)}
                            >
                                {LANGUAGES.map((l) => (
                                    <option key={l} value={l}>
                                        {l}
                                    </option>
                                ))}
                            </select>
                        </div>
                        <div className="stg-field" style={{ flex: 1 }}>
                            <label className="stg-label">Region</label>
                            <select
                                className="stg-select"
                                value={REGIONS.includes(region) ? region : REGIONS[0]}
                                onChange={(e) => setRegion(e.target.value)}
                            >
                                {REGIONS.map((r) => (
                                    <option key={r} value={r}>
                                        {r}
                                    </option>
                                ))}
                            </select>
                        </div>
                    </div>

                    <button
                        className="stg-save-btn"
                        onClick={handleSaveBusinessInfo}
                        disabled={saving}
                    >
                        <i className="bx bx-save" /> {saving ? "Saving..." : "Save changes"}
                    </button>
                </div>
            </div>
        </Layout>
    );
}