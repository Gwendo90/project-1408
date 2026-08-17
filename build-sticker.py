#!/usr/bin/env python3
"""
Backt den weißen Aufkleberrand in ein Reaktionsbild.

    python3 build-sticker.py QUELLE.png ZIEL.png
    python3 build-sticker.py --pruefen reactions/*.png     # nur messen, nichts schreiben

Warum als Skript und nicht von Hand: `build_flags.py` im Desktop-Ordner erzeugt
den heutigen Stand der Flaggen nicht mehr (siehe README). Damit das den
Reaktionsbildern nicht genauso geht, stehen die erprobten Werte hier – im Repo,
neben den Bildern, die sie erzeugen.

────────────────────────────────────────────────────────────────────────────────
Warum überhaupt ein Rand: Die Katzen sind schwarze Silhouetten und fliegen über
die Spielkarte, die dunkel sein kann – dort waren sie kaum zu erkennen.

Warum gebacken und nicht per CSS: Verkettete `drop-shadow` verfolgen die
Alphakante genau und umranden deshalb jede Fellzacke einzeln – ein weißer Kamm
statt einer Kontur. Ein Stanz-Sticker folgt der groben Form, nicht der Zeichnung.

Wie: Alphakanal weichzeichnen (σ 16), hart schwellen (18), einmal nachglätten,
1,2 px Antialiasing. Das Weichzeichnen rundet Ecken und überbrückt Lücken bis
etwa 2σ – genau das lässt die Zacken in einer geschlossenen Form verschwinden.

Die Werte sind erprobt, nicht geraten: σ 8 und 12 folgten den Zacken noch, σ 20
schnitt bei `cat-grumpy` am Bildrand ab. Ein echtes morphologisches Schließen
(stark wachsen, dann zurückschrumpfen) fasste die Zitterstriche besser, brauchte
aber so viel Rand, dass die Katze zu klein wurde.
────────────────────────────────────────────────────────────────────────────────
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageFilter

KANTE   = 320      # Ausgabegröße, quadratisch
POLSTER = 26       # Luft für die Kontur; ohne sie schneidet der Bildrand sie ab
SIGMA   = 16       # Weichzeichnung des Alphakanals
SCHWELLE = 18      # ab diesem Wert gehört ein Pixel zur Kontur
GLATT   = 4        # Nachglätten der geschwellten Maske
AA      = 1.2      # Antialiasing der Kante


def sticker(quelle: Path) -> Image.Image:
    im = Image.open(quelle).convert('RGBA')

    # Auf den Inhalt beschneiden statt auf einen festen Rahmen: Die Vorlagen sind
    # unterschiedlich gefüllt, und ein fester Schnitt hätte bei der weit
    # gestreckten Katze die Vorderpfoten abgeschnitten (gemessen: Inhalt beginnt
    # bei x=33, der alte Einheitsschnitt bei x=47).
    kasten = im.split()[-1].getbbox()
    if not kasten:
        sys.exit(f'{quelle}: Bild ist vollständig durchsichtig')
    inhalt = im.crop(kasten)

    # In das Feld ohne Polster einpassen, Seitenverhältnis behalten.
    frei = KANTE - 2 * POLSTER
    faktor = min(frei / inhalt.width, frei / inhalt.height)
    neu = inhalt.resize((max(1, round(inhalt.width * faktor)),
                         max(1, round(inhalt.height * faktor))), Image.LANCZOS)

    mitte = Image.new('RGBA', (KANTE, KANTE), (0, 0, 0, 0))
    mitte.paste(neu, ((KANTE - neu.width) // 2, (KANTE - neu.height) // 2), neu)

    # ── Die Kontur ──
    alpha = mitte.split()[-1]
    maske = alpha.filter(ImageFilter.GaussianBlur(SIGMA))
    maske = maske.point(lambda w: 255 if w >= SCHWELLE else 0)
    maske = maske.filter(ImageFilter.GaussianBlur(GLATT))
    maske = maske.point(lambda w: 255 if w >= 128 else 0)
    maske = maske.filter(ImageFilter.GaussianBlur(AA))

    weiss = Image.new('RGBA', (KANTE, KANTE), (255, 255, 255, 255))
    weiss.putalpha(maske)
    weiss.alpha_composite(mitte)          # Katze auf die weiße Form
    return weiss


def randabstand(bild: Image.Image) -> int:
    """Kleinster Abstand der Kontur zum Bildrand. 0 heißt: abgeschnitten."""
    k = bild.split()[-1].getbbox()
    if not k:
        return KANTE
    return min(k[0], k[1], bild.width - k[2], bild.height - k[3])


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('dateien', nargs='+', type=Path)
    p.add_argument('--pruefen', action='store_true',
                   help='nur den Randabstand vorhandener Bilder messen')
    a = p.parse_args()

    if a.pruefen:
        for f in a.dateien:
            im = Image.open(f).convert('RGBA')
            d = randabstand(im)
            print(f'{f.name:26} {im.size[0]}x{im.size[1]}  Randabstand {d:>3} px'
                  + ('  ← ABGESCHNITTEN' if d == 0 else ''))
        return

    if len(a.dateien) != 2:
        sys.exit('Zum Bauen genau zwei Angaben: QUELLE ZIEL')
    quelle, ziel = a.dateien
    bild = sticker(quelle)
    d = randabstand(bild)
    if d == 0:
        sys.exit(f'{ziel}: Kontur berührt den Bildrand – POLSTER erhöhen')
    bild.save(ziel, optimize=True)
    print(f'{ziel} geschrieben: {KANTE}x{KANTE}, Randabstand {d} px, '
          f'{ziel.stat().st_size / 1024:.0f} KB')


if __name__ == '__main__':
    main()
