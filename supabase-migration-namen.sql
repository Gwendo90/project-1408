-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: Namensnormalisierung und Verknüpfung der Statistikzeilen
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Einmalig im Supabase-SQL-Editor ausführen, VOR dem Hochladen der neuen
-- duell.html. Der Client kommt mit der alten Datenbank noch zurecht (ein
-- fehlgeschlagener Insert erzeugt nur eine Warnung in der Konsole), aber die
-- neuen Spalten bleiben bis dahin leer.
--
-- Erwartete Erfolgsmeldung: "Success. No rows returned."
--
-- Das Skript ist wiederholbar: mehrfaches Ausführen ändert nichts mehr und
-- lässt bestehende Zeilen unangetastet. Alle neuen Spalten sind nullable,
-- der Altbestand (13 Partien, 180 Tipps) bleibt also gültig.
--
-- Behoben werden vier Dinge:
--   1. Doppelte Solo-Zeile beim Neuladen  → partien.lauf_id + eindeutiger Index
--   2. "Jenny" / "jenny" / "Jenny " als drei Spieler → name_key, und die vier
--      Auswertungsfunktionen rechnen ab jetzt darüber (Abschnitt 7)
--   3. Zeilen einer Partie hängen nicht zusammen → partie_id in beiden Tabellen
--   4. Fehlende Spalten für spätere Auswertungen → Veto, Position, Dauer
--
-- Die Abschnitte bauen aufeinander auf, das Skript also von oben nach unten
-- in einem Rutsch ausführen.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Neue Spalten in `partien` ───────────────────────────────────────────
--
-- lauf_id   Ein Wert je Partie und Gerät, vom Client erzeugt und im
--           localStorage gehalten. Dient allein der Entdopplung: er überlebt
--           ein Neuladen der Seite, die Modulvariable `partieProtokolliert`
--           tut das nicht.
-- partie_id Ein Wert je Partie, im Spielzustand abgelegt. Alle Geräte
--           schreiben denselben – darüber hängen `partien` und `tipps`
--           zusammen.
-- dauer_s   Spieldauer in Sekunden, vom Spielstart bis zur letzten
--           Auswertung. Startzeitpunkt steht im Spielzustand, nicht auf dem
--           Gerät – sonst stimmte er nach einem Wiedereinstieg nicht.
-- fehler    Verbrauchte Leben (Solo). Im Duell null, dort gibt es keine.

alter table public.partien
  add column if not exists lauf_id   uuid,
  add column if not exists partie_id uuid,
  add column if not exists dauer_s   integer,
  add column if not exists fehler    integer;


-- ── 2. Neue Spalten in `tipps` ─────────────────────────────────────────────
--
-- partie_id      Verweis auf die Partie, siehe oben.
-- art            'normal' = regulärer Zug des Spielers am Zug,
--                'veto'   = Tipp eines Vetogebers auf dieselbe Karte.
-- geklaut        Nur bei art='veto' aussagekräftig: true, wenn die Karte
--                tatsächlich den Besitzer gewechselt hat.
-- pos            Gewählte Lücke (0 = ganz links).
-- leiste_laenge  Länge der Zeitleiste, in die einsortiert wurde, VOR dem
--                Einsortieren. pos/leiste_laenge machen den Tipp erst
--                vergleichbar: eine Lücke von drei zu treffen ist etwas
--                anderes als eine von elf.
--
-- Achtung: beide beziehen sich auf die Leiste, in die tatsächlich einsortiert
-- wurde. Beim Veto ist das die Leiste des Spielers am Zug, nicht die des
-- Vetogebers – geprüft wird ja dieselbe Aufgabe, an der jener gescheitert ist.

alter table public.tipps
  add column if not exists partie_id     uuid,
  add column if not exists art           text,
  add column if not exists geklaut       boolean,
  add column if not exists pos           integer,
  add column if not exists leiste_laenge integer;

-- Altbestand hat art = NULL; eine CHECK-Bedingung mit NULL ergibt NULL und
-- gilt damit als erfüllt. Die alten Zeilen bleiben also gültig.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.tipps'::regclass
       and conname  = 'tipps_art_check'
  ) then
    alter table public.tipps
      add constraint tipps_art_check check (art in ('normal','veto'));
  end if;
end $$;


-- ── 3. Normalisierter Name ─────────────────────────────────────────────────
--
-- Namen sind Freitext. `name_key` ist die Vergleichsform, `name` bleibt die
-- Anzeigeform – so lässt sich weiterhin zeigen, wie jemand sich zuletzt
-- geschrieben hat, ohne dass "Jenny", "jenny" und "Jenny " auseinanderfallen.
-- GENERATED ... STORED heißt: die Datenbank pflegt die Spalte selbst, der
-- Client schreibt sie nie mit.

alter table public.partien
  add column if not exists name_key text
  generated always as (lower(btrim(name))) stored;

alter table public.tipps
  add column if not exists name_key text
  generated always as (lower(btrim(name))) stored;

create index if not exists partien_name_key_idx on public.partien (name_key);
create index if not exists tipps_name_key_idx   on public.tipps   (name_key);


-- ── 4. Entdopplung ─────────────────────────────────────────────────────────
--
-- Ein eindeutiger Index statt einer UNIQUE-Bedingung: nur der kennt
-- IF NOT EXISTS und ist damit ohne Umweg wiederholbar. Die Garantie ist
-- dieselbe.
--
-- Bewusst über (lauf_id, name_key) und NICHT über lauf_id allein: im Duell
-- schreibt ein einziges Gerät in EINEM insert die Zeilen aller Mitspieler,
-- alle mit derselben lauf_id. Ein Index auf lauf_id allein würde diesen
-- insert komplett zurückweisen – die Duellstatistik fiele ersatzlos aus.
-- Mit dem Namen daneben greift die Entdopplung wie gewünscht (dasselbe Gerät,
-- derselbe Lauf, derselbe Spieler = eine Zeile) und das Duell bleibt heil.
--
-- NULLs gelten in Postgres als voneinander verschieden. Der Altbestand hat
-- durchgehend lauf_id = NULL und kollidiert deshalb weder mit sich selbst
-- noch mit neuen Zeilen.

create unique index if not exists partien_lauf_name_uidx
  on public.partien (lauf_id, name_key);

-- Der zweite Riegel, und der eigentlich tragende. Gemessen an einer zu Ende
-- gespielten Testpartie schreiben im Duell BEIDE Geräte die Zeilen aller
-- Mitspieler, nicht nur eines – vier Zeilen statt zwei. Der Index oben hilft
-- da nicht: jedes Gerät bringt seine eigene lauf_id mit. Die partie_id ist
-- auf allen Geräten dieselbe und übersteht auch ein Neuladen, deshalb fängt
-- dieser Index beide Fälle ab.
--
-- Eine zweite Zeile für dieselbe Person in derselben Partie gibt es
-- regulär nicht: "Nochmal spielen" und jeder Solostart vergeben eine neue
-- partie_id. Der Altbestand hat partie_id = NULL und bleibt unberührt.
create unique index if not exists partien_partie_name_uidx
  on public.partien (partie_id, name_key);


-- ── 5. Verknüpfung ─────────────────────────────────────────────────────────

create index if not exists partien_partie_id_idx on public.partien (partie_id);
create index if not exists tipps_partie_id_idx   on public.tipps   (partie_id);


-- ── 6. Rechte ──────────────────────────────────────────────────────────────
--
-- RLS wirkt zeilenweise, nicht spaltenweise: die neuen Spalten fallen
-- automatisch unter die bestehenden Regeln. Zu prüfen bleibt, dass es bei
-- select + insert bleibt und sich kein update/delete eingeschlichen hat.
-- Die Tabellenrechte werden hier nur festgezurrt, vorhandene Regeln bleiben
-- unberührt – angelegt wird eine nur, wenn für die Aktion noch keine da ist.

do $$
declare t text;
begin
  foreach t in array array['partien','tipps'] loop
    execute format('alter table public.%I enable row level security', t);

    if not exists (select 1 from pg_policies
                    where schemaname = 'public' and tablename = t
                      and cmd in ('SELECT','ALL')) then
      execute format('create policy %I on public.%I for select to anon, authenticated using (true)',
                     t || '_select_anon', t);
    end if;

    if not exists (select 1 from pg_policies
                    where schemaname = 'public' and tablename = t
                      and cmd in ('INSERT','ALL')) then
      execute format('create policy %I on public.%I for insert to anon, authenticated with check (true)',
                     t || '_insert_anon', t);
    end if;
  end loop;
end $$;

grant  select, insert            on table public.partien, public.tipps to anon, authenticated;
revoke update, delete, truncate  on table public.partien, public.tipps from anon, authenticated;


-- ── 7. Auswertungen auf den normalisierten Namen umstellen ─────────────────
--
-- Muss NACH Abschnitt 3 laufen – die Rümpfe greifen auf name_key zu. Deshalb
-- steht das hier in derselben Datei und nicht in einer zweiten.
--
-- Signatur und Rückgabetyp bleiben bei allen vier Funktionen exakt gleich,
-- sonst scheitert CREATE OR REPLACE und der Client bekäme Felder, die er
-- nicht kennt. Was sie zählen und in welcher Reihenfolge sie liefern, ändert
-- sich ebenfalls nicht – nur *wer* als derselbe Mensch gilt.

-- Bleibt eine Liste einzelner Solo-Partien, nicht eine je Spieler: eine
-- Person darf die Bestenliste weiterhin mehrfach belegen, das ist bisheriges
-- Verhalten und keine neue Auswertung. Neu ist allein der angezeigte Name –
-- statt der Schreibweise aus genau dieser Zeile die zuletzt verwendete
-- desselben Menschen. Sonst stünde in der Liste einmal "Jenny" und einmal
-- "jenny", und es sähe nach zwei Spielerinnen aus.
create or replace function public.bestenliste(p_limit integer default 10)
returns table(name text, karten integer, beendet_am timestamp with time zone)
language sql
stable
as $function$
  select first_value(p.name) over (partition by p.name_key
                                   order by p.beendet_am desc, p.id desc) as name,
         p.karten,
         p.beendet_am
  from public.partien p
  where p.modus = 'solo'
  order by p.karten desc, p.beendet_am asc
  limit greatest(1, least(coalesce(p_limit,10), 50));
$function$;

-- Gruppiert über name_key statt über name. Der Anzeigename ist der aus der
-- jüngsten Zeile der Gruppe – array_agg sortiert absteigend, [1] ist damit
-- die zuletzt benutzte Schreibweise.
create or replace function public.duellbilanz()
returns table(name text, spiele bigint, siege bigint)
language sql
stable
as $function$
  select (array_agg(p.name order by p.beendet_am desc, p.id desc))[1] as name,
         count(*)                             as spiele,
         count(*) filter (where p.gewonnen)   as siege
  from public.partien p
  where p.modus = 'duell'
  group by p.name_key
  order by count(*) filter (where p.gewonnen) desc, count(*) asc;
$function$;

-- Hier wird kein Name ausgegeben, nur gefiltert. Normalisiert werden muss
-- deshalb der Parameter: die Filterung passiert in der Datenbank, damit sie
-- auch dann greift, wenn ein älterer Client den Namen ungeputzt schickt.
create or replace function public.quote_jahrzehnt(p_name text default null::text)
returns table(jahrzehnt integer, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  select (t.jahr / 10) * 10                as jahrzehnt,
         count(*)                          as gesamt,
         count(*) filter (where t.korrekt) as richtig
  from public.tipps t
  where p_name is null or t.name_key = lower(btrim(p_name))
  group by 1
  order by 1;
$function$;

create or replace function public.quote_land(p_name text default null::text)
returns table(land text, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  select t.land,
         count(*)                          as gesamt,
         count(*) filter (where t.korrekt) as richtig
  from public.tipps t
  where p_name is null or t.name_key = lower(btrim(p_name))
  group by 1
  order by count(*) desc;
$function$;


-- ═══════════════════════════════════════════════════════════════════════════
-- Zum Nachsehen – separat ausführen, gehört nicht zur Migration.
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Spalten:
--   select table_name, column_name, data_type, is_nullable, is_generated
--     from information_schema.columns
--    where table_schema = 'public' and table_name in ('partien','tipps')
--    order by table_name, ordinal_position;
--
-- Rechte für anon (erwartet: nur INSERT und SELECT, je Tabelle):
--   select table_name, privilege_type
--     from information_schema.role_table_grants
--    where grantee = 'anon' and table_name in ('partien','tipps')
--    order by table_name, privilege_type;
--
-- Regeln:
--   select tablename, policyname, cmd, roles
--     from pg_policies
--    where tablename in ('partien','tipps') order by tablename, cmd;
--
-- Normalisierung wirkt (zeigt zusammengefasste Schreibweisen):
--   select name_key, count(*), array_agg(distinct name) from public.partien
--    group by name_key order by 2 desc;
--
-- Die vier Auswertungen laufen noch (müssen dieselben Zahlen liefern wie
-- vorher, solange keine zwei Schreibweisen im Bestand sind):
--   select * from public.bestenliste(10);
--   select * from public.duellbilanz();
--   select * from public.quote_jahrzehnt(null);
--   select * from public.quote_land('  JENNY ');   -- muss Jennys Zeilen finden
