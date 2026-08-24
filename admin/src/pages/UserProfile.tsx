import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
    doc,
    getDoc,
    collection,
    query,
    where,
    getDocs,
    updateDoc,
    addDoc,
    type DocumentReference,
    type Query,
    type DocumentData,
    type DocumentSnapshot,
    type QuerySnapshot
} from "firebase/firestore";
import { db } from "../lib/firebase";
import Layout from "../components/Layout";
import "../styles/userProfile.css";

// ------------------------------------------------------------------
// Types
// ------------------------------------------------------------------
interface ClientInfo {
    fullName: string;
    initials: string;
    photoURL?: string | null;
}

interface ClientProfileData {
    primaryGoal?: string;
    location?: string;
}

interface SubscriptionInfo {
    trainerName: string;
    status: string;
}

interface MeasurementEntry {
    id: string;
    date: string;
    weightKg?: string | number;
    sleepHours?: string | number;
    waterL?: string | number;
    steps?: string | number;
}

interface HealthCondition {
    id: string;
    conditionName: string;
}

interface Procedure {
    id: string;
    procedureName: string;
    procedureDate?: string;
    recoveryStatus?: string;
}

interface Medication {
    id: string;
    name: string;
}

interface SessionEntry {
    id: string;
    serviceType: string;
    trainerName: string;
    scheduledDate: string;
    time: string;
}

interface DietPlanSummary {
    templateId?: string;
    templateName?: string;
    weekNumber?: number;
    netCarbsG?: number;
    fastingWindow?: string;
}

interface ActionItem {
    id: string;
    title: string;
    completed: boolean;
    dueDate?: string;
}

interface RawProgressData {
    date?: string;
    weight?: number;
    sleep?: number;
    hydration?: number;
    steps?: number;
}

// ------------------------------------------------------------------
// Date Helpers
// ------------------------------------------------------------------
const parseDateFlexible = (val: unknown): Date | null => {
    if (!val) return null;
    if (typeof (val as { toDate?: () => Date }).toDate === "function") {
        return (val as { toDate: () => Date }).toDate();
    }
    if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
    if (typeof val === "number") {
        const ms = val < 10000000000 ? val * 1000 : val;
        const d = new Date(ms);
        return isNaN(d.getTime()) ? null : d;
    }
    if (typeof val === "string") {
        const s = val.trim();
        if (!s || s === "—") return null;

        const parsed = new Date(s);
        if (!isNaN(parsed.getTime())) return parsed;

        const isoMatch = s.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/);
        if (isoMatch) {
            const y = parseInt(isoMatch[1], 10);
            const m = parseInt(isoMatch[2], 10) - 1;
            const d = parseInt(isoMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }

        const dmyMatch = s.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})/);
        if (dmyMatch) {
            const d = parseInt(dmyMatch[1], 10);
            const m = parseInt(dmyMatch[2], 10) - 1;
            const y = parseInt(dmyMatch[3], 10);
            const res = new Date(y, m, d);
            if (!isNaN(res.getTime())) return res;
        }
    }
    return null;
};

const formatFullDate = (dString: unknown) => {
    if (!dString || dString === "—") return "—";
    const d = parseDateFlexible(dString);
    if (!d) return dString.toString();
    return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
};

const formatShortDate = (dString: unknown) => {
    if (!dString || dString === "—") return "—";
    const d = parseDateFlexible(dString);
    if (!d) return dString.toString();
    return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
};

// ------------------------------------------------------------------
// Main Component
// ------------------------------------------------------------------
export default function UserProfile() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();

    const [client, setClient] = useState<ClientInfo | null>(null);
    const [profile, setProfile] = useState<ClientProfileData>({});
    const [subscription, setSubscription] = useState<SubscriptionInfo | null>(null);
    const [measurements, setMeasurements] = useState<MeasurementEntry[]>([]);
    const [conditions, setConditions] = useState<HealthCondition[]>([]);
    const [procedures, setProcedures] = useState<Procedure[]>([]);
    const [medications, setMedications] = useState<Medication[]>([]);
    const [sessions, setSessions] = useState<SessionEntry[]>([]);
    const [totalSessions, setTotalSessions] = useState<number>(0);
    const [dietPlan, setDietPlan] = useState<DietPlanSummary | null>(null);

    // Measurement Tabs State
    const [timeFilter, setTimeFilter] = useState<"Day" | "Week" | "Month">("Day");

    // Action Checkout State
    const [actionItems, setActionItems] = useState<ActionItem[]>([]);
    const [newTaskTitle, setNewTaskTitle] = useState("");
    const [addingTask, setAddingTask] = useState(false);

    // Location & Coordinates State
    const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);
    const [isLocationModalOpen, setIsLocationModalOpen] = useState(false);
    const [locationInput, setLocationInput] = useState("");
    const [savingLocation, setSavingLocation] = useState(false);

    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!id) return;
        let isMounted = true;

        async function loadProfileFast() {
            try {
                const safeGetDoc = async (docRef: DocumentReference<DocumentData>) => {
                    try {
                        return await getDoc(docRef);
                    } catch (e) {
                        console.warn("Doc fetch error:", e);
                        return { exists: () => false, data: () => ({}) } as unknown as DocumentSnapshot<DocumentData>;
                    }
                };
                const safeGetDocs = async (queryRef: Query<DocumentData>) => {
                    try {
                        return await getDocs(queryRef);
                    } catch (e) {
                        console.warn("Docs fetch error:", e);
                        return { empty: true, docs: [] } as unknown as QuerySnapshot<DocumentData>;
                    }
                };

                // 1. Fetch User Record with fallbacks
                let userSnap = await safeGetDoc(doc(db, "users", id!));
                if (!userSnap.exists()) {
                    const fallbackUser = await safeGetDocs(query(collection(db, "users"), where("uid", "==", id!)));
                    if (!fallbackUser.empty) {
                        userSnap = fallbackUser.docs[0];
                    } else {
                        userSnap = await safeGetDoc(doc(db, "clients", id!));
                    }
                }

                // Fetch all related subcollections & associated data concurrently
                const [
                    profileSnap, subSnap,
                    bookingsUserSnap, bookingsClientSnap,
                    sessionsUserSnap, sessionsClientSnap,
                    progressSnap, dietSnap, conditionsSnap,
                    proceduresSnap, medsSnap, actionItemsSnap,
                    assessDocSnap, assessUserSnap, assessClientSnap
                ] = await Promise.all([
                    safeGetDoc(doc(db, "users", id!, "clientProfile", id!)),
                    safeGetDocs(query(collection(db, "subscriptions"), where("clientId", "==", id))),
                    safeGetDocs(query(collection(db, "bookings"), where("userId", "==", id))),
                    safeGetDocs(query(collection(db, "bookings"), where("clientId", "==", id))),
                    safeGetDocs(query(collection(db, "sessions"), where("userId", "==", id))),
                    safeGetDocs(query(collection(db, "sessions"), where("clientId", "==", id))),
                    safeGetDocs(collection(db, "users", id!, "progress_history")),
                    safeGetDocs(query(collection(db, "clientDietPlans"), where("clientId", "==", id))),
                    safeGetDocs(collection(db, "users", id!, "healthConditions")),
                    safeGetDocs(collection(db, "users", id!, "proceduresSurgeries")),
                    safeGetDocs(collection(db, "users", id!, "medications")),
                    safeGetDocs(collection(db, "users", id!, "actionItems")),
                    safeGetDoc(doc(db, "assessments", id!)),
                    safeGetDocs(query(collection(db, "assessments"), where("userId", "==", id!))),
                    safeGetDocs(query(collection(db, "assessments"), where("clientId", "==", id!)))
                ]);

                if (!userSnap.exists() && isMounted) {
                    setClient(null);
                    setLoading(false);
                    return;
                }

                // Safely cast data to objects
                const userData = (userSnap.data() || {}) as Record<string, unknown>;
                const profileData = (profileSnap.exists() ? profileSnap.data() : {}) as Record<string, unknown>;

                let assessData: Record<string, unknown> = {};
                if (assessDocSnap.exists()) {
                    assessData = assessDocSnap.data() as Record<string, unknown>;
                } else if (!assessUserSnap.empty) {
                    assessData = assessUserSnap.docs[0].data() as Record<string, unknown>;
                } else if (!assessClientSnap.empty) {
                    assessData = assessClientSnap.docs[0].data() as Record<string, unknown>;
                }

                const fullName = (userData.fullName || userData.name || profileData.fullName || profileData.name || "Unknown Client") as string;
                const initials = fullName.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase() || "CL";

                const photoURL = (
                    userData.photoURL || userData.profileImage || userData.avatar || userData.avatarUrl || userData.imageUrl || userData.photo ||
                    profileData.photoURL || profileData.profileImage || profileData.avatar || profileData.avatarUrl || profileData.imageUrl || profileData.photo ||
                    assessData.photoURL || assessData.profileImage
                ) as string | null || null;

                // -------------------------------------------------------------
                // AGGRESSIVE DATA EXTRACTOR for Profile Info & Location
                // -------------------------------------------------------------
                let parsedCoords: { lat: number; lng: number } | null = null;

                const findValue = (sources: unknown[], keys: string[]): string | undefined => {
                    for (const source of sources) {
                        if (!source || typeof source !== 'object') continue;
                        const srcObj = source as Record<string, unknown>;
                        for (const key of keys) {
                            const val = srcObj[key];
                            if (typeof val === 'string' && val.trim() !== '' && val.toLowerCase() !== 'not set' && val.toLowerCase() !== 'null') return val.trim();
                            if (Array.isArray(val) && val.length > 0 && typeof val[0] === 'string' && val[0].trim() !== '') return val[0].trim();

                            // If it's a nested object (e.g. { city: "Vytilla", state: "Kerala" })
                            if (typeof val === 'object' && val !== null) {
                                const obj = val as Record<string, unknown>;
                                if (typeof obj.city === 'string' && obj.city.trim() !== '') return obj.city.trim();
                                if (typeof obj.address === 'string' && obj.address.trim() !== '') return obj.address.trim();
                                if (typeof obj.locationAddress === 'string' && obj.locationAddress.trim() !== '') return obj.locationAddress.trim();
                                if (typeof obj.place === 'string' && obj.place.trim() !== '') return obj.place.trim();
                                if (typeof obj.placeName === 'string' && obj.placeName.trim() !== '') return obj.placeName.trim();
                                if (typeof obj.name === 'string' && obj.name.trim() !== '') return obj.name.trim();
                                if (typeof obj.title === 'string' && obj.title.trim() !== '') return obj.title.trim();
                                if (typeof obj.value === 'string' && obj.value.trim() !== '') return obj.value.trim();
                            }
                        }
                    }
                    return undefined;
                };

                const possibleSources = [
                    userData, profileData, assessData,
                    userData.personalInfo, userData.personalDetails, userData.contactInfo, userData.address, userData.location, userData.currentLocation, userData.profile,
                    profileData.personalInfo, profileData.personalDetails, profileData.address, profileData.location, profileData.profile,
                    assessData.personalInfo, assessData.fitnessGoals, assessData.personalDetails, assessData.location, assessData.generalInfo, assessData.lifestyle
                ];

                // Check for explicit GPS coordinates
                possibleSources.forEach(s => {
                    if (s && typeof s === 'object') {
                        const obj = s as Record<string, unknown>;
                        const lat = obj.latitude ?? obj.lat ?? (obj.coords as Record<string, unknown>)?.latitude ?? (obj.coords as Record<string, unknown>)?.lat;
                        const lng = obj.longitude ?? obj.lng ?? (obj.coords as Record<string, unknown>)?.longitude ?? (obj.coords as Record<string, unknown>)?.lng;
                        if (typeof lat === 'number' && typeof lng === 'number' && lat !== 0 && lng !== 0 && !parsedCoords) {
                            parsedCoords = { lat, lng };
                        }
                    }
                });

                // Check booking / session coordinates if not found
                const bookingDocs = [...bookingsUserSnap.docs, ...bookingsClientSnap.docs, ...sessionsUserSnap.docs, ...sessionsClientSnap.docs];
                bookingDocs.forEach(bDoc => {
                    const bData = bDoc.data();
                    if (!parsedCoords) {
                        const bLat = bData.locationLat ?? bData.lat ?? (bData.location as Record<string, unknown>)?.lat;
                        const bLng = bData.locationLng ?? bData.lng ?? (bData.location as Record<string, unknown>)?.lng;
                        if (typeof bLat === 'number' && typeof bLng === 'number' && bLat !== 0 && bLng !== 0) {
                            parsedCoords = { lat: bLat, lng: bLng };
                        }
                    }
                });

                const extractedGoal = findValue(possibleSources, [
                    'primaryGoal', 'goal', 'fitnessGoal', 'goals', 'PrimaryGoal', 'objective', 'My Goals'
                ]) || "Not set";

                let extractedLocation = findValue(possibleSources, [
                    'location', 'address', 'city', 'Location', 'Address', 'City', 'currentLocation', 'locationAddress', 'locality', 'state', 'town', 'place', 'placeName', 'homeAddress', 'area', 'district', 'pincode', 'region'
                ]);

                if (!extractedLocation) {
                    for (const bDoc of bookingDocs) {
                        const bData = bDoc.data();
                        const bLoc = bData.locationAddress || bData.locationTitle || bData.address || (typeof bData.location === 'string' ? bData.location : (bData.location as Record<string, unknown>)?.address);
                        if (typeof bLoc === 'string' && bLoc.trim()) {
                            extractedLocation = bLoc.trim();
                            break;
                        }
                    }
                }

                if (!extractedLocation && parsedCoords) {
                    extractedLocation = `${parsedCoords.lat.toFixed(4)}, ${parsedCoords.lng.toFixed(4)}`;
                }

                if (isMounted) {
                    setClient({ fullName, initials, photoURL });
                    setCoords(parsedCoords);
                    setProfile({
                        primaryGoal: extractedGoal,
                        location: extractedLocation || "Not set"
                    });
                }

                // Process Subscriptions
                let subStatus = "No Subscription";
                let trainerId = (userData.assignedTrainerId || userData.trainerId) as string | undefined;
                let trainerName = (userData.trainerName || "—") as string;

                if (!subSnap.empty) {
                    const subData = subSnap.docs[0].data();
                    subStatus = subData.status === "active" ? "Active" : subData.status === "due" ? "Due" : "Expired";
                    if (subData.trainerId) trainerId = subData.trainerId;
                } else if (userData.subscriptionStatus || userData.isActive) {
                    subStatus = userData.isActive ? "Active" : (userData.subscriptionStatus as string);
                }

                if (trainerId && (trainerName === "—" || !trainerName)) {
                    try {
                        const tSnap = await getDoc(doc(db, "trainers", trainerId));
                        if (tSnap.exists()) trainerName = tSnap.data().fullName || tSnap.data().name;
                        else {
                            const uSnap = await getDoc(doc(db, "users", trainerId));
                            if (uSnap.exists()) trainerName = uSnap.data().fullName || uSnap.data().name;
                        }
                    } catch (error) {
                        console.warn("Could not fetch trainer", error);
                    }
                }

                if (isMounted) setSubscription({ trainerName, status: subStatus });

                // Process Action Items (Checkout list)
                if (isMounted) {
                    const fetchedActions = actionItemsSnap.docs.map(d => ({
                        id: d.id,
                        title: d.data().title || "Untitled Task",
                        completed: !!d.data().completed,
                        dueDate: d.data().dueDate || ""
                    }));
                    fetchedActions.sort((a, b) => Number(a.completed) - Number(b.completed));
                    setActionItems(fetchedActions);
                }

                // Process Measurements
                const sortedProgress = progressSnap.docs
                    .map(d => ({ id: d.id, ...(d.data() as RawProgressData) }))
                    .sort((a, b) => (b.date || b.id).localeCompare(a.date || a.id));

                if (isMounted) {
                    setMeasurements(sortedProgress.map(p => ({
                        id: p.id,
                        date: p.date || p.id,
                        weightKg: p.weight ?? "—",
                        sleepHours: p.sleep ?? "—",
                        waterL: p.hydration ? (p.hydration / 1000).toFixed(1) : "—",
                        steps: p.steps?.toLocaleString() ?? "—"
                    })));
                }

                // Process Bookings & Sessions
                const allDocsMap = new Map<string, Record<string, unknown>>();
                [
                    ...bookingsUserSnap.docs,
                    ...bookingsClientSnap.docs,
                    ...sessionsUserSnap.docs,
                    ...sessionsClientSnap.docs
                ].forEach(d => {
                    const docData = d.data() as Record<string, unknown>;
                    const uniqueKey = (docData.bookingId || docData.sessionId || d.id) as string;
                    if (!allDocsMap.has(uniqueKey)) {
                        allDocsMap.set(uniqueKey, { id: d.id, ...docData });
                    }
                });

                const sortedBookings = Array.from(allDocsMap.values()).map(b => {
                    const rawDate = (b.scheduledDate || b.date || b.sessionDate || b.bookingDate || b.createdAt || b.timestamp) as unknown;
                    const parsedDate = parseDateFlexible(rawDate);
                    return {
                        id: b.id as string,
                        serviceType: (b.sessionType || b.serviceType || b.service || b.plan || "Training Session") as string,
                        trainerName: (b.trainerName || b.trainer || b.assignedTrainerName || trainerName || "Trainer") as string,
                        scheduledDate: (rawDate ? rawDate.toString() : "—"),
                        dateObj: parsedDate,
                        time: (b.time || b.startTime || b.scheduledTime || "") as string,
                    };
                }).sort((a, b) => {
                    const dateA = a.dateObj ? a.dateObj.getTime() : 0;
                    const dateB = b.dateObj ? b.dateObj.getTime() : 0;
                    return dateB - dateA;
                });

                if (isMounted) {
                    setTotalSessions(sortedBookings.length);
                    setSessions(sortedBookings.slice(0, 5).map(b => ({
                        id: b.id,
                        serviceType: b.serviceType,
                        trainerName: b.trainerName,
                        scheduledDate: b.scheduledDate,
                        time: b.time
                    })));
                }

                // Process Medical Data
                if (isMounted) {
                    const extractStrings = (rawData: unknown): string[] => {
                        if (!rawData || rawData === "") return [];
                        if (typeof rawData === "string") {
                            if (rawData.toLowerCase() === "none" || rawData.toLowerCase() === "na" || rawData.toLowerCase() === "null") return [];
                            return rawData.split(",").map(s => s.trim()).filter(Boolean);
                        }
                        const parseItem = (item: unknown): string | null => {
                            if (typeof item === "string") {
                                if (item.toLowerCase() === "none" || item.toLowerCase() === "na" || item.toLowerCase() === "null") return null;
                                return item.trim() || null;
                            }
                            if (typeof item === "object" && item !== null) {
                                const obj = item as Record<string, unknown>;
                                const val = obj.name || obj.conditionName || obj.procedureName || obj.medicationName || obj.condition || obj.title || obj.type || obj.area;
                                if (typeof val === "string" && val.trim()) return val.trim();
                            }
                            return null;
                        };
                        if (Array.isArray(rawData)) return rawData.map(parseItem).filter((s): s is string => Boolean(s));
                        if (typeof rawData === "object" && rawData !== null) return Object.values(rawData).map(parseItem).filter((s): s is string => Boolean(s));
                        return [];
                    };

                    const combineFields = (...fields: unknown[]): string[] => {
                        const combined: string[] = [];
                        for (const field of fields) combined.push(...extractStrings(field));
                        return Array.from(new Set(combined));
                    };

                    // 1. Health Conditions & Constraints
                    const subConds = conditionsSnap.docs.map(d => d.data().conditionName || d.data().name || d.data().condition || "Unknown");
                    const allCondsStrs = combineFields(
                        subConds,
                        userData.healthConditions,
                        userData.medicalConditions,
                        userData.physicalConstraints,
                        userData.injuries,
                        userData.conditions,
                        profileData.healthConditions,
                        profileData.medicalConditions,
                        profileData.physicalConstraints,
                        profileData.injuries,
                        assessData.healthConditions,
                        assessData.medicalConditions,
                        assessData.physicalConstraints,
                        assessData.injuries,
                        assessData.medicalHistory,
                        assessData.limitations
                    );
                    setConditions(allCondsStrs.map((str, idx) => ({ id: `cond-${idx}`, conditionName: str })));

                    // 2. Medications
                    const subMeds = medsSnap.docs.map(d => d.data().name || d.data().medicationName || "Unknown");
                    const allMedsStrs = combineFields(
                        subMeds,
                        userData.medications,
                        userData.prescriptions,
                        userData.drugs,
                        profileData.medications,
                        profileData.prescriptions,
                        assessData.medications,
                        assessData.currentMedications,
                        assessData.supplements
                    );
                    setMedications(allMedsStrs.map((str, idx) => ({ id: `med-${idx}`, name: str })));

                    // 3. Procedures / Surgeries
                    const finalProcs: Procedure[] = proceduresSnap.docs.map(d => ({
                        id: d.id,
                        procedureName: (d.data().procedureName || d.data().name || d.data().surgeryName || "Procedure") as string,
                        procedureDate: d.data().procedureDate || d.data().date,
                        recoveryStatus: d.data().recoveryStatus || d.data().status
                    }));

                    const existingProcNames = new Set(finalProcs.map(p => p.procedureName.toLowerCase()));

                    // Also extract detailed surgery objects directly from user / profile / assess data
                    const rawSurgeriesArrays = [userData.surgeries, userData.proceduresSurgeries, profileData.surgeries, profileData.proceduresSurgeries, assessData.surgeries, assessData.procedures];
                    rawSurgeriesArrays.forEach((arr) => {
                        if (Array.isArray(arr)) {
                            arr.forEach((item, idx) => {
                                if (typeof item === "object" && item !== null) {
                                    const obj = item as Record<string, unknown>;
                                    const pName = (obj.name || obj.surgeryName || obj.procedureName || obj.procedure || "Surgery").toString().trim();
                                    const pDate = (obj.date || obj.procedureDate || "").toString().trim();
                                    const pRec = (obj.recoveryStatus || (obj.ongoingRehab ? "Ongoing Rehab" : "") || obj.status || "").toString().trim();
                                    if (pName && !existingProcNames.has(pName.toLowerCase())) {
                                        existingProcNames.add(pName.toLowerCase());
                                        finalProcs.push({
                                            id: `surg-obj-${idx}`,
                                            procedureName: pName,
                                            procedureDate: pDate || undefined,
                                            recoveryStatus: pRec || undefined
                                        });
                                    }
                                }
                            });
                        }
                    });

                    const extraProcStrs = combineFields(
                        userData.surgeries, userData.proceduresSurgeries, userData.procedures, userData.operations,
                        profileData.surgeries, profileData.proceduresSurgeries,
                        assessData.surgeries, assessData.procedures, assessData.pastSurgeries, assessData.operations
                    );

                    extraProcStrs.forEach((str, idx) => {
                        if (!existingProcNames.has(str.toLowerCase())) {
                            existingProcNames.add(str.toLowerCase());
                            finalProcs.push({ id: `extra-proc-${idx}`, procedureName: str });
                        }
                    });
                    setProcedures(finalProcs);

                    // Diet Plan
                    if (!dietSnap.empty) {
                        const activePlanDoc = dietSnap.docs.find(d => d.data().status === "active") || dietSnap.docs[0];
                        const d = activePlanDoc.data();
                        setDietPlan({
                            templateId: d.templateId,
                            templateName: d.templateName,
                            weekNumber: d.weekNumber,
                            netCarbsG: d.netCarbsG,
                            fastingWindow: d.fastingWindow,
                        });
                    }
                }
            } catch (err) {
                console.error("Profile load error:", err);
            } finally {
                if (isMounted) setLoading(false);
            }
        }

        loadProfileFast();
        return () => { isMounted = false; };
    }, [id]);

    // ------------------------------------------------------------------
    // Action Checkout Handlers
    // ------------------------------------------------------------------
    const toggleActionItem = async (itemId: string, currentCompleted: boolean) => {
        if (!id) return;

        setActionItems(prev =>
            prev.map(item => item.id === itemId ? { ...item, completed: !currentCompleted } : item)
                .sort((a, b) => Number(a.completed) - Number(b.completed))
        );

        try {
            await updateDoc(doc(db, "users", id, "actionItems", itemId), { completed: !currentCompleted });
        } catch (error) {
            console.error("Error updating task:", error);
            setActionItems(prev =>
                prev.map(item => item.id === itemId ? { ...item, completed: currentCompleted } : item)
                    .sort((a, b) => Number(a.completed) - Number(b.completed))
            );
        }
    };

    const handleAddTask = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newTaskTitle.trim() || !id) return;

        setAddingTask(true);
        try {
            const docRef = await addDoc(collection(db, "users", id, "actionItems"), {
                title: newTaskTitle.trim(),
                completed: false,
                createdAt: new Date().toISOString()
            });

            setActionItems(prev => [
                { id: docRef.id, title: newTaskTitle.trim(), completed: false },
                ...prev
            ].sort((a, b) => Number(a.completed) - Number(b.completed)));

            setNewTaskTitle("");
        } catch (error) {
            console.error("Error adding task:", error);
        } finally {
            setAddingTask(false);
        }
    };

    // ------------------------------------------------------------------
    // Location Management Handlers & Google Maps URL
    // ------------------------------------------------------------------
    const handleSaveLocation = async (customLoc?: string, customCoords?: { lat: number; lng: number }) => {
        const locToSave = customLoc !== undefined ? customLoc : locationInput.trim();
        if (!id || !locToSave) return;
        setSavingLocation(true);
        try {
            const updateData: Record<string, unknown> = {
                location: locToSave,
                address: locToSave,
            };
            if (customCoords) {
                updateData.lat = customCoords.lat;
                updateData.lng = customCoords.lng;
                updateData.latitude = customCoords.lat;
                updateData.longitude = customCoords.lng;
                setCoords(customCoords);
            }
            await updateDoc(doc(db, "users", id), updateData);
            setProfile(prev => ({ ...prev, location: locToSave }));
            setIsLocationModalOpen(false);
        } catch (error) {
            console.error("Error saving location:", error);
        } finally {
            setSavingLocation(false);
        }
    };

    const handleDetectGps = () => {
        if (!navigator.geolocation) {
            alert("Geolocation is not supported by your browser.");
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const { latitude, longitude } = position.coords;
                const coordsStr = `${latitude.toFixed(5)}, ${longitude.toFixed(5)}`;
                setLocationInput(coordsStr);
                setCoords({ lat: latitude, lng: longitude });
            },
            (err) => {
                console.error("Geolocation error:", err);
                alert("Could not fetch current device GPS location. Please check browser permissions.");
            }
        );
    };

    // ------------------------------------------------------------------
    // Computed Variables (Location & Measurements Filter)
    // ------------------------------------------------------------------
    const hasValidLocation = profile.location && profile.location.toLowerCase() !== "not set";
    const googleMapsUrl = coords
        ? `https://www.google.com/maps?q=${coords.lat},${coords.lng}`
        : (hasValidLocation
            ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(profile.location as string)}`
            : undefined);

    // Filter measurements based on selected tab (Day = 3 items, Week = 7 items, Month = all items up to 30)
    const displayCount = timeFilter === "Day" ? 3 : timeFilter === "Week" ? 7 : 30;
    const filteredMeasurements = measurements.slice(0, displayCount);

    if (loading) {
        return (
            <Layout title="Users Managements">
                <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "50vh", gap: "10px", color: "#0c2b75", fontSize: "18px", fontWeight: "bold" }}>
                    <i className='bx bx-loader-alt bx-spin' style={{ fontSize: "28px" }}></i>
                    Loading client profile...
                </div>
            </Layout>
        );
    }

    if (!client) {
        return (
            <Layout title="Users Managements">
                <div style={{ padding: "40px", textAlign: "center", color: "#94a3b8", fontSize: "18px" }}>
                    Client not found in the database.
                </div>
            </Layout>
        );
    }

    return (
        <Layout title="Users Managements">
            <div className="profile-page-wrapper">

                {/* Back Button */}
                <button className="back-btn-outlined" onClick={() => navigate("/users")}>
                    <i className="bx bx-arrow-back" /> Back to Users
                </button>

                {/* Header Card */}
                <div className="profile-header-card-v2">
                    {client.photoURL ? (
                        <img
                            src={client.photoURL}
                            alt={client.fullName}
                            className="avatar-red"
                            onError={(e) => {
                                (e.target as HTMLElement).style.display = "none";
                            }}
                        />
                    ) : (
                        <div className="avatar-red">{client.initials}</div>
                    )}

                    <div className="header-info-v2">
                        <h2 className="name">{client.fullName}</h2>
                        <div className="header-meta-v2">
                            <span><i className="bx bx-target-lock icon-red" /> Primary Goal : {profile.primaryGoal}</span>

                            {/* Interactive Clickable Location Button */}
                            <button
                                type="button"
                                className="header-location-badge-btn"
                                onClick={() => {
                                    if (hasValidLocation && googleMapsUrl) {
                                        window.open(googleMapsUrl, "_blank", "noopener,noreferrer");
                                    } else {
                                        setLocationInput(profile.location && profile.location !== "Not set" ? profile.location : "");
                                        setIsLocationModalOpen(true);
                                    }
                                }}
                                title={hasValidLocation ? "Click to open in Google Maps" : "Click to set client location"}
                            >
                                <i className="bx bx-map icon-green" />
                                <span>Location : {profile.location}</span>
                                <i
                                    className="bx bx-edit-alt header-location-edit-icon"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        setLocationInput(profile.location && profile.location !== "Not set" ? profile.location : "");
                                        setIsLocationModalOpen(true);
                                    }}
                                    title="Edit / Set Location"
                                />
                            </button>

                            <span><i className="bx bx-user icon-grey" /> Trainer : {subscription?.trainerName}</span>
                        </div>
                    </div>

                    {subscription && (
                        <div className={`status-badge ${subscription.status === "Active" ? "active" : "inactive"}`}>
                            {subscription.status}
                        </div>
                    )}
                </div>

                {/* Location Update Modal */}
                {isLocationModalOpen && (
                    <div className="location-modal-overlay" onClick={() => setIsLocationModalOpen(false)}>
                        <div className="location-modal-card" onClick={(e) => e.stopPropagation()}>
                            <div className="location-modal-header">
                                <h3 className="location-modal-title">Client Location &amp; Maps</h3>
                                <button className="location-modal-close" onClick={() => setIsLocationModalOpen(false)}>
                                    &times;
                                </button>
                            </div>
                            <p style={{ fontSize: "13.5px", color: "#64748b", margin: "0 0 16px 0", lineHeight: "1.5" }}>
                                Enter the client's city, address, or GPS coordinates to view on Google Maps.
                            </p>
                            <input
                                type="text"
                                className="location-modal-input"
                                placeholder="e.g. Kochi, Kerala or 9.9816, 76.2999"
                                value={locationInput}
                                onChange={(e) => setLocationInput(e.target.value)}
                                autoFocus
                            />
                            <div style={{ display: "flex", gap: "10px", alignItems: "center", marginBottom: "16px" }}>
                                <button type="button" className="location-modal-btn-gps" onClick={handleDetectGps}>
                                    <i className="bx bx-current-location" /> Use Device GPS
                                </button>
                                {googleMapsUrl && hasValidLocation && (
                                    <a
                                        href={googleMapsUrl}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        style={{ fontSize: "12.5px", color: "#0284c7", fontWeight: 600, textDecoration: "underline" }}
                                    >
                                        Open on Google Maps &rarr;
                                    </a>
                                )}
                            </div>
                            <div className="location-modal-actions">
                                <button
                                    type="button"
                                    className="location-modal-btn-cancel"
                                    onClick={() => setIsLocationModalOpen(false)}
                                >
                                    Cancel
                                </button>
                                <button
                                    type="button"
                                    className="location-modal-btn-save"
                                    onClick={() => handleSaveLocation()}
                                    disabled={savingLocation}
                                >
                                    {savingLocation ? "Saving..." : "Save Location"}
                                </button>
                            </div>
                        </div>
                    </div>
                )}

                {/* Main Content Grid */}
                <div className="profile-grid-3">

                    {/* Row 1, Col 1 & 2: Measurements */}
                    <div className="base-card span-2">
                        <div className="card-top-row">
                            <div>
                                <h3 className="card-title-main">Measurement History</h3>
                                <p className="card-subtitle">Track your progress over time</p>
                            </div>
                            <span className="download-link" onClick={() => alert("Downloading Report...")}>Download Report</span>
                        </div>

                        {/* Interactive Tabs */}
                        <div className="tabs-pill-container">
                            <button
                                className={timeFilter === "Day" ? "active" : ""}
                                onClick={() => setTimeFilter("Day")}
                            >Day</button>
                            <button
                                className={timeFilter === "Week" ? "active" : ""}
                                onClick={() => setTimeFilter("Week")}
                            >Week</button>
                            <button
                                className={timeFilter === "Month" ? "active" : ""}
                                onClick={() => setTimeFilter("Month")}
                            >Month</button>
                        </div>

                        {filteredMeasurements.length === 0 ? (
                            <div style={{ color: '#94a3b8', fontSize: '14px' }}>No progress logs recorded for this timeframe.</div>
                        ) : (
                            <table className="data-table-v2">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Weight (Kg)</th>
                                        <th>Sleep(Hrs)</th>
                                        <th>Hydration(L)</th>
                                        <th>Steps</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filteredMeasurements.map(m => (
                                        <tr key={m.id}>
                                            <td>{formatFullDate(m.date)}</td>
                                            <td>{m.weightKg}</td>
                                            <td>{m.sleepHours}</td>
                                            <td>{m.waterL}</td>
                                            <td>{m.steps}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        )}
                    </div>

                    {/* Row 1, Col 3: Diet Plan */}
                    <div className="base-card span-1">
                        <div className="card-top-row">
                            <h3 className="card-title-main" style={{ margin: 0 }}>Active Diet Plan</h3>
                            <span className="diet-week-badge">Week {dietPlan?.weekNumber || 1}</span>
                        </div>

                        <h2 className="diet-plan-title">
                            {dietPlan?.templateName || "No Plan Assigned"}
                        </h2>

                        {dietPlan ? (
                            <>
                                <div className="diet-features">
                                    <div className="diet-feature">
                                        <i className="bx bx-check-circle" />
                                        <span><strong>Target :</strong> under {dietPlan.netCarbsG || '-'}g carbs</span>
                                    </div>
                                    <div className="diet-feature">
                                        <i className="bx bx-check-circle" />
                                        <span><strong>Fast Window :</strong> {dietPlan.fastingWindow || '-'}</span>
                                    </div>
                                </div>
                                <button className="view-menu-btn" onClick={() => navigate(`/diet-plans/view/${dietPlan.templateId}`)}>
                                    View Full Menu
                                </button>
                            </>
                        ) : (
                            <p style={{ color: '#94a3b8', fontSize: '14px' }}>Assign a plan to track diet features.</p>
                        )}
                    </div>

                    {/* Row 2, Col 1: Physical Conditions */}
                    <div className="base-card navy-bg span-1">
                        <div className="navy-title-row">
                            <i className="bx bxs-briefcase" />
                            <h3>Physical Conditions Profile</h3>
                        </div>

                        <div className="navy-section">
                            <div className="navy-sec-title"><span className="red-dot" /> Procedures &amp; Surgeries</div>
                            {procedures.length === 0 ? (
                                <p style={{ fontSize: '12px', color: 'rgba(255,255,255,0.6)', margin: 0 }}>None recorded.</p>
                            ) : (
                                procedures.map(p => (
                                    <div key={p.id} className="navy-inner-card">
                                        <div className="navy-inner-title">{p.procedureName}</div>
                                        <div className="navy-inner-sub">
                                            {p.procedureDate ? `Date: ${p.procedureDate}` : ""}
                                            {p.procedureDate && p.recoveryStatus ? " • " : ""}
                                            {p.recoveryStatus ? `Recovery: ${p.recoveryStatus}` : ""}
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        <div className="navy-section">
                            <div className="navy-sec-title"><span className="red-dot" /> Medications (Physical)</div>
                            {medications.length === 0 ? (
                                <p style={{ fontSize: '12px', color: 'rgba(255,255,255,0.6)', margin: 0 }}>None recorded.</p>
                            ) : (
                                <div className="navy-pill-list">
                                    {medications.map(m => <span key={m.id} className="navy-pill">{m.name}</span>)}
                                </div>
                            )}
                        </div>

                        <div className="navy-section">
                            <div className="navy-sec-title"><span className="red-dot" /> Health Conditions</div>
                            {conditions.length === 0 ? (
                                <p style={{ fontSize: '12px', color: 'rgba(255,255,255,0.6)', margin: 0 }}>None recorded.</p>
                            ) : (
                                <div className="navy-pill-list">
                                    {conditions.map(c => <span key={c.id} className="navy-pill">{c.conditionName}</span>)}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Row 2, Col 2: Session History */}
                    <div className="base-card light-grey span-1">
                        <div className="sess-header">
                            <h3><i className="bx bx-history" /> Session History</h3>
                            <span className="sess-total">{totalSessions} Total</span>
                        </div>

                        <div>
                            {sessions.length === 0 ? (
                                <div style={{ color: '#94a3b8', fontSize: '14px', padding: '20px 0' }}>No sessions booked yet.</div>
                            ) : (
                                sessions.map(s => (
                                    <div key={s.id} className="sess-row">
                                        <div>
                                            <div className="sess-title">{s.serviceType}</div>
                                            <div className="sess-trainer"><i className="bx bx-user" /> Trainer : {s.trainerName}</div>
                                        </div>
                                        <div className="sess-date">{formatShortDate(s.scheduledDate)}</div>
                                    </div>
                                ))
                            )}
                        </div>

                        {totalSessions > 0 && (
                            <button className="view-all-link" onClick={() => navigate(`/users/${id}/sessions`)}>
                                View all sessions
                            </button>
                        )}
                    </div>

                    {/* Row 2, Col 3: Actions Checkout */}
                    <div className="span-1">

                        {/* UPDATE: Ensure route matches your App.tsx exact route */}
                        <button className="btn-red-solid" onClick={() => navigate(`/users/${id}/diet-plan`)}>
                            Assign New Plan
                        </button>

                        <div className="base-card light-grey" style={{ padding: '24px 20px' }}>
                            <h3 className="card-title-main" style={{ fontSize: '15px' }}>Action Checkout</h3>

                            <div className="checkout-list">
                                {actionItems.length === 0 ? (
                                    <div style={{ fontSize: '13px', color: '#94a3b8', margin: '10px 0' }}>No action items assigned.</div>
                                ) : (
                                    actionItems.map(item => (
                                        <label key={item.id} className={`chk-item ${item.completed ? 'strike' : ''}`}>
                                            <input
                                                type="checkbox"
                                                checked={item.completed}
                                                onChange={() => toggleActionItem(item.id, item.completed)}
                                            />
                                            <span>{item.title} {item.dueDate && `(Due ${item.dueDate})`}</span>
                                        </label>
                                    ))
                                )}
                            </div>

                            {/* Add New Checkout Task Form */}
                            <form onSubmit={handleAddTask} className="add-task-form">
                                <input
                                    type="text"
                                    placeholder="Add new action item..."
                                    value={newTaskTitle}
                                    onChange={(e) => setNewTaskTitle(e.target.value)}
                                    disabled={addingTask}
                                />
                                <button type="submit" disabled={addingTask || !newTaskTitle.trim()}>
                                    {addingTask ? <i className="bx bx-loader-alt bx-spin"></i> : <i className="bx bx-plus"></i>}
                                </button>
                            </form>
                        </div>
                    </div>

                </div>
            </div>
        </Layout>
    );
}