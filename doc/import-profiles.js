// import-profiles.js
// Script per Firestore: associa ad ogni utente Auth un profilo completo in Firestore

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const firestore = admin.firestore();

const profiles = [
  {
    email: 'lorenzo.rossi@example.com',
    name: 'Lorenzo Rossi',
    gender: 'male',
    age: '25',
    hobbies: 'calcio, fotografia, viaggi',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=lorenzo.rossi@example.com&size=512',
    lastCity: 'Milano',
    lastLat: 45.4642035,
    lastLong: 9.189982,
    lastLogin: new Date('2025-05-10T02:30:01+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:41:20+02:00')
  },
  {
    email: 'martina.bianchi@example.com',
    name: 'Martina Bianchi',
    gender: 'female',
    age: '28',
    hobbies: 'yoga, lettura, cucina',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=martina.bianchi@example.com&size=512',
    lastCity: 'Roma',
    lastLat: 41.9027835,
    lastLong: 12.4963655,
    lastLogin: new Date('2025-05-10T02:35:12+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:45:30+02:00')
  },
  {
    email: 'alessandro.verdi@example.com',
    name: 'Alessandro Verdi',
    gender: 'male',
    age: '32',
    hobbies: 'ciclismo, cinema, tecnologia',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=alessandro.verdi@example.com&size=512',
    lastCity: 'Napoli',
    lastLat: 40.8517746,
    lastLong: 14.2681244,
    lastLogin: new Date('2025-05-10T02:20:45+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:50:10+02:00')
  },
  {
    email: 'giulia.neri@example.com',
    name: 'Giulia Neri',
    gender: 'female',
    age: '24',
    hobbies: 'pittura, danza, musica',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=giulia.neri@example.com&size=512',
    lastCity: 'Torino',
    lastLat: 45.070312,
    lastLong: 7.6868565,
    lastLogin: new Date('2025-05-10T02:10:05+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:42:55+02:00')
  },
  {
    email: 'marco.russo@example.com',
    name: 'Marco Russo',
    gender: 'male',
    age: '29',
    hobbies: 'lettura, escursionismo, basket',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=marco.russo@example.com&size=512',
    lastCity: 'Firenze',
    lastLat: 43.7695604,
    lastLong: 11.2558136,
    lastLogin: new Date('2025-05-10T02:05:30+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:44:15+02:00')
  },
  {
    email: 'elena.conti@example.com',
    name: 'Elena Conti',
    gender: 'female',
    age: '31',
    hobbies: 'fotografia, viaggi, cucina',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=elena.conti@example.com&size=512',
    lastCity: 'Venezia',
    lastLat: 45.4408474,
    lastLong: 12.3155151,
    lastLogin: new Date('2025-05-10T02:25:20+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:43:40+02:00')
  },
  {
    email: 'davide.greco@example.com',
    name: 'Davide Greco',
    gender: 'male',
    age: '26',
    hobbies: 'videogiochi, musica, pallavolo',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=davide.greco@example.com&size=512',
    lastCity: 'Bologna',
    lastLat: 44.494887,
    lastLong: 11.3426163,
    lastLogin: new Date('2025-05-10T02:15:00+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:46:05+02:00')
  },
  {
    email: 'sara.ferrari@example.com',
    name: 'Sara Ferrari',
    gender: 'female',
    age: '27',
    hobbies: 'yoga, fotografia, cinema',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=sara.ferrari@example.com&size=512',
    lastCity: 'Palermo',
    lastLat: 38.1156883,
    lastLong: 13.3612678,
    lastLogin: new Date('2025-05-10T02:12:10+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:41:55+02:00')
  },
  {
    email: 'federico.martini@example.com',
    name: 'Federico Martini',
    gender: 'male',
    age: '34',
    hobbies: 'ciclismo, lettura, scrittura',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=federico.martini@example.com&size=512',
    lastCity: 'Genova',
    lastLat: 44.4056457,
    lastLong: 8.946256,
    lastLogin: new Date('2025-05-10T02:18:35+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:42:10+02:00')
  },
  {
    email: 'chiara.romano@example.com',
    name: 'Chiara Romano',
    gender: 'female',
    age: '30',
    hobbies: 'giardinaggio, pittura, viaggi',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=chiara.romano@example.com&size=512',
    lastCity: 'Verona',
    lastLat: 45.4383842,
    lastLong: 10.9916215,
    lastLogin: new Date('2025-05-10T02:22:50+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:47:30+02:00')
  },
  {
    email: 'matteo.galli@example.com',
    name: 'Matteo Galli',
    gender: 'male',
    age: '23',
    hobbies: 'skateboard, musica, fotografia',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=matteo.galli@example.com&size=512',
    lastCity: 'Bari',
    lastLat: 41.1171434,
    lastLong: 16.8718715,
    lastLogin: new Date('2025-05-10T02:08:45+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:48:20+02:00')
  },
  {
    email: 'valentina.costa@example.com',
    name: 'Valentina Costa',
    gender: 'female',
    age: '22',
    hobbies: 'disegno, lettura, yoga',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=valentina.costa@example.com&size=512',
    lastCity: 'Catania',
    lastLat: 37.5078772,
    lastLong: 15.0830303,
    lastLogin: new Date('2025-05-10T02:28:15+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:49:10+02:00')
  },
  {
    email: 'luca.deluca@example.com',
    name: 'Luca De Luca',
    gender: 'male',
    age: '35',
    hobbies: 'cucina, viaggi, pallanuoto',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=luca.deluca@example.com&size=512',
    lastCity: 'Messina',
    lastLat: 38.1938138,
    lastLong: 15.5540152,
    lastLogin: new Date('2025-05-10T02:13:25+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:41:10+02:00')
  },
  {
    email: 'francesca.sala@example.com',
    name: 'Francesca Sala',
    gender: 'female',
    age: '33',
    hobbies: 'teatro, musica, cinema',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=francesca.sala@example.com&size=512',
    lastCity: 'Padova',
    lastLat: 45.4064341,
    lastLong: 11.8767611,
    lastLogin: new Date('2025-05-10T02:16:55+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:43:00+02:00')
  },
  {
    email: 'simone.ferrara@example.com',
    name: 'Simone Ferrara',
    gender: 'male',
    age: '28',
    hobbies: 'escursionismo, fotografia, scrittura',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=simone.ferrara@example.com&size=512',
    lastCity: 'Trieste',
    lastLat: 45.6495269,
    lastLong: 13.7768189,
    lastLogin: new Date('2025-05-10T02:21:05+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:44:45+02:00')
  },
  {
    email: 'giovanna.lombardi@example.com',
    name: 'Giovanna Lombardi',
    gender: 'female',
    age: '29',
    hobbies: 'pittura, giardinaggio, yoga',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=giovanna.lombardi@example.com&size=512',
    lastCity: 'Brescia',
    lastLat: 45.5416209,
    lastLong: 10.2118001,
    lastLogin: new Date('2025-05-10T02:24:40+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:43:50+02:00')
  },
  {
    email: 'nicola.bruno@example.com',
    name: 'Nicola Bruno',
    gender: 'male',
    age: '36',
    hobbies: 'basket, musica, viaggi',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=nicola.bruno@example.com&size=512',
    lastCity: 'Taranto',
    lastLat: 40.4697504,
    lastLong: 17.2470461,
    lastLogin: new Date('2025-05-10T02:11:30+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:45:00+02:00')
  },
  {
    email: 'arianna.villa@example.com',
    name: 'Arianna Villa',
    gender: 'female',
    age: '24',
    hobbies: 'fotografia, danza, cinema',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=arianna.villa@example.com&size=512',
    lastCity: 'Prato',
    lastLat: 43.8777168,
    lastLong: 11.1020355,
    lastLogin: new Date('2025-05-10T02:09:20+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:45:35+02:00')
  },
  {
    email: 'emanuele.costa@example.com',
    name: 'Emanuele Costa',
    gender: 'male',
    age: '31',
    hobbies: 'videogiochi, scrittura, ciclismo',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=emanuele.costa@example.com&size=512',
    lastCity: 'Reggio Calabria',
    lastLat: 38.110493,
    lastLong: 15.6612635,
    lastLogin: new Date('2025-05-10T02:14:15+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:46:25+02:00')
  },
  {
    email: 'silvia.monti@example.com',
    name: 'Silvia Monti',
    gender: 'female',
    age: '27',
    hobbies: 'cucina, yoga, lettura',
    photoUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=silvia.monti@example.com&size=512',
    lastCity: 'Modena',
    lastLat: 44.6471288,
    lastLong: 10.9252264,
    lastLogin: new Date('2025-05-10T02:17:50+02:00'),
    lastLocationUpdate: new Date('2025-05-10T02:44:00+02:00')
  }
];





async function main() {
  console.log('🚀 Inizio import dei profili in Firestore');
  let pageToken;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    for (const userRecord of result.users) {
      const profile = profiles.find(p => p.email === userRecord.email);
      if (!profile) {
        console.warn(`⚠️ Profile non trovato per utente ${userRecord.email}`);
        continue;
      }
      const data = {
        name: profile.name,
        email: profile.email,
        gender: profile.gender,
        age: profile.age,
        hobbies: profile.hobbies,
        photoUrl: profile.photoUrl,
        lastCity: profile.lastCity,
        lastLat: profile.lastLat,
        lastLong: profile.lastLong,
        lastLogin: admin.firestore.Timestamp.fromDate(profile.lastLogin),
        lastLocationUpdate: admin.firestore.Timestamp.fromDate(profile.lastLocationUpdate)
      };
      await firestore.collection('users').doc(userRecord.uid).set(data, { merge: true });
      console.log(`✔ Profilo Firestore creato per ${userRecord.email} (UID: ${userRecord.uid})`);
    }
    pageToken = result.pageToken;
  } while (pageToken);
  console.log('🎉 Import profili completato.');
}

main().catch(err => {
  console.error('❌ Errore durante l import:', err);
  process.exit(1);
});
