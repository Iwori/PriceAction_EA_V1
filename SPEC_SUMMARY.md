# RESUMEN COMPLETO DE ESPECIFICACIONES — EA PriceAction MT5

## Documento fuente: Especificación v2 de Eduardo Antonio Uriel Sánchez (13/02/2026)

## Actualización v3: Feedback de backtesting por video (22/02/2026)

## Plataforma: MT5 (MQL5) | Símbolo óptimo: US100 M3 | Compatible: cualquier símbolo/TF

---

## 1. PUNTOS ESTRUCTURALES (PE)

### 1.1 Formaciones

- **PE alcista:** Vela bajista + vela alcista, O bajista + Doji + alcista
- **PE bajista:** Vela alcista + vela bajista, O alcista + Doji + bajista
- **Doji:** cierre == apertura (mechas irrelevantes)

### 1.2 Nivel del PE

- **PE alcista:** MIN(cierre_bajista, apertura_alcista). Con Doji: MIN(cierre_bajista, cierre_doji, apertura_alcista). Solo cuerpos, no mechas.
- **PE bajista:** MAX(cierre_alcista, apertura_bajista). Con Doji: MAX(cierre_alcista, cierre_doji, apertura_bajista). Solo cuerpos, no mechas.

### 1.3 Espacios vacíos

Se buscan en las **4 velas anteriores** y **4 velas siguientes** a la formación.

**Izquierda (primero):** Revisar 4 velas antes de la 1ª vela del PE (alcista si PE bajista, bajista si PE alcista), de DERECHA a IZQUIERDA:

- Vela NO toca nivel PE (ni mecha ni cuerpo) → cuenta como espacio vacío
- Vela toca con mecha → pasar a la siguiente (izquierda)
- Vela abre o cierra (solo O/C, no mechas) POR ENCIMA del nivel (PE bajista) o POR DEBAJO (PE alcista), o EXACTAMENTE en el nivel → **STOP: no hay más búsqueda, si no había espacio vacío aún → NO HAY PE**

**Derecha (solo si ≥1 espacio izq):** Revisar 4 velas después de la última vela del PE (alcista si PE alcista, bajista si PE bajista), de IZQUIERDA a DERECHA:

- Mismas reglas que izquierda
- **PE NO EXISTE hasta que una de las 4 velas siguientes CIERRE creando espacio vacío**

### 1.4 Normal vs Estricto

- **Normal:** Al menos 1 espacio vacío a cada lado, pero un lado tiene solo 1
- **Estricto:** ≥2 espacios vacíos a cada lado (no necesariamente consecutivos)

---

## 2. ZONAS DE INTERÉS (ZI)

### 2.1 ZI basada en PE

Requiere PE válido (formación + mín 1 espacio vacío cada lado). Luego:

- **PE alcista → ZI alcista:** cuerpo vela bajista < cuerpo vela alcista
- **PE bajista → ZI bajista:** cuerpo vela alcista < cuerpo vela bajista
- La zona cubre **TODA la vela** (incluye mechas), aunque la verificación usa solo cuerpos

### 2.2 ZI basada en frenazo

**ZI alcista** (formaciones):

- Alcista + bajista + alcista
- Alcista + Doji + bajista + alcista
- Alcista + bajista + Doji + alcista
- Alcista + 2 bajistas + alcista
- Alcista + Doji + 2 bajistas + alcista
- Alcista + 2 bajistas + Doji + alcista
- "Frenazo" = todas las velas entre la 1ª y 2ª alcista (sin incluirlas)

**ZI bajista:** Simétrico con bajistas.

**[v3] Regla de quiebre de la vela anterior (pre-condición del frenazo):**

- Si la vela ANTERIOR a la 1ª vela de la formación es de **dirección opuesta**, la 1ª vela DEBE haber cerrado **por encima del máximo** (ZI alcista) o **por debajo del mínimo** (ZI bajista) de esa vela anterior. Es decir, debe quebrarla completamente. Si no la quiebra → **NO es frenazo válido**.
- Si la vela anterior es de **misma dirección** que la 1ª vela → no se aplica esta restricción.
- Si la vela anterior es **Doji** → mirar una vela más atrás.

**Quiebre del frenazo (ZI alcista):**

1. Si la última vela alcista CIERRA > MAX(mechas frenazo) → zona confirmada automáticamente
2. Si no: esperar que alguna vela siguiente cierre > MAX(mechas frenazo) ANTES de que una vela cierre < MIN(cierres frenazo). Si cierra debajo primero → SE ANULA
3. Sin límite de velas, sin importar dirección

**Quiebre del frenazo (ZI bajista):** Simétrico invertido.

### 2.3 Condiciones del frenazo (body ratio)

Cuando la vela ANTERIOR a la formación es de dirección opuesta a la 1ª vela:

- Suma cuerpos frenazo / cuerpo 1ª vela > 1.5 → **NO hay zona**
- **[v3] Adicionalmente:** la 1ª vela de la formación NO puede ser mayor al **150%** del tamaño (cuerpo) de la vela anterior opuesta. Si lo supera → **NO hay zona**.
- Si la vela anterior es misma dirección → sin límite
- Si la vela anterior es Doji → mirar una más atrás

### 2.4 Propiedades comunes de zonas

1. Una zona puede ser PE + frenazo a la vez (no marcar doble)
2. Zonas pueden crearse dentro de otras zonas
3. **La vela siguiente a la que CREA la zona NO puede mitigar ESA zona** (sí las anteriores)
   - Crea zona PE: vela que crea espacio vacío derecho habiendo izquierdo
   - Crea zona frenazo: vela que quiebra el frenazo
4. **Zonas que se tocan = una sola** (Grand Zone / fusión)

### 2.5 Mitigación

**Total:** El precio penetra a través de la zona. Para zona alcista: bar low ≤ extremo inferior. Para zona bajista: bar high ≥ extremo superior. Da igual si es cuerpo o mecha.
**Parcial:** Una vela entra en la zona pero no la penetra completamente. Da igual si cierra dentro o no. Doji también mitiga.
**ZI válida** = zona completa nunca mitigada O trozo restante de zona parcialmente mitigada.

**[v3] Regla de temporalidad de la mitigación (importante para P2/P3):**

- La mitigación de una zona aplica **a partir de la vela siguiente**. La vela que cierra dentro de una zona y al mismo tiempo la mitiga (parcial o totalmente) **sí se considera como cierre en zona válida** a efectos de detección de patrones. Es decir: primero se evalúa si la vela cerró en zona válida (para P2/P3), y después se aplica la mitigación para velas futuras.

### 2.6 Expiración

- A las **80 velas** (configurable) desde la vela que CONFIRMA la zona → zona inválida

---

## 3. PATRÓN 2

### 3.1 Formación

- **ZI alcista (→ BUY):** Vela bajista cierra DENTRO de ZI alcista no mitigada + vela alcista ENVOLVENTE. O con Doji intermedio.
- **ZI bajista (→ SELL):** Vela alcista cierra DENTRO de ZI bajista no mitigada + vela bajista ENVOLVENTE. O con Doji intermedio.
- **Envolvente:** Cuerpo mayor que cuerpo de vela anterior. Si anterior es Doji → comparar con 2ª anterior.
- **[v3] REQUISITO OBLIGATORIO:** La vela anterior a la envolvente DEBE cerrar dentro de una ZI válida. Si no cierra en ninguna zona, la envolvente por sí sola NO genera patrón 2 bajo ninguna circunstancia.

### 3.2 Excepción wick (2 velas anteriores)

- Las 2 velas anteriores a la formación NO pueden invalidar dibujando MECHA en el precio de cierre de la 1ª vela de la formación
- Si la 1ª vela cierra en zona "recién mitigada por mechas de las 2 anteriores" → se ignora la mitigación y se procede igual
- Condición: las 2 velas solo mitigan con MECHA (no cuerpo) en el nivel de cierre
- **[v3] Aclaración:** Si alguna de las 2 velas anteriores mitiga la zona con CUERPO (no mecha) en el nivel de cierre, la excepción NO aplica y la zona se considera mitigada.

### 3.3 Fibonacci 1

- **ZI alcista (BUY):** 100% = MIN(cotización con mechas) de formación + 2 velas anteriores (4 o 5 velas). 0% = cierre envolvente.
- **ZI bajista (SELL):** 100% = MAX(cotización con mechas) de formación + 2 velas anteriores. 0% = cierre envolvente.
- **Tamaño patrón 2** = distancia 0%→100% del Fib1

### 3.4 Cap del SL (Fib1)

- Tamaño P2 / indicador ≥ 1 → SL máximo en **175%** del Fib1
- Tamaño P2 / indicador < 1 → SL máximo en **200%** del Fib1

### 3.5 Búsqueda de ZI y PE para colocar SL (Fib2)

4. Buscar ZI válidas entre 100% y 123% del Fib1
5. Buscar PE con nivel entre 100% y 140% del Fib1

**Si encuentra ZI** (entre 100-123%): alargar Fib hasta extremo de la ZI. Si ZI se solapa con otra → incluir esa también. 100% nuevo = extremo ZI (respetando cap 175/200%).
**Si encuentra solo PE** (entre 100-140%): alargar Fib hasta mín/máx alcanzado por velas del PE (con mechas). 100% nuevo = extremo PE (respetando cap 175/200%).
**Si ZI + PE:** priorizar PE.
**Si zonas solapadas:** incluir todas las zonas conectadas.

### 3.6 Sin ZI ni PE

- **Con tendencia previa** (alguna vela de últimas 70 cerró/abrió más allá del 100%):
  - P2/indicador < 2.5 → SL en fib 1.40
  - P2/indicador ≥ 2.5 → SL en fib 1.23
- **Sin tendencia previa:** SL en fib **1.15**

### 3.7 Tabla de entrada (Fib2)

Tamaño Fib2 / indicador (ATR medido en vela envolvente):

| Ratio         | Entrada          |
| ------------- | ---------------- |
| ≤ 1.3         | Directa (Market) |
| > 1.3 y ≤ 1.6 | 23% Fib          |
| > 1.6 y ≤ 2.8 | 38% Fib          |
| > 2.8 y ≤ 3.5 | 50% Fib          |
| > 3.5         | 61% Fib          |

### 3.8 SL en Patrón 2

SL = 100% del Fib2 + **5% de holgura** sobre el tamaño del SL

---

## 4. PATRÓN 3

### 4.1 Formación

- **ZI bajista (→ BUY):** Vela alcista cierra dentro de ZI bajista + vela bajista/Doji (frenazo)
- **ZI alcista (→ SELL):** Vela bajista cierra dentro de ZI alcista + vela alcista/Doji (frenazo)
- Regla wick 2 velas anteriores: IGUAL que Patrón 2

### 4.2 Espera de quiebre

- **BUY:** Esperar que una vela CIERRE por encima del extremo SUPERIOR de la ZI bajista
- **SELL:** Esperar que una vela CIERRE por debajo del extremo INFERIOR de la ZI alcista

### 4.3 Tamaño del Patrón 3

- Medir desde que se forma el frenazo hasta que se confirma el quiebre
- Extremos: máximos y mínimos (con mechas) de todas las velas entre frenazo y quiebre (incluidas)
- **Si tamaño P3 > 2× tamaño ZI → NO hay patrón** (cancelar)
- Si el quiebre ocurre antes de superar 2×ZI → hay patrón (medir se detiene)

### 4.4 Solapamiento con ZI (P3 ampliado)

- Si ZI alcista (BUY) o bajista (SELL) de misma dirección se solapa con el Fib del P3 (extremo toca entre 0% y 100%) → fusionar → **tamaño P3 ampliado**
- Puede encadenarse: zona toca zona toca zona...
- La cancelación por >2×ZI solo usa el tamaño P3 INICIAL, no el ampliado

### 4.5 Fibonacci P3

- **BUY:** 100% = extremo inferior P3 (o P3 ampliado), 0% = extremo superior
- **SELL:** 100% = extremo superior P3, 0% = extremo inferior

### 4.6 Tabla de entrada P3

Ratio = (tamaño P3 o P3 ampliado) / indicador. ATR medido en **1ª vela alcista (BUY) o 1ª vela bajista (SELL)** del patrón:

| Ratio         | Entrada |
| ------------- | ------- |
| < 1.5         | 33% Fib |
| ≥ 1.5 y < 2.5 | 40% Fib |
| ≥ 2.5 y < 3.5 | 50% Fib |
| ≥ 3.5         | 61% Fib |

### 4.7 SL Patrón 3 — Situación normal

Ratio = (tamaño P3 o P3 ampliado) / indicador:

| Ratio          | SL en Fib |
| -------------- | --------- |
| ≤ 0.5          | 300%      |
| > 0.5 y ≤ 0.85 | 220%      |
| > 0.85 y ≤ 1   | 200%      |
| > 1            | 150%      |

- **5% holgura** sobre tamaño SL (abajo en BUY, arriba en SELL)

### 4.8 Excepciones SL P3

**1. Si hay PE** (entre 100% Fib y nivel SL normal):

- SL → mín/máx alcanzado por velas del PE (con mechas)
- PE solo ACORTA el SL, nunca lo alarga más allá de la holgura normal
- Cap = nivel de holgura normal

**2. Si hay ZI** (el nivel SL normal toca una ZI de misma dirección):

- ZI NO debe solaparse con el tamaño del patrón (entre 0-100% Fib)
- Si sí se solapa → ya es P3 ampliado, colocar normalmente
- Si no se solapa: nuevo Fib desde extremo ZI hasta extremo superior P3
  - Ratio nuevo/indicador < 2.5 → entrada 50%
  - Ratio ≥ 2.5 → entrada 61%
  - SL en 105% del nuevo Fib (cubre ZI completa)
- **ZI ALARGA el SL sin límite**

**3. Si PE + ZI a la vez:** priorizar ZI

### 4.9 Regla que impide P3 (impulso ≥6×)

- Medir impulso anterior (opuesto a la dirección del trade)
- Impulso = vela directriz + ≥2 intermedias + vela de cierre que quiebra apertura de la 1ª
- Intermedias: cualquier dirección, pero no pueden cerrar más allá del extremo de la 1ª vela
- Medir indicador en la vela a MITAD del impulso
- Si tamaño impulso / indicador(mitad) ≥ 6 → **NO tomar P3**
- Si impar (ej 31 velas), usar vela nº floor(N/2) = 15

---

## 5. REGLAS COMUNES

### 5.1 Gestión de riesgo

- **TP = 4.2 × SL** (configurable)
- **Holgura SL = 5%** siempre (abajo BUY, arriba SELL)
- **Riesgo = 0.5% del balance** (configurable)
- Si no hay margen suficiente → ajustar lotaje al máximo disponible

### 5.2 Breakeven y Trailing

**Stage 1** — Activar cuando: ratio ≥ 1:1.3 O 2 PE estrictos formados post-entry

- Mover SL a: extremo inferior ZI alcista (BUY) o superior ZI bajista (SELL)
- Si no hay ZI → usar PE: mín PE alcista (BUY) o máx PE bajista (SELL)
- **Priorizar ZI sobre PE**
- SL NO puede superar el nivel de entrada aún

**Stage 2** — Activar cuando: ratio ≥ 1:3

- SL puede superar el nivel de entrada
- Mover a: PE ESTRICTO o **PENÚLTIMA** ZI formada (misma dirección)
- Misma priorización: ZI sobre PE
- Solo ZI/PE de misma dirección que el trade

### 5.3 Anulación de entradas

1. **13 velas post-loss:** Tras operación perdedora (profit < 0), no abrir hasta que cierren 13 velas (configurable). Seguir analizando, pero no colocar órdenes. Si la señal se habría activado durante las 13 velas → descartar (ya pasó momento óptimo).

2. **2+ PE estrictos:** Buy Limit + 2 PE alcistas estrictos formados después → cancelar. Sell Limit + 2 PE bajistas estrictos → cancelar.

3. **Precio avanza > 2.5× tamaño patrón:** Buy Limit y vela alcista cierra > 2.5× desde cierre envolvente (P2) o extremo superior P3 → cancelar. Sell Limit simétrico.

4. **Cierre extremo en ZI opuesta:** Si la vela alcista más alta (BUY) o bajista más baja (SELL) cierra dentro de una ZI válida → cancelar. Comparar siempre con la extrema desde creación del patrón.

### 5.4 Priorización

- De las **últimas 3** en misma dirección, priorizar la **más restrictiva** (menor entry BUY, mayor entry SELL)
- **No priorizar entre direcciones opuestas:** BUY y SELL pueden coexistir como pending, la que se active primero gana
- Máximo 2 órdenes pendientes simultáneas (Buy Limit + Sell Limit)

### 5.5 Monotarea

- **Solo 1 posición abierta** por símbolo
- Al activarse una pending → eliminar la otra
- Si ya hay posición abierta → no activar ninguna nueva
- **[v3] Aclaración:** Bajo NINGUNA circunstancia puede haber una compra y una venta abiertas simultáneamente. Si hay una posición activa (compra o venta), todas las órdenes pendientes deben cancelarse y no se abre ninguna operación nueva hasta que la posición actual se cierre.
- Símbolos diferentes = independientes

### 5.6 Cierre en ZI

- Si vela que confirma patrón (envolvente P2, o quiebre P3) cierra dentro de ZI válida → anular
- Si la vela más extrema posterior al patrón cierra en ZI válida → anular

### 5.7 Horarios

- 2 franjas configurables (defecto: 08:00-12:00 y 14:00-20:00)
- Análisis 24/7, solo ejecución dentro de franjas
- **Cierre total diario a 21:50** (configurable)

### 5.8 Libertad del usuario

- El usuario puede abrir/cerrar operaciones, modificar SL/TP sin interferencia del EA

---

## 6. REQUISITOS FUNCIONALES (Inputs configurables)

- % riesgo por operación
- Magic Number
- Símbolo permitido (o cualquiera)
- Límite pérdida diaria (€ y %)
- ON/OFF Breakeven y Trailing
- 2 franjas horarias (inicio/fin cada una)
- Hora cierre total (defecto 21:50)
- ON/OFF dibujos visuales (zonas, PE)
- Color zonas alcistas y bajistas
- **[v3] Colores diferenciados por origen de zona:**
  - ZI basada en frenazo alcista: azul normal (como está)
  - ZI basada en frenazo bajista: rojo normal (como está)
  - ZI basada en PE alcista: azul oscuro
  - ZI basada en PE bajista: rojo oscuro
  - Motivo: cuando dos zonas del mismo color se solapan, MetaTrader anula el color en la intersección (se ve blanco), dificultando el análisis visual.
- Nº velas espera post-loss (defecto 13)
- Ratio TP (defecto 4.2)
- Nº velas expiración zona (defecto 80)

---

## 7. REQUISITOS NO FUNCIONALES

### 7.1 Rendimiento

- No congelar terminal ni consumir excesiva RAM
- Lógica solo al cierre de vela (OnTick filtrado por NewBar)

### 7.2 Fiabilidad

- Manejar errores de servidor (requotes, deslizamiento)
- Bucle de reintentos para órdenes
- Compatible ECN (Market Execution) y Standard (Instant Execution)

### 7.3 Logs

- Imprimir en pestaña "Expertos": zona detectada, patrón encontrado, operación rechazada por filtro, etc.
- Notificaciones push a MT5 móvil

### 7.4 Persistencia/VPS

- RecoverExistingState: al reiniciar, buscar posiciones con MagicNumber
- No duplicar órdenes
- No ejecutar señales retroactivas tras reinicio
- Deep scan al inicio (50 velas PE, 60 velas zonas)

### 7.5 Compatibilidad

- Cualquier símbolo y timeframe
- Strategy Tester MT5
- Optimizado para TF bajos (M1-M5)
- Multi-símbolo (cada gráfico independiente)

---

## 8. CRITERIOS DE ACEPTACIÓN

1. **Prueba Visual:** Dibujos fieles a las reglas
2. **Prueba de Backtest:** Todas las situaciones y excepciones cubiertas
3. **Código fuente:** .mq5 limpio, comentado, compilable sin errores ni warnings
4. **IP:** Propiedad exclusiva de Eduardo

---

## 9. HISTORIAL DE CAMBIOS

### v3 — 22/02/2026 (Feedback video backtesting)

- **Sec 2.2:** Nueva regla de quiebre de vela anterior para frenazo. La 1ª vela debe quebrar completamente la vela anterior si es de dirección opuesta.
- **Sec 2.3:** Aclaración: la 1ª vela del frenazo no puede superar 150% del tamaño de la vela anterior opuesta.
- **Sec 2.5:** Regla de temporalidad de mitigación — la vela que cierra en zona válida y la mitiga se evalúa primero como cierre en zona para P2/P3, luego se aplica mitigación para velas futuras.
- **Sec 3.1:** Énfasis en requisito obligatorio de cierre en ZI para P2. Envolvente sin cierre previo en zona NO genera patrón.
- **Sec 3.2:** Aclaración sobre excepción wick — si el cuerpo (no mecha) de las 2 velas anteriores cruza el nivel, la excepción no aplica.
- **Sec 5.5:** Refuerzo de monotarea — bajo ninguna circunstancia compra y venta simultáneas.
- **Sec 6:** Colores diferenciados para ZI basadas en PE (oscuro) vs frenazo (normal).
