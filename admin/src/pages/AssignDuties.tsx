import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, getDocs, doc, setDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/assignDuties.css";

interface Trainer {
    id: string;
    fullName: string;
    initials: string;
    clientCount: number;
}

interface ClientRow {
    id: string;
    fullName: string;
    initials: string;
    subText: string;
    packageType: string;
    primaryGoal: string;
    goalColor: string;
    currentTrainerId: string | null;
    currentTrainerName: string | null;
    status: "unassigned" | "assigned" | "reassign_request";
}

// Helpers for visual styling
function getGoalColor(goal?: string) {
    if (!goal) return "#bb0013";
    const g = goal.toLowerCase();
    if (g.includes("fat") || g.includes("loss") || g.includes("weight")) return "#01bce3";
    if (g.includes("strength") || g.includes("muscle")) return "#00225d";
    return "#bb0013";
}

function getPackageClass(pkgName: string) {
    if (!pkgName) return "pkg-blue";
    if (pkgName.includes("2")) return "pkg-gray";
    if (pkgName.includes("3")) return "pkg-cyan";
    return "pkg-blue";
}

async function fetchAssignData() {
    const trainersSnap = await getDocs(query(collection(db, "users"), where("role", "==", "trainer")));
    const trainersMap: Record<string, string> = {};
    const tempTrainers: Record<string, Trainer> = {};

    trainersSnap.docs.forEach(docSnap => {
        const data = docSnap.data();
        const name = data.fullName || "Unknown Trainer";
        trainersMap[docSnap.id] = name;

        tempTrainers[docSnap.id] = {
            id: docSnap.id,
            fullName: name,
            initials: name.split(" ").map((n: string) => n[0]).join("").substring(0, 2).toUpperCase(),
            clientCount: 0
        };
    });

    const clientsSnap = await getDocs(query(collection(db, "users"), where("role", "==", "client")));
    const loadedClients: ClientRow[] = [];

    clientsSnap.docs.forEach(docSnap => {
        const data = docSnap.data();
        const name = data.fullName || "Unknown Client";
        const trainerId = data.trainerId || null;

        if (trainerId && tempTrainers[trainerId]) {
            tempTrainers[trainerId].clientCount += 1;
        }

        let status: ClientRow["status"] = "assigned";
        if (!trainerId) status = "unassigned";
        if (data.reassignRequest) status = "reassign_request"; // Strictly maps to Firebase flag

        let subText = "Joined recently";
        if (data.createdAt) {
            const createdDate = data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt);
            const diffTime = Math.abs(new Date().getTime() - createdDate.getTime());
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            if (diffDays < 30) {
                subText = `Joined ${diffDays} days ago`;
            } else {
                const diffMonths = Math.floor(diffDays / 30);
                subText = `Active for ${diffMonths} month${diffMonths > 1 ? 's' : ''}`;
            }
        }

        loadedClients.push({
            id: docSnap.id,
            fullName: name,
            initials: name.split(" ").map((n: string) => n[0]).join("").substring(0, 2).toUpperCase(),
            subText: subText,
            packageType: data.packageType || "No Package",
            primaryGoal: data.primaryGoal || "Unspecified",
            goalColor: getGoalColor(data.primaryGoal),
            currentTrainerId: trainerId,
            currentTrainerName: trainerId ? trainersMap[trainerId] : null,
            status: status
        });
    });

    return {
        newTrainers: Object.values(tempTrainers),
        newClients: loadedClients
    };
}


export default function AssignDuties() {
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [clients, setClients] = useState<ClientRow[]>([]);
    const [trainers, setTrainers] = useState<Trainer[]>([]);
    const [filterTab, setFilterTab] = useState<"all" | "pending" | "assigned">("all");

    // Pagination State
    const [currentPage, setCurrentPage] = useState(1);
    const ITEMS_PER_PAGE = 5;

    // Modal State
    const [modalOpen, setModalOpen] = useState(false);
    const [selectedClient, setSelectedClient] = useState<ClientRow | null>(null);
    const [assigning, setAssigning] = useState(false);

    useEffect(() => {
        let isMounted = true;

        fetchAssignData()
            .then(({ newTrainers, newClients }) => {
                if (isMounted) {
                    setTrainers(newTrainers);
                    setClients(newClients);
                    setLoading(false);
                }
            })
            .catch((error) => {
                console.error("Error loading assign data:", error);
                if (isMounted) setLoading(false);
            });

        return () => {
            isMounted = false;
        };
    }, []);

    // Filter Logic
    const filteredClients = clients.filter(c => {
        if (filterTab === "all") return true;
        if (filterTab === "pending") return c.status === "unassigned" || c.status === "reassign_request";
        if (filterTab === "assigned") return c.status === "assigned";
        return true;
    });

    // Pagination Logic
    const totalPages = Math.ceil(filteredClients.length / ITEMS_PER_PAGE) || 1;
    const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
    const paginatedClients = filteredClients.slice(startIndex, startIndex + ITEMS_PER_PAGE);

    // Handle Tab Change
    const handleTabChange = (tab: "all" | "pending" | "assigned") => {
        setFilterTab(tab);
        setCurrentPage(1);
    };

    // Open Modal List
    const openAssignModal = (client: ClientRow) => {
        setSelectedClient(client);
        setModalOpen(true);
    };

    const confirmAssignment = async (trainerId: string) => {
        if (!selectedClient) return;
        setAssigning(true);
        try {
            await setDoc(doc(db, "users", selectedClient.id), {
                trainerId: trainerId,
                reassignRequest: false
            }, { merge: true });

            const { newTrainers, newClients } = await fetchAssignData();
            setTrainers(newTrainers);
            setClients(newClients);

            setModalOpen(false);
            setSelectedClient(null);
        } catch (error) {
            console.error("Failed to assign trainer:", error);
        } finally {
            setAssigning(false);
        }
    };

    if (loading) {
        return <Layout title="Assign Duties"><div style={{ padding: 24, color: '#6b7280' }}>Loading assignment data...</div></Layout>;
    }

    const unassignedCount = clients.filter(c => c.status === "unassigned").length;
    const requestCount = clients.filter(c => c.status === "reassign_request").length;
    const assignedCount = clients.length - unassignedCount;
    const activeTrainersCount = trainers.length;
    const avgLoad = activeTrainersCount > 0 ? Math.round(assignedCount / activeTrainersCount) : 0;

    return (
        <Layout title="Assign Duties">
            <div className="ad-nav-row">
                <button className="ad-back-btn" onClick={() => navigate("/trainers")}>
                    <i className="bx bx-arrow-back" /> Back to Trainer
                </button>
            </div>

            <div className="ad-stats-row">
                <div className="ad-stat-card">
                    <div className="ad-stat-icon red-icon"><i className="bx bx-user-x" /></div>
                    <div>
                        <div className="ad-stat-label">UNASSIGNED CLIENTS</div>
                        <div className="ad-stat-value">{String(unassignedCount).padStart(2, '0')}</div>
                    </div>
                </div>

                <div className="ad-stat-card">
                    <div className="ad-stat-icon blue-icon"><i className="bx bx-pie-chart-alt-2" /></div>
                    <div>
                        <div className="ad-stat-label">AVG TRAINER LOAD</div>
                        <div className="ad-stat-value">{avgLoad}/ <span style={{ color: '#9ca3af', fontSize: '24px' }}>18</span></div>
                    </div>
                </div>

                <div className="ad-stat-card">
                    <div className="ad-stat-icon teal-icon"><i className="bx bx-hourglass" /></div>
                    <div>
                        <div className="ad-stat-label">PENDING REQUESTS</div>
                        <div className="ad-stat-value">{String(requestCount).padStart(2, '0')}</div>
                    </div>
                </div>
            </div>

            <div className="ad-table-card">
                <div className="ad-table-header">
                    <div className="ad-tabs-wrapper">
                        <span className="ad-tabs-label">ACTIVE TRAINERS</span>
                        <div className="ad-tabs-group">
                            <button className={filterTab === "all" ? "active" : ""} onClick={() => handleTabChange("all")}>All</button>
                            <button className={filterTab === "pending" ? "active" : ""} onClick={() => handleTabChange("pending")}>Pending</button>
                            <button className={filterTab === "assigned" ? "active" : ""} onClick={() => handleTabChange("assigned")}>Assigned</button>
                        </div>
                    </div>
                </div>

                <div className="ad-table-responsive">
                    <table className="ad-table">
                        <thead>
                            <tr>
                                <th>CLIENT NAME</th>
                                <th>PACKAGE TYPE</th>
                                <th>PRIMARY GOAL</th>
                                <th>CURRENT TRAINER</th>
                                <th>ACTIONS</th>
                            </tr>
                        </thead>
                        <tbody>
                            {paginatedClients.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="ad-empty-table">No clients found for this filter.</td>
                                </tr>
                            ) : (
                                paginatedClients.map((client) => (
                                    <tr key={client.id}>
                                        <td>
                                            <div className="ad-client-cell">
                                                <div className="ad-avatar">{client.initials}</div>
                                                <div className="ad-client-info">
                                                    <div className="ad-client-name">{client.fullName}</div>
                                                    <div className="ad-client-sub">{client.subText}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td>
                                            <span className={`ad-package-pill ${getPackageClass(client.packageType)}`}>
                                                {client.packageType}
                                            </span>
                                        </td>
                                        <td>
                                            <div className="ad-goal-cell">
                                                <span className="ad-goal-dot" style={{ backgroundColor: client.goalColor }}></span>
                                                {client.primaryGoal}
                                            </div>
                                        </td>
                                        <td>
                                            {client.status === "unassigned" ? (
                                                <div className="ad-unassigned-text">
                                                    <i className="bx bx-error" /> Unassigned
                                                </div>
                                            ) : (
                                                <div className="ad-trainer-cell">
                                                    <div className="ad-avatar small">{client.currentTrainerName?.substring(0, 2).toUpperCase()}</div>
                                                    <span>{client.currentTrainerName}</span>
                                                </div>
                                            )}
                                        </td>
                                        <td>
                                            {/* ONLY SHOW BUTTON IF UNASSIGNED OR REQUESTED REASSIGNMENT */}
                                            {client.status === "unassigned" && (
                                                <button className="ad-btn-solid-red" onClick={() => openAssignModal(client)}>
                                                    Assign Trainer
                                                </button>
                                            )}
                                            {client.status === "reassign_request" && (
                                                <button className="ad-btn-text-red" onClick={() => openAssignModal(client)}>
                                                    Change Trainer
                                                </button>
                                            )}
                                            {client.status === "assigned" && (
                                                <div
                                                    style={{ color: '#9ca3af', fontSize: '12px', fontStyle: 'italic', cursor: 'not-allowed' }}
                                                    title="Trainer can only be changed upon client request."
                                                >
                                                    <i className="bx bx-lock-alt" style={{ marginRight: 4 }} />
                                                    Assigned
                                                </div>
                                            )}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>

                <div className="ad-pagination">
                    <span className="ad-page-info">
                        Showing {filteredClients.length > 0 ? startIndex + 1 : 0}-
                        {Math.min(startIndex + ITEMS_PER_PAGE, filteredClients.length)} of {filteredClients.length} clients
                    </span>
                    <div className="ad-page-controls">
                        <button
                            className={`ad-page-text-btn ${currentPage === 1 ? "disabled" : ""}`}
                            onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                            disabled={currentPage === 1}
                        >
                            Prev
                        </button>

                        {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
                            <button
                                key={page}
                                className={currentPage === page ? "active" : ""}
                                onClick={() => setCurrentPage(page)}
                            >
                                {page}
                            </button>
                        ))}

                        <button
                            className={`ad-page-text-btn ${currentPage === totalPages ? "disabled" : ""}`}
                            onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                            disabled={currentPage === totalPages}
                        >
                            Next
                        </button>
                    </div>
                </div>
            </div>

            {/* ASSIGN TRAINER MODAL (TRAINER LIST) */}
            {modalOpen && selectedClient && (
                <div className="ad-modal-overlay" onClick={() => !assigning && setModalOpen(false)}>
                    <div className="ad-modal" onClick={e => e.stopPropagation()}>
                        <div className="ad-modal-header">
                            <h2>{selectedClient.status === 'unassigned' ? 'Assign Trainer' : 'Change Trainer Request'}</h2>
                            <button className="ad-modal-close" onClick={() => setModalOpen(false)}><i className="bx bx-x" /></button>
                        </div>
                        <div className="ad-modal-body">
                            <p className="ad-modal-subtitle">
                                Select a trainer from the list below for <strong>{selectedClient.fullName}</strong>.
                                {selectedClient.currentTrainerName && ` (Currently assigned to ${selectedClient.currentTrainerName})`}
                            </p>

                            <div className="ad-modal-trainers-list">
                                {trainers.length === 0 ? (
                                    <p style={{ textAlign: 'center', color: '#6b7280' }}>No trainers available in the system.</p>
                                ) : (
                                    trainers.map(trainer => (
                                        <div key={trainer.id} className="ad-modal-trainer-card">
                                            <div className="ad-modal-trainer-info">
                                                <div className="ad-avatar">{trainer.initials}</div>
                                                <div>
                                                    <div className="ad-client-name">{trainer.fullName}</div>
                                                    <div className="ad-client-sub">{trainer.clientCount} Active Clients</div>
                                                </div>
                                            </div>
                                            <button
                                                className="ad-btn-solid-blue"
                                                onClick={() => confirmAssignment(trainer.id)}
                                                disabled={assigning || trainer.id === selectedClient.currentTrainerId}
                                            >
                                                {trainer.id === selectedClient.currentTrainerId ? "Current" : "Assign"}
                                            </button>
                                        </div>
                                    ))
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}