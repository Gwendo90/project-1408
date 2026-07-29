// ── Supabase-Zugangsdaten ────────────────────────────────────────────
// Zu finden im Supabase-Dashboard unter:  Project Settings → API
//
// Der publishable key ist absichtlich öffentlich – er darf im Browser
// stehen und ins Repo committet werden. Er steckt ohnehin sichtbar im
// ausgelieferten JavaScript. Geschützt wird die Datenbank nicht durch
// Geheimhaltung des Keys, sondern durch die RLS-Regeln im Schema.
//
// Was NIE hierher darf: der service_role- bzw. secret-Key. Der hebelt
// RLS komplett aus. Für dieses Spiel wird er nirgends gebraucht.

window.SUPABASE_URL = 'https://smdpjadtbrgjufuxwtpg.supabase.co';
window.SUPABASE_KEY = 'sb_publishable_Be6H_Tncld2TlUOC27HRCg_BUwkXowz';

// Wie viele Karten braucht man zum Sieg?
window.DUELL_ZIEL = 10;
