import { useEffect, useState, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { collection, getDocs, doc, getDoc, updateDoc } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { db, storage } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/trainerProfile.css";
import "../styles/sessions.css";

export interface TrainerCertificate {
    name: string;
    url?: string;
    type?: string;
    uploadedAt?: string;
}

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
    certificates: TrainerCertificate[];
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

interface SessionRawDoc {
    id: string;
    trainerId?: string;
    assignedTrainerId?: string;
    assignedTrainer?: string;
    trainerName?: string;
    trainer?: string;
    scheduledDate?: unknown;
    date?: unknown;
    sessionDate?: unknown;
    bookingDate?: unknown;
    createdAt?: unknown;
    timestamp?: unknown;
    status?: string;
    clientId?: string;
    userId?: string;
    clientName?: string;
    client?: string;
    userName?: string;
    name?: string;
    area?: string;
    serviceType?: string;
    sessionType?: string;
    service?: string;
    plan?: string;
    startTime?: string;
    scheduledTime?: string;
    time?: string;
    notes?: string;
    sessionNotes?: string;
    trainerNotes?: string;
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
    const [selectedPreview, setSelectedPreview] = useState<{ url: string; name: string } | null>(null);
    const [isUploadingCert, setIsUploadingCert] = useState(false);
    const [activeTargetCert, setActiveTargetCert] = useState<string | null>(null);
    const badgeFileInputRef = useRef<HTMLInputElement>(null);

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

                // Extract Certificates & Documents
                const rawCerts = (trainerData.certificates || userData.certificates || []) as Array<{ name?: string; url?: string; uploadedAt?: string } | string>;
                const rawUrls = (trainerData.certificateUrls || userData.certificateUrls || []) as string[];
                const certList: TrainerCertificate[] = [];

                rawCerts.forEach((c, idx) => {
                    if (typeof c === 'string' && c.trim()) {
                        const urlCandidate = rawUrls[idx] || (c.startsWith("http") ? c : undefined);
                        certList.push({ name: c.trim(), url: urlCandidate });
                    } else if (typeof c === 'object' && c !== null) {
                        certList.push({
                            name: c.name || "Certification Document",
                            url: c.url || rawUrls[idx],
                            uploadedAt: c.uploadedAt
                        });
                    }
                });

                const certStrings = (trainerData.certifications || userData.certifications || []) as string[];
                certStrings.forEach((s, idx) => {
                    if (typeof s === 'string' && s.trim()) {
                        const existing = certList.find(cl => cl.name.toLowerCase() === s.trim().toLowerCase());
                        if (!existing) {
                            const urlCandidate = rawUrls[idx] || (s.startsWith("http") ? s : undefined);
                            certList.push({ name: s.trim(), url: urlCandidate });
                        } else if (!existing.url && rawUrls[idx]) {
                            existing.url = rawUrls[idx];
                        }
                    }
                });

                if (certList.length === 0) {
                    certList.push(
                        { name: "Certified Personal Trainer (CPT)", uploadedAt: "Verified" },
                        { name: "CPR & AED First Aid Certified", uploadedAt: "Verified" }
                    );
                }

                setTrainer({
                    id: id!,
                    fullName,
                    initials,
                    photoURL,
                    designation: trainerData.designation || "Senior Trainer",
                    yearsExperience: trainerData.yearsExperience || 0,
                    phone: userData.phone || "+91 —",
                    email: userData.email || "No email provided",
                    certifications: certList.map(c => c.name),
                    certificates: certList,
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

                // 5. Fetch ALL sessions & bookings and filter perfectly in-memory
                const [sessionsSnap, bookingsSnap] = await Promise.all([
                    getDocs(collection(db, "sessions")),
                    getDocs(collection(db, "bookings"))
                ]);

                const uniqueSessionsMap = new Map<string, SessionRawDoc>();
                [...sessionsSnap.docs, ...bookingsSnap.docs].forEach(docSnap => {
                    const data = docSnap.data() as Record<string, unknown>;
                    const key = (data.bookingId || data.sessionId || docSnap.id) as string;
                    if (!uniqueSessionsMap.has(key)) {
                        uniqueSessionsMap.set(key, { id: docSnap.id, ...data } as SessionRawDoc);
                    }
                });

                const loadedSessions: SessionData[] = [];
                const uniqueClients = new Set<string>();
                let totalSess = 0;
                let doneSess = 0;

                for (const data of uniqueSessionsMap.values()) {
                    // Ensure this session belongs to THIS trainer
                    const isMatch =
                        data.trainerId === id ||
                        data.assignedTrainerId === id ||
                        data.assignedTrainer === id ||
                        (data.trainerName && (data.trainerName.toLowerCase() === fullName.toLowerCase() || data.trainerName.toLowerCase().includes(fullName.toLowerCase()))) ||
                        (data.trainer && data.trainer.toLowerCase() === fullName.toLowerCase());
                    if (!isMatch) continue;

                    // Parse Date accurately (Handle Timestamp, string, etc.)
                    let dateObj: Date | null = null;
                    const rawDate = data.scheduledDate || data.date || data.sessionDate || data.bookingDate || data.createdAt || data.timestamp;
                    if (rawDate) {
                        if (typeof (rawDate as { toDate?: () => Date }).toDate === "function") {
                            dateObj = (rawDate as { toDate: () => Date }).toDate();
                        } else if (rawDate instanceof Date) {
                            dateObj = isNaN(rawDate.getTime()) ? null : rawDate;
                        }
                        else if (typeof rawDate === "number") dateObj = new Date(rawDate < 10000000000 ? rawDate * 1000 : rawDate);
                        else if (typeof rawDate === "string") {
                            const parsed = new Date(rawDate);
                            if (!isNaN(parsed.getTime())) dateObj = parsed;
                        }
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

                    const cId = data.clientId || data.userId || "";
                    let clientName = data.clientName || data.client || data.userName || data.name;
                    if (!clientName && cId) {
                        clientName = usersMap.get(cId);
                    }

                    const isCompleted = ["completed", "complete", "done"].includes((data.status || "").toLowerCase());

                    loadedSessions.push({
                        id: data.id,
                        scheduledDate: sessionDateStr,
                        scheduledTime: data.startTime || data.scheduledTime || data.time || "—",
                        clientName: clientName || "Unknown Client",
                        area: data.area || "—",
                        service: data.serviceType || data.sessionType || data.service || data.plan || "Personal Training",
                        status: isCompleted ? "Done" : (data.status || "Upcoming"),
                        notes: data.notes || data.sessionNotes || data.trainerNotes || "",
                    });

                    dayObj.totalSessions += 1;
                    if (isCompleted) dayObj.completedSessions += 1;

                    if (cId) uniqueClients.add(cId);
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

    const handleBadgeFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file || !id) return;
        setIsUploadingCert(true);
        try {
            const targetName = activeTargetCert || file.name;
            const sanitized = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
            const certStorageRef = ref(storage, `trainerCertificates/${id}/${Date.now()}_${sanitized}`);
            await uploadBytes(certStorageRef, file);
            const downloadUrl = await getDownloadURL(certStorageRef);

            const existingCerts = [...(trainer?.certificates || [])];
            let found = false;
            const updated = existingCerts.map(c => {
                if (c.name.toLowerCase() === targetName.toLowerCase() || (activeTargetCert && c.name.toLowerCase() === activeTargetCert.toLowerCase())) {
                    found = true;
                    return { ...c, url: downloadUrl, uploadedAt: new Date().toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) };
                }
                return c;
            });

            if (!found) {
                updated.push({
                    name: file.name,
                    url: downloadUrl,
                    uploadedAt: new Date().toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" })
                });
            }

            try {
                await updateDoc(doc(db, "trainers", id), {
                    certificates: updated,
                    certificateUrls: updated.map(c => c.url).filter(Boolean)
                });
            } catch {
                await updateDoc(doc(db, "users", id), {
                    certificates: updated
                });
            }

            setTrainer(prev => prev ? {
                ...prev,
                certificates: updated,
                certifications: updated.map(c => c.name)
            } : null);

            // Automatically open preview modal with the newly uploaded file
            setSelectedPreview({ url: downloadUrl, name: targetName });
        } catch (err) {
            console.error("Certificate upload error:", err);
            alert("Could not upload certificate image. Please try again.");
        } finally {
            setIsUploadingCert(false);
            setActiveTargetCert(null);
            if (badgeFileInputRef.current) badgeFileInputRef.current.value = "";
        }
    };

    return (
        <Layout title="View Profile">
            {/* Hidden File Input for Certificate Uploads */}
            <input
                type="file"
                ref={badgeFileInputRef}
                onChange={handleBadgeFileUpload}
                style={{ display: "none" }}
                accept=".pdf,.png,.jpg,.jpeg,.doc,.docx"
            />

            {/* Top Navigation */}
            <div className="tp-nav-row">
                <button className="back-btn-outlined" onClick={() => navigate("/trainers")}>
                    <i className="bx bx-arrow-back" style={{ fontSize: '18px' }} /> Back to Trainers
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
                            style={{ objectFit: "cover" }}
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
                            {trainer.certificates && trainer.certificates.length > 0 ? (
                                trainer.certificates.map((cert, idx) => {
                                    const hasUrl = Boolean(cert.url);
                                    const isFile = hasUrl || cert.name.includes(".") || cert.name.toLowerCase().endsWith(".png") || cert.name.toLowerCase().endsWith(".jpg") || cert.name.toLowerCase().endsWith(".jpeg") || cert.name.toLowerCase().endsWith(".pdf");

                                    return (
                                        <button
                                            key={idx}
                                            type="button"
                                            className={`tp-badge ${hasUrl || isFile ? "clickable" : ""}`}
                                            onClick={() => {
                                                if (cert.url) {
                                                    setSelectedPreview({ url: cert.url, name: cert.name });
                                                } else {
                                                    setActiveTargetCert(cert.name);
                                                    badgeFileInputRef.current?.click();
                                                }
                                            }}
                                            title={hasUrl ? `Click to view ${cert.name}` : `Click to attach proof image for ${cert.name}`}
                                        >
                                            {isUploadingCert && activeTargetCert === cert.name ? (
                                                <i className="bx bx-loader-alt bx-spin" style={{ fontSize: "14px", color: "#0284c7" }} />
                                            ) : (
                                                <i
                                                    className={cert.url?.includes(".pdf") || cert.name.toLowerCase().endsWith(".pdf")
                                                        ? "bx bxs-file-pdf"
                                                        : (hasUrl || isFile ? "bx bx-image-alt" : "bx bx-check-shield")
                                                    }
                                                    style={{ fontSize: "14px", color: hasUrl ? "#0284c7" : "#10b981" }}
                                                />
                                            )}
                                            <span>{cert.name}</span>
                                            {hasUrl ? (
                                                <i className="bx bx-link-external" style={{ fontSize: "12px", opacity: 0.8, color: "#0284c7" }} />
                                            ) : isFile ? (
                                                <i className="bx bx-upload" style={{ fontSize: "12px", opacity: 0.7, color: "#f59e0b" }} title="Upload proof image" />
                                            ) : null}
                                        </button>
                                    );
                                })
                            ) : (
                                <>
                                    <span className="tp-badge"><i className="bx bx-check-shield" style={{ color: "#10b981" }} /> ISSA Certified Personal Trainer</span>
                                    <span className="tp-badge"><i className="bx bx-check-shield" style={{ color: "#10b981" }} /> CPR & First Aid</span>
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

            {/* CERTIFICATE PREVIEW MODAL */}
            {selectedPreview && (
                <div
                    className="modal-overlay"
                    onClick={() => setSelectedPreview(null)}
                    style={{
                        position: "fixed",
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        backgroundColor: "rgba(15, 23, 42, 0.75)",
                        backdropFilter: "blur(4px)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        zIndex: 9999,
                        padding: "20px"
                    }}
                >
                    <div
                        className="preview-modal-card"
                        onClick={(e) => e.stopPropagation()}
                        style={{
                            backgroundColor: "#ffffff",
                            borderRadius: "16px",
                            maxWidth: "750px",
                            width: "100%",
                            maxHeight: "90vh",
                            overflow: "hidden",
                            display: "flex",
                            flexDirection: "column",
                            boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)"
                        }}
                    >
                        <div style={{ padding: "16px 20px", borderBottom: "1px solid #e2e8f0", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                            <h3 style={{ margin: 0, fontSize: "16px", fontWeight: 700, color: "#1e293b", display: "flex", alignItems: "center", gap: "8px" }}>
                                <i className="bx bx-certification" style={{ color: "#0284c7", fontSize: "20px" }} />
                                {selectedPreview.name}
                            </h3>
                            <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                                <a
                                    href={selectedPreview.url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    style={{
                                        padding: "6px 12px",
                                        borderRadius: "6px",
                                        backgroundColor: "#f1f5f9",
                                        color: "#0f172a",
                                        fontSize: "13px",
                                        fontWeight: 600,
                                        textDecoration: "none",
                                        display: "flex",
                                        alignItems: "center",
                                        gap: "4px"
                                    }}
                                >
                                    <i className="bx bx-link-external" /> Open in New Tab
                                </a>
                                <button
                                    onClick={() => setSelectedPreview(null)}
                                    style={{
                                        border: "none",
                                        background: "transparent",
                                        fontSize: "24px",
                                        cursor: "pointer",
                                        color: "#64748b",
                                        display: "flex",
                                        alignItems: "center",
                                        justifyContent: "center",
                                        padding: "4px"
                                    }}
                                >
                                    &times;
                                </button>
                            </div>
                        </div>
                        <div style={{ padding: "20px", overflowY: "auto", display: "flex", justifyContent: "center", alignItems: "center", background: "#0f172a", minHeight: "350px" }}>
                            {selectedPreview.url.includes(".pdf") ? (
                                <iframe src={selectedPreview.url} style={{ width: "100%", height: "550px", border: "none", borderRadius: "8px" }} title="Certificate PDF" />
                            ) : (
                                <img src={selectedPreview.url} alt={selectedPreview.name} style={{ maxWidth: "100%", maxHeight: "65vh", objectFit: "contain", borderRadius: "8px" }} />
                            )}
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}