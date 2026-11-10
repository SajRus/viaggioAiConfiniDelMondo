# PoC 4: modifica dei blocchi

Dimostra selezione DDA, rompi e piazza, ricostruzione del chunk e dei vicini. Criterio di successo: modifica visibile al frame successivo e nessun buco ai bordi tra chunk.

Parte dal codice del PoC 3 e aggiunge `VoxelRaycast` (Amanatides e Woo, portata 5 blocchi), `ChunkManager` (scrive il byte, segna il chunk e i vicini sul bordo, ricostruisce i segnati a fine frame), `BlockEditor` (rompi e piazza, vietato se il blocco occupa lo spazio del giocatore) e l'evidenziazione del blocco mirato.

Il mesher salta gli strati vuoti in cima e scarta subito i blocchi sepolti: il risultato è identico, come confermano test e audit.

Fuori da questo PoC: hotbar (RF-06), registro delle differenze e salvataggio (RF-07), bordi invalicabili (RF-02).

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . --resolution 1920x1080                                     # clic, poi sinistro rompe, destro piazza, WASD, Spazio, Esc
"$GODOT_BIN" --headless --path . --fixed-fps 60 -- --edit-soak --soak-edits=1000 # audit dei bordi, circa 1 minuto
"$GODOT_BIN" --path . --resolution 1920x1080 -- --edit-bench                     # tempi delle modifiche
```

## Misure

Apple M1, Godot 4.7 stable, build di debug dell'editor.

### Nessun buco ai bordi

Modifiche casuali, per il 70% su coordinate di bordo. Dopo ogni modifica, ogni chunk nel raggio di uno viene confrontato con una ricostruzione da zero. Alla fine, il totale delle facce viene confrontato con un conteggio sull'intero mondo che ignora i chunk.

| Modifiche | Chunk disallineati | Facce costruite | Facce attese |
| --- | --- | --- | --- |
| 1.000 (seed 1) | 0 | 221.912 | 221.912 |
| 500 (seed 2, mesher ottimizzato) | 0 | 220.318 | 220.318 |

Controprova in una copia che non segna i chunk vicini: 138 chunk disallineati in 100 modifiche, e 58 facce mancanti.

### Modifica visibile al frame successivo

Con un clic simulato su un blocco d'angolo tra tre chunk, il confronto dei frame registrati mostra un solo cambiamento, nel frame immediatamente successivo al clic.

### Tempo di una modifica

Mesh e collisione di tutti i chunk coinvolti, in finestra, Metal, 1920 × 1080, 60 campioni per classe, 6 esecuzioni.

| Posizione del blocco | Chunk ricostruiti | Mediana | 95° percentile | Massimo |
| --- | --- | --- | --- | --- |
| Interno | 1 | 6,3–6,7 ms | 7,0–11,1 ms | 16,7 ms |
| Bordo | 2 | 11,3–11,7 ms | 12,9–13,3 ms | 13,6 ms |
| Angolo | 3 | 15,9–16,2 ms | 18,1–20,4 ms | 24,3 ms |
| Angolo del chunk più pieno | 3 | 15,5–15,8 ms | 16,2–17,7 ms | 19,6 ms |

La ricostruzione del singolo chunk rispetta RNF-04. Un blocco d'angolo, circa 4 colonne su 256, può costare un frame in più.
