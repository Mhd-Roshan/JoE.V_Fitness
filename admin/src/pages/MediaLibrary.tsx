import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { collection, query, where, getDocs, doc, updateDoc } from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/mediaLibrary.css";

interface Recording {
    id: string;
    fileName: string;
    trainerName: string;
    clientName: string;
    serviceType: string;
    duration: string;
    recordingUrl: string;
    recordedAt: Date | null;
    fileType: string;
}

interface RawSessionDoc {
    trainerName?: string;
    clientName?: string;
    serviceType?: string;
    recordingUrl?: string;
    recordingDuration?: string;
    recordingFileType?: string;
    recordingFileName?: string;
    recordedAt?: { toDate: () => Date };
}

const PAGE_SIZE = 4;

export default function MediaLibrary() {
    const navigate = useNavigate();
    const [recordings, setRecordings] = useState<Recording[]>([]);
    const [loading, setLoading] = useState(true);
    const [serviceFilter, setServiceFilter] = useState("all");
    const [trainerFilter, setTrainerFilter] = useState("all");
    const [dateFrom, setDateFrom] = useState("");
    const [dateTo, setDateTo] = useState("");
    const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
    const [activeId, setActiveId] = useState<string | null>(null);
    const [page, setPage] = useState(1);

    useEffect(() => {
        async function load() {
            try {
                const snap = await getDocs(
                    query(collection(db, "sessions"), where("recordingUrl", "!=", null))
                );
                const rows: Recording[] = snap.docs.map((d) => {
                    const data = d.data() as RawSessionDoc;
                    return {
                        id: d.id,
                        fileName:
                            data.recordingFileName ??
                            `${data.serviceType ?? "Session"}_${data.clientName ?? "Client"}`.replace(
                                /\s+/g,
                                "_"
                            ),
                        trainerName: data.trainerName ?? "—",
                        clientName: data.clientName ?? "—",
                        serviceType: data.serviceType ?? "—",
                        duration: data.recordingDuration ?? "—",
                        recordingUrl: data.recordingUrl ?? "",
                        recordedAt: data.recordedAt?.toDate ? data.recordedAt.toDate() : null,
                        fileType: data.recordingFileType ?? "audio",
                    };
                });
                rows.sort(
                    (a, b) => (b.recordedAt?.getTime() ?? 0) - (a.recordedAt?.getTime() ?? 0)
                );
                setRecordings(rows);
                if (rows.length > 0) setActiveId(rows[0].id);
            } catch (err) {
                console.error("Media library load error:", err);
            } finally {
                setLoading(false);
            }
        }
        load();
    }, []);

    const services = useMemo(
        () => Array.from(new Set(recordings.map((r) => r.serviceType))),
        [recordings]
    );
    const trainers = useMemo(
        () => Array.from(new Set(recordings.map((r) => r.trainerName))),
        [recordings]
    );

    const filtered = recordings.filter((r) => {
        if (serviceFilter !== "all" && r.serviceType !== serviceFilter) return false;
        if (trainerFilter !== "all" && r.trainerName !== trainerFilter) return false;
        if (dateFrom && r.recordedAt && r.recordedAt < new Date(dateFrom)) return false;
        if (dateTo && r.recordedAt && r.recordedAt > new Date(dateTo + "T23:59:59")) return false;
        return true;
    });

    const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    const pageRows = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
    const activeRecording = recordings.find((r) => r.id === activeId) ?? null;

    function resetFilters() {
        setServiceFilter("all");
        setTrainerFilter("all");
        setDateFrom("");
        setDateTo("");
        setPage(1);
    }

    function toggleSelect(id: string) {
        setSelectedIds((prev) => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id);
            else next.add(id);
            return next;
        });
    }

    async function handleDeleteSelected() {
        if (selectedIds.size === 0) return;
        if (!window.confirm(`Remove ${selectedIds.size} recording(s)? This can't be undone.`)) {
            return;
        }
        try {
            await Promise.all(
                Array.from(selectedIds).map((id) =>
                    updateDoc(doc(db, "sessions", id), { recordingUrl: null })
                )
            );
            setRecordings((prev) => prev.filter((r) => !selectedIds.has(r.id)));
            setSelectedIds(new Set());
        } catch (err) {
            console.error("Delete recordings failed:", err);
        }
    }

    async function handleDeleteOne(id: string) {
        if (!window.confirm("Remove this recording? This can't be undone.")) return;
        try {
            await updateDoc(doc(db, "sessions", id), { recordingUrl: null });
            setRecordings((prev) => prev.filter((r) => r.id !== id));
            if (activeId === id) setActiveId(null);
        } catch (err) {
            console.error("Delete recording failed:", err);
        }
    }

    function handleDownloadAll() {
        filtered.forEach((r) => {
            if (r.recordingUrl) window.open(r.recordingUrl, "_blank");
        });
    }

    if (loading) {
        return (
            <Layout title="Media Sessions">
                <p style={{ color: "#999" }}>Loading media library...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Media Sessions">
            <button className="profile-back-btn" onClick={() => navigate("/sessions")}>
                <i className="bx bx-arrow-back" /> Back to Sessions
            </button>

            <div className="media-lib-header">
                <div>
                    <div className="media-lib-title">Media Library</div>
                    <div className="media-lib-subtitle">
                        Central repository for all training session captures.
                    </div>
                </div>
                <div className="media-lib-header-actions">
                    <button className="media-lib-download-all-btn" onClick={handleDownloadAll}>
                        <i className="bx bx-download" /> Download All
                    </button>
                    <button
                        className="media-lib-delete-selected-btn"
                        onClick={handleDeleteSelected}
                        disabled={selectedIds.size === 0}
                    >
                        <i className="bx bx-trash" /> Delete Selected
                    </button>
                </div>
            </div>

            <div className="media-lib-layout">
                <div className="media-lib-filter-card">
                    <div className="media-lib-filter-heading">
                        <i className="bx bx-filter-alt" /> Filter Media
                    </div>

                    <div className="media-lib-filter-field">
                        <label className="media-lib-filter-label">SERVICE CATEGORY</label>
                        <select
                            className="media-lib-filter-select"
                            value={serviceFilter}
                            onChange={(e) => {
                                setServiceFilter(e.target.value);
                                setPage(1);
                            }}
                        >
                            <option value="all">All Services</option>
                            {services.map((s) => (
                                <option key={s} value={s}>
                                    {s}
                                </option>
                            ))}
                        </select>
                    </div>

                    <div className="media-lib-filter-field">
                        <label className="media-lib-filter-label">TRAINER</label>
                        <select
                            className="media-lib-filter-select"
                            value={trainerFilter}
                            onChange={(e) => {
                                setTrainerFilter(e.target.value);
                                setPage(1);
                            }}
                        >
                            <option value="all">Any Trainer</option>
                            {trainers.map((t) => (
                                <option key={t} value={t}>
                                    {t}
                                </option>
                            ))}
                        </select>
                    </div>

                    <div className="media-lib-filter-field">
                        <label className="media-lib-filter-label">DATE RANGE</label>
                        <div className="media-lib-date-row">
                            <input
                                type="date"
                                className="media-lib-date-input"
                                value={dateFrom}
                                onChange={(e) => {
                                    setDateFrom(e.target.value);
                                    setPage(1);
                                }}
                            />
                            <input
                                type="date"
                                className="media-lib-date-input"
                                value={dateTo}
                                onChange={(e) => {
                                    setDateTo(e.target.value);
                                    setPage(1);
                                }}
                            />
                        </div>
                    </div>

                    <button className="media-lib-reset-btn" onClick={resetFilters}>
                        RESET FILTERS
                    </button>
                </div>

                <div className="media-lib-table-card">
                    {filtered.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 24 }}>
                            No recordings match these filters.
                        </div>
                    ) : (
                        <>
                            <div className="media-lib-table-header">
                                <span className="media-lib-col-check" />
                                <span className="media-lib-col-name">FILE NAME</span>
                                <span className="media-lib-col-duration">DURATION</span>
                                <span className="media-lib-col-date">DATE &amp; TIME</span>
                                <span className="media-lib-col-actions">ACTIONS</span>
                            </div>

                            {pageRows.map((r) => (
                                <div
                                    key={r.id}
                                    className={`media-lib-row ${r.id === activeId ? "active" : ""}`}
                                >
                                    <span className="media-lib-col-check">
                                        <input
                                            type="checkbox"
                                            checked={selectedIds.has(r.id)}
                                            onChange={() => toggleSelect(r.id)}
                                        />
                                    </span>
                                    <span
                                        className="media-lib-col-name media-lib-name-cell"
                                        onClick={() => setActiveId(r.id)}
                                    >
                                        <span className="media-lib-file-icon">
                                            <i className="bx bx-file-blank" />
                                        </span>
                                        <span>
                                            <div className="media-lib-file-name">{r.fileName}</div>
                                            <div className="media-lib-file-sub">
                                                {r.trainerName} • {r.clientName}
                                            </div>
                                        </span>
                                    </span>
                                    <span className="media-lib-col-duration">{r.duration}</span>
                                    <span className="media-lib-col-date">
                                        <div>
                                            {r.recordedAt
                                                ? r.recordedAt.toLocaleDateString(undefined, {
                                                    month: "short",
                                                    day: "2-digit",
                                                    year: "numeric",
                                                })
                                                : "—"}
                                        </div>
                                        <div className="media-lib-file-sub">
                                            {r.recordedAt
                                                ? r.recordedAt.toLocaleTimeString([], {
                                                    hour: "2-digit",
                                                    minute: "2-digit",
                                                })
                                                : ""}
                                        </div>
                                    </span>
                                    <span className="media-lib-col-actions">
                                        <button
                                            className="media-lib-icon-btn"
                                            onClick={() => setActiveId(r.id)}
                                        >
                                            <i className="bx bx-play" />
                                        </button>
                                        <button
                                            className="media-lib-icon-btn"
                                            onClick={() => window.open(r.recordingUrl, "_blank")}
                                        >
                                            <i className="bx bx-download" />
                                        </button>
                                        <button
                                            className="media-lib-icon-btn danger"
                                            onClick={() => handleDeleteOne(r.id)}
                                        >
                                            <i className="bx bx-trash" />
                                        </button>
                                    </span>
                                </div>
                            ))}

                            <div className="media-lib-pagination">
                                <span className="media-lib-pagination-count">
                                    Showing {pageRows.length} of {filtered.length} recordings
                                </span>
                                <div className="media-lib-pagination-controls">
                                    <button
                                        className="media-lib-page-btn"
                                        disabled={page === 1}
                                        onClick={() => setPage((p) => Math.max(1, p - 1))}
                                    >
                                        <i className="bx bx-chevron-left" />
                                    </button>
                                    {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
                                        <button
                                            key={p}
                                            className={`media-lib-page-btn ${p === page ? "active" : ""}`}
                                            onClick={() => setPage(p)}
                                        >
                                            {p}
                                        </button>
                                    ))}
                                    <button
                                        className="media-lib-page-btn"
                                        disabled={page === totalPages}
                                        onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                                    >
                                        <i className="bx bx-chevron-right" />
                                    </button>
                                </div>
                            </div>
                        </>
                    )}
                </div>

                <div className="media-lib-player-card">
                    {!activeRecording ? (
                        <div className="profile-empty" style={{ color: "#fff", padding: 16 }}>
                            Select a recording to play.
                        </div>
                    ) : (
                        <>
                            <div className="media-lib-player-header">
                                <span className="media-lib-player-filetype">
                                    .{activeRecording.fileType.toUpperCase()}
                                </span>
                                <div>
                                    <div className="media-lib-player-name">
                                        {activeRecording.fileName}
                                    </div>
                                    <div className="media-lib-player-sub">
                                        {activeRecording.trainerName} • {activeRecording.clientName}
                                    </div>
                                </div>
                            </div>

                            {activeRecording.recordingUrl ? (
                                <audio
                                    key={activeRecording.id}
                                    controls
                                    className="media-lib-audio-player"
                                    src={activeRecording.recordingUrl}
                                >
                                    Your browser does not support audio playback.
                                </audio>
                            ) : (
                                <div className="profile-empty" style={{ color: "#fff" }}>
                                    No playable file for this recording.
                                </div>
                            )}
                        </>
                    )}
                </div>
            </div>
        </Layout>
    );
}