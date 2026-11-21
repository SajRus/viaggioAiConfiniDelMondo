# Viaggio ai confini del mondo — Analisi e progettazione

Versione del 15 novembre 2026 · fonte di verità del progetto

L'MVP ha chiuso il gate 4 il 15 novembre 2026. Questa versione aggiunge l'analisi della fase 2, sopravvivenza, divisa nelle sottofasi 5a e 5b.

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

Fuori scope per ora: multiplayer, mondo infinito, nemici comuni e la loro IA (in 5b combattono solo i due boss), logica tipo redstone, biomi multipli, acqua fluida, illuminazione per singolo blocco, supporto mod, controlli touch, build web e pubblicazione.

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
| RF-09 | Alberi semplici generati sul terreno | Could, anticipato nella 5a: il crafting ha bisogno di legno |
| RF-10 | Volo in modalità creativa | Could |
| RF-11 | Ciclo giorno/notte visivo | Could |

### Fase 2: sopravvivenza base

La fase 2 si divide in due sottofasi, ognuna con il proprio gate. La 5a porta la sopravvivenza senza combattimento; la 5b il viaggio verso il finale, con un'analisi propria che parte solo dopo il gate 5a.

| ID | Requisito | Priorità | Sottofase |
| --- | --- | --- | --- |
| RF-20 | Salute, danno da caduta e respawn | Must | 5a |
| RF-21 | Inventario con quantità: i blocchi rotti entrano in inventario, piazzarli li consuma | Must | 5a |
| RF-22 | Sconfiggere il Drago dei Confini | Must | 5b |
| RF-23 | Trovare tutte e 5 le gemme madre | Must | 5b |
| RF-24 | Sconfiggere il portatore di mondi | Must | 5b |
| RF-25 | Tempo di rottura diverso per tipo di blocco | Should | 5a |
| RF-26 | Crafting minimo: 3–5 ricette | Should | 5a |
| RF-27 | Fame | Could | Dopo 5b |
| RF-28 | Nemici comuni con IA semplice | Could | Dopo 5b |

Il Drago dei Confini è un boss originale: sostituisce il nome della prima stesura, che apparteneva a Minecraft.

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
├── SaveSystem         mondo compresso e giocatore in user://   <──>  World
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
- La generazione è deterministica: stesso seed, stesso mondo.
- Il terreno ha una versione. La versione 1 è quello dell'MVP, solo erba, terra e pietra, e non cambia mai: serve a ricostruire i salvataggi di versione 1. I mondi nuovi usano l'ultima versione.
- Versione 2, introdotta nella 5a perché senza legno e sabbia le ricette sono impossibili:
  - le colonne alte 24 blocchi o meno hanno sabbia al posto di erba e terra, circa il 15–18% della superficie;
  - gli alberi nascono su una griglia di celle da 6 × 6 colonne, al massimo uno per cella con probabilità del 45%, mai sulla sabbia: circa 750 alberi per mondo. Tronco di 4–6 tronchi su un blocco di terra, chioma di foglie larga 5 blocchi;
  - ogni chunk disegna anche le parti degli alberi vicini che lo toccano, così una chioma a cavallo di due chunk resta intera;
  - la generazione del mondo intero passa da circa 140 ms a 220–470 ms.

### Meshing

- Face culling: per ogni blocco solido si emette una faccia solo se il vicino in quella direzione è aria o trasparente, anche oltre il bordo del chunk. Tra due blocchi trasparenti dello stesso tipo, come due foglie o due vetri, non c'è faccia: con gli alberi della 5a le facce tra foglie erano due terzi delle facce trasparenti.
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
3. A fine frame si ricostruiscono mesh e collisione dei soli chunk segnati. Il piazzamento ricostruisce subito, prima della fisica, altrimenti il giocatore può entrare nella cella appena occupata.
4. Il salvataggio legge i blocchi direttamente dai chunk, quindi la modifica non va registrata altrove.

### Salvataggio

Un salvataggio deve sopravvivere a ogni aggiornamento del gioco. Per questo il file contiene il mondo intero e non dipende dal generatore del terreno, che cambierà con la 5b, né dal rumore di Godot, che può cambiare con la 4.8.

- Il file è `user://world.sav`, cioè `~/Library/Application Support/Godot/app_userdata/Viaggio ai confini del mondo/world.sav`. La cartella dipende dal nome del progetto, che quindi non si cambia.
- Formato binario: numero di versione u32 in testa, poi sezioni. Ogni sezione ha un'etichetta di 4 caratteri, la lunghezza in byte e il contenuto.
- Versione 2, quella attuale:
  - sezione `WRLD`: seed, chunk per lato e i 4 MB di blocchi compressi con Zstandard, circa 108 KB (3–4 ms per comprimere, 2 ms per decomprimere);
  - sezione `PLYR`: posizione del giocatore.
- Una nuova sezione si aggiunge senza cambiare versione: chi legge salta le sezioni che non conosce, e una sezione mancante vale come valore di partenza. Cambiare il contenuto di una sezione esistente richiede una nuova versione.
- Ogni versione nuova continua a leggere tutte le precedenti. Un file di versione vecchia si converte al primo caricamento: si copia accanto come `world.sav.v<N>.bak` e si riscrive subito nella versione attuale.
- La versione 1 dell'MVP conteneva seed, posizione e solo i blocchi modificati. Si legge rigenerando la versione 1 del terreno, quella dell'MVP: un test ne fissa l'output.
- Gli ID dei blocchi sono scritti nel file e non si rinumerano mai: un blocco nuovo prende un ID libero.
- Per ogni versione c'è un file d'esempio in `test/save/fixtures/`, che i test caricano a ogni esecuzione della CI.
- La scrittura passa da un file temporaneo, così un salvataggio fallito lascia intatto il precedente.

Questa garanzia copre gli aggiornamenti del gioco, non la cancellazione della cartella né il passaggio a un altro Mac.

### Thread

La generazione avviene sul main thread dietro una schermata di caricamento, distribuita su più frame. Quando una modifica tocca più chunk, il loro meshing gira in parallelo sul WorkerThreadPool di Godot e il main thread lo attende nello stesso frame; mesh e collisione si creano poi sul main thread. La validazione ha mostrato che, dopo qualche minuto di carico, il Mac scende di frequenza e la sola ricostruzione sul main thread superava RNF-04.

## Progettazione della sottofase 5a: sopravvivenza

La 5a aggiunge una modalità sopravvivenza accanto a quella creativa, senza toccare il motore voxel: salute, inventario, tempi di rottura e crafting sono logica di gioco sopra il ChunkManager.

### Modalità di gioco

- Il menu "Nuovo mondo" chiede la modalità: creativa, la scelta di partenza, o sopravvivenza. La modalità si salva con il mondo e non si cambia dopo.
- In creativa tutto resta com'è nell'MVP: hotbar fissa con 8 blocchi infiniti, rottura istantanea, nessun danno.
- In sopravvivenza valgono RF-20, RF-21, RF-25 e RF-26.

### Salute e respawn (RF-20)

- Il giocatore ha 20 punti salute, mostrati nell'HUD come una barra sopra la hotbar.
- Danno da caduta: il giocatore registra la quota più alta raggiunta da quando ha lasciato il terreno. All'atterraggio perde 1 punto per ogni blocco di caduta oltre i 3. È una funzione pura dell'altezza, quindi si testa senza fisica.
- A 0 punti compare una schermata "Sei caduto" con il pulsante Rinasci. Il giocatore rinasce al punto di partenza del mondo con la salute piena e tiene l'inventario.
- La salute si ricarica di 1 punto ogni 4 secondi. Senza fame (RF-27, Could) non c'è un altro modo per recuperarla.

### Inventario (RF-21)

- 8 posti nella hotbar e 24 nello zaino. Ogni posto tiene un solo tipo di oggetto: fino a 64 blocchi, oppure un solo strumento.
- Un oggetto è un blocco o uno strumento. I blocchi tengono il loro ID da 1 a 255; gli strumenti hanno ID propri in un registro degli oggetti separato, così i byte del mondo non cambiano.
- Un blocco rotto entra nel primo posto con lo stesso tipo e spazio libero, altrimenti nel primo posto vuoto. Se l'inventario è pieno il blocco va perso. L'erba rotta dà terra; le foglie e il vetro non danno nulla.
- Piazzare consuma un blocco dal posto selezionato nella hotbar. Se il posto è vuoto, il clic destro non fa nulla.
- Il tasto E apre l'inventario: libera il mouse e mette in pausa le azioni del giocatore. Un clic prende una pila e un secondo clic la posa, la scambia o la unisce.
- All'inizio di un mondo in sopravvivenza l'inventario è vuoto.

### Tempi di rottura (RF-25)

- In sopravvivenza si rompe tenendo premuto il clic sinistro. Se il mirino cambia blocco o il tasto si rilascia, il progresso si azzera.
- Il registro dei blocchi aggiunge la durezza di ogni tipo, in secondi a mani nude:

| Blocco | Mani nude | Piccone di legno | Piccone di pietra |
| --- | --- | --- | --- |
| Foglie, vetro | 0,3 s | 0,3 s | 0,3 s |
| Erba, terra, sabbia | 0,6 s | 0,6 s | 0,6 s |
| Tronco, assi | 1,5 s | 1,5 s | 1,5 s |
| Pietra | 4,0 s | 1,5 s | 0,8 s |

- Il blocco mirato mostra un'incrinatura in 4 stadi, disegnata come sovrapposizione sul blocco e non nella mesh del chunk: rompere non ricostruisce nulla finché il blocco non sparisce.

### Crafting (RF-26)

Le ricette sono una lista fissa nella schermata dell'inventario, senza griglia. Una ricetta si attiva se l'inventario contiene gli ingredienti; un clic la esegue, togliendo gli ingredienti e aggiungendo il risultato.

| Ricetta | Ingredienti | Risultato |
| --- | --- | --- |
| Assi | 1 tronco | 4 assi |
| Vetro | 4 sabbia | 1 vetro |
| Piccone di legno | 5 assi | 1 piccone di legno |
| Piccone di pietra | 2 assi e 3 pietra | 1 piccone di pietra |

I picconi non si consumano. Sono oggetti dell'inventario e agiscono solo quando sono selezionati nella hotbar.

### Salvataggio

La 5a aggiunge al formato una sezione `SURV` con la modalità, la salute e i 32 posti dell'inventario, ognuno come ID oggetto u16 e quantità u8. È una sezione nuova, quindi il formato resta alla versione 2: un file senza `SURV`, compresi quelli di versione 1, si carica come mondo creativo. Gli ID degli strumenti, come quelli dei blocchi, non si rinumerano mai.

### Materie prime

Le ricette usano tronchi e sabbia, quindi la 5a porta anche la versione 2 del terreno con alberi e sabbia (vedi "Generazione del terreno"). Senza, nessuna ricetta si può fare: il primo playtest della 5a lo ha mostrato.

### Texture

L'atlante 4 × 4 ha 6 caselle libere, quante ne servono: i 4 stadi dell'incrinatura e le icone dei due picconi. Sajmir le genera o le trova come le altre; fino ad allora si usano segnaposto.

### Rischi della 5a

Nessuno dei requisiti della 5a introduce un rischio tecnico nuovo: mesh, collisioni e dati del mondo non cambiano. Per questo la 5a non ha PoC e passa da questa analisi allo sviluppo.

| Rischio | Impatto | Mitigazione |
| --- | --- | --- |
| Danno da caduta sbagliato su scale, bordi o salti ripetuti | Medio | Funzione pura dell'altezza con unit test; scenari di caduta nel playtest |
| Interfaccia dell'inventario fragile con il mouse catturato | Medio | Stessa regola dell'HUD sul `mouse_filter`; test di integrazione con lo scene runner |
| Salvataggi precedenti non più leggibili | Medio | Sezione nuova nel formato, con i file d'esempio di ogni versione caricati dai test |

### Test e gate 5a

- Unit test: danno da caduta, inventario (aggiunta, consumo, pile piene, inventario pieno), ricette, tempi di rottura per blocco e strumento, sezione `SURV` salvata e ricaricata, file d'esempio senza `SURV` caricati come creativi.
- Test di integrazione: rompere un blocco in sopravvivenza lo mette nell'inventario, piazzarlo lo toglie.
- La prova di resistenza e la misura delle prestazioni restano valide e si ripetono: RNF-01 e RNF-04 non devono peggiorare.
- Playtest sul Mac con una checklist di sopravvivenza in `docs/validazione.md`.
- Gate 5a: RF-20 e RF-21 completi, RF-25 e RF-26 completi o rinviati da Sajmir, test verdi, playtest superato.

## Struttura della sottofase 5b: il viaggio

La 5b dà al gioco un finale. Questa sezione fissa solo la struttura; mondo, combattimento e boss si progettano nell'analisi della 5b, dopo il gate 5a.

- Le 5 gemme madre sono nascoste in strutture sotto terra, generate dal seed insieme al terreno. Una la custodisce il Drago dei Confini.
- Con tutte e 5 le gemme, al bordo del mondo si evoca il portatore di mondi, il boss finale. Sconfiggerlo chiude il gioco.
- Il combattimento è corpo a corpo e riguarda solo i due boss. I nemici comuni (RF-28) restano fuori.
- Rischi da studiare con PoC propri: un drago in volo in un mondo voxel di 256 × 256 × 64 blocchi, la generazione delle strutture sotterranee senza rompere RNF-03, il movimento dei boss tra i blocchi.

## Piano SDLC

Il lavoro procede in cinque fasi, l'ultima divisa in due sottofasi, ognuna chiusa da un gate: nessuna fase parte finché la precedente non ha superato i suoi criteri.

| Fase | Contenuto | Gate di uscita |
| --- | --- | --- |
| 1. Analisi e progettazione | Requisiti e design (questo documento) | Gate 1: documento approvato, decisioni chiuse |
| 2. PoC tecnici | 4 spike isolati, sul Mac | Gate 2: criteri dei PoC superati sul Mac |
| 3. Sviluppo MVP | Requisiti Must e Should, con unit test | Gate 3: Must completati, test verdi |
| 4. Validazione e QA | Test, prestazioni, playtest, export | Gate 4: zero bug bloccanti, RNF rispettati |
| 5a. Sopravvivenza | Analisi, sviluppo, QA di RF-20, 21, 25 e 26 | Gate 5a: Must completati, test verdi, playtest superato |
| 5b. Il viaggio | Analisi, PoC, sviluppo, QA di RF-22, 23 e 24 | Gate 5b: definito nell'analisi della 5b |

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
