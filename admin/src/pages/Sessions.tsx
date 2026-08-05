import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    query,
    where,
    getDocs,
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/sessions.css";

interface SessionRow {
    id: string;
    time: string;
    trainerName: string;
    clientName: string;
    serviceType: string;
    status: string;
    hasMedia: boolean;
}

interface MediaCard {
    id: string;
    title: string;
    trainerInitials: string;
    trainerName: string;
    duration: string;
    fileType: string;
    ago: string;
}

interface RawSessionDoc {
    scheduledTime?: string;
    scheduledDate?: string;
    trainerName?: string;
    clientName?: string;
    serviceType?: string;
    status?: string;
    recordingUrl?: string;
    recordingDuration?: string;
    recordingFileType?: string;
    recordedAt?: { toDate: () => Date };
}

type TabKey = "today" | "week" | "rescheduled";

function todayStr() {
    return new Date().toISOString().slice(0, 10);
}

function weekAgoStr() {
    const d = new Date();
    d.setDate(d.getDate() - 7);
    return d.toISOString().slice(0, 10);
}

function timeAgo(date: Date): string {
    const mins = Math.floor((Date.now() - date.getTime()) / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    return `${Math.floor(hrs / 24)}d ago`;
}

export default function Sessions() {
    const navigate = useNavigate();
    const [tab, setTab] = useState<TabKey>("today");
    const [sessions, setSessions] = useState<SessionRow[]>([]);
    const [totalCount, setTotalCount] = useState(0);
    const [completionPct, setCompletionPct] = useState(0);
    const [mediaCount, setMediaCount] = useState(0);
    const [mediaCards, setMediaCards] = useState<MediaCard[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            setLoading(true);
            try {
                const today = todayStr();

                let sessionsQuery;
                if (tab === "today") {
                    sessionsQuery = query(
                        collection(db, "sessions"),
                        where("scheduledDate", "==", today)
                    );
                } else if (tab === "week") {
                    sessionsQuery = query(
                        collection(db, "sessions"),
                        where("scheduledDate", ">=", weekAgoStr()),
                        where("scheduledDate", "<=", today)
                    );
                } else {
                    sessionsQuery = query(
                        collection(db, "sessions"),
                        where("status", "==", "rescheduled")
                    );
                }

                const snap = await getDocs(sessionsQuery);
                if (cancelled) return;

                const rows: SessionRow[] = snap.docs.map((d) => {
                    const data = d.data() as RawSessionDoc;
                    return {
                        id: d.id,
                        time: data.scheduledTime ?? "—",
                        trainerName: data.trainerName ?? "—",
                        clientName: data.clientName ?? "—",
                        serviceType: data.serviceType ?? "—",
                        status: data.status ?? "scheduled",
                        hasMedia: Boolean(data.recordingUrl),
                    };
                });
                rows.sort((a, b) => a.time.localeCompare(b.time));
                setSessions(rows);
                setTotalCount(rows.length);

                const completed = rows.filter((r) => r.status === "completed").length;
                setCompletionPct(
                    rows.length === 0 ? 0 : Math.round((completed / rows.length) * 1000) / 10
                );

                const withMedia = rows.filter((r) => r.hasMedia).length;
                setMediaCount(withMedia);

                // Recent audio sessions (most recently recorded, across all sessions)
                const mediaSnap = await getDocs(
                    query(collection(db, "sessions"), where("recordingUrl", "!=", null))
                );
                if (cancelled) return;

                const media = mediaSnap.docs
                    .map((d) => {
                        const data = d.data() as RawSessionDoc;
                        const recordedAt = data.recordedAt?.toDate
                            ? data.recordedAt.toDate()
                            : null;
                        return {
                            id: d.id,
                            title: `${data.serviceType ?? "Session"} - ${data.clientName ?? "Client"
                                }`,
                            trainerInitials: (data.trainerName ?? "—")
                                .split(" ")
                                .map((p: string) => p[0])
                                .join("")
                                .slice(0, 2)
                                .toUpperCase(),
                            trainerName: data.trainerName ?? "—",
                            duration: data.recordingDuration ?? "—",
                            fileType: (data.recordingFileType ?? "audio").toUpperCase(),
                            ago: recordedAt ? timeAgo(recordedAt) : "",
                            _sortDate: recordedAt?.getTime() ?? 0,
                        };
                    })
                    .sort((a, b) => b._sortDate - a._sortDate)
                    .slice(0, 3);
                setMediaCards(media);
            } catch (err) {
                console.error("Sessions load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();
        return () => {
            cancelled = true;
        };
    }, [tab]);

    if (loading) {
        return (
            <Layout title="All Sessions">
                <p style={{ color: "#999" }}>Loading sessions...</p>
            </Layout>
        );
    }

    return (
        <Layout title="All Sessions">
            <div className="sessions-header">
                <div>
                    <div className="sessions-title">Sessions Management</div>
                    <div className="sessions-subtitle">
                        Monitor real-time training activity and session media.
                    </div>
                </div>
                <div className="sessions-tabs">
                    {(["today", "week", "rescheduled"] as TabKey[]).map((k) => (
                        <button
                            key={k}
                            className={`sessions-tab-btn ${tab === k ? "active" : ""}`}
                            onClick={() => setTab(k)}
                        >
                            {k === "today" ? "Today" : k === "week" ? "This Week" : "Rescheduled"}
                        </button>
                    ))}
                </div>
            </div>

            <div className="sessions-metric-cards">
                <div className="sessions-metric-card">
                    <div className="sessions-metric-label">TOTAL SESSIONS TODAY</div>
                    <div className="sessions-metric-value">{totalCount}</div>
                </div>
                <div className="sessions-metric-card">
                    <div className="sessions-metric-label">COMPLETION RATE (%)</div>
                    <div className="sessions-metric-value">{completionPct}</div>
                </div>
                <div className="sessions-metric-card">
                    <div className="sessions-metric-label">SESSIONS WITH MEDIA</div>
                    <div className="sessions-metric-value">{mediaCount}</div>
                </div>
            </div>

            <div className="sessions-table-card">
                <div className="sessions-table-header">
                    <div className="sessions-table-title">All Sessions</div>
                </div>

                {sessions.length === 0 ? (
                    <div className="profile-empty" style={{ padding: 24 }}>
                        No sessions found for this view.
                    </div>
                ) : (
                    <>
                        <table className="sessions-table">
                            <thead>
                                <tr>
                                    <th>Time</th>
                                    <th>Trainer</th>
                                    <th>Client</th>
                                    <th>Service</th>
                                    <th>Status</th>
                                    <th>Media</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {sessions.slice(0, 5).map((s) => (
                                    <tr key={s.id}>
                                        <td className="sessions-mono">{s.time}</td>
                                        <td>{s.trainerName}</td>
                                        <td className="sessions-bold">{s.clientName}</td>
                                        <td>
                                            <span className="sessions-service-pill">
                                                {s.serviceType.toUpperCase()}
                                            </span>
                                        </td>
                                        <td>
                                            {s.status === "live" ? (
                                                <span className="sessions-status-pill live">
                                                    <span className="live-dot" /> LIVE
                                                </span>
                                            ) : s.status === "completed" ? (
                                                <span className="sessions-status-pill done">Done</span>
                                            ) : (
                                                <span className="sessions-status-pill upcoming">
                                                    Upcoming
                                                </span>
                                            )}
                                        </td>
                                        <td>
                                            {s.hasMedia ? (
                                                <i className="bx bx-play-circle sessions-media-icon" />
                                            ) : (
                                                <span className="sessions-no-media">—</span>
                                            )}
                                        </td>
                                        <td>
                                            <button className="sessions-action-btn">
                                                <i className="bx bx-show" />
                                            </button>
                                            <button className="sessions-action-btn">
                                                <i className="bx bx-edit" />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        <div className="sessions-table-footer">
                            Showing {Math.min(5, sessions.length)} of {sessions.length} sessions
                        </div>
                    </>
                )}
            </div>

            <div className="sessions-media-section">
                <div className="sessions-media-header">
                    <div className="sessions-media-title">
                        <span className="sessions-media-icon-badge">
                            <i className="bx bx-microphone" />
                        </span>
                        Recent Audio Sessions
                    </div>
                    <button
                        className="sessions-media-library-btn"
                        onClick={() => navigate("/sessions/media")}
                    >
                        Full Media Library <i className="bx bx-right-arrow-alt" />
                    </button>
                </div>

                {mediaCards.length === 0 ? (
                    <div className="profile-empty">No recorded sessions yet.</div>
                ) : (
                    <div className="sessions-media-grid">
                        {mediaCards.map((m) => (
                            <div key={m.id} className="media-card">
                                <div className="media-card-waveform">
                                    <span className="media-card-filetype">.{m.fileType}</span>
                                    <span className="media-card-duration">{m.duration}</span>
                                </div>
                                <div className="media-card-body">
                                    <div className="media-card-title">{m.title}</div>
                                    <div className="media-card-footer">
                                        <div className="media-card-trainer">
                                            <span className="media-card-avatar">
                                                {m.trainerInitials}
                                            </span>
                                            <span>
                                                {m.trainerName} • {m.ago}
                                            </span>
                                        </div>
                                        <button className="media-card-download">
                                            <i className="bx bx-download" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </Layout>
    );
}