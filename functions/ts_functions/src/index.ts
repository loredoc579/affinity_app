// functions/ts_functions/src/index.ts

// Importa la callable function
import {getProfiles} from "./getProfiles";
// Importa il trigger Firestore
import {onChatCreated} from "./onChatCreated";
import {onMessageCreated} from "./onMessageCreated";

// Aggiungi qui altri import di trigger o callable che hai definito

// Esporta tutto per il deploy
export {
  getProfiles,
  onChatCreated,
  onMessageCreated,
};
