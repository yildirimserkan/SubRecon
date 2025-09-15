#!/bin/bash

# 🎨 Renkler
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# ⛔️ sudo ile calistirilmasin
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}[-] Bu script'i sudo ile calistirma. Lutfen normal kullanici olarak calistir.${RESET}"
  exit 1
fi

# 🌐 Hedef domain kontrol
if [ -z "$1" ]; then
  echo -e "${RED}Kullanim: ./subrecon.sh hedef.com${RESET}"
  exit 1
fi

DOMAIN=$1
OUTDIR="$HOME/output/$DOMAIN"
TOOLS_DIR="$HOME/.subrecon/tools"
mkdir -p "$OUTDIR"
mkdir -p "$TOOLS_DIR"

# ✨ Spinner fonksiyonu
display_spinner() {
  pid=$!
  spin='-\\|/'
  i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r${YELLOW}[${spin:$i:1}] $1...${RESET}"
    sleep .1
  done
  printf "\r${GREEN}[\u2713] $1 tamamlandi.${RESET}\n"
}

# 🎮 Telegram bildirim fonksiyonu
telegram_notify() {
  local MESSAGE="$1"
  local TOKEN="7965245352:AAEWlhIxR2qkmnLqH_ujpk5LPfYGkUUM6Sc"
  local CHAT_ID="598638564"
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" > /dev/null
}

# 🚀 Go yüklü mü kontrol et
if ! command -v go &>/dev/null; then
  echo -e "${RED}[-] Go kurulu degil. Lutfen 'sudo apt install golang -y' ile kur.${RESET}"
  exit 1
fi

# ⬆️ Araclari kontrol et ve yoksa indir
TOOLS=(subfinder amass dnsx httpx)

for tool in "${TOOLS[@]}"; do
  if [ ! -f "$TOOLS_DIR/$tool" ]; then
    echo -e "${YELLOW}[i] $tool bulunamadi. Indiriliyor...${RESET}"
    if [ "$tool" == "subfinder" ]; then
      go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    elif [ "$tool" == "amass" ]; then
      go install github.com/owasp-amass/amass/v4/...@latest
    else
      go install github.com/projectdiscovery/$tool/cmd/$tool@latest
    fi
    cp "$HOME/go/bin/$tool" "$TOOLS_DIR/$tool"
    chmod +x "$TOOLS_DIR/$tool"
  fi
  if [ ! -x "$TOOLS_DIR/$tool" ]; then
    echo -e "${RED}[-] $tool calistirilabilir degil. Sorun var.${RESET}"
    exit 1
  fi
  echo -e "${GREEN}[+] $tool hazir.${RESET}"
done

# 🔎 Subdomain arama
"$TOOLS_DIR/subfinder" -d $DOMAIN -silent -all > "$OUTDIR/subs1.txt" &
display_spinner "Subfinder calisiyor"

timeout 60s "$TOOLS_DIR/amass" enum -passive -d $DOMAIN > "$OUTDIR/subs2.txt" &
display_spinner "Amass calisiyor"

cat "$OUTDIR"/subs*.txt | sort -u > "$OUTDIR/all_subs.txt"

# 🌐 DNS cozumleme
"$TOOLS_DIR/dnsx" -silent -l "$OUTDIR/all_subs.txt" -o "$OUTDIR/resolved.txt" &
display_spinner "DNSx calisiyor"

# 🌍 HTTP servis tespiti
"$TOOLS_DIR/httpx" -l "$OUTDIR/resolved.txt" -title -tech-detect -status-code -silent -o "$OUTDIR/httpx.txt" &
display_spinner "Httpx calisiyor"

# 📊 Yeni subdomain kontrolü
if [ -f "$OUTDIR/old_resolved.txt" ]; then
  diff "$OUTDIR/resolved.txt" "$OUTDIR/old_resolved.txt" | grep ">" | sed 's/> //' > "$OUTDIR/new.txt"
  if [ -s "$OUTDIR/new.txt" ]; then
    echo -e "${GREEN}[+] Yeni subdomain(ler) bulundu:${RESET}"
    cat "$OUTDIR/new.txt"
    telegram_notify "🚀 Yeni subdomain bulundu:\n$(cat $OUTDIR/new.txt)"
  fi
fi

# 📁 Eskiyi yedekle
cp "$OUTDIR/resolved.txt" "$OUTDIR/old_resolved.txt"

# 📈 Ekrana yazdir
if [ -f "$OUTDIR/httpx.txt" ]; then
  echo -e "\n${GREEN}[+] HTTP erisebilir subdomain listesi:${RESET}"
  cut -d' ' -f1 "$OUTDIR/httpx.txt" | sort -u

  echo -e "\n${GREEN}[+] Detayli HTTP bilgileri:${RESET}"
  column -t -s ' ' "$OUTDIR/httpx.txt"
else
  echo -e "\n${YELLOW}[!] httpx.txt dosyasi olusmadi. HTTP tarama sonuc yok.${RESET}"
fi

# 🚀 Taramayi bildirim olarak gönder
telegram_notify "✅ Subrecon taramasi tamamlandi: $DOMAIN"

# ✅ Tamam
echo -e "\n${GREEN}[\u2713] Tum islem tamamlandi. Cikti klasoru: $OUTDIR${RESET}"
