# Narrativa de la demo — formato 5 minutos (one-take)

> Idioma: **español** (relato en cámara).
> English talk track: [`demo-narrative-5min.en.md`](demo-narrative-5min.en.md).
> Guion cronometrado en inglés: [`docs/demo-script.md`](demo-script.md) § Five-minute one-take.
> Relato completo (~9–10 min): [`demo-narrative-v1.md`](demo-narrative-v1.md).

Estado: variante de grabación / slot corto. **Mismas cuatro pruebas A–D** y los dos cambios en vivo. Sin digresión `ls`. Sin recaps largos. Pensado para **one-take** (sin jump-cuts de edición): el ritmo sale del ensayo, no del montaje.

## Mensaje

Cuando hablamos con clientes sobre arquitecturas agénticas, la seguridad es uno de los mayores challenges. Con **BYOA** podemos desplegar cualquier agente/harness — y eso es peligroso si no hay guardrails: skills, scripts, internet, tareas complejas por defecto. Esta demo muestra las **capabilities de seguridad de RHOAI** para ayudar a desplegar agentes de forma segura en producción. En 5 minutos **demostramos** cuatro controles; no instalamos nada en escena.

## Diferencias vs el relato de 10 min

| En 10 min | En 5 min (one-take) |
|---|---|
| Intro gap modelos/seguridad (~55s) | Hook de **~45s**: challenge cliente + BYOA + dos paneles |
| Explicar → pegar prompt | **Pegar → Play → una frase** |
| Digresión `haz un ls` tras B | **Cortada** |
| Recap de 3 capas antes de D (~40s) | **Una frase** al vuelo |
| Esperar el script de recon en cámara | Narrar encima; si el modelo se alarga, avanzar al Change 2 en cuanto se vea código útil |
| MLflow con varias invocaciones | **Curl deny → allow** (misma traza, distinta Response) |
| Cierre amplio | Overall Demo **Play** + roadmap/GitOps/RHPDS + tagline |

Backstage, políticas y scripts: iguales que v1 (`default.yaml` → `demo-allow-google-egress.sh` → `demo-enable-guardrails.sh`; reset con `demo-reset.sh`).

## Relato en vivo (5:00)

Pantalla partida: [`v5/live.html`](demo/v5/live.html) (izquierda) + Control UI / OpenClaw (derecha). Misma sesión de chat para A–C; **New session** solo antes de D-after (tras Change 2), como en v1.

### 0:00–0:45 — Hook + dos paneles

**Texto (relato):**

Cuando tenemos conversaciones con nuestros clientes para hacer uso de arquitecturas agénticas, la seguridad es uno de los mayores challenges que nos encontramos.

Con el BYO agent estamos habilitando el poder desplegar cualquier agente/harness, y esto puede ocasionar muchos problemas de seguridad si no somos capaces de configurar unos guardrails de seguridad para limitar lo que puede o no hacer. Ejecutar skills, crear scripts, acceder a internet — en definitiva es un agente que por defecto puede hacer muchas tareas complejas y potencialmente peligrosas.

Es por esto que hemos preparado una demo para hacer un showcase de las capabilities de seguridad que proporciona RHOAI, de forma que nos permita ayudar a nuestros clientes a desplegar de forma segura estos agentes en sus entornos productivos.

La demo está organizada en dos paneles: a la izquierda vemos una representación visual de la arquitectura con una serie de pasos guiados que nos permiten explicar distintos escenarios de seguridad; a la derecha tenemos OpenClaw, que usaremos como harness para interactuar con el modelo y ver cómo se comporta.

*(Companion en paso A o Overall Demo listo; no hace falta recorrer todo el mapa capa a capa.)*

### 0:45–1:15 — Prueba A (`inference.local` / API key)

1. **Copy prompt** (auditor de key — mismo que v1 / `demo-script.md`).
2. **Play** en Control UI.

**Esperado:** sin key real (`apiKey: unused` / env vacío). El agente no sabe qué modelo usa ni tiene la API key: habla con `inference.local`; el gateway inyecta la credencial.

**Frase:** “La key la inyecta el gateway; el sandbox no la tiene.”

### 1:15–1:40 — Prueba B (`/etc/shadow` / Landlock)

1. **Copy prompt** (`cat /etc/shadow`).
2. **Play**.

**Esperado:** Permission denied (OpenShell sandbox / Landlock).

**Frase:** “Los ficheros de sistema ya estaban cerrados desde el minuto cero.”

No hacer `ls` ni contraste de workspace.

### 1:40–2:45 — Prueba C + Change 1 (egress)

#### C.before — conectividad controlada (OpenShell gateway)

1. **Copy prompt** (`curl -sI https://google.com`).
2. **Play** → **bloqueado**.

**Frase:** “Controlamos la conectividad del agente desde el gateway.”

#### C.after — modo permisivo

1. Terminal visible: `./scripts/demo-allow-google-egress.sh` — explicar la config (allowlist google.com; agente en modo permisivo para ese destino).
2. Mismo prompt.
3. **Play** → **HTTP 200** (o 301 hacia google).

**Frase:** “Una palanca de política; no rebuild del sandbox. El agente no cambia.”

Avanzar companion a C-after cuando el 200 esté en pantalla.

### 2:45–4:05 — Prueba D + Change 2 (NeMo)

#### D.before — full access to model capabilities

1. **Copy prompt** (recon de red — mismo que v1).
2. **Play** → respuesta potencialmente peligrosa (script / plan de recon).

Mientras genera: “Sin Guardrails, el modelo puede entregar la tarea peligrosa; no hace falta que la ejecute.”

#### D.after — NeMo Guardrails in action

1. Explicar NeMo Guardrails (TrustyAI): capa de seguridad en el path de inferencia.
2. Terminal: `./scripts/demo-enable-guardrails.sh`.
3. **New session** en Control UI.
4. Mismo prompt → **Play** → rechazo / rail (“I can't respond” o equivalente).

**Frase:** “OpenClaw sigue en `inference.local`; cambia el backend. Quien corta es el guardrail, no el harness.”

Si el modelo se demora en D-before: no rellenar con teoría; a ~3:50 de reloj, lanzar Change 2 aunque el script no haya terminado (el contraste before/after sigue siendo válido si el before ya generó código).

### 4:05–4:30 — MLflow (trazabilidad)

Abrir Gen AI Studio / experimento `openclaw-tracing` de **esta** sesión (o pestaña MLflow del companion).

Mostrar el **curl a google**: misma clase de traza, **otra Response** — blocked vs allowed. Con MLflow tenemos trazabilidad completa: acciones, comandos, invocaciones al LLM, prompts.

**Frase:** “Éxitos y bloqueos en el mismo sitio — observabilidad de plataforma, no un extra.”

Si no da tiempo: solo el contraste curl deny → allow.

### 4:30–4:45 — Overall Demo + resumen

Volver al paso **Overall Demo** en el companion y dar a **Play**. Mientras corre, un resumen corto del camino de seguridad que acabamos de ver (credenciales, ficheros, egress, Guardrails, trazas).

### 4:45–5:00 — Roadmap + GitOps + cierre

Señalar funcionalidades que vamos a añadir (nice-to-have del proyecto): red teaming con EvalHub/Garak ([`demo-narrative-v2.md`](demo-narrative-v2.md)), MCP Gateway, cost/showback.

**Frase:** “Todo el despliegue está basado en GitOps; sería sencillo levantarlo en RHPDS / demo.redhat.com.”

Tagline: *Your Agent. Our Platform. Production-Ready.*

## Timing (reloj)

| Bloque | Reloj | Tope duro |
|---|---|---|
| Hook + dos paneles | 0:00–0:45 | 0:50 |
| A | 0:45–1:15 | 1:20 |
| B | 1:15–1:40 | 1:45 |
| C + Change 1 | 1:40–2:45 | 2:50 |
| D + Change 2 | 2:45–4:05 | 4:10 |
| MLflow | 4:05–4:30 | 4:35 |
| Overall Demo Play | 4:30–4:45 | 4:50 |
| Roadmap + GitOps + tagline | 4:45–5:00 | 5:00 |

Si el reloj llega a **4:10** sin D-after: saltar a New session + prompt de rechazo; comprimir MLflow a ~20s; intentar Overall + la frase GitOps/RHPDS.

## Preflight (igual que v1)

```bash
./scripts/demo-reset.sh
./scripts/demo-presenter-serve.sh
# New session en Control UI antes de grabar
```

Skills: `demo-backstage-prep`, `demo-present`, `demo-allow-google-egress`, `demo-enable-guardrails`, `mlflow-tracing-validate`.

## Ensayo one-take

- Cronometrar con reloj visible; no pausar la grabación.
- Prompts ya en el companion (**Copy prompt**); no teclear a mano; ritmo **prompt → Play**.
- Scripts de Change 1/2 en historial de terminal (Enter, no buscar el path).
- Si un prompt LLM tarda: avanzar al siguiente hito del reloj; no improvisar digresiones.
- Ensayar el salto a Overall Demo + la frase GitOps/RHPDS para que quepan en 15s.

## Relación con v1

Misma arquitectura, mismos scripts, mismas pruebas. Este archivo solo **comprime el relato** para un slot de 5 minutos (hook de cliente, beats prompt→Play, cierre Overall + roadmap). Para el runbook largo y el contexto de producto, usar [`demo-narrative-v1.md`](demo-narrative-v1.md).
