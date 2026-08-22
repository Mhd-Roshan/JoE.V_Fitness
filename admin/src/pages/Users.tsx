import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, getDocs } from "firebase/firestore";
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
}

// Define strict type for Subscription Data to satisfy ESLint
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
                // 1. Fetch EVERYTHING at the exact same time (Lightning Fast)
                const [clientsSnap, trainersSnap, usersSnap, packagesSnap, subsSnap] = await Promise.all([
                    getDocs(query(collection(db, "users"), where("role", "==", "client"))),
                    getDocs(collection(db, "trainers")),
                    getDocs(query(collection(db, "users"), where("role", "==", "trainer"))), // Just in case trainers are in users
                    getDocs(collection(db, "packages")),
                    getDocs(collection(db, "subscriptions"))
                ]);

                // 2. Build Memory Maps for Instant O(1) Lookups (Removes the lag!)
                const trainersMap: Record<string, string> = {};
                trainersSnap.forEach(doc => { trainersMap[doc.id] = doc.data().fullName || doc.data().name; });
                usersSnap.forEach(doc => { trainersMap[doc.id] = doc.data().fullName || doc.data().name; });

                const packagesMap: Record<string, string> = {};
                packagesSnap.forEach(doc => { packagesMap[doc.id] = doc.data().name || doc.data().title; });

                // Use the strict SubData interface here instead of "any"
                const subsMap: Record<string, SubData> = {};
                subsSnap.forEach(doc => {
                    const data = doc.data() as SubData;
                    if (data.clientId) subsMap[data.clientId] = data; // Link sub to client
                });

                // 3. Process clients instantly in memory without waiting for network again
                const rows: UserRow[] = clientsSnap.docs.map(clientDoc => {
                    const clientData = clientDoc.data();
                    const subData = subsMap[clientDoc.id]; // Instant lookup

                    // --- TRAINER LOGIC ---
                    const targetTrainerId = clientData.assignedTrainerId || clientData.trainerId || subData?.trainerId;
                    let finalTrainerName = "—";
                    if (targetTrainerId && trainersMap[targetTrainerId]) {
                        finalTrainerName = trainersMap[targetTrainerId];
                    } else if (clientData.trainerName) {
                        finalTrainerName = clientData.trainerName;
                    }

                    // --- PACKAGE LOGIC (Aggressive Fallbacks) ---
                    const targetPackageId = clientData.packageId || clientData.planId || subData?.packageId;
                    let finalPackageName = "—";
                    if (targetPackageId && packagesMap[targetPackageId]) {
                        finalPackageName = packagesMap[targetPackageId];
                    } else if (clientData.packageName || clientData.selectedPackage || clientData.plan) {
                        finalPackageName = clientData.packageName || clientData.selectedPackage || clientData.plan;
                    } else if (subData?.packageName) {
                        finalPackageName = subData.packageName;
                    }

                    // --- STATUS LOGIC (Aggressive Fallbacks) ---
                    let finalStatus: UserRow["status"] = "No Subscription";

                    // Check subscription doc first
                    if (subData?.status) {
                        const s = subData.status.toLowerCase();
                        finalStatus = s === "active" ? "Active" : s === "due" ? "Due" : "Expired";
                    }
                    // Fallback to user doc directly
                    else if (clientData.subscriptionStatus || clientData.status) {
                        const s = (clientData.subscriptionStatus || clientData.status).toLowerCase();
                        finalStatus = s === "active" ? "Active" : s === "due" ? "Due" : "Expired";
                    }
                    // Boolean fallback
                    else if (clientData.isActive === true) {
                        finalStatus = "Active";
                    } else if (finalPackageName !== "—") {
                        // If they have a package but no clear status, assume Active
                        finalStatus = "Active";
                    }

                    // --- DATE LOGIC ---
                    let joinedDate = "—";
                    if (clientData.createdAt) {
                        const dateObj = typeof clientData.createdAt.toDate === "function"
                            ? clientData.createdAt.toDate()
                            : new Date(clientData.createdAt);

                        joinedDate = dateObj.toLocaleDateString("en-GB", {
                            day: "2-digit", month: "short", year: "numeric",
                        });
                    }

                    return {
                        id: clientDoc.id,
                        name: clientData.fullName || clientData.name || "Unnamed",
                        phone: clientData.phone || "—",
                        packageName: finalPackageName,
                        trainerName: finalTrainerName,
                        joined: joinedDate,
                        status: finalStatus,
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

    const filteredRows = users.filter((u) =>
        u.name.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <Layout title="Users Managements">
            <div className="users-header">
                <div className="users-title">Users</div>
                <div className="users-subtitle">
                    All registered customers and their current subscription.
                </div>
            </div>

            <div className="users-toolbar">
                <input
                    className="users-search-input"
                    placeholder="Search clients..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                />
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

            <div className="users-table-card">
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
                                        <i className='bx bx-loader-alt bx-spin' style={{ fontSize: "20px", color: "#003AA3" }}></i>
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
                                    <td className="users-name-cell">{user.name}</td>
                                    <td>{user.phone}</td>
                                    <td>
                                        <span className="users-package-pill" style={{ opacity: user.packageName === "—" ? 0.5 : 1 }}>
                                            {user.packageName}
                                        </span>
                                    </td>
                                    <td>{user.trainerName}</td>
                                    <td>{user.joined}</td>
                                    <td>
                                        <span
                                            className={`users-status-pill ${user.status === "Active"
                                                ? "active"
                                                : user.status === "No Subscription"
                                                    ? "expired"
                                                    : "due"
                                                }`}
                                        >
                                            {user.status}
                                        </span>
                                    </td>
                                    <td>
                                        <button
                                            className="users-view-btn"
                                            title="View profile"
                                            onClick={() => navigate(`/users/${user.id}`)}
                                        >
                                            <i className="bx bx-show" />
                                        </button>
                                    </td>
                                </tr>
                            ))}
                    </tbody>
                </table>
            </div>
        </Layout>
    );
}