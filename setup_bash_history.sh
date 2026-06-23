#!/usr/bin/env bash
# =============================================================================
# setup_bash_history.sh
# Configura historial bash de 10,000 líneas con timestamp YYYY-MM-DD HH:MM:SS
# Para usuarios existentes + nuevos usuarios (via /etc/profile y /etc/skel)
# Requiere: ejecutar como root
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*"; }

# ── Verificar root ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root (usa sudo)."
    exit 1
fi

# ── Bloque de configuración que se inyectará ──────────────────────────────────
HISTORY_CONFIG='
# ── Historial Bash extendido (10,000 líneas + timestamp) ─────────────────────
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
export HISTCONTROL=ignoredups:erasedups          # sin duplicados consecutivos
shopt -s histappend                              # acumula, no sobreescribe
# Guarda y recarga historial en cada prompt (multi-sesión)
export PROMPT_COMMAND="history -a; history -c; history -r${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
# ─────────────────────────────────────────────────────────────────────────────
'

MARKER="# ── Historial Bash extendido (10,000 líneas + timestamp)"

# ── Función: inyectar en un archivo si no existe ya el bloque ─────────────────
inject_config() {
    local target="$1"
    if grep -qF "$MARKER" "$target" 2>/dev/null; then
        warn "Ya configurado en $target — omitido."
    else
        printf '%s\n' "$HISTORY_CONFIG" >> "$target"
        ok "Configuración añadida → $target"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# 1. /etc/profile  →  afecta a TODOS (login shells, usuarios nuevos y actuales)
# ═════════════════════════════════════════════════════════════════════════════
info "Configurando /etc/profile (global, login shells) …"
cp /etc/profile /etc/profile.bak.$(date +%Y%m%d_%H%M%S)
inject_config /etc/profile

# ═════════════════════════════════════════════════════════════════════════════
# 2. /etc/bash.bashrc  →  cubre shells interactivos no-login (terminales comunes)
# ═════════════════════════════════════════════════════════════════════════════
info "Configurando /etc/bash.bashrc (shells interactivos no-login) …"
cp /etc/bash.bashrc /etc/bash.bashrc.bak.$(date +%Y%m%d_%H%M%S)
inject_config /etc/bash.bashrc

# ═════════════════════════════════════════════════════════════════════════════
# 3. /etc/skel/.bashrc  →  se copia al HOME de cada usuario NUEVO
# ═════════════════════════════════════════════════════════════════════════════
info "Configurando /etc/skel/.bashrc (plantilla para usuarios nuevos) …"
[[ ! -f /etc/skel/.bashrc ]] && touch /etc/skel/.bashrc
inject_config /etc/skel/.bashrc

# ═════════════════════════════════════════════════════════════════════════════
# 4. Usuarios EXISTENTES con shell bash y home real
# ═════════════════════════════════════════════════════════════════════════════
info "Aplicando a usuarios existentes con shell bash …"
echo ""

while IFS=: read -r username _ uid _ _ homedir shell; do
    # Solo UID >= 1000 (usuarios normales) o root (UID 0), con bash y home real
    if [[ "$shell" == */bash ]] && [[ -d "$homedir" ]] && \
       { [[ "$uid" -eq 0 ]] || [[ "$uid" -ge 1000 ]]; }; then

        bashrc="$homedir/.bashrc"
        [[ ! -f "$bashrc" ]] && touch "$bashrc" && chown "$username":"$username" "$bashrc" 2>/dev/null || true

        echo -n "  → $username ($bashrc) … "
        if grep -qF "$MARKER" "$bashrc" 2>/dev/null; then
            echo -e "${YELLOW}ya configurado${NC}"
        else
            printf '%s\n' "$HISTORY_CONFIG" >> "$bashrc"
            chown "$username":"$username" "$bashrc" 2>/dev/null || true
            echo -e "${GREEN}✓${NC}"
        fi

        # Expandir el archivo .bash_history existente si es menor a 10000 líneas
        hist_file="$homedir/.bash_history"
        if [[ -f "$hist_file" ]]; then
            lines=$(wc -l < "$hist_file")
            echo "    └─ .bash_history actual: $lines líneas (límite ahora 10,000)"
        fi
    fi
done < /etc/passwd

# ═════════════════════════════════════════════════════════════════════════════
# Resumen
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Configuración completada exitosamente               ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "  HISTSIZE       = 10,000 líneas en memoria"
echo "  HISTFILESIZE   = 10,000 líneas en ~/.bash_history"
echo "  HISTTIMEFORMAT = YYYY-MM-DD HH:MM:SS"
echo "  HISTCONTROL    = sin duplicados consecutivos"
echo "  histappend     = activo (multi-sesión segura)"
echo ""
echo "  Archivos modificados:"
echo "    • /etc/profile          (login shells — global)"
echo "    • /etc/bash.bashrc      (shells interactivos — global)"
echo "    • /etc/skel/.bashrc     (plantilla nuevos usuarios)"
echo "    • ~/.bashrc de cada usuario bash existente"
echo ""
warn "Los backups de /etc/profile y /etc/bash.bashrc se guardaron"
warn "con extensión .bak.YYYYMMDD_HHMMSS en el mismo directorio."
echo ""
info "Para activar en la sesión actual sin reiniciar:"
echo "    source ~/.bashrc   ó   source /etc/profile"
echo ""
