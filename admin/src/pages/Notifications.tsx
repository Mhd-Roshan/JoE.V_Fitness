import { useEffect, useState } from "react";
import {
    collection,
    query,
    orderBy,
    limit,
    getDocs,
    getCountFromServer,
    where,
    updateDoc,
    doc,
    deleteDoc,
    addDoc,
    serverTimestamp,
} from "firebase/firestore";
import { db, auth } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/notifications.css";

interface NotificationItem {
    id: string;
    type: string;
    title: string;
    body: string;
    read: boolean;
    createdAt: Date | null;
}

const TYPE_ICON: Record<string, { icon: string; className: string }> = {
    new_client: { icon: "bx-user-plus", className: "blue" },
    payment: { icon: "bx-credit-card", className: "green" },
    session: { icon: "bx-calendar-check", className: "purple" },
    subscription: { icon: "bx-error", className: "orange" },
};

function timeAgo(date: Date | null): string {
    if (!date) return "";
    const mins = Math.floor((Date.now() - date.getTime()) / 60000);
    if (mins < 1) return "Just now";
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return days === 1 ? "Yesterday" : `${days}d ago`;
}

export default function Notifications() {
    const [notifications, setNotifications] = useState<NotificationItem[]>([]);
    const [unreadCount, setUnreadCount] = useState(0);
    const [userCount, setUserCount] = useState(0);
    const [loading, setLoading] = useState(true);

    // Push composer state
    const [targetAudience, setTargetAudience] = useState("all");
    const [notificationType, setNotificationType] = useState("renewal_reminder");
    const [language, setLanguage] = useState("Malayalam");
    const [title, setTitle] = useState("");
    const [messageBody, setMessageBody] = useState("");
    const [sending, setSending] = useState(false);
    const [sendError, setSendError] = useState<string | null>(null);
    const [sendSuccess, setSendSuccess] = useState(false);

    useEffect(() => {
        let cancelled = false;

        async function load() {
            try {
                const snap = await getDocs(
                    query(collection(db, "notifications"), orderBy("createdAt", "desc"), limit(20))
                );
                if (cancelled) return;

                setNotifications(
                    snap.docs.map((d) => {
                        const data = d.data();
                        return {
                            id: d.id,
                            type: data.type ?? "session",
                            title: data.title ?? "Notification",
                            body: data.body ?? "",
                            read: data.read ?? false,
                            createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : null,
                        };
                    })
                );

                const unreadSnap = await getCountFromServer(
                    query(collection(db, "notifications"), where("read", "==", false))
                );
                if (cancelled) return;
                setUnreadCount(unreadSnap.data().count);

                const usersSnap = await getCountFromServer(
                    query(collection(db, "users"), where("role", "==", "client"))
                );
                if (cancelled) return;
                setUserCount(usersSnap.data().count);
            } catch (err) {
                console.error("Notifications load error:", err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        }

        load();

        return () => {
            cancelled = true;
        };
    }, []);

    async function handleReadAll() {
        try {
            await Promise.all(
                notifications
                    .filter((n) => !n.read)
                    .map((n) => updateDoc(doc(db, "notifications", n.id), { read: true }))
            );
            setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
            setUnreadCount(0);
        } catch (err) {
            console.error("Mark all read failed:", err);
        }
    }

    async function handleClearAll() {
        if (!window.confirm("Clear all notifications? This can't be undone.")) return;
        try {
            await Promise.all(
                notifications.map((n) => deleteDoc(doc(db, "notifications", n.id)))
            );
            setNotifications([]);
            setUnreadCount(0);
        } catch (err) {
            console.error("Clear all failed:", err);
        }
    }

    function resetComposer() {
        setTargetAudience("all");
        setNotificationType("renewal_reminder");
        setLanguage("Malayalam");
        setTitle("");
        setMessageBody("");
        setSendError(null);
    }

    const [sentCount, setSentCount] = useState<number | null>(null);

    async function handleSendNow() {
        if (!title.trim() || !messageBody.trim()) {
            setSendError("Title and message body are required.");
            return;
        }
        setSending(true);
        setSendError(null);
        setSendSuccess(false);
        setSentCount(null);

        try {
            const finalTitle = title.trim();
            const finalBody = messageBody.trim();

            // 1. Determine Target Users
            let recipientIds: string[] = [];

            if (targetAudience === "trainers") {
                const snap = await getDocs(query(collection(db, "users"), where("role", "==", "trainer")));
                recipientIds = snap.docs.map((d) => d.id);
            } else if (targetAudience === "active") {
                const subSnap = await getDocs(query(collection(db, "subscriptions"), where("status", "==", "active")));
                recipientIds = Array.from(new Set(subSnap.docs.map((d) => d.data().clientId || d.data().userId).filter(Boolean)));
                if (recipientIds.length === 0) {
                    const snap = await getDocs(query(collection(db, "users"), where("role", "==", "client")));
                    recipientIds = snap.docs.map((d) => d.id);
                }
            } else if (targetAudience === "expiring") {
                const subSnap = await getDocs(query(collection(db, "subscriptions"), where("status", "==", "due")));
                recipientIds = Array.from(new Set(subSnap.docs.map((d) => d.data().clientId || d.data().userId).filter(Boolean)));
            } else {
                // "all" users
                const snap = await getDocs(collection(db, "users"));
                recipientIds = snap.docs.map((d) => d.id);
            }

            // 2. Deliver in-app notification to each user's notifications subcollection
            const userNotifPromises = recipientIds.map((uid) =>
                addDoc(collection(db, "users", uid, "notifications"), {
                    title: finalTitle,
                    message: finalBody,
                    body: finalBody,
                    type: notificationType,
                    language: language,
                    isRead: false,
                    read: false,
                    timestamp: serverTimestamp(),
                    createdAt: serverTimestamp(),
                }).catch((e) => console.warn(`Failed to deliver to user ${uid}:`, e))
            );

            // 3. Save to Global Notifications feed for Admin
            const adminNotifPromise = addDoc(collection(db, "notifications"), {
                type: notificationType,
                title: finalTitle,
                body: finalBody,
                message: finalBody,
                targetAudience,
                language,
                read: false,
                sentToCount: recipientIds.length,
                createdAt: serverTimestamp(),
            });

            // 4. Save to pushNotificationRequests
            const requestPromise = addDoc(collection(db, "pushNotificationRequests"), {
                targetAudience,
                notificationType,
                language,
                title: finalTitle,
                body: finalBody,
                status: "sent",
                sentCount: recipientIds.length,
                requestedBy: auth.currentUser?.uid ?? null,
                createdAt: serverTimestamp(),
            });

            const [globalDoc] = await Promise.all([
                adminNotifPromise,
                requestPromise,
                ...userNotifPromises,
            ]);

            // Update UI list immediately
            if (globalDoc) {
                setNotifications((prev) => [
                    {
                        id: globalDoc.id,
                        type: notificationType,
                        title: finalTitle,
                        body: finalBody,
                        read: false,
                        createdAt: new Date(),
                    },
                    ...prev,
                ]);
                setUnreadCount((c) => c + 1);
            }

            setSentCount(recipientIds.length);
            setSendSuccess(true);
            resetComposer();
        } catch (err) {
            console.error("Sending notification failed:", err);
            setSendError("Couldn't send this notification. Check your connection and try again.");
        } finally {
            setSending(false);
        }
    }

    if (loading) {
        return (
            <Layout title="Notification">
                <p style={{ color: "#999" }}>Loading notifications...</p>
            </Layout>
        );
    }

    return (
        <Layout title="Notification">
            <div className="notif-layout">
                <div className="notif-feed-card">
                    <div className="notif-feed-header">
                        <div className="notif-feed-title-row">
                            <span className="notif-feed-title">Recent Message</span>
                            {unreadCount > 0 && (
                                <span className="notif-new-badge">{unreadCount} New</span>
                            )}
                        </div>
                        <div className="notif-feed-actions">
                            <button className="notif-read-all-btn" onClick={handleReadAll}>
                                Read all
                            </button>
                            <button className="notif-clear-btn" onClick={handleClearAll}>
                                Clear
                            </button>
                        </div>
                    </div>

                    {notifications.length === 0 ? (
                        <div className="profile-empty" style={{ padding: 24 }}>
                            No notifications yet.
                        </div>
                    ) : (
                        <div className="notif-list">
                            {notifications.map((n) => {
                                const typeInfo = TYPE_ICON[n.type] ?? TYPE_ICON.session;
                                return (
                                    <div key={n.id} className="notif-item">
                                        <span className={`notif-icon-badge ${typeInfo.className}`}>
                                            <i className={`bx ${typeInfo.icon}`} />
                                        </span>
                                        <div className="notif-item-body">
                                            <div className="notif-item-title-row">
                                                <span className="notif-item-title">{n.title}</span>
                                                {!n.read && <span className="notif-unread-dot" />}
                                            </div>
                                            <div className="notif-item-desc">{n.body}</div>
                                            <div className="notif-item-time">
                                                {timeAgo(n.createdAt)}
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </div>

                <div className="notif-composer-card">
                    <div className="notif-composer-title">Send push notification</div>

                    {sendSuccess && (
                        <div className="notif-success-banner">
                            <i className="bx bx-check-circle" style={{ fontSize: "16px", marginRight: "6px" }} />
                            Notification sent successfully to {sentCount ?? "all"} recipient(s)!
                        </div>
                    )}
                    {sendError && <div className="notif-error-banner">{sendError}</div>}

                    <div className="notif-field">
                        <label className="notif-label">Target Audience</label>
                        <select
                            className="notif-select"
                            value={targetAudience}
                            onChange={(e) => setTargetAudience(e.target.value)}
                        >
                            <option value="all">All Users ({userCount})</option>
                            <option value="active">Active Subscribers</option>
                            <option value="expiring">Expiring Soon</option>
                            <option value="trainers">Trainers</option>
                        </select>
                    </div>

                    <div className="notif-field">
                        <label className="notif-label">Notification Type</label>
                        <select
                            className="notif-select"
                            value={notificationType}
                            onChange={(e) => setNotificationType(e.target.value)}
                        >
                            <option value="renewal_reminder">Renewal reminder</option>
                            <option value="promotion">Promotion</option>
                            <option value="session_reminder">Session reminder</option>
                            <option value="general_update">General update</option>
                        </select>
                    </div>

                    <div className="notif-field">
                        <label className="notif-label">Languages</label>
                        <select
                            className="notif-select"
                            value={language}
                            onChange={(e) => setLanguage(e.target.value)}
                        >
                            <option value="Malayalam">Malayalam</option>
                            <option value="English">English</option>
                        </select>
                    </div>

                    <div className="notif-field">
                        <label className="notif-label">Title</label>
                        <input
                            className="notif-input"
                            placeholder="Your JoE.V subscription is due!"
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                        />
                    </div>

                    <div className="notif-field">
                        <label className="notif-label">Message Body</label>
                        <textarea
                            className="notif-textarea"
                            rows={4}
                            placeholder="Hi! Your monthly subscription renews soon. Tap to pay and keep your sessions going."
                            value={messageBody}
                            onChange={(e) => setMessageBody(e.target.value)}
                        />
                    </div>

                    <div className="notif-composer-footer">
                        <button
                            className="notif-send-btn"
                            onClick={handleSendNow}
                            disabled={sending}
                        >
                            <i className="bx bx-send" /> {sending ? "Sending..." : "Send now"}
                        </button>
                        <button className="notif-clear-form-btn" onClick={resetComposer}>
                            Clear
                        </button>
                    </div>
                </div>
            </div>
        </Layout>
    );
}