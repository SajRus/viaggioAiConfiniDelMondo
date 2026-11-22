# Validazione e QA

Fase 4 del piano in [analisi-progettazione.md](analisi-progettazione.md). Gate 4: zero bug bloccanti e RNF rispettati.

**Gate 4 approvato da Sajmir il 15 novembre 2026**, dopo il playtest completo sul Mac. RNF-04 è accettato sulla mediana; i massimi oltre 16 ms restano un limite noto.

## Verifiche automatiche

| Verifica | Come si esegue | Esito |
| --- | --- | --- |
| Unit test e integrazione | CI a ogni push e PR, oppure il comando in `CLAUDE.md` | 154 test verdi |
| Prova di resistenza | `play_soak.tscn` (sotto) | Vedi sotto |

La prova di resistenza gioca da sola nel gioco finale: un bot cammina e salta mentre piazza e rompe blocchi attorno al giocatore, e a ogni tick controlla sulla griglia che il giocatore non sia dentro un blocco. Alla fine confronta le facce costruite con un conteggio indipendente.

| Seed | Tempo simulato | Piazzati | Rotti | Dentro un blocco | Fuori dal mondo | Facce costruite e attese |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 30 min | 499 | 3.568 | 0 | 0 | Uguali |
| 2 | 30 min | 510 | 3.611 | 0 | 0 | Uguali |
| 1, con meshing in parallelo | 30 min | 499 | 3.568 | 0 | 0 | Uguali |
| 2, con scansione divisa in fasce | 30 min | 510 | 3.611 | 0 | 0 | Uguali |

Prima della correzione del piazzamento, il seed 1 dava 40 tick con il giocatore dentro un blocco.

## Misura delle prestazioni

Da eseguire **con il gioco e l'editor chiusi e il Mac collegato alla corrente**. Ogni esecuzione aggiunge una riga a `user://perf_log.csv`.

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --path . res://tools/qa/perf_run.tscn --resolution 1920x1080
```

Il percorso dura 30 secondi, sorvola il mondo a 1080p con il vsync attivo e modifica un blocco ogni 45 frame.

### Ottimizzazione della ricostruzione

La misura pulita di Sajmir ha dato una modifica mediana di 24,75 ms, oltre RNF-04. Misurando le fasi una per una, dopo qualche minuto di carico tutte rallentavano insieme di circa 2,3 volte, anche il codice nativo: il Mac scende di frequenza. Il costo maggiore era il mesher in GDScript.

- Il mesher annota le facce visibili e le scrive poi in array dimensionati una volta sola. Su 256 chunk con 233.730 facce il risultato è identico al precedente e il tempo scende del 18%.
- Quando una modifica tocca più chunk, il loro meshing gira in parallelo sul WorkerThreadPool, in media su 1,3–1,6 chunk per modifica.
- Dopo una seconda misura di Sajmir (mediana 18,20 ms), anche la scansione del singolo chunk si divide in 4 fasce di altezza su thread diversi. Le fasce unite in ordine danno la stessa lista di facce di una scansione unica, come verificano i test.

| Condizione, 1080p con vsync, Mac a batteria | Modifica, mediana | Modifica, massimo |
| --- | --- | --- |
| Prima, a Mac caldo | 24,8–28,4 ms | 31,8–32,9 ms |
| Dopo, 2 esecuzioni a 60 FPS | 7,6–8,2 ms | 15,8–16,4 ms |
| Dopo, 1 esecuzione a 118 FPS | 20,4 ms | 38,1 ms |
| Misura di Sajmir dopo il meshing in parallelo, 60 FPS | 18,2 ms | 26,1 ms |
| Con scansione divisa, 4 esecuzioni a 117–144 FPS, collegato alla corrente | 7,5–12,7 ms | 20,9–35,5 ms |
| Misura di Sajmir con scansione divisa, 60 FPS a 1080p | 15,98 ms | 24,75 ms |
| Misura di Sajmir con scansione divisa, 59–60 FPS, finestra a 2880 × 1800 | 11,8–12,0 ms | 16,8–20,2 ms |
| 5a con alberi, prima di togliere le facce tra foglie, 2 esecuzioni a 60 FPS | 11,7–13,7 ms | 19,8–31,9 ms |
| 5a con alberi e senza facce tra foglie, 2 esecuzioni a 60 FPS | 8,8–10,2 ms | 15,9–17,0 ms |

Nelle esecuzioni a più di 60 FPS la finestra non era sincronizzata con lo schermo a 60 Hz, quindi il carico di disegno è più alto del normale. Il dato per il gate è una misura a 60 FPS.

### Misure registrate

Apple M1, Metal, build di debug dell'editor, 1920 × 1080, con vsync.

| Condizione | FPS medio | 1% più lento | Modifica, mediana | Caricamento |
| --- | --- | --- | --- | --- |
| 5 esecuzioni, Mac a batteria con un'altra istanza del gioco aperta | 59,9–60,0 | 17,5–28,6 ms | 12,5–27,1 ms | Non rilevato |
| 3 esecuzioni precedenti, stesse condizioni non controllate | 65,7–144,2 | 10,6–18,9 ms | 8,8–9,8 ms | 1,85–2,92 s |
| 3 esecuzioni, Mac a batteria con un altro processo Godot aperto | 59,9–105,1 | 17,8–26,7 ms | 8,0–23,7 ms | 1,80–1,84 s |
| 1 esecuzione a 2880 × 1800, non a 1080p | 61,2 | 32,3 ms | 24,0 ms | 1,81 s |

Queste misure non sono pulite: la riga da usare per il gate è quella che si ottiene con il comando sopra, verificando che il viewport stampato sia 1920 × 1080. La build di release, ancora da provare, è di norma più veloce.

Un singolo blocco di circa 1 s è comparso in più esecuzioni, sempre in punti diversi del percorso. È capitato quasi sempre quando il frame rate superava i 60 FPS nonostante il vsync, segno che la finestra non veniva presentata normalmente. Il renderer non c'entra: 0 blocchi in 8 esecuzioni tra Metal e Vulkan. La causa non è confermata. Se compare con tutto chiuso, va trattato come un bug da risolvere prima del gate. Lo strumento stampa quando avviene ogni blocco oltre 500 ms.

Nella misura di Sajmir con la scansione divisa il blocco è ricomparso una volta (1.008 ms a 5,4 s), in un'esecuzione a 59 FPS in cui macOS aveva portato la finestra a tutto schermo. Durare quasi esattamente 1 s fa pensare a un'attesa con timeout nella presentazione della finestra, non al codice del gioco, ma resta un'ipotesi.

Lo strumento ora disegna la scena sempre a 1920 × 1080, anche se macOS ridimensiona la finestra, e stampa sia la risoluzione di disegno sia quella della finestra. Con il vsync ogni frame dura circa 16,67 ms con qualche oscillazione, quindi al posto dei frame oltre 16,67 ms conta i frame saltati, cioè quelli oltre 25 ms.

## Requisiti non funzionali

| ID | Target | Stato |
| --- | --- | --- |
| RNF-01 | ≥ 60 FPS a 1080p | Misura pulita di Sajmir: 60 FPS medi, nessun blocco. Cali isolati nell'1% più lento (fino a 30 ms) |
| RNF-02 | 16 × 16 chunk da 16 × 16 × 64 | Rispettato |
| RNF-03 | Generazione ≤ 5 s | Rispettato: 1,7–2,9 s |
| RNF-04 | Ricostruzione del chunk entro un frame (≤ 16 ms) | Misure di Sajmir: mediana 11,8–15,98 ms, massimo fino a 24,75 ms. La mediana rientra, al limite a 1080p. Ogni modifica ricostruisce fino a 3 chunk |
| RNF-05 | Circa 4 MB di dati blocco | Rispettato: 4.194.304 byte |
| RNF-06 | Tipi statici, warning come errori, test | Rispettato |
| RNF-07 | Godot 4.7 | Rispettato |

## Playtest sul Mac

- [x] Nuovo mondo senza seed: il terreno è diverso a ogni partita
- [x] Nuovo mondo con un seed: ripetendo lo stesso seed il terreno è identico
- [x] Camminare, saltare, guardarsi attorno con il mouse
- [x] Rompere e piazzare con tutti gli 8 blocchi, scelti con i tasti 1–8 e con la rotella
- [x] Il piazzamento addosso al giocatore viene rifiutato
- [x] Raggiungere ogni bordo del mondo: non si può uscire
- [x] Scavare fino in fondo: non si cade fuori dal mondo
- [x] Modificare blocchi ai bordi tra chunk: nessun buco né scatto evidente
- [x] Costruire una casetta, Esc, Salva, Menu principale, Carica: la casetta è identica
- [x] Salvare, chiudere il gioco, riaprirlo, Carica: la casetta è identica
- [x] Riprendi, Menu principale ed Esci funzionano dalla pausa

## Playtest della sottofase 5a

**Gate 5a approvato da Sajmir il 21 novembre 2026.**

Sulla build esportata, con un nuovo mondo in sopravvivenza.

- [x] Il menu propone Creativa e Sopravvivenza; un mondo creativo funziona come prima
- [x] All'inizio la salute è 20/20 e l'inventario è vuoto
- [x] Rompere tenendo premuto il clic sinistro: l'incrinatura cresce in 4 stadi, rilasciare o cambiare blocco azzera
- [x] Il blocco rotto entra nell'inventario; l'erba dà terra, foglie e vetro non danno nulla
- [x] Piazzare consuma un blocco dalla hotbar; con il posto vuoto o un piccone non si piazza nulla
- [x] E apre e chiude l'inventario; un clic prende una pila, un secondo clic la posa, la unisce o la scambia
- [x] Un mondo nuovo ha alberi sulle colline e sabbia nelle valli; un tronco rotto dà un tronco
- [x] Le 4 ricette si attivano solo con gli ingredienti e producono il risultato
- [x] La pietra a mani nude richiede circa 4 s, con il piccone di legno 1,5 s e con quello di pietra meno di 1 s
- [x] Un salto sul piano non toglie salute; una caduta da 6 blocchi toglie 3 punti
- [x] La salute risale di un punto ogni 4 secondi
- [x] A salute zero compare "Sei caduto"; Rinasci riporta al punto di partenza con salute piena e lo stesso inventario
- [x] Esc, Salva, Menu principale, Carica: salute e inventario sono quelli salvati
- [x] Il salvataggio di prima della 5a si carica ancora, come mondo creativo

## Export macOS

Il preset è in `export_presets.cfg`: binario universale, firma ad-hoc, senza notarizzazione. Esclude `tools/`, `test/`, `poc/`, `docs/` e `addons/`. Servono i template di export della 4.7 (Editor → Manage Export Templates → Download and Install). Per esportare l'architettura arm64 la 4.7 richiede l'importazione delle texture ETC2/ASTC, attiva in `project.godot`.

```sh
"$GODOT_BIN" --headless --path . --export-release "macOS" "build/macos/Viaggio ai confini del mondo.app"
open "build/macos/Viaggio ai confini del mondo.app"
```

La build esportata pesa 164 MB e si avvia senza errori. Gli strumenti di `tools/qa/` non sono inclusi, quindi la misura delle prestazioni resta sulla build dell'editor.
