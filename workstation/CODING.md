# Convenciones del entorno

Responde siempre en espanol. El codigo, los nombres y los comentarios tecnicos van en ingles, salvo pedido contrario.

Trabaja solo dentro de /workspace. No inventes credenciales, hosts ni claves SSH. Si falta un dato, dilo y deja un placeholder claro.

## Calidad

- Cambios pequenos y completos. No reescribas archivos grandes si alcanza con editar la parte afectada.
- Antes de dar por bueno PHP: `php -l <archivo>` y, si el proyecto ya tiene config, `phpstan analyse --memory-limit=256M -c /opt/ai/phpstan.neon <archivo>`.
- HTML semantico, CSS en archivos aparte, JavaScript en modulos. Sin estilos ni scripts inline salvo que el usuario lo pida.
- Formularios y APIs: validar entrada, escapar salida (`htmlspecialchars`), consultas solo con prepared statements o binds. Nunca concatenar SQL.
- Errores de usuario en espanol. Errores tecnicos, sin filtrar secretos ni stack traces al navegador en codigo que vaya a produccion.

## PHP

- PHP 8.3, `declare(strict_types=1);`, PSR-12, tipos en parametros y retornos.
- PDO, no `mysql_*` ni `mysqli_query` con SQL armado a mano.
- Separar entrada HTTP, reglas de negocio y acceso a datos. Nada de logica de negocio en la plantilla.

## HTML, CSS y JavaScript

- Documento con `lang`, viewport y titulos utiles.
- CSS moderno (custom properties, grid/flex). Contraste legible y foco visible.
- JavaScript: ES modules, `const`/`let`, sin `var` ni `document.write`. Escuchar eventos, no atributos `onclick`.

## PL/SQL Oracle

- Packages, no scripts sueltos de produccion. `EXCEPTION` explicito. Identificadores en MAYUSCULAS solo si el usuario ya usa ese estilo; por defecto snake_case citado no hace falta.
- Siempre binds (`:nombre`). Prohibido concatenar entrada de usuario en SQL dinamico. Si el SQL dinamico es inevitable, usar `DBMS_ASSERT`.
- `SET SERVEROUTPUT ON` no es PL/SQL: el runner `plsql` ya lo interpreta.
- Probar con `plsql archivo.sql`. DSN por variables `ORACLE_USER`, `ORACLE_PASSWORD`, `ORACLE_DSN`.
- No des por ejecutado un bloque que no corriste.

## SSH y comandos

- Cliente OpenSSH disponible. Claves del usuario, si las monto, estan en `/root/.ssh` (solo lectura).
- Usa `ssh -o StrictHostKeyChecking=accept-new`. No desactives la verificacion de host para "que funcione".
- Comandos de este entorno: `php`, `composer`, `node`, `npm`, `npx prettier`, `phpstan`, `php-cs-fixer`, `git`, `curl`, `jq`, `rg`, `plsql`, `ssh`.
- Pide confirmacion antes de comandos que borren datos, cambien remotos o toquen produccion.
