# Revisión 2/2 — Scaffold iOS, ejecutores y CI

Revisión del 22 de septiembre de 2026 sobre `main`, commit `c1ec591a4110e224eb8ac6b7d995eadfc845f8a8`; los números de línea corresponden a ese árbol y las referencias a issues, a sus cuerpos consultados hoy.

Verificado: repositorio público; ningún ruleset; protección clásica de `main` devuelve 404; runner `wsl-nico` (id 21) conectado y disponible; ralph instalado en v1.2.1; ningún label `ralph-host:*`; todavía no existen `Karta/` ni `KartaPresentation`.

Ejecuté `. "$HOME/.local/share/swiftly/env.sh" && swift test --package-path KartaCore`: **53 tests en 18 suites, todos verdes**, con Swift 6.3.2 en Linux; no ejecuté XcodeGen, Xcode ni un simulador, y los bloques siguientes son propuestas, no implementaciones verificadas en macOS.

## 1. Scaffold de #1

1. **P1 — #1 puede arrancar antes de existir su contrato** ([issue #1, «Blocked by»](https://github.com/nicoamigosa/karta/issues/1), `KartaCore/Package.swift:7`): declara «None» aunque exige productos, store, frontera y texto que siguen pendientes en #31, #32, #37, #46 y #49. **Acción:** bloquear #1 por #32, #36, #37, #38, #45, #46, #47, #48 y #49 —#31 y las reglas de seguridad quedan incluidas transitivamente— y entregar a Devin un SHA integrado donde el store ya conecte esos comportamientos.

2. **P1 — `Bundle.module` pertenece a un target, no al paquete entero** (`docs/adr/0001-kartapresentation-target-separado.md:18`, `KartaCore/Package.swift:13`, `RecipeCatalog.swift:16` y `TechniqueClip.swift:44` en `KartaCore/Sources/KartaCore/`): mover únicamente el adaptador a Presentation deja los recursos y el accessor interno en Core, contradiciendo además el criterio de #31 que prohíbe `Bundle` en Core. **Acción:** en #31 mover ambos JSON a `Sources/KartaPresentation/Resources/`, trasladar allí `.process("Resources")`, exponer un adaptador público inyectable y aclarar en ADR 0001 esa propiedad física de los recursos; Core conserva exclusivamente el decode puro y sus reglas ([recursos SwiftPM](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package)).

3. **P1 — el scaffold carece de configuración ejecutable** (`AGENTS.md:29`, `AGENTS.md:53`): no fija ubicación del proyecto, productos enlazados, test host ni esquema compartido. **Acción:** usar el `project.yml` completo siguiente, generar `Karta/Karta.xcodeproj`, reservar `Karta/App` para el shell y `Karta/Tests` para la integración alojada en la app; versionar el YAML y excluir el proyecto generado ([especificación XcodeGen](https://yonaskolb.github.io/XcodeGen/Docs/ProjectSpec.html)).

4. **P1 — las fotos no tienen un suministro acordado** (`KartaCore/Sources/KartaCore/Resources/seed-recipes.json:5`, [#45](https://github.com/nicoamigosa/karta/issues/45)): el seed contiene URLs de `img.karta.app`, pero el contrato no aporta assets ni demuestra que esas URLs sirvan imágenes. **Acción:** entregar con #45 un manifiesto y fotos autorizadas que cubran cada receta del seed, usar referencias locales para el scaffold y verificar una foto real por tarjeta sin red; un placeholder prueba el estado de carga, pero no cumple la aceptación de hero photo.

5. **P2 — el test existente no verifica el empaquetado iOS ni la cantidad esperada** (`KartaCore/Tests/KartaCoreTests/RecipeCatalogTests.swift:11`, [#1, «Acceptance criteria»](https://github.com/nicoamigosa/karta/issues/1)): comprueba únicamente que la colección no esté vacía y que tenga ingredientes y pasos. **Acción:** conservar esos comportamientos y la seguridad en Linux, y añadir un único test Swift Testing alojado en la app que cargue el adaptador real sin URL de fixture, compare los IDs con la lista editorial aprobada de #32 y compruebe ingredientes/pasos, detectando así un bundle ausente o un seed equivocado.

6. **P2 — el mínimo de plataforma está atribuido a un ADR que no lo contiene** (`docs/adr/0001-kartapresentation-target-separado.md:1`, [#31, «Acceptance criteria»](https://github.com/nicoamigosa/karta/issues/31)): iOS 17/macOS 14 aparece en #31 y en el banner de #1, pero falta en ADR 0001 y en el manifest actual. **Acción:** registrar esos mínimos por Observation en ADR 0001 y declararlos en el paquete, manteniendo `SWIFT_VERSION: "6.0"` como modo de lenguaje y Swift 6.3 como versión del compilador.

### `Karta/project.yml` completo propuesto

Requiere que #31 ya publique los dos productos y que existan `App/` y `Tests/`; el bundle id es una propuesta concreta para simulador, sin team ni aprovisionamiento de dispositivo.

```yaml
name: Karta
options:
  minimumXcodeGenVersion: 2.46.0
  deploymentTarget:
    iOS: "17.0"
configs:
  Debug: debug
  Release: release
packages:
  KartaCore:
    path: ../KartaCore
settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  Karta:
    type: application
    platform: iOS
    sources:
      - path: App
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.nicoamigosa.karta
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Karta
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
    dependencies:
      - package: KartaCore
        product: KartaCore
      - package: KartaCore
        product: KartaPresentation
  KartaTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.nicoamigosa.karta.tests
        GENERATE_INFOPLIST_FILE: YES
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Karta.app/Karta"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: Karta
      - package: KartaCore
        product: KartaCore
      - package: KartaCore
        product: KartaPresentation
schemes:
  Karta:
    build:
      targets:
        Karta: all
        KartaTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      gatherCoverageData: true
      targets:
        - name: KartaTests
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
```

Topología que debe materializar #31 y consumir #1:

```text
KartaCore/
  Package.swift
  Sources/
    KartaCore/                     reglas, decode puro, modelos
    KartaPresentation/             estado, reducers, store, formato, adaptador
      Resources/
        seed-recipes.json
        seed-clips.json
  Tests/
    KartaCoreTests/
    KartaPresentationTests/        import público; incluye seed y observación
Karta/
  project.yml
  App/                            @main, composición y vistas SwiftUI
    Assets.xcassets/               fotos locales y recursos propios del shell
  Tests/                          test alojado del bundle real
```

El manifest declara `platforms: [.iOS(.v17), .macOS(.v14)]`, ambos productos, `KartaPresentation` con dependencia de `KartaCore` y `resources: [.process("Resources")]`, y un test target por biblioteca. El shell llama al adaptador público de Presentation; nunca a `Bundle.module` directamente ni a una copia del JSON en `Bundle.main`. Los adaptadores de almacenamiento/red, la detección de visibilidad, reproducción y efectos físicos permanecen en iOS; transiciones, elegibilidad, fechas inyectadas, resultados de carga y formato se prueban en Linux.

## 2. Contrato de AGENTS.md para ralph y Devin

1. **P1 — el routing documentado desactiva una capacidad ya instalada** (`AGENTS.md:128`, `ralph/README.md:221`): dice que falta soporte upstream, aunque v1.2.1 filtra por host y los issues sin label pueden ejecutarse en cualquiera. **Acción:** crear `ralph-host:linux` y `ralph-host:macos`, asignar Linux a #29–#49 y macOS a #1, #2 y #4–#15, conservando `ralph-needs-human` donde corresponda y exigiendo exactamente un host a cada issue ejecutable.

2. **P1 — hay dependencias descritas en prosa que el scheduler no ve** ([#2](https://github.com/nicoamigosa/karta/issues/2), [#6](https://github.com/nicoamigosa/karta/issues/6), [#8](https://github.com/nicoamigosa/karta/issues/8), [#46](https://github.com/nicoamigosa/karta/issues/46), sección «Blocked by»): citar #38, #36 o #39 en un banner no impide empezar, y #46 puede cerrarse antes de integrarse el feed que #1 espera consumir. **Acción:** además del bloqueo de #1, añadir #43 a #2, #36 a #6, #39/#41 a #7, #38/#39 a #8, #34/#40/#43 a #4, #40/#48 a #9, #47 a #10 y #45 a #12, y exigir una comprobación Linux del store integrado al finalizar los productores antes de abrir la sesión Devin.

3. **P1 — no hay propietario del gate de revisión de Devin** (`AGENTS.md:87`, `AGENTS.md:118`, `AGENTS.md:133`): exige PASS para todo PR, atribuye todos los merges al loop y a la vez entrega iOS a un agente que no pasa por ese loop. **Acción:** distinguir PR de ralph, revisado y fusionado por el loop, de PR de Devin, cuya revisión independiente y merge con gates verificados coordina Nico; Devin termina con el PR y sus pruebas, nunca con una aprobación o merge propio.

4. **P1 — #1 promete un feed incondicionalmente no vacío** ([#1, banner](https://github.com/nicoamigosa/karta/issues/1), `CONTEXT.md:36`, `docs/adr/0004-frontera-de-lo-nuevo.md:24`): ese texto permite rellenarlo con recetas inseguras cuando no hay ninguna compatible. **Acción:** sustituirlo por «El feed continúa por debajo de la frontera mientras haya recetas compatibles; sin respuesta de intolerancias se muestra el estado de onboarding, y sin recetas compatibles se muestra el estado específico, sin relajar seguridad», separando el perfil explícito de prueba del arranque real.

5. **P2 — #4 conserva una aceptación contraria a la decisión vigente** ([#4, «Probably cooked»](https://github.com/nicoamigosa/karta/issues/4), `docs/adr/0008-cocinado-inferido-por-la-sesion.md:10`): pide inferencia por permanencia en el último paso sin el banner correctivo que sí tienen otras issues. **Acción:** reemplazar ese criterio por consumo del resultado de sesión completa de #40 y hacer que #4 sólo renderice y comunique los eventos del shell.

6. **P2 — el encabezado y el arranque contradicen el contrato detallado** (`AGENTS.md:4`, `AGENTS.md:21`, `AGENTS.md:23`): atribuyen todo al loop, llaman a las tres capas «two targets» y siguen titulando que toda la lógica va a Core. **Acción:** reemplazar esos textos por el bloque siguiente, mantener la separación actual de tres capas y declarar que «nunca saltarse FeedQuery» significa consumirlo a través del store, sin invocarlo desde las vistas.

7. **P2 — faltan comandos reproducibles y evidencia por criterio** (`AGENTS.md:29`, `AGENTS.md:56`, `docs/mac-handoff.md:42`): la orden no fija directorio/proyecto, runtime ni Xcode y la instalación de XcodeGen queda a interpretación de Devin. **Acción:** añadir el contrato macOS siguiente y actualizar el setup del handoff para que remita a él, quitando el comando `open Karta.xcodeproj` desde una ubicación ambigua y el recuento histórico de tests.

### Texto de sustitución para AGENTS.md

Para introducción, encabezado Architecture, Workflow/Gates y Running ralph:

```markdown
Work is tracked in GitHub issues. Linux issues run through ralph; iOS shell
issues are implemented by Devin on macOS. There are two SwiftPM library
targets and one iOS application target.

## Architecture — rules in Core, state in Presentation, rendering in Karta

Views read the KartaPresentation store and send actions. The store reaches
recipes through the domain queries; views never call or bypass FeedQuery.
Bundle resource loading belongs to KartaPresentation, with resources owned
by that target. File storage, network transport and physical effects belong
to Karta. Test their policies and state transitions in the Linux packages.

## Execution and review

Every ready issue has exactly one ralph-host:linux or ralph-host:macos label.
Host routing already exists in installed ralph v1.2.1. ralph runs only on Linux;
Devin handles macOS issues outside the loop. Dependencies must be open-issue
references under Blocked by, not only prose references in a banner.

Before Devin starts, all package blockers must be merged and the public store
integration must pass Linux tests at the handoff SHA. Record the public API,
seed expectations, assets and acceptance evidence required in the issue.

Both executors branch from current main and use ralph/issue-<N>. Every PR
contains What changed, Seams under test, How I verified, Open decisions and
Acceptance criteria. All package logic follows the tdd skill with Swift
Testing; never disable tests or lower expectations to pass CI.

Every merge requires KartaCore (Linux) and iOS gate success, plus an independent
reviewer PASS for the exact current head SHA. ralph handles its own PR review
and merge. Nico arranges independent review and maintainer merge for Devin
PRs. Devin never approves, merges or closes issues. A new head invalidates PASS.

Use Closes #N in the PR body and commit body only when every criterion is
verified, including macOS simulator evidence where required. Otherwise use
Part of #N. Linux-only work never claims simulator verification. Closing is
a consequence of the authorized merge, not an action by the implementing agent.

Run from the repository root on WSL:

    . "$HOME/.local/share/swiftly/env.sh"
    export RALPH_TDD_SKILL=/home/nico/.codex/skills/tdd/SKILL.md
    test -r "$RALPH_TDD_SKILL"
    swift test --package-path KartaCore
    ./ralph/once.sh

Production requires RALPH_REQUIRE_PROTECTION=1 and
RALPH_REQUIRE_REVIEWER_TOKEN=1. Configure the read-only reviewer credential
in the protected host environment before running; missing protection or
credentials stops the run and never triggers a fallback to sandbox mode.
```

### Texto macOS para AGENTS.md y contrato de #1

Baseline propuesta: runner `macos-26`, Xcode **26.4.1 (17E202)**, Swift **6.3**, simulador **iPhone 17 / iOS 26.4**; están documentados en la [imagen oficial del runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md) y en la [tabla de compatibilidad de Apple](https://developer.apple.com/xcode/system-requirements). iOS 17 sigue siendo el deployment target, no la versión del runtime de CI; la tabla actual no enumera iPhone 16 para ese runtime. Esta ejecución no certifica comportamiento en iOS 17: añadir una comprobación con ese runtime cuando se verifique la compatibilidad mínima del producto.

```markdown
### macOS / Devin

Provision the VM before starting the paid implementation session: macOS 26.2
or later in the 26.x family, Xcode 26.4.1 (17E202), iOS 26.4 Simulator runtime,
and an iPhone 17 simulator. Fail setup if these are absent; do not silently
substitute another Xcode or runtime. Use the same toolchain in iOS CI.

From the repository root, with Homebrew and git already available:

    export DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer
    xcodebuild -version
    xcrun swift --version
    xcrun simctl list devices available
    brew install xcbeautify
    KARTA_XCODEGEN_DIR=$(mktemp -d /tmp/karta-xcodegen.XXXXXX)
    git clone --depth 1 --branch 2.46.0 https://github.com/yonaskolb/XcodeGen.git "$KARTA_XCODEGEN_DIR"
    test "$(git -C "$KARTA_XCODEGEN_DIR" rev-parse HEAD)" = 8445e778451c7e44237b90281bde622d764b0084
    xcrun swift build --package-path "$KARTA_XCODEGEN_DIR" -c release --product xcodegen
    "$KARTA_XCODEGEN_DIR/.build/release/xcodegen" --version
    xcrun swift test --package-path KartaCore
    "$KARTA_XCODEGEN_DIR/.build/release/xcodegen" generate --spec Karta/project.yml
    xcodebuild -list -project Karta/Karta.xcodeproj

The pinned XcodeGen binary above generates the project in both CI and Devin.
Cache that binary by source commit, platform, architecture and Xcode build.

Run the following in Bash from the repository root; use a fresh result path
on repeated runs because xcodebuild refuses an existing xcresult directory:

    set -euo pipefail
    mkdir -p artifacts
    xcodebuild -project Karta/Karta.xcodeproj -scheme Karta \
      -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
      -derivedDataPath .build-ios/DerivedData \
      -clonedSourcePackagesDirPath .build-ios/SourcePackages \
      -resultBundlePath artifacts/Karta.xcresult \
      CODE_SIGNING_ALLOWED=NO test 2>&1 \
      | tee artifacts/xcodebuild.log | xcbeautify

Karta/Tests contains a hosted Swift Testing bundle test using public imports
of KartaCore and KartaPresentation. It loads the production seed adapter,
checks the exact editorial recipe ID set agreed in #32 and checks non-empty
ingredients and steps. Do not copy the JSON into the test target or use a
test fixture URL instead of the production adapter.

For #1 attach the xcresult and log, a screenshot showing hero photo, name,
time, difficulty and servings, and a simulator recording scrolling between
different recipe IDs. Record the simulator, Xcode build and tested Git SHA.
The hosted test proves packaging; the recording proves scroll/render behavior.
Use the explicit test profile agreed in the Linux handoff, without bypassing
the store or treating unanswered intolerances as an empty safety profile.

Do not commit Karta/Karta.xcodeproj, .build-ios or artifacts. They are generated
outputs; CI uploads artifacts for review. UI interaction automation is outside
the hosted unit test; under the current no-XCTest rule, capture simulator
interaction evidence without claiming an XCUITest suite exists.
```

## 3. CI pública y protección efectiva

1. **P0 — código de PR puede ejecutarse en la máquina personal** (`.github/workflows/ci.yml:17` y `:27`): ambos jobs usan el runner `wsl-nico` en un repositorio público y un contenedor no elimina ese acceso persistente. **Acción:** detener su servicio y retirarlo de Settings → Actions → Runners, cancelar runs pendientes destinados a él, cambiar ambos jobs a `ubuntu-24.04` y eliminar el contenedor de `detect`, conservando `swift:6.3` sólo en `core`; retirar el registro evita que un PR vuelva a seleccionar `self-hosted` ([seguridad de runners](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)).

2. **P1 — ralph puede rechazar la CI verde actual** (`.github/workflows/ci.yml:44`, `ralph/README.md:70`): el SHA revisado tiene `Karta app (iOS Simulator)=skipped` y la configuración por defecto del loop exige éxito en todos los checks descubiertos. **Acción:** añadir el check agregador `iOS gate`, siempre ejecutado y con validación explícita de sus dependencias, y fijar `RALPH_REQUIRED_CHECKS_JSON='["KartaCore (Linux)","iOS gate"]'` tanto en configuración como en ruleset.

3. **P1 — omitir macOS para todo cambio de Core debilita la integración** (`.github/workflows/ci.yml:35`, `KartaCore/Package.swift:4`): un cambio de API, disponibilidad o recursos del paquete puede pasar Linux y romper el consumidor SwiftUI. **Acción:** aplicar filtros dentro del workflow, ejecutar iOS ante `Karta/**`, `KartaCore/Sources/**`, `KartaCore/Package.swift`, lockfiles, scripts de build y `.github/workflows/**`, y omitirlo sólo para documentación o tests exclusivos de paquete; ejecutar también iOS en todo push a `main` cuando exista la app.

4. **P1 — la detección permite desaparecer al target sin fallo** (`.github/workflows/ci.yml:35`): borrar `Karta/project.yml` hace que iOS se omita como si el scaffold no hubiera llegado nunca. **Acción:** comparar base y head, fallar si había proyecto en base y desaparece en head, rechazar un `.xcodeproj` sin su YAML y permitir ausencia únicamente durante la fase anterior al scaffold; no usar `paths` en el trigger de un workflow requerido porque puede dejar el check pendiente ([checks omitidos](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)).

5. **P1 — `main` no impone ninguna gate** (`AGENTS.md:15`, API `repos/nicoamigosa/karta/rulesets`): devuelve `[]`, por lo que PASS y CI son convenciones del ejecutor y la configuración prescrita desactiva el preflight. **Acción:** instalar primero los checks estables, crear el ruleset activo sin bypass del bloque siguiente y activar ambos requisitos de ralph con el token lector separado.

6. **P2 — el entorno iOS cambia sin revisar el contrato** (`.github/workflows/ci.yml:45`, `:52`, `:58`): `macos-latest`, XcodeGen sin versión y un destino sin runtime no fijan el compilador ni aseguran que exista el dispositivo. **Acción:** usar `macos-26`, `DEVELOPER_DIR` de Xcode 26.4.1, el XcodeGen 2.46.0 del contrato y el destino iPhone 17/iOS 26.4, validándolos antes de generar; el runner seguirá actualizándose y la ausencia del baseline debe fallar explícitamente.

7. **P2 — el formatter no está instalado explícitamente** (`.github/workflows/ci.yml:52`, `:59`): el job instala XcodeGen pero presupone `xcpretty`, y el pipeline complica conservar el resultado de las pruebas. **Acción:** instalar `xcbeautify`, usar Bash con `set -euo pipefail`, `2>&1 | tee ... | xcbeautify --renderer github-actions` y subir log/xcresult incluso al fallar; el código actual con `PIPESTATUS[0]` no demuestra por sí mismo un falso verde ([uso oficial de xcbeautify](https://github.com/cpisciotta/xcbeautify#github-actions)).

8. **P2 — no hay límites ni reutilización de builds** (`.github/workflows/ci.yml:8`, `:41`): los jobs carecen de timeouts, cancelación de ejecuciones obsoletas y caché. **Acción:** fijar timeouts de 15/3/25/2 minutos para core/detect/ios/gate, cancelar ejecuciones anteriores del mismo PR, restaurar `.build-ios/DerivedData` y `.build-ios/SourcePackages` con claves de SO/arquitectura/build de Xcode/XcodeGen/hash de manifest-lockfiles-project y SHA, y guardar caché sólo desde `push` a `main`, sin omitir nunca `test` por un cache hit.

9. **P2 — el workflow no declara mínimos permisos** (`.github/workflows/ci.yml:3`, `:20`): depende de la configuración global del token y del checkout con credenciales persistidas. **Acción:** declarar `permissions: {contents: read}`, usar `persist-credentials: false` en los checkouts y fijar las actions a SHAs auditados; si la detección usa la API de archivos del PR, conceder exclusivamente `pull-requests: read` a ese job ([permisos de Actions](https://docs.github.com/en/actions/reference/security/secure-use)).

### Configuración concreta de detección y gate

El workflow se dispara para todos los PR y pushes a `main`, sin filtro global. `detect` hace checkout con historial suficiente, calcula el diff desde merge-base para PR y desde `before` para push, valida presencia del scaffold en base/head y publica `run_ios=true|false`; cualquier error al resolver referencias o calcular cambios termina en fallo, nunca en «sin cambios». Los SHA del evento se pasan mediante variables de entorno, y los nombres de archivo se procesan delimitados por NUL. En el primer push sin base resoluble se ejecuta iOS si existe el scaffold, en lugar de inferir que no hace falta.

```yaml
permissions:
  contents: read
concurrency:
  group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# Fragmento de jobs; core conserva name: KartaCore (Linux).
# detect expone run_ios después de validar las reglas anteriores.
# ios usa needs: detect y if: needs.detect.outputs.run_ios == 'true'.
jobs:
  ios-gate:
    name: iOS gate
    runs-on: ubuntu-24.04
    timeout-minutes: 2
    needs: [detect, ios]
    if: always()
    steps:
      - name: Require the expected iOS outcome
        shell: bash
        env:
          DETECT_RESULT: ${{ needs.detect.result }}
          RUN_IOS: ${{ needs.detect.outputs.run_ios }}
          IOS_RESULT: ${{ needs.ios.result }}
        run: |
          set -euo pipefail
          test "$DETECT_RESULT" = success
          case "$RUN_IOS:$IOS_RESULT" in
            true:success|false:skipped) exit 0 ;;
            *) exit 1 ;;
          esac
```

| Caso | Resultado obligatorio |
|---|---|
| App aún ausente en base y head | core success; iOS omitido; gate success |
| PR sólo de documentación o tests Linux | core success; iOS omitido; gate success |
| Cambio en fuentes/manifest/recursos de paquete con app existente | core success; iOS success; gate success |
| Creación o cambio del shell; cambio de workflow | core success; iOS success si existe shell; gate success |
| Push a main con shell existente | core success; iOS success; gate success |
| Borrado del scaffold, fallo de detect o iOS cancelado cuando era necesario | gate failure |

Antes de exigir los checks, probar esos casos con PRs de validación y confirmar que un fallo de `swift test` también impide merge; la gate no sustituye la revisión de cambios al propio workflow.

El paquete no tiene dependencias remotas hoy: la caché SwiftPM remota aporta poco hasta que las haya; DerivedData sí puede reducir recompilaciones. Usar restore keys sólo dentro de la misma combinación de herramientas/configuración, conservar un lockfile versionado cuando aparezcan dependencias remotas y sacar ese archivo de la exclusión global de `.gitignore:4`. Subir `artifacts/` con `if: always()` y retención de siete días, sin credenciales en cachés ni artefactos.

### Ruleset mínimo y configuración del loop

Payload propuesto para `POST /repos/nicoamigosa/karta/rulesets`, tras ejecutar con éxito los nuevos checks; `15368` es el id de la GitHub App Actions observado en los check-runs actuales ([API de rulesets](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset)).

```json
{
  "name": "main-ci-no-bypass",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {"include": ["refs/heads/main"], "exclude": []}
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "KartaCore (Linux)", "integration_id": 15368},
          {"context": "iOS gate", "integration_id": 15368}
        ]
      }
    }
  ]
}
```

No añadir bypass para el propietario, administrador, bot o merge por PR. No activar merge queue sin ampliar el workflow a `merge_group`. Con checks estrictos, actualizar una rama atrasada y repetir pruebas/revisión del nuevo head antes del merge.

Contenido propuesto de `.ralph/config.env`, sin secretos:

```bash
RALPH_CI_POLICY=required
RALPH_REQUIRED_CHECKS_JSON='["KartaCore (Linux)","iOS gate"]'
RALPH_REQUIRE_PROTECTION=1
RALPH_REQUIRE_REVIEWER_TOKEN=1
```

Provisionar `RALPH_REVIEWER_GH_TOKEN` como fine-grained PAT limitado a `nicoamigosa/karta`, distinto del token del orquestador y con lectura de Metadata, Contents, Issues y Pull requests; guardarlo únicamente en el entorno protegido del host, como especifica `ralph/README.md:522`. No he inspeccionado secretos del host: el estado real del token no se deduce de que AGENTS diga que falta.

Este mínimo permite el preflight de ralph con `RALPH_REVIEW_IDENTITY` sin configurar: **GitHub exige CI y PR; el loop exige además PASS**. Un PAT lector separado no constituye una identidad revisora independiente ni puede publicar aprobaciones; si se configura `RALPH_REVIEW_IDENTITY` distinta, ralph exige una aprobación obligatoria o `ralph-review`, y habrá que provisionar un publicador externo autorizado, vinculado al SHA, antes de exigir esa señal. El ruleset mínimo no impide que un mantenedor fusione el PR de Devin sin PASS: el contrato asigna a Nico esa comprobación, y convertirla en garantía del servidor requiere esa segunda integración.

## Cambios en AGENTS.md / CI que haría antes de lanzar el loop

1. Retirar `wsl-nico` de Actions y mover core/detect a runners hospedados.
2. Instalar `iOS gate` con detección que falle ante errores o desaparición del scaffold.
3. Exigir `KartaCore (Linux)` e `iOS gate` por nombre en ralph y en un ruleset activo sin bypass.
4. Provisionar el PAT lector y activar ambos requisitos de protección, eliminando la excepción sandbox del contrato productivo.
5. Crear/asignar labels de host y corregir la frase que afirma que falta soporte upstream.
6. Corregir dependencias de #1 y de las issues de shell, y exigir el store integrado y probado antes de Devin.
7. Resolver la propiedad de los recursos en #31 y completar ADR 0001 con mínimos de plataforma.
8. Incorporar el project.yml y el contrato reproducible de macOS, assets y evidencia por criterio.
9. Asignar explícitamente revisión independiente y merge de los PRs de Devin, con PASS ligado al head actual.
10. Añadir filtros por dependencias reales, timeouts, concurrencia, caché y artefactos a CI.
