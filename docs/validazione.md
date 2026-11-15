# Validazione e QA

Fase 4 del piano in [analisi-progettazione.md](analisi-progettazione.md). Gate 4: zero bug bloccanti e RNF rispettati.

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

Un singolo blocco di circa 1 s è comparso in più esecuzioni, sempre in punti diversi del percorso. È capitato quasi sempre quando il frame rate superava i 60 FPS nonostante il vsync, segno che la finestra non veniva presentata normalmente. Il renderer non c'entra: 0 blocchi in 8 esecuzioni tra Metal e Vulkan. La causa non è confermata. Se compare con tutto chiuso, va trattato come un bug da risolvere prima del gate. Lo strumento ora forza la finestra a 1920 × 1080 e stampa quando avviene ogni blocco oltre 500 ms.

## Requisiti non funzionali

| ID | Target | Stato |
| --- | --- | --- |
| RNF-01 | ≥ 60 FPS a 1080p | Misura pulita di Sajmir: 60 FPS medi, nessun blocco. Cali isolati nell'1% più lento (fino a 30 ms) |
| RNF-02 | 16 × 16 chunk da 16 × 16 × 64 | Rispettato |
| RNF-03 | Generazione ≤ 5 s | Rispettato: 1,7–2,9 s |
| RNF-04 | Ricostruzione del chunk entro un frame (≤ 16 ms) | Mediana 7,6–8,2 ms dopo l'ottimizzazione: da confermare con la misura pulita |
| RNF-05 | Circa 4 MB di dati blocco | Rispettato: 4.194.304 byte |
| RNF-06 | Tipi statici, warning come errori, test | Rispettato |
| RNF-07 | Godot 4.7 | Rispettato |

## Playtest sul Mac

- [ ] Nuovo mondo senza seed: il terreno è diverso a ogni partita
- [ ] Nuovo mondo con un seed: ripetendo lo stesso seed il terreno è identico
- [ ] Camminare, saltare, guardarsi attorno con il mouse
- [ ] Rompere e piazzare con tutti gli 8 blocchi, scelti con i tasti 1–8 e con la rotella
- [ ] Il piazzamento addosso al giocatore viene rifiutato
- [ ] Raggiungere ogni bordo del mondo: non si può uscire
- [ ] Scavare fino in fondo: non si cade fuori dal mondo
- [ ] Modificare blocchi ai bordi tra chunk: nessun buco né scatto evidente
- [ ] Costruire una casetta, Esc, Salva, Menu principale, Carica: la casetta è identica
- [ ] Salvare, chiudere il gioco, riaprirlo, Carica: la casetta è identica
- [ ] Riprendi, Menu principale ed Esci funzionano dalla pausa

## Export macOS

Il Mac ha i template di export per Godot 4.6.3, non per la 4.7.

1. Nell'editor: Editor → Manage Export Templates → Download and Install.
2. Project → Export → Add → macOS, con bundle identifier a piacere e firma ad-hoc.
3. Nella scheda Resources, in "Filters to exclude": `tools/*, test/*, poc/*, docs/*`.
4. Export Project e avvio dell'app, poi la misura e il playtest sulla build esportata.
