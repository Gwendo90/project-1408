11# Project 1408

Ein selbstgebautes Eurovision-Kartenspiel nach Hitster-Art — als **gedrucktes Kartenspiel** mit
QR-Codes und als **Web-App** auf GitHub Pages.

> **Für KI-Assistenten:** Lies erst den Abschnitt [Fallstricke](#fallstricke). Dort stehen die
> Dinge, die beim Anfassen dieses Codes schiefgehen — mehrere davon sind teuer erkauft.

Live: <https://gwendo90.github.io/project-1408/>

---

## Worum geht es

Die Spieler hören einen 30- bis 90-sekündigen Ausschnitt eines Eurovision-Beitrags und müssen
ihn **chronologisch** in ihre eigene Zeitleiste einsortieren, ohne das Jahr zu kennen. Sitzt die
Karte richtig, bleibt sie liegen. Wer zuerst zehn Karten hat, gewinnt.

Es gibt zwei getrennte Anwendungen im Repo:

| | Datei | Zweck |
|---|---|---|
| **Offline-Modus** | `index.html` | Ergänzt das gedruckte Spiel. QR-Code auf der Karte scannen → Song wird abgespielt → auflösen. Kein Backend, keine Spiellogik. |
| **Online-Modus** | `duell.html` | Vollständiges Spiel im Browser, 1–4 Spieler auf getrennten Geräten. Backend: Supabase. |

Beide teilen sich `songs.json` und die Bildmarken. Dazu je eine Anleitung als Webseite:
`anleitung.html` für das gedruckte Spiel, `anleitung-online.html` für den Online-Modus —
erreichbar über den „So geht's"-Knopf oben links auf dem Startbildschirm von `duell.html`.

---

## Repo-Inhalt

```
index.html              Offline-Modus: QR scannen und abspielen
duell.html              Online-Modus: das eigentliche Spiel (~90 KB, alles inline)
duell-config.js         Supabase-URL und öffentlicher Key
supabase.js             Supabase-Bibliothek, eigenständig (siehe Fallstricke!)
songs.json              336 Songs mit Vorschau-URLs
flags/                  44 Herzflaggen als PNG, 128×128
anleitung.html          Spielanleitung fürs gedruckte Kartenspiel
anleitung-online.html   Spielanleitung für den Online-Modus (Prinzip, Solo vs. Mehrspieler, Veto)
Logo.png / Logo.svg     Bildmarke (Logo.svg NICHT verwenden, siehe Fallstricke)
manifest.json           PWA-Manifest (Pfade sind kaputt, siehe Offene Punkte)
icon-192/512.png, apple-touch-icon.png

supabase-migration-namen.sql  Namensnormalisierung, Verknüpfung, Entdopplung — einmalig
supabase-statistik-2.sql      Zweiter Satz Auswertungen + Zeitfilter — nach der Migration
```

**`supabase-schema.sql` und `supabase-statistik.sql` fehlen im Repo.** Sie sind einmal
eingespielt worden und danach verloren gegangen; das Schema ist damit nicht reproduzierbar.
Die Rümpfe der vier Auswertungsfunktionen lassen sich im Notfall aus der laufenden Datenbank
zurückholen:

```sql
select p.proname, pg_get_functiondef(p.oid)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('bestenliste','duellbilanz','quote_jahrzehnt','quote_land');
```

Nicht im Repo, nur lokal im Projektordner: `Set_1/`, `Set_2/` (Kartenbilder für den Druck,
~170 MB), `build_flags.py`, `trace_heart.py`, die Excel-Dateien und QR-Generatoren.

---

## Die Songdaten

`songs.json` ist ein **Objekt mit den Schlüsseln `"001"` bis `"336"`** — kein Array. Die IDs
entsprechen den QR-Codes auf den gedruckten Karten.

```json
"001": {
  "year": "1956",           // String, nicht Zahl
  "artist": "Lys Assia",
  "title": "Refrain",
  "country": "Schweiz",     // deutscher Name, 44 verschiedene
  "flag": "🇨🇭",             // Emoji, dient als Rückfall
  "place": "1",             // Platzierung beim ESC
  "sid": "448456972",       // iTunes-Track-ID
  "u":   "https://music.apple.com/…",
  "pr":  "https://audio-ssl.itunes.apple.com/…"   // Vorschau, direkt abspielbar
}
```

* Jahre **1956–2026**, 71 Jahrgänge, jeder mehrfach belegt — gleiche Jahre sind der Normalfall.
* **Alle 336 Einträge haben ein gefülltes `pr`-Feld.** Der iTunes-Lookup in `index.html` ist
  reiner Rückfall und greift praktisch nie.
* Die Vorschauen sind **überwiegend 90 Sekunden lang**, nicht 30 (Stichprobe: 22 von 24).
  Nirgends 30 Sekunden fest annehmen.
* Die Kartenbilder in `Set_1/` und `Set_2/` sind nach **Druckreihenfolge** benannt, nicht nach
  Song-ID. Es gibt keine Zuordnung Bild → ID. Der Online-Modus baut die Karten deshalb in CSS
  nach.

---

## Spielregeln

### Kern (gedruckt und online identisch)

1. Karte ziehen, Ausschnitt hören, Jahr **nicht** sichtbar.
2. In die eigene Zeitleiste einsortieren.
3. Richtig → Karte bleibt. Falsch → Karte verfällt.
4. Zehn Karten gewinnen.

**Was „richtig" heißt:** Die Karte sitzt an Position `i`, wenn
`jahr(links) <= jahr(karte) <= jahr(rechts)`. Gleiche Jahre zählen als passend — bei 336 Songs
auf 71 Jahrgänge ist das der Normalfall, nicht die Ausnahme.

Bei zehn Karten sind im Schnitt nur **1,14 von 11 Lücken** korrekt; Raten trifft also zu rund
11 %. Es gibt immer mindestens eine gültige Lücke, eine Sackgasse ist unmöglich (über 5000
Zufallsfälle geprüft).

### Kartenklau per Veto (online umgesetzt)

Entspricht dem „Einspruch" der gedruckten Anleitung:

* Der Spieler am Zug legt sich mit **„Karte einloggen"** verbindlich fest.
* Danach 15 Sekunden Fenster für alle Mitspieler. **Wer zuerst tippt, bekommt den Zugriff**,
  die anderen sind raus. Meldet niemand ein Veto, wird automatisch aufgelöst.
* Der Vetogeber tippt eine Lücke **in der Zeitleiste des Spielers am Zug** — dieselbe Aufgabe,
  an der dieser gerade gescheitert ist. Die angefochtene Stelle selbst ist gesperrt.
* Ein Veto zieht **nur**, wenn der Spieler am Zug daneben lag **und** der Vetogeber richtig
  liegt. Gegen eine korrekte Platzierung geht es immer verloren.
* Erfolg → die Karte wird automatisch an der passenden Stelle in die Leiste des Vetogebers
  einsortiert, das Veto bleibt erhalten. Misserfolg → Veto verbraucht.
* Drei Vetos je Spieler (`VETOS_START`).

### Solo

Endlos ziehen, nach drei Fehlern ist Schluss (`SOLO_FEHLER`). Gezählt werden die gesammelten
Karten, Bestwert lokal in `localStorage`. **Kein Veto, kein Backend nötig** — Solo läuft auch,
wenn Supabase nicht erreichbar ist.

**Der Bestwert hängt am Namen, nicht am Gerät.** In `duell1408best` steht ein Objekt
`{ name_key: karten }`, normalisiert wie in der Datenbank. Früher lag dort eine blanke Zahl
fürs ganze Gerät, während daneben „Dein Bestwert" stand — wer sie erspielt hatte, war nirgends
vermerkt, also bekam jeder den Rekord seines Vorgängers als eigenen angezeigt. `besteAlle()`
zieht so eine alte Zahl **einmalig** auf den zuletzt hier benutzten Namen um und schreibt das
fest; bloß beim Lesen umzudeuten reichte nicht, weil dieser Name sich ändert und die Zahl
sonst von Spieler zu Spieler wanderte. Ist noch kein Name bekannt, bleibt sie unangetastet
liegen statt verworfen zu werden.

**Das letzte Leben beendet die Partie nicht sofort.** Sonst verschwände genau die Karte
ungesehen, an der man gescheitert ist. Stattdessen setzt `auswerten()` nur `soloAus`, die
Auflösung bleibt stehen, und erst „Ergebnis ansehen" schaltet in `naechsteKarte()` auf `over`.
**Gewertet wird trotzdem sofort** (Bestwert und `partien`-Zeile fallen weiterhin in
`auswerten()` bzw. `nachAuswertung()`) — wer den Tab an dieser Stelle zumacht, verliert
seinen Lauf nicht.

### Noch nicht umgesetzt

Die **Chips** aus der gedruckten Anleitung: Wer dran ist, kann zusätzlich zum Jahr ein Merkmal
nennen (Land / Titel + Interpret / Titel + Interpret + Platzierung) und sich dafür einen Chip
verdienen.

---

## Architektur von `duell.html`

Eine einzelne Datei: HTML, CSS und ein `<script type="module">`. Kein Build-Schritt, kein
Paketmanager. Bearbeiten heißt: die Datei ändern und hochladen.

### Bildschirme und Phasen

Fünf `.screen`-Elemente, jeweils `position:fixed`, umgeschaltet über `show(id)`:
`homeScreen`, `lobbyScreen`, `gameScreen`, `overScreen`, `statsScreen`.

Der Spielzustand kennt sechs Phasen:

```
lobby → draw → turn → [veto] → result → draw → …  → over
```

* `draw` — Spieler am Zug tippt „Karte ziehen"
* `turn` — Song läuft, Lücke wählen, „Karte einloggen"
* `veto` — 15-Sekunden-Fenster (entfällt, wenn niemand Vetos übrig hat oder im Solo)
* `result` — Karte aufgedeckt, Auswertung sichtbar
* `over` — Sieg, leeres Deck oder Abbruch

### Der Spielzustand

**Eine Zeile in `games` je Partie**, der komplette Zustand als JSONB. Für vier Spieler ist das
deutlich einfacher zu handhaben als normalisierte Tabellen, und Realtime schickt bei jeder
Änderung ohnehin die ganze Zeile.

```js
{
  phase, ziel, turn,                  // 'p1'…'p4'
  seats:     { p1:{name}, p2:…, p3:null, p4:null },
  raus:      { p3:true },             // ausgestiegene Spieler
  timelines: { p1:[songId,…], … },    // immer nach Jahr sortiert
  vetos:     { p1:3, … },
  deck:      [songId,…],              // gemischt, es wird vom Ende gezogen
  current:   songId,                  // gezogene Karte
  pending:   { seat, index },         // eingeloggt, noch nicht ausgewertet
  vetoBis:   1785412863168,           // Serverzeit in ms, 0 = kein Countdown
  vetoAngemeldet: 'p4',               // wer den Wettlauf gewonnen hat
  audio:     { playing, startedAt, seek },
  result:    { seat, id, index, correct, klau },
  hinweis:   'Jenny hat das Spiel verlassen',
  winner, verlassen, solo, fehler, maxFehler,
  soloAus                             // Solo entschieden, Auflösung noch sichtbar
}
```

**Sitzplätze:** Feste Liste `SITZE = ['p1','p2','p3','p4']`. Nie `p1`/`p2` fest verdrahten —
dafür gibt es `aktive(st)`, `mitspieler(st, ausser)`, `naechster(st, von)`, `freierSitz(st)`.

### Schreiben: optimistisches Sperren

Jede Zustandsänderung läuft über `commit(mutator)`:

```js
await commit(s => { s.phase = 'turn'; return s; });   // null = Änderung verwerfen
```

Geschrieben wird mit `.eq('version', G.version)`. Trifft das null Zeilen, hat jemand anders
zuerst geschrieben — dann wird neu geladen und der Mutator erneut angewandt (bis zu fünfmal).

**Daraus folgt: Mutatoren müssen wiederholbar sein.** Keine Nebenwirkungen hineinschreiben, die
nicht doppelt passieren dürfen. Die einzige Ausnahme ist der Solo-Bestwert, und der ist
kommentiert.

Der Wettlauf ums Veto funktioniert genau darüber: Beide schreiben `vetoAngemeldet`, einer
gewinnt, beim anderen findet der Mutator die Phase schon verändert vor und gibt `null` zurück.

### Realtime

`postgres_changes` auf `games`, gefiltert nach `code`. Dazu **alle 4 Sekunden ein Poll als
Rückfall** — Realtime reißt bei Netzwechsel (WLAN → mobil) still ab.

### Audio-Synchronisation

Der Ton wird **nicht gestreamt**. Alle laden dieselbe iTunes-Vorschau und springen an dieselbe
Stelle. Im Zustand steht nur `{ playing, startedAt, seek }`.

Die Geräteuhren gehen unterschiedlich, deshalb misst jeder Client beim Start seinen Versatz zur
Serveruhr (`server_now()`-RPC, drei Messungen, beste Laufzeit gewinnt) und rechnet mit
`serverNow()`.

Beim Autostart liegt `startedAt` **900 ms in der Zukunft** (`VORLAUF_MS`), damit alle Geräte
die Datei geladen haben, bevor Sekunde 0 fällt. Zusätzlich wird die **nächste Karte vorgeladen**,
während noch aufgelöst wird — beide kennen die Deck-Reihenfolge.

Wichtige Entwurfsentscheidung: Wer beim Kartenstart weniger als `ANLAUF_KULANZ` (3 s)
hinterherhinkt, hört sie **trotzdem von vorn**. Die Spieler sitzen nicht im selben Raum, ein
Versatz von ein, zwei Sekunden ist unhörbar — ein fehlender Songanfang fällt sofort auf.

Jede Audio-Anweisung wird **genau einmal** umgesetzt (`audioAnweisung` als Signatur). Ein
fortlaufender Abgleich auf die Sollposition würde den Start von vorn sofort wegkorrigieren.

**Der Ton läuft durch die Veto-Phase weiter.** Wer über ein Veto nachdenkt, muss den Song
dabei noch hören — sonst entscheidet er aus der Erinnerung. `einloggen()` fasst `audio`
deshalb nicht an; angehalten wird erst in `auswerten()`. Weil die Signatur dadurch über den
Phasenwechsel hinweg gleich bleibt, spielt die Datei ohne Sprung weiter, statt neu zu starten.
Der Player selbst ist in dieser Phase ausgeblendet, die Bühne gehört dem Countdown —
`audible` in `renderGame()` muss die Phase trotzdem einschließen, sonst räumt `stopAudio()`
das `<audio>`-Element ab.

**`weiterspielen()` im 250-ms-Takt ist die Absicherung dafür.** Safari auf dem iPhone hält die
Wiedergabe gelegentlich von sich aus an; am Rechner tritt das nicht auf. Weil in der Veto-Phase
sonst nichts mehr das Element anfasst — der Zustand ändert sich ja nicht —, käme der Ton ohne
diese Prüfung nie zurück. Die Funktion nimmt die Wiedergabe nur wieder auf und **fasst
`currentTime` nicht an**: Zurückspringen wäre genau der fortlaufende Abgleich, den
`audioAnweisung` verhindern soll. Sie greift ausschließlich in `turn` und `veto`, nie während
Vorlauf oder nach dem Durchlaufen.

### Kartenoptik

Die gedruckten Karten sind ausgemessen und in CSS nachgebaut:

* **25 Farbverläufe**, aus allen 336 Druckkarten ermittelt, teils in beide Richtungen verwendet.
  Die Zuordnung ist **deterministisch aus der Song-ID** (FNV-1a-Hash), nicht zufällig — sonst
  hätte dieselbe Karte in der Zeitleiste eine andere Farbe als in der Auflösung, und auf zwei
  Geräten verschiedene.
* **Ziffernhöhe 21,5 % der Kartenhöhe** (über 10 Karten gemessen, absolut stabil). Umgesetzt mit
  Container-Queries (`cqw`), damit die Typografie an der Karte hängt und nicht am Viewport.
* Die Breite streut in DM Sans stärker als in der Druckschrift; der Mittelwert von 64,2 % wird
  mit `letter-spacing:-.045em` getroffen. Ein exakter Treffer bräuchte die Originalschrift.
* **Der Playbutton ist die Kartenrückseite.** Er hat Form, Größe und Eckenradius der
  aufgedeckten Karte — beim Auflösen wird die Karte umgedreht, nicht ausgetauscht. Auf der
  gedruckten Rückseite sitzt der QR-Code auf schwarzem Grund, umringt von acht dünnen Ringen
  im Verlauf; hier steht der Knopf an seiner Stelle. Am Druckmotiv ausgemessen (480 px):
  Ringe bei r=136…198, Abstand 8,8 px, Strich 4,3 px, Verlauf diagonal von `#30B7FE` oben links
  über Violett nach `#FC2786` unten rechts. Auf dem Schirm läuft das Band weiter nach außen
  (r=48…90 bei 100 als halber Kartenbreite) und **Strich wie Abstand sind etwa doppelt so
  groß** wie im Druckverhältnis — maßstabsgetreu wirken die Rillen am Bildschirm wie ein feines
  Raster statt wie Rillen. Die Statuszeile steht **unter** der Karte, nicht darauf – auf hellem Grund
  also wieder schwarz. Ihr Platz ist die Zeile der Auflösung: die ist leer, solange der Player
  zu sehen ist, und der Player verschwindet, sobald sie gefüllt wird. Eine Restzeit wird nicht
  angezeigt; wie weit der Song ist, sagt der Ring.
* **Der Fortschritt ist der Rahmen des Knopfes**, nicht mehr ein Balken darunter. Der Knopf
  selbst ist schwarz wie die Karte — sichtbar sind nur das Zeichen und der Bogen, der sich
  füllt. Ungefüllt bleibt der Rahmen schwarz, deshalb liegt bewusst **keine Spur** darunter.
  Der Ring sitzt bei r=42 im 200er-Viewport und trifft damit genau die Knopfkante (42 % der
  Karte); wer eines von beiden ändert, muss das andere mitziehen. Strichstärke und Abstand
  zum innersten Deko-Ring sind dieselben wie zwischen den Ringen untereinander (3 und 6), der
  Bogen sitzt also im Raster statt daneben.
* **Der Fortschrittsring benutzt einen zurückgedrehten Verlauf** (`#ringGradFest`). Ein Verlauf
  mit `gradientUnits="userSpaceOnUse"` rechnet im Koordinatensystem des nutzenden Elements —
  das `rotate(-90)`, mit dem der Ring bei zwölf Uhr beginnt, dreht ihn also mit. Seine Farben
  standen dadurch um 90° versetzt zu den Ringen daneben (gemessen: oben Magenta statt
  Blauviolett). `gradientTransform="rotate(90 …)"` hebt das auf, und der Bogen blendet sich in
  den Ringkranz ein, statt sich davon abzusetzen.
* **Einsortiert wird durch Antippen oder Ziehen.** Die gewählte Lücke wird so breit wie eine
  Karte und zeigt die Rückseite in klein — die Karte liegt dann sichtbar dort, wo sie landen
  soll. Gezogen wird über Zeigerereignisse, nicht über HTML5-Drag-and-Drop: das greift auf dem
  Handy zuverlässig und mit Maus genauso. Erst ab `ZIEH_SCHWELLE` (6 px) Bewegung wird aus dem
  Antippen ein Zug, sonst wäre jeder Tipp auf den Playbutton einer; der Klick nach dem
  Loslassen wird über einen Zeitstempel abgefangen. Abgelegt wird auf der **nächstgelegenen**
  Lücke, nicht auf der genau unter dem Zeiger — 30 px breite Ziele trifft man im Ziehen kaum.
  Das Ziehbild schwebt über dem Zeiger, sonst läge der Finger auf der Lücke. Die abgelegte
  Karte lässt sich vor dem Einloggen wieder herausziehen und woanders einschieben; Quelle des
  Zugs ist dann sie statt des Players (`ziehQuelle()`).
* **Herzflaggen** in `flags/`, Dateiname aus dem deutschen Ländernamen abgeleitet
  (`flagSlug()` in `duell.html` **muss identisch zu `slug()` in `build_flags.py` bleiben**).
  Fehlt eine Datei, springt per `onerror` das Emoji ein.

### Statistik

Zwei Tabellen, beide werden **nie aufgeräumt**:

* `partien` — eine Zeile je beendetes Spiel → Solo-Bestenliste und Gewinnbilanz
* `tipps` — eine Zeile je Einsortierung → Trefferquote nach Jahrzehnt und Land

Jahr und Land werden in `tipps` **mitgeschrieben** statt nur die Song-ID: so bleibt die
Statistik gültig, wenn `songs.json` später korrigiert wird.

Ausgewertet wird **immer in SQL-Funktionen**, nie im Client: Die App holt fertige Summen statt
tausender Zeilen. Alle sind `STABLE`, `SECURITY INVOKER` (die RLS-Regeln greifen also weiter)
und für `anon` nur ausführbar, nicht mehr.

| Funktion | Liefert | Datei |
|---|---|---|
| `bestenliste(p_limit, p_seit)` | einzelne Solo-Partien, beste zuerst | Migration |
| `duellbilanz(p_seit)` | Spiele und Siege je Person | Migration |
| `quote_jahrzehnt(p_name, p_seit)` | Trefferquote je Jahrzehnt | Migration |
| `quote_land(p_name, p_seit)` | Trefferquote je Land | Migration |
| `schwerste_karten(p_seit, p_min, p_limit)` | Karten mit der schlechtesten Quote, über alle | Statistik-2 |
| `angstgegner(p_name, p_seit, p_limit)` | Karten, die *dir* mehrfach danebengingen | Statistik-2 |
| `aktivitaet(p_name, p_seit)` | Partien je Kalendertag | Statistik-2 † |
| `duellmatrix(p_seit)` | Paarungen und ihr Siegstand | Statistik-2 |
| `quote_position(p_name, p_seit)` | Quote nach Anfang / Mitte / Ende der Leiste | Statistik-2 † |
| `serien(p_name, p_seit, p_limit)` | längste Folge richtiger Tipps je Person | Statistik-2 † |
| `klaubilanz(p_seit)` | erbeutete und verlorene Karten je Person | Statistik-2 |
| `partie_rueckblick(p_partie_id, p_name)` | Quote, beste Serie und härteste Karte einer Partie | Statistik-2 |
| `anzeigename(p_key)` | Hilfsfunktion: zuletzt benutzte Schreibweise | Statistik-2 |

† **Wird von der Statistikseite nicht mehr aufgerufen.** Die drei Kästen sind wieder
entfernt worden: „Aktivität" hat nur Betrieb angezeigt, nicht Können, „Längste Serie"
steht schon im Solospiel, und „Nach Lückenposition" sagt mehr über die Länge der Leiste
als über den Spieler. Die Funktionen bleiben in der Datenbank — ein `DROP` wäre eine
weitere Migration, und `partie_rueckblick` rechnet die beste Serie einer Partie ohnehin
selbst (für den Rückblick auf dem Endbildschirm, der bleibt).

Ein paar Entscheidungen, die man den Signaturen nicht ansieht:

* **`p_seit` (timestamptz, NULL = alles)** haben alle. Die vier alten mussten dafür abgelegt
  und neu angelegt werden — ein Parameter mehr ist eine andere Signatur, `CREATE OR REPLACE`
  hätte eine zweite Fassung danebengestellt und den Aufruf mehrdeutig gemacht.
* **`serien` gibt eine Zeile je Person aus**, ihre beste. Sonst belegte eine einzige starke
  Partie die ganze Liste — so, wie es die Bestenliste bis heute tut.
* **`klaubilanz` leitet das Opfer ab.** In der Veto-Zeile steht nur der Täter. Angesetzt wird
  deshalb an `art='veto' AND geklaut`, und über dieselbe `partie_id` + `song_id` wird die Zeile
  mit `art='normal' AND korrekt=false` dazugesucht. Nur an `art='normal' AND korrekt=false`
  anzusetzen wäre falsch: Das trifft auch jede Runde, in der ein Veto *scheiterte* — dort hat
  niemand etwas verloren.
* **`duellmatrix` paart über `partie_id`**, nicht über die Textspalte `gegner`. In der stehen
  alle Mitspieler zusammengeklebt, daraus lässt sich keine Paarung zurückgewinnen.
* **`partie_rueckblick` beantwortet alles in einer Abfrage.** Der Endbildschirm soll nicht auf
  vier Umläufe warten. Die härteste Karte wird über den *gesamten* Bestand bestimmt, nicht nur
  über die Mitspieler dieser Runde — im Solo wären das die eigenen ein bis zwei Versuche, also
  0 % oder 100 % und damit nichtssagend.

#### Zeitzone

Tagesgrenzen liegen in **Europe/Zurich**, nicht in UTC — sonst kippte eine Partie um 23:30 auf
den Folgetag. Der Client rechnet dieselbe Zone, sonst zählte „Dieser Monat" ein bis zwei Stunden
des Vormonats mit: `ZONE` in `duell.html` und die Zeichenkette in `supabase-statistik-2.sql`
gehören zusammen. Wer eine neue Auswertung nach Tagen oder Monaten baut, muss beide anfassen.
(Im SQL steht die Zone derzeit nur noch in `aktivitaet` und `serien` — beide werden von der
Seite nicht mehr aufgerufen; im Client zählt sie weiter, `monatsbeginn()` hängt daran.)

`monatsbeginn()` nähert sich dem Monatsersten in **zwei Durchgängen** an: erst so tun, als wäre
Zürich UTC, dann den tatsächlichen Versatz abziehen. Ein Durchgang reicht nicht — am 30. März
gilt „heute" schon die Sommerzeit, der Monatserste aber noch nicht. Geprüft gegen neun Stichtage
über beide Umstellungen hinweg.

#### Die Statistikseite

Zwei Umschalter: `statSicht` (ich / alle → `p_name`) und `statZeit` (Monat / alles → `p_seit`).
`statBloecke()` ist die **einzige** Stelle, an der ein Kasten angemeldet wird — id, Aufruf,
Zeichenfunktion, Leertext.

**Zwei Zurück-Knöpfe, ein Weg.** Der am Fuß (`btnStatsBack`) und der oben (`btnStatsOben`)
hängen an derselben Funktion — die Seite ist lang, und nach dem Scrollen ist der Fuß weit weg.
Der obere ist `position:sticky`, nicht `absolute` wie `.raus` und `.hilfe` auf den anderen
Bildschirmen: hier ist der Bildschirm selbst der scrollende Kasten (`overflow-y:auto`), ein
absolut gesetzter Knopf würde beim Scrollen nach oben aus dem Bild wandern. Weil er im
geklebten Zustand über den Kästen liegt, hat er eine eigene Fläche — sonst liefe der Text
darunter durch.

Geholt wird mit `Promise.allSettled`, und **jeder Kasten zeichnet für sich**, sobald seine
Antwort da ist. Mit einem `Promise.all` über acht Aufrufe würde der langsamste zum
Taktgeber für alle, und ein einziger Fehlschlag ließe die ganze Seite auf „lädt…" stehen.
`statLauf` zählt dabei mit: Antworten aus einer älteren Einstellung werden verworfen, sonst
könnte man sich beim schnellen Umschalten gemischte Zahlen zusammenklicken.

Songtitel kommen **aus `songs.json`**, nicht aus der Datenbank — die RPCs geben nur `song_id`
zurück, damit die Statistik gültig bleibt, wenn Songdaten später korrigiert werden. Fehlt eine
ID dort, wird sie selbst angezeigt (`Song 999`), es stürzt nichts ab.

Der **Rückblick auf dem Endbildschirm** wird nachgeladen und eingeblendet; der Bildschirm selbst
erscheint sofort wie bisher. Ohne Verbindung, bei einem Fehler oder für eine Partie von vor der
Umstellung fällt der Kasten ersatzlos weg — auf dem Siegesbildschirm hat keine Fehlermeldung
etwas verloren. Seine `partie_id` kommt aus dem Spielzustand, nicht aus einer Modulvariablen,
damit er auch nach einem Neuladen noch funktioniert. Und weil die Tipp-Zeilen nebenher
geschrieben werden und bei Spielende noch unterwegs sein können, fragt er bei leerem Ergebnis
**ein zweites Mal** nach, statt „0/0" hinzuschreiben.

**Das Protokollieren hängt am Spielzustand, nicht am Gerät.** Bei einem Veto schreibt der
Gegner die Auswertung, protokolliert dabei aber den Tipp des Spielers am Zug. Läuft es über
`myName()`, landet er beim Falschen.

**Und zwar an dem Zustand, den der eigene `commit()` geschrieben hat** — nicht an `G.state`.
`nachAuswertung()`, `partieMerken()` und `tippMerken()` bekommen ihn übergeben. Warum, steht
unter [Fallstricke](#fallstricke); kurz: zwischen Schreiben und Protokollieren liegt ein
`await`, und was danach in `G.state` steht, muss nicht mehr dieselbe Runde sein.

#### Namen

Namen sind Freitext, und die Datenbank vergleicht buchstäblich — „Jenny", „jenny" und
„Jenny " wären drei Spielerinnen mit drei getrennten Quoten. Beide Tabellen haben deshalb
eine erzeugte Spalte `name_key` (`lower(btrim(name))`, `GENERATED ALWAYS ... STORED`), über
die alle vier Auswertungen gruppieren und filtern. `name` bleibt die Anzeigeform; gezeigt
wird die **zuletzt benutzte** Schreibweise, nicht irgendeine.

Der Client muss dieselbe Normalisierung fahren (`normName()`), sonst erkennt die
Statistikseite die eigene Zeile nicht wieder: Die Auswertung liefert ja womöglich eine andere
Schreibweise zurück als die, unter der gerade gespielt wird.

#### Weitere Spalten

| Spalte | Tabelle | Inhalt |
|---|---|---|
| `partie_id` | beide | Eine Kennung je Partie, im Spielzustand abgelegt. Alle Geräte schreiben dieselbe — darüber hängen `partien` und `tipps` zusammen. |
| `lauf_id` | `partien` | Eine Kennung je Partie **und Gerät**, im `localStorage`. Hält fest, welches Gerät die Zeile geschrieben hat. |
| `dauer_s` | `partien` | Sekunden vom Spielstart bis zur letzten Auswertung. Der Startzeitpunkt steht im Zustand, nicht auf dem Gerät — sonst stimmte er nach einem Wiedereinstieg nicht. |
| `fehler` | `partien` | Verbrauchte Leben im Solo. Im Duell `null`, dort gibt es keine. |
| `art` | `tipps` | `'normal'` oder `'veto'`. |
| `geklaut` | `tipps` | Ob die Karte bei dieser Auflösung den Besitzer gewechselt hat. Steht bei **beiden** Zeilen derselben Karte gleich drin; welche Seite man war, sagt `art`. So lässt sich erbeutet und verloren getrennt zählen. |
| `pos`, `leiste_laenge` | `tipps` | Gewählte Lücke und Länge der Leiste **vor** dem Einsortieren. Ohne die beiden ist „richtig" nicht vergleichbar: eine Lücke von drei zu treffen ist etwas anderes als eine von elf. |

`pos` und `leiste_laenge` beziehen sich auf die Leiste, in die **tatsächlich einsortiert
wurde**. Beim Veto ist das die des Spielers am Zug, nicht die des Vetogebers — geprüft wird
dieselbe Aufgabe, an der jener gescheitert ist. `auswerten()` hält die Länge fest, bevor
gesplict wird, und legt sie als `result.leiste` in den Zustand.

#### Entdopplung

Zwei eindeutige Indizes auf `partien` fangen doppelte Zeilen ab, beide über `name_key`:

* **`(partie_id, name_key)`** ist der tragende. Er deckt das Neuladen ab (die `partie_id`
  übersteht es, im Solo über den `localStorage`, im Duell über den Server) **und** den Fall,
  dass im Duell beide Geräte schreiben.
* **`(lauf_id, name_key)`** ist der engere und deckt nur das Neuladen ab.

Bewusst **nicht** über `lauf_id` allein: Im Duell schreibt ein Gerät die Zeilen aller
Mitspieler in *einem* `insert`, alle mit derselben `lauf_id`. Ein Index darauf allein wiese
den ganzen `insert` zurück, und die Duellstatistik fiele ersatzlos aus.

Der Client fängt den Fehlercode `23505` deshalb ab, ohne zu warnen — er ist der Normalfall,
nicht die Störung. Alte Zeilen haben überall `NULL`, und `NULL`s gelten als voneinander
verschieden; der Altbestand bleibt unberührt.

#### Nachreichen

Schlägt der `partien`-Insert fehl, landet die Partie in `duell1408nachtrag` und geht beim
nächsten Start noch einmal raus (`nachtragSenden()`, bis zu `NACH_MAX` Versuche, höchstens
zehn Einträge). Vorher war so ein Ergebnis schlicht verloren: Der Bestwert stand auf dem
Gerät, die Zeile fehlte in der Datenbank, und gesagt hat das niemand — genau das erklärt
einen Bestwert, der in der Bestenliste nicht auftaucht. Solange etwas aussteht, sagt der
Startbildschirm es jetzt.

**Gefahrlos ist das Nachreichen nur wegen der Entdopplung.** Die Zeilen bringen ihre
`partie_id` mit; eine Partie, die doch angekommen war, weist der eindeutige Index mit `23505`
ab, und dieser Fehler zählt hier als Erfolg. Ohne die Indizes würde jeder Nachtrag einen
Doppeleintrag erzeugen — wer sie je entfernt, muss das Nachreichen mit entfernen.

---

## Supabase

SQL wird von Hand im SQL-Editor ausgeführt, je Datei einmal. „Success. No rows returned" ist
die richtige Erfolgsmeldung. Reihenfolge:

1. `supabase-schema.sql` und `supabase-statistik.sql` — die Tabellen. **Fehlen im Repo**, siehe
   [Repo-Inhalt](#repo-inhalt).
2. `supabase-migration-namen.sql` — Spalten, `name_key`, Entdopplung.
3. `supabase-statistik-2.sql` — der zweite Satz Auswertungen. Setzt Schritt 2 voraus und legt
   dabei auch die vier alten Funktionen mit `p_seit` neu an.

Beide neuen Dateien sind wiederholbar: nochmal ausführen ändert nichts mehr und lässt
bestehende Zeilen unangetastet. Wer eine Datei erweitert, muss sie **erneut ganz** einspielen —
ein nachträglich angehängter Abschnitt ist sonst nirgends angekommen, und die Prüfabfrage zeigt
dann völlig zu Recht noch den alten Stand.

| Tabelle | Inhalt | RLS für `anon` |
|---|---|---|
| `games` | laufende Partien, Zustand als JSONB | select, insert, update — **kein delete** |
| `partien` | beendete Spiele | select, insert |
| `tipps` | einzelne Einsortierungen | select, insert |

`purge_old_games()` löscht Partien älter als 7 Tage; die Statistiktabellen bleiben unberührt.

**Vertrauensmodell:** Der Client kennt die Wahrheit. `songs.json` ist öffentlich, jeder Spieler
kann das Jahr der aktuellen Karte nachschlagen. Für ein Spiel unter Freunden ist das in Ordnung;
serverseitig prüfen hieße, die Auswertung in eine Edge Function zu verlagern. Der Zustand ist so
gebaut, dass das nachrüstbar wäre, ohne den Client umzuschreiben.

Der `sb_publishable_`-Key in `duell-config.js` gehört ins Repo — er steckt ohnehin im
ausgelieferten JavaScript. Geschützt wird durch die RLS-Regeln, nicht durch Geheimhaltung. Der
`secret`/`service_role`-Key darf **nie** dorthin.

---

## Lokal entwickeln

**Nicht per Doppelklick öffnen.** Über `file://` scheitern `fetch('songs.json')` und einiges
mehr. Stattdessen:

```bash
cd Website && python3 -m http.server 8000
```

Dann <http://localhost:8000/duell.html>. Es gibt keinen Build-Schritt.

Zum Testen zu zweit: ein normales und ein privates Fenster — zwei normale Tabs teilen sich den
`localStorage` (`duell1408`, `duell1408solo`, `duell1408best`, `duell1408lauf`) und
überschreiben sich gegenseitig die Sitzung.

---

## Fallstricke

Alles hier ist mindestens einmal schiefgegangen.

**Keine statischen Modul-Importe.** Die Bibliothek kam früher per
`import … from 'https://esm.sh/…'`. Diese Einstiegsdatei zieht sechs weitere nach; schlägt eine
fehl, wird das **gesamte Modul nie ausgeführt** — kein Knopf reagiert, keine Fehlermeldung, das
Namensfeld funktioniert weiter, weil es reines HTML ist. Genau so sah der Fehler aus, und er
trat sporadisch auf. Deshalb liegt `supabase.js` jetzt als klassisches Skript im Repo. **Keine
neuen `import`-Anweisungen ins Modul aufnehmen.**

**`Logo.svg` ist kein Vektor.** Es ist ein PNG in einer SVG-Hülle, mit `width="164"` als
Eigengröße und einem Filter, der die Rasterung auf diese Größe festnagelt. Über `<img>` wird es
dadurch unscharf hochskaliert. `duell.html` benutzt deshalb `Logo.png` (513×222). `index.html`
bettet dasselbe SVG **inline** ein — dort skaliert der Filterbereich mit und es ist scharf. Kein
echter Vektor liegt im Projekt, auch die PDFs enthalten nur Bilder.

**`height:100dvh`, nicht `inset:0`.** Auf dem iPhone misst `position:fixed; inset:0` die *große*
Viewport-Höhe; Safaris untere Leiste verdeckt dann den letzten Knopf.

**Vorschauen sind 90 Sekunden**, nicht 30. Nie fest annehmen, immer `aud.duration` abwarten.

**`songs.json` ist ein Objekt**, kein Array. `Object.keys()` liefert die IDs.

**Der Spieler am Zug kann aussteigen.** `naechster()` muss dann ab seinem Platz in der
*Grundreihenfolge* weitersuchen — er steht ja nicht mehr in der Aktivenliste, `indexOf` liefert
−1 und der Zug fiele auf den ersten Spieler zurück statt an den Nachbarn zu gehen.

**Werkzeug-Latenz beim Testen.** Zwischen zwei Aufrufen eines Automatisierungswerkzeugs können
über 10 Sekunden vergehen. Das 15-Sekunden-Veto-Fenster läuft dabei ab. Für interaktive Tests
`vetoBis` künstlich weit setzen.

**Kein `setPointerCapture` beim Ziehen.** Ein eingefangener Zeiger leitet auch den darauf
folgenden `click` auf das fangende Element um. Weil beim `pointerdown` unbedingt gefangen wurde,
landete der Klick immer am `playerBox` statt am `#pbtn` — der Ton ließ sich nicht mehr anhalten,
obwohl der Knopf normal aussah und `elementFromPoint` ihn korrekt lieferte. Die Zeiger-Ereignisse
laufen deshalb über `window`; auch ohne Fangen erreichen sie uns dort. Ein Test, der den Klick
selbst auf den Knopf schickt, übergeht die Umleitung und findet den Fehler **nicht**.

**`.krueck` braucht `display:block`.** Die Mini-Kartenrückseite ist ein `span`. In der Lücke
ist sie Flex-Kind und wird dadurch blockartig, im Ziehbild hängt sie in einem normalen `div` —
dort greifen `width` und `height` an einem inline-Element nicht, und sie blieb ohne Fläche.
Sichtbarer Fehler: das Ziehbild fehlt, obwohl `.zieher` im DOM steht.

**Das Ring-SVG braucht `pointer-events:none`.** Es liegt als absolut positioniertes Element
über dem Playbutton und paint daher darüber — und fängt ohne diese Regel auch jeden Klick ab.
Der Ton startete dann zwar automatisch, ließ sich aber weder anhalten noch nach dem Durchlauf
erneut abspielen; der Knopf sah dabei völlig normal aus. Nachweisbar über
`document.elementFromPoint()` in der Knopfmitte: liefert es `<svg class="ringe">` statt des
Knopfes, ist genau das der Fehler.

**Rollbalken: entweder `scrollbar-width` oder `::-webkit-scrollbar`, nicht beides.** Die
Zeitleiste zeigt ihren Rollbalken absichtlich dauerhaft — sonst sieht man am Rechner nicht,
dass sie seitlich weitergeht. Sobald aber `scrollbar-width` oder `scrollbar-color` gesetzt ist,
ignoriert Chrome die `::-webkit-scrollbar`-Regeln und zeichnet wieder einen überlagernden
Balken, der im Ruhezustand unsichtbar ist. Messbar an `offsetHeight − clientHeight`: mit den
Pseudoelementen allein 6 px, mit `scrollbar-width` daneben 0 px. Für Firefox steht der andere
Weg deshalb in einem `@supports not selector(::-webkit-scrollbar)`-Block.

**Erst die Migration, dann die Seite.** SQL läuft nicht über GitHub — GitHub Pages liefert nur
statische Dateien aus, eine `.sql` im Repo ist dort totes Papier. Sie muss von Hand in den
Supabase-SQL-Editor. Die Reihenfolge ist deshalb: **erst alles SQL einspielen, dann
`duell.html` hochladen.** Andersherum schickt der Client Spalten und ruft Funktionen, die es
noch nicht gibt; PostgREST lehnt den `insert` ab, und weil er absichtlich ins Leere läuft, sieht
man davon nur eine Zeile in der Entwicklerkonsole. Das Spiel läuft weiter, die Statistik fehlt
still. Die Statistikseite ist gnädiger — sie sagt je Kasten „Auswertung fehlt noch".

**Auswertungen über `partie_id`, `pos` oder `art` beginnen erst am Migrationstag.** Der
Altbestand hat diese Spalten durchgehend `NULL` — beim Einspielen waren das 187 Tipps und 14
Partien, davon *keine einzige* mit `partie_id`. Betroffen sind `duellmatrix`, `quote_position`,
`serien`, `klaubilanz` und `partie_rueckblick`: Sie liefern leere Ergebnisse, bis mit der neuen
`duell.html` gespielt wurde. Das ist kein Fehler, und die Kästen sagen es auch — sie
unterscheiden zwei Leerfälle („noch keine Daten" gegen „wird erst seit der Umstellung
erfasst"). Wer eine neue Auswertung baut, muss diese Zeilen sauber ausschließen **und** dem
Nutzer sagen, warum erst ab einem Datum gezählt wird. Eine leere Tabelle ohne Erklärung sieht
aus wie ein Defekt.

`schwerste_karten`, `angstgegner`, `aktivitaet` und die vier alten Funktionen rechnen dagegen
auf dem gesamten Bestand und zeigen sofort etwas.

**Nach dem `await` ist der Zustand nicht mehr derselbe.** `commit()` gibt deshalb den
geschriebenen Zustand zurück und nicht bloß `true`. Wer stattdessen hinterher `G.state` liest,
protokolliert womöglich eine Auflösung, die es nicht mehr gibt: Zwischen dem eigenen Schreiben
und dem Auflösen des Versprechens kann ein anderes Gerät die Partie längst weitergedreht
haben, und `nachAuswertung()` findet dann `result: null` vor. Messbar mit einem Prüfstand, der
schneller weiterklickt als ein Mensch: **sieben Vetorunden, eine einzige Tipp-Zeile.** Nach der
Umstellung dieselben sieben Runden, dreizehn Zeilen. Im Spiel zu zweit tritt das selten auf –
nötig wäre, dass der Gegner innerhalb eines Netzumlaufs weiterklickt –, aber es fällt nie auf:
Es gibt keine Fehlermeldung, nur eine Lücke in den Daten. Alle Aufrufer prüfen weiterhin bloß
auf wahr/falsch, ein Zustandsobjekt ist immer wahr.

**Alle Phasen prüfen, nicht nur eine.** Ein Layout-Fehler war nur in `draw` und `turn` sichtbar,
weil die Bühne dort leer ist (Player und Balken sind absolut positioniert) und eine
`auto`-Rasterspalte deshalb auf Breite null zusammenfiel. In `result` sah alles gut aus.

---

## Offene Punkte

* **`manifest.json` ist kaputt:** `start_url` und `scope` zeigen auf `/esc-hitster/`, die Seite
  liegt aber unter `/project-1408/`. „Zum Home-Bildschirm hinzufügen" landet auf einer 404.
  Außerdem ist `theme_color` dunkel (`#08080F`), während die Seiten hell sind.
* **Chips** aus der gedruckten Anleitung sind nicht umgesetzt.
* **Lobby-Abbruch:** Steigt jemand aus, *bevor* gestartet wurde, warten die anderen weiter.
  Nach dem Start wird der Ausstieg sauber behandelt.
* **Die Bestenliste listet Partien, nicht Spieler.** Eine Person kann sie mehrfach belegen —
  Jenny steht mit vier von zehn Plätzen darin. Das ist so gewachsen, nicht entschieden.
* **Der Solo-Bestwert bleibt je Gerät getrennt.** Er hängt jetzt am Namen, aber im
  `localStorage` — wer auf Handy und Rechner spielt, hat zwei davon. Die Datenbank kennt den
  wahren Höchstwert; der Startbildschirm fragt sie nicht, weil Solo ausdrücklich auch ohne
  Verbindung laufen soll.
