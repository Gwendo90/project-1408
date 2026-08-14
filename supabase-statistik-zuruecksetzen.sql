-- ═══════════════════════════════════════════════════════════════════════════
-- Statistik zurücksetzen
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Im Supabase-SQL-Editor ausführen. Über die App geht das nicht: `anon` hat auf
-- `partien` und `tipps` kein delete (siehe supabase-migration-namen.sql), und
-- das soll auch so bleiben – sonst könnte jeder Spieler die Bestenliste leeren.
--
-- WICHTIG: Der Client hebt Zeilen auf, die nicht durchkamen (`duell1408nachtrag`
-- im localStorage) und reicht sie beim nächsten Start nach. Wer nur die
-- Datenbank leert, bekommt sie also zurück. Abschnitt 4 unten sagt, was auf den
-- Geräten zu tun ist – das ist kein Beiwerk, sondern Teil des Zurücksetzens.
--
-- Reihenfolge: erst `tipps`, dann `partien`. Heute gibt es keinen Fremdschlüssel
-- zwischen beiden, aber falls einer nachkommt, ist diese Richtung die richtige.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Vorher hinsehen ─────────────────────────────────────────────────────
-- Einzeln ausführen. Löschen ist nicht rückholbar.

select 'partien' as tabelle, modus, count(*) from public.partien group by modus
union all
select 'tipps',  coalesce(art, '(alt)'), count(*) from public.tipps group by art
union all
select 'games',  coalesce(state->>'phase', '(leer)'), count(*) from public.games
  group by state->>'phase'
order by 1, 2;


-- ── 2a. Nur die Testzeilen weg ─────────────────────────────────────────────
-- Der sanfte Weg: alles mit Namen, die auf "zz-" beginnen. So hießen die Läufe
-- aus der Entwicklung. Echte Spielstände bleiben stehen.

-- delete from public.tipps   where name_key like 'zz-%';
-- delete from public.partien where name_key like 'zz-%';


-- ── 2b. Alles zurücksetzen ─────────────────────────────────────────────────
-- Der harte Weg. Die Kommentarzeichen entfernen, wenn es wirklich alles sein
-- soll.
--
-- `truncate` statt `delete`: schneller, und es setzt auch die Zähler der
-- id-Spalten zurück, sofern es Sequenzen sind. Wer `delete` nimmt, behält die
-- laufenden Nummern – für die Auswertungen macht das keinen Unterschied.

-- truncate table public.tipps, public.partien;


-- ── 3. Verwaiste Partien aufräumen ─────────────────────────────────────────
-- `games` ist keine Statistik, sondern der Zustand laufender Runden. Die Zeilen
-- bleiben liegen, wenn niemand zu Ende spielt – aktuell sind es 73. Sie stören
-- nichts, aber wer sauber anfangen will:
--
-- Alles, was beendet ist oder seit einem Tag nicht angefasst wurde. `beendet`
-- heißt phase='over'; eine Lobby, in der nie jemand ankam, bleibt 'lobby'.
-- Spalten der Tabelle: code, state, version, created_at, updated_at.

-- delete from public.games
--  where state->>'phase' = 'over'
--     or updated_at < now() - interval '1 day';

-- Nur die Testrunden aus der Entwicklung (Spieler hießen dort "ZZ-…"). Der
-- ganze Zustand wird als Text durchsucht; `state->'seats'::text` wäre falsch,
-- weil ::text stärker bindet als -> und damit auf 'seats' angewendet würde.
-- delete from public.games where state::text like '%ZZ-%';


-- ── 4. Und auf jedem Gerät ─────────────────────────────────────────────────
-- Die Datenbank ist nur die eine Hälfte. Im Browser jedes Spielers liegen:
--
--   duell1408nachtrag   Zeilen, die nicht durchkamen – werden NACHGEREICHT
--                       und tauchen sonst nach dem Zurücksetzen wieder auf
--   duell1408best       Solo-Bestwert je Name ("Dein Bestwert" am Start)
--   duell1408tag        heutiges Tagesduell-Ergebnis (sperrt den zweiten Lauf)
--   duell1408karten     wie oft welche Karte dran war ("frische Karten zuerst")
--   duell1408solo       eine angefangene Solo-Partie
--   duell1408lauf       Kennung gegen Doppeleinträge
--   duell1408           Name und letzter Spielcode
--   duell1408filter     Einstellungen – die will man meist BEHALTEN
--
-- In der Browser-Konsole auf der Spielseite, ohne die Einstellungen:
--
--   ['duell1408nachtrag','duell1408best','duell1408tag','duell1408karten',
--    'duell1408solo','duell1408lauf','duell1408']
--     .forEach(k => localStorage.removeItem(k));
--   sessionStorage.removeItem('duell1408statistik');
--   location.reload();
--
-- Wirklich alles, Einstellungen inbegriffen:
--
--   localStorage.clear(); sessionStorage.clear(); location.reload();


-- ── 5. Nachher prüfen ──────────────────────────────────────────────────────

-- select (select count(*) from public.partien) as partien,
--        (select count(*) from public.tipps)   as tipps,
--        (select count(*) from public.games)   as games;
-- select * from public.bestenliste(10, null);
-- select * from public.tagesbestenliste();
