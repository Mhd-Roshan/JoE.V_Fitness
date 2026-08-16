import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    query,
    where,
    getDocs,
    doc,
    getDoc,
    limit,
} from "firebase/firestore";
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

export default function Users() {
    const navigate = useNavigate();
    const [users, setUsers] = useState<UserRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState("");

    useEffect(() => {
        let isMounted = true;

        async function loadUsers() {
            try {
                // Fetch all clients
                const clientsQuery = query(
                    collection(db, "users"),
                    where("role", "==", "client")
                );
                const clientsSnap = await getDocs(clientsQuery);

                console.log(`Found ${clientsSnap.docs.length} clients in database.`);

                const rows: UserRow[] = await Promise.all(
                    clientsSnap.docs.map(async (clientDoc) => {
                        const clientData = clientDoc.data();

                        let packageName = "—";
                        let trainerName = "—";
                        let status: UserRow["status"] = "No Subscription";

                        // Wrap subscription fetch in try-catch so a missing index doesn't break the whole table
                        try {
                            const subQuery = query(
                                collection(db, "subscriptions"),
                                where("clientId", "==", clientDoc.id),
                                where("status", "==", "active"),
                                limit(1)
                            );
                            const subSnap = await getDocs(subQuery);

                            if (!subSnap.empty) {
                                const sub = subSnap.docs[0].data();
                                status = sub.status === "active" ? "Active" : sub.status;

                                // Join against packages collection
                                if (sub.packageId) {
                                    const packageSnap = await getDoc(doc(db, "packages", sub.packageId));
                                    if (packageSnap.exists()) {
                                        packageName = packageSnap.data().name || "—";
                                    }
                                }

                                // Join against trainers collection
                                if (sub.trainerId) {
                                    const trainerSnap = await getDoc(doc(db, "users", sub.trainerId));
                                    if (trainerSnap.exists()) {
                                        trainerName = trainerSnap.data().fullName || trainerSnap.data().name || "—";
                                    }
                                }
                            }
                        } catch (subError) {
                            console.warn(`Error fetching sub for client ${clientDoc.id}. You might need to create a Firestore Index.`, subError);
                        }

                        // Safely parse the joined date (handles Firestore Timestamps & ISO strings)
                        let joinedDate = "—";
                        if (clientData.createdAt) {
                            if (typeof clientData.createdAt.toDate === "function") {
                                joinedDate = clientData.createdAt.toDate().toLocaleDateString("en-GB", {
                                    day: "2-digit", month: "short", year: "numeric",
                                });
                            } else {
                                joinedDate = new Date(clientData.createdAt).toLocaleDateString("en-GB", {
                                    day: "2-digit", month: "short", year: "numeric",
                                });
                            }
                        }

                        return {
                            id: clientDoc.id,
                            // Fallback to check both fullName and name just in case
                            name: clientData.fullName || clientData.name || "Unnamed",
                            phone: clientData.phone || "—",
                            packageName,
                            trainerName,
                            joined: joinedDate,
                            status,
                        };
                    })
                );

                if (isMounted) setUsers(rows);
            } catch (err) {
                console.error("Users load error:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        loadUsers();

        return () => {
            isMounted = false;
        };
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
                                    Loading real client data from Firestore...
                                </td>
                            </tr>
                        )}

                        {!loading && filteredRows.length === 0 && (
                            <tr>
                                <td colSpan={7} className="users-empty-state">
                                    No clients registered yet or found. Please ensure users have role="client" in the database.
                                </td>
                            </tr>
                        )}

                        {!loading &&
                            filteredRows.map((user) => (
                                <tr key={user.id}>
                                    <td className="users-name-cell">{user.name}</td>
                                    <td>{user.phone}</td>
                                    <td>
                                        <span className="users-package-pill">{user.packageName}</span>
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