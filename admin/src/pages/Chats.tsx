import { useEffect, useRef, useState } from "react";
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
} from "firebase/firestore";
import { db, auth } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/chats.css";

interface ThreadRow {
    id: string; // clientId
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
    attachmentName?: string;
    createdAt: string;
}

interface ClientPanelData {
    fullName: string;
    photoURL: string | null;
    primaryGoal: string | null;
    dietPlanName: string | null;
    sharedFiles: string[];
}

export default function Chats() {
    const [threads, setThreads] = useState<ThreadRow[]>([]);
    const [threadSearch, setThreadSearch] = useState("");
    const [selectedId, setSelectedId] = useState<string | null>(null);
    const [messages, setMessages] = useState<MessageRow[]>([]);
    const [clientPanel, setClientPanel] = useState<ClientPanelData | null>(null);
    const [draft, setDraft] = useState("");
    const [loadingThreads, setLoadingThreads] = useState(true);
    const scrollRef = useRef<HTMLDivElement>(null);

    // Live thread list
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
                            ? data.lastMessageAt.toDate().toLocaleString([], {
                                hour: "2-digit",
                                minute: "2-digit",
                            })
                            : "",
                        unreadCount: data.unreadCount ?? 0,
                    };
                })
            );
            setLoadingThreads(false);
            if (!selectedId && snap.docs.length > 0) setSelectedId(snap.docs[0].id);
        });
        return () => unsub();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Live messages for selected thread
    useEffect(() => {
        if (!selectedId) return;
        const q = query(
            collection(db, "chatThreads", selectedId, "messages"),
            orderBy("createdAt", "asc"),
            limit(200)
        );
        const unsub = onSnapshot(q, (snap) => {
            setMessages(
                snap.docs.map((d) => {
                    const data = d.data();
                    return {
                        id: d.id,
                        senderRole: data.senderRole ?? "client",
                        text: data.text ?? "",
                        attachmentName: data.attachmentName,
                        createdAt: data.createdAt?.toDate
                            ? data.createdAt.toDate().toLocaleTimeString([], {
                                hour: "2-digit",
                                minute: "2-digit",
                            })
                            : "",
                    };
                })
            );
            setTimeout(() => {
                scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
            }, 50);
        });
        return () => unsub();
    }, [selectedId]);

    // Client info panel for selected thread
    useEffect(() => {
        if (!selectedId) return;

        let cancelled = false;

        async function loadPanel() {
            try {
                const userSnap = await getDocs(
                    query(collection(db, "users"), where("__name__", "==", selectedId))
                );
                const userData = userSnap.docs[0]?.data();

                const profileSnap = await getDocs(
                    collection(db, "users", selectedId!, "clientProfile")
                );
                const profileData = profileSnap.docs[0]?.data();

                const dietSnap = await getDocs(
                    query(
                        collection(db, "clientDietPlans"),
                        where("clientId", "==", selectedId),
                        where("status", "==", "active"),
                        limit(1)
                    )
                );
                const dietName = dietSnap.docs[0]?.data()?.templateName ?? null;

                const filesSnap = await getDocs(
                    query(
                        collection(db, "chatThreads", selectedId!, "messages"),
                        where("attachmentName", "!=", null)
                    )
                );
                const sharedFiles = filesSnap.docs
                    .map((d) => d.data().attachmentName)
                    .filter(Boolean);

                if (!cancelled) {
                    setClientPanel({
                        fullName: userData?.fullName ?? "Unknown Client",
                        photoURL: userData?.photoURL ?? null,
                        primaryGoal: profileData?.primaryGoal ?? null,
                        dietPlanName: dietName,
                        sharedFiles,
                    });
                }
            } catch (err) {
                console.error("Client panel load error:", err);
                if (!cancelled) setClientPanel(null);
            }
        }

        loadPanel();

        return () => {
            cancelled = true;
        };
    }, [selectedId]);

    async function handleSend() {
        if (!draft.trim() || !selectedId) return;
        const text = draft.trim();
        setDraft("");
        try {
            await addDoc(collection(db, "chatThreads", selectedId, "messages"), {
                senderRole: "admin",
                senderId: auth.currentUser?.uid ?? null,
                text,
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

    const filteredThreads = threads.filter((t) =>
        t.clientName.toLowerCase().includes(threadSearch.toLowerCase())
    );
    const selectedThread = threads.find((t) => t.id === selectedId);

    return (
        <Layout title="Chats">
            <div className="chats-layout">
                <div className="chats-list-panel">
                    <div className="chats-list-header">Messages</div>
                    <div className="chats-search-box">
                        <i className="bx bx-search" />
                        <input
                            placeholder="Search clients, sessions..."
                            value={threadSearch}
                            onChange={(e) => setThreadSearch(e.target.value)}
                        />
                    </div>

                    {loadingThreads ? (
                        <p style={{ color: "#999", padding: 16 }}>Loading...</p>
                    ) : filteredThreads.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 16 }}>
                            No conversations yet.
                        </div>
                    ) : (
                        filteredThreads.map((t) => (
                            <button
                                key={t.id}
                                className={`chat-thread-item ${t.id === selectedId ? "active" : ""}`}
                                onClick={() => setSelectedId(t.id)}
                            >
                                <div className="chat-thread-avatar">
                                    {t.photoURL ? (
                                        <img src={t.photoURL} alt={t.clientName} />
                                    ) : (
                                        t.clientName
                                            .split(" ")
                                            .map((p) => p[0])
                                            .join("")
                                            .slice(0, 2)
                                            .toUpperCase()
                                    )}
                                </div>
                                <div className="chat-thread-body">
                                    <div className="chat-thread-name-row">
                                        <span className="chat-thread-name">{t.clientName}</span>
                                        <span className="chat-thread-time">{t.lastMessageAt}</span>
                                    </div>
                                    <div className="chat-thread-preview">
                                        {t.lastMessage || "No messages yet"}
                                    </div>
                                </div>
                                {t.unreadCount > 0 && (
                                    <span className="chat-thread-unread">{t.unreadCount}</span>
                                )}
                            </button>
                        ))
                    )}
                </div>

                <div className="chats-thread-panel">
                    {!selectedThread ? (
                        <div className="chats-empty-state">Select a conversation to view messages.</div>
                    ) : (
                        <>
                            <div className="chats-thread-header">
                                <div className="chat-thread-avatar">
                                    {selectedThread.photoURL ? (
                                        <img src={selectedThread.photoURL} alt={selectedThread.clientName} />
                                    ) : (
                                        selectedThread.clientName
                                            .split(" ")
                                            .map((p) => p[0])
                                            .join("")
                                            .slice(0, 2)
                                            .toUpperCase()
                                    )}
                                </div>
                                <div>
                                    <div className="chats-thread-header-name">
                                        {selectedThread.clientName}
                                    </div>
                                </div>
                            </div>

                            <div className="chats-messages" ref={scrollRef}>
                                {messages.length === 0 ? (
                                    <div className="profile-empty">No messages yet.</div>
                                ) : (
                                    messages.map((m) => (
                                        <div
                                            key={m.id}
                                            className={`chat-bubble-row ${m.senderRole === "admin" ? "sent" : "received"
                                                }`}
                                        >
                                            <div className="chat-bubble">
                                                {m.attachmentName && (
                                                    <div className="chat-bubble-attachment">
                                                        <i className="bx bx-file" /> {m.attachmentName}
                                                    </div>
                                                )}
                                                {m.text && <div>{m.text}</div>}
                                                <div className="chat-bubble-time">{m.createdAt}</div>
                                            </div>
                                        </div>
                                    ))
                                )}
                            </div>

                            <div className="chats-input-row">
                                <button className="chats-attach-btn" title="Attach diet plan or file">
                                    <i className="bx bx-paperclip" />
                                </button>
                                <input
                                    className="chats-input"
                                    placeholder="Type a message..."
                                    value={draft}
                                    onChange={(e) => setDraft(e.target.value)}
                                    onKeyDown={(e) => e.key === "Enter" && handleSend()}
                                />
                                <button className="chats-send-btn" onClick={handleSend}>
                                    <i className="bx bx-send" />
                                </button>
                            </div>
                        </>
                    )}
                </div>

                <div className="chats-client-panel">
                    {!selectedId ? (
                        <div className="profile-empty" style={{ padding: 16 }}>
                            Select a conversation to see client details.
                        </div>
                    ) : !clientPanel ? (
                        <p style={{ color: "#999", padding: 16 }}>Loading...</p>
                    ) : (
                        <>
                            <div className="client-panel-photo">
                                {clientPanel.photoURL ? (
                                    <img src={clientPanel.photoURL} alt={clientPanel.fullName} />
                                ) : (
                                    <div className="client-panel-photo-fallback">
                                        {clientPanel.fullName
                                            .split(" ")
                                            .map((p) => p[0])
                                            .join("")
                                            .slice(0, 2)
                                            .toUpperCase()}
                                    </div>
                                )}
                            </div>
                            <div className="client-panel-name">{clientPanel.fullName}</div>
                            <button className="client-panel-view-btn">View Full Profile</button>

                            <div className="client-panel-section-title">Active Diet Plan</div>
                            {clientPanel.primaryGoal && (
                                <span className="client-panel-tag">{clientPanel.primaryGoal}</span>
                            )}
                            {clientPanel.dietPlanName ? (
                                <span className="client-panel-tag">{clientPanel.dietPlanName}</span>
                            ) : (
                                <div className="profile-empty">No active plan assigned.</div>
                            )}

                            <div className="client-panel-section-title">
                                Shared Files ({clientPanel.sharedFiles.length})
                            </div>
                            {clientPanel.sharedFiles.length === 0 ? (
                                <div className="profile-empty">No files shared yet.</div>
                            ) : (
                                clientPanel.sharedFiles.map((f, i) => (
                                    <div key={i} className="client-panel-file-pill">
                                        <i className="bx bx-file" /> {f}
                                    </div>
                                ))
                            )}

                            <button className="client-panel-note-btn">Private Trainer Note</button>
                        </>
                    )}
                </div>
            </div>
        </Layout>
    );
}