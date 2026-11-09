# PoC 3: movimento e collisione

Dimostra un `CharacterBody3D` sulle forme di collisione dei chunk. Criterio di successo: nessun attraversamento dei blocchi in una sessione di test e collisione ricostruita entro un frame (RNF-04, ≤ 16 ms).

Parte dal codice del PoC 2. Ogni chunk è uno `StaticBody3D` con una `ConcavePolygonShape3D` generata dalle stesse facce della mesh. Il giocatore è un box di 0,6 × 1,8 × 0,6 che non ruota: gira solo la testa. Motore fisico: Jolt.

Fuori da questo PoC: rompere e piazzare blocchi (PoC 4), bordi invalicabili del mondo (RF-02).

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . --resolution 1920x1080                                  # clic, WASD, Spazio, R ricostruisce il chunk, Esc
"$GODOT_BIN" --headless --path . --fixed-fps 60 -- --soak --soak-seed=1       # bot per 30 minuti simulati
"$GODOT_BIN" --path . --resolution 1920x1080 -- --rebuild-bench               # tempi di ricostruzione
```

## Misure

Apple M1, Godot 4.7 stable, build di debug dell'editor.

### Attraversamento

Un bot guida il giocatore a caso tra terreno, pilastri e tettoie alte due blocchi, con salti frequenti. A ogni tick un controllo sulla griglia dei blocchi, indipendente dal motore fisico, verifica che il box non entri in un blocco, con 2 cm di tolleranza.

| Seed | Tempo simulato | Blocchi percorsi | Dentro un blocco | Cadute dal mondo |
| --- | --- | --- | --- | --- |
| 1 | 30 min | 7.158 | 0 | 0 |
| 2 | 30 min | 7.121 | 0 | 0 |
| 3 | 30 min | 7.188 | 0 | 0 |
| 4 | 30 min | 7.182 | 0 | 0 |

Controprova in una copia con le collisioni disattivate: 3.160 violazioni in 1 minuto simulato.

### Ricostruzione di un chunk

In finestra, Metal, 1920 × 1080, 30 iterazioni, 3 esecuzioni. Il totale è per singola iterazione.

| Chunk | Facce | Mesh, mediana | Collisione, mediana | Totale, mediana | Totale, massimo |
| --- | --- | --- | --- | --- | --- |
| Sotto il giocatore | 736 | 5,7–5,9 ms | 1,5 ms | 7,2–7,4 ms | 9,8 ms |
| Il più pieno del mondo | 1.862 | 8,7–8,9 ms | 3,2 ms | 11,8–12,1 ms | 13,5 ms |

In headless, dove i tick non sono legati al rendering, il ciclo con ricostruzione costa solo circa 0,1 ms più della ricostruzione stessa: il motore fisico adotta la nuova forma senza costi visibili.

Caricamento dei 256 chunk con collisioni: 2,0–2,3 s in finestra (RNF-03: ≤ 5 s).
