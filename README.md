# SubRecon

Bash tabanlı otomatik keşif ve Attack Surface Management (ASM) yardımcı aracı.

## Hızlı Başlangıç

```bash
chmod +x subrecon/subrecon.sh
./subrecon/subrecon.sh -h
```

## Kullanım
Komut satırı argümanlarını görmek için `-h` veya `--help` bayrağını kullanın.

## Bağımlılıklar
- `bash` (>= 4)
- Dış araçlar: `nmap`, `curl` (ve gerekirse diğerleri)

> Not: Dış araçlar proje dizininde gömülü değilse sisteminizde kurulu olmalıdır.

## Klasör Yapısı
- `subrecon/` – ana betikler ve araçlar
- `subrecon/tools/` – yardımcı scriptler (varsa)

## Lisans
MIT