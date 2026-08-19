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
| **Online-Modus** | `duell.html` | Vollständiges Spiel im Browser, 1–10 Spieler auf getrennten Geräten. Backend: Supabase. |

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
songs.json              336 Songs mit Vorschau-URLs — nur fürs Offlinespiel, unangetastet
songs-online.json       1428 Songs fürs Onlinespiel (enthält die 336)
flags/                  53 Herzflaggen als PNG, 128×128 — eine je Land der Online-Datei
reactions/              25 Katzen als PNG, 320×320, mit gebackenem Aufkleberrand
anleitung.html          Spielanleitung fürs gedruckte Kartenspiel
anleitung-online.html   Spielanleitung für den Online-Modus (Prinzip, Solo vs. Mehrspieler, Veto)
Logo.png / Logo.svg     Bildmarke (Logo.svg NICHT verwenden, siehe Fallstricke)
manifest.json           PWA-Manifest (Pfade sind kaputt, siehe Offene Punkte)
icon-192/512.png, apple-touch-icon.png

supabase-migration-namen.sql  Namensnormalisierung, Verknüpfung, Entdopplung — einmalig
supabase-statistik-2.sql      Zweiter Satz Auswertungen + Zeitfilter — nach der Migration
supabase-tagesduell.sql       Tagesduell: Spalten tag/dauer_ms, Tagessperre, Bestenliste
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

**Zwei Dateien, eine gemeinsame Nummerierung:**

| Datei | Songs | Wer liest sie |
|---|---|---|
| `songs.json` | 336 | `index.html` — das Offlinespiel. Entspricht genau den gedruckten Karten. |
| `songs-online.json` | 1428 | `duell.html` — das Onlinespiel. Enthält die 336 und 1092 weitere. |

`songs.json` bleibt bewusst **unangetastet**: Ihre IDs sind die QR-Codes auf den gedruckten
Karten, dort darf sich nichts verschieben. Wer Songs ergänzen will, ergänzt die Online-Datei.

**Die 336 gemeinsamen IDs bezeichnen in beiden Dateien denselben Song** — geprüft über Jahr,
Interpret, Titel und Land, null Abweichungen. Das ist keine Kosmetik, sondern die Bedingung
dafür, dass die bisherige Statistik gültig bleibt: In `tipps` steht die Song-ID, und
`schwerste_karten` und `angstgegner` geben sie zurück, damit der Client Titel und Interpret in
der Songdatei nachschlägt. Wären IDs neu vergeben worden, zeigte die Statistik zu allen alten
Zeilen die falschen Songs. **Wer die Online-Datei erweitert, muss die bestehenden IDs deshalb
unberührt lassen und nur hinten anhängen.**

Beide sind ein **Objekt**, kein Array — die Schlüssel laufen von `"001"` bis `"336"` bzw.
`"1430"` (ab 1000 vierstellig; `479` und `626` fehlen, siehe unten — 1428 Einträge).

**Auf die Reihenfolge von `Object.keys(SONGS)` ist kein Verlass.** JavaScript ordnet
ganzzahlig aussehende Schlüssel numerisch *vor* alle übrigen, `"1000"` steht also vor `"001"`
(dort bremst die führende Null die Sonderbehandlung). Der Code sortiert deshalb überall selbst
(`Object.keys(SONGS).sort()`), und das ist die lexikografische Ordnung, nicht die numerische:
`"099" < "100" < "1000" < "1430" < "200"`. Deterministisch ist beides, mehr braucht es nicht.

```json
"001": {
  "year": "1956",           // String, nicht Zahl
  "artist": "Lys Assia",
  "title": "Refrain",
  "country": "Schweiz",     // deutscher Name, 44 offline / 53 online
  "flag": "🇨🇭",             // Emoji, dient als Rückfall
  "place": "1",             // Platzierung beim ESC
  "sid": "448456972",       // iTunes-Track-ID
  "u":   "https://music.apple.com/…",
  "pr":  "https://audio-ssl.itunes.apple.com/…"   // Vorschau, direkt abspielbar
}
```

* Jahre **1956–2026**, 71 Jahrgänge, jeder mehrfach belegt — gleiche Jahre sind der Normalfall.
  Online sind es rund 20 Songs je Jahrgang, gleiche Jahre also noch häufiger als offline.
* **Alle Einträge in beiden Dateien haben ein gefülltes `pr`-Feld.** Der iTunes-Lookup in
  `index.html` ist reiner Rückfall und greift praktisch nie.
* **`sid` und `u` liest das Onlinespiel nicht** (nur `year`, `artist`, `title`, `country`,
  `flag`, `place`, `pr`). Sie bleiben trotzdem in der Datei: Ohne sie wären es 104 statt 142 KB
  gzip — die 38 KB wiegen den Informationsverlust nicht auf.
* **Vorschauen liegen in zwei Fassungen vor:** `…plus.aac.ep.m4a` ist die verlängerte
  (~90 s), `…plus.aac.p.m4a` die kurze (~30 s). In `songs-online.json` sind 1364 verlängert und
  65 kurz. Wichtig beim Prüfen: Die iTunes-Lookup-API gibt **immer die kurze** zurück. Ein
  Vergleich `pr` gegen `previewUrl` meldet deshalb fast die ganze Datei als „falsch". Verglichen
  werden muss der **Asset-Ordner** (der UUID-Teil des Pfads), nicht der Dateiname.

* **Ein behobener Datenfehler, und wie er gefunden wurde.** Die IDs `379` (Conchita Bautista,
  *Estando contigo*, 1961) und `423` (dieselbe Interpretin, *Qué bueno, qué bueno*, 1965)
  zeigten auf **dieselbe** Vorschau-URL — die einzige Dopplung unter 1430 Einträgen. Welche der
  beiden falsch war, ließ sich am Ton entscheiden: die geteilte Datei (89,9 s) gegen die
  offiziellen 30-Sekunden-Vorschauen beider `sid` gestellt und über die Energie-Hüllkurve in
  20-ms-Fenstern kreuzkorreliert.

  | Vergleich | Korrelation |
  |---|---|
  | 379 *Estando contigo* gegen die geteilte Datei | **0,995** bei Versatz 0,0 s |
  | 423 *Qué bueno, qué bueno* gegen die geteilte Datei | 0,177 |

  Also: `379` war richtig (verlängerte Fassung des eigenen Songs, die kurze ist exakt deren
  Anfang), `423` falsch — dort erklang der Song von 1961, obwohl die Karte auf 1965 gehört.
  `423` hat jetzt seine eigene Vorschau, notwendigerweise die kurze 30-Sekunden-Fassung; eine
  verlängerte gibt die API für diesen Track nicht heraus.

* **Der Ordnervergleich allein reicht nicht — es braucht den Hörtest.** Ein abweichender
  Asset-Ordner kann zwei Dinge heißen: dieselbe Aufnahme aus einer anderen Veröffentlichung
  (harmlos) oder eine fremde Aufnahme (Fehler). Über die Titel lässt sich das **nicht**
  unterscheiden, und diese Verwechslung stand hier lange: Der Titel kommt aus dem `sid` und damit
  aus dem **Link**, nicht aus der Vorschau. Eine vom Nachbartrack gegriffene Datei fällt so
  grundsätzlich nicht auf.

  Entschieden wird es am Ton: Energie-Hüllkurve in 20-ms-Fenstern, normierte Kreuzkorrelation
  gegen die offizielle Vorschau des verlinkten Tracks, bestes Fenster gesucht. ≥ 0,90 heißt
  dieselbe Aufnahme, < 0,60 eine fremde. Von 87 Abweichungen im Bestand:

  | Urteil | Anzahl |
  |---|---|
  | gleiche Aufnahme (≥ 0,90) | 54 |
  | unklar (0,60–0,90) | 8 |
  | fremde Aufnahme (< 0,60) | 25 |

  Für die 25 wurde über den Asset-Ordner bestimmt, **welcher** Titel dort erklingt — alle Titel
  des Interpreten aufzählen und den Ordner vergleichen. Acht davon waren nachweislich ein anderer
  Song desselben Interpreten (`343` *La rue s'allume* statt *Ne crois pas*, `436`
  *Kolmatta Linjaa Takaisin* statt *Varjoon-suojaan*, `1349` *Yerku Mas* statt *Jako* und fünf
  weitere), einer nur eine andere Einspielung desselben Titels (`129`), sechzehn gehörten zu
  keinem Titel des angegebenen Interpreten.

  **Alle 33 Zeilen unter 0,90 tragen jetzt die offizielle Vorschau ihres verlinkten Tracks** —
  damit garantiert der richtige Song, dafür 30 statt 90 Sekunden. Die 54 mit gleicher Aufnahme
  blieben unangetastet: Sie sind richtig *und* lang, ein Tausch wäre nur Verlust. Nachgeprüft ist
  für alle 33, dass die neue Vorschau zum eigenen `sid` gehört und mit HTTP 200 antwortet.

  Die Fehlerquote passt zu der des Werkzeugs: `esc_links.py` löst die verlängerte Vorschau über
  eine Nähe-Heuristik im HTML der Albumseite auf („die `.ep`-URL, die am dichtesten hinter der
  Track-ID steht"), weil der strukturierte Weg über das eingebettete JSON nicht mehr greift. Bei
  einem Lauf über 258 Taylor-Swift-Titel lagen damit 6 daneben (2,3 %), hier mindestens 16 von
  1428 (1,1 %). **Wer das Skript erneut laufen lässt, muss den Hörtest hinterherschicken.**

* **Vier weitere Zeilen, bei denen iTunes eine andere Fassung nennt als die Datei.** Sie fielen
  beim Ordnervergleich auf. Das exakte Werkzeug zur Aufklärung ist nicht die Korrelation, sondern
  **der Asset-Ordner als Kennung**: Alle Titel des Interpreten aufzählen und schauen, zu welchem
  der Ordner gehört. Damit steht fest, was tatsächlich erklingt.

  | ID | Karte | Was tatsächlich erklang | Stand |
  |---|---|---|---|
  | `428` | Madalena Iglésias – *Ele e ela* (1966) | *Quemé Tus Cartas* — anderer Song derselben Interpretin vom selben EP | **behoben**: jetzt *Él y Ella*, die spanische Fassung desselben ESC-Titels. Eine portugiesische gibt es bei iTunes nicht. |
  | `1244` | Gjon's Tears – *Répondez-moi* (2020) | die **Originalfassung**, also richtig — nur `sid` und `u` zeigten auf den Sunlike-Brothers-Remix | **behoben**: `sid`/`u` auf den Track gesetzt, zu dem die Vorschau gehört. Der Ton blieb unverändert. |
  | `830` | Donna & Joseph McCaul – *Love?* (2005) | *Love (Remix)* von 2017 — richtiger Song, falsche Fassung | **nicht behebbar**: Das ESC-Original von 2005 ist in keinem der Stores DE/IE/GB/US vorhanden. |
  | `479` | Marie – *Un train qui part* (Monaco 1973) | ein Titel, der zu **keinem** Track der angegebenen Interpreten gehört | **entfernt** (siehe unten). In den Stores DE/FR/MC/GB/US/CH/BE und in 32 Eurovision-Sammelalben nicht auffindbar. |
  | `626` | Thomas Forstner – *Nur ein Lied* (Österreich 1989) | **Mark Forster – *Ein Lied* (2026)**. Anderer Interpret, anderes Lied, 37 Jahre daneben — der Namensgleichklang hat den automatischen Abgleich getäuscht. | **entfernt** am 17.08.2026. In DE/AT/CH/GB/US existiert keine Fassung: Forstner ist dort nur mit späterem Material vertreten (*Hautnah* 2024, *Summer Dream* 2021), und von den 29 gefundenen *Nur ein Lied* ist keins seins. Auch *Venedig im Regen* (1991) fehlt. |

  Bei `830` ist immerhin die Melodie die richtige, die Karte bleibt also spielbar.

  **`479` und `626` sind aus `songs-online.json` entfernt**, deshalb 1428 statt 1430 Einträge und
  zwei Lücken in der Nummerierung. Eine Karte mit fremdem Ton ist schlechter als eine fehlende:
  Sie bestraft gerade die Spieler, die den Ton zum Schätzen nutzen. Die IDs werden **nicht neu
  vergeben** — sonst zeigte die Statistik zu einer alten `tipps`-Zeile den falschen Song
  (dieselbe Regel wie bei den 336 gemeinsamen IDs). Auf beide verwies zum Zeitpunkt des
  Entfernens keine einzige Zeile in `tipps`. Nichts im Code setzt eine lückenlose Nummerierung
  voraus: `verlauf()` hasht die ID, und die Statistik zeigt bei fehlender ID „Song 626" statt zu
  scheitern (`kartenZeile`, `zeigeRueckblick`).

  **Zwei Dinge, die beim Entfernen erst am 17.08. auffielen** — beide sind seither erledigt, aber
  beim nächsten Mal wieder zu bedenken:

  1. **Laufende Partien tragen die ID weiter.** Deck und Zeitleisten stehen im Spielzustand in
     der Datenbank bzw. im `localStorage`, nicht in der Songdatei. Beim Entfernen von `626`
     hatten **alle 19 offenen Partien** die ID noch im Deck; beim Ziehen wäre `yearOf` auf
     `undefined` gelaufen. Dagegen putzt jetzt `zustandPutzen()` jeden übernommenen Zustand
     (in `adopt()` und beim Wiederaufnehmen eines Solo-Laufs). Der nächste `commit` schreibt die
     bereinigte Fassung zurück, die Partie heilt sich selbst — an der Datenbank ist nichts zu tun.
  2. **Das Tagesduell verschob sich früher komplett**, siehe `TAG_POOL` weiter unten.

* **Die Quelldatei unter `Sonstiges/songs-online.json` im Desktop-Ordner kennt keine dieser
  Korrekturen** (`423`, `428`, `1244`). Ein Neubau daraus bringt sie alle zurück.
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
* **„Durchlassen" ist eine Stimme, keine Entscheidung.** Aufgelöst wird erst, wenn *alle*
  Berechtigten verzichtet haben — oder wenn die 15 Sekunden ablaufen. Wer die Berechtigten
  sind, sagt `vetoBerechtigt()`: alle Aktiven außer dem Spieler am Zug, sofern Vetos übrig
  sind. Wer keine mehr hat, hält die Runde nicht auf.

  Bis zum 17.08.2026 beendete der **erste** Verzicht die Runde für alle. Ab drei Spielern
  nahm das den übrigen ihre Bedenkzeit, ohne dass sie etwas falsch gemacht hätten. Im
  Zweispieler-Duell ist „alle" genau einer, dort ist das Verhalten unverändert.

  Der Verzicht ist **endgültig**: nach dem Klick verschwindet der Vetoknopf. Sonst wäre die
  Stimme nichts wert, und zwischen Meinungswechsel und Auflösung könnte die Runde hängen.
* Zwei getrennte Wege beenden das Fenster, und das ist Absicht: `durchlassen()` stimmt ab und
  löst nur bei Vollständigkeit auf, `vetoAblauf()` löst bedingungslos auf. Der Countdown darf
  nicht an `durchlassen()` hängen — auf dem Gerät des Spielers am Zug hätte der keine Stimme
  und käme nie durch.
* **Stimmen hängen an einer Marke, nicht nur am Sitz.** `durchFuer` hält
  `partieId|current|seat|index` der Runde fest, für die abgestimmt wurde; `durchStand(st)`
  liefert nur Stimmen mit passender Marke. Grund sind gemischte Versionen beim Hochladen:
  Ein Client mit dem Stand *vor* dem 17.08.2026 kennt `durch` nicht, räumt es beim Auswerten
  nicht ab und setzt es beim Einloggen nicht zurück. Ohne Marke könnte eine Stimme aus der
  Vorrunde die nächste Abstimmung sofort kippen und das Vetofenster überspringen. Die Marke
  fällt im Zweifel auf „noch nicht abgestimmt" zurück — es wird gewartet, nicht abgekürzt.
  Die `partieId` steckt mit drin, weil `playAgain` das Deck neu mischt und dieselbe Karte in
  der Revanche wieder auftauchen kann.
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

### Kartenauswahl (Filter)

Bei 1428 Karten ist „alle" nicht immer die beste Runde. Über **Kartenauswahl** auf dem
Startbildschirm lässt sich der Kartenstapel eingrenzen — **für Solo und Duell, nicht fürs
Tagesduell**, dessen ganzer Sinn ja das gemeinsame Deck ist.

| Filter | Stufen | Karten |
|---|---|---|
| Platzierung | Alle · Finalisten · Top 10 · Top 5 · Top 3 · Sieger | 1428 · 1139 · 577 · 304 · 192 · 71 |
| Jahrzehnte | 1950er … 2020er, mehrfach wählbar | 44 … 342 je Jahrzehnt |
| Länder | 13 Gruppen, mehrfach wählbar | 29 (Verschwundene) … 365 (Mittelmeer) |
| Frische Karten zuerst | Schalter | — |

**„Finalisten" ist nicht dasselbe wie „Alle".** In `songs-online.json` steht `place` entweder als
Zahl oder als `"x"` — Letzteres heißt „im Halbfinale ausgeschieden". Das betrifft genau die Jahre
ab 2004, nachgezählt 289 Songs. Jede Stufe außer „Alle" wirft sie heraus, weil `parseInt("x")`
`NaN` ergibt und der Vergleich damit fehlschlägt. Das ist beabsichtigt und der Grund für die
eigene Stufe.

**Die Ländergruppen überlappen absichtlich** — Österreich ist deutschsprachig *und*
mitteleuropäisch, Israel liegt am Mittelmeer *und* außerhalb Europas. Ausgewählte Gruppen werden
**vereinigt, nicht geschnitten**. Geprüft ist außerdem, dass jedes der 53 Länder in mindestens
einer Gruppe steckt: Sonst wäre „alle Gruppen an" nicht dasselbe wie „alle Länder", und niemand
käme darauf, welches Land fehlt.

**`null` heißt „alle", nicht „keine".** Bei Jahrzehnten und Gruppen wird eine Vollauswahl als
`null` gespeichert, nicht als vollständige Liste. Sonst würde das Ergänzen einer Gruppe oder eines
Jahrzehnts aus jeder gespeicherten Vollauswahl stillschweigend eine Teilauswahl machen. `umschalten()`
setzt deshalb auf `null` zurück, sobald alle Werte an sind — und ebenso, wenn der letzte abgewählt
wird, denn ein leerer Pool wäre keine sinnvolle Antwort auf „ich will keins davon".

**Frische Karten zuerst** sortiert den Stapel in Stufen: erst alle, die auf diesem Gerät noch nie
dran waren, dann die einmal gezogenen und so weiter, innerhalb einer Stufe gemischt. Sobald jede
Karte einmal lief, wird daraus von selbst „die seltenste zuerst". Zwei Dinge daran sind nicht
offensichtlich:

* **Die Stufen liegen absteigend im Array.** Gezogen wird mit `deck.pop()`, also vom *Ende* — die
  frischesten Karten müssen deshalb hinten liegen. Nachgemessen: Zähler von vorn nach hinten
  monoton fallend, am Deckende ausschließlich Karten mit Zähler 0.
* **Gezählt wird in `renderGame()`, nicht im Mutator von `drawCard()`.** Der wird bei einem
  Versionskonflikt erneut ausgeführt und zählte die Karte dann doppelt. Gezählt wird je Gerät, im
  Duell also auf beiden — gesehen haben sie die Karte ja beide. (Die Startkarte einer Partie wird
  mitgezählt, obwohl sie nur ausliegt; bei einer frischen Karte pro Runde nicht der Rede wert.)

**Im Duell gilt die Auswahl des Gastgebers.** Es gibt ein Deck, also kann es nur eine Auswahl
geben. Damit das niemanden überrascht, steht sie in der Lobby — beim Gastgeber als
„Kartenauswahl: …", bei allen anderen als „Kartenauswahl des Gastgebers: …". Dafür liegt eine
Kurzfassung als `state.filter` im Spielzustand; gefiltert wird daraus **nicht** erneut, das Deck
steht ja längst fest.

**Unter `FILT_MIN` (20) Karten wird nicht gestartet**, mit Begründung im Statustext. Technisch
ginge es — das leere Deck beendet die Partie von selbst —, ergäbe aber keine Runde. Der Wächter
sitzt **vor** dem Anlegen der `games`-Zeile, damit eine abgewiesene Auswahl keine verwaiste Partie
hinterlässt. `neuesDeck()` für die Revanche mitten im Spiel greift dagegen notfalls auf alle Karten
zurück: Wer schon spielt, soll nicht durch eine zwischenzeitlich verschärfte Auswahl aufgehalten
werden.

### Schwierigkeit und Duellmodi

Beides steht im **Einstellungsbildschirm** (dem früheren „Kartenauswahl"), weil es dieselbe
Frage beantwortet: Wie soll die nächste Partie aussehen?

| | Stufen |
|---|---|
| Schwierigkeit (Mehrspieler + Endlosmodus) | Einfach · Fortgeschritten |
| Mehrspieler-Modus | Klassisch (10) · Individuell (5–20) · Deathmatch |

**Fortgeschritten sortiert nach Jahr *und* Platzierung** — und daran hängt eine Feinheit, die
`place = "x"` betrifft. Diese Karten sind im Halbfinale ausgeschieden und haben keine
Finalplatzierung, ihre Reihenfolge innerhalb des Jahres ist also unbestimmt. Naiv umgesetzt
(„neben einer x-Karte ist alles erlaubt") entstünde daraus eine Leiste, die als Ganzes falsch
sortiert ist, obwohl jeder einzelne Tipp galt: Aus `9 · x` würde durch Einsortieren von `1` am
Ende die Folge `9 · x · 1`. `isCorrect()` vergleicht deshalb mit dem nächsten Nachbarn desselben
Jahres, **der eine Platzierung hat**, und überspringt die x-Karten. Geprüft sind 18 Fälle gegen
die echten Funktionen, darunter genau dieser.

**Die Spielweise steht im Spielzustand, nicht auf dem Gerät** (`state.schwer`, `state.ziel`,
`state.tod`). Das ist keine Bequemlichkeit: `isCorrect()` läuft auf **beiden** Clients, und mit
einer gerätelokalen Einstellung würden sie unterschiedlich urteilen. Im Duell gilt deshalb die
Einstellung des Gastgebers, sichtbar in der Lobby.

**Deathmatch trennt Ausscheiden vom Verlassen.** `state.raus[k]` heißt „hat das Spiel verlassen"
und gilt für immer, `state.aus[k]` heißt „im Deathmatch ausgeschieden" und wird bei der Revanche
geleert. Ohne getrennte Kennzeichen ließe sich beim Neustart nicht unterscheiden, wen man
zurückholen darf. `aktive()` schließt beides aus.

Zwei Entscheidungen zum Deathmatch, die man ihm nicht ansieht:

* **Nur der eigene Zug scheidet aus, kein misslungenes Veto.** Sonst wäre Vetogeben Selbstmord
  und niemand würde es je wagen — ein Fehlveto kostet weiterhin nur das Veto.
* **Das Kartenziel bleibt** (10 bzw. die eingestellte Zahl). Ohne eines liefe eine Partie zweier
  vorsichtiger Spieler durch den ganzen Stapel von 1428 Karten.

**Das Tagesduell ist ausdrücklich einfach**, unabhängig von der Einstellung — `schwer: false`
steht dort fest im Zustand. Alle sollen dieselbe Aufgabe haben, sonst wäre die Tagesbestenliste
wertlos.

### Tagesduell

**Alle spielen an einem Tag dieselben zehn Karten in derselben Reihenfolge** (`TAG_KARTEN`).
Erst dadurch sind Läufe überhaupt vergleichbar — die Solo-Bestenliste war bis dahin eine
Sammlung unterschiedlich schwerer Decks. Und man kann sich zeitversetzt messen, ohne
gleichzeitig online zu sein.

Statt Leben läuft eine **Stoppuhr**. Gewertet wird nach **Fehlern, bei Gleichstand nach Zeit**.
Alle zehn Karten werden gespielt, ein Fehler beendet nichts.

**Das Deck entsteht aus dem Datum, nicht aus Zufall.** `seedAus()` (FNV-1a, wie bei
`verlauf()`) macht aus `'1408|2026-08-12'` einen Seed, `mulberry32()` daraus die Zahlenfolge,
mit der `shuffled()` mischt — dieselbe Funktion wie sonst, sie nimmt den Zufallsgeber jetzt als
Parameter. Zwei Dinge sind daran nicht offensichtlich:

* **Gemischt wird über `TAG_POOL`, einen festen Nummernraum `"001"`…`"2000"`, nicht über die
  vorhandenen Schlüssel.** Fehlende IDs fallen erst *danach* heraus (`.filter(id => SONGS[id])`),
  dann wird auf elf gekürzt. Die Reihenfolge hängt so nicht am Bestand.

  Vorher lief das über `Object.keys(SONGS).sort()`, und das war eine stille Falle: Fisher-Yates
  hängt an der Länge der Liste, also verschob **jede** Änderung an der Songdatei das Deck
  **jedes** Tages — auch rückwirkend. Beim Entfernen von Song `626` am 17.08.2026 blieb von den
  elf Karten des Tages keine einzige an ihrer Stelle, obwohl `626` in diesem Deck gar nicht
  vorkam. Wer an dem Tag schon gespielt hatte, war mit den Nachfolgenden nicht mehr vergleichbar.

  Mit festem Raum trifft eine Änderung nur noch die Tage, an denen der Song wirklich unter den
  ersten elf lag. Gemessen über 60 Tage: Song `100` entfernen ändert 0 Tage (er kam in keinem
  dieser Decks vor), die Lücke `479` füllen ändert genau den einen Tag, an dem sie auftaucht.

  `2000` als Grenze und nicht `1430` (heute größte ID): So sind die nächsten rund 570 neuen Songs
  bloß bisher übersprungene Plätze. Erst wer darüber hinaus erweitert, muss die Grenze anheben —
  und verschiebt dabei wieder alles.
* **Durchweg `Math.imul` und `| 0` / `>>> 0`.** Damit wird in 32-Bit-Ganzzahlen gerechnet und
  nicht in Fließkomma, wo die oberen Bits verloren gingen und zwei Geräte auseinanderlaufen
  könnten.

Nachgemessen: zwei unabhängige Browserstarts mit demselben Datum liefern identische Startkarte
und identisches Deck, zwei verschiedene Daten völlig verschiedene. (Die früher hier notierte
Beispielfolge `start=180, 072,078,…` galt für das alte Mischen über `Object.keys` und stimmt
seit der Umstellung auf `TAG_POOL` nicht mehr.)

Läuft technisch auf der **Solo-Mechanik** — kein Netz, kein Warten, ein Sitz. Kennzeichen ist
allein `tag` im Spielzustand; ohne ihn ist es eine gewöhnliche Solo-Partie. Was daran hängt:

| | Solo | Tagesduell |
|---|---|---|
| Deck | `shuffled()` über alle 1428 | zehn Karten aus dem Tages-Seed |
| Ende | nach drei Fehlern (`SOLO_FEHLER`) | wenn das Deck leer ist |
| `maxFehler` | `3` | `null` — keine Leben |
| Anzeige | Karten + Herzen | Fortschritt + Fehler + Uhr |
| `modus` in `partien` | `'solo'` | `'tag'`, dazu `tag` und `dauer_ms` |

**`maxFehler` ist `null` und nicht `Infinity`.** Der Solo-Zustand geht als JSON in den
`localStorage`, und aus `Infinity` würde dabei `null` — `fehler >= null` ist ab dem ersten
Fehler wahr. Mit `Infinity` wäre der Lauf nach einem Neuladen also sofort vorbei.

**Die Uhr startet beim ersten Ziehen, nicht beim Start.** Wer den Bildschirm liest, bevor er
zieht, soll dafür keine Sekunden bezahlen. Sie hält an, sobald die letzte Karte *ausgewertet*
ist (`dauerMs` im Zustand) — nicht erst beim Tastendruck danach, sonst zählte das Betrachten
der letzten Auflösung mit. Weil `begonnen` im Zustand steht und nicht auf dem Gerät, übersteht
die laufende Zeit ein Neuladen (nachgemessen: 0:01,8 → 0:02,0).

Angezeigt wird **mm:ss,z**. Zehntel, weil bei gleicher Fehlerzahl die Zeit entscheidet und
ganze Sekunden dort zu oft gleich wären. Zwischen den Zeichenvorgängen zählt `uhrTick()` im
bestehenden 250-ms-Takt nur dieses eine Feld weiter, statt neu zu zeichnen.

**Es zählt nur der erste Lauf des Tages.** Mit bekanntem Deck wäre ein zweiter kein Vergleich
mehr. Verbindlich ist der Teilindex `partien_tagesduell_einmal` über `(name_key, tag)` — der
zweite Insert scheitert mit 23505, was der Client schon als „steht schon drin" behandelt. Der
Vermerk in `duell1408tag` macht daneben nur den Startbildschirm sofort richtig, ohne auf eine
Antwort zu warten; er gilt naturgemäß nur für ein Gerät.

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

**Der Übergang nach `over` ist immer ein Tastendruck, nie automatisch.** Zwei Kennzeichen
halten die Auflösung stehen, obwohl die Partie schon entschieden ist:

| | gesetzt in | bedeutet |
|---|---|---|
| `soloAus` | `auswerten` (Solo, letztes Leben) | Solo entschieden |
| `partieAus` | `auswerten` (Mehrspieler, Siegkarte oder letztes Ausscheiden) | Duell entschieden |

Vorher sprang der Mehrspieler-Modus bei der Siegkarte direkt auf den Endbildschirm — genau bei
der Karte, die die Partie entscheidet, sah man also nie das Jahr. Der Knopf heißt dann
„Ergebnis ansehen" statt „Nächste Karte", und `naechsteKarte()` schaltet auf `over`.

Drei Stellen hängen daran und müssen beide Kennzeichen kennen:

* **`nachAuswertung`** wertet sofort (`partieMerken`), nicht erst beim Tastendruck: Wer den Tab
  auf der Auflösung zumacht, soll seine Partie nicht verlieren. Dass `naechsteKarte` beim
  Wechsel auf `over` ein zweites Mal `partieMerken` ruft, ist harmlos — `partieProtokolliert`
  fängt es ab (nachgemessen: zwei Zeilen für zwei Spieler, kein doppelter Satz).
* **`leaveGame`** rührt eine entschiedene Partie nicht mehr an. Ohne diese Sperre hätte ein
  Aussteigen zwischen Siegkarte und Tastendruck den Sieg in einen Abbruch verwandelt.
* **`renderActions`** beschriftet den Knopf.

### Der Spielzustand

**Eine Zeile in `games` je Partie**, der komplette Zustand als JSONB. Für zehn Spieler ist das
deutlich einfacher zu handhaben als normalisierte Tabellen, und Realtime schickt bei jeder
Änderung ohnehin die ganze Zeile.

```js
{
  phase, ziel, turn,                  // 'p1'…'p10'
  seats:     { p1:{name}, p2:…, p3:null, … },   // MAX_SPIELER Schlüssel
  raus:      { p3:true },             // ausgestiegene Spieler
  timelines: { p1:[songId,…], … },    // immer nach Jahr sortiert
  vetos:     { p1:3, … },
  getroffen: { p1:7, … },             // selbst richtig einsortierte Karten
  geklaut:   { p1:2, … },             // per Veto geholte Karten
  partieAus: true,                    // Duell entschieden, Auflösung noch sichtbar
  deck:      [songId,…],              // gemischt, es wird vom Ende gezogen
  current:   songId,                  // gezogene Karte
  pending:   { seat, index },         // eingeloggt, noch nicht ausgewertet
  vetoBis:   1785412863168,           // Serverzeit in ms, 0 = kein Countdown
  vetoAngemeldet: 'p4',               // wer den Wettlauf gewonnen hat
  durch:     { p2:true },             // wer schon durchgelassen hat (Veto-Abstimmung)
  audio:     { playing, startedAt, seek },
  result:    { seat, id, index, correct, klau },
  hinweis:   'Jenny hat das Spiel verlassen',
  winner, verlassen, solo, fehler, maxFehler,
  soloAus                             // Solo entschieden, Auflösung noch sichtbar
}
```

**Sitzplätze:** Feste Liste `SITZE`, erzeugt aus `MAX_SPIELER` (10) als `p1`…`p10` — wie im
gedruckten Original. Nie `p1`/`p2` fest verdrahten — dafür gibt es `aktive(st)`,
`mitspieler(st, ausser)`, `naechster(st, von)`, `freierSitz(st)`, `vetoBerechtigt(st)`,
`alleDurch(st)`, `vetoOffen(st)`.

Die Erhöhung von vier auf zehn (17.08.2026) kostete drei Zeilen Logik, weil sich alles über
`SITZE` bewegt. Nur zwei Stellen waren getippt statt erzeugt: der Anfangszustand in `newGame`
(`seats`, `timelines`) und der Lobby-Satz „Alle vier Plätze belegt". Beide bauen jetzt auf
`SITZE` bzw. `MAX_SPIELER` auf.

**Alte Spielzustände kennen nur `p1`…`p4`** und stören nicht: `aktive()` prüft auf `seats[k]`,
fehlende Schlüssel gelten als frei. Eine Lobby von vorher füllt sich also einfach weiter auf.

**Nicht mitskaliert: die Mindestgröße des Decks** (`FILT_MIN` = 20). Zehn Spieler brauchen
zehn Startkarten und bis zu 90 weitere; ein knapp gefiltertes Deck ist vorher leer, dann
gewinnt nach `naechsteKarte` die längste Leiste. Kein Absturz — `FILT_MIN` liegt über
`MAX_SPIELER`, es reicht immer für die Startkarten —, aber eine kurze Partie. Die Auswahl steht
fest, bevor bekannt ist, wie viele mitspielen, deshalb lässt sich das nicht automatisch prüfen.

**`durch` gehört zu `vetoBis` und `vetoAngemeldet`** und wird an fünf Stellen mit zurückgesetzt:
`einloggen` (Fenster öffnet), `auswerten` (Fenster schließt), `leaveGame`, `startGame`,
`playAgain`. Ein Rest aus der Vorrunde ließe die nächste Abstimmung zu früh kippen.

Die **sechste** Stelle mit `vetoAngemeldet = null` ist `vetoZurueck` („Doch nicht") — und die
lässt `durch` absichtlich stehen: die Stimmen der anderen sind weiter gültig, nur der
Zurücktretende hat noch keine abgegeben. Ein Hängen ist dabei nicht möglich, weil er selbst
nie in `durch` steht (der Vetoknopf verschwindet nach dem Verzicht) und weil `vetoZurueck` das
Fenster mit vollen 15 Sekunden neu öffnet.

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

### Katzen-Reaktionen

Ein Knopf unten rechts, aufgefaltet erscheinen fünfundzwanzig Katzen (`reactions/`), eine Auswahl fliegt
bei allen Mitspielern ein. Nur im Duell — im Solo und Tagesduell wäre niemand da, der sie sieht,
deshalb schaltet `renderGame()` den Knopf nur bei `!st.solo && mitspieler(...).length > 0`.

**Sie laufen über Realtime-Broadcast, nicht über den Spielzustand.** Das ist die eine
Entscheidung, die hier zählt: Eine Katze ist flüchtig. Im Zustand wäre sie ein Schreibvorgang mit
neuer Versionsnummer, würde also mit dem optimistischen Sperren beim Einloggen einer Karte
konkurrieren, in der Datenbank stehen bleiben und nach einem Neuladen erneut auftauchen. Über
`channel.send({ type:'broadcast', event:'katze', … })` passiert nichts davon. Der Preis: Reißt
Realtime ab, geht die Katze verloren — der 4-Sekunden-Poll holt nur Zustände nach, keine
Broadcasts. Für Zierrat ist das der richtige Tausch.

**Der eigene Broadcast kommt nicht zurück** (`self` ist standardmäßig aus), deshalb zeigt
`reaktionSenden()` die eigene Katze sofort örtlich an — was ohnehin die schnellere Rückmeldung
ist. Alles von außen wird geprüft: ein unbekannter Dateiname wird verworfen (feste Liste
`KATZEN`), und der fremde Anzeigename geht über `textContent` in den DOM, nie über `innerHTML`.

Vier Sachen, die beim Bauen nicht auf Anhieb saßen:

* **Die Winkel.** `fuelleKatzen()` rechnet `y = -r·sin θ`, weil y auf dem Bildschirm nach unten
  zeigt. Damit heißt 180° links und 90° oben, der Bogen läuft also von 178° **abwärts** auf 86°.
  Mit 178→268 fiel er nach unten aus dem Bild (gemessen: fünf von acht Katzen außerhalb).
* **Die Ringzahl wird gerechnet, nicht festgelegt.** `katzenRinge(n)` sucht das kleinste k, bei
  dem die Sehne zwischen Nachbarn desselben Rings — 2·r₀·sin(k·Schritt/2) — den
  Knopfdurchmesser samt Luft übertrifft. Mit acht Katzen reichten zwei Ringe, mit vierzehn drei,
  mit fünfundzwanzig sind es fünf. Fest verdrahtet hätten die neuen die alten überlappt: Die
  Sehne wäre von 50 auf 27px gefallen, bei 32px Bedarf.

  Die Obergrenze der Schleife lag ursprünglich bei vier Ringen — und gab bei 25 Katzen
  **trotzdem vier zurück**, obwohl vier nicht reichten. Die Kacheln überlappten sich dann um
  10px, ohne dass irgendwo etwas gemeldet hätte. Sie steht jetzt bei sechs.

  Die **Spanne** lässt sich dabei nicht ausweichen: unter 178° käme eine Katze über die
  Aktionsknöpfe, über 90° hinaus rechts aus dem Bild — bei 86° stand die oberste auf dem
  äußersten Ring noch 5px vom Rand, bei 82° ragte sie auf einem 320px-Schirm hinaus (beides
  gemessen). Mehr Katzen heißt also: mehr Ringe, nicht mehr Grad. Die Knöpfe sind von 42 über 36
  auf **30px** geschrumpft und der Ringabstand von 54 auf 40, sonst reichte der fünfte Ring über
  den linken Rand. Nachgemessen auf 320×568, 375×667, 390×844 und 430×932: keine Überlappung,
  keine Katze außerhalb.
* **Der weiße Aufkleberrand steckt in den PNG, nicht in einem Filter.** Die Katzen sind schwarze
  Silhouetten, und die einfliegende zieht über die dunkle Karte — dort war sie kaum zu erkennen.
  Der erste Versuch über verkettete `drop-shadow` scheiterte an der Bildsprache: Die verfolgen
  die Alphakante genau und umrandeten deshalb **jede Fellzacke und jeden Zitterstrich einzeln** —
  bei `cat-spooked-fur` ein weißer Kamm am Schwanz, bei `cat-startled` verstreute Schnipsel um
  die Katze herum. Ein Stanz-Sticker folgt aber der groben Form, nicht der Zeichnung.

  Gebacken wird er deshalb beim Aufbereiten der Bilder: Alphakanal weichzeichnen (σ 16), hart
  schwellen (18), einmal nachglätten, 1,2 px Antialiasing. Das Weichzeichnen rundet Ecken und
  überbrückt Lücken bis etwa 2σ — genau das lässt die Zacken in einer geschlossenen Form
  verschwinden. Die Werte sind erprobt: σ 8 und 12 folgten den Zacken noch, σ 20 schnitt bei
  `cat-grumpy` am Bildrand ab. Ein echtes morphologisches Schließen (stark wachsen, dann
  zurückschrumpfen) fasste die Zitterstriche besser, brauchte aber so viel Rand, dass die Katze
  zu klein wurde.

  Dafür sitzt der Inhalt mit **26 px Polster** im 320er-Rahmen, sonst würde die Kontur an der
  Bildkante abgeschnitten — geprüft ist für alle 14, dass die Maske den Rand nicht berührt. Weil
  jedes Bild dadurch rund 16 % Polster mitbringt, füllt es in der Auswahl die Kachel **ganz**
  (vorher 78 %): Auf der weißen Kachel ist der Rand unsichtbar, die Katze wäre sonst geschrumpft.
  Im CSS bleibt nur der weiche Schatten.
* **Knopf und Katzen liegen außerhalb der Bildschirme**, obwohl sie nur zum Spielbildschirm
  gehören. `.screen.hidden` trägt ein `transform`, und das spannt für `position:fixed` einen
  eigenen Bezugsrahmen auf — als Kind läge der Knopf relativ zum geschrumpften Bildschirm und
  wanderte beim Ein- und Ausblenden sichtbar umher. Ausgeschaltet werden sie deshalb in `show()`,
  derselben Stelle, die auch den Statistik-Vermerk führt.

Gebremst wird zweifach: `REAKT_SPERRE` (1,2 s) sperrt den Knopf nach dem Senden sichtbar, und
`REAKT_MAX` (3) begrenzt, wie viele gleichzeitig im Bild sein können — bei zehn tippfreudigen
Spielern wäre der Bildschirm sonst zugeklebt. Aufgeräumt wird per `animationend` **und** per
Timer: Bei einem Tabwechsel bleibt das Ereignis aus, und die Katze stünde für immer im DOM.

### Vetokatze zur Auflösung

Wurde ein Veto eingelegt, fliegt bei der Auflösung eine Katze ein: `veto-erfolg.png`
(rennt mit dem Fisch im Maul weg) oder `veto-fehl.png` (starrt einen Fisch im Glas an), dazu
die Unterschrift „X hat die Karte geklaut!" bzw. „X konnte die Karte nicht schnappen" — in der
zweiten Person, wenn es einen selbst betrifft, wie im Auflösungstext daneben.

**Zwei Bilder für drei Ausgänge.** Ob das Veto am eigenen Fehlgriff scheiterte oder daran, dass
der Spieler am Zug richtig lag (dann wird die Lücke des Vetogebers nie angesehen), macht für ihn
keinen Unterschied: die Karte hat er nicht.

**Nicht verschickt, sondern abgeleitet.** Anders als die getippten Reaktionen läuft das nicht über
Broadcast, sondern aus `st.result.klau` in `render()`. Damit erscheint es auf jedem Gerät von
selbst und kann nicht verloren gehen. Gegen Mehrfachauslösung dient `vetoKatzeFuer` mit der Marke
`partieId:songId:index` — `render()` läuft bei jeder Zustandsänderung erneut, und die
Partiekennung muss mit hinein, weil `playAgain` das Deck neu mischt und dieselbe Karte
wiederkommen kann. Die Marke des Konfettis taugt dafür nicht: die wird nur gesetzt, wenn überhaupt
jemand die Karte bekam.

**Die Lage musste zweimal wandern**, beide Male aus einem gemessenen Grund:

* Auf der Standardhöhe der Reaktionen (42 %) lag die Katze **quer über der Jahreszahl**. Die
  getippten Reaktionen fliegen während des Zugs, da steht auf der Bühne der Player — die
  Vetokatze fliegt in der Auflösung, und dort steht die aufgedeckte Karte.
* Rechts unten sitzen die beiden Reaktionsknöpfe mit `z-index:60`, also **über** dem Flug (58).
  Der 💬-Knopf schnitt ein Loch in die Unterschrift, und deren rechter Rand lief aus dem Bild.
  Sie hängt deshalb links (`left:4%; right:auto` — beides zusammen presste sonst die Breite).

Der Rahmen ist breiter als das Bild (`img { width:66% }`), damit die Unterschrift umbrechen kann,
ohne die Katze aufzublasen. Sie bleibt länger stehen als eine getippte Reaktion (2,6 s bis zum
Abflug statt 1,5 s) — man muss sie lesen. Die Haltedauer steht doppelt, im CSS und als Argument
von `flugAbschluss`; beides muss zusammenpassen, sonst räumt der Timer weg, was noch fliegt.

### Aufkleberrand bauen: `build-sticker.py`

Die erprobten Werte stehen jetzt im Repo statt nur im Text: `python3 build-sticker.py QUELLE ZIEL`
beschneidet auf den Inhalt, passt ihn mit 26 px Polster in den 320er-Rahmen ein und backt die
Kontur (σ 16, Schwelle 18, nachglätten 4, 1,2 px Antialiasing). `--pruefen` misst bei vorhandenen
Bildern den Abstand der Kontur zum Bildrand; 0 heißt abgeschnitten, das Skript bricht dann ab.

Beschnitten wird auf den **Inhalt**, nicht auf den festen Einheitsrahmen der ersten vierzehn
Bilder: `veto erfolg.png` beginnt bei x = 33, der alte Schnitt bei x = 47 — die Vorderpfoten wären
weg gewesen. Randabstand der beiden neuen: 12 px und 3 px, die vorhandenen liegen zwischen 1 und
15 px.

### Sprüche statt Chat

Ein zweiter Knopf (💬) über dem Katzenknopf, dahinter vierzehn feste Sprüche aus `SPRUECHE`. Sie
fliegen genauso ein wie die Katzen, nur als Sprechblase.

**Warum kein echter Chat:** Er bräuchte ein Eingabefeld, eine Verlaufsliste und dauerhaft Platz
auf dem Spielbildschirm — und würde beim Tippen genau von dem ablenken, worum es geht. Feste
Sprüche sind ein Tipp statt eines Satzes und brauchen keinen Platz, solange sie zu sind.

Was sich mit den Katzen **teilt**: die Auffangfläche zum Wegtippen (`huelleNachziehen()` hält sie,
solange irgendeine Auswahl offen ist), die Sperre (`reaktBereit()` — **eine** für beide Knöpfe,
sonst ließe sich durch Abwechseln die doppelte Menge senden), der Flugrahmen (`flugRahmen()` /
`flugAbschluss()`) und die Begrenzung auf `REAKT_MAX`. Die beiden Auswahlen schließen sich
gegenseitig; übereinander geöffnet lägen die Katzenringe hinter der Spruchtafel.

Drei Entscheidungen:

* **Tafel statt Kranz.** „Liebe den Song!" ist zehnmal so breit wie ein Katzenknopf — im
  aufgefalteten Kranz stünde die Hälfte außerhalb des Bildschirms. Die Sprüche stehen deshalb als
  umbrechende Kachelwolke rechts unten, verankert über dem Knopf, und wachsen nach oben und links.
* **Verschickt wird der Text, nicht seine Nummer.** Über den Index wäre die Nutzlast kürzer, aber
  ein Gerät mit älterer Liste zeigte beim Nachrücken eines Spruchs den falschen. Neue Sprüche
  gehören trotzdem ans **Ende** — dann bleibt die Reihenfolge der gewohnten stabil.
* **`spruchEmpfangen()` nimmt nur an, was in `SPRUECHE` steht.** Das ist keine Förmlichkeit: Einen
  Broadcast kann mit dem öffentlichen Schlüssel jeder abschicken (siehe *Grenzen des anon-Keys*).
  Ohne die Prüfung ließe sich beliebiger Text auf fremde Bildschirme schreiben. Markup greift
  ohnehin nicht — der Text geht über `textContent` in den DOM, geprüft mit einem
  `<img src=x onerror=…>` als Nutzlast —, es geht um den Inhalt.

Länger als etwa 16 Zeichen sollte kein Spruch sein, sonst bricht die Kachel in der Tafel um.

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

#### Freischalten (`unlockAudio`) — und was daran zweimal schiefging

iOS und Android erlauben programmatisches `play()` erst, wenn das Element einmal **aus einer
Nutzergeste heraus** gespielt hat. Der wartende Spieler tippt aber nicht, also wird beim ersten
Antippen irgendwo auf der Seite freigeschaltet.

Ursprünglich immer über ein stummes Schnipsel (`SILENT`) auf demselben `<audio>`-Element. Auf
dem Startbildschirm ist das harmlos — dort ist es leer. **Nach einem Neuladen mitten in der
Partie steckt aber schon eine Preview darin**, und die war nach dem ersten Antippen weg: Das
Umschalten setzt Dauer und Position zurück, und zurückgelegt wurde die Quelle nur im
Erfolgsfall von `play()`. Genau der tritt hier nicht ein — nachgemessen im Kopfmodus:

| Lage | `play()` auf `SILENT` | Folge vorher |
|---|---|---|
| ohne Geste (Zustand vor dem ersten Tippen) | wird abgelehnt | Quelle bleibt stumm |
| Autoplay erlaubt | löst sich **nie** auf (`SILENT` hat Dauer 0 bzw. `Infinity`) | Quelle bleibt stumm |

Und weil `syncAudio()` die Quelle nur bei einem **Kartenwechsel** neu setzte, kam die Preview
für den Rest der Karte nicht wieder: kein Ton, Anzeige klebt auf „Lädt…", Playbutton ohne
Wirkung. Im Duell fällt das besonders auf, weil der wartende Spieler nach dem Neuladen keinen
Grund hat, irgendetwas anzutippen, bevor er hören will.

Deshalb jetzt:

* **Freigeschaltet wird mit dem, was schon geladen ist.** Steckt die Preview der aktuellen
  Karte im Element, wird sie selbst angespielt — schaltet genauso frei, kann aber nichts
  verlieren. Nur bei leerem Element kommt das stumme Schnipsel zum Einsatz. Danach
  `audioAnweisung = null` und neu zeichnen, damit `syncAudio()` pausiert/läuft und die Position
  wieder auf den Spielzustand bringt.
* **`syncAudio()` und `weiterspielen()` prüfen die Quelle**, nicht nur die Kartennummer. Steht
  etwas Fremdes im Element, wird die Preview neu gesetzt. Das fängt auch den Fall auf, dass iOS
  geladene Medien im Hintergrund von sich aus hinauswirft.
* **`previewUrl()` löst die Adresse auf**, statt `s.pr` direkt zu vergleichen. `aud.src` gibt
  immer die aufgelöste Form zurück; mit einem relativen Eintrag in `songs.json` wäre der
  Vergleich nie gleich und die Quelle würde bei jedem Zeichnen neu geladen — eine Endlosschleife
  aus „Lädt…". Heute stehen dort absolute Adressen, das soll aber nicht die Bedingung sein.
* **`onAudioEnded()` reagiert nur auf die Preview.** Läge das stumme Schnipsel im Element,
  würde sein sofortiges Ende als „Song durchgelaufen" gelesen — und der Spieler am Ball
  schaltete damit den Ton für **beide** ab.

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

  Mit `songs-online.json` kamen **neun Länder** dazu — Andorra, Belarus, Georgien, Marokko,
  Mazedonien, Nordmazedonien, Slowakei, Slowenien, Tschechien (83 Songs). Alle neun sind
  gebaut, es fällt also nirgends auf das Emoji zurück. Mazedonien und Nordmazedonien zeigen
  dieselbe Flagge (die Sonnenflagge gilt seit 1995, die Umbenennung 2019 änderte sie nicht) —
  zwei Dateien braucht es dennoch, weil der Dateiname aus dem Ländernamen entsteht.

  **`build_flags.py` erzeugt diesen Stand noch nicht wieder.** Das Skript liegt nur lokal
  (Desktop-Projektordner), liest `songs.json` und schreibt nach `Website/flags` — also in die
  *alte* Kopie der Website, nicht ins Repo. Für Reproduzierbarkeit fehlen ihm drei Dinge: die
  Online-Datei als zweite Quelle der Länderliste, die Einträge `"Belarus": "Belarus"` und
  `"Nordmazedonien": "NorthMacedonia"` in `LAND_ZU_DATEI`, und das Repo als Ziel. Das
  Quellmaterial (`Flaggen Herzen/*/New<Land>.png`, 72 Dateien) deckt alle 53 Länder ab.

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
| `tagesbestenliste(p_tag, p_limit)` | Tagesduell: Platz, Fehler, Zeit | Tagesduell |
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

**Ein Neuladen behält die Seite.** Wer auf der Statistik F5 drückt, landete vorher auf dem
Startbildschirm. `SICHT_KEY` hält jetzt fest, dass die Seite offen ist, dazu beide Umschalter
und den Scrollstand. Das ist der **einzige Schlüssel im `sessionStorage`** statt im
`localStorage`: ein Neuladen soll die Seite behalten, ein Besuch morgen aber wieder am Start
beginnen, und in einem zweiten Tab hat der Stand nichts zu suchen. Drei Feinheiten, die man
beim Nachbauen falsch machen kann:

* **Geschrieben wird in `show()`**, der einzigen Stelle, an der der Bildschirm wechselt. Jeder
  Weg von der Seite weg geht darüber, keiner muss selbst daran denken.
* **`statistikWieder()` steht am Ende von `init()`**, hinter dem Wiederaufnehmen einer laufenden
  Partie. Die zeichnet den Spielbildschirm, und die Statistik muss darüber liegen — der
  Zurück-Knopf findet die Partie dann trotzdem vor und führt ins Spiel statt auf den Start.
  Damit dieses erste `show('gameScreen')` den Schlüssel nicht löscht, bevor ihn jemand gelesen
  hat, schreibt `statistikMerken()` nur bei echter Änderung. Der Vergleich ist nicht bloß
  Sparsamkeit gegen das im Sekundentakt laufende `render()`, er ist tragend.
* **Gescrollt wird erst nach `await zeigeStatistik()`.** Solange in allen Kästen „lädt…" steht,
  ist die Seite ein Vielfaches kürzer, und der Scrollstand würde auf deren Ende
  zusammengestaucht.

Ohne Verbindung zur Datenbank bricht `init()` vorher ab und bleibt am Startbildschirm — dort
steht dann die Fehlermeldung, die auf der Statistik niemand zu sehen bekäme.

Geholt wird mit `Promise.allSettled`, und **jeder Kasten zeichnet für sich**, sobald seine
Antwort da ist. Mit einem `Promise.all` über acht Aufrufe würde der langsamste zum
Taktgeber für alle, und ein einziger Fehlschlag ließe die ganze Seite auf „lädt…" stehen.
`statLauf` zählt dabei mit: Antworten aus einer älteren Einstellung werden verworfen, sonst
könnte man sich beim schnellen Umschalten gemischte Zahlen zusammenklicken.

Songtitel kommen **aus `songs.json`**, nicht aus der Datenbank — die RPCs geben nur `song_id`
zurück, damit die Statistik gültig bleibt, wenn Songdaten später korrigiert werden. Fehlt eine
ID dort, wird sie selbst angezeigt (`Song 999`), es stürzt nichts ab.

Der **Kasten auf dem Endbildschirm** hat zwei Quellen, und das ist wichtig für das Timing:

| Zelle | kommt aus | wann |
|---|---|---|
| selbst geraten · geklaut · mit Startkarte | Spielzustand (`zeigeEndBilanz`) | sofort |
| in Folge · härteste Karte der Partie | RPC `partie_rueckblick` | nachgeladen |

Die Datenbankzellen stehen bis dahin auf „–". Kommt nichts, bleibt es dabei — auf dem
Siegesbildschirm hat keine Fehlermeldung etwas verloren. Die `partie_id` kommt aus dem
Spielzustand, nicht aus einer Modulvariablen, damit es auch nach einem Neuladen funktioniert.
Und weil die Tipp-Zeilen nebenher geschrieben werden und bei Spielende noch unterwegs sein
können, fragt der Rückblick bei leerem Ergebnis **ein zweites Mal** nach.

**Warum die Startkarte ausdrücklich dasteht.** Vorher zeigte der Kasten „9/12 getroffen" neben
einem Stand von „10 Karten" — zwei Zahlen, die nicht zusammenpassen wollten, weil jeder Spieler
mit einer aufgedeckten Karte anfängt und diese in keiner Trefferzahl steckt. Jetzt steht die
Zerlegung da, und sie geht auf:

```
timelines[k].length === 1 + getroffen[k] + geklaut[k]
```

Das gilt ausnahmslos: Eine Karte kommt nur über einen eigenen Treffer oder ein gelungenes Veto in
eine Leiste, und sie verlässt sie nie wieder (ein misslungenes Veto kostet das Veto, nicht die
Karte). `endBilanz()` **prüft die Gleichung** und gibt bei Abweichung `null` zurück — dann stehen
Striche statt Zahlen. Das greift bei Partien, die vor dem 17.08.2026 begonnen haben und die
Zähler nicht kennen, und bei Leisten, aus denen `zustandPutzen()` eine entfernte Karte geworfen
hat. Eine erfundene Aufschlüsselung wäre schlimmer als keine.

Die Zähler stehen bewusst **im Spielzustand** und nicht in einer RPC: So sind sie ohne Netz da,
sofort statt nach einer halben Sekunde, und alle Geräte zeigen dasselbe.

`partie_rueckblick` liefert weiter `quote_richtig` und `quote_gesamt` — angezeigt werden sie nicht
mehr. Die Trefferquote steht auf der Statistikseite, dort ist sie richtig aufgehoben. Im Client
dient `quote_gesamt` nur noch als Prüfung, ob die Tipp-Zeilen schon angekommen sind; die Felder
bleiben in der Funktion, ein `DROP` wäre eine Migration ohne Gegenwert.

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
4. `supabase-tagesduell.sql` — Spalten `tag` und `dauer_ms`, die Tagessperre,
   `tagesbestenliste()` und die erweiterte `modus`-Bedingung. Setzt Schritt 2 voraus
   (`name_key`). **Wer eine frühere Fassung dieser Datei eingespielt hat, muss sie erneut
   ausführen** — Abschnitt 1b kam später dazu, und ohne ihn wird jede Tagesduell-Zeile
   abgewiesen.

Alle neuen Dateien sind wiederholbar: nochmal ausführen ändert nichts mehr und lässt
bestehende Zeilen unangetastet. Wer eine Datei erweitert, muss sie **erneut ganz** einspielen —
ein nachträglich angehängter Abschnitt ist sonst nirgends angekommen, und die Prüfabfrage zeigt
dann völlig zu Recht noch den alten Stand.

**`partien.modus` trägt eine CHECK-Bedingung.** Sie erlaubt `'solo'`, `'duell'` und – seit
`supabase-tagesduell.sql` – `'tag'`. Die ursprüngliche Fassung steht in `supabase-schema.sql`,
und die **fehlt im Repo**: In den vorhandenen Dateien ist die Bedingung also nicht zu sehen. Genau
daran ist das Tagesduell zunächst gescheitert — die Zeilen prallten mit `23514` ab, weil beim
Bauen der Migration aus „steht in keiner Datei" auf „gibt es nicht" geschlossen wurde. **Was das
Schema angeht, ist die Datenbank die Quelle, nicht die Ablage.** Ein neuer `modus` braucht immer
auch eine erweiterte Bedingung; abfragen lässt sie sich mit:

```sql
select conname, pg_get_constraintdef(oid)
  from pg_constraint where conrelid = 'public.partien'::regclass;
```

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

**`init()` steht als letzte Zeile des Moduls — und muss dort bleiben.** Solange der Aufruf
mitten in der Datei stand, war alles, was weiter unten als `const` definiert ist, zum Zeitpunkt
von `init()` noch nicht ausgewertet; ein Zugriff darauf warf einen `ReferenceError`.
Funktionsdeklarationen (`function name()`) sind hochgezogen und gingen, `const`-Pfeilfunktionen
nicht. Das hat **viermal** zugeschlagen: `heuteTag`, `FILT_STANDARD`, `WAHL_FARBEN`, `nameDa`.

Bemerkt wurde es jedes Mal erst an der Folge, nie am Fehler selbst — weil ein weit gefasstes
`catch` ihn schluckte (`tagErgebnis`) oder weil `init()` einfach abbrach und danach die Songs
fehlten, die Chips leer blieben oder die Namenssperre ausfiel. **Ein weit gefasstes `catch` macht
so einen Fehler unsichtbar; beim Suchen zuerst dort nachsehen.**

Seit der Aufruf am Dateiende steht, ist die Fehlerklasse zu: Beim Ausführen von `init()` ist das
Modul vollständig ausgewertet, jede Hilfsfunktion ist erreichbar, egal wo sie steht. Wer etwas
ans Dateiende anhängt, hängt es **über** `init()` — sonst kommt die Falle zurück.

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
