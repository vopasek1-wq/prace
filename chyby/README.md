# Nahlášené chyby

Tabule chyb webu ve třech sloupcích. Otevři `index.html` (nejlépe přes GitHub Pages nebo lokální server).

| Sloupec | `sloupec` v JSON | Barva |
|---|---|---|
| Závažné chyby | `zavazne` | mírně červená |
| K úpravě | `upravit` | mírně oranžová |
| Hotovo | `hotovo` | mírně zelená |

## Ukládání
* **Napojit GitHub** (vpravo nahoře): vlož fine-grained token s právem *Contents: Read and write* k repozitáři `prace`. Každá změna se pak hned uloží do `chyby/chyby.json` a fotky do `chyby/fotky/`.
* Bez tokenu je tabule **jen ke čtení** (kamarád ji tak může prohlížet bez nastavování).

## Pro Clauda (a další, kdo opravuje)
Všechna data jsou v **`chyby/chyby.json`**:

```json
{ "chyby": [ {
  "id": "c1",
  "sloupec": "zavazne",
  "nazev": "Krátký název",
  "popis": "Co je špatně",
  "stranka": "web-mobilo/index.html",
  "datum": "2026-11-12",
  "fotky": ["fotky/abc123.jpg"]
} ] }
```

Postup (bez tokenu, Claude pracuje přímo v repozitáři):
1. Přečti `chyby/chyby.json`, začni sloupcem `zavazne`, pak `upravit`. Fotky (cesty relativně ke složce `chyby/`) ukazují problém.
2. Oprav chybu v souboru uvedeném ve `stranka`.
3. Přesuň box do hotových: změň `"sloupec"` na `"hotovo"` a do `popis` krátce dopiš, co se opravilo.
4. Boxy nemaž, to dělá autor. Ve stejném commitu změň `chyby.json` i opravený kód.
