// import-profiles.js
// Scarica da randomuser.me 9 ritratti high-res (~600×600) divisi per gender
// e carica su Firebase Storage per abilitare CORS
// Genera per ogni utente un array di 9 photoUrls pubbliche reali, seedati per coerenza

const admin = require('firebase-admin');
const fetch = require('node-fetch');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'affinity-9e25e.firebasestorage.app'
});

const firestore = admin.firestore();
const bucket = admin.storage().bucket();

/**
 * Semplice hash per generare un numero a partire da stringa
 */
function simpleHash(str) {
  let hash = 0;
  for (const ch of str) {
    hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  }
  return hash;
}

/**
 * Download dell'immagine da URL e restituisce buffer
 */
async function downloadBuffer(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Fetch fallita: ${res.status} ${url}`);
  return res.buffer();
}

/**
 * Scarica e carica un singolo avatar seedato tramite Randomuser API
 */
async function fetchAndUploadAvatar(gender, uid, idx) {
  const seedValue = simpleHash(`${uid}-${gender}-${idx}`) % 100000;
  const apiUrl = `https://randomuser.me/api/?seed=${seedValue}&gender=${gender}`;
  const apiRes = await fetch(apiUrl);
  if (!apiRes.ok) throw new Error(`API fetch fallita: ${apiRes.status}`);
  const json = await apiRes.json();
  const pic = json?.results?.[0]?.picture;
  if (!pic?.large) throw new Error(`Missing picture.large for seed ${seedValue}`);
  const imgUrl = pic.large;  // ~600×600

  const buffer = await downloadBuffer(imgUrl);
  const filePath = `avatars/${gender}/${uid}-${idx}.jpg`;
  const file = bucket.file(filePath);
  await file.save(buffer, { resumable: false, metadata: { contentType: 'image/jpeg' } });
  await file.makePublic();
  return file.publicUrl();
}

/**
 * Genera e carica 9 avatar per ogni utente, seedati uno a uno
 */
async function generatePhotoUrls(gender, uid, count = 9) {
  const urls = [];
  let idx = 0;
  while (urls.length < count && idx < count * 5) {
    try {
      const url = await fetchAndUploadAvatar(gender, uid, idx);
      urls.push(url);
    } catch (err) {
      console.warn(`⚠️ [${uid}] idx=${idx} skip: ${err.message}`);
    }
    idx++;
  }
  if (urls.length < count) {
    throw new Error(`Non ho potuto generare ${count} avatar per ${uid}, ottenuti ${urls.length}`);
  }
  return urls;
}

async function main() {
  console.log('🚀 Inizio import avatar high-res per tutti gli utenti...');
  let pageToken;

  do {
    const { users, pageToken: nextPage } = await admin.auth().listUsers(1000, pageToken);
    pageToken = nextPage;

    for (const { uid } of users) {
      const docRef = firestore.collection('users').doc(uid);
      const snap = await docRef.get();
      const data = snap.exists ? snap.data() : {};
      const gender = data.gender === 'female' ? 'female' : 'male';
      try {
        const photoUrls = await generatePhotoUrls(gender, uid);
        await docRef.set({ photoUrls }, { merge: true });
        console.log(`✔ [${uid}] caricati 9 avatar high-res (${gender})`);
      } catch (e) {
        console.error(`❌ [${uid}] errore avatar: ${e.message}`);
      }
    }
  } while (pageToken);

  console.log('🎉 Import completato per tutti gli utenti.');
}

main().catch(err => { console.error('Fatal error:', err); process.exit(1); });
