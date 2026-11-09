# Feature Specification: Reemplazo de Mobile Device Charges

**Feature Branch**: `danield772-github-spec-kit`

**Created**: 2026-11-04

**Status**: Draft - requisitos aclarados; listo para planificación

**Input**: User description: "Reemplazar y modernizar la página averiada Mobile Device
Charges del sitio Asset Voucher. Cada empleado debe consultar los dispositivos
celulares asignados a su nombre, su número de teléfono y su costo. La información
proviene de un Excel que un departamento actualiza mensualmente. La pantalla
principal y PC Asset Charges sirven como referencia."

**Clarifications (2026-11-09)**: La fuente es la hoja `Billing Data` con las columnas
`Description 2 - Emp Number`, `Mobile Number`,
`Equipment Payment Plan Charges` y `Activation Date`. El único importe disponible
es el cargo mensual; no existe un precio de adquisición separado. El período se
obtiene del prefijo `MM_YYYY` del nombre del archivo; el sufijo de versión cambia
con cada archivo recibido y no forma parte del período.

## Clarifications

### Session 2026-11-04

- Q: ¿El Excel de cada mes contiene todas las asignaciones móviles vigentes o solamente
  los cambios respecto al mes anterior? → A: Todas las asignaciones vigentes del mes.
- Q: ¿Qué dato del Excel identifica de forma única cada asignación móvil dentro de
  un mes? → A: El número de teléfono, único para cada asignación del mismo mes.
- Q: ¿Cómo verifica Asset Voucher actualmente la identidad del empleado que entra
  al sitio? → A: Reconoce automáticamente la cuenta corporativa del equipo.
- Q: ¿Quiénes deben tener permiso para cargar y publicar el Excel mensual en la
  aplicación? → A: Solo personal de TI expresamente autorizado.
- Q: ¿Qué meses debe permitir publicar la aplicación respecto al mes que ya está
  visible para los empleados? → A: El mismo mes para corregirlo o uno posterior;
  los meses anteriores se rechazan.

### Session 2026-11-09

- Q: ¿Qué hoja y columnas contiene el Excel móvil, y qué representa el importe?
  → A: La hoja `Billing Data` contiene `Description 2 - Emp Number`,
  `Mobile Number`, `Equipment Payment Plan Charges` y `Activation Date`.
  El importe es el cargo mensual; no hay precio de adquisición separado.
- Q: ¿Dónde se indica el período de facturación y cómo se reconoce una nueva
  versión del archivo? → A: El nombre empieza con `MM_YYYY`; el sufijo de versión
  aumenta cada vez que se recibe un archivo nuevo.
- Q: ¿La fecha `Activation Date` es obligatoria en cada fila? → A: Puede venir
  vacía.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consultar las asignaciones móviles propias (Priority: P1)

Como empleado, quiero consultar los dispositivos celulares asociados a mi identidad
para conocer los números de teléfono, el cargo mensual y la fecha de activación
registrados a mi nombre.

**Why this priority**: Es la función principal de la página que dejó de funcionar.

**Independent Test**: Con datos ficticios de dos empleados, abrir la consulta para
uno de ellos y comparar cada asignación, número de teléfono, cargo mensual y fecha
de activación con la fuente mensual, usando el número de empleado y sin mostrar
registros ajenos.

**Acceptance Scenarios**:

1. **Given** un empleado identificado y una fuente publicada con una asignación a
   su número de empleado, **When** consulta Mobile Device Charges, **Then** ve su
   contexto de empleado, el número de teléfono, el cargo mensual, la fecha de
   activación y el período de datos.
2. **Given** un empleado con varias asignaciones, **When** consulta la página,
   **Then** puede consultar todas sus asignaciones, sin incluir las de otra persona.
3. **Given** dos empleados con el mismo nombre visible, **When** uno consulta sus
   dispositivos, **Then** el sistema selecciona únicamente los registros de su
   número de empleado y no concede acceso por una coincidencia de nombres.
4. **Given** un cargo mensual válido de cero, **When** se presenta la asignación,
   **Then** se muestra como cero y no se confunde con un dato ausente.

---

### User Story 2 - Navegar desde Asset Voucher y regresar (Priority: P2)

Como empleado, quiero acceder desde la opción Mobile Device Charges y regresar a
la selección de Asset Voucher sin afectar la sección PC Asset Charges.

**Why this priority**: Conserva el recorrido conocido y limita el reemplazo a la
sección averiada.

**Independent Test**: Abrir la opción móvil desde la selección, regresar y comprobar
que PC Asset Charges sigue conduciendo a su sección existente, sin cambios en ella.

**Acceptance Scenarios**:

1. **Given** la selección de Asset Voucher, **When** el empleado elige Mobile Device
   Charges, **Then** llega a la consulta móvil en el contexto de su cuenta corporativa
   reconocida automáticamente, sin introducir un número de empleado para autorizarse.
2. **Given** la consulta móvil, **When** el empleado elige volver,
   **Then** regresa a la selección de Asset Voucher.
3. **Given** el reemplazo móvil disponible, **When** el empleado elige PC Asset
   Charges, **Then** conserva el acceso y comportamiento de esa sección.
4. **Given** un empleado que utiliza teclado o una pantalla estrecha,
   **When** recorre la consulta, **Then** puede alcanzar los controles y leer
   todos los números e importes sin depender exclusivamente de iconos o colores.

---

### User Story 3 - Publicar el Excel mensual de forma manual (Priority: P2)

Como integrante de TI expresamente autorizado, quiero cargar manualmente el Excel
mensual, verificar si sus datos son válidos y publicarlo, para que cada empleado
consulte la información del último período publicado y reconozca a qué mes corresponde.

**Why this priority**: La fuente cambia cada mes; una consulta correcta necesita
mostrar el período y evitar mezclar versiones de los datos.

**Independent Test**: Preparar dos conjuntos mensuales ficticios con una asignación
agregada, una retirada y un cargo mensual modificado; cargar y publicar el nuevo
archivo como responsable autorizado y verificar el resultado de la publicación
y el conjunto disponible para consulta, sin necesitar el recorrido de navegación.

**Acceptance Scenarios**:

1. **Given** un período publicado y otro nuevo válido, **When** el nuevo período
   se carga manualmente y se publica por un responsable autorizado, **Then**
   este recibe confirmación con el período publicado y la consulta refleja sus
   asignaciones, números, cargos mensuales y fechas de activación.
2. **Given** una asignación que ya no figura en el nuevo período,
   **When** se consulta el período recién publicado,
   **Then** la asignación anterior no continúa apareciendo como actual.
3. **Given** una actualización con datos obligatorios ausentes o asignaciones
   ambiguas, **When** el responsable carga el archivo, **Then** no sustituye el
   conjunto válido anterior y recibe un rechazo con los problemas que debe corregir.
4. **Given** una actualización aún no publicada, **When** un empleado consulta
   sus datos, **Then** no ve una mezcla del período anterior con el nuevo.
5. **Given** un empleado sin autorización para actualizar datos, **When** intenta
   cargar o publicar un archivo, **Then** el intento se rechaza y no modifica
   la información publicada.
6. **Given** el mismo conjunto mensual válido ya publicado, **When** el responsable
   vuelve a cargarlo y publicarlo, **Then** las asignaciones y los importes no se
   duplican y el período sigue identificado correctamente.
7. **Given** un archivo que repite un número de teléfono dentro del mismo mes,
   aunque lo asocie a empleados distintos, **When** el responsable lo carga,
   **Then** recibe un rechazo por asignación duplicada o contradictoria y el
   conjunto publicado permanece intacto.
8. **Given** una persona del departamento que mantiene el Excel o de TI sin
   autorización expresa para publicar, **When** intenta cargar o publicar datos,
   **Then** se rechaza el intento y no cambia el conjunto publicado.
9. **Given** un mes publicado y un Excel completo válido que corrige ese mismo mes,
   **When** TI autorizado lo publica, **Then** el conjunto corregido reemplaza
   por completo al anterior, conservando el mes y sin duplicar asignaciones.
10. **Given** un mes publicado y un archivo de un mes anterior, **When** TI autorizado
    intenta publicarlo, **Then** recibe un rechazo por período anterior y los datos
    vigentes no cambian.

---

### User Story 4 - Distinguir ausencia de dispositivos de un error (Priority: P2)

Como empleado, quiero saber si no tengo asignaciones o si la consulta no puede
obtener los datos, para no interpretar una falla como ausencia de cargos.

**Why this priority**: La página actual falla; el reemplazo debe comunicar los
errores sin divulgar detalles internos ni presentar resultados engañosos.

**Independent Test**: Probar por separado un empleado sin asignaciones, una fuente
no disponible y una identidad no verificable.

**Acceptance Scenarios**:

1. **Given** una fuente válida sin asignaciones para el empleado,
   **When** consulta sus datos, **Then** ve un mensaje de ausencia de dispositivos
   para el período consultado.
2. **Given** una fuente no disponible o sin un período publicado,
   **When** consulta sus datos, **Then** ve un mensaje de indisponibilidad,
   no una lista vacía presentada como consulta exitosa.
3. **Given** una identidad que no puede verificarse o vincularse de forma única,
   **When** se solicita la consulta, **Then** no se divulgan asignaciones y
   se comunica que la consulta no puede completarse.
4. **Given** una falla interna, **When** se muestra el error al empleado,
   **Then** el mensaje no contiene credenciales, identificadores internos
   de conexión ni detalles de ejecución.
5. **Given** una cuenta corporativa que no se reconoce automáticamente o no tiene
   correspondencia inequívoca con un número de empleado, **When** se abre la consulta,
   **Then** el sistema no permite sustituir esa verificación escribiendo un número
   y no divulga asignaciones.

### Edge Cases

- Un empleado tiene cero, una o varias asignaciones móviles en el mismo período.
- Dos empleados comparten nombre; la asociación debe seguir siendo inequívoca.
- La fuente contiene un número de teléfono con prefijo internacional, espacios
  o ceros iniciales; la presentación no debe perder sus caracteres significativos.
- El cargo mensual es cero, falta o tiene un formato inválido; estos casos no son
  equivalentes y el valor no se sustituye por un concepto inexistente.
- La fecha de activación puede estar vacía; cuando está presente debe tener un
  formato válido y no debe confundirse con el período mensual del archivo.
- La fuente repite una misma asignación en el mismo período o contiene asignaciones
  contradictorias; no se duplican costos ni se resuelve la contradicción
  silenciosamente. El teléfono identifica la asignación y no puede repetirse en el
  mismo mes; un número de empleado sí puede tener varios teléfonos distintos.
- La actualización mensual falla, llega tarde o aún no se publica;
  nunca debe presentarse una versión anterior como si fuera del nuevo período.
- El responsable carga un archivo que no es Excel, está ilegible o no contiene los
  datos obligatorios; recibe un rechazo y la información publicada queda intacta.
- El mismo archivo se publica más de una vez; no se duplican asignaciones ni importes.
- Se carga un archivo de un mes anterior al vigente; se rechaza su publicación.
- Se corrige el mes vigente; el archivo completo corregido sustituye al anterior,
  sin combinar ambas versiones del mismo mes.
- La fuente nueva retira o reasigna un dispositivo; cada empleado ve únicamente
  las asignaciones que le corresponden en el período publicado.
- La fuente incluye monedas o conceptos de costo distintos; no se mezclan
  ni se convierten importes sin una regla aprobada.
- Una persona sin identidad autorizada intenta consultar datos de otro empleado;
  no obtiene información de sus dispositivos, teléfonos ni costos.
- Un empleado intenta actualizar la fuente sin autorización; no puede publicar
  cambios mediante la carga manual.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST reemplazar la consulta Mobile Device Charges
  manteniendo su entrada desde Asset Voucher; PC Asset Charges queda fuera del cambio.
- **FR-002**: El sistema MUST verificar la identidad del empleado antes de divulgar
  asignaciones mediante la cuenta corporativa que Asset Voucher reconoce
  automáticamente. MUST limitar la consulta al número de empleado asociado
  inequívocamente a esa cuenta verificada; si no puede verificarse la cuenta
  o su correspondencia, MUST denegar la consulta sin divulgar asignaciones.
- **FR-003**: La asociación entre Asset Voucher y la fuente mensual MUST realizarse
  por número de empleado, no por nombre visible; proporcionar el número de otra
  persona MUST NOT autorizar la consulta de sus asignaciones.
- **FR-004**: La consulta MUST listar todas las asignaciones celulares propias
  del período publicado, mostrando el número de teléfono, el cargo mensual y la
  fecha de activación de cada una, además del contexto del empleado.
- **FR-005**: La página MUST presentar `Equipment Payment Plan Charges` como
  cargo mensual con una etiqueta inequívoca; MUST NOT inventar un precio de
  adquisición ni calcular cargos que no existan en la fuente.
- **FR-006**: Los números de teléfono MUST conservar sus caracteres significativos;
  el cargo MUST conservar el valor de la fuente e identificar la moneda solo
  cuando esta se encuentre definida en la fuente, sin inferirla por un símbolo.
  La fecha de activación, cuando esté presente, MUST presentarse como atributo de
  la asignación, no como período de facturación; si está vacía, la página MUST
  indicar que no está disponible.
- **FR-007**: La consulta MUST identificar el mes de los datos publicados y
  distinguir ese período de la fecha en que se realiza la consulta.
- **FR-008**: Los datos de consulta MUST poder actualizarse desde el Excel mensual
  mediante una carga manual en la aplicación disponible únicamente para personal
  de TI expresamente autorizado a cargar y publicar. Pertenecer al departamento
  que prepara el Excel o a TI MUST NOT conceder automáticamente ese permiso;
  la primera versión no incluye carga automática.
- **FR-009**: Antes de publicar una actualización, la carga manual MUST comprobar
  que el Excel es legible, que incluye la hoja `Billing Data` con las columnas
  `Description 2 - Emp Number`, `Mobile Number`,
  `Equipment Payment Plan Charges` y `Activation Date`, y que contiene datos
  válidos de número de empleado, teléfono, cargo mensual, fecha de activación
  cuando esté presente, y período obtenido del nombre del archivo. La fecha de
  activación vacía MUST NOT invalidar por sí sola una fila.
  El teléfono MUST identificar una única asignación en cada mes. La carga MUST
  rechazar archivos inválidos y teléfonos repetidos en el mismo período, incluso
  si corresponden a empleados diferentes; MUST explicar al responsable los problemas
  encontrados y conservar la versión válida publicada. Varias asignaciones con
  teléfonos distintos para un mismo número de empleado son válidas.
- **FR-010**: Cada Excel mensual MUST representar todas las asignaciones vigentes
  del período. Su publicación MUST sustituir por completo el conjunto anterior
  para la consulta actual; las asignaciones ausentes en el nuevo archivo MUST dejar
  de mostrarse, sin mezclar versiones ni conservar registros por omisión.
- **FR-011**: El sistema MUST distinguir una consulta válida sin asignaciones de
  una consulta que falló o no pudo verificar la identidad.
- **FR-012**: Los errores MUST comunicar la indisponibilidad o el rechazo de una
  actualización de forma explícita y MUST NOT divulgar detalles internos sensibles.
- **FR-013**: La página MUST permitir regresar a la selección de Asset Voucher
  y presentar título, contexto de empleado y listado legible, tomando PC Asset
  Charges como referencia estructural, no como obligación de copiar su diseño antiguo.
- **FR-014**: La consulta MUST poder operarse con teclado y permitir leer cada
  número y costo en pantallas de escritorio y estrechas; los controles MUST
  tener etiquetas comprensibles sin depender únicamente de imágenes o color.
- **FR-015**: Los empleados MUST NOT modificar asignaciones, costos ni datos
  de la fuente a través de esta consulta; la actualización queda limitada
  al proceso autorizado definido para la fuente mensual.
- **FR-016**: La publicación manual MUST confirmar explícitamente el resultado
  y el período publicado; una carga o publicación fallida MUST NOT presentarse
  como exitosa ni alterar el conjunto válido anterior.
- **FR-017**: Volver a publicar el mismo conjunto mensual válido MUST NOT
  duplicar asignaciones ni cargos mensuales.
- **FR-018**: Cuando exista un período publicado, la aplicación MUST permitir
  publicar un Excel completo válido del mismo mes como corrección o de un mes
  posterior. MUST rechazar la publicación de un mes anterior, con un mensaje
  explícito y sin modificar el conjunto vigente. La comparación MUST realizarse
  contra el período vigente al publicar; una corrección MUST sustituir por completo
  el conjunto del mismo mes, sin mezclar sus versiones.

### Key Entities *(include if feature involves data)*

- **Empleado**: Persona identificada que consulta sus asignaciones; tiene una
  identidad de acceso, un nombre visible y un número de empleado que permite
  relacionarla inequívocamente con la fuente mensual.
- **Asignación móvil**: Asociación de un dispositivo celular con un empleado
  para el período publicado; se identifica por el número de teléfono y el mes,
  e incluye número de empleado, cargo mensual y fecha de activación.
- **Cargo mensual**: Importe `Equipment Payment Plan Charges` registrado en la
  fuente para la línea o dispositivo. No existe un importe de adquisición separado.
- **Fecha de activación**: Fecha `Activation Date` asociada con la línea; puede
  no estar informada y no es el período de facturación.
- **Conjunto mensual**: Información autorizada procedente del Excel para un mes,
  con todas las asignaciones vigentes, datos validados y un estado de publicación.
- **Responsable de actualización**: Integrante de TI expresamente autorizado
  para cargar y publicar manualmente el Excel mensual. El departamento que prepara
  la fuente no recibe permiso de publicación por mantener el archivo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En el conjunto de aceptación ficticio, el 100% de las asignaciones,
  números de teléfono, cargos mensuales y fechas de activación mostrados coincide
  con el período publicado para cada número de empleado, incluyendo empleados
  con cero, una y varias asignaciones.
- **SC-002**: En el 100% de los escenarios de acceso no autorizado y de empleados
  con nombres iguales, no se divulga ninguna asignación de otra persona.
- **SC-003**: En condiciones habituales de acceso corporativo, al menos el 95%
  de las consultas muestra el listado o un estado explícito en cinco segundos
  desde que el empleado abre Mobile Device Charges.
- **SC-004**: Al menos el 90% de los participantes de la prueba de uso puede
  identificar un número de teléfono y su cargo mensual, reconocer la fecha de
  activación y el período, y regresar a Asset Voucher en un minuto, sin ayuda.
- **SC-005**: El 100% de las pruebas de actualización mensual refleja las altas,
  bajas, reasignaciones y cambios de costo de un único período publicado;
  ninguna actualización rechazada modifica el conjunto válido anterior.
- **SC-006**: El 100% de las pruebas de ausencia de asignaciones, indisponibilidad
  de datos e identidad no verificable presenta estados distinguibles,
  sin revelar información interna sensible.
- **SC-007**: El 100% de los recorridos de aceptación de PC Asset Charges conserva
  su navegación y comportamiento después de habilitar el reemplazo móvil.
- **SC-008**: En el 100% de las pruebas de carga manual, el responsable puede
  distinguir publicación exitosa y rechazo; los archivos inválidos y los intentos
  sin autorización no cambian los datos, y repetir una publicación no los duplica.
- **SC-009**: El 100% de las pruebas de corrección del mismo mes refleja únicamente
  el conjunto corregido; el 100% de los intentos de publicar meses anteriores
  al vigente se rechaza sin modificar las asignaciones ni los importes publicados.

## Assumptions

- **Alcance confirmado**: Reemplazar únicamente Mobile Device Charges; no
  reconstruir todo Asset Voucher ni modernizar PC Asset Charges.
- **Referencia visual**: Las capturas muestran una selección con las dos opciones,
  contexto de empleado y regreso; PC Asset Charges muestra título y una tabla con
  datos por activo e importes. Estos patrones orientan la experiencia móvil.
- **Límite de la referencia**: Las columnas Serial, Type, User Name y Location,
  los enlaces de detalle y el total visibles en PC Asset Charges no demuestran
  que existan datos o reglas equivalentes para celulares. No se incorporan
  como funciones obligatorias de esta primera especificación.
- **Motivo del reemplazo**: La captura móvil evidencia una falla de acceso a datos.
  No confirma reglas de negocio ni obliga a recuperar el origen averiado;
  el Excel mensual es la fuente solicitada para el reemplazo.
- **Consulta de lectura**: El empleado consulta sus propias asignaciones;
  no se incluyen edición, aprobación, pago, reclamaciones, exportaciones
  ni consulta general de otros empleados.
- **Histórico**: La primera versión muestra el último período publicado;
  no incluye un selector de meses ni consulta histórica.
- **Identidad existente confirmada**: Asset Voucher reconoce automáticamente
  la cuenta corporativa del equipo. El reemplazo conserva esa verificación;
  no incluye registro de cuentas nuevas ni acceso autorizado mediante la
  introducción de un número de empleado.
- **Dependencia de identidad**: Durante la planificación se debe verificar
  cómo Asset Voucher proporciona la relación confiable entre la cuenta corporativa
  reconocida automáticamente y su número de empleado.
- **Estructura de datos confirmada**: La hoja fuente es `Billing Data`; sus
  encabezados son `Description 2 - Emp Number`, `Mobile Number`,
  `Equipment Payment Plan Charges` y `Activation Date`. No hay un precio de
  adquisición separado. El prefijo `MM_YYYY` del nombre identifica el período;
  el sufijo numérico de versión se incrementa con cada archivo recibido y no
  identifica un período diferente. La fecha de activación no reemplaza al período.
- **Dependencia de datos**: Antes de implementar se deben verificar, con una
  muestra anonimizada, el formato de archivo, el formato de la fecha de activación,
  la moneda si está especificada, y la representación del teléfono.
  No se incorporarán datos reales de empleados a la especificación.
- **Actualización inicial**: La carga y publicación mensual es manual y la realiza
  personal de TI expresamente autorizado. El departamento responsable continúa
  preparando el Excel; no se incluye edición individual de filas en la aplicación.
- **Corte mensual confirmado**: Cada archivo contiene todas las asignaciones
  vigentes del mes, no únicamente los cambios. Su publicación sustituye por completo
  el conjunto de consulta anterior.
- **Correcciones confirmadas**: Se permite sustituir el conjunto completo del mes
  vigente para corregirlo y publicar meses posteriores; no se permite retroceder
  a un mes anterior mediante la carga manual.
- **Evolución solicitada**: La actualización automática se abordará después de
  confirmar que la versión manual funciona correctamente. Queda fuera de esta
  primera entrega; sus mecanismos y criterios de habilitación deberán especificarse
  antes de implementarla.
- **Sin reglas inventadas**: No se calculan cargos, elegibilidad, descuentos
  ni conversiones monetarias que el departamento responsable no haya definido.
