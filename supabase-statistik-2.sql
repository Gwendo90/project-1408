-- ═══════════════════════════════════════════════════════════════════════════
-- Auswertungen, zweiter Satz
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Setzt `supabase-migration-namen.sql` voraus – ohne die Spalten `partie_id`,
-- `pos`, `leiste_laenge`, `art`, `geklaut` und `name_key` legen mehrere dieser
-- Funktionen gar nicht erst an.
--
-- Einmal im SQL-Editor ausführen, vor dem Hochladen der neuen `duell.html`.
-- Erwartete Erfolgsmeldung: "Success. No rows returned."
-- Wiederholbar: alles ist CREATE OR REPLACE, es wird nichts gelöscht.
--
-- Alle Funktionen lesen nur. Sie laufen als SECURITY INVOKER, die
-- RLS-Regeln der Tabellen gelten also weiter; `anon` bekommt ausschließlich
-- EXECUTE.
--
-- Zwei Festlegungen, die überall gelten:
--   * Gruppiert wird über `name_key`, nie über `name`. Angezeigt wird die
--     zuletzt benutzte Schreibweise (siehe `anzeigename`).
--   * `p_seit` (timestamptz) grenzt den Zeitraum ein, NULL heißt alles.
--     Gemessen wird an `tipps.am` bzw. `partien.beendet_am`.
--
-- ACHTUNG, Zeitspalte: In `tipps` heißt sie **`am`**, nicht `created_at`.
--
-- ACHTUNG, Datenlage: Alles, was `partie_id`, `pos`, `art` oder `geklaut`
-- braucht, kann erst Daten liefern, nachdem die neue `duell.html` online ist
-- UND danach gespielt wurde. Der Altbestand hat diese Spalten durchgehend
-- NULL (Stand beim Anlegen dieser Datei: 187 Tipps und 14 Partien, davon
-- **null** mit `partie_id`). Betroffen sind duellmatrix, quote_position,
-- serien, klaubilanz und partie_rueckblick – die geben bis dahin leere
-- Ergebnisse zurück, und zwar völlig zu Recht.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── Hilfsfunktion: Anzeigename ─────────────────────────────────────────────
--
-- Zu einem `name_key` die zuletzt benutzte Schreibweise. Schaut in beide
-- Tabellen, damit auch jemand einen Namen bekommt, der bisher nur getippt
-- und noch keine Partie beendet hat.

create or replace function public.anzeigename(p_key text)
returns text
language sql
stable
as $function$
  select n.name from (
    select t.name, t.am         as wann from public.tipps   t where t.name_key = p_key
    union all
    select p.name, p.beendet_am as wann from public.partien p where p.name_key = p_key
  ) n
  order by n.wann desc
  limit 1;
$function$;


-- ── Schwerste Karten ───────────────────────────────────────────────────────
--
-- Über alle Spieler. `p_min` ist die Mindestzahl an Tipps: ohne sie stünde
-- jede Karte ganz oben, die genau einmal gespielt und dabei verrissen wurde.
-- Aufsteigend nach Trefferquote, bei Gleichstand die häufiger gespielte
-- zuerst – die ist besser belegt.
--
-- Läuft auf dem gesamten Bestand, auch auf den Zeilen von vor der Migration.

create or replace function public.schwerste_karten(
  p_seit  timestamptz default null,
  p_min   integer     default 3,
  p_limit integer     default 10)
returns table(song_id text, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  select t.song_id,
         count(*)                          as gesamt,
         count(*) filter (where t.korrekt) as richtig
  from public.tipps t
  where (p_seit is null or t.am >= p_seit)
  group by t.song_id
  having count(*) >= greatest(1, coalesce(p_min, 3))
  order by (count(*) filter (where t.korrekt))::numeric / count(*) asc,
           count(*) desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;


-- ── Angstgegner ────────────────────────────────────────────────────────────
--
-- Songs, die diese eine Person mehrfach falsch einsortiert hat. Einmal
-- danebenliegen ist Pech, zweimal ist ein Muster – daher `falsch >= 2` fest
-- verdrahtet und nicht als Parameter.
--
-- Ohne `p_name` kommt nichts zurück: das hier ist ausdrücklich persönlich.

create or replace function public.angstgegner(
  p_name  text,
  p_seit  timestamptz default null,
  p_limit integer     default 10)
returns table(song_id text, falsch bigint, gesamt bigint)
language sql
stable
as $function$
  select t.song_id,
         count(*) filter (where not t.korrekt) as falsch,
         count(*)                              as gesamt
  from public.tipps t
  where t.name_key = lower(btrim(p_name))
    and (p_seit is null or t.am >= p_seit)
  group by t.song_id
  having count(*) filter (where not t.korrekt) >= 2
  order by count(*) filter (where not t.korrekt) desc,
           count(*) asc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;


-- ── Aktivität je Tag ───────────────────────────────────────────────────────
--
-- Tagesgrenzen in Europe/Zurich, nicht in UTC: `beendet_am` ist timestamptz
-- und liegt intern in UTC, eine Partie um 23:30 Zürich fiele sonst auf den
-- Folgetag.
--
-- Gezählt werden Partien, nicht Zeilen. Im Duell schreibt jedes Gerät eine
-- Zeile je Mitspieler – über `partie_id` zusammengefasst ist das eine Partie.
-- Altzeilen ohne `partie_id` bekommen ersatzweise ihre eigene id, zählen also
-- einzeln; genauer geht es rückwirkend nicht.

create or replace function public.aktivitaet(
  p_name text        default null,
  p_seit timestamptz default null)
returns table(tag date, partien integer)
language sql
stable
as $function$
  select (p.beendet_am at time zone 'Europe/Zurich')::date                  as tag,
         count(distinct coalesce(p.partie_id::text, 'alt' || p.id::text))::int as partien
  from public.partien p
  where (p_name is null or p.name_key = lower(btrim(p_name)))
    and (p_seit is null or p.beendet_am >= p_seit)
  group by 1
  order by 1;
$function$;


-- ── Kopf an Kopf ───────────────────────────────────────────────────────────
--
-- Paarungen über `partie_id`, nicht über die Textspalte `gegner`: dort stehen
-- alle Mitspieler als ein zusammengeklebter String, aus dem sich keine
-- Paarung zurückgewinnen lässt.
--
-- `b.name_key > a.name_key` gibt jede Paarung genau einmal aus, nicht zweimal
-- gespiegelt. Bei drei oder vier Mitspielern entsteht jede Zweierkombination;
-- eine gemeinsame Partie, die ein Dritter gewonnen hat, zählt dann für beide
-- als kein Sieg – gemeinsam gespielt haben sie sie trotzdem.

create or replace function public.duellmatrix(p_seit timestamptz default null)
returns table(name_a text, name_b text, siege_a bigint, siege_b bigint)
language sql
stable
as $function$
  select public.anzeigename(a.name_key)      as name_a,
         public.anzeigename(b.name_key)      as name_b,
         count(*) filter (where a.gewonnen)  as siege_a,
         count(*) filter (where b.gewonnen)  as siege_b
  from public.partien a
  join public.partien b
    on  b.partie_id = a.partie_id
    and b.name_key  > a.name_key
  where a.modus = 'duell' and b.modus = 'duell'
    and a.partie_id is not null
    and (p_seit is null or a.beendet_am >= p_seit)
  group by a.name_key, b.name_key
  order by count(*) desc, 1;
$function$;


-- ── Quote nach Lückenposition ──────────────────────────────────────────────
--
-- Bei einer Leiste der Länge L gibt es L+1 Lücken, `pos` läuft von 0 bis L.
-- Ganz vorn und ganz hinten ist nur eine Grenze zu treffen, in der Mitte
-- zwei – deshalb die Aufteilung.
--
-- Leisten unter zwei Karten fliegen raus: dort gibt es überhaupt keine Mitte,
-- die Aufteilung wäre sinnlos. Ebenso Zeilen ohne `pos` (vor der Migration).

create or replace function public.quote_position(
  p_name text        default null,
  p_seit timestamptz default null)
returns table(bucket text, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  with m as (
    select case when t.pos = 0               then 'Anfang'
                when t.pos = t.leiste_laenge then 'Ende'
                else                              'Mitte'
           end as b,
           t.korrekt
    from public.tipps t
    where t.pos is not null
      and t.leiste_laenge >= 2
      and (p_name is null or t.name_key = lower(btrim(p_name)))
      and (p_seit is null or t.am >= p_seit)
  )
  select m.b,
         count(*)                          as gesamt,
         count(*) filter (where m.korrekt) as richtig
  from m
  group by m.b
  order by case m.b when 'Anfang' then 1 when 'Mitte' then 2 else 3 end;
$function$;


-- ── Längste Serie ──────────────────────────────────────────────────────────
--
-- Klassisches "gaps and islands": Zwei Zählungen laufen mit – eine über alle
-- Tipps, eine getrennt nach richtig/falsch. Ihre Differenz bleibt innerhalb
-- einer ununterbrochenen Folge konstant und ändert sich bei jedem Bruch. Über
-- diese Differenz wird gruppiert.
--
-- Fenster über (name_key, partie_id): Serien laufen nicht über Partiegrenzen
-- hinweg. Sortiert nach `am`, bei gleicher Zeit nach `id` – zwei Tipps
-- derselben Karte (Zug und Veto) können auf dieselbe Millisekunde fallen.
--
-- Je Person eine Zeile, ihre beste. Sonst könnte eine einzige starke Partie
-- die ganze Liste belegen.

create or replace function public.serien(
  p_name  text        default null,
  p_seit  timestamptz default null,
  p_limit integer     default 10)
returns table(name text, laenge integer, partie_id uuid, datum date)
language sql
stable
as $function$
  with basis as (
    select t.name_key, t.partie_id, t.am, t.korrekt,
           row_number() over (partition by t.name_key, t.partie_id
                              order by t.am, t.id) as rn,
           row_number() over (partition by t.name_key, t.partie_id, t.korrekt
                              order by t.am, t.id) as rk
    from public.tipps t
    where t.partie_id is not null
      and (p_name is null or t.name_key = lower(btrim(p_name)))
      and (p_seit is null or t.am >= p_seit)
  ),
  laeufe as (
    select b.name_key, b.partie_id,
           count(*)   as laenge,
           max(b.am)  as bis
    from basis b
    where b.korrekt
    group by b.name_key, b.partie_id, (b.rn - b.rk)
  ),
  beste as (
    select distinct on (l.name_key) l.name_key, l.partie_id, l.laenge, l.bis
    from laeufe l
    order by l.name_key, l.laenge desc, l.bis desc
  )
  select public.anzeigename(x.name_key),
         x.laenge::int,
         x.partie_id,
         (x.bis at time zone 'Europe/Zurich')::date
  from beste x
  order by x.laenge desc, x.bis desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;


-- ── Klau-Bilanz ────────────────────────────────────────────────────────────
--
-- `geklaut`   = eigene Zeilen mit art='veto' und geklaut=true.
-- `bestohlen` = wem dabei die Karte abgenommen wurde.
--
-- Das Opfer steht nicht in der Veto-Zeile, es wird abgeleitet: Zu jedem
-- gelungenen Veto gehört in derselben Partie zu derselben Karte genau eine
-- Zeile mit art='normal' und korrekt=false – der Zug, an dem der Spieler am
-- Zug gescheitert ist (siehe `nachAuswertung()` in duell.html, das beide
-- Zeilen aus demselben `result` schreibt).
--
-- Wichtig dabei: Angesetzt wird an der **Veto-Zeile mit geklaut=true**, nicht
-- an "art='normal' und korrekt=false". Letzteres allein trifft auch jede
-- Runde, in der ein Veto scheiterte – dort hat niemand etwas verloren.
--
-- (partie_id, song_id) ist eindeutig: das Deck wird gemischt und abgetragen,
-- jede Karte kommt in einer Partie höchstens einmal vor. `count(distinct v.id)`
-- zählt trotzdem am Veto entlang, damit eine doppelt protokollierte Gegenzeile
-- die Bilanz nicht aufblähen könnte – `tipps` hat keine Entdopplung.

create or replace function public.klaubilanz(p_seit timestamptz default null)
returns table(name text, geklaut bigint, bestohlen bigint)
language sql
stable
as $function$
  with erbeutet as (
    select v.name_key, count(*) as n
    from public.tipps v
    where v.art = 'veto' and v.geklaut
      and v.partie_id is not null
      and (p_seit is null or v.am >= p_seit)
    group by v.name_key
  ),
  verloren as (
    select o.name_key, count(distinct v.id) as n
    from public.tipps v
    join public.tipps o
      on  o.partie_id = v.partie_id
      and o.song_id   = v.song_id
      and o.art       = 'normal'
      and o.korrekt   = false
    where v.art = 'veto' and v.geklaut
      and v.partie_id is not null
      and (p_seit is null or v.am >= p_seit)
    group by o.name_key
  ),
  wer as (
    select name_key from erbeutet
    union
    select name_key from verloren
  )
  select public.anzeigename(w.name_key),
         coalesce(e.n, 0),
         coalesce(l.n, 0)
  from wer w
  left join erbeutet e on e.name_key = w.name_key
  left join verloren l on l.name_key = w.name_key
  order by coalesce(e.n, 0) desc, coalesce(l.n, 0) asc, 1;
$function$;


-- ── Rückblick auf eine Partie ──────────────────────────────────────────────
--
-- Eine Abfrage, nicht vier: Der Endbildschirm soll nicht auf vier Umläufe
-- warten.
--
-- `haerteste_song_id` ist die Karte **dieser Partie** mit der niedrigsten
-- Trefferquote **über den gesamten Bestand** – nicht nur über die Mitspieler
-- dieser Runde. Im Solo wären das sonst nur die eigenen ein bis zwei Versuche,
-- also 0 % oder 100 % und damit nichtssagend. Bei Gleichstand die Karte, die
-- in dieser Partie zuletzt dran war.

create or replace function public.partie_rueckblick(
  p_partie_id uuid,
  p_name      text)
returns table(quote_gesamt bigint, quote_richtig bigint,
              beste_serie integer, haerteste_song_id text)
language sql
stable
as $function$
  with meine as (
    select t.korrekt,
           row_number() over (order by t.am, t.id)                  as rn,
           row_number() over (partition by t.korrekt
                              order by t.am, t.id)                  as rk
    from public.tipps t
    where t.partie_id = p_partie_id
      and t.name_key  = lower(btrim(p_name))
  ),
  serie as (
    select coalesce(max(x.c), 0) as laenge
    from (select count(*) as c from meine where korrekt group by (rn - rk)) x
  ),
  karten as (
    select t.song_id, max(t.am) as zuletzt
    from public.tipps t
    where t.partie_id = p_partie_id
    group by t.song_id
  ),
  haerte as (
    select k.song_id
    from karten k
    join public.tipps g on g.song_id = k.song_id
    group by k.song_id, k.zuletzt
    order by (count(*) filter (where g.korrekt))::numeric / count(*) asc,
             k.zuletzt desc
    limit 1
  )
  select (select count(*) from meine),
         (select count(*) from meine where korrekt),
         (select laenge from serie)::int,
         (select song_id from haerte);
$function$;


-- ── Die vier bisherigen Auswertungen bekommen p_seit ───────────────────────
--
-- Sie müssen denselben Zeitfilter kennen wie die neuen, sonst zeigte die
-- Statistikseite oben „Dieser Monat" und darunter trotzdem alles.
--
-- Warum erst ablegen statt CREATE OR REPLACE: Ein Parameter mehr ist eine
-- andere Signatur. REPLACE würde die alte Fassung nicht ersetzen, sondern
-- eine zweite danebenstellen – und ein Aufruf mit nur den alten Argumenten
-- wäre dann mehrdeutig ("function is not unique"). Deshalb gezielt weg und
-- neu.
--
-- Ein Bruch für den laufenden Betrieb ist das nicht: p_seit hat einen
-- Vorgabewert, die alte duell.html ruft weiterhin nur mit ihren bisherigen
-- Argumenten auf und bekommt automatisch NULL – also alles, wie gehabt.

drop function if exists public.bestenliste(integer);
drop function if exists public.duellbilanz();
drop function if exists public.quote_jahrzehnt(text);
drop function if exists public.quote_land(text);

-- Unverändert eine Liste einzelner Solo-Partien, keine je Spieler. Angezeigt
-- wird die zuletzt benutzte Schreibweise – innerhalb des gewählten Zeitraums,
-- denn nur den sieht die Fensterfunktion.
create or replace function public.bestenliste(
  p_limit integer     default 10,
  p_seit  timestamptz default null)
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
    and (p_seit is null or p.beendet_am >= p_seit)
  order by p.karten desc, p.beendet_am asc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;

create or replace function public.duellbilanz(p_seit timestamptz default null)
returns table(name text, spiele bigint, siege bigint)
language sql
stable
as $function$
  select (array_agg(p.name order by p.beendet_am desc, p.id desc))[1] as name,
         count(*)                             as spiele,
         count(*) filter (where p.gewonnen)   as siege
  from public.partien p
  where p.modus = 'duell'
    and (p_seit is null or p.beendet_am >= p_seit)
  group by p.name_key
  order by count(*) filter (where p.gewonnen) desc, count(*) asc;
$function$;

create or replace function public.quote_jahrzehnt(
  p_name text        default null,
  p_seit timestamptz default null)
returns table(jahrzehnt integer, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  select (t.jahr / 10) * 10                as jahrzehnt,
         count(*)                          as gesamt,
         count(*) filter (where t.korrekt) as richtig
  from public.tipps t
  where (p_name is null or t.name_key = lower(btrim(p_name)))
    and (p_seit is null or t.am >= p_seit)
  group by 1
  order by 1;
$function$;

create or replace function public.quote_land(
  p_name text        default null,
  p_seit timestamptz default null)
returns table(land text, gesamt bigint, richtig bigint)
language sql
stable
as $function$
  select t.land,
         count(*)                          as gesamt,
         count(*) filter (where t.korrekt) as richtig
  from public.tipps t
  where (p_name is null or t.name_key = lower(btrim(p_name)))
    and (p_seit is null or t.am >= p_seit)
  group by 1
  order by count(*) desc;
$function$;


-- ── Rechte ─────────────────────────────────────────────────────────────────
--
-- Funktionen sind in Postgres von Haus aus für PUBLIC ausführbar. Hier wird
-- das eingeschränkt und gezielt vergeben, damit „nur EXECUTE für anon" auch
-- wirklich dasteht und nicht bloß gilt, weil niemand es weggenommen hat.

do $$
declare f text;
begin
  foreach f in array array[
    'public.anzeigename(text)',
    'public.schwerste_karten(timestamptz,integer,integer)',
    'public.angstgegner(text,timestamptz,integer)',
    'public.aktivitaet(text,timestamptz)',
    'public.duellmatrix(timestamptz)',
    'public.quote_position(text,timestamptz)',
    'public.serien(text,timestamptz,integer)',
    'public.klaubilanz(timestamptz)',
    'public.partie_rueckblick(uuid,text)',
    -- Frisch angelegt, also brauchen auch die ihre Rechte wieder:
    'public.bestenliste(integer,timestamptz)',
    'public.duellbilanz(timestamptz)',
    'public.quote_jahrzehnt(text,timestamptz)',
    'public.quote_land(text,timestamptz)'
  ] loop
    execute format('revoke all on function %s from public', f);
    execute format('grant execute on function %s to anon, authenticated, service_role', f);
  end loop;
end $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- Selbsttest – einzeln ausführen, gehört nicht zur Installation.
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Der SQL-Editor zeigt bei mehreren Anweisungen nur das Ergebnis der letzten.
--
-- Laufen sofort, auch auf dem Altbestand:
--   select * from public.anzeigename('jenny');
--   select * from public.schwerste_karten(null, 3, 10);
--   select * from public.angstgegner('Jenny', null, 10);
--   select * from public.aktivitaet(null, null);
--   select * from public.aktivitaet('  JENNY ', null);      -- Name ungeputzt
--
-- Liefern erst nach Partien mit der neuen duell.html etwas (vorher leer, und
-- das ist richtig so):
--   select * from public.duellmatrix(null);
--   select * from public.quote_position(null, null);
--   select * from public.serien(null, null, 10);
--   select * from public.klaubilanz(null);
--   select * from public.partie_rueckblick(
--            (select partie_id from public.partien where partie_id is not null
--              order by beendet_am desc limit 1), 'Jenny');
--
-- Zeitfilter greift (zweite Zahl muss kleiner oder gleich der ersten sein):
--   select (select count(*) from public.schwerste_karten(null, 1, 50))        as alles,
--          (select count(*) from public.schwerste_karten(now() - interval '30 days', 1, 50)) as monat;
--
-- Zeitzone stimmt (muss den Zürcher Kalendertag zeigen, nicht den UTC-Tag):
--   select tag, partien from public.aktivitaet(null, null) order by tag desc limit 5;
--
-- Rechte (erwartet: eine Zeile je Funktion, nur für anon/authenticated/service_role):
--   select p.proname, r.grantee, r.privilege_type
--     from information_schema.role_routine_grants r
--     join pg_proc p on p.proname = r.routine_name
--    where r.routine_schema = 'public'
--      and p.proname in ('schwerste_karten','angstgegner','aktivitaet','duellmatrix',
--                        'quote_position','serien','klaubilanz','partie_rueckblick','anzeigename')
--    order by 1, 2;
