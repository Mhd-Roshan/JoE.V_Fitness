import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { collection, query, where, getDocs, doc, getDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/trainerProfile.css";

interface TrainerDetails {
    id: string;
    fullName: string;
    initials: string;
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

function getStartOfWeek(date: Date) {
    const d = new Date(date);
    const day = d.getDay(),
        diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
}

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

    useEffect(() => {
        if (!id) return;

        async function loadData() {
            try {
                const userDoc = await getDoc(doc(db, "users", id!));
                const userData = userDoc.exists() ? userDoc.data() : {};

                const trainerQuery = await getDocs(
                    query(collection(db, "trainers"), where("trainerId", "==", id))
                );
                const trainerData = trainerQuery.docs[0]?.data() ?? {};

                const fullName = userData.fullName || "Unknown Trainer";
                const initials = fullName.split(" ").map((n: string) => n[0]).join("").substring(0, 2).toUpperCase();

                setTrainer({
                    id: id!,
                    fullName,
                    initials,
                    designation: trainerData.designation || "Senior Trainer",
                    yearsExperience: trainerData.yearsExperience || 0,
                    phone: userData.phone || "+91 —",
                    email: userData.email || "No email provided",
                    certifications: trainerData.certifications || [],
                });

                const today = new Date();
                const startOfWeek = getStartOfWeek(today);
                const daysArray: DaySummary[] = [];

                for (let i = 0; i < 7; i++) {
                    const d = new Date(startOfWeek);
                    d.setDate(d.getDate() + i);
                    daysArray.push({
                        dateStr: d.toISOString().split("T")[0],
                        dayName: d.toLocaleDateString("en-US", { weekday: "short" }),
                        dayNum: d.toLocaleDateString("en-US", { day: "2-digit" }),
                        totalSessions: 0,
                        completedSessions: 0,
                    });
                }

                const startStr = daysArray[0].dateStr;
                const endStr = daysArray[6].dateStr;

                const todayStr = today.toISOString().split("T")[0];
                const isTodayInWeek = daysArray.some(d => d.dateStr === todayStr);
                setSelectedDate(isTodayInWeek ? todayStr : startStr);

                const sessionsSnap = await getDocs(
                    query(
                        collection(db, "sessions"),
                        where("trainerId", "==", id),
                        where("scheduledDate", ">=", startStr),
                        where("scheduledDate", "<=", endStr)
                    )
                );

                const loadedSessions: SessionData[] = [];
                const uniqueClients = new Set<string>();
                let totalSess = 0;
                let doneSess = 0;

                for (const docSnap of sessionsSnap.docs) {
                    const data = docSnap.data();

                    let clientName = data.clientName;
                    if (!clientName && data.clientId) {
                        const clientDoc = await getDoc(doc(db, "users", data.clientId));
                        if (clientDoc.exists()) clientName = clientDoc.data().fullName;
                    }

                    if (data.clientId) uniqueClients.add(data.clientId);

                    const isCompleted = data.status === "completed" || data.status === "Complete" || data.status === "Done";

                    loadedSessions.push({
                        id: docSnap.id,
                        scheduledDate: data.scheduledDate,
                        scheduledTime: data.scheduledTime || "TBD",
                        clientName: clientName || "Unknown Client",
                        area: data.area || "—",
                        service: data.serviceType || data.service || "—",
                        status: isCompleted ? "Done" : "Pending",
                        notes: data.notes || "",
                    });

                    const dayObj = daysArray.find(d => d.dateStr === data.scheduledDate);
                    if (dayObj) {
                        dayObj.totalSessions += 1;
                        if (isCompleted) dayObj.completedSessions += 1;
                    }

                    totalSess++;
                    if (isCompleted) doneSess++;
                }

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
        return <Layout title="View Profile"><div style={{ padding: "24px" }}>Loading profile...</div></Layout>;
    }
    if (!trainer) {
        return <Layout title="View Profile"><div style={{ padding: "24px", color: "red" }}>Trainer not found.</div></Layout>;
    }

    const displaySessions = viewMode === "week"
        ? sessions
        : sessions.filter(s => s.scheduledDate === selectedDate);

    const weekStartFormat = weekDays[0] ? new Date(weekDays[0].dateStr).toLocaleDateString("en-US", { month: "long", day: "numeric" }) : "";
    const weekEndFormat = weekDays[6] ? new Date(weekDays[6].dateStr).toLocaleDateString("en-US", { day: "numeric", year: "numeric" }) : "";

    let dayHeaderStr = "";
    if (viewMode === "day" && selectedDate) {
        const d = new Date(selectedDate);
        const dateStr = d.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
        dayHeaderStr = dateStr;
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
                    <div className="tp-avatar">{trainer.initials}</div>
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
                        onClick={() => setViewMode("week")}
                    >
                        <i className="bx bx-calendar-event" /> Week View
                    </button>
                    <button
                        className={`tp-toggle-btn ${viewMode === "day" ? "active" : ""}`}
                        onClick={() => setViewMode("day")}
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

            {/* Schedule Header */}
            <div className="tp-schedule-container">
                <div className="tp-schedule-header">
                    <h3 className="tp-schedule-title">
                        {viewMode === "week"
                            ? `Full Schedule - Week, ${weekStartFormat} -${weekEndFormat.split(",")[0]} ${weekEndFormat.split(",")[1]}`
                            : `Full Schedule - ${dayHeaderStr}`
                        }
                    </h3>
                    <button className="tp-outline-btn">
                        <i className="bx bx-calendar" style={{ fontSize: '16px' }} /> All Sessions
                    </button>
                </div>

                {displaySessions.length === 0 ? (
                    <div className="tp-empty-state">No sessions scheduled for this period.</div>
                ) : (
                    <>
                        {/* =========================================
                            WEEK VIEW (Solid Table layout)
                        ========================================= */}
                        {viewMode === "week" && (
                            <div className="tp-table-card">
                                <div className="tp-table-responsive">
                                    <table className="tp-table">
                                        <thead>
                                            <tr>
                                                <th>DAY</th>
                                                <th>TIME</th>
                                                <th>USER</th>
                                                <th>AREA</th>
                                                <th>SERVICE</th>
                                                <th>STATUS</th>
                                                <th>NOTES</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {displaySessions.map((session, index) => {
                                                const showDateGroup = index === 0 || displaySessions[index - 1].scheduledDate !== session.scheduledDate;
                                                const d = new Date(session.scheduledDate);
                                                const displayDay = d.toLocaleDateString("en-US", { weekday: "short" });
                                                const displayNum = d.toLocaleDateString("en-US", { day: "numeric" });
                                                const displayMonth = d.toLocaleDateString("en-US", { month: "short", day: "numeric" });

                                                // Pattern styling like in the image
                                                const borderClass = (index % 2 === 0) ? "border-blue" : "border-red";

                                                return (
                                                    <tr key={session.id}>
                                                        <td className="tp-cell-day">
                                                            {showDateGroup && (
                                                                <div className={`tp-day-group ${borderClass}`}>
                                                                    <div className="tp-day-group-main">{displayDay} {displayNum}</div>
                                                                    <div className="tp-day-group-sub">{displayMonth}</div>
                                                                </div>
                                                            )}
                                                        </td>
                                                        <td className="tp-mono-text">{session.scheduledTime}</td>
                                                        <td className="tp-bold-text">{session.clientName}</td>
                                                        <td className="tp-area-text">{session.area}</td>
                                                        <td className="tp-service-text">{session.service}</td>
                                                        <td>
                                                            <span className={`tp-status-pill ${session.status === "Done" ? "done" : "pending"}`}>
                                                                {session.status}
                                                            </span>
                                                        </td>
                                                        <td className="tp-notes-cell">{session.notes || "—"}</td>
                                                    </tr>
                                                );
                                            })}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}

                        {/* =========================================
                            DAY VIEW (Separated Cards Layout)
                        ========================================= */}
                        {viewMode === "day" && (
                            <div className="tp-day-view-wrapper">
                                <div className="tp-day-header-row tp-grid-6">
                                    <div>TIME</div>
                                    <div>USER</div>
                                    <div>AREA</div>
                                    <div>SERVICE</div>
                                    <div>STATUS</div>
                                    <div>NOTES</div>
                                </div>

                                <div className="tp-day-cards-list">
                                    {displaySessions.map((session) => (
                                        <div key={session.id} className="tp-day-card-row tp-grid-6">
                                            <div className="tp-mono-text">{session.scheduledTime}</div>
                                            <div className="tp-bold-text">{session.clientName}</div>
                                            <div className="tp-area-text">{session.area}</div>
                                            <div className="tp-service-text">{session.service}</div>
                                            <div>
                                                <span className={`tp-status-pill ${session.status === "Done" ? "done" : "pending"}`}>
                                                    {session.status}
                                                </span>
                                            </div>
                                            <div className="tp-notes-cell">{session.notes || "—"}</div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {/* Pagination Footer */}
                        <div className="tp-pagination">
                            <span className="tp-page-info">
                                Showing 1 to {displaySessions.length} of {viewMode === "week" ? "weekly" : "daily"} sessions
                            </span>
                            <div className="tp-page-controls">
                                <button><i className="bx bx-chevron-left" /></button>
                                <button><i className="bx bx-chevron-right" /></button>
                            </div>
                        </div>
                    </>
                )}
            </div>
        </Layout>
    );
}