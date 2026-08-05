import { useState } from "react";
import type { SyntheticEvent } from "react";
import { FirebaseError } from "firebase/app";
import { signInWithEmailAndPassword } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { useNavigate } from "react-router-dom";
import { auth, db } from "../lib/firebase";
import "../styles/login.css";

import documentFrom1 from "../assets/Document from محمد روشان.png";

export default function Login() {
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [rememberMe, setRememberMe] = useState(false);
    const [statusMessage, setStatusMessage] = useState("");
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

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

    const handleSubmit = async (event: SyntheticEvent<HTMLFormElement>) => {
        event.preventDefault();
        setStatusMessage("");

        if (!email || !password) {
            setStatusMessage("Please enter your email and password.");
            return;
        }

        setLoading(true);

        try {
            const cred = await signInWithEmailAndPassword(auth, email, password);

            const userDoc = await getDoc(doc(db, "users", cred.user.uid));
            const role = userDoc.data()?.role;

            if (role !== "admin") {
                await auth.signOut();
                setStatusMessage("This account is not authorized for admin access.");
                setLoading(false);
                return;
            }

            navigate("/");
        } catch (err: unknown) {
            if (err instanceof FirebaseError) {
                setStatusMessage(mapAuthError(err.code));
            } else {
                setStatusMessage("Sign in failed. Please try again.");
            }
            setLoading(false);
        }
    };

    const handleForgotPassword = () => {
        setStatusMessage("Password recovery is not available yet.");
    };

    return (
        <main className="login-page">
            <div className="login-card-wrap">
                <img className="document-from" alt="JoE.V" src={documentFrom1} />

                <form className="rectangle" onSubmit={handleSubmit} noValidate={false}>
                    <div className="field-group">
                        <label className="text-wrapper-2" htmlFor="email">
                            Email
                        </label>
                        <input
                            id="email"
                            name="email"
                            type="email"
                            autoComplete="email"
                            required
                            value={email}
                            onChange={(event) => setEmail(event.target.value)}
                            placeholder="Enter Your Email"
                            className="div"
                        />
                    </div>

                    <div className="field-group">
                        <label className="text-wrapper-3" htmlFor="password">
                            Password
                        </label>
                        <input
                            id="password"
                            name="password"
                            type="password"
                            autoComplete="current-password"
                            required
                            value={password}
                            onChange={(event) => setPassword(event.target.value)}
                            placeholder="Enter Your Password"
                            className="rectangle-2"
                        />
                    </div>

                    <div className="remember-row">
                        <div className="remember-left">
                            <input
                                type="checkbox"
                                name="rememberMe"
                                checked={rememberMe}
                                onChange={(event) => setRememberMe(event.target.checked)}
                                className="rectangle-3"
                                id="rememberMe"
                            />
                            <label className="text-wrapper-4" htmlFor="rememberMe">
                                Remember me
                            </label>
                        </div>

                        <button
                            type="button"
                            className="text-wrapper-6"
                            onClick={handleForgotPassword}
                        >
                            Forgot password?
                        </button>
                    </div>

                    <button type="submit" className="rectangle-4" disabled={loading}>
                        <span className="text-wrapper-5">
                            {loading ? "Logging in..." : "Login"}
                        </span>
                    </button>

                    <p className="status-message" aria-live="polite">
                        {statusMessage}
                    </p>
                </form>
            </div>
        </main>
    );
}

/*
  NOTE on "Remember me": to make this functional, import
  { setPersistence, browserLocalPersistence, browserSessionPersistence }
  from "firebase/auth" and call setPersistence(auth, rememberMe
    ? browserLocalPersistence
    : browserSessionPersistence)
  BEFORE calling signInWithEmailAndPassword.
*/