import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { useNavigate } from "react-router-dom";
import { auth, db } from "../lib/firebase";

export default function Login() {
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    async function handleLogin(e: React.FormEvent) {
        e.preventDefault();
        setError(null);
        setLoading(true);

        try {
            const cred = await signInWithEmailAndPassword(auth, email, password);

            // Verify this account is actually an admin — not a trainer account
            // that somehow got the wrong login URL
            const userDoc = await getDoc(doc(db, "users", cred.user.uid));
            const role = userDoc.data()?.role;

            if (role !== "admin") {
                await auth.signOut();
                setError("This account is not authorized for admin access.");
                setLoading(false);
                return;
            }

            navigate("/");
        } catch (err: any) {
            setError(mapAuthError(err.code));
            setLoading(false);
        }
    }

    function mapAuthError(code: string) {
        switch (code) {
            case "auth/invalid-credential":
            case "auth/wrong-password":
                return "Incorrect email or password.";
            case "auth/user-not-found":
                return "No account found with this email.";
            case "auth/too-many-requests":
                return "Too many attempts. Try again later.";
            default:
                return "Sign in failed. Please try again.";
        }
    }

    return (
        <div style={styles.page}>
            <form style={styles.card} onSubmit={handleLogin}>
                <h1 style={styles.title}>JoE.V Fitness Admin</h1>
                <p style={styles.subtitle}>Sign in to manage the platform</p>

                <label style={styles.label}>Email</label>
                <input
                    style={styles.input}
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    autoComplete="email"
                />

                <label style={styles.label}>Password</label>
                <input
                    style={styles.input}
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    autoComplete="current-password"
                />

                {error && <div style={styles.error}>{error}</div>}

                <button style={styles.button} type="submit" disabled={loading}>
                    {loading ? "Signing in..." : "Sign In"}
                </button>
            </form>
        </div>
    );
}

const styles: Record<string, React.CSSProperties> = {
    page: {
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "#f5f7fa",
    },
    card: {
        background: "#fff",
        padding: "40px",
        borderRadius: "16px",
        width: "360px",
        boxShadow: "0 8px 24px rgba(0,0,0,0.08)",
    },
    title: { color: "#00225D", margin: 0, fontSize: "22px" },
    subtitle: { color: "#666", marginTop: "4px", marginBottom: "24px", fontSize: "14px" },
    label: { fontSize: "13px", fontWeight: 600, color: "#00225D", marginBottom: "4px", display: "block" },
    input: {
        width: "100%",
        padding: "10px 12px",
        marginBottom: "16px",
        borderRadius: "8px",
        border: "1px solid #ddd",
        fontSize: "14px",
        boxSizing: "border-box",
    },
    error: { color: "#ff0000", fontSize: "13px", marginBottom: "12px" },
    button: {
        width: "100%",
        padding: "12px",
        background: "#ff0000",
        color: "#fff",
        border: "none",
        borderRadius: "999px",
        fontWeight: 700,
        fontSize: "15px",
        cursor: "pointer",
    },
};