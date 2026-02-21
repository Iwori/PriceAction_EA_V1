\# RESUMEN COMPLETO DE ESPECIFICACIONES â€” EA PriceAction MT5

\## Documento fuente: EspecificaciÃ³n v2 de Eduardo Antonio Uriel SÃ¡nchez (13/02/2026)

\## Plataforma: MT5 (MQL5) | SÃ­mbolo Ã³ptimo: US100 M3 | Compatible: cualquier sÃ­mbolo/TF



---



\## 1. PUNTOS ESTRUCTURALES (PE)



\### 1.1 Formaciones

\- \*\*PE alcista:\*\* Vela bajista + vela alcista, O bajista + Doji + alcista

\- \*\*PE bajista:\*\* Vela alcista + vela bajista, O alcista + Doji + bajista

\- \*\*Doji:\*\* cierre == apertura (mechas irrelevantes)



\### 1.2 Nivel del PE

\- \*\*PE alcista:\*\* MIN(cierre\_bajista, apertura\_alcista). Con Doji: MIN(cierre\_bajista, cierre\_doji, apertura\_alcista). Solo cuerpos, no mechas.

\- \*\*PE bajista:\*\* MAX(cierre\_alcista, apertura\_bajista). Con Doji: MAX(cierre\_alcista, cierre\_doji, apertura\_bajista). Solo cuerpos, no mechas.



\### 1.3 Espacios vacÃ­os

Se buscan en las \*\*4 velas anteriores\*\* y \*\*4 velas siguientes\*\* a la formaciÃ³n.



\*\*Izquierda (primero):\*\* Revisar 4 velas antes de la 1Âª vela del PE (alcista si PE bajista, bajista si PE alcista), de DERECHA a IZQUIERDA:

\- Vela NO toca nivel PE (ni mecha ni cuerpo) â†’ cuenta como espacio vacÃ­o

\- Vela toca con mecha â†’ pasar a la siguiente (izquierda)

\- Vela abre o cierra (solo O/C, no mechas) POR ENCIMA del nivel (PE bajista) o POR DEBAJO (PE alcista), o EXACTAMENTE en el nivel â†’ \*\*STOP: no hay mÃ¡s bÃºsqueda, si no habÃ­a espacio vacÃ­o aÃºn â†’ NO HAY PE\*\*



\*\*Derecha (solo si â‰¥1 espacio izq):\*\* Revisar 4 velas despuÃ©s de la Ãºltima vela del PE (alcista si PE alcista, bajista si PE bajista), de IZQUIERDA a DERECHA:

\- Mismas reglas que izquierda

\- \*\*PE NO EXISTE hasta que una de las 4 velas siguientes CIERRE creando espacio vacÃ­o\*\*



\### 1.4 Normal vs Estricto

\- \*\*Normal:\*\* Al menos 1 espacio vacÃ­o a cada lado, pero un lado tiene solo 1

\- \*\*Estricto:\*\* â‰¥2 espacios vacÃ­os a cada lado (no necesariamente consecutivos)



---



\## 2. ZONAS DE INTERÃ‰S (ZI)



\### 2.1 ZI basada en PE

Requiere PE vÃ¡lido (formaciÃ³n + mÃ­n 1 espacio vacÃ­o cada lado). Luego:

\- \*\*PE alcista â†’ ZI alcista:\*\* cuerpo vela bajista < cuerpo vela alcista

\- \*\*PE bajista â†’ ZI bajista:\*\* cuerpo vela alcista < cuerpo vela bajista

\- La zona cubre \*\*TODA la vela\*\* (incluye mechas), aunque la verificaciÃ³n usa solo cuerpos



\### 2.2 ZI basada en frenazo



\*\*ZI alcista\*\* (formaciones):

\- Alcista + bajista + alcista

\- Alcista + Doji + bajista + alcista

\- Alcista + bajista + Doji + alcista

\- Alcista + 2 bajistas + alcista

\- Alcista + Doji + 2 bajistas + alcista

\- Alcista + 2 bajistas + Doji + alcista

\- "Frenazo" = todas las velas entre la 1Âª y 2Âª alcista (sin incluirlas)



\*\*ZI bajista:\*\* SimÃ©trico con bajistas.



\*\*Quiebre del frenazo (ZI alcista):\*\*

1\. Si la Ãºltima vela alcista CIERRA > MAX(mechas frenazo) â†’ zona confirmada automÃ¡ticamente

2\. Si no: esperar que alguna vela siguiente cierre > MAX(mechas frenazo) ANTES de que una vela cierre < MIN(cierres frenazo). Si cierra debajo primero â†’ SE ANULA

3\. Sin lÃ­mite de velas, sin importar direcciÃ³n



\*\*Quiebre del frenazo (ZI bajista):\*\* SimÃ©trico invertido.



\### 2.3 Condiciones del frenazo (body ratio)

Cuando la vela ANTERIOR a la formaciÃ³n es de direcciÃ³n opuesta a la 1Âª vela:

\- Suma cuerpos frenazo / cuerpo 1Âª vela > 1.5 â†’ \*\*NO hay zona\*\*

\- Si la vela anterior es misma direcciÃ³n â†’ sin lÃ­mite

\- Si la vela anterior es Doji â†’ mirar una mÃ¡s atrÃ¡s



\### 2.4 Propiedades comunes de zonas

1\. Una zona puede ser PE + frenazo a la vez (no marcar doble)

2\. Zonas pueden crearse dentro de otras zonas

3\. \*\*La vela siguiente a la que CREA la zona NO puede mitigar ESA zona\*\* (sÃ­ las anteriores)

&nbsp;  - Crea zona PE: vela que crea espacio vacÃ­o derecho habiendo izquierdo

&nbsp;  - Crea zona frenazo: vela que quiebra el frenazo

4\. \*\*Zonas que se tocan = una sola\*\* (Grand Zone / fusiÃ³n)



\### 2.5 MitigaciÃ³n

\*\*Total:\*\* Una vela atraviesa completamente la zona (crea cotizaciÃ³n de extremo a extremo). Da igual si es cuerpo o mecha.

\*\*Parcial:\*\* Una vela entra en la zona pero no la atraviesa completa. Da igual si cierra dentro o no. Doji tambiÃ©n mitiga.

\*\*ZI vÃ¡lida\*\* = zona completa nunca mitigada O trozo restante de zona parcialmente mitigada.



\### 2.6 ExpiraciÃ³n

\- A las \*\*80 velas\*\* (configurable) desde la vela que CONFIRMA la zona â†’ zona invÃ¡lida



---



\## 3. PATRÃ“N 2



\### 3.1 FormaciÃ³n

\- \*\*ZI alcista (â†’ BUY):\*\* Vela bajista cierra DENTRO de ZI alcista no mitigada + vela alcista ENVOLVENTE. O con Doji intermedio.

\- \*\*ZI bajista (â†’ SELL):\*\* Vela alcista cierra DENTRO de ZI bajista no mitigada + vela bajista ENVOLVENTE. O con Doji intermedio.

\- \*\*Envolvente:\*\* Cuerpo mayor que cuerpo de vela anterior. Si anterior es Doji â†’ comparar con 2Âª anterior.



\### 3.2 ExcepciÃ³n wick (2 velas anteriores)

\- Las 2 velas anteriores a la formaciÃ³n NO pueden invalidar dibujando MECHA en el precio de cierre de la 1Âª vela de la formaciÃ³n

\- Si la 1Âª vela cierra en zona "reciÃ©n mitigada por mechas de las 2 anteriores" â†’ se ignora la mitigaciÃ³n y se procede igual

\- CondiciÃ³n: las 2 velas solo mitigan con MECHA (no cuerpo) en el nivel de cierre



\### 3.3 Fibonacci 1

\- \*\*ZI alcista (BUY):\*\* 100% = MIN(cotizaciÃ³n con mechas) de formaciÃ³n + 2 velas anteriores (4 o 5 velas). 0% = cierre envolvente.

\- \*\*ZI bajista (SELL):\*\* 100% = MAX(cotizaciÃ³n con mechas) de formaciÃ³n + 2 velas anteriores. 0% = cierre envolvente.

\- \*\*TamaÃ±o patrÃ³n 2\*\* = distancia 0%â†’100% del Fib1



\### 3.4 Cap del SL (Fib1)

\- TamaÃ±o P2 / indicador â‰¥ 1 â†’ SL mÃ¡ximo en \*\*175%\*\* del Fib1

\- TamaÃ±o P2 / indicador < 1 â†’ SL mÃ¡ximo en \*\*200%\*\* del Fib1



\### 3.5 BÃºsqueda de ZI y PE para colocar SL (Fib2)

4\. Buscar ZI vÃ¡lidas entre 100% y 123% del Fib1

5\. Buscar PE con nivel entre 100% y 140% del Fib1



\*\*Si encuentra ZI\*\* (entre 100-123%): alargar Fib hasta extremo de la ZI. Si ZI se solapa con otra â†’ incluir esa tambiÃ©n. 100% nuevo = extremo ZI (respetando cap 175/200%).

\*\*Si encuentra solo PE\*\* (entre 100-140%): alargar Fib hasta mÃ­n/mÃ¡x alcanzado por velas del PE (con mechas). 100% nuevo = extremo PE (respetando cap 175/200%).

\*\*Si ZI + PE:\*\* priorizar PE.

\*\*Si zonas solapadas:\*\* incluir todas las zonas conectadas.



\### 3.6 Sin ZI ni PE

\- \*\*Con tendencia previa\*\* (alguna vela de Ãºltimas 70 cerrÃ³/abriÃ³ mÃ¡s allÃ¡ del 100%):

&nbsp; - P2/indicador < 2.5 â†’ SL en fib 1.40

&nbsp; - P2/indicador â‰¥ 2.5 â†’ SL en fib 1.23

\- \*\*Sin tendencia previa:\*\* SL en fib \*\*1.15\*\*



\### 3.7 Tabla de entrada (Fib2)

TamaÃ±o Fib2 / indicador (ATR medido en vela envolvente):

| Ratio | Entrada |

|-------|---------|

| â‰¤ 1.3 | Directa (Market) |

| > 1.3 y â‰¤ 1.6 | 23% Fib |

| > 1.6 y â‰¤ 2.8 | 38% Fib |

| > 2.8 y â‰¤ 3.5 | 50% Fib |

| > 3.5 | 61% Fib |



\### 3.8 SL en PatrÃ³n 2

SL = 100% del Fib2 + \*\*5% de holgura\*\* sobre el tamaÃ±o del SL



---



\## 4. PATRÃ“N 3



\### 4.1 FormaciÃ³n

\- \*\*ZI bajista (â†’ BUY):\*\* Vela alcista cierra dentro de ZI bajista + vela bajista/Doji (frenazo)

\- \*\*ZI alcista (â†’ SELL):\*\* Vela bajista cierra dentro de ZI alcista + vela alcista/Doji (frenazo)

\- Regla wick 2 velas anteriores: IGUAL que PatrÃ³n 2



\### 4.2 Espera de quiebre

\- \*\*BUY:\*\* Esperar que una vela CIERRE por encima del extremo SUPERIOR de la ZI bajista

\- \*\*SELL:\*\* Esperar que una vela CIERRE por debajo del extremo INFERIOR de la ZI alcista



\### 4.3 TamaÃ±o del PatrÃ³n 3

\- Medir desde que se forma el frenazo hasta que se confirma el quiebre

\- Extremos: mÃ¡ximos y mÃ­nimos (con mechas) de todas las velas entre frenazo y quiebre (incluidas)

\- \*\*Si tamaÃ±o P3 > 2Ã— tamaÃ±o ZI â†’ NO hay patrÃ³n\*\* (cancelar)

\- Si el quiebre ocurre antes de superar 2Ã—ZI â†’ hay patrÃ³n (medir se detiene)



\### 4.4 Solapamiento con ZI (P3 ampliado)

\- Si ZI alcista (BUY) o bajista (SELL) de misma direcciÃ³n se solapa con el Fib del P3 (extremo toca entre 0% y 100%) â†’ fusionar â†’ \*\*tamaÃ±o P3 ampliado\*\*

\- Puede encadenarse: zona toca zona toca zona...

\- La cancelaciÃ³n por >2Ã—ZI solo usa el tamaÃ±o P3 INICIAL, no el ampliado



\### 4.5 Fibonacci P3

\- \*\*BUY:\*\* 100% = extremo inferior P3 (o P3 ampliado), 0% = extremo superior

\- \*\*SELL:\*\* 100% = extremo superior P3, 0% = extremo inferior



\### 4.6 Tabla de entrada P3

Ratio = (tamaÃ±o P3 o P3 ampliado) / indicador. ATR medido en \*\*1Âª vela alcista (BUY) o 1Âª vela bajista (SELL)\*\* del patrÃ³n:

| Ratio | Entrada |

|-------|---------|

| < 1.5 | 33% Fib |

| â‰¥ 1.5 y < 2.5 | 40% Fib |

| â‰¥ 2.5 y < 3.5 | 50% Fib |

| â‰¥ 3.5 | 61% Fib |



\### 4.7 SL PatrÃ³n 3 â€” SituaciÃ³n normal

Ratio = (tamaÃ±o P3 o P3 ampliado) / indicador:

| Ratio | SL en Fib |

|-------|-----------|

| â‰¤ 0.5 | 300% |

| > 0.5 y â‰¤ 0.85 | 220% |

| > 0.85 y â‰¤ 1 | 200% |

| > 1 | 150% |

\+ \*\*5% holgura\*\* sobre tamaÃ±o SL (abajo en BUY, arriba en SELL)



\### 4.8 Excepciones SL P3

\*\*1. Si hay PE\*\* (entre 100% Fib y nivel SL normal):

\- SL â†’ mÃ­n/mÃ¡x alcanzado por velas del PE (con mechas)

\- PE solo ACORTA el SL, nunca lo alarga mÃ¡s allÃ¡ de la holgura normal

\- Cap = nivel de holgura normal



\*\*2. Si hay ZI\*\* (el nivel SL normal toca una ZI de misma direcciÃ³n):

\- ZI NO debe solaparse con el tamaÃ±o del patrÃ³n (entre 0-100% Fib)

\- Si sÃ­ se solapa â†’ ya es P3 ampliado, colocar normalmente

\- Si no se solapa: nuevo Fib desde extremo ZI hasta extremo superior P3

&nbsp; - Ratio nuevo/indicador < 2.5 â†’ entrada 50%

&nbsp; - Ratio â‰¥ 2.5 â†’ entrada 61%

&nbsp; - SL en 105% del nuevo Fib (cubre ZI completa)

\- \*\*ZI ALARGA el SL sin lÃ­mite\*\*



\*\*3. Si PE + ZI a la vez:\*\* priorizar ZI



\### 4.9 Regla que impide P3 (impulso â‰¥6Ã—)

\- Medir impulso anterior (opuesto a la direcciÃ³n del trade)

\- Impulso = vela directriz + â‰¥2 intermedias + vela de cierre que quiebra apertura de la 1Âª

\- Intermedias: cualquier direcciÃ³n, pero no pueden cerrar mÃ¡s allÃ¡ del extremo de la 1Âª vela

\- Medir indicador en la vela a MITAD del impulso

\- Si tamaÃ±o impulso / indicador(mitad) â‰¥ 6 â†’ \*\*NO tomar P3\*\*

\- Si impar (ej 31 velas), usar vela nÂº floor(N/2) = 15



---



\## 5. REGLAS COMUNES



\### 5.1 GestiÃ³n de riesgo

\- \*\*TP = 4.2 Ã— SL\*\* (configurable)

\- \*\*Holgura SL = 5%\*\* siempre (abajo BUY, arriba SELL)

\- \*\*Riesgo = 0.5% del balance\*\* (configurable)

\- Si no hay margen suficiente â†’ ajustar lotaje al mÃ¡ximo disponible



\### 5.2 Breakeven y Trailing



\*\*Stage 1\*\* â€” Activar cuando: ratio â‰¥ 1:1.3 O 2 PE estrictos formados post-entry

\- Mover SL a: extremo inferior ZI alcista (BUY) o superior ZI bajista (SELL)

\- Si no hay ZI â†’ usar PE: mÃ­n PE alcista (BUY) o mÃ¡x PE bajista (SELL)

\- \*\*Priorizar ZI sobre PE\*\*

\- SL NO puede superar el nivel de entrada aÃºn



\*\*Stage 2\*\* â€” Activar cuando: ratio â‰¥ 1:3

\- SL puede superar el nivel de entrada

\- Mover a: PE ESTRICTO o \*\*PENÃšLTIMA\*\* ZI formada (misma direcciÃ³n)

\- Misma priorizaciÃ³n: ZI sobre PE

\- Solo ZI/PE de misma direcciÃ³n que el trade



\### 5.3 AnulaciÃ³n de entradas



1\. \*\*13 velas post-loss:\*\* Tras operaciÃ³n perdedora (profit < 0), no abrir hasta que cierren 13 velas (configurable). Seguir analizando, pero no colocar Ã³rdenes. Si la seÃ±al se habrÃ­a activado durante las 13 velas â†’ descartar (ya pasÃ³ momento Ã³ptimo).



2\. \*\*2+ PE estrictos:\*\* Buy Limit + 2 PE alcistas estrictos formados despuÃ©s â†’ cancelar. Sell Limit + 2 PE bajistas estrictos â†’ cancelar.



3\. \*\*Precio avanza > 2.5Ã— tamaÃ±o patrÃ³n:\*\* Buy Limit y vela alcista cierra > 2.5Ã— desde cierre envolvente (P2) o extremo superior P3 â†’ cancelar. Sell Limit simÃ©trico.



4\. \*\*Cierre extremo en ZI opuesta:\*\* Si la vela alcista mÃ¡s alta (BUY) o bajista mÃ¡s baja (SELL) cierra dentro de una ZI vÃ¡lida â†’ cancelar. Comparar siempre con la extrema desde creaciÃ³n del patrÃ³n.



\### 5.4 PriorizaciÃ³n

\- De las \*\*Ãºltimas 3\*\* en misma direcciÃ³n, priorizar la \*\*mÃ¡s restrictiva\*\* (menor entry BUY, mayor entry SELL)

\- \*\*No priorizar entre direcciones opuestas:\*\* BUY y SELL pueden coexistir como pending, la que se active primero gana

\- MÃ¡ximo 2 Ã³rdenes pendientes simultÃ¡neas (Buy Limit + Sell Limit)



\### 5.5 Monotarea

\- \*\*Solo 1 posiciÃ³n abierta\*\* por sÃ­mbolo

\- Al activarse una pending â†’ eliminar la otra

\- Si ya hay posiciÃ³n abierta â†’ no activar ninguna nueva

\- SÃ­mbolos diferentes = independientes



\### 5.6 Cierre en ZI

\- Si vela que confirma patrÃ³n (envolvente P2, o quiebre P3) cierra dentro de ZI vÃ¡lida â†’ anular

\- Si la vela mÃ¡s extrema posterior al patrÃ³n cierra en ZI vÃ¡lida â†’ anular



\### 5.7 Horarios

\- 2 franjas configurables (defecto: 08:00-12:00 y 14:00-20:00)

\- AnÃ¡lisis 24/7, solo ejecuciÃ³n dentro de franjas

\- \*\*Cierre total diario a 21:50\*\* (configurable)



\### 5.8 Libertad del usuario

\- El usuario puede abrir/cerrar operaciones, modificar SL/TP sin interferencia del EA



---



\## 6. REQUISITOS FUNCIONALES (Inputs configurables)



\- % riesgo por operaciÃ³n

\- Magic Number

\- SÃ­mbolo permitido (o cualquiera)

\- LÃ­mite pÃ©rdida diaria (â‚¬ y %)

\- ON/OFF Breakeven y Trailing

\- 2 franjas horarias (inicio/fin cada una)

\- Hora cierre total (defecto 21:50)

\- ON/OFF dibujos visuales (zonas, PE)

\- Color zonas alcistas y bajistas

\- NÂº velas espera post-loss (defecto 13)

\- Ratio TP (defecto 4.2)

\- NÂº velas expiraciÃ³n zona (defecto 80)



---



\## 7. REQUISITOS NO FUNCIONALES



\### 7.1 Rendimiento

\- No congelar terminal ni consumir excesiva RAM

\- LÃ³gica solo al cierre de vela (OnTick filtrado por NewBar)



\### 7.2 Fiabilidad

\- Manejar errores de servidor (requotes, deslizamiento)

\- Bucle de reintentos para Ã³rdenes

\- Compatible ECN (Market Execution) y Standard (Instant Execution)



\### 7.3 Logs

\- Imprimir en pestaÃ±a "Expertos": zona detectada, patrÃ³n encontrado, operaciÃ³n rechazada por filtro, etc.

\- Notificaciones push a MT5 mÃ³vil



\### 7.4 Persistencia/VPS

\- RecoverExistingState: al reiniciar, buscar posiciones con MagicNumber

\- No duplicar Ã³rdenes

\- No ejecutar seÃ±ales retroactivas tras reinicio

\- Deep scan al inicio (50 velas PE, 60 velas zonas)



\### 7.5 Compatibilidad

\- Cualquier sÃ­mbolo y timeframe

\- Strategy Tester MT5

\- Optimizado para TF bajos (M1-M5)

\- Multi-sÃ­mbolo (cada grÃ¡fico independiente)



---



\## 8. CRITERIOS DE ACEPTACIÃ“N



1\. \*\*Prueba Visual:\*\* Dibujos fieles a las reglas

2\. \*\*Prueba de Backtest:\*\* Todas las situaciones y excepciones cubiertas

3\. \*\*CÃ³digo fuente:\*\* .mq5 limpio, comentado, compilable sin errores ni warnings

4\. \*\*IP:\*\* Propiedad exclusiva de Eduardo

