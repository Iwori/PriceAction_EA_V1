# DICCIONARIO DE CÃ“DIGOS â€” Debug Log Compacto EA PriceAction
## Objetivo: Reducir tamaÃ±o del log ~70% para permitir backtests de semanas/meses

---

## FORMATO GENERAL DE LÃNEA
```
DDHHMM|COD|datos_separados_por_pipe
```
- **DDHHMM:** DÃ­a+Hora+Minuto (6 dÃ­gitos). Ej: `020800` = dÃ­a 02, 08:00
- **COD:** CÃ³digo de 2-3 caracteres (ver tablas abajo)
- **|** separador de campos
- Precios: sin punto decimal cuando son enteros, con 1 decimal si necesario

---

## CÃ“DIGOS DE EVENTO (COD)

### Puntos Estructurales
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `PE` | PE detectado | `#id|B/R|N/S|nivel|eL|eR|bar` |

- B=Bull, R=Bear (Bear=Rojo)
- N=Normal, S=Strict
- eL=espacios izq, eR=espacios der

**Ejemplo:** `020109|PE|#3|R|S|25286.5|2|4|14`
â†’ DÃ­a 02 01:09, PE #3, Bear Strict, nivel 25286.5, 2 espacios izq, 4 der, bar 14

---

### Zonas de InterÃ©s
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `ZC` | Zona creada | `#id|B/R|P/K|hi|lo|bar` |
| `ZP` | Zona mitigada parcial | `#id|hi|lo|bar` |
| `ZF` | Zona mitigada FULL | `#id|bar` |
| `ZX` | Zona expirada | `#id|bar` |
| `ZH` | Zona histÃ³rica full (deep scan) | `#id|B/R|P/K|bar` |
| `ZG` | Grand Zone (fusiÃ³n) | `#idA+#idB|hi|lo` |

- P=PE-based, K=braKe-based
- hi=upper, lo=lower

**Ejemplo:** `020109|ZC|#2|R|P|25608.5|25559.7|1`
â†’ Zona #2 creada, Bear PE, upper=25608.5, lower=25559.7, bar 1

---

### Patrones
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `PR` | PatrÃ³n registrado | `#id|2/3|L/S|sz|atr|e|sl|tp` |
| `P3W` | P3 en WAIT_BREAK | `#id|sz` |
| `P3K` | P3 confirmado (quiebre) | `#id|close` |
| `PX` | PatrÃ³n cancelado | `#id|motivo_cÃ³digo` |

- 2=P2, 3=P3
- L=Long, S=Short
- sz=size(pips), atr=ATR
- e=entry, sl=stoploss, tp=takeprofit
- Si entry=0 (P3 wait), solo logear P3W

**Motivos de cancelaciÃ³n (PX):**
| CÃ³digo | Significado |
|--------|-------------|
| `adv` | Price advanced >2.5Ã— pattern size |
| `zi` | Extreme close in opposite ZI |
| `3lim` | Exceeded 3-pattern limit per direction |
| `13w` | Entry moment passed during 13-candle wait |
| `13m` | Market entry cannot wait for 13-candle rule |
| `slx` | SL crossed entry (price moved) |
| `2pe` | 2+ strict PE cancelled limit |
| `p3sz` | P3 size > 2Ã— ZI |
| `imp` | Impulse â‰¥6Ã— indicator (P3 vetoed) |
| `dc` | Daily close |

**Ejemplo:** `020812|PX|#2|13w`
â†’ PatrÃ³n #2 cancelado: entry moment passed during 13-candle wait

---

### Decisiones de anÃ¡lisis
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `DW` | Wick exception P2 | `shift|close` |
| `DZ` | ZI encontrada para Fib2 | `#zi|ext100|cap` |
| `DP` | PE encontrado para Fib2 | `#pe|ext100|cap` |
| `DN` | No ZI/PE | `trend=Y/N|fib=nivel` |
| `DL` | Lot calc | `bal|risk$|tv|ts|sld|ticks|lots` |
| `DF` | Fib2 ratio | `ratio|entry_type` |
| `DH` | Holgura 5% aplicada | `sl_antes|sl_despues` |
| `DG` | Grand zone fusiÃ³n | `#z1+#z2|new_hi|new_lo` |
| `flash` | Flash position (limit filled + SL/TP hit entre OnTick calls) | `#pat|pos=position_id|profit` |

**Ejemplo:** `020803|DN|N|1.15`
â†’ No ZI/PE encontrado, sin tendencia previa, SL en fib 1.15

**Ejemplo:** `021403|D|flash|#4|pos=16|-497.00`
→ Patrón #4, posición 16 se llenó y cerró entre ticks, pérdida -497.00

---

### Trades (Ã³rdenes y posiciones)
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `TL` | Limit order placed | `#tk|L/S|lots|e|sl|tp` |
| `TM` | Market order placed | `#tk|L/S|lots|e|sl|tp` |
| `TA` | Order activated (fill) | `#tk|price` |
| `TD` | Order deleted (mono/cancel) | `#tk|motivo` |
| `TC` | Position closed | `#tk|profit` |
| `TR` | Trade result | `#tk|retcode` |
| `TO` | Monotask: delete other pending | `#tk` |

- L=Long/Buy, S=Short/Sell
- #tk=ticket number

**Ejemplo:** `020803|TL|#3|S|65.78|25466.1|25473.7|25434.2`
â†’ Sell Limit #3, 65.78 lots, entry 25466.1, SL 25473.7, TP 25434.2

---

### Breakeven / Trailing
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `B1` | BE Stage 1 triggered | `#tk|ratio|spe|old_sl|new_sl` |
| `B2` | BE Stage 2 triggered | `#tk|ratio|old_sl|new_sl` |
| `BT` | Trailing moved | `#tk|old_sl|new_sl|source` |

- spe=strict PE count
- source=ZI#id o PE#id (quÃ© zona/PE se usÃ³ para mover)

**Ejemplo:** `021709|B1|#23|1.85|0|25633.2|25608.5`
â†’ BE Stage 1, ticket #23, ratio 1.85, 0 strict PEs, SL movido de 25633.2 a 25608.5

---

### Sistema / Control
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `$I` | Init (parÃ¡metros) | `sÃ­mbolo|tf|balance|risk%` |
| `$S` | Symbol info | `tv|ts|sl_lev|lot_min|lot_max|cmode` |
| `$D` | Daily reset | `balance` |
| `$C` | Daily close triggered | (sin datos) |
| `$L` | Loss detected + wait | `profit|vela_wait` |
| `$R` | Recovery state | `has_pos|ticket` |
| `$E` | Error | `cÃ³digo|mensaje` |

---

### Brake (frenazo) pendientes
| CÃ³digo | Significado | Formato datos |
|--------|-------------|---------------|
| `KP` | Brake pending registered | `#id|B/R|break_lv|cancel_lv` |
| `KR` | Brake rejected (body ratio) | `ratio|bar` |
| `KA` | Brake annulled (cierre cruzÃ³ cancel level) | `#id` |

---

## EJEMPLO COMPLETO â€” Log actual vs Log compacto

### Log actual (281 caracteres):
```
[2026.01.02 08:03:00] [DECISION] P2 wick exception at shift 2, close=25467.50000
[2026.01.02 08:03:00] [DECISION] P2 NoZI/PE: trend=NO, SL fib=1.15
[2026.01.02 08:03:00] [DECISION] P2: No ZI/PE. SL level set to 25473.20000
[2026.01.02 08:03:00] [PATTERN] REGISTERED #2 | P2 SHORT | State=CONFIRMED | Entry=25466.10000 SL=25473.70000 TP=25434.20000 | Size=80.0 pips | ATR=5.4
[2026.01.02 08:03:00] [DECISION] LOT_CALC: Balance=100000.00 Risk$=500.00 | TickVal=0.100000 TickSz=0.10000 | SLdist=7.60000 SLticks=76.0 | RawLots=65.7895
[2026.01.02 08:03:00] [TRADE] LIMIT_ORDER | Ticket=#3 | Dir=SELL_LIMIT Lots=65.78 Entry=25466.10000 SL=25473.70000 TP=25434.20000
```

### Log compacto (152 caracteres, -46%):
```
020803|DW|2|25467.5
020803|DN|N|1.15
020803|DH|25473.2|25473.7
020803|PR|#2|2|S|80|5.4|25466.1|25473.7|25434.2
020803|DL|100000|500|0.1|0.1|7.6|76|65.78
020803|TL|#3|S|65.78|25466.1|25473.7|25434.2
```

### Ahorro estimado:
| Tipo de lÃ­nea | Actual | Compacto | Ahorro |
|---------------|--------|----------|--------|
| PE detectado | ~95 chars | ~35 chars | 63% |
| Zona creada | ~90 chars | ~35 chars | 61% |
| Zona partial | ~95 chars | ~20 chars | 79% |
| PatrÃ³n registrado | ~140 chars | ~45 chars | 68% |
| CancelaciÃ³n | ~85 chars | ~20 chars | 76% |
| Trade | ~120 chars | ~45 chars | 62% |
| Lot calc | ~135 chars | ~40 chars | 70% |
| **Promedio** | **~110 chars** | **~35 chars** | **~68%** |

### Impacto en backtesting:
- 1 dÃ­a actual: 2749 lÃ­neas Ã— ~110 chars = ~302 KB
- 1 dÃ­a compacto: 2749 lÃ­neas Ã— ~35 chars = ~96 KB
- **3 meses compacto: ~8.6 MB** (vs ~27 MB actual)
- Con LogLevel TRADES: ~50 lÃ­neas/dÃ­a Ã— 35 chars = 1.75 KB/dÃ­a â†’ **3 meses = 157 KB**

---

## NOTAS DE IMPLEMENTACIÃ“N

1. Formato fecha `DDHHMM`: Suficiente para backtests dentro del mismo mes. Para multi-mes agregar `MMDDHHMM` (8 dÃ­gitos).
2. Precios: usar formato mÃ¡s corto posible. Ej: `25466.1` en vez de `25466.10000`.
3. El LogLevel existente (FULL/TRADES/OFF) sigue aplicando â€” este formato compacto aplica a FULL.
4. Los cÃ³digos son case-sensitive y fijos (no cambiarÃ¡n).
5. Separador `|` elegido porque no aparece en datos numÃ©ricos.
