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
        async function loadUsers() {
            try {
                const clientsQuery = query(
                    collection(db, "users"),
                    where("role", "==", "client")
                );
                const clientsSnap = await getDocs(clientsQuery);

                const rows: UserRow[] = await Promise.all(
                    clientsSnap.docs.map(async (clientDoc) => {
                        const clientData = clientDoc.data();

                        // Real join: find this client's active subscription
                        const subQuery = query(
                            collection(db, "subscriptions"),
                            where("clientId", "==", clientDoc.id),
                            where("status", "==", "active"),
                            limit(1)
                        );
                        const subSnap = await getDocs(subQuery);

                        let packageName = "—";
                        let trainerName = "—";
                        let status: UserRow["status"] = "No Subscription";

                        if (!subSnap.empty) {
                            const sub = subSnap.docs[0].data();
                            status = sub.status === "active" ? "Active" : sub.status;

                            // Join against packages collection for the real package name
                            if (sub.packageId) {
                                const packageSnap = await getDoc(doc(db, "packages", sub.packageId));
                                packageName = packageSnap.exists()
                                    ? packageSnap.data().name
                                    : "—";
                            }

                            // Join against trainers collection for the real trainer name
                            if (sub.trainerId) {
                                const trainerSnap = await getDoc(doc(db, "users", sub.trainerId));
                                trainerName = trainerSnap.exists()
                                    ? trainerSnap.data().fullName
                                    : "—";
                            }
                        }

                        return {
                            id: clientDoc.id,
                            name: clientData.fullName ?? "Unnamed",
                            phone: clientData.phone ?? "—",
                            packageName,
                            trainerName,
                            joined: clientData.createdAt?.toDate
                                ? clientData.createdAt.toDate().toLocaleDateString("en-GB", {
                                    day: "2-digit",
                                    month: "short",
                                    year: "numeric",
                                })
                                : "—",
                            status,
                        };
                    })
                );

                setUsers(rows);
            } catch (err) {
                console.error("Users load error:", err);
            } finally {
                setLoading(false);
            }
        }

        loadUsers();
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
                                    No clients registered yet. Once someone signs up through the
                                    client app (phone OTP), they'll appear here automatically.
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
                                            className={`users-status-pill ${user.status === "Active" ? "active" : "due"
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