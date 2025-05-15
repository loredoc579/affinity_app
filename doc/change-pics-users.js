// import-profiles.js
// Scarica ritratti ad alta risoluzione (1024×1024) divisi per gender da Unsplash
// con retry su errori e fallback a Randomuser API, poi carica su Firebase Storage (CORS)
// Genera per ogni utente un array di 9 photoUrls pubbliche

const admin = require('firebase-admin');
const fetch = require('node-fetch');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'affinity-9e25e.firebasestorage.app'
});

const firestore = admin.firestore();
const bucket = admin.storage().bucket();

// Pausa per backoff
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Retry fetch fino a maxRetries con backoff esponenziale
async function fetchBufferWithRetry(url, maxRetries = 5) {
  let attempt = 0;
  let wait = 500;
  while (attempt < maxRetries) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.buffer();
    } catch (err) {
      attempt++;
      if (attempt >= maxRetries) throw err;
      await sleep(wait);
      wait *= 2;
    }
  }
}

// Genera seed numerico da stringa
function simpleHash(str) {
  let hash = 0;
  for (const ch of str) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  return hash;
}

// Scarica immagine da Unsplash portrait o fallback Randomuser
async function downloadPortrait(gender, seed) {
  const query = gender === 'female' ? 'woman,portrait' : 'man,portrait';
  const unsplashUrl = `https://source.unsplash.com/random/1024x1024/?${query}&sig=${seed}`;
  try {
    return await fetchBufferWithRetry(unsplashUrl);
  } catch {
    // fallback a Randomuser large
    const rndSeed = seed % 100;
    const category = gender === 'female' ? 'women' : 'men';
    const url = `https://randomuser.me/api/portraits/${category}/${rndSeed}.jpg`;
    return await fetchBufferWithRetry(url);
  }
}

// Scarica e carica un singolo avatar, ritorna URL pubblico
async function fetchAndUploadAvatar(gender, uid, idx) {
  const seed = simpleHash(`${uid}-${gender}-${idx}`);
  const buffer = await downloadPortrait(gender, seed);
  const filePath = `avatars/${gender}/${uid}-${idx}.jpg`;
  const file = bucket.file(filePath);
  await file.save(buffer, { resumable: false, metadata: { contentType: 'image/jpeg' } });
  await file.makePublic();
  return file.publicUrl();
}

// Genera 9 avatar per utente
async function generatePhotoUrls(gender, uid) {
  const avatars = [];
  for (let i = 0; i < 9; i++) {
    try {
      avatars.push(await fetchAndUploadAvatar(gender, uid, i));
    } catch (err) {
      console.warn(`⚠️ [${uid}] idx=${i} skip: ${err.message}`);
    }
  }
  if (avatars.length < 9) throw new Error(`Solo ${avatars.length}/9 avatar per ${uid}`);
  return avatars;
}

async function main() {
  console.log('🚀 Inizio import avatar high-res (Unsplash+fallback)...');
  let pageToken;
  do {
    const { users, pageToken: next } = await admin.auth().listUsers(1000, pageToken);
    pageToken = next;
    for (const { uid } of users) {
      const doc = await firestore.collection('users').doc(uid).get();
      const gender = doc.exists && doc.data().gender === 'female' ? 'female' : 'male';
      try {
        const photoUrls = await generatePhotoUrls(gender, uid);
        await firestore.collection('users').doc(uid).set({ photoUrls }, { merge: true });
        console.log(`✔ [${uid}] caricati 9 avatar (${gender})`);
      } catch (e) {
        console.error(`❌ [${uid}] errore avatar: ${e.message}`);
      }
    }
  } while (pageToken);
  console.log('🎉 Operazione completata.');
}

main().catch(err => { console.error('Fatal error:', err); process.exit(1); });
