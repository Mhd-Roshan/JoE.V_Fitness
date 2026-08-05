import { useEffect, useState, type ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { onAuthStateChanged, type User } from "firebase/auth";
import { auth } from "../lib/firebase";

export default function RequireAuth({ children }: { children: ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [checked, setChecked] = useState(false);

    useEffect(() => {
        const unsub = onAuthStateChanged(auth, (u) => {
            setUser(u);
            setChecked(true);
        });
        return () => unsub();
    }, []);

    if (!checked) {
        return (
            <div style={{ padding: 40, textAlign: "center", color: "#999" }}>
                Checking session...
            </div>
        );
    }

    if (!user) {
        return <Navigate to="/login" replace />;
    }

    return <>{children}</>;
}