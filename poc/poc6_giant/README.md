# PoC 6: gigante tra i blocchi

Dimostra l'inseguimento del portatore di mondi sul terreno con alberi: salita dei gradini e muri rotti, senza pathfinding. Criterio di successo: raggiunge il giocatore da 100 blocchi di distanza su 10 seed senza bloccarsi; ogni blocco rotto entro RNF-04.

Il mondo è quello del gioco: terreno versione 2 con sabbia e alberi, 16 × 16 chunk, mesher, chunk manager e collisione copiati da `src/world/`. Le misure delle ricostruzioni sono quindi quelle del gioco.

- `GiantPlanner` decide l'azione del gigante dai blocchi intorno, senza nodi, e si prova nei test. Il gigante cammina dritto verso il giocatore. Se davanti c'è un gradino di un blocco con spazio sopra, salta. Se c'è un muro più alto rompe il blocco più vicino, compresi quelli che servono come spazio per la testa sul gradino. Se è sopra il giocatore, scava sotto i piedi.
- `Giant` è il gigante: un `CharacterBody3D` di 1,8 × 3,8 × 1,8 blocchi con la gravità e il salto del giocatore e 3,5 blocchi al secondo di passo. Rompe al massimo un blocco ogni 0,5 s. Si gira solo il modello: la scatola di collisione resta allineata agli assi, come quella che il pianificatore controlla.

Fuori da questo PoC: colpo a terra, blocco scagliato, salute del gigante, comparsa accanto all'altare.

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . --resolution 1920x1080                                          # clic, WASD, Spazio, Esc; R fa ripartire il gigante da 100 blocchi
"$GODOT_BIN" --headless --path . --fixed-fps 60 -- --giant-chase --world-seed=1         # inseguimento, un paio di secondi
"$GODOT_BIN" --headless --path . --fixed-fps 60 -- --giant-chase --bunker --world-seed=1 # il giocatore è chiuso in un recinto di pietra
"$GODOT_BIN" --path . --resolution 1920x1080 -- --giant-chase --world-seed=5           # in finestra, con i tempi delle ricostruzioni e dei frame
```

Altri argomenti: `--no-vsync` misura il costo reale dei frame; `--shot-dir=<cartella>` salva un'immagine ogni 5 secondi. L'inseguimento esce con codice 1 se il gigante resta fermo: per 15 secondi non si avvicina di almeno un blocco, oppure non arriva entro 300 secondi.

## Misure

Apple M1, Godot 4.7 stable, build di debug dell'editor.

### Raggiunge il giocatore da 100 blocchi

Il giocatore resta fermo al centro del mondo. Il gigante parte da almeno 100 blocchi, da un lato diverso per ogni seed, su terreno libero da alberi.

| Seed | Dislivello | Campo aperto: tempo, salti, blocchi rotti | Con il recinto: tempo, blocchi rotti (di cui pietra) |
| --- | --- | --- | --- |
| 1 | +1 | 148,7 s, 36, 252 | 150,8 s, 256 (4) |
| 2 | +3 | 73,3 s, 24, 95 | 79,6 s, 107 (12) |
| 3 | +4 | 82,4 s, 21, 118 | 87,4 s, 129 (11) |
| 4 | +3 | 78,0 s, 19, 106 | 85,5 s, 122 (16) |
| 5 | −7 | 65,5 s, 29, 83 | 77,1 s, 107 (26) |
| 6 | −2 | 96,9 s, 22, 146 | 102,6 s, 158 (12) |
| 7 | −16 | 129,4 s, 35, 218 | 139,4 s, 238 (20) |
| 8 | −3 | 136,6 s, 28, 228 | 139,7 s, 234 (6) |
| 9 | +9 | 79,1 s, 26, 110 | 83,6 s, 119 (11) |
| 10 | −6 | 94,8 s, 33, 140 | 102,5 s, 155 (11) |

Il gigante arriva su tutti i 20 percorsi. Il recinto è un anello di pietra a 3 blocchi dal giocatore, alto 4 blocchi sopra il terreno più alto lì intorno. Dove rompe poca pietra, il gigante è sceso scavando da una chioma che sporge sul muro.

Quasi tutti i blocchi rotti sono foglie: un gigante alto 4 blocchi passa nelle chiome. Le foglie prendono la maggior parte del tempo, perché il gigante rompe un blocco ogni 0,5 s.

Tre difetti trovati e corretti durante le prove, ognuno con una controprova:

- La scatola di collisione ruotava con il gigante. In diagonale sporgeva oltre quella del pianificatore, toccava foglie che lui non vedeva e il gigante restava fermo in `WALK` (seed 1, a 72 blocchi).
- Arrivato su una chioma sopra il giocatore, il gigante non aveva una direzione verso cui camminare: restava fermo (seed 1 con il recinto). Ora scava sotto i piedi.
- Il recinto lasciava buchi sotto gli alberi, e su un pendio era un gradino da saltare. Era un errore dello scenario di prova, non del gigante.

### Ogni blocco rotto entro RNF-04

Tempo di ricostruzione di mesh e collisione dopo ogni blocco rotto: 1–3 chunk, sul main thread con il WorkerThreadPool, come nel gioco.

| Prova | Ricostruzioni | Mediana | 95° percentile | Massimo | Oltre 16,7 ms |
| --- | --- | --- | --- | --- | --- |
| Headless, 10 seed | 1.300 circa | 4,1–5,7 ms | 7,2–12,6 ms | 8,3–118,9 ms | 5 |
| Finestra 1080p, seed 2 con il recinto | 107 | 13,0 ms | 23,9 ms | 24,9 ms | 31 |
| Finestra 1080p, seed 5 | 83 | 16,2 ms | 24,0 ms | 25,2 ms | 21 |
| Finestra 1080p, seed 9 | 110 | 16,4 ms | 25,2 ms | 34,4 ms | 43 |
| Finestra 1080p, seed 5, senza vsync | 83 | 15,7 ms | 23,5 ms | 25,2 ms | 13 |

In finestra la mediana rientra in RNF-04, ma il 15–40% delle rotture lo supera, fino a 25 ms e una volta 34 ms (3 chunk). Sono gli stessi valori delle modifiche del giocatore al gate 4 (mediana 11,8–15,98 ms, massimo 24,75 ms), accettate allora sulla mediana. Il gigante non aggiunge costo, perché rompe al massimo 2 blocchi al secondo, e ogni ricostruzione è quella di una modifica del giocatore. Il criterio "ogni blocco entro RNF-04" non è soddisfatto alla lettera: vale lo stesso limite noto del gioco. Sajmir lo ha accettato sulla mediana il 25 novembre 2026, come al gate 4.

### Frame

| Prova | Mediana | 95° percentile | Massimo |
| --- | --- | --- | --- |
| Seed 5, vsync | 16,7 ms | 18,0 ms | 30,0 ms |
| Seed 9, vsync | 16,7 ms | 17,9 ms | 36,7 ms |
| Seed 5, senza vsync | 5,7 ms | 7,2 ms | 27,1 ms |
