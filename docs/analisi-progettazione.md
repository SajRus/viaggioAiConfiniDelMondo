# Viaggio ai confini del mondo — Analisi e progettazione

Versione dell'8 novembre 2026 · fonte di verità del progetto

## Visione e scope

Viaggio ai confini del mondo è un sandbox voxel 3D in prima persona, piccolo e finito: un mondo generato proceduralmente in cui si rompono e piazzano blocchi. Prima un MVP creativo che valida il motore voxel, poi una fase 2 di sopravvivenza base.

| Tema | Scelta | Perché |
| --- | --- | --- |
| Nome | Viaggio ai confini del mondo | Richiama il mondo finito con bordi invalicabili (RF-02) |
| Visuale | 3D voxel, prima persona | È il cuore dell'idea |
| Modalità | Creativa nell'MVP, sopravvivenza in fase 2 | Il motore voxel è il rischio principale: va validato prima del gameplay |
| Linguaggio | GDScript con tipizzazione statica | Nativo in Godot, iterazione rapida, errori intercettati prima |
| Piattaforma | Desktop, solo uso locale sul Mac; nessuna pubblicazione | Niente build web né store: cade il vincolo del renderer Compatibility |
| Motore | Godot 4.7, installato sul Mac | Ramo stabile corrente; nessuna migrazione fino a fine MVP |
| Texture | Pixel art 16 × 16, generata con ChatGPT o cercata online | Quelle prese online solo con licenza d'uso, per esempio CC0 |
| Team | Sajmir e il sistema multi-agent | Gli agenti sviluppano, Sajmir approva ogni gate e prova sul Mac |
| Mondo | Finito, non infinito | Elimina streaming dei chunk e gestione della memoria a runtime |

Fuori scope per ora: multiplayer, mondo infinito, nemici e IA, logica tipo redstone, biomi multipli, acqua fluida, illuminazione per singolo blocco, supporto mod, controlli touch, build web e pubblicazione.

Le meccaniche voxel sono libere da usare, il marchio e gli asset di Minecraft no: le texture si generano con ChatGPT o si prendono online solo con una licenza che lo consenta.

## Requisiti funzionali

L'MVP ha 6 requisiti Must, tutti al servizio di un solo ciclo di gioco: muoversi, mirare, rompere, piazzare. La fase 2 parte solo dopo che l'MVP ha superato validazione e QA.

### MVP: modalità creativa

| ID | Requisito | Priorità |
| --- | --- | --- |
| RF-01 | Generazione del terreno da rumore con seed configurabile: colline, erba in superficie, terra sotto, pietra in profondità | Must |
| RF-02 | Mondo finito con bordi invalicabili | Must |
| RF-03 | Movimento in prima persona: WASD, mouse look, salto, gravità, collisione con i blocchi | Must |
| RF-04 | Rompere il blocco mirato (click sinistro), con evidenziazione del blocco sotto il mirino | Must |
| RF-05 | Piazzare un blocco sulla faccia mirata (click destro), vietato se occupa lo spazio del giocatore | Must |
| RF-06 | Hotbar con 6–8 tipi di blocco, selezione con tasti numerici o rotella | Must |
| RF-07 | Salvataggio e caricamento del mondo | Should |
| RF-08 | Menu principale e menu di pausa: nuovo mondo, carica, esci | Should |
| RF-09 | Alberi semplici generati sul terreno | Could |
| RF-10 | Volo in modalità creativa | Could |
| RF-11 | Ciclo giorno/notte visivo | Could |

### Fase 2: sopravvivenza base

| ID | Requisito | Priorità |
| --- | --- | --- |
| RF-20 | Salute, danno da caduta e respawn | Must |
| RF-21 | Inventario con quantità: i blocchi rotti entrano in inventario, piazzarli li consuma | Must |
| RF-22 | Sconfiggere l'Ender Drago | Must |
| RF-23 | Trovare tutte e 5 le gemme madre | Must |
| RF-24 | Sconfiggere il portatore di mondi | Must |
| RF-25 | Tempo di rottura diverso per tipo di blocco | Should |
| RF-26 | Crafting minimo: 3–5 ricette | Should |
| RF-27 | Fame | Could |
| RF-28 | Nemici con IA semplice | Won't (per ora) |

## Requisiti non funzionali

Il gioco deve girare a 60 FPS sul Mac di sviluppo. Senza build web cade il vincolo del renderer Compatibility: si parte con il renderer predefinito (Forward+) e lo si conferma nel PoC 2. I target sotto sono ipotesi di progetto: i PoC li confermano o li correggono.

| ID | Requisito | Target | Come si misura |
| --- | --- | --- | --- |
| RNF-01 | Frame rate | ≥ 60 FPS a 1080p sul Mac di sviluppo | Monitor prestazioni di Godot su un percorso di prova fisso |
| RNF-02 | Dimensione del mondo | 16 × 16 chunk da 16 × 16 × 64 blocchi: 256 × 256 × 64, circa 4,2 milioni di blocchi | Parametro configurabile, valore finale fissato dai PoC |
| RNF-03 | Tempo di generazione del mondo | ≤ 5 s | Timer nel codice |
| RNF-04 | Reattività alla modifica di un blocco | Ricostruzione del chunk entro un frame (≤ 16 ms) | Profiler di Godot |
| RNF-05 | Memoria dei dati blocco | Circa 4 MB (1 byte per blocco) | Calcolo e monitor memoria |
| RNF-06 | Qualità del codice | GDScript con tipi statici, warning trattati come errori, test automatici sui moduli logici | Pipeline di CI su GitHub Actions |
| RNF-07 | Versione del motore | Godot 4.7, installato sul Mac | Fissata nel progetto |

Sul Mac è installato Godot 4.7, il ramo stabile corrente, la cui patch più recente è la 4.7.2 del 16 agosto 2026 ([endoflife.date](https://endoflife.date/godot)). La 4.8 è in beta dal 15 ottobre 2026 ([annuncio](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-1/)) e si valuta solo dopo l'MVP.

## Architettura

L'architettura separa i dati dalla loro rappresentazione: i chunk tengono i byte, il ChunkMesher ne ricava grafica e collisioni, e il giocatore agisce solo attraverso il ChunkManager.

```text
Giocatore (CharacterBody3D, camera FPS)  ──>  Interazione blocchi (selezione DDA, 5 blocchi)  <──  HUD (mirino, hotbar)
      ▲                                                  │
      │ collisioni dei chunk                             │ get_block / set_block
      │                                                  ▼
World (scena del mondo)
├── ChunkManager       scrive i byte del blocco, marca i chunk modificati ──> ChunkMesher
├── TerrainGenerator   FastNoiseLite + seed, riempie i chunk all'avvio
├── ChunkMesher        face culling + atlante, rifà solo i chunk marcati ──> mesh e collisione dei chunk
└── Chunk × 256        16 × 16 × 64 byte di dati, mesh e collisione propri

Autoload
├── SaveSystem         seed, giocatore, differenze in user://   <──>  World
└── BlockRegistry      tipi di blocco, flag, coordinate nell'atlante  ──>  ChunkMesher
```

Rompere o piazzare un blocco cambia un solo byte; i chunk marcati vengono ricostruiti a fine frame. BlockRegistry e SaveSystem sono autoload, cioè singleton globali di Godot.

## Modello dati e algoritmi chiave

Il mondo è una griglia di byte divisa in chunk: mesh, collisioni e salvataggi si ricavano tutti da quella griglia, che resta l'unica fonte di verità.

### Blocchi

- ID a 8 bit: 0 è l'aria, fino a 255 tipi.
- Il registro dei blocchi definisce per ogni tipo: nome, coordinate nell'atlante delle texture per faccia (sopra, lato, sotto), solido sì/no, trasparente sì/no.
- Set iniziale: erba, terra, pietra, sabbia, tronco, foglie, assi, vetro. Ogni texture è un PNG di 16 × 16 pixel esatti; l'atlante si importa Lossless e il materiale usa il filtro Nearest, così i pixel restano netti.

### Chunk

Ogni chunk misura 16 × 16 × 64 blocchi e tiene i dati in un PackedByteArray da 16.384 byte. L'indice di un blocco nelle coordinate locali del chunk è:

```latex
i = x + 16\,z + 256\,y
```

Ogni chunk ha un flag "da ricostruire" e conosce i quattro chunk vicini sul piano orizzontale.

### Generazione del terreno

- FastNoiseLite, integrato in Godot, produce una mappa delle altezze 2D a partire dal seed del mondo.
- Per ogni colonna: pietra in profondità, 3 blocchi di terra, erba in superficie.
- La generazione è deterministica: stesso seed, stesso mondo. Su questo si basa il salvataggio.
- Gli alberi (RF-09) arrivano in una seconda passata, dopo il terreno.

### Meshing

- Face culling: per ogni blocco solido si emette una faccia solo se il vicino in quella direzione è aria o trasparente, anche oltre il bordo del chunk.
- Output: una ArrayMesh costruita da array impacchettati (vertici, normali, UV, indici), con un solo materiale, atlante delle texture e filtro nearest.
- I blocchi trasparenti (vetro, foglie) finiscono in una seconda superficie della mesh.
- Il greedy meshing, che unisce le facce complanari, entra solo se i PoC mostrano troppi vertici.

### Collisioni

Ogni chunk ha una ConcavePolygonShape3D generata dalle stesse facce della mesh; il giocatore è un CharacterBody3D. Se il PoC 3 mostra ricostruzioni troppo lente, il ripiego è una collisione AABB scritta a mano contro la griglia, senza motore fisico.

### Selezione del blocco

Il mirino usa un attraversamento della griglia voxel per voxel (algoritmo DDA di Amanatides e Woo) con portata di 5 blocchi. Restituisce il blocco colpito e la normale della faccia: rompere scrive 0 in quel blocco, piazzare scrive nel blocco adiacente lungo la normale. Non dipende dalla fisica, quindi si testa con unit test puri.

### Modifica di un blocco

1. `set_block(posizione, id)` aggiorna il byte nel chunk.
2. Il chunk viene segnato da ricostruire; se il blocco è sul bordo, anche il chunk vicino.
3. A fine frame si ricostruiscono mesh e collisione dei soli chunk segnati.
4. La modifica entra nel registro delle differenze usato dal salvataggio.

### Salvataggio

Il file contiene seed, posizione del giocatore e solo i blocchi modificati, raggruppati per chunk. Al caricamento si rigenera il mondo dal seed e si riapplicano le differenze. Formato binario con numero di versione in testa, scritto in `user://`.

### Thread

Nell'MVP tutto gira sul main thread: la generazione avviene dietro una schermata di caricamento, distribuita su più frame. Su desktop i thread sono disponibili: se il PoC 2 lo richiede, generazione e meshing passano al WorkerThreadPool di Godot.

## Piano SDLC

Il lavoro procede in cinque fasi, ognuna chiusa da un gate: nessuna fase parte finché la precedente non ha superato i suoi criteri.

| Fase | Contenuto | Gate di uscita |
| --- | --- | --- |
| 1. Analisi e progettazione | Requisiti e design (questo documento) | Gate 1: documento approvato, decisioni chiuse |
| 2. PoC tecnici | 4 spike isolati, sul Mac | Gate 2: criteri dei PoC superati sul Mac |
| 3. Sviluppo MVP | Requisiti Must e Should, con unit test | Gate 3: Must completati, test verdi |
| 4. Validazione e QA | Test, prestazioni, playtest, export | Gate 4: zero bug bloccanti, RNF rispettati |
| 5. Fase 2: sopravvivenza | Stesso ciclo: analisi, PoC, QA | — |

Se un gate non passa si torna alla fase precedente: un PoC fallito cambia il design, non si aggira dentro l'MVP.

### Chi fa cosa

Il sistema multi-agent sviluppa e testa la logica; Sajmir approva ogni gate e verifica sul Mac tutto ciò che si vede o si misura, perché gli agenti lavorano in cloud e non vedono il gioco.

| Attività | Sistema multi-agent | Sajmir |
| --- | --- | --- |
| Analisi e design | Aggiorna questo documento e le specifiche | Rivede e approva il gate 1 |
| PoC e sviluppo | Scrive GDScript e unit test, apre PR su GitHub | Approva le PR a rischio medio, prova ogni build sul Mac |
| Texture | Script che porta le immagini a 16 × 16 e monta l'atlante | Genera le immagini con ChatGPT o le trova online |
| Validazione e QA | Esegue i test headless in CI | Playtest, misure di prestazione, approvazione dei gate |

Prima del PoC 1 il sistema va attrezzato per Godot: binario headless di Godot 4.7 in CI, gdUnit4 6.2.x e le convenzioni GDScript del progetto (tipi statici, warning come errori).

### PoC tecnici

Ogni PoC è un progetto Godot separato che isola un solo rischio. Il codice dei PoC entra nell'MVP solo dopo una revisione; altrimenti si riscrive pulito.

| PoC | Cosa dimostra | Criterio di successo |
| --- | --- | --- |
| PoC 1: chunk singolo | Dati del chunk, meshing con face culling, atlante delle texture | Chunk visivamente corretto; ricostruzione entro RNF-04 |
| PoC 2: mondo intero | 256 chunk generati e renderizzati sul Mac; conferma del renderer | RNF-01 e RNF-03 rispettati |
| PoC 3: movimento e collisione | CharacterBody3D sulle forme di collisione dei chunk | Nessun attraversamento dei blocchi in una sessione di test; collisione ricostruita entro un frame |
| PoC 4: modifica dei blocchi | Selezione DDA, rompi e piazza, ricostruzione del chunk e dei vicini | Modifica visibile al frame successivo; nessun buco ai bordi tra chunk |

### Validazione e quality assurance

- Unit test con [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), versione 6.2.x, compatibile con Godot 4.7: indice del chunk, generazione deterministica, DDA, face culling, salvataggio e ricaricamento senza perdite.
- Test di integrazione con lo scene runner di gdUnit4: rompere o piazzare un blocco aggiorna mesh e collisione.
- Test di prestazione: un percorso di prova automatico registra FPS e tempi sul Mac a ogni release candidate.
- Playtest sul Mac con checklist di scenari: generare un mondo, costruire una casetta, salvare, ricaricare, ritrovarla identica.
- CI su GitHub Actions: Godot headless e gdUnit4 a ogni push; l'export macOS si fa sul Mac. Repository Git con la cartella `.godot/` esclusa.
- Definition of Done per ogni requisito: codice tipizzato, test verdi, revisione fatta, nessun warning.

## Rischi e decisioni aperte

Il rischio principale è la velocità di GDScript nel meshing: per questo i PoC 1 e 2 vengono prima di qualsiasi gameplay.

| Rischio | Impatto | Mitigazione |
| --- | --- | --- |
| GDScript troppo lento per generare e ricostruire le mesh di 256 chunk | Alto | Misura nei PoC 1 e 2; poi, in ordine: array impacchettati, lavoro spalmato su più frame o su thread (WorkerThreadPool), greedy meshing. Ultima risorsa: meshing in C++ con GDExtension |
| Scope creep verso un "Minecraft completo" | Alto | Backlog con priorità MoSCoW: ciò che non è Must aspetta la chiusura dell'MVP |
| Gli agenti lavorano in cloud e non vedono il gioco né le prestazioni sul Mac | Medio | Logica coperta da unit test in CI; verifica visiva e misure sul Mac prima di ogni gate |
| Le immagini generate con l'AI non sono vera pixel art 16 × 16: risoluzione alta, griglia irregolare, colori sfumati | Medio | Script degli agenti che ridimensiona a 16 × 16 con nearest neighbor e riduce la palette; ritocco a mano dove serve |
| Collisione per chunk lenta da ricostruire o instabile sugli spigoli | Medio | PoC 3; ripiego su collisione AABB scritta a mano contro la griglia |
| Cambiamenti incompatibili passando da Godot 4.7 a 4.8 | Basso | Versione fissata nel progetto; migrazione valutata dopo l'MVP, mai a metà |
| Asset o nome troppo vicini a Minecraft | Basso | Uso privato, nessuna pubblicazione; texture generate o con licenza d'uso, nome originale |

### Decisioni aperte

- [x] Dimensione finale del mondo: 16 × 16 chunk, confermata dopo il PoC 2

## Fonti

- [Godot, cicli di supporto su endoflife.date](https://endoflife.date/godot)
- [Dev snapshot: Godot 4.8 beta 1](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-1/)
- [gdUnit4 su GitHub](https://github.com/godot-gdunit-labs/gdUnit4)
