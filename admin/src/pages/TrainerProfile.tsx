import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { collection, getDocs, doc, getDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/trainerProfile.css";
import "../styles/sessions.css";

interface TrainerDetails {
    id: string;
    fullName: string;
    initials: string;
    photoURL: string | null;
    designation: string;
    yearsExperience: number;
    phone: string;
    email: string;
    certifications: string[];
}

interface TrainerStats {
    totalUsers: number;
    sessionsThisWeek: number;
    doneThisWeek: number;
    completionRate: number;
}

interface SessionData {
    id: string;
    scheduledDate: string;
    scheduledTime: string;
    clientName: string;
    area: string;
    service: string;
    status: string;
    notes: string;
}

interface DaySummary {
    dateStr: string;
    dayName: string;
    dayNum: string;
    totalSessions: number;
    completedSessions: number;
}

// Ensure the week starts perfectly at midnight (Monday start)
function getStartOfWeek(date: Date) {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
}

const PAGE_SIZE = 5;

export default function TrainerProfile() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [trainer, setTrainer] = useState<TrainerDetails | null>(null);
    const [stats, setStats] = useState<TrainerStats>({
        totalUsers: 0,
        sessionsThisWeek: 0,
        doneThisWeek: 0,
        completionRate: 0,
    });
    const [sessions, setSessions] = useState<SessionData[]>([]);
    const [weekDays, setWeekDays] = useState<DaySummary[]>([]);
    const [viewMode, setViewMode] = useState<"week" | "day">("week");
    const [selectedDate, setSelectedDate] = useState<string>("");

    const [page, setPage] = useState(1);

    useEffect(() => {
        if (!id) return;

        async function loadData() {
            try {
                // 1. Get Trainer User Doc
                const userDoc = await getDoc(doc(db, "users", id!));
                const userData = userDoc.exists() ? userDoc.data() : {};

                // 2. Get Trainer Profile Doc
                const trainersSnap = await getDocs(collection(db, "trainers"));
                const trainerDoc = trainersSnap.docs.find(d => d.data().trainerId === id || d.id === id);
                const trainerData = trainerDoc ? trainerDoc.data() : {};

                const fullName = userData.fullName || trainerData.fullName || "Unknown Trainer";
                const initials = fullName.split(" ").map((n: string) => n[0]).join("").substring(0, 2).toUpperCase();
                const photoURL = userData.photoURL || trainerData.photoURL || null;

                setTrainer({
                    id: id!,
                    fullName,
                    initials,
                    photoURL,
                    designation: trainerData.designation || "Senior Trainer",
                    yearsExperience: trainerData.yearsExperience || 0,
                    phone: userData.phone || "+91 —",
                    email: userData.email || "No email provided",
                    certifications: trainerData.certifications || [],
                });

                // 3. Generate the 7 days of the current week
                const today = new Date();
                today.setHours(0, 0, 0, 0);
                const startOfWeek = getStartOfWeek(today);
                const daysArray: DaySummary[] = [];

                for (let i = 0; i < 7; i++) {
                    const d = new Date(startOfWeek);
                    d.setDate(d.getDate() + i);

                    // Format strictly as YYYY-MM-DD local time
                    const y = d.getFullYear();
                    const m = String(d.getMonth() + 1).padStart(2, '0');
                    const dayNum = String(d.getDate()).padStart(2, '0');
                    const dateStr = `${y}-${m}-${dayNum}`;

                    daysArray.push({
                        dateStr,
                        dayName: d.toLocaleDateString("en-US", { weekday: "short" }),
                        dayNum: dayNum,
                        totalSessions: 0,
                        completedSessions: 0,
                    });
                }

                const todayY = today.getFullYear();
                const todayM = String(today.getMonth() + 1).padStart(2, '0');
                const todayD = String(today.getDate()).padStart(2, '0');
                const todayStr = `${todayY}-${todayM}-${todayD}`;

                const isTodayInWeek = daysArray.some(d => d.dateStr === todayStr);
                setSelectedDate(isTodayInWeek ? todayStr : daysArray[0].dateStr);

                // 4. Fetch Users mapping for Client Names
                const allUsersSnap = await getDocs(collection(db, "users"));
                const usersMap = new Map(allUsersSnap.docs.map(d => [d.id, d.data().fullName]));

                // 5. Fetch ALL sessions and filter perfectly in-memory
                const sessionsSnap = await getDocs(collection(db, "sessions"));

                const loadedSessions: SessionData[] = [];
                const uniqueClients = new Set<string>();
                let totalSess = 0;
                let doneSess = 0;

                for (const docSnap of sessionsSnap.docs) {
                    const data = docSnap.data();

                    // Ensure this session belongs to THIS trainer
                    const isMatch = data.trainerId === id || data.trainerName === fullName || data.trainer === fullName;
                    if (!isMatch) continue;

                    // Parse Date accurately (Handle Timestamp, string, etc.)
                    let dateObj: Date | null = null;
                    const rawDate = data.scheduledDate || data.date || data.sessionDate || data.createdAt;
                    if (rawDate) {
                        if (typeof rawDate.toDate === "function") dateObj = rawDate.toDate();
                        else dateObj = new Date(rawDate);
                    }
                    if (!dateObj || isNaN(dateObj.getTime())) continue;

                    // Convert session date to matching YYYY-MM-DD
                    const sY = dateObj.getFullYear();
                    const sM = String(dateObj.getMonth() + 1).padStart(2, '0');
                    const sD = String(dateObj.getDate()).padStart(2, '0');
                    const sessionDateStr = `${sY}-${sM}-${sD}`;

                    // Check if the session falls in the current week we generated
                    const dayObj = daysArray.find(d => d.dateStr === sessionDateStr);
                    if (!dayObj) continue; // Skip if it's from a different week

                    let clientName = data.clientName || data.client;
                    if (!clientName && data.clientId) {
                        clientName = usersMap.get(data.clientId);
                    }

                    const isCompleted = ["completed", "complete", "done"].includes((data.status || "").toLowerCase());

                    loadedSessions.push({
                        id: docSnap.id,
                        scheduledDate: sessionDateStr,
                        scheduledTime: data.scheduledTime || data.time || "—",
                        clientName: clientName || "Unknown Client",
                        area: data.area || "—",
                        service: data.serviceType || data.service || "—",
                        status: isCompleted ? "Done" : (data.status || "Upcoming"),
                        notes: data.notes || data.sessionNotes || data.trainerNotes || "",
                    });

                    dayObj.totalSessions += 1;
                    if (isCompleted) dayObj.completedSessions += 1;

                    if (data.clientId) uniqueClients.add(data.clientId);
                    totalSess++;
                    if (isCompleted) doneSess++;
                }

                // Sort by Date, then by Time
                loadedSessions.sort((a, b) => {
                    if (a.scheduledDate === b.scheduledDate) {
                        return a.scheduledTime.localeCompare(b.scheduledTime);
                    }
                    return a.scheduledDate.localeCompare(b.scheduledDate);
                });

                setSessions(loadedSessions);
                setWeekDays(daysArray);
                setStats({
                    totalUsers: uniqueClients.size,
                    sessionsThisWeek: totalSess,
                    doneThisWeek: doneSess,
                    completionRate: totalSess > 0 ? Math.round((doneSess / totalSess) * 100) : 0,
                });

            } catch (error) {
                console.error("Error fetching trainer data:", error);
            } finally {
                setLoading(false);
            }
        }

        loadData();
    }, [id]);

    if (loading) {
        return <Layout title="View Profile"><div style={{ padding: "24px", color: "#9ca3af" }}>Loading profile...</div></Layout>;
    }
    if (!trainer) {
        return <Layout title="View Profile"><div style={{ padding: "24px", color: "red" }}>Trainer not found.</div></Layout>;
    }

    const filteredSessions = viewMode === "week"
        ? sessions
        : sessions.filter(s => s.scheduledDate === selectedDate);

    // Pagination logic
    const totalPages = Math.max(1, Math.ceil(filteredSessions.length / PAGE_SIZE));
    const pageRows = filteredSessions.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

    const weekStartFormat = weekDays[0] ? new Date(weekDays[0].dateStr).toLocaleDateString("en-US", { month: "long", day: "numeric" }) : "";
    const weekEndFormat = weekDays[6] ? new Date(weekDays[6].dateStr).toLocaleDateString("en-US", { day: "numeric", year: "numeric" }) : "";

    let dayHeaderStr = "";
    if (viewMode === "day" && selectedDate) {
        // Prevent JS from shifting timezone back 1 day by appending T00:00:00
        const d = new Date(`${selectedDate}T00:00:00`);
        dayHeaderStr = d.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
    }

    return (
        <Layout title="View Profile">
            {/* Top Navigation */}
            <div className="tp-nav-row">
                <button className="tp-back-btn" onClick={() => navigate("/trainers")}>
                    <i className="bx bx-arrow-back" style={{ fontSize: '18px' }} /> Back to Trainer
                </button>
            </div>

            {/* Blue Info Banner */}
            <div className="tp-banner-card">
                <div className="tp-banner-left">

                    {/* conditionally render image or initials */}
                    {trainer.photoURL ? (
                        <img
                            src={trainer.photoURL}
                            alt={trainer.fullName}
                            className="tp-avatar"
                            style={{ objectFit: 'cover' }}
                        />
                    ) : (
                        <div className="tp-avatar">{trainer.initials}</div>
                    )}

                    <div className="tp-info">
                        <h2 className="tp-name">{trainer.fullName}</h2>
                        <p className="tp-subtitle">
                            {trainer.designation} &nbsp;.&nbsp; {trainer.yearsExperience} yrs experience
                        </p>
                        <div className="tp-contact">
                            <span><i className="bx bxs-phone" /> {trainer.phone}</span>
                            <span className="tp-email"><i className="bx bx-envelope" /> {trainer.email}</span>
                        </div>
                        <div className="tp-cert-badges">
                            {trainer.certifications.length > 0 ? (
                                trainer.certifications.map((cert, idx) => (
                                    <span key={idx} className="tp-badge">{cert}</span>
                                ))
                            ) : (
                                <>
                                    <span className="tp-badge">ISSA Certified Personal Trainer</span>
                                    <span className="tp-badge">CPR & First Aid</span>
                                </>
                            )}
                        </div>
                    </div>
                </div>

                <div className="tp-banner-right">
                    <div className="tp-stat-block">
                        <span className="tp-stat-value">{stats.totalUsers}</span>
                        <span className="tp-stat-label">Users</span>
                    </div>
                    <div className="tp-stat-divider"></div>
                    <div className="tp-stat-block">
                        <span className="tp-stat-value">{stats.sessionsThisWeek}</span>
                        <span className="tp-stat-label">Sessions/ Week</span>
                    </div>
                    <div className="tp-stat-divider"></div>
                    <div className="tp-stat-block">
                        <span className="tp-stat-value">{stats.doneThisWeek}</span>
                        <span className="tp-stat-label">Done this week</span>
                    </div>
                    <div className="tp-stat-divider"></div>
                    <div className="tp-stat-block">
                        <span className="tp-stat-value">{stats.completionRate}%</span>
                        <span className="tp-stat-label">Completion rate</span>
                    </div>
                </div>
            </div>

            {/* View Controls & Day Cards */}
            <div className="tp-controls-row">
                <div className="tp-toggle-group">
                    <button
                        className={`tp-toggle-btn ${viewMode === "week" ? "active" : ""}`}
                        onClick={() => {
                            setViewMode("week");
                            setPage(1); // Safely reset page on click
                        }}
                    >
                        <i className="bx bx-calendar-event" /> Week View
                    </button>
                    <button
                        className={`tp-toggle-btn ${viewMode === "day" ? "active" : ""}`}
                        onClick={() => {
                            setViewMode("day");
                            setPage(1); // Safely reset page on click
                        }}
                    >
                        <i className="bx bx-file" /> Day View
                    </button>
                </div>

                <div className="tp-days-scroll">
                    {weekDays.map((day, index) => {
                        const isActive = viewMode === "day" && selectedDate === day.dateStr;
                        const progPct = day.totalSessions > 0 ? (day.completedSessions / day.totalSessions) * 100 : 0;

                        return (
                            <div
                                key={index}
                                className={`tp-day-card ${isActive ? "active" : ""}`}
                                onClick={() => {
                                    setViewMode("day");
                                    setSelectedDate(day.dateStr);
                                    setPage(1); // Safely reset page on click
                                }}
                            >
                                <div className="tp-day-header">
                                    <span className="tp-day-name">{day.dayName.toUpperCase()} <span className="tp-day-num">{day.dayNum}</span></span>
                                </div>
                                <div className="tp-day-sub">
                                    {isActive && <span className="tp-dot-indicator"></span>}
                                    {day.totalSessions} Sessions
                                </div>
                                <div className="tp-progress-bar">
                                    <div
                                        className={`tp-progress-fill ${isActive ? 'light' : 'green'}`}
                                        style={{ width: `${progPct}%` }}
                                    ></div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>

            {/* NEW STANDARD SESSIONS TABLE */}
            <div className="sessions-table-card" style={{ marginTop: "24px" }}>

                {/* TABLE HEADER */}
                <div className="sessions-table-header">
                    <h3 className="sessions-table-title">
                        {viewMode === "week"
                            ? `Full Schedule - Week, ${weekStartFormat} - ${weekEndFormat}`
                            : `Full Schedule - ${dayHeaderStr}`
                        }
                    </h3>
                    <button
                        className="sessions-action-btn"
                        onClick={() => navigate('/sessions')}
                        style={{ border: "none", color: "#00225d", display: "flex", alignItems: "center", gap: "6px", fontWeight: "700" }}
                    >
                        <i className="bx bx-calendar" /> All Sessions
                    </button>
                </div>

                {/* TABLE */}
                <div style={{ overflowX: "auto" }}>
                    <table className="sessions-table">
                        <thead>
                            <tr>
                                <th>TIME</th>
                                <th>CLIENT</th>
                                <th>AREA</th>
                                <th>SERVICE</th>
                                <th>STATUS</th>
                                <th>NOTES</th>
                            </tr>
                        </thead>
                        <tbody>
                            {pageRows.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ textAlign: "center", color: "#94a3b8", padding: "32px" }}>
                                        No sessions scheduled for this period.
                                    </td>
                                </tr>
                            ) : (
                                pageRows.map((row) => {
                                    const statusLower = row.status.toLowerCase();
                                    const statusClass =
                                        (statusLower === "done" || statusLower === "completed") ? "done" :
                                            statusLower === "live" ? "live" : "upcoming";

                                    return (
                                        <tr key={row.id}>
                                            <td className="sessions-mono" style={{ color: statusLower === 'live' || row.scheduledTime.includes('10:00') ? '#bb0013' : 'inherit' }}>
                                                {/* In week view, stack the date above the time. In day view, just show time. */}
                                                {viewMode === "week" && row.scheduledDate ? (
                                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                                                        <span style={{ fontSize: '10px', color: '#808080', textTransform: 'uppercase' }}>
                                                            {new Date(`${row.scheduledDate}T00:00:00`).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                                                        </span>
                                                        <span>{row.scheduledTime}</span>
                                                    </div>
                                                ) : (
                                                    row.scheduledTime
                                                )}
                                            </td>
                                            <td className="sessions-bold">{row.clientName}</td>
                                            <td>{row.area}</td>
                                            <td>
                                                <span className="sessions-service-pill">
                                                    {row.service}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`sessions-status-pill ${statusClass}`}>
                                                    {statusLower === "live" && <div className="live-dot"></div>}
                                                    {row.status === "completed" || row.status === "Complete" ? "Done" : row.status}
                                                </span>
                                            </td>
                                            <td style={{ color: "#808080", fontSize: "13px" }}>
                                                {row.notes || "—"}
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>

                {/* TABLE FOOTER (PAGINATION) */}
                {filteredSessions.length > 0 && (
                    <div className="sessions-table-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span>
                            Showing {pageRows.length} of {filteredSessions.length} {viewMode === "week" ? "weekly" : "daily"} sessions
                        </span>

                        <div style={{ display: "flex", gap: "8px" }}>
                            <button
                                disabled={page === 1}
                                onClick={() => setPage((p) => Math.max(1, p - 1))}
                                className="sessions-action-btn"
                                style={{ opacity: page === 1 ? 0.5 : 1 }}
                            >
                                <i className="bx bx-chevron-left" style={{ fontSize: '16px', verticalAlign: 'middle' }} />
                            </button>
                            <button
                                disabled={page === totalPages}
                                onClick={() => setPage((p) => Math.max(totalPages, p + 1))}
                                className="sessions-action-btn"
                                style={{ opacity: page === totalPages ? 0.5 : 1 }}
                            >
                                <i className="bx bx-chevron-right" style={{ fontSize: '16px', verticalAlign: 'middle' }} />
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </Layout>
    );
}