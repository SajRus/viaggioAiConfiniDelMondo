# Viaggio ai confini del mondo

Sandbox voxel 3D in prima persona, con mondo finito. Godot 4.7, GDScript, renderer Forward+.

**Fonte di verità: [docs/analisi-progettazione.md](docs/analisi-progettazione.md).** Leggilo prima di progettare o implementare qualcosa. Se il codice deve divergere dal documento, si aggiorna prima il documento.

## Regole di progetto

- Il lavoro segue le fasi e i gate del documento: nessuna fase parte finché la precedente non ha superato il suo gate, e ogni gate lo approva Sajmir.
- Ogni PoC è un progetto Godot separato che isola un solo rischio. Un PoC fallito cambia il design, non si aggira dentro l'MVP.
- Scope: solo ciò che è previsto dai requisiti. Ciò che non è Must aspetta la chiusura dell'MVP.
- Versione del motore fissata a Godot 4.7. Nessuna migrazione a 4.8 prima della fine dell'MVP.
- Texture: PNG 16 × 16 generati con ChatGPT o presi online solo con licenza d'uso (per esempio CC0). Nessun asset o marchio di Minecraft.
- Ogni modifica passa da una PR su GitHub. Gli agenti non vedono il gioco: ciò che si vede o si misura lo verifica Sajmir sul Mac.

## Stile GDScript

- Segui la [guida di stile ufficiale](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html): tab per l'indentazione, `snake_case` per file, funzioni e variabili, `PascalCase` per classi e nodi, `CONSTANT_CASE` per costanti ed enum.
- Tipi statici ovunque: variabili, costanti, parametri e valori di ritorno, compreso `-> void`.
- `:=` solo quando il tipo è evidente dal lato destro. Con valori `Variant` dichiara il tipo in modo esplicito.
- I warning GDScript sono errori (`project.godot`, sezione `[debug]`). `addons/` è escluso.
- Niente `@warning_ignore` senza un commento che spieghi il motivo. Per la divisione intera, dove è voluta, preferisci gli shift (`x >> 4`) se il divisore è una potenza di 2.
- I dati stanno in `PackedByteArray` e array impacchettati. Il meshing è il rischio principale: niente allocazioni evitabili nei cicli caldi.

## Struttura

| Cartella | Contenuto |
| --- | --- |
| `src/` | Codice del gioco |
| `test/` | Test gdUnit4, stessa struttura di `src/`, file `*_test.gd` |
| `assets/textures/` | Texture |
| `docs/` | Analisi e progettazione |
| `addons/gdUnit4/` | gdUnit4 6.2.3, non modificare |
| `poc/` | Un progetto Godot separato per ogni PoC. `poc/.gdignore` lo nasconde al progetto principale |

I file `.uid` si committano, sempre insieme al file a cui si riferiscono. `.godot/` non si committa.

## Test

I test sono obbligatori per ogni modulo logico: indice del chunk, generazione deterministica, DDA, face culling, salvataggio e ricaricamento. Una suite estende `GdUnitTestSuite` e i metodi di test iniziano con `test_`.

Per eseguirli sul Mac, dalla radice del repository:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --audio-driver Dummy --add res://test
```

La CI (`.github/workflows/ci.yml`) esegue gli stessi test a ogni push e PR, con gli stessi warning come errori.

In modalità headless gli `InputEvent` non arrivano al gioco. I test che simulano input con lo scene runner richiederanno `headless: false` in CI, che usa un display virtuale.

## Definition of Done

Un requisito è finito solo se:

- il codice è tipizzato;
- i test sono verdi;
- la revisione è fatta;
- non ci sono warning.
