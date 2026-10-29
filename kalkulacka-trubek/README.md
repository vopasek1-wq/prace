# Řezání trubek na míru

Kalkulačka pro řezání lešenářských trubek (ocel Ø 48,3 × 4,05 mm, hliník Ø 48,3 × 4,00 mm) z originální délky
6000 mm s prořezem 3 mm a tolerancí ±5 mm. Je to jediný soubor `index.html` v této složce: stačí ho otevřít
v prohlížeči, nic se neinstaluje a funguje i bez internetu (písmo Open Sans je vložené do souboru).

## Použití

* Zadáš počet kusů a délku (v milimetrech), případně vložíš celý seznam z textu (např. `10 × 3740`). Materiál: ocel nebo hliník.
* Kalkulačka rozloží kusy na co nejmenší počet trubek, seskupí stejné nářezy a ukáže pruh každé trubky v měřítku
  6000 mm (pravítko v metrech, polohy prořezů, odřezek šrafovaně) a přehled délek.
* Barva kusu je v pruhu i v přehledu délek stejná. Barev je 20, u delšího seznamu se přidají odstíny.
* Štítek „Nejmenší možný počet trubek (ověřeno)“ se ukáže, když řešič dokázal, že méně trubek být nemůže.
* Pole **Materiál** odkazuje na stránku produktu na movitech.cz.
* Zadání se pamatuje v prohlížeči. Výsledek jde zkopírovat, poslat e-mailem, stáhnout jako CSV, vytisknout nebo sdílet
  odkazem se zadáním (`#ocel-3740x10-2465x12`, desetinná tečka je `p`). Tisk, CSV, odkaz a e-mail jsou jen ve
  stránce otevřené samostatně, ne ve vloženém náhledu.
* Světlý i tmavý režim podle nastavení zařízení, ovládání z klávesnice a čtečky obrazovky (ověřeno nástrojem axe).

## Jak se počítá

Prořez 3 mm se počítá u každého řezu včetně řezu před zbytkem trubky. Rozložení hledá heuristika (knapsack,
First Fit Decreasing, náhodná pořadí); u menších zadání ho úplné prohledávání ověří jako optimum.

## Testy

Řešič je přímo v `index.html`; testy si ho z něj vyříznou a spustí (Node.js 22+, bez závislostí):

```
node --test "kalkulacka-trubek/test/*.test.js"
```

Testy kontrolují známé příklady, že je každý kus umístěný právě jednou a žádná trubka není přeplněná, a u malých
zadání porovnávají výsledek s přesným minimem. Spouští je i GitHub Actions (`tests-kalkulacka-trubek.yml`).

## Zveřejnění na GitHub Pages

Workflow `.github/workflows/pages-kalkulacka-trubek.yml` nahraje na Pages jen tuto stránku. Jednorázově je potřeba
v *Settings → Pages* nastavit **Source: GitHub Actions**. Adresa: `https://<uživatel>.github.io/prace/kalkulacka-trubek/`.
