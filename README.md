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

supabase-schema.sql     Tabelle `games` — muss einmalig eingespielt werden
supabase-statistik.sql  Tabellen `partien` + `tipps` — einmalig einspielen
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
* **Herzflaggen** in `flags/`, Dateiname aus dem deutschen Ländernamen abgeleitet
  (`flagSlug()` in `duell.html` **muss identisch zu `slug()` in `build_flags.py` bleiben**).
  Fehlt eine Datei, springt per `onerror` das Emoji ein.

### Statistik

Zwei Tabellen, beide werden **nie aufgeräumt**:

* `partien` — eine Zeile je beendetes Spiel → Solo-Bestenliste und Gewinnbilanz
* `tipps` — eine Zeile je Einsortierung → Trefferquote nach Jahrzehnt und Land

Jahr und Land werden in `tipps` **mitgeschrieben** statt nur die Song-ID: so bleibt die
Statistik gültig, wenn `songs.json` später korrigiert wird.

Ausgewertet wird über SQL-Funktionen (`bestenliste`, `duellbilanz`, `quote_jahrzehnt`,
`quote_land`), damit die App fertige Summen holt statt tausende Zeilen.

**Das Protokollieren hängt am Spielzustand, nicht am Gerät.** Bei einem Veto schreibt der
Gegner die Auswertung, protokolliert dabei aber den Tipp des Spielers am Zug. Läuft es über
`myName()`, landet er beim Falschen.

---

## Supabase

Zwei SQL-Dateien, je einmal im SQL-Editor ausführen. „Success. No rows returned" ist die
richtige Erfolgsmeldung.

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
`localStorage` (`duell1408`, `duell1408solo`, `duell1408best`) und überschreiben sich
gegenseitig die Sitzung.

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
* **Veto-Statistik:** Erfolgreiche Klaus werden nicht getrennt erfasst; dafür bräuchte `tipps`
  eine Spalte mehr.
* **Doppelte Solo-Zeile bei Neuladen:** Wer die Seite genau auf der letzten Auflösung neu lädt
  und dann „Ergebnis ansehen" tippt, schreibt eine zweite `partien`-Zeile. `partieProtokolliert`
  ist eine Modulvariable und überlebt das Neuladen nicht. Enges Zeitfenster, unschöne, aber
  harmlose Folge: ein Doppeleintrag in der Bestenliste.
