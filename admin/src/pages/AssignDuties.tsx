import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, getDocs, doc, setDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/assignDuties.css";

// ------------------------------------------------------------------
// TypeScript Interfaces
// ------------------------------------------------------------------
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

interface HeatmapData {
    morningLoad: number;
    afternoonLoad: number;
}

interface Recommendation {
    id: string;
    clientName: string;
    trainerId: string;
    trainerName: string;
    score: number;
    reason: string;
}

type FlexField = string | string[] | { name?: string; title?: string; planName?: string };

interface UserDocData {
    fullName?: string;
    trainerId?: string;
    reassignRequest?: boolean;
    createdAt?: { toDate?: () => Date } | string | number;
    primaryGoal?: FlexField;
    goal?: FlexField;
    fitnessGoal?: FlexField;
    myGoal?: FlexField;
    myGoals?: FlexField;
    goals?: FlexField;
    assessment?: {
        primaryGoal?: FlexField;
        goal?: FlexField;
        fitnessGoal?: FlexField;
    };
    packageType?: FlexField;
    package?: FlexField;
    plan?: FlexField;
    planName?: FlexField;
    subscriptionPlan?: FlexField;
    packageName?: FlexField;
    membership?: FlexField;
    membershipType?: FlexField;
}

interface SubDocData {
    userId?: string;
    clientId?: string;
    trainerId?: string;
    status?: string;
    primaryGoal?: FlexField;
    goal?: FlexField;
    fitnessGoal?: FlexField;
    packageType?: FlexField;
    package?: FlexField;
    plan?: FlexField;
    planName?: FlexField;
    subscriptionPlan?: FlexField;
    packageName?: FlexField;
    membership?: FlexField;
}

interface AssessDocData {
    userId?: string;
    clientId?: string;
    primaryGoal?: FlexField;
    goal?: FlexField;
    fitnessGoal?: FlexField;
    goals?: FlexField;
}

interface GoalDocData {
    userId?: string;
    clientId?: string;
    primaryGoal?: FlexField;
    goal?: FlexField;
    fitnessGoal?: FlexField;
    goals?: FlexField;
}

// ------------------------------------------------------------------
// UI Helpers
// ------------------------------------------------------------------
function getGoalColor(goal?: string) {
    if (!goal || goal === "Unspecified") return "#dc2626";
    const g = goal.toLowerCase();
    if (g.includes("fat") || g.includes("strength") || g.includes("muscle") || g.includes("loss")) return "#1e3a8a";
    return "#dc2626";
}

function getPackageClass(pkgName: string) {
    if (!pkgName || pkgName === "No Package") return "pkg-gray";
    const name = pkgName.toLowerCase();
    if (name.includes("2")) return "pkg-gray";
    if (name.includes("3")) return "pkg-cyan";
    return "pkg-blue";
}

// ------------------------------------------------------------------
// Deep Data Extractors 
// ------------------------------------------------------------------
function parseFlexField(val: FlexField | undefined): string | null {
    if (!val) return null;
    if (typeof val === 'string') return val.trim() !== '' ? val.trim() : null;
    if (Array.isArray(val) && val.length > 0 && typeof val[0] === 'string') return val[0].trim();
    if (typeof val === 'object' && !Array.isArray(val) && val !== null) {
        if ('name' in val && typeof val.name === 'string') return val.name.trim();
        if ('title' in val && typeof val.title === 'string') return val.title.trim();
        if ('planName' in val && typeof val.planName === 'string') return val.planName.trim();
    }
    return null;
}

function extractGoal(
    userDoc?: UserDocData,
    subDoc?: SubDocData,
    assessDoc?: AssessDocData,
    goalDoc?: GoalDocData
): string {
    const possibleGoals = [
        userDoc?.primaryGoal, userDoc?.goal, userDoc?.fitnessGoal, userDoc?.myGoal, userDoc?.myGoals, userDoc?.goals,
        userDoc?.assessment?.primaryGoal, userDoc?.assessment?.goal, userDoc?.assessment?.fitnessGoal,
        subDoc?.primaryGoal, subDoc?.goal, subDoc?.fitnessGoal,
        assessDoc?.primaryGoal, assessDoc?.goal, assessDoc?.fitnessGoal, assessDoc?.goals,
        goalDoc?.primaryGoal, goalDoc?.goal, goalDoc?.fitnessGoal, goalDoc?.goals
    ];

    for (const g of possibleGoals) {
        const parsed = parseFlexField(g);
        if (parsed) return parsed;
    }
    return "Unspecified";
}

function extractPackage(userDoc?: UserDocData, subDoc?: SubDocData): string {
    const possiblePackages = [
        userDoc?.packageType, userDoc?.package, userDoc?.plan, userDoc?.planName,
        userDoc?.subscriptionPlan, userDoc?.packageName, userDoc?.membership, userDoc?.membershipType,
        subDoc?.packageType, subDoc?.package, subDoc?.plan, subDoc?.planName,
        subDoc?.subscriptionPlan, subDoc?.packageName, subDoc?.membership
    ];

    for (const p of possiblePackages) {
        const parsed = parseFlexField(p);
        if (parsed) return parsed;
    }
    return "No Package";
}

// ------------------------------------------------------------------
// Main Fetch Logic
// ------------------------------------------------------------------
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

    const [subsSnap, assessSnap, goalsSnap] = await Promise.all([
        getDocs(collection(db, "subscriptions")).catch(() => ({ docs: [] })),
        getDocs(collection(db, "assessments")).catch(() => ({ docs: [] })),
        getDocs(collection(db, "goals")).catch(() => ({ docs: [] }))
    ]);

    const subsMap: Record<string, SubDocData> = {};
    subsSnap.docs.forEach(d => {
        const data = d.data() as SubDocData;
        const uid = data.userId || data.clientId;
        if (uid && (data.status === "active" || !subsMap[uid])) subsMap[uid] = data;
    });

    const assessMap: Record<string, AssessDocData> = {};
    assessSnap.docs.forEach(d => {
        const data = d.data() as AssessDocData;
        const uid = data.userId || data.clientId || d.id;
        assessMap[uid] = data;
    });

    const goalsMap: Record<string, GoalDocData> = {};
    goalsSnap.docs.forEach(d => {
        const data = d.data() as GoalDocData;
        const uid = data.userId || data.clientId || d.id;
        goalsMap[uid] = data;
    });

    const clientsSnap = await getDocs(query(collection(db, "users"), where("role", "==", "client")));
    const loadedClients: ClientRow[] = [];

    clientsSnap.docs.forEach(docSnap => {
        const data = docSnap.data() as UserDocData;
        const uid = docSnap.id;

        const subData = subsMap[uid];
        const assessData = assessMap[uid];
        const goalData = goalsMap[uid];

        const name = data.fullName || "Unknown Client";
        const trainerId = data.trainerId || subData?.trainerId || null;

        if (trainerId && tempTrainers[trainerId]) {
            tempTrainers[trainerId].clientCount += 1;
        }

        let status: ClientRow["status"] = "assigned";
        if (!trainerId) status = "unassigned";
        if (data.reassignRequest) status = "reassign_request";

        let subText = "Joined recently";
        if (data.createdAt) {
            let createdDate: Date;
            if (typeof data.createdAt === 'object' && data.createdAt !== null && 'toDate' in data.createdAt && typeof data.createdAt.toDate === 'function') {
                createdDate = data.createdAt.toDate();
            } else {
                createdDate = new Date(data.createdAt as string | number);
            }

            const diffTime = Math.abs(new Date().getTime() - createdDate.getTime());
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            if (diffDays < 30) {
                subText = `Joined ${diffDays} days ago`;
            } else {
                const diffMonths = Math.floor(diffDays / 30);
                subText = `Active for ${diffMonths} month${diffMonths > 1 ? 's' : ''}`;
            }
        }

        const actualGoal = extractGoal(data, subData, assessData, goalData);
        const actualPackage = extractPackage(data, subData);

        loadedClients.push({
            id: uid,
            fullName: name,
            initials: name.split(" ").map((n: string) => n[0]).join("").substring(0, 2).toUpperCase(),
            subText: subText,
            packageType: actualPackage,
            primaryGoal: actualGoal,
            goalColor: getGoalColor(actualGoal),
            currentTrainerId: trainerId,
            currentTrainerName: trainerId ? trainersMap[trainerId] : null,
            status: status
        });
    });

    const today = new Date().toISOString().split("T")[0];
    const sessionsSnap = await getDocs(query(collection(db, "sessions"), where("scheduledDate", "==", today)));

    let morningCount = 0;
    let afternoonCount = 0;

    sessionsSnap.docs.forEach(docSnap => {
        const timeStr = (docSnap.data().scheduledTime || docSnap.data().time || "").toUpperCase();
        if (timeStr.includes("AM")) {
            morningCount++;
        } else if (timeStr.includes("PM")) {
            afternoonCount++;
        }
    });

    const activeTrainersCount = Object.keys(tempTrainers).length || 1;
    const maxShiftSlots = activeTrainersCount * 8;
    const morningLoad = Math.min(Math.round((morningCount / maxShiftSlots) * 100), 100);
    const afternoonLoad = Math.min(Math.round((afternoonCount / maxShiftSlots) * 100), 100);

    const unassignedClients = loadedClients.filter(c => c.status !== "assigned");
    const sortedTrainers = Object.values(tempTrainers).sort((a, b) => a.clientCount - b.clientCount);
    const recommendations: Recommendation[] = [];

    unassignedClients.slice(0, 2).forEach((client, index) => {
        const bestTrainer = sortedTrainers[index % sortedTrainers.length];
        if (bestTrainer) {
            const score = Math.max(98 - (bestTrainer.clientCount * 2), 75);
            recommendations.push({
                id: client.id,
                clientName: client.fullName,
                trainerId: bestTrainer.id,
                trainerName: bestTrainer.fullName,
                score: score,
                reason: client.primaryGoal !== "Unspecified" ? `${client.primaryGoal} Match` : "Capacity Match"
            });
        }
    });

    return {
        newTrainers: Object.values(tempTrainers),
        newClients: loadedClients,
        heatmapStats: { morningLoad, afternoonLoad },
        newRecommendations: recommendations
    };
}

export default function AssignDuties() {
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [clients, setClients] = useState<ClientRow[]>([]);
    const [trainers, setTrainers] = useState<Trainer[]>([]);

    // Sort and Filter States
    const [filterTab, setFilterTab] = useState<"all" | "pending" | "assigned">("all");
    const [sortOrder, setSortOrder] = useState<"asc" | "desc">("asc");

    // Dropdown state
    const [dropdownOpen, setDropdownOpen] = useState<string | null>(null);

    const [heatmap, setHeatmap] = useState<HeatmapData>({ morningLoad: 0, afternoonLoad: 0 });
    const [recommendations, setRecommendations] = useState<Recommendation[]>([]);

    const [currentPage, setCurrentPage] = useState(1);
    const ITEMS_PER_PAGE = 5;

    const [modalOpen, setModalOpen] = useState(false);
    const [selectedClient, setSelectedClient] = useState<ClientRow | null>(null);
    const [assigning, setAssigning] = useState(false);

    useEffect(() => {
        let isMounted = true;

        fetchAssignData()
            .then(({ newTrainers, newClients, heatmapStats, newRecommendations }) => {
                if (isMounted) {
                    setTrainers(newTrainers);
                    setClients(newClients);
                    setHeatmap(heatmapStats);
                    setRecommendations(newRecommendations);
                    setLoading(false);
                }
            })
            .catch((error) => {
                console.error("Error loading assign data:", error);
                if (isMounted) setLoading(false);
            });

        return () => { isMounted = false; };
    }, []);

    // Close dropdown when clicking outside
    useEffect(() => {
        const handleClickOutside = () => setDropdownOpen(null);
        window.addEventListener("click", handleClickOutside);
        return () => window.removeEventListener("click", handleClickOutside);
    }, []);

    // --- 1. FILTER & SORT LOGIC ---
    let filteredClients = clients.filter(c => {
        if (filterTab === "all") return true;
        if (filterTab === "pending") return c.status === "unassigned" || c.status === "reassign_request";
        if (filterTab === "assigned") return c.status === "assigned";
        return true;
    });

    filteredClients = filteredClients.sort((a, b) => {
        if (sortOrder === "asc") return a.fullName.localeCompare(b.fullName);
        return b.fullName.localeCompare(a.fullName);
    });

    // --- 2. PAGINATION LOGIC ---
    const totalPages = Math.ceil(filteredClients.length / ITEMS_PER_PAGE) || 1;
    const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
    const paginatedClients = filteredClients.slice(startIndex, startIndex + ITEMS_PER_PAGE);

    const handleTabChange = (tab: "all" | "pending" | "assigned") => {
        setFilterTab(tab);
        setCurrentPage(1);
    };

    // --- 3. EXPORT TO CSV LOGIC ---
    const handleExportCSV = () => {
        const headers = ["Client Name", "Package Type", "Primary Goal", "Current Trainer", "Status"];
        const rows = filteredClients.map(c => [
            `"${c.fullName}"`,
            `"${c.packageType}"`,
            `"${c.primaryGoal}"`,
            `"${c.currentTrainerName || 'Unassigned'}"`,
            `"${c.status}"`
        ]);

        const csvContent = [headers.join(","), ...rows.map(r => r.join(","))].join("\n");
        const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = `client_assignments_${new Date().toISOString().split("T")[0]}.csv`;
        link.style.display = "none";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };

    const openAssignModal = (client: ClientRow) => {
        setSelectedClient(client);
        setModalOpen(true);
    };

    // --- 4. ASSIGN & REMOVE TRAINER LOGIC ---
    const confirmAssignment = async (trainerId: string | null) => {
        if (!selectedClient) return;
        setAssigning(true);
        try {
            await setDoc(doc(db, "users", selectedClient.id), {
                trainerId: trainerId,
                reassignRequest: false
            }, { merge: true });

            const { newTrainers, newClients, heatmapStats, newRecommendations } = await fetchAssignData();
            setTrainers(newTrainers);
            setClients(newClients);
            setHeatmap(heatmapStats);
            setRecommendations(newRecommendations);

            setModalOpen(false);
            setSelectedClient(null);
            setDropdownOpen(null);
        } catch (error) {
            console.error("Failed to update trainer:", error);
        } finally {
            setAssigning(false);
        }
    };

    if (loading) {
        return <Layout title="Assign Duties"><div style={{ padding: 24, color: '#64748b' }}>Loading assignment data...</div></Layout>;
    }

    const unassignedCount = clients.filter(c => c.status === "unassigned").length;
    const requestCount = clients.filter(c => c.status === "reassign_request").length;
    const assignedCount = clients.length - unassignedCount;
    const activeTrainersCount = trainers.length;
    const avgLoad = activeTrainersCount > 0 ? Math.round(assignedCount / activeTrainersCount) : 0;
    const maxCapacityPerTrainer = 15;

    return (
        <Layout title="Assign Duties">
            <div className="ad-nav-row">
                <button className="ad-back-btn" onClick={() => navigate("/trainers")}>
                    <i className="bx bx-arrow-back" style={{ fontSize: '18px' }} /> Back to Trainer
                </button>
            </div>

            <div className="ad-stats-row">
                <div className="ad-stat-card">
                    <div className="ad-stat-icon red-icon"><i className="bx bx-user-x" /></div>
                    <div className="ad-stat-info">
                        <div className="ad-stat-label">UNASSIGNED CLIENTS</div>
                        <div className="ad-stat-value">{String(unassignedCount).padStart(2, '0')}</div>
                    </div>
                </div>

                <div className="ad-stat-card">
                    <div className="ad-stat-icon blue-icon"><i className="bx bx-pie-chart-alt-2" /></div>
                    <div className="ad-stat-info">
                        <div className="ad-stat-label">AVG TRAINER LOAD</div>
                        <div className="ad-stat-value">{avgLoad}/ <span className="ad-stat-value-light">{maxCapacityPerTrainer}</span></div>
                    </div>
                </div>

                <div className="ad-stat-card">
                    <div className="ad-stat-icon teal-icon"><i className="bx bx-hourglass" /></div>
                    <div className="ad-stat-info">
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
                    <div className="ad-table-actions">
                        {/* TOGGLE SORT BUTTON */}
                        <button className="ad-icon-btn" onClick={() => setSortOrder(prev => prev === "asc" ? "desc" : "asc")} title="Sort A-Z / Z-A">
                            <i className={sortOrder === "asc" ? "bx bx-sort-a-z" : "bx bx-sort-z-a"}></i>
                        </button>
                        {/* DOWNLOAD CSV BUTTON */}
                        <button className="ad-icon-btn" onClick={handleExportCSV} title="Download CSV">
                            <i className="bx bx-download"></i>
                        </button>
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
                                            {client.status === "unassigned" && (
                                                <button className="ad-btn-solid-red" onClick={() => openAssignModal(client)}>
                                                    Assign Trainer
                                                </button>
                                            )}
                                            {client.status === "reassign_request" && (
                                                <button className="ad-btn-text-red" onClick={() => openAssignModal(client)}>
                                                    Review Change
                                                </button>
                                            )}
                                            {/* 3-DOTS MENU */}
                                            {client.status === "assigned" && (
                                                <div className="ad-dropdown-container">
                                                    <button
                                                        className="ad-btn-icon-only"
                                                        title="Options"
                                                        onClick={(e) => {
                                                            e.stopPropagation();
                                                            setDropdownOpen(dropdownOpen === client.id ? null : client.id);
                                                        }}
                                                    >
                                                        <i className="bx bx-dots-vertical-rounded"></i>
                                                    </button>
                                                    {dropdownOpen === client.id && (
                                                        <div className="ad-dropdown-menu" onClick={(e) => e.stopPropagation()}>
                                                            <button onClick={() => { setDropdownOpen(null); openAssignModal(client); }}>
                                                                <i className="bx bx-transfer-alt"></i> Change Trainer
                                                            </button>
                                                            <button className="text-red" onClick={() => { setSelectedClient(client); confirmAssignment(null); }}>
                                                                <i className="bx bx-trash"></i> Remove Trainer
                                                            </button>
                                                        </div>
                                                    )}
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
                        Showing {filteredClients.length > 0 ? startIndex + 1 : 0}-{Math.min(startIndex + ITEMS_PER_PAGE, filteredClients.length)} of {filteredClients.length} clients
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

            <div className="ad-bottom-grid">
                <div className="ad-bottom-card">
                    <div className="ad-card-header">
                        <h3>Trainer Availability Heatmap</h3>
                        <i className="bx bx-info-circle"></i>
                    </div>

                    <div className="ad-heatmap-row">
                        <div className="ad-heatmap-labels">
                            <span className="ad-hm-time">Morning Shift (3AM - 11AM)</span>
                            <span className={heatmap.morningLoad > 70 ? "ad-hm-high" : "ad-hm-optimal"}>
                                {heatmap.morningLoad > 70 ? `High Load (${heatmap.morningLoad}%)` : `Optimal (${heatmap.morningLoad}%)`}
                            </span>
                        </div>
                        <div className="ad-progress-bar">
                            <div className={`fill ${heatmap.morningLoad > 70 ? 'red' : 'blue'}`} style={{ width: `${heatmap.morningLoad}%` }}></div>
                        </div>
                    </div>

                    <div className="ad-heatmap-row">
                        <div className="ad-heatmap-labels">
                            <span className="ad-hm-time">Afternoon Shift (11AM - 11PM)</span>
                            <span className={heatmap.afternoonLoad > 70 ? "ad-hm-high" : "ad-hm-optimal"}>
                                {heatmap.afternoonLoad > 70 ? `High Load (${heatmap.afternoonLoad}%)` : `Optimal (${heatmap.afternoonLoad}%)`}
                            </span>
                        </div>
                        <div className="ad-progress-bar">
                            <div className={`fill ${heatmap.afternoonLoad > 70 ? 'red' : 'blue'}`} style={{ width: `${heatmap.afternoonLoad}%` }}></div>
                        </div>
                    </div>
                </div>

                <div className="ad-bottom-card">
                    <div className="ad-card-header">
                        <h3>Recommended Pairings</h3>
                        <span className="ad-ai-badge">AI DRIVEN</span>
                    </div>

                    <div className="ad-ai-list">
                        {recommendations.length === 0 ? (
                            <p style={{ color: '#64748b', fontSize: '13px' }}>All clients are currently assigned.</p>
                        ) : (
                            recommendations.map(rec => (
                                <div
                                    key={rec.id}
                                    className="ad-ai-item"
                                    onClick={() => {
                                        const c = clients.find(cl => cl.id === rec.id);
                                        if (c) openAssignModal(c);
                                    }}
                                >
                                    <div className="ad-ai-icon"><i className="bx bx-git-merge"></i></div>
                                    <div className="ad-ai-info">
                                        <div className="ad-ai-title">{rec.clientName} <i className="bx bx-right-arrow-alt"></i> {rec.trainerName}</div>
                                        <div className="ad-ai-sub">Match score: {rec.score}% ({rec.reason})</div>
                                    </div>
                                    <i className="bx bx-chevron-right ad-ai-arrow"></i>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </div>

            {/* ASSIGN TRAINER MODAL */}
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
                                    <p style={{ textAlign: 'center', color: '#64748b' }}>No trainers available in the system.</p>
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