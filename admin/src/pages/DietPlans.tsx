import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
    collection,
    query,
    orderBy,
    onSnapshot,
    doc,
    addDoc,
    updateDoc,
    serverTimestamp,
    limit,
    where,
    getDocs,
    getDoc,
    writeBatch
} from "firebase/firestore";
import { db, auth } from "../lib/firebase";
import Layout from "../components/Layout";
import EmojiPicker, { Theme } from "emoji-picker-react";
import "../styles/chats.css";

// ------------------------------------------------------------------
// Types
// ------------------------------------------------------------------
interface ThreadRow {
    id: string;
    clientName: string;
    photoURL: string | null;
    lastMessage: string;
    lastMessageAt: string;
    unreadCount: number;
}

interface MessageRow {
    id: string;
    senderRole: "client" | "admin";
    text: string;
    type?: "text" | "diet_plan" | "file";
    attachment?: {
        templateId?: string;
        name?: string;
        subtitle?: string;
        url?: string;
        pdfUrl?: string;
    };
    createdAt: string;
}

interface ClientPanelData {
    fullName: string;
    photoURL: string | null;
    primaryGoal: string | null;
    dietPlanName: string | null;
    weight: string;
    bodyFat: string;
    initials: string;
}

interface DietTemplate {
    id: string;
    name: string;
    subtitle: string;
    url?: string;
}

// ------------------------------------------------------------------
// Helper functions
// ------------------------------------------------------------------
const extractDataAggressively = (sources: unknown[], keys: string[]): string | undefined => {
    for (const source of sources) {
        if (!source || typeof source !== 'object') continue;
        const srcObj = source as Record<string, unknown>;
        for (const key of keys) {
            const val = srcObj[key];
            if (typeof val === 'string' && val.trim() !== '') return val.trim();
            if (Array.isArray(val) && val.length > 0 && typeof val[0] === 'string') return val[0].trim();
            if (typeof val === 'object' && val !== null) {
                const obj = val as Record<string, unknown>;
                if (typeof obj.value === 'string') return obj.value.trim();
                if (typeof obj.name === 'string') return obj.name.trim();
                if (typeof obj.title === 'string') return obj.title.trim();
            }
        }
    }
    return undefined;
};

const SkeletonThread = () => (
    <div className="thread-item skeleton-mode">
        <div className="skeleton-avatar"></div>
        <div className="thread-content" style={{ gap: '8px', display: 'flex', flexDirection: 'column' }}>
            <div className="skeleton-line" style={{ width: '60%' }}></div>
            <div className="skeleton-line" style={{ width: '90%', height: '12px' }}></div>
        </div>
    </div>
);

// ------------------------------------------------------------------
// Main Component
// ------------------------------------------------------------------
export default function Chats() {
    const navigate = useNavigate();

    // Core States
    const [threads, setThreads] = useState<ThreadRow[]>([]);
    const [threadSearch, setThreadSearch] = useState("");
    const [selectedId, setSelectedId] = useState<string | null>(null);
    const [messages, setMessages] = useState<MessageRow[]>([]);
    const [clientPanel, setClientPanel] = useState<ClientPanelData | null>(null);
    const [draft, setDraft] = useState("");
    const [loadingThreads, setLoadingThreads] = useState(true);

    // UI & Modal States
    const [showMobileChat, setShowMobileChat] = useState(false);
    const [showAttachMenu, setShowAttachMenu] = useState(false);
    const [showDietModal, setShowDietModal] = useState(false);
    const [showEmojiPicker, setShowEmojiPicker] = useState(false);
    const [dietTemplates, setDietTemplates] = useState<DietTemplate[]>([]);

    const scrollRef = useRef<HTMLDivElement>(null);
    const attachMenuRef = useRef<HTMLDivElement>(null);
    const emojiPickerRef = useRef<HTMLDivElement>(null);

    const sharedFiles = messages
        .filter(m => m.attachment && m.attachment.name)
        .map(m => ({
            id: m.id,
            name: m.attachment!.name,
            type: m.type,
            templateId: m.attachment!.templateId
        }))
        .reverse();

    useEffect(() => {
        const handleClickOutside = (e: MouseEvent) => {
            if (attachMenuRef.current && !attachMenuRef.current.contains(e.target as Node)) {
                setShowAttachMenu(false);
            }
            if (emojiPickerRef.current && !emojiPickerRef.current.contains(e.target as Node)) {
                setShowEmojiPicker(false);
            }
        };
        document.addEventListener("mousedown", handleClickOutside);
        return () => document.removeEventListener("mousedown", handleClickOutside);
    }, []);

    // 1. Fetch Live Threads
    useEffect(() => {
        const q = query(collection(db, "chatThreads"), orderBy("lastMessageAt", "desc"));
        const unsub = onSnapshot(q, (snap) => {
            setThreads(
                snap.docs.map((d) => {
                    const data = d.data();
                    return {
                        id: d.id,
                        clientName: data.clientName ?? "Unknown Client",
                        photoURL: data.clientPhotoURL ?? null,
                        lastMessage: data.lastMessage ?? "",
                        lastMessageAt: data.lastMessageAt?.toDate
                            ? data.lastMessageAt.toDate().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
                            : "",
                        unreadCount: data.unreadCount ?? 0,
                    };
                })
            );
            setLoadingThreads(false);
            if (!selectedId && snap.docs.length > 0 && window.innerWidth > 768) {
                setSelectedId(snap.docs[0].id);
            }
        });
        return () => unsub();
    }, [selectedId]);

    // 2. Fetch Live Messages
    useEffect(() => {
        if (!selectedId) return;
        const q = query(collection(db, "chatThreads", selectedId, "messages"), orderBy("createdAt", "asc"), limit(200));
        const unsub = onSnapshot(q, (snap) => {
            setMessages(
                snap.docs.map((d) => {
                    const data = d.data();
                    return {
                        id: d.id,
                        senderRole: data.senderRole ?? "client",
                        text: data.text ?? "",
                        type: data.type ?? "text",
                        attachment: data.attachment,
                        createdAt: data.createdAt?.toDate
                            ? data.createdAt.toDate().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
                            : "",
                    };
                })
            );
            setTimeout(() => {
                scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
            }, 100);
        });

        updateDoc(doc(db, "chatThreads", selectedId), { unreadCount: 0 }).catch(console.error);

        return () => unsub();
    }, [selectedId]);

    // 3. Fetch Advanced Client Panel Data
    useEffect(() => {
        if (!selectedId) return;
        let isMounted = true;

        async function loadPanel() {
            try {
                const [userSnap, profileSnapQuery, assessDocSnap, assessUserSnap, dietSnap, progressSnap] = await Promise.all([
                    getDoc(doc(db, "users", selectedId!)),
                    getDocs(collection(db, "users", selectedId!, "clientProfile")),
                    getDoc(doc(db, "assessments", selectedId!)),
                    getDocs(query(collection(db, "assessments"), where("userId", "==", selectedId!))),
                    getDocs(query(collection(db, "clientDietPlans"), where("clientId", "==", selectedId!), where("status", "==", "active"), limit(1))),
                    getDocs(query(collection(db, "users", selectedId!, "progress_history"), limit(1)))
                ]);

                if (!isMounted) return;

                const userData = (userSnap.data() || {}) as Record<string, unknown>;
                const profileData = (profileSnapQuery.docs[0]?.data() || {}) as Record<string, unknown>;
                let assessData: Record<string, unknown> = {};
                if (assessDocSnap.exists()) assessData = assessDocSnap.data();
                else if (!assessUserSnap.empty) assessData = assessUserSnap.docs[0].data();

                const possibleSources = [userData, profileData, assessData, userData.personalInfo, assessData.fitnessGoals, profileData.personalInfo];

                const goal = extractDataAggressively(possibleSources, ['primaryGoal', 'goal', 'fitnessGoal', 'goals']) || "Not Set";

                let currentWeight = "—";
                let currentBf = "—";

                if (!progressSnap.empty) {
                    const prog = progressSnap.docs[0].data();
                    if (prog.weight) currentWeight = String(prog.weight);
                    if (prog.bodyFat) currentBf = String(prog.bodyFat);
                }
                if (currentWeight === "—") currentWeight = extractDataAggressively(possibleSources, ['weight', 'currentWeight']) || "—";
                if (currentBf === "—") currentBf = extractDataAggressively(possibleSources, ['bodyFat', 'bf', 'bodyFatPercentage']) || "—";

                const threadFallback = threads.find(t => t.id === selectedId);
                const fullName = (userData.fullName || userData.name || threadFallback?.clientName || "Unknown Client") as string;

                const initials = fullName.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase();
                const dietName = dietSnap.empty ? null : (dietSnap.docs[0].data().templateName as string);
                const fetchedPhotoURL = (userData.photoURL as string) || null;

                if (threadFallback && fullName !== "Unknown Client" && fullName !== threadFallback.clientName) {
                    updateDoc(doc(db, "chatThreads", selectedId!), { clientName: fullName, clientPhotoURL: fetchedPhotoURL }).catch(console.error);
                }

                setClientPanel({ fullName, initials, photoURL: fetchedPhotoURL, primaryGoal: goal, dietPlanName: dietName, weight: currentWeight, bodyFat: currentBf });

            } catch (err) {
                console.error("Client panel load error:", err);
            }
        }

        loadPanel();
        return () => { isMounted = false; };
    }, [selectedId, threads]);


    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    async function handleDeleteChat() {
        if (!selectedId) return;
        const confirmDelete = window.confirm("Are you sure you want to delete this entire conversation? This action cannot be undone.");
        if (!confirmDelete) return;

        try {
            const batch = writeBatch(db);
            const msgsSnap = await getDocs(collection(db, "chatThreads", selectedId, "messages"));
            msgsSnap.forEach(docSnap => batch.delete(docSnap.ref));
            batch.delete(doc(db, "chatThreads", selectedId));
            await batch.commit();

            setSelectedId(null);
            setShowMobileChat(false);
            setMessages([]);
        } catch (err) {
            console.error("Failed to delete chat:", err);
            alert("An error occurred while deleting the chat.");
        }
    }

    async function handleSendText() {
        if (!draft.trim() || !selectedId) return;
        const text = draft.trim();
        setDraft("");
        setShowEmojiPicker(false);

        try {
            await addDoc(collection(db, "chatThreads", selectedId, "messages"), {
                senderRole: "admin",
                senderId: auth.currentUser?.uid ?? null,
                text,
                type: "text",
                createdAt: serverTimestamp(),
            });
            await updateDoc(doc(db, "chatThreads", selectedId), {
                lastMessage: text,
                lastMessageAt: serverTimestamp(),
            });
        } catch (err) {
            console.error("Send message failed:", err);
        }
    }

    async function handleOpenDietModal() {
        setShowAttachMenu(false);
        try {
            const snap = await getDocs(collection(db, "dietPlanTemplates"));
            setDietTemplates(snap.docs.map(d => {
                const data = d.data();
                return {
                    id: d.id,
                    name: data.name || data.templateName || "Untitled",
                    subtitle: data.subtitle || data.description || "Custom Diet Plan",
                    url: data.pdfUrl || data.fileUrl || data.url || ""
                };
            }));
            setShowDietModal(true);
        } catch (error) {
            console.error("Failed to load templates:", error);
        }
    }

    // 🔥 THIS IS WHERE THE MAGIC HAPPENS 🔥
    async function handleSendDietPlan(template: DietTemplate) {
        if (!selectedId) return;
        setShowDietModal(false);

        try {
            // 1. Fetch all items inside the template from the database
            const tplSnap = await getDoc(doc(db, "dietPlanTemplates", template.id));
            const tplData = tplSnap.exists() ? tplSnap.data() : {};
            const meals = tplData.meals || tplData.schedule || tplData.items || [];

            // 2. Generate a Text-Based Table format for the Chat Message
            let textFormattedTable = `📋 **DIET PLAN: ${template.name.toUpperCase()}**\n`;
            textFormattedTable += `━━━━━━━━━━━━━━━━━━━━━━\n`;

            if (meals.length > 0) {
                // FIXED ESLINT ISSUE HERE: using Record<string, unknown> instead of 'any'
                meals.forEach((m: Record<string, unknown>) => {
                    const name = String(m.name || m.mealName || m.meal || m.time || `Meal`);
                    const items = String(m.items || m.food || m.description || 'No items listed');
                    const cals = String(m.calories || m.cals || '0');
                    const p = String(m.protein || m.p || '0');
                    const c = String(m.carbs || m.c || '0');
                    const f = String(m.fats || m.fat || m.f || '0');

                    textFormattedTable += `🍽️ **${name.toUpperCase()}**\n`;
                    textFormattedTable += `🥑 ${items}\n`;
                    textFormattedTable += `🔥 ${cals} kcal | P:${p}g | C:${c}g | F:${f}g\n`;
                    textFormattedTable += `━━━━━━━━━━━━━━━━━━━━━━\n`;
                });
            } else {
                textFormattedTable += `(No specific meals listed. Please open the attached PDF.)\n`;
            }

            // 3. Send the message containing both the table text AND the attachment data
            await addDoc(collection(db, "chatThreads", selectedId, "messages"), {
                senderRole: "admin",
                senderId: auth.currentUser?.uid ?? null,
                text: textFormattedTable,
                type: "diet_plan",
                attachment: {
                    templateId: template.id,
                    name: template.name,
                    subtitle: template.subtitle,
                    url: template.url || "",
                    pdfUrl: template.url || "",
                },
                createdAt: serverTimestamp(),
            });

            await updateDoc(doc(db, "chatThreads", selectedId), {
                lastMessage: `Shared Diet Plan: ${template.name}`,
                lastMessageAt: serverTimestamp(),
            });
        } catch (err) {
            console.error("Send diet failed:", err);
        }
    }

    const filteredThreads = threads.filter((t) => t.clientName.toLowerCase().includes(threadSearch.toLowerCase()));
    const selectedThread = threads.find((t) => t.id === selectedId);

    const currentChatName = clientPanel?.fullName || selectedThread?.clientName || "Unknown Client";
    const currentChatPhoto = clientPanel?.photoURL || selectedThread?.photoURL;

    return (
        <Layout title="Chats">
            <div className={`chats-wrapper ${showMobileChat ? 'mobile-chat-active' : ''}`}>

                {/* LEFT PANEL */}
                <div className="chats-left-panel">
                    <div className="chats-left-header">
                        <h2>Messages</h2>
                        <div className="chats-search">
                            <i className="bx bx-search"></i>
                            <input
                                type="text"
                                placeholder="Search clients..."
                                value={threadSearch}
                                onChange={(e) => setThreadSearch(e.target.value)}
                            />
                        </div>
                    </div>

                    <div className="chats-thread-list custom-scrollbar">
                        {loadingThreads ? (
                            <>
                                <SkeletonThread />
                                <SkeletonThread />
                                <SkeletonThread />
                            </>
                        ) : filteredThreads.length === 0 ? (
                            <div className="empty-state">
                                <div className="empty-icon"><i className="bx bx-ghost"></i></div>
                                <p>No conversations found.</p>
                            </div>
                        ) : (
                            filteredThreads.map((t) => (
                                <button
                                    key={t.id}
                                    className={`thread-item ${t.id === selectedId ? "active" : ""}`}
                                    onClick={() => {
                                        setSelectedId(t.id);
                                        setShowMobileChat(true);
                                    }}
                                >
                                    <div className="thread-avatar-wrapper">
                                        {t.photoURL ? (
                                            <img src={t.photoURL} alt={t.clientName} className="thread-avatar" />
                                        ) : (
                                            <div className="thread-avatar">
                                                {t.clientName.split(" ").map((p) => p[0]).join("").slice(0, 2).toUpperCase()}
                                            </div>
                                        )}
                                        <div className="online-dot"></div>
                                    </div>

                                    <div className="thread-content">
                                        <div className="thread-top-row">
                                            <span className="thread-name">{t.clientName}</span>
                                            <span className="thread-time">{t.lastMessageAt}</span>
                                        </div>
                                        <div className={`thread-message ${t.unreadCount > 0 ? 'unread-text' : ''}`}>
                                            {t.lastMessage || "No messages yet"}
                                        </div>
                                    </div>

                                    {t.unreadCount > 0 && (
                                        <div className="thread-badges">
                                            <span className="unread-badge">{t.unreadCount}</span>
                                        </div>
                                    )}
                                </button>
                            ))
                        )}
                    </div>
                </div>

                {/* CENTER PANEL */}
                <div className="chats-center-panel">
                    {!selectedThread ? (
                        <div className="empty-state chat-empty">
                            <div className="empty-icon"><i className="bx bx-message-square-dots"></i></div>
                            <h3>Your Messages</h3>
                            <p>Select a client from the list to start chatting.</p>
                        </div>
                    ) : (
                        <>
                            {/* Chat Header */}
                            <div className="chat-header">
                                <button
                                    className="mobile-back-btn"
                                    onClick={() => setShowMobileChat(false)}
                                >
                                    <i className="bx bx-chevron-left"></i>
                                </button>

                                <div className="thread-avatar-wrapper" style={{ width: 42, height: 42 }}>
                                    {currentChatPhoto ? (
                                        <img src={currentChatPhoto} alt="Client" className="thread-avatar" />
                                    ) : (
                                        <div className="thread-avatar">
                                            {currentChatName.split(" ").map(p => p[0]).join("").slice(0, 2).toUpperCase()}
                                        </div>
                                    )}
                                </div>
                                <div className="chat-header-info">
                                    <div className="chat-header-name">{currentChatName}</div>
                                    <div className="chat-header-status">
                                        <i className="bx bxs-circle"></i> Active Now
                                    </div>
                                </div>

                                <div className="chat-header-actions">
                                    <button
                                        className="chat-delete-btn"
                                        title="Delete Chat"
                                        onClick={handleDeleteChat}
                                    >
                                        <i className="bx bx-trash"></i>
                                    </button>
                                    <button
                                        title="View Profile"
                                        onClick={() => navigate(`/users/${selectedId}`)}
                                    >
                                        <i className="bx bx-user-circle"></i>
                                    </button>
                                </div>
                            </div>

                            {/* Chat Messages */}
                            <div className="chat-messages-area custom-scrollbar" ref={scrollRef}>
                                <div className="chat-date-divider"><span>Conversation Started</span></div>

                                {messages.map((m, index) => {
                                    const isLast = index === messages.length - 1 || messages[index + 1].senderRole !== m.senderRole;

                                    // Make newlines in the table text render properly
                                    const formattedText = m.text.split('\n').map((item, key) => {
                                        return <span key={key}>{item}<br /></span>
                                    });

                                    return (
                                        <div
                                            key={m.id}
                                            className={`message-row ${m.senderRole === "admin" ? "sent" : "received"} ${isLast ? 'last-in-group' : ''}`}
                                        >
                                            {(m.type === "text" || m.type === "diet_plan") && (
                                                <div className="message-bubble-wrapper">
                                                    <div className="message-bubble" style={{ whiteSpace: "pre-line" }}>
                                                        {formattedText}
                                                    </div>

                                                    {m.type === "diet_plan" && m.attachment && (
                                                        <div className="diet-attachment-card" style={{ marginTop: 8 }}>
                                                            <div className="diet-att-icon"><i className="bx bx-restaurant"></i></div>
                                                            <div className="diet-att-info">
                                                                <div className="diet-att-label">ATTACHED DIET TEMPLATE</div>
                                                                <h4 className="diet-att-title">{m.attachment.name}</h4>
                                                            </div>
                                                            <button
                                                                className="diet-att-btn"
                                                                title="View Plan"
                                                                onClick={() => navigate(`/diet-plans/view/${m.attachment?.templateId}`)}
                                                            >
                                                                <i className="bx bx-right-arrow-alt"></i>
                                                            </button>
                                                        </div>
                                                    )}

                                                    {isLast && <div className="message-time">{m.createdAt} {m.senderRole === 'admin' ? '• Delivered' : ''}</div>}
                                                </div>
                                            )}
                                        </div>
                                    );
                                })}
                            </div>

                            {/* Chat Input Area */}
                            <div className="chat-input-container">
                                <div className="attachment-wrapper" ref={attachMenuRef}>
                                    <button
                                        className={`chat-action-btn ${showAttachMenu ? 'active' : ''}`}
                                        onClick={() => setShowAttachMenu(!showAttachMenu)}
                                    >
                                        <i className="bx bx-plus-circle"></i>
                                    </button>

                                    {showAttachMenu && (
                                        <div className="attach-popover">
                                            <button onClick={handleOpenDietModal}>
                                                <div className="pop-icon diet"><i className="bx bx-food-menu"></i></div>
                                                <span>Share Diet Plan</span>
                                            </button>
                                            <button onClick={() => setShowAttachMenu(false)}>
                                                <div className="pop-icon doc"><i className="bx bx-file"></i></div>
                                                <span>Share Document</span>
                                            </button>
                                        </div>
                                    )}
                                </div>

                                <div className="chat-input-wrapper">
                                    <input
                                        type="text"
                                        className="chat-input-box"
                                        placeholder="Type a message..."
                                        value={draft}
                                        onChange={(e) => setDraft(e.target.value)}
                                        onKeyDown={(e) => e.key === "Enter" && handleSendText()}
                                        onClick={() => { setShowAttachMenu(false); setShowEmojiPicker(false); }}
                                    />

                                    {/* Cleaner Emoji Picker */}
                                    <div className="emoji-picker-container" ref={emojiPickerRef}>
                                        <button
                                            className="chat-emoji-btn"
                                            onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                                        >
                                            <i className="bx bx-smile"></i>
                                        </button>

                                        {showEmojiPicker && (
                                            <div className="emoji-picker-popover">
                                                <EmojiPicker
                                                    onEmojiClick={(e) => setDraft(prev => prev + e.emoji)}
                                                    theme={Theme.LIGHT}
                                                    searchDisabled={true}
                                                    skinTonesDisabled={true}
                                                />
                                            </div>
                                        )}
                                    </div>
                                </div>

                                <button
                                    className={`chat-send-btn ${draft.trim() ? 'active' : ''}`}
                                    onClick={handleSendText}
                                    disabled={!draft.trim()}
                                >
                                    <i className="bx bxs-send"></i>
                                </button>
                            </div>
                        </>
                    )}
                </div>

                {/* RIGHT PANEL */}
                <div className="chats-right-panel custom-scrollbar">
                    {!clientPanel ? (
                        <div className="empty-state">
                            <i className="bx bx-id-card" style={{ fontSize: '48px', color: '#cbd5e1', margin: '0 0 16px 0' }}></i>
                            <p>Loading details...</p>
                        </div>
                    ) : (
                        <>
                            <div className="cp-header">
                                {clientPanel.photoURL ? (
                                    <img src={clientPanel.photoURL} alt="Client" className="cp-avatar" />
                                ) : (
                                    <div className="cp-avatar">{clientPanel.initials}</div>
                                )}
                                <h3 className="cp-name">{clientPanel.fullName}</h3>
                                <div className="cp-subtitle">CLIENT DASHBOARD</div>
                                <div className="cp-view-link" onClick={() => navigate(`/users/${selectedId}`)}>
                                    View Full Profile <i className="bx bx-right-arrow-alt"></i>
                                </div>
                            </div>

                            <div className="cp-body">
                                <div className="cp-section-title">QUICK STATS</div>
                                <div className="cp-stats-grid">
                                    <div className="cp-stat-card">
                                        <div className="cp-stat-label">WEIGHT</div>
                                        <div className="cp-stat-value">{clientPanel.weight} <small>kg</small></div>
                                    </div>
                                    <div className="cp-stat-card">
                                        <div className="cp-stat-label">BF %</div>
                                        <div className="cp-stat-value">{clientPanel.bodyFat} <small>%</small></div>
                                    </div>
                                </div>

                                <div className="cp-data-card">
                                    <div className="cp-data-icon"><i className="bx bx-target-lock"></i></div>
                                    <div className="cp-data-info">
                                        <div className="cp-data-label">PRIMARY GOAL</div>
                                        <div className="cp-data-value">{clientPanel.primaryGoal}</div>
                                    </div>
                                </div>

                                <div className="cp-data-card">
                                    <div className="cp-data-icon"><i className="bx bx-food-menu"></i></div>
                                    <div className="cp-data-info">
                                        <div className="cp-data-label">ACTIVE DIET PLAN</div>
                                        <div className="cp-data-value">{clientPanel.dietPlanName || "None Assigned"}</div>
                                    </div>
                                </div>

                                <div className="cp-section-title" style={{ marginTop: '32px' }}>
                                    SHARED FILES ({sharedFiles.length})
                                </div>
                                <div className="cp-files-list">
                                    {sharedFiles.length === 0 ? (
                                        <div className="empty-state" style={{ padding: '10px 0' }}>
                                            <p style={{ fontSize: '12px' }}>No files shared yet.</p>
                                        </div>
                                    ) : (
                                        sharedFiles.map((f) => (
                                            <div
                                                key={f.id}
                                                className="cp-file-item"
                                                onClick={() => f.templateId && navigate(`/diet-plans/view/${f.templateId}`)}
                                            >
                                                <div className="file-icon">
                                                    <i className={f.type === "diet_plan" ? "bx bx-restaurant" : "bx bx-file-blank"}></i>
                                                </div>
                                                <span className="file-name">{f.name}</span>
                                            </div>
                                        ))
                                    )}
                                </div>
                            </div>
                        </>
                    )}
                </div>
            </div>

            {/* SEND DIET PLAN MODAL */}
            {showDietModal && (
                <div className="diet-modal-overlay" onClick={() => setShowDietModal(false)}>
                    <div className="diet-modal" onClick={e => e.stopPropagation()}>
                        <div className="diet-modal-header">
                            <h2>Share Diet Plan</h2>
                            <button className="diet-modal-close" onClick={() => setShowDietModal(false)}>
                                <i className="bx bx-x"></i>
                            </button>
                        </div>
                        <div className="diet-modal-list custom-scrollbar">
                            {dietTemplates.length === 0 ? (
                                <div className="empty-state">No templates found.</div>
                            ) : (
                                dietTemplates.map(t => (
                                    <div key={t.id} className="diet-modal-item">
                                        <div className="diet-modal-icon">
                                            <i className="bx bx-restaurant"></i>
                                        </div>
                                        <div className="diet-modal-info">
                                            <h4>{t.name}</h4>
                                            <p>{t.subtitle}</p>
                                        </div>
                                        <button className="diet-modal-send-btn" onClick={() => handleSendDietPlan(t)}>
                                            Send
                                        </button>
                                    </div>
                                ))
                            )}
                        </div>
                    </div>
                </div>
            )}
        </Layout>
    );
}