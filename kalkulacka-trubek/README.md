# Kalkulace trubek

Kalkulačka pro řezání trubek z originální délky 6000 mm s prořezem 3 mm. Je to jediný soubor
`index.html` v této složce: stačí ho otevřít v prohlížeči, nic se neinstaluje.

* Zadáš počet kusů a délku (v milimetrech), případně vložíš celý seznam z textu. Materiál: ocel nebo hliník.
* Kalkulačka rozloží kusy na co nejmenší počet trubek, seskupí stejné nářezy a ukáže odřezky a přehled délek.
* Prořez 3 mm se počítá u každého řezu včetně řezu před zbytkem trubky.
* Rozložení hledá heuristika (knapsack + First Fit Decreasing); u menších zadání ho úplné prohledávání ověří jako optimum.
* Výsledek jde vytisknout nebo poslat e-mailem (v souboru otevřeném z disku). Zadání se pamatuje v prohlížeči.
