# PoC 2: mondo intero

Dimostra che 256 chunk si generano e si renderizzano sul Mac con Forward+. Criterio di successo: RNF-01 (≥ 60 FPS a 1080p) e RNF-03 (generazione ≤ 5 s).

Parte dal codice del PoC 1 e aggiunge generazione da FastNoiseLite con seed, culling oltre i bordi del chunk e caricamento distribuito su più frame. I chunk conoscono i quattro vicini tramite riferimenti deboli, per non creare cicli di memoria.

Fuori da questo PoC: collisioni (PoC 3), modifica dei blocchi (PoC 4).

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . --resolution 1920x1080                      # clic, WASD e Q/E per volare, Esc libera il mouse
"$GODOT_BIN" --path . --resolution 1920x1080 -- --bench-vsync     # percorso fisso di 20 s, come si gioca
"$GODOT_BIN" --path . --resolution 1920x1080 -- --bench           # stesso percorso, vsync disattivato
```

## Misure

Apple M1, Godot 4.7 stable, Metal, build di debug dell'editor, viewport 1920 × 1080, 256 chunk.

| Misura | Risultato | Target |
| --- | --- | --- |
| Caricamento completo, 15 esecuzioni | 1,55–1,92 s | ≤ 5 s |
| Generazione dati | 0,13–0,16 s | |
| Mesh, media per chunk | circa 5 ms | |
| FPS medio con vsync, 6 esecuzioni | 122–145 | ≥ 60 |
| 1% peggiore con vsync | 7,7–17,6 ms | |
| Frame peggiore con vsync | 15–44 ms, isolati | |

Con vsync disattivato il FPS medio è tra 141 e 198, ma in 3 esecuzioni su 9 compare un singolo blocco di circa 1 s, in punti diversi del percorso. Con vsync attivo non è comparso in 6 esecuzioni. La causa non è confermata.
