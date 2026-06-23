# setup_bash_history
script para que todos los perfiles de usuario en ubuntu 26 tendan historial del 10,000 lineas con timestamp aaaa-mm-dd hh:mm:ss, de usuarios existentes y cuando se cren nuevo stambien vengan con eso (/etc/profile)

Claude respondió: Cómo usarloCreó un archivo, archivo leídoCreó un archivo, archivo leídoCómo usarlo
bashsudo bash setup_bash_history.sh

Qué hace el script
Archivo modificadoPor qué/etc/profileLogin shells (SSH, TTY) — aplica a todos/etc/bash.bashrcShells interactivos no-login (terminales de escritorio)/etc/skel/.bashrcPlantilla que se copia al crear un usuario nuevo con adduser~/.bashrc de cada usuarioAplica inmediatamente a los usuarios existentes con bash

Variables que configura
bashHISTSIZE=10000            # líneas en memoria
HISTFILESIZE=10000        # líneas en ~/.bash_history
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "   # timestamp en cada entrada
HISTCONTROL=ignoredups:erasedups        # sin duplicados
shopt -s histappend       # no sobreescribe, acumula
PROMPT_COMMAND="history -a; history -c; history -r"  # sincroniza entre sesiones
Verificar que funciona
