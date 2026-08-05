import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    query,
    where,
    getDocs,
    orderBy,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/packages.css";

interface PackageCard {
    id: string;
    name: string;
    price: number;
    features: string[];
    badge: "bestValue" | "mostPopular" | null;
    order: number;
}

interface RawPackageDoc {
    name?: string;
    price?: number;
    features?: string[];
    badge?: "bestValue" | "mostPopular" | null;
    order?: number;
}

interface RawSubscriptionDoc {
    status?: string;
    packageId?: string;
    packageName?: string;
    monthlyPrice?: number;
    createdAt?: { toDate: () => Date };
}

function weekAgoDate() {
    const d = new Date();
    d.setDate(d.getDate() - 7);
    return d;
}

export default function Packages() {
    const navigate = useNavigate();
    const [packages, setPackages] = useState<PackageCard[]>([]);
    const [activeSubCount, setActiveSubCount] = useState(0);
    const [newThisWeek, setNewThisWeek] = useState(0);
    const [totalRevenue, setTotalRevenue] = useState(0);
    const [mostPopularAddon, setMostPopularAddon] = useState<{
        name: string;
        conversionPct: number;
    } | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function load() {
            try {
                const pkgSnap = await getDocs(
                    query(collection(db, "packages"), orderBy("order", "asc"))
                );
                setPackages(
                    pkgSnap.docs.map((d) => {
                        const data = d.data() as RawPackageDoc;
                        return {
                            id: d.id,
                            name: data.name ?? "Package",
                            price: data.price ?? 0,
                            features: data.features ?? [],
                            badge: data.badge ?? null,
                            order: data.order ?? 0,
                        };
                    })
                );

                const subsSnap = await getDocs(
                    query(collection(db, "subscriptions"), where("status", "==", "active"))
                );
                const subs = subsSnap.docs.map((d) => d.data() as RawSubscriptionDoc);
                setActiveSubCount(subs.length);

                const weekAgo = weekAgoDate();
                const newCount = subs.filter(
                    (s) => s.createdAt?.toDate && s.createdAt.toDate() >= weekAgo
                ).length;
                setNewThisWeek(newCount);

                const revenue = subs.reduce((sum, s) => sum + (s.monthlyPrice ?? 0), 0);
                setTotalRevenue(revenue);

                // Most popular add-on: highest active-subscriber count among addOns collection
                const addonsSnap = await getDocs(collection(db, "addOns"));
                let best: { name: string; conversionPct: number } | null = null;
                addonsSnap.docs.forEach((d) => {
                    const data = d.data();
                    const conv = data.conversionPct ?? 0;
                    if (!best || conv > best.conversionPct) {
                        best = { name: data.name ?? "Add-on", conversionPct: conv };
                    }
                });
                setMostPopularAddon(best);
            } catch (err) {
                console.error("Packages load error:", err);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, []);

    if (loading) {
        return (
            <Layout title="Packages">
                <p style={{ color: "#999" }}>Loading packages...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Packages">
            <div className="packages-header">
                <div>
                    <div className="packages-title">Packages &amp; Add-ons</div>
                    <div className="packages-subtitle">
                        Strategize your membership tiers and boost secondary revenue with
                        high-value add-ons.
                    </div>
                </div>
                <div className="packages-header-actions">
                    <button
                        className="packages-manage-addons-btn"
                        onClick={() => navigate("/packages/addons")}
                    >
                        Manage Add-ons
                    </button>
                    <button
                        className="packages-add-btn"
                        onClick={() => navigate("/packages/add")}
                    >
                        + Add Package
                    </button>
                </div>
            </div>

            <div className="packages-stats-row">
                <div className="packages-stat-card">
                    <div className="packages-stat-top">
                        <span className="packages-stat-label">TOTAL PACKAGE REVENUE</span>
                        <i className="bx bx-rupee packages-stat-icon" />
                    </div>
                    <div className="packages-stat-value-row">
                        <span className="packages-stat-value">
                            ₹{totalRevenue.toLocaleString("en-IN", { minimumFractionDigits: 2 })}
                        </span>
                    </div>
                    <div className="packages-stat-footnote">vs last 30 days period</div>
                </div>

                <div className="packages-stat-card">
                    <div className="packages-stat-top">
                        <span className="packages-stat-label">ACTIVE SUBSCRIPTIONS</span>
                        <i className="bx bx-group packages-stat-icon" />
                    </div>
                    <div className="packages-stat-value-row">
                        <span className="packages-stat-value">{activeSubCount}</span>
                        {newThisWeek > 0 && (
                            <span className="packages-stat-pill">
                                +{newThisWeek} NEW THIS WEEK
                            </span>
                        )}
                    </div>
                    <div className="packages-stat-footnote">Active member pool</div>
                </div>

                <div className="packages-stat-card">
                    <div className="packages-stat-top">
                        <span className="packages-stat-label">MOST POPULAR ADD-ON</span>
                        <i className="bx bx-star packages-stat-icon cyan" />
                    </div>
                    <div className="packages-stat-value-row">
                        {mostPopularAddon ? (
                            <>
                                <span className="packages-stat-value small">
                                    {mostPopularAddon.name}
                                </span>
                                <span className="packages-stat-conv">
                                    {mostPopularAddon.conversionPct}% Conv.
                                </span>
                            </>
                        ) : (
                            <span className="profile-empty">No add-ons yet</span>
                        )}
                    </div>
                    <div className="packages-stat-footnote">High secondary revenue item</div>
                </div>
            </div>

            {packages.length === 0 ? (
                <div className="profile-empty" style={{ padding: 24 }}>
                    No packages created yet.
                </div>
            ) : (
                <div className="packages-tiers-row">
                    {packages.map((p) => (
                        <div
                            key={p.id}
                            className={`packages-tier-card ${p.badge === "bestValue" ? "highlighted" : ""
                                }`}
                        >
                            {p.badge === "mostPopular" && (
                                <div className="packages-most-popular-badge">MOST POPULAR</div>
                            )}
                            <div className="packages-tier-header">
                                <div className="packages-tier-name-row">
                                    <span className="packages-tier-name">{p.name}</span>
                                    {p.badge === "bestValue" && (
                                        <span className="packages-best-value-badge">
                                            BEST VALUE
                                        </span>
                                    )}
                                </div>
                                <div className="packages-tier-subtitle">
                                    Package {p.order}
                                </div>
                            </div>

                            <div className="packages-tier-price">
                                ₹{p.price.toLocaleString("en-IN")}
                                <span className="packages-tier-price-suffix">/Mo</span>
                            </div>

                            <div className="packages-tier-features">
                                {p.features.length === 0 ? (
                                    <span className="profile-empty">No features listed.</span>
                                ) : (
                                    p.features.map((f, i) => (
                                        <div key={i} className="packages-tier-feature">
                                            <i className="bx bx-check-circle" />
                                            <span>{f}</span>
                                        </div>
                                    ))
                                )}
                            </div>

                            <button
                                className={`packages-edit-plan-btn ${p.badge === "mostPopular" ? "filled" : ""
                                    }`}
                                onClick={() => navigate(`/packages/edit/${p.id}`)}
                            >
                                Edit Plan
                            </button>
                        </div>
                    ))}
                </div>
            )}

            <div className="packages-section-title">Subscription Tiers</div>
        </Layout>
    );
}