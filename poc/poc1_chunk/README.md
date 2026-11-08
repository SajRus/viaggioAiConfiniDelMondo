# PoC 1: chunk singolo

Dimostra dati del chunk, meshing con face culling e atlante delle texture. Criterio di successo: chunk visivamente corretto e ricostruzione entro RNF-04 (≤ 16 ms).

Fuori da questo PoC: rumore e generazione del terreno (PoC 2), collisioni (PoC 3), chunk vicini (PoC 4). Oltre il bordo del chunk il mesher considera aria.

`assets/atlas.png` è un atlante segnaposto creato da `tools/make_placeholder_atlas.gd`.

## Come provarlo sul Mac

Da questa cartella:

```sh
export GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path .                    # scena: 1, 2, 3 cambiano chunk, R ricostruisce
"$GODOT_BIN" --path . -- --bench         # misura dei tempi
./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --audio-driver Dummy --add res://test
```

## Misure

Apple M1, Godot 4.7 stable, Metal, build di debug dell'editor. Tempo di costruzione della mesh, 30 ricostruzioni.

| Chunk | Facce | Mediana | Massimo | RNF-04 |
| --- | --- | --- | --- | --- |
| Colline con pilastri | 2.860 | 7,68 ms | 9,70 ms | Rispettato |
| Pieno | 4.608 | 14,05 ms | 15,20 ms | Rispettato |
| Scacchiera, caso peggiore artificiale | 49.152 | 85,94 ms | 98,37 ms | Non rispettato |
