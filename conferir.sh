#!/usr/bin/env bash
# Confere cada site de sites.txt: resposta 200 com o texto esperado, sem noindex e certificado com mais de 14 dias.
# Tenta 3 vezes antes de acusar falha, para não alarmar por instabilidade passageira.
set -u
falhas=0

conferir() {
  local url="$1" texto="$2" host corpo codigo
  host=$(echo "$url" | sed -E 's#https?://([^/]+).*#\1#')
  corpo=$(mktemp)
  codigo=$(curl -sS -L --max-time 30 -A "monitor-sites (GitHub Actions)" -o "$corpo" -w "%{http_code}" "$url") || codigo="000"
  if [ "$codigo" != "200" ]; then echo "HTTP $codigo"; return 1; fi
  if ! grep -q "$texto" "$corpo"; then echo "resposta sem o texto esperado: $texto"; return 1; fi
  if grep -qiE '<meta[^>]+name="robots"[^>]+noindex' "$corpo"; then echo "produção com noindex"; return 1; fi
  local fim dias
  fim=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  dias=$(( ( $(date -d "$fim" +%s) - $(date +%s) ) / 86400 ))
  if [ "$dias" -lt 14 ]; then echo "certificado vence em $dias dia(s) ($fim)"; return 1; fi
  echo "ok (certificado: $dias dias)"
}

while IFS='|' read -r url texto; do
  [ -z "$url" ] || [ "${url:0:1}" = "#" ] && continue
  for tentativa in 1 2 3; do
    if msg=$(conferir "$url" "$texto"); then break; fi
    [ "$tentativa" -lt 3 ] && sleep 20
  done
  echo "$url: $msg"
  case "$msg" in ok*) ;; *) falhas=$((falhas + 1)); echo "::error title=Site com problema::$url — $msg" ;; esac
done < sites.txt

exit "$falhas"
