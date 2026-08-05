import { initializeApp, getApps } from "firebase/app";
import { getAuth, initializeAuth, inMemoryPersistence } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";


const firebaseConfig = {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Secondary app: used ONLY to create trainer/client accounts without
// signing the currently logged-in admin out of their own session.
// Uses in-memory persistence so it never contends with the admin's
// IndexedDB auth lock — without this, createUserWithEmailAndPassword
// on this instance can hang indefinitely.
const secondaryApp =
    getApps().find((a) => a.name === "Secondary") ??
    initializeApp(firebaseConfig, "Secondary");

let secondaryAuth;
try {
    secondaryAuth = initializeAuth(secondaryApp, {
        persistence: inMemoryPersistence,
    });
} catch {
    // Already initialized (e.g. Vite hot-reload) — reuse the existing instance.
    secondaryAuth = getAuth(secondaryApp);
}

export { secondaryAuth };