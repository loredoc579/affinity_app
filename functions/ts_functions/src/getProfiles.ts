import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldPath} from "firebase-admin/firestore";

if (!admin.apps.length) {
  admin.initializeApp();
}

const DEFAULT_PAGE_SIZE = 30;
const db = admin.firestore();

const categoryMap: Record<string, string> = {
  // Sport & Fitness
  "Palestra": "Sport",
  "Trekking": "Sport",
  "Corsa": "Sport",
  "Yoga": "Sport",
  "Calcio": "Sport",
  "Nuoto": "Sport",
  "Arrampicata": "Sport",
  // Creatività
  "Fotografia": "Arte",
  "Pittura": "Arte",
  "Scrittura": "Arte",
  "Design": "Arte",
  "Teatro": "Arte",
  "Fai da te": "Arte",
  // Intrattenimento
  "Netflix": "Intrattenimento",
  "Cinema": "Intrattenimento",
  "Videogiochi": "Intrattenimento",
  "Anime": "Intrattenimento",
  "Giochi da Tavolo": "Intrattenimento",
  "Concerti": "Intrattenimento",
  // Food
  "Sushi": "Food",
  "Vino": "Food",
  "Cucinare": "Food",
  "Birra Artigianale": "Food",
  "Cibo di Strada": "Food",
  "Caffè": "Food",
  // Stile di Vita
  "Viaggi": "Life",
  "Cani": "Life",
  "Gatti": "Life",
  "Astrologia": "Life",
  "Sostenibilità": "Life",
  "Moda": "Life",
};

/**
 * Calculates an advanced match score based on hobbies and their categories.
 * @param {string[]} myHobbies - The hobbies of the calling user.
 * @param {string[]} theirHobbies - The hobbies of the other user.
 * @return {number} The calculated match score (0-100).
 */
function calculateAdvancedScore(
  myHobbies: string[],
  theirHobbies: string[]
): number {
  if (
    !Array.isArray(myHobbies) ||
    !Array.isArray(theirHobbies) ||
    myHobbies.length === 0 ||
    theirHobbies.length === 0
  ) {
    return 0;
  }

  let totalPoints = 0;
  const maxPossiblePoints = myHobbies.length * 10;

  myHobbies.forEach((myHobby) => {
    if (theirHobbies.includes(myHobby)) {
      totalPoints += 10; // 10 punti per hobby identico
    } else {
      const myCat = categoryMap[myHobby];
      // Controlla se l'altro ha almeno un hobby della stessa categoria
      const hasSameCategory = theirHobbies.some(
        (h) => categoryMap[h] === myCat
      );
      if (hasSameCategory) {
        totalPoints += 4; // 4 punti per stessa categoria
      }
    }
  });

  const finalScore = (totalPoints / maxPossiblePoints) * 100;
  return Math.min(Math.round(finalScore), 100); // Massimo 100%
}

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
  rankingScore?: number;
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

      // 🌟 Calcolo affinità AVANZATO e SICURO
      const rawTheirHobbies = data.hobbies;

      // Force conversion to Array to avoid "some is not a function" crash
      const safeMyHobbies: string[] = Array.isArray(myHobbies) ? myHobbies : [];
      const safeTheirHobbies: string[] = Array.isArray(rawTheirHobbies) ?
        rawTheirHobbies :
        [];

      const matchScore = calculateAdvancedScore(
        safeMyHobbies, safeTheirHobbies);

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

  // 🌟 6) ORDINAMENTO: Mix tra Popolarità (rankingScore) e Affinità (matchScore)
  validProfiles.sort((a, b) => {
    // Se un utente è nuovo e non ha ancora un ranking, gli diamo 50 (la media)
    const rankA = a.rankingScore ?? 50;
    const rankB = b.rankingScore ?? 50;

    // L'algoritmo finale: 50% importanza all'affinità,
    // 50% alla popolarità dell'utente
    const totalScoreA = (rankA * 0.5) + ((a.matchScore || 0) * 0.5);
    const totalScoreB = (rankB * 0.5) + ((b.matchScore || 0) * 0.5);

    // Chi ha il totale più alto va in cima al mazzo
    return totalScoreB - totalScoreA;
  });

  // 7) Paginazione
  const finalPageSize = pageSize && pageSize > 0 ? pageSize : DEFAULT_PAGE_SIZE;
  const profilesToReturn = validProfiles.slice(0, finalPageSize);

  // 8) Cursore per la pagina successiva
  let nextCursor = null;
  // Se abbiamo scaricato esattamente il limite massimo (150),
  // significa che molto probabilmente ci sono altre pagine nel database
  if (rawDocs.length === 150) {
    nextCursor = rawDocs[rawDocs.length - 1].id;
  }

  return {profiles: profilesToReturn, nextCursor};
});

/**
 * Computes the set of user IDs to exclude from profile results.
 * @param {string} me - The user ID of the caller.
 * @return {Promise<Set<string>>} A set of excluded user IDs.
 */
async function computeExcludedIds(me: string): Promise<Set<string>> {
  const excluded = new Set<string>([me]);

  // Escludi Chat (Match o cancellate)
  const chatSnap = await db.collection("chats")
    .where("participants", "array-contains", me)
    .get();
  for (const d of chatSnap.docs) {
    const other = (d.get("participants") as string[]).find((id) => id !== me);
    if (other) excluded.add(other);
  }

  // --- INIZIO LOGICA SCADENZA SWIPE (1 GIORNO) ---
  // Calcoliamo la data e l'ora di esattamente 24 ore fa
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const oneDayAgoTimestamp = admin.firestore.Timestamp.fromDate(oneDayAgo);

  // Peschiamo solo i voti (Ricevute) più recenti di 24 ore fa
  const recentSwipesSnap = await db.collection("users")
    .doc(me)
    .collection("swipes")
    .where("timestamp", ">", oneDayAgoTimestamp)
    .get();

  for (const doc of recentSwipesSnap.docs) {
    // Aggiungiamo l'ID dell'utente votato alla lista degli esclusi
    excluded.add(doc.id);
  }
  // --- FINE LOGICA SCADENZA SWIPE ---

  return excluded;
}
