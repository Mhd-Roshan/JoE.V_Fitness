import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, getDocs, doc, deleteDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/users.css";

interface UserRow {
    id: string;
    name: string;
    phone: string;
    packageName: string;
    trainerName: string;
    joined: string;
    status: "Active" | "Due" | "Expired" | "No Subscription";
    location?: string;
    mapsUrl?: string;
    photoURL?: string | null;
}

interface SubData {
    clientId?: string;
    trainerId?: string;
    packageId?: string;
    packageName?: string;
    status?: string;
}

export default function Users() {
    const navigate = useNavigate();
    const [users, setUsers] = useState<UserRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState("");

    useEffect(() => {
        let isMounted = true;

        async function loadDataFast() {
            try {
                const [clientsSnap, trainersSnap, usersSnap, packagesSnap, subsSnap] = await Promise.all([
                    getDocs(query(collection(db, "users"), where("role", "==", "client"))),
                    getDocs(collection(db, "trainers")),
                    getDocs(query(collection(db, "users"), where("role", "==", "trainer"))),
                    getDocs(collection(db, "packages")),
                    getDocs(collection(db, "subscriptions"))
                ]);

                const trainersMap: Record<string, string> = {};
                trainersSnap.forEach(doc => { trainersMap[doc.id] = doc.data().fullName || doc.data().name; });
                usersSnap.forEach(doc => { trainersMap[doc.id] = doc.data().fullName || doc.data().name; });

                const packagesMap: Record<string, string> = {};
                packagesSnap.forEach(doc => { packagesMap[doc.id] = doc.data().name || doc.data().title; });

                const subsMap: Record<string, SubData> = {};
                subsSnap.forEach(doc => {
                    const data = doc.data() as SubData;
                    if (data.clientId) subsMap[data.clientId] = data;
                });

                const rows: UserRow[] = clientsSnap.docs.map(clientDoc => {
                    const clientData = clientDoc.data();
                    const subData = subsMap[clientDoc.id];

                    // TRAINER LOGIC
                    const targetTrainerId = clientData.assignedTrainerId || clientData.trainerId || subData?.trainerId;
                    let finalTrainerName = "—";
                    if (targetTrainerId && trainersMap[targetTrainerId]) {
                        finalTrainerName = trainersMap[targetTrainerId];
                    } else if (clientData.trainerName) {
                        finalTrainerName = clientData.trainerName;
                    }

                    // PACKAGE LOGIC 
                    const targetPackageId = clientData.packageId || clientData.planId || subData?.packageId;
                    let finalPackageName = "—";
                    if (targetPackageId && packagesMap[targetPackageId]) {
                        finalPackageName = packagesMap[targetPackageId];
                    } else if (clientData.packageName || clientData.selectedPackage || clientData.plan) {
                        finalPackageName = clientData.packageName || clientData.selectedPackage || clientData.plan;
                    } else if (subData?.packageName) {
                        finalPackageName = subData.packageName;
                    }

                    // STATUS LOGIC 
                    let finalStatus: UserRow["status"] = "No Subscription";
                    if (subData?.status) {
                        const s = subData.status.toLowerCase();
                        finalStatus = s === "active" ? "Active" : s === "due" ? "Due" : "Expired";
                    } else if (clientData.subscriptionStatus || clientData.status) {
                        const s = (clientData.subscriptionStatus || clientData.status).toLowerCase();
                        finalStatus = s === "active" ? "Active" : s === "due" ? "Due" : "Expired";
                    } else if (clientData.isActive === true) {
                        finalStatus = "Active";
                    } else if (finalPackageName !== "—") {
                        finalStatus = "Active";
                    }

                    // DATE LOGIC
                    let joinedDate = "—";
                    if (clientData.createdAt) {
                        const dateObj = typeof clientData.createdAt.toDate === "function"
                            ? clientData.createdAt.toDate()
                            : new Date(clientData.createdAt);

                        joinedDate = dateObj.toLocaleDateString("en-GB", {
                            day: "2-digit", month: "short", year: "numeric",
                        });
                    }

                    // LOCATION & MAPS LOGIC
                    const loc = clientData.location || clientData.address || clientData.city || (typeof clientData.currentLocation === 'object' ? clientData.currentLocation?.address : clientData.currentLocation);
                    const lat = clientData.lat || clientData.latitude || (typeof clientData.currentLocation === 'object' ? clientData.currentLocation?.lat : undefined);
                    const lng = clientData.lng || clientData.longitude || (typeof clientData.currentLocation === 'object' ? clientData.currentLocation?.lng : undefined);
                    let mapsUrl: string | undefined;
                    let locStr: string | undefined = typeof loc === 'string' && loc.trim() ? loc.trim() : undefined;
                    if (typeof lat === 'number' && typeof lng === 'number' && lat !== 0 && lng !== 0) {
                        mapsUrl = `https://www.google.com/maps?q=${lat},${lng}`;
                        if (!locStr) locStr = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
                    } else if (locStr && locStr.toLowerCase() !== 'not set') {
                        mapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(locStr)}`;
                    }

                    const photoURL = (clientData.photoURL || clientData.profileImage || clientData.avatar || clientData.avatarUrl || clientData.imageUrl || null) as string | null;

                    return {
                        id: clientDoc.id,
                        name: clientData.fullName || clientData.name || "Unnamed",
                        phone: clientData.phone || "—",
                        packageName: finalPackageName,
                        trainerName: finalTrainerName,
                        joined: joinedDate,
                        status: finalStatus,
                        location: locStr,
                        mapsUrl: mapsUrl,
                        photoURL: photoURL,
                    };
                });

                if (isMounted) setUsers(rows);
            } catch (err) {
                console.error("Fast load error:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        loadDataFast();

        return () => { isMounted = false; };
    }, []);

    const handleDeleteUser = async (userId: string) => {
        const confirmDelete = window.confirm(
            "Are you sure you want to delete this client? This action cannot be undone."
        );
        if (!confirmDelete) return;

        try {
            await deleteDoc(doc(db, "users", userId));
            setUsers((prev) => prev.filter((u) => u.id !== userId));
            alert("Client deleted successfully.");
        } catch (error) {
            console.error("Error deleting user:", error);
            alert("An error occurred while trying to delete the client.");
        }
    };

    const filteredRows = users.filter((u) =>
        u.name.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <Layout title="Users Managements">
            <div className="users-page-wrapper">

                {/* HEADER */}
                <div className="users-header">
                    <h1 className="users-title">Users</h1>
                    <p className="users-subtitle">
                        All registered customers and their current subscription.
                    </p>
                </div>

                {/* TOOLBAR (Matches image perfectly) */}
                <div className="users-toolbar">
                    <div className="users-search-container">
                        <i className="bx bx-search users-search-icon"></i>
                        <input
                            className="users-search-input"
                            placeholder="Search clients..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                        />
                    </div>
                    <div className="users-filters-container">
                        <select className="users-filter-select" defaultValue="">
                            <option value="">All Package</option>
                            <option value="1">Package 1</option>
                            <option value="2">Package 2</option>
                            <option value="3">Package 3</option>
                        </select>
                        <select className="users-filter-select" defaultValue="">
                            <option value="">All Statuses</option>
                            <option value="active">Active</option>
                            <option value="due">Due</option>
                        </select>
                    </div>
                </div>

                {/* TABLE CARD */}
                <div className="users-table-card">
                    <div className="table-responsive">
                        <table className="users-table">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Phone</th>
                                    <th>Packages</th>
                                    <th>Trainer</th>
                                    <th>Joined</th>
                                    <th>Status</th>
                                    <th></th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading && (
                                    <tr>
                                        <td colSpan={7} className="users-empty-state">
                                            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "10px" }}>
                                                <i className='bx bx-loader-alt bx-spin' style={{ fontSize: "20px", color: "#00225d" }}></i>
                                                Loading clients...
                                            </div>
                                        </td>
                                    </tr>
                                )}

                                {!loading && filteredRows.length === 0 && (
                                    <tr>
                                        <td colSpan={7} className="users-empty-state">
                                            No clients found.
                                        </td>
                                    </tr>
                                )}

                                {!loading &&
                                    filteredRows.map((user) => (
                                        <tr key={user.id}>
                                            <td className="fw-700 text-dark">
                                                <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                                                    {user.photoURL ? (
                                                        <img
                                                            src={user.photoURL}
                                                            alt={user.name}
                                                            style={{ width: "32px", height: "32px", borderRadius: "50%", objectFit: "cover", flexShrink: 0, border: "1px solid #e2e8f0" }}
                                                            onError={(e) => { (e.target as HTMLElement).style.display = "none"; }}
                                                        />
                                                    ) : (
                                                        <div style={{ width: "32px", height: "32px", borderRadius: "50%", background: "#d20015", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "11px", fontWeight: 700, flexShrink: 0 }}>
                                                            {user.name.split(" ").map(n => n[0]).join("").slice(0, 2).toUpperCase()}
                                                        </div>
                                                    )}
                                                    <span>{user.name}</span>
                                                </div>
                                            </td>
                                            <td className="text-normal">{user.phone}</td>
                                            <td>
                                                <span className="users-package-badge" style={{ opacity: user.packageName === "—" ? 0.5 : 1 }}>
                                                    {user.packageName}
                                                </span>
                                            </td>
                                            <td className="fw-700 text-dark">{user.trainerName}</td>
                                            <td className="text-normal">{user.joined}</td>
                                            <td>
                                                <span
                                                    className={`users-status-badge ${user.status === "Active"
                                                        ? "status-active"
                                                        : user.status === "Due"
                                                            ? "status-due"
                                                            : "status-expired"
                                                        }`}
                                                >
                                                    {user.status}
                                                </span>
                                            </td>
                                            <td>
                                                <div className="users-actions-group">
                                                    {user.mapsUrl && (
                                                        <a
                                                            href={user.mapsUrl}
                                                            target="_blank"
                                                            rel="noopener noreferrer"
                                                            className="users-action-btn"
                                                            title={`View ${user.name}'s location on Google Maps`}
                                                            style={{ color: "#16a34a" }}
                                                        >
                                                            <i className="bx bx-map" />
                                                        </a>
                                                    )}
                                                    <button
                                                        className="users-action-btn"
                                                        title="View profile"
                                                        onClick={() => navigate(`/users/${user.id}`)}
                                                    >
                                                        <i className="bx bx-show" />
                                                    </button>
                                                    <button
                                                        className="users-action-btn delete-btn"
                                                        title="Delete User"
                                                        onClick={() => handleDeleteUser(user.id)}
                                                    >
                                                        <i className="bx bx-trash" />
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </Layout>
    );
}