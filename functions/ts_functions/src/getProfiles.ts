import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {Timestamp, FieldPath} from "firebase-admin/firestore";

if (!admin.apps.length) {
  admin.initializeApp();
}

const DEFAULT_PAGE_SIZE = 30;
const db = admin.firestore();

/**
 * Haversine formula: distanza in km tra due coordinate
 * @param {number} lat1 - Latitude of the first point
 * @param {number} lng1 - Longitude of the first point
 * @param {number} lat2 - Latitude of the second point
 * @param {number} lng2 - Longitude of the second point
 * @return {number} The distance in kilometers between the two points
 */
function haversineDistance(
  lat1: number, lng1: number,
  lat2: number, lng2: number,
): number {
  const toRad = (v: number) => (v * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat/2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng/2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

interface UIFilters {
  gender?: "male" | "female" | "other" | "all";
  minAge?: number | string;
  maxAge?: number | string;
  maxDistance?: number | string;
}

interface Location {
  position?: {
    latitude: number;
    longitude: number;
  };
}

interface Req {
  uid: string;
  uiFilters?: UIFilters;
  cursor?: string;
  pageSize?: number;
}

interface UserDocData extends admin.firestore.DocumentData {
  name?: string;
  age?: number | string;
  gender?: string;
  bio?: string;
  photoUrls?: string[];
  hobbies?: string[];
  isVerified?: boolean;
  isPaused?: boolean;
  location?: Location;
}

interface UserProfile extends UserDocData {
  uid: string;
  matchScore: number;
}

interface IntermediateProfile {
  uid: string;
  data: UserDocData;
  matchScore: number;
  lat?: number;
  lng?: number;
}

/**
 * Carica i dati dell'utente chiamante (Posizione + Hobby)
 * @param {string} uid - The user ID of the caller
 */
async function loadCallerData(uid: string) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "User not found");
  }
  const data = snap.data();
  const geo = (data?.location as Location)?.position;
  if (!geo ||
      typeof geo.latitude !== "number" ||
      typeof geo.longitude !== "number") {
    throw new HttpsError("failed-precondition", "User location not available");
  }
  return {
    lat: geo.latitude,
    lng: geo.longitude,
    hobbies: (data?.hobbies as string[]) || [],
  };
}

/**
 * Query base su Firestore
 * @param {UIFilters} [filters] - Optional filters for the query
 * @return {admin.firestore.Query} The base Firestore query
 */
function buildBaseQuery(filters?: UIFilters): admin.firestore.Query {
  let q: admin.firestore.Query = db.collection("users");
  if (filters?.gender && filters.gender !== "all") {
    q = q.where("gender", "==", filters.gender);
  }
  return q.orderBy(FieldPath.documentId(), "asc");
}

/**
 * Filtra i profili per distanza, esclusioni, pausa e calcola il Match Score
 * @param {admin.firestore.QueryDocumentSnapshot[]} docs - The array
 * @param {Set<string>} excluded - Set of user IDs to exclude from results
 * @param {number} myLat - Latitude of the calling user
 * @param {number} myLng - Longitude of the calling user
 * @param {string[]} myHobbies - Array of hobbies of the calling user
 * @param {number | string} [rawMaxDistance] - Optional maximum distance filter
 * @return {UserProfile[]} The filtered and processed array of user profiles
 */
function processProfiles(
  docs: admin.firestore.QueryDocumentSnapshot[],
  excluded: Set<string>,
  myLat: number,
  myLng: number,
  myHobbies: string[],
  rawMaxDistance?: number | string
): UserProfile[] {
  const maxDistance = Number(rawMaxDistance);
  const hasDistanceFilter = !isNaN(maxDistance) && maxDistance > 0;

  return docs
    .map((d): IntermediateProfile => {
      const data = d.data();
      const geo = (data.location as Location)?.position;

      // Calcolo affinità
      let matchScore = 0;
      const theirHobbies = (data.hobbies as string[]) || [];
      if (myHobbies.length > 0 && theirHobbies.length > 0) {
        const common = myHobbies.filter((h) => theirHobbies.includes(h));
        matchScore = Math.round((common.length / myHobbies.length) * 100);
      }

      return {
        uid: d.id,
        data: data,
        matchScore: matchScore,
        lat: geo?.latitude,
        lng: geo?.longitude,
      };
    })
    .filter((p) => {
      // 1. Esclusioni (te stesso, match, swipe)
      if (excluded.has(p.uid)) return false;

      // 2. Controllo PAUSA (Ora TypeScript lo vede correttamente!)
      if (p.data.isPaused === true) return false;

      // 3. Distanza
      if (!hasDistanceFilter) return true;
      if (typeof p.lat !== "number" || typeof p.lng !== "number") return false;

      const dist = haversineDistance(myLat, myLng, p.lat, p.lng);
      return dist <= maxDistance;
    })
    .map((p): UserProfile => ({
      ...p.data, // Uniamo i dati originali
      uid: p.uid,
      matchScore: p.matchScore, // Aggiungiamo il punteggio calcolato
    }));
}

export const getProfiles = onCall<Req>(async (req) => {
  const {uid, uiFilters, cursor, pageSize} = req.data;
  if (req.auth && req.auth.uid !== uid) {
    throw new HttpsError("permission-denied", "Auth mismatch");
  }

  // 1) Carica dati del chiamante (posizione e hobby per affinità)
  const {
    lat: myLat,
    lng: myLng,
    hobbies: myHobbies,
  } = await loadCallerData(uid);
  // 2) Calcola ID da escludere
  const excluded = await computeExcludedIds(uid);

  // 3) Query Firestore
  let q = buildBaseQuery(uiFilters);
  if (cursor) q = q.startAfter(cursor);
  q = q.limit(150);

  const snap = await q.get();
  const rawDocs = snap.docs;

  // 4) Filtro Età
  const ageFilteredDocs = rawDocs.filter((doc) => {
    const minA = Number(uiFilters?.minAge);
    const maxA = Number(uiFilters?.maxAge);
    if (isNaN(minA) || isNaN(maxA)) return true;
    const ageNum = parseInt(String(doc.get("age")), 10);
    return !isNaN(ageNum) && ageNum >= minA && ageNum <= maxA;
  });

  // 5) Processa profili (Distanza, Pausa e Match Score)
  const validProfiles = processProfiles(
    ageFilteredDocs,
    excluded,
    myLat,
    myLng,
    myHobbies,
    uiFilters?.maxDistance
  );

  // 6) ORDINAMENTO: Mettiamo i profili con affinità più alta in cima
  validProfiles.sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));

  // 7) Paginazione
  const finalPageSize = pageSize && pageSize > 0 ? pageSize : DEFAULT_PAGE_SIZE;
  const profilesToReturn = validProfiles.slice(0, finalPageSize);

  // 8) Cursore per la pagina successiva
  let nextCursor = null;
  if (profilesToReturn.length > 0) {
    const lastUid = profilesToReturn[profilesToReturn.length - 1].uid;
    const lastIdx = rawDocs.findIndex((d) => d.id === lastUid);
    if (lastIdx !== -1 && lastIdx < rawDocs.length - 1) {
      nextCursor = rawDocs[lastIdx].id;
    }
  }

  return {profiles: profilesToReturn, nextCursor};
});

/**
 * Computes the set of user IDs to exclude from profile results.
 * @param {string} me - The user ID of the caller.
 * @return {Promise<Set<string>>} A set of excluded user IDs.
 */
async function computeExcludedIds(me: string): Promise<Set<string>> {
  const now = Timestamp.now().toDate();
  const ts = Timestamp.fromDate(
    new Date(now.getFullYear(), now.getMonth(), now.getDate())
  );

  const excluded = new Set<string>([me]);

  // Escludi Chat (Match o cancellate)
  const chatSnap = await db.collection("chats")
    .where("participants", "array-contains", me)
    .get();
  for (const d of chatSnap.docs) {
    const other = (d.get("participants") as string[]).find((id) => id !== me);
    if (other) excluded.add(other);
  }

  // Escludi Swipes di oggi
  const swipeSnap = await db.collection("swipes")
    .where("from", "==", me)
    .where("timestamp", ">=", ts)
    .get();
  for (const d of swipeSnap.docs) {
    excluded.add(d.get("to") as string);
  }

  return excluded;
}
