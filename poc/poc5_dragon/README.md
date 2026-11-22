# PoC 5: drago in volo

Dimostra il ciclo del Drago dei Confini sopra un'arena: volo in cerchio, picchiata sul giocatore, 3 secondi a terra e ritorno in volo. Il giocatore lo colpisce solo mentre è a terra. Criterio di successo: 50 cicli di fila senza blocchi; il drago si sconfigge in un combattimento di prova; 60 FPS.

- `DragonBrain` è il volo senza nodi: una macchina a stati (`CIRCLING`, `DIVING`, `LANDED`, `RISING`, `DEFEATED`) che si prova nei test. Il drago non esce mai dalla colonna d'aria sopra l'arena, quindi non deve evitare nulla. La picchiata punta i piedi del giocatore, tenuti dentro l'arena a 2 blocchi dal bordo, e lo colpisce una volta sola: 4 danni e una spinta.
- `Dragon` è il drago a schermo, fatto di cubi colorati: ali che battono in volo e restano tese in picchiata; il corpo diventa rosso per un istante quando viene colpito.
- `Combat` gestisce i colpi del giocatore. La portata è di 3,5 blocchi, con un colpo ogni 0,5 s, a segno o no. Il danno è 1 a mani nude, 2 col piccone, 3 con la spada di legno e 5 con quella di pietra.
- `ArenaBot` gioca al posto di una persona. Vaga per l'arena e appena fuori, a volte resta fermo sotto il drago; se combatte, corre dal drago atterrato e colpisce.

L'arena è una piattaforma di 15 × 15 blocchi su un prato, senza voxel: il rischio isolato è il volo, non il terreno.

Fuori da questo PoC: l'innesco quando il giocatore sale sull'arena, la gemma lasciata dal drago, il salvataggio, la precedenza tra colpire il drago e rompere un blocco.

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . --resolution 1920x1080                                                  # clic, WASD, Spazio, sinistro colpisce, 1–4 arma, R ricomincia, Esc
"$GODOT_BIN" --headless --path . --fixed-fps 60 -- --dragon-soak --cycles=50 --soak-seed=1     # prova di resistenza, pochi secondi
"$GODOT_BIN" --path . --resolution 1920x1080 -- --dragon-fight --weapon=wooden                 # combattimento del bot, con i tempi dei frame
"$GODOT_BIN" --path . --resolution 1920x1080 -- --dragon-fight --weapon=wooden --no-vsync      # costo reale di un frame
```

`--weapon` accetta `hand`, `pickaxe`, `wooden` e `stone`. `--shot-dir=<cartella>` salva un'immagine per ogni stato del drago. Le due prove escono con codice 1 se qualcosa non va.

## Misure

Apple M1, Godot 4.7 stable, build di debug dell'editor.

### 50 cicli senza blocchi

A ogni frame fisico la prova controlla che il drago resti nella colonna d'aria sopra l'arena e che nessuno stato superi il suo limite più un frame. Il limite di picchiata e risalita è la diagonale più lunga del volume di volo divisa per la velocità. Il giocatore non muore, così il drago non si azzera a metà prova.

| Seed | Cicli | Tempo simulato | Picchiate a segno | Problemi |
| --- | --- | --- | --- | --- |
| 1 | 50 | 572,5 s | 17 | 0 |
| 2–10 | 50 ciascuno | — | 12–20 | 0 |

| Stato | Più lungo (seed 1) | Limite |
| --- | --- | --- |
| In cerchio | 6,00 s | 6,00 s |
| Picchiata | 1,13 s | 1,41 s |
| A terra | 3,00 s | 3,00 s |
| Risalita | 1,60 s | 2,82 s |

Controprova con la picchiata rallentata a metà velocità: la prova segnala `DIVING dura 1,43 s, oltre il limite di 1,41 s` ed esce con codice 1.

### Combattimento di prova

Il bot, seed 1, sempre a segno quando il drago è a terra:

| Arma | Tempo | Colpi | Picchiate subite | Morti |
| --- | --- | --- | --- | --- |
| Spada di pietra | 20,9 s | 12 | 2 (8 danni) | 0 |
| Spada di legno | 42,0 s | 20 | 2 (8 danni) | 0 |
| Piccone | 55,5 s | 30 | 2 (8 danni) | 0 |
| Mano | 113,1 s | 60 | 3 (12 danni) | 0 |

Il drago si sconfigge con ogni arma. Il bot colpisce 6 volte per atterraggio, quindi il combattimento è facile; una persona sarà più lenta. Il bilanciamento si rivede nel playtest della 5b.

### 60 FPS

Combattimento con la spada di legno in finestra a 1920 × 1080, Metal. Esclusi i primi 2 secondi di caricamento.

| Vsync | Frame | Mediana | 95° percentile | Massimo |
| --- | --- | --- | --- | --- |
| Sì | 1.838 | 16,7 ms | 19,0 ms | 297,2 ms* |
| No | 7.994 | 3,2 ms | 8,1 ms | 25,5 ms |

\* Salvataggio delle immagini con `--shot-dir` durante la misura.

Senza vsync un frame costa 3,2 ms di mediana: il drago e il combattimento sono lontani dal limite di 16,7 ms. Con il vsync il 12% dei frame misura più di 17,7 ms, come nelle misure del gioco: è il ritmo della presentazione, non il costo del frame. Da confermare a occhio sul Mac.
