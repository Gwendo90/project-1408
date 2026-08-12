-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: Tagesduell
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Einmalig im Supabase-SQL-Editor ausführen, VOR dem Hochladen der neuen
-- duell.html. Der Client kommt mit der alten Datenbank zurecht – der Insert
-- schlägt dann fehl und landet im Nachtrag, die Tagesbestenliste sagt
-- "Auswertung fehlt noch". Gespielt werden kann trotzdem.
--
-- Erwartete Erfolgsmeldung: "Success. No rows returned."
--
-- Das Skript ist wiederholbar: mehrfaches Ausführen ändert nichts mehr.
--
-- Was das Tagesduell ist: Alle spielen an einem Tag dieselben zehn Karten in
-- derselben Reihenfolge. Das Deck entsteht im Client aus einem Seed, der aus
-- dem Datum gebildet wird – es steht also nirgends in der Datenbank und muss
-- das auch nicht. Gewertet wird nach Fehlern, bei Gleichstand nach Zeit.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Neue Spalten in `partien` ───────────────────────────────────────────
--
-- tag       Der Tag, für den der Lauf zählt – als date, nicht aus
--           `beendet_am` abgeleitet. Ein Lauf, der um 23:58 beginnt und um
--           00:01 endet, gehört zum Deck des Vortags; aus dem Endzeitpunkt
--           wäre das nicht mehr zu erkennen. Bei allen anderen Modi null.
-- dauer_ms  Dieselbe Dauer wie `dauer_s`, nur in Millisekunden. Nötig, weil
--           die Zeit bei gleicher Fehlerzahl die Reihenfolge entscheidet und
--           ganze Sekunden dort zu oft gleich wären. `dauer_s` bleibt
--           daneben stehen, damit bestehende Auswertungen nichts merken.

alter table public.partien
  add column if not exists tag      date,
  add column if not exists dauer_ms integer;


-- ── 2. Nur der erste Lauf des Tages zählt ──────────────────────────────────
--
-- Die Sperre gehört in die Datenbank, nicht in den Client: der Vermerk im
-- localStorage gilt nur für ein Gerät, und mit bekanntem Deck wäre ein
-- zweiter Lauf kein Vergleich mehr.
--
-- Teilindex mit `where modus = 'tag'`, damit Solo- und Duellzeilen nicht
-- betroffen sind – die haben `tag is null`, und mehrere davon je Person
-- müssen erlaubt bleiben. Über `name_key` und nicht über `name`, sonst wären
-- "Jenny" und "jenny" zwei Läufe.
--
-- Der Client wertet den Verstoß (SQLSTATE 23505) bereits als "steht schon
-- drin" und meldet keinen Fehler – genau dafür ist der Index da.

create unique index if not exists partien_tagesduell_einmal
  on public.partien (name_key, tag)
  where modus = 'tag';


-- ── 3. Tagesbestenliste ────────────────────────────────────────────────────
--
-- Sortiert nach Fehlern, bei Gleichstand nach Zeit. Der Platz kommt fertig
-- mit, damit ihn nicht jeder Aufrufer selbst zählen muss – und damit er bei
-- Gleichstand überall gleich ausfällt.
--
-- `p_tag` leer heißt "heute", geschnitten in Europe/Zurich. Dieselbe Zone wie
-- im Client (`ZONE` in duell.html) und wie in den übrigen Auswertungen: läge
-- hier UTC, wechselte der Tag zwei Stunden zu früh und die Liste zeigte ab
-- 22 Uhr das Deck von morgen, das noch niemand gespielt hat.
--
-- `dauer_ms asc nulls last`: Läufe ohne gemessene Zeit stehen hinten statt
-- vorn. Vorkommen sollte das nicht, aber sortiert wird nach echten Werten,
-- nicht nach fehlenden.

create or replace function public.tagesbestenliste(
  p_tag   date    default null,
  p_limit integer default 20)
returns table(platz bigint, name text, fehler integer, dauer_ms integer)
language sql
stable
as $function$
  select row_number() over (order by p.fehler asc, p.dauer_ms asc nulls last) as platz,
         p.name,
         p.fehler,
         p.dauer_ms
  from public.partien p
  where p.modus = 'tag'
    and p.tag = coalesce(p_tag, (now() at time zone 'Europe/Zurich')::date)
  order by p.fehler asc, p.dauer_ms asc nulls last
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$function$;


-- ── 4. Rechte ──────────────────────────────────────────────────────────────
--
-- Wie bei den übrigen Auswertungen: für `anon` ausführbar, nicht mehr.
-- `revoke ... from public` zuerst, weil eine neu angelegte Funktion sonst
-- über die Rolle `public` für jeden ausführbar bliebe.

do $$
begin
  execute 'revoke all on function public.tagesbestenliste(date,integer) from public';
  execute 'grant execute on function public.tagesbestenliste(date,integer) '
       || 'to anon, authenticated, service_role';
end $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- Selbsttest – einzeln ausführen, gehört nicht zur Installation.
-- ═══════════════════════════════════════════════════════════════════════════
--
--   select * from public.tagesbestenliste();            -- heute
--   select * from public.tagesbestenliste('2026-08-12');
--
-- Dass die Sperre greift, lässt sich so prüfen (die zweite Anweisung muss
-- mit "duplicate key value violates unique constraint" scheitern):
--
--   insert into public.partien (name, modus, tag, karten, fehler, dauer_ms)
--   values ('Prüflauf', 'tag', current_date, 11, 2, 134000);
--   insert into public.partien (name, modus, tag, karten, fehler, dauer_ms)
--   values ('prüflauf', 'tag', current_date, 11, 0,  90000);
--
-- Danach wieder aufräumen:
--
--   delete from public.partien where name_key = 'prüflauf';
