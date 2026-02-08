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
 * @param {number} lat1 Latitudine punto 1
 * @param {number} lng1 Longitudine punto 1
 * @param {number} lat2 Latitudine punto 2
 * @param {number} lng2 Longitudine punto 2
 * @return {number} Distanza in km
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
  ageRange?: { start: number; end: number };
  maxDistance?: number;
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

/**
 * Recupera la posizione (lat,lng) dell'utente da Firestore
 * @param {string} uid ID dell'utente
 */
async function loadUserLocation(
  uid: string
): Promise<{ lat: number; lng: number }> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "User not found");
  }
  const data = snap.data();
  interface Location {
    position?: {
      latitude: number;
      longitude: number;
    };
  }
  const geo = (data?.location as Location)?.position;
  if (
    !geo ||
    typeof geo.latitude !== "number" ||
    typeof geo.longitude !== "number"
  ) {
    throw new HttpsError("failed-precondition", "User location not available");
  }
  return {lat: geo.latitude, lng: geo.longitude};
}

/**
 * Costruisce la query iniziale applicando filtri di gender e età
 * @param {UIFilters} [filters] Filtri utente
 * @return {admin.firestore.Query} Query di base su `users`
 */
function buildBaseQuery(filters?: UIFilters): admin.firestore.Query {
  console.log("🔍 buildBaseQuery con filters:", filters);

  let q: admin.firestore.Query = db.collection("users");

  // gender
  if (filters?.gender && filters.gender !== "all") {
    q = q.where("gender", "==", filters.gender);
    console.log("🧃 Filtro gender applicato:", filters.gender);
  } else {
    console.log("🧃 Nessun filtro gender (all)");
  }

  // ordinamento unico per documentId per paginazione stabile
  return q.orderBy(FieldPath.documentId(), "asc");
}

/**
 * Applica paginazione alla query
 * @param {admin.firestore.Query} q La query Firestore da paginare
 * @param {string} [cursor] Il cursore per la paginazione (document ID)
 * @param {number} [pageSize] Numero di risultati per pagina
 * @return {admin.firestore.Query} La query con la paginazione applicata
 */
function applyPagination(
  q: admin.firestore.Query,
  cursor?: string,
  pageSize?: number
): admin.firestore.Query {
  console.log("🔍 applyPagination cursor, pageSize:", cursor, pageSize);
  const size = pageSize && pageSize > 0 ? pageSize : DEFAULT_PAGE_SIZE;
  let query = q;
  if (cursor) {
    query = query.startAfter(cursor);
  }
  return query.limit(size);
}

/**
 * Filtra i documenti Firestore escludendo ID e applicando il filtro distanza
 * @param {admin.firestore.QueryDocumentSnapshot[]} docs
 *   Array di documenti Firestore da filtrare
 * @param {Set<string>} excluded Set di userId da escludere
 * @param {number} myLat Latitudine dell'utente chiamante
 * @param {number} myLng Longitudine dell'utente chiamante
 * @param {number} [maxDistance] Distanza massima in km per includere i profili
 * @return {Record<string, unknown>[]} Array di profili filtrati
 */
function filterByDistanceAndExclusions(
  docs: admin.firestore.QueryDocumentSnapshot[],
  excluded: Set<string>,
  myLat: number,
  myLng: number,
  maxDistance?: number
): Record<string, unknown>[] {
  return docs
    .map((d) => {
      const data = d.data();
      const geo = (data.location as Location)?.position;
      return {
        uid: d.id,
        data,
        lat: geo?.latitude,
        lng: geo?.longitude,
      };
    })
    .filter((p) => {
      if (excluded.has(p.uid)) return false;
      if (typeof maxDistance !== "number") return true;
      if (typeof p.lat !== "number" || typeof p.lng !== "number") return false;
      const dist = haversineDistance(myLat, myLng, p.lat, p.lng);
      return dist <= maxDistance;
    })
    .map((p) => ({
      ...p.data,
      uid: p.uid,
    }));
}

/**
 * Callable function che restituisce profili filtrati, esclusi e paginati
 */
export const getProfiles = onCall<Req>(async (req) => {
  const {uid, uiFilters, cursor, pageSize} = req.data;
  if (!req.auth) {
    console.warn("⚠️ No auth context (emulator)");
  } else if (req.auth.uid !== uid) {
    throw new HttpsError("permission-denied", "Auth mismatch");
  }
  if (!uid) {
    throw new HttpsError("invalid-argument", "Missing user ID");
  }

  console.log("📥 getProfiles per:", uid);

  // 1) posizione utente
  const {lat: myLat, lng: myLng} = await loadUserLocation(uid);
  console.log("📍 User location:", myLat, myLng);

  // 2) esclusioni
  let excluded: Set<string>;
  try {
    excluded = await computeExcludedIds(uid);
    console.log("✅ computeExcludedIds completato:", excluded.size, "IDs");
  } catch (e) {
    console.error("❌ computeExcludedIds errore:", e);
    throw new HttpsError(
      "internal",
      "Errore computeExcludedIds",
      {cause: (e as Error).message}
    );
  }

  // 3) query base + paginazione
  let q = buildBaseQuery(uiFilters);
  q = applyPagination(q, cursor, pageSize);

  // 4) esecuzione query
  let snap;
  try {
    snap = await q.get();
    console.log("📦 Utenti trovati (pre-filter):", snap.size);
  } catch (e) {
    console.error("🔥 errore q.get():", e);
    throw new HttpsError(
      "internal",
      "Errore query utenti",
      {cause: (e as Error).message}
    );
  }

  // 5a) filtro età in JS (age è stringa nel DB)
  const rawDocs = snap.docs;
  const ageFilteredDocs = rawDocs.filter((doc) => {
    if (!uiFilters?.ageRange) return true;
    const {start, end} = uiFilters.ageRange;
    const ageRaw = doc.get("age");
    const ageNum = typeof ageRaw === "number" ?
      ageRaw :
      parseInt(ageRaw as string, 10);
    return ageNum >= start && ageNum <= end;
  });
  console.log("🗂️ Documenti dopo filtro età:", ageFilteredDocs.length);

  // 5b) filtro distanza + ID esclusi
  const profiles = filterByDistanceAndExclusions(
    ageFilteredDocs,
    excluded,
    myLat,
    myLng,
    uiFilters?.maxDistance
  );
  console.log("✅ Profili finali restituiti:", profiles.length);

  // 6) cursore successivo basato sui rawDocs per stabilità
  const nextCursor =
    snap.size === (pageSize || DEFAULT_PAGE_SIZE) ?
      snap.docs[snap.docs.length - 1].id :
      null;

  return {profiles, nextCursor};
});


/**
 * Calcola l’insieme di userId da escludere (matches, canc., swipe)
 * @param {string} me UID chiamante
 */
async function computeExcludedIds(me: string): Promise<Set<string>> {
  console.log("🔎 computeExcludedIds per:", me);
  const now = Timestamp.now().toDate();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const ts = Timestamp.fromDate(startOfDay);

  const black = new Set<string>();
  const matched = new Set<string>();
  const today = new Set<string>();

  // chats
  const chatSnap = await db
    .collection("chats")
    .where("participants", "array-contains", me)
    .get();
  console.log("  🗂️ chats trovate:", chatSnap.size);
  for (const d of chatSnap.docs) {
    const parts = (d.get("participants") as string[]) || [];
    const other = parts.find((id) => id !== me);
    if (!other) continue;
    const isDel = d.get("deleted") === true;
    const delTs = (d.get("deletedDate") as Timestamp)?.toDate();
    if (isDel && delTs && delTs >= startOfDay) {
      black.add(other);
    } else {
      matched.add(other);
    }
  }

  // swipes oggi
  const swipeSnap = await db
    .collection("swipes")
    .where("from", "==", me)
    .where("timestamp", ">=", ts)
    .get();
  console.log("  🗂️ swipes today:", swipeSnap.size);
  for (const d of swipeSnap.docs) {
    today.add(d.get("to") as string);
  }

  return new Set([me, ...black, ...matched, ...today]);
}
