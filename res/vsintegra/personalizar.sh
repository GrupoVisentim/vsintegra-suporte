#!/usr/bin/env bash
# Personalização "VS Integra Suporte" — roda no GitHub Actions logo depois de baixar o código do RustDesk
# (passo inserido em .github/workflows/flutter-build.yml). Troca servidor, chave e nome; se alguma troca
# não pegar (o RustDesk mudou o arquivo), PARA a compilação em vez de gerar um app apontando pro lugar errado.
set -euo pipefail

NOME_CURTO="VSIntegra"                 # nome interno (pastas, serviço do Windows) — sem espaço de propósito
NOME_EXIBIDO="VS Integra Suporte"      # nome que aparece no Windows (Propriedades) e no Android
SERVIDOR="191.101.70.117"              # servidor próprio na VPS (/docker/rustdesk)
CHAVE="WogQPInisUXot8CQT5gaMf8d4Qw4l+uClZhMvv68oFU="
PACOTE_ANDROID="br.com.vsintegra.suporte"

if [ -f .vsintegra-ok ]; then echo "já personalizado"; exit 0; fi

# sed que funciona igual no Linux/Windows (GNU) e no Mac (BSD): grava um .bak e apaga.
troca() { local arq="${!#}"; sed -i.vsbak "$@" && rm -f "${arq}.vsbak"; }

CFG=libs/hbb_common/src/config.rs
troca -E "s|(pub static ref APP_NAME: RwLock<String> = RwLock::new\(\")RustDesk(\"\.to_owned\(\)\);)|\1${NOME_CURTO}\2|" "$CFG"
troca -E "s|(pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[)\"[^\"]*\"(\];)|\1\"${SERVIDOR}\"\2|" "$CFG"
troca -E "s|(pub const RS_PUB_KEY: &str = \")[^\"]*(\";)|\1${CHAVE}\2|" "$CFG"
grep -q "RwLock::new(\"${NOME_CURTO}\".to_owned())" "$CFG" || { echo "ERRO: não troquei o APP_NAME em $CFG"; exit 1; }
grep -qF "&[\"${SERVIDOR}\"]" "$CFG" || { echo "ERRO: não troquei o servidor em $CFG"; exit 1; }
grep -qF "\"${CHAVE}\"" "$CFG" || { echo "ERRO: não troquei a chave em $CFG"; exit 1; }

# Programa do Windows (propriedades do rustdesk.exe instalado)
RC=flutter/windows/runner/Runner.rc
if [ -f "$RC" ]; then
  troca "s/\"RustDesk Remote Desktop\"/\"${NOME_EXIBIDO} Remoto\"/; s/\"ProductName\", \"RustDesk\"/\"ProductName\", \"${NOME_EXIBIDO}\"/" "$RC"
fi

# Instalador/portátil do Windows (o .exe que o cliente baixa): nome nas Propriedades e no aviso do Windows
PT=libs/portable/Cargo.toml
if [ -f "$PT" ]; then
  troca "s/^description = \"RustDesk Remote Desktop\"/description = \"${NOME_EXIBIDO}\"/; s/^ProductName = \"RustDesk\"/ProductName = \"${NOME_EXIBIDO}\"/; s/^FileDescription = \"RustDesk Remote Desktop\"/FileDescription = \"${NOME_EXIBIDO}\"/" "$PT"
  grep -q "ProductName = \"${NOME_EXIBIDO}\"" "$PT" || { echo "ERRO: não troquei o nome do instalador em $PT"; exit 1; }
fi

# Defeito do RustDesk em cliente personalizado: a INSTALAÇÃO copia o rustdesk.exe mas não renomeia para
# {APP_NAME}.exe (a atualização renomeia) — e depois tenta abrir C:\Program Files\VSIntegra\VSIntegra.exe.
# Acrescenta o mesmo {rename_exe} da atualização na instalação. Aceita CRLF (o Windows do GitHub baixa assim).
WIN=src/platform/windows.rs
if [ -f "$WIN" ]; then
  perl -0pi -e 's/(md \\"\{path\}\\"(\r?\n)\{copy_exe\}\r?\n)/$1\{rename_exe\}$2/' "$WIN"
  perl -0pi -e 's/(copy_exe = copy_exe_cmd\(&src_exe, &exe, &path\)\?,)(\r?\n)(\s*import_config = get_import_config\(&exe\),)/$1$2        rename_exe = rename_exe_cmd(&src_exe, &path)?, \/\/ vsintegra: renomeia na instalacao$2$3/' "$WIN"
  grep -q 'vsintegra: renomeia na instalacao' "$WIN" || { echo "ERRO: não corrigi a instalação em $WIN"; exit 1; }
  [ "$(grep -c '^{rename_exe}' "$WIN")" -ge 2 ] || { echo "ERRO: não pus o {rename_exe} na instalação em $WIN"; exit 1; }
fi

MAN=flutter/android/app/src/main/AndroidManifest.xml
if [ -f "$MAN" ]; then
  troca "s/android:label=\"RustDesk\"/android:label=\"${NOME_EXIBIDO}\"/; s/android:label=\"RustDesk Input\"/android:label=\"${NOME_EXIBIDO} Input\"/" "$MAN"
fi

GR=flutter/android/app/build.gradle
if [ -f "$GR" ]; then
  troca "s/applicationId \"com.carriez.flutter_hbb\"/applicationId \"${PACOTE_ANDROID}\"/" "$GR"
fi

touch .vsintegra-ok
echo "Personalizado: ${NOME_EXIBIDO} -> ${SERVIDOR}"
