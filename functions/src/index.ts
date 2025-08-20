import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * 📢 NOTIFICATION À TOUS : message du chef
 * Déclenchée à la création d’un doc dans chefMessages/{messageId}.
 * Envoie une notif à tous via le topic all_users.
 */
export const notifyAllUsersOnChefMessage = functions.firestore
  .document("chefMessages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const title = "Message du chef";
    const body = data?.message ?? "Nouveau message disponible.";

    const payload = {
      notification: { title, body },
    };

    try {
      await admin.messaging().sendToTopic("all_users", payload);
      console.log("✅ Notification envoyée à tous (topic all_users)");
    } catch (error) {
      console.error("❌ Erreur notification générale :", error);
    }
  });

/**
 * 👥 NOTIFICATION À UN GROUPE
 * Déclenchée à la création d’un doc dans groupMessages/{messageId}.
 * Chaque message contient { group: "OPS"|"PNT"|"TECH", message: "..."}.
 */
export const notifyGroupOnChefMessage = functions.firestore
  .document("groupMessages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const group = data?.group;
    const message = data?.message ?? "Nouveau message disponible.";

    if (!group) {
      console.log("⚠️ Aucun groupe indiqué dans le message.");
      return;
    }

    const title = `Message ${group}`;
    const body = message;

    const payload = {
      notification: { title, body },
    };

    try {
      await admin.messaging().sendToTopic(`group_${group}`, payload);
      console.log(`✅ Notification envoyée au groupe ${group}`);
    } catch (error) {
      console.error(`❌ Erreur notification groupe ${group} :`, error);
    }
  });

/**
 * 🚁 ✈️ NOTIFICATIONS MISSION : avion (ATR72) ou hélico (AH175/EC225)
 * Déclenchée à chaque ajout, modif ou suppression dans missions/{missionId}.
 * Notifie l’équipage + CDT (+ mécanos avion).
 */
export const notifyMissionParticipants = functions.firestore
  .document("missions/{missionId}")
  .onWrite(async (change, context) => {
    const newData = change.after.exists ? change.after.data() : null;
    const oldData = change.before.exists ? change.before.data() : null;
    if (!newData && !oldData) return;

    const isDeleted = !newData;
    const mission = (newData ?? oldData) as FirebaseFirestore.DocumentData;
    const { vecteur, pilote1, pilote2, pilote3, date } = mission;

    // ✅ Type appareil
    const isAvion = vecteur === "ATR72";
    const isHelico = ["AH175", "EC225"].includes(vecteur);

    // ✅ Équipage
    const trigrammes: string[] = [pilote1, pilote2, isHelico ? pilote3 : null]
      .filter((val, idx, arr) => val && arr.indexOf(val) === idx);

    const tokens: string[] = [];

    async function addTokensFromQuery(query: FirebaseFirestore.Query<FirebaseFirestore.DocumentData>) {
      const snapshot = await query.get();
      snapshot.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken && !tokens.includes(data.fcmToken)) {
          tokens.push(data.fcmToken);
        }
      });
    }

    // ✅ Ajouter équipage
    for (const trigramme of trigrammes) {
      await addTokensFromQuery(
        admin.firestore().collection("users").where("trigramme", "==", trigramme)
      );
    }

    // ✅ Ajouter CDT
    await addTokensFromQuery(
      admin.firestore().collection("users").where("fonction", "==", "CDT")
    );

    // ✅ Ajouter mécanos avion
    if (isAvion) {
      await addTokensFromQuery(
        admin.firestore().collection("users")
          .where("role", "==", "mecano")
          .where("group", "==", "avion")
      );
    }

    if (tokens.length === 0) {
      console.log("⚠️ Aucun token trouvé pour cette mission.");
      return;
    }

    // ✅ Action
    const action = isDeleted
      ? "supprimée"
      : change.before.exists
        ? "modifiée"
        : "créée";

    // ✅ Date format FR (jour + mois, sans année)
    const dateObj = date?.toDate ? date.toDate() : new Date(date);
    const dateLisible = new Intl.DateTimeFormat("fr-FR", {
      day: "numeric",
      month: "long",
    }).format(dateObj);

    // ✅ Titre
    const title = isAvion ? "Mission ATR72" : `Mission ${vecteur}`;

    // ✅ Payload
    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body: `Mission du ${dateLisible} – ${action}.`,
      },
      data: {
        missionId: context.params.missionId,
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(
        `✅ Notification ${title} envoyée à ${response.successCount} destinataires (échecs: ${response.failureCount}).`
      );
    } catch (error) {
      console.error("❌ Erreur d’envoi notification mission :", error);
    }
  });
