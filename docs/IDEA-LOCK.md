# TALOS — Fikir Kilidi (Immutable Component Checklist)

> Bu checklist projenin degismez bilesenlerini tanimlar.
> Her faz sonunda bu listeye karsi "fikir bozuldu mu?" kontrolu yapilir.
> Herhangi bir madde ihlal edilirse, o faz TAMAMLANMAMIS sayilir.
> Kaynak: TALOS-MONAD-proje-dokumani.md (v2)

---

## A. Cekirdek Mekanizma: Commit-Verify-Execute (CVE)

- [ ] Ajan islem yapmadan once iddia paketini (AgentClaim) olusturur
- [ ] Ajan iddia paketinin keccak256 hash'ini on-chain'e commit eder
- [ ] Dogrulama 3 katmanli pipeline ile yapilir (hash → oracle → policy)
- [ ] Tum katmanlar gecerse islem yurutulur, herhangi biri basarisizsa fonlar iade edilir
- [ ] CVE akisi atomiktir — verifyAndExecute tek tx icinde dogrulama + yurutme yapar

## B. Escrow Modeli

- [ ] Fonlar ASLA ajanin cuzdaninda tutulmaz — Talos kontratinda kilitlidir
- [ ] EscrowStatus state machine: Locked → Committed → Verified → Executed/Refunded/Expired
- [ ] State machine tek yonlu ilerler (geri gecis yok, SoftReject retry harici)
- [ ] Zaman asimi durumunda fonlar otomatik iade edilir (permissionless refund)
- [ ] Per-intent storage: her escrow bagimsiz storage slot'a yazilir (paralel execution uyumu)

## C. 3 Katmanli Dogrulama

- [ ] **Katman 1 (Hash):** keccak256(abi.encode(claim)) == commitHash
- [ ] **Katman 2 (Oracle):** Chainlink AggregatorV3Interface ile fiyat karsilastirmasi
- [ ] **Katman 3 (Policy):** Modular policy engine'ler (SpendingLimit, ContractWhitelist, SlippageGuard, Drawdown)
- [ ] Katmanlar sirayla calisir — onceki basarisizsa sonraki calistirilmaz

## D. Kademeli Tolerans (v2)

- [ ] %0-%1.5 sapma → Passed (islem onaylandi)
- [ ] %1.5-%5 sapma → SoftReject (slash YOK, hafif itibar dususu, retry hakki)
- [ ] %5+ sapma → HardReject (stake slash + ciddi itibar dususu)
- [ ] SoftReject sonrasi escrow Locked'a doner, ajan yeni commit yapabilir

## E. Ikili Ceza Mekanizmasi

- [ ] Talos cezasi: ajan stake'inin %10'u kesilir (HardReject durumunda)
- [ ] Monad cezasi: basarisiz tx gas_limit kadar MON yakar (zincir duzeyi)
- [ ] Iki ceza birlikte uygulanir — kotu niyet cift katli maliyetlidir

## F. ELO Itibar Sistemi

- [ ] Baslangic puani: 1000, aralik: 0-2000
- [ ] K-faktor deneyime gore degisir: K=40 (<50 tx), K=20 (50-200 tx), K=10 (200+ tx)
- [ ] Puan 100'un altina dustugunde ajan yasaklanir (isBanned = true)
- [ ] Itibar on-chain'de tutulur, herkes okuyabilir

## G. Moduler Verifier ve Policy Mimarisi

- [ ] IVerifier interface: verify(claimData, references) → VerificationOutput
- [ ] IPolicyEngine interface: check(claimData, agent, amount, targetContract) → PolicyOutput
- [ ] PriceVerifier: Chainlink oracle fiyat dogrulamasi
- [ ] BalanceVerifier: ERC-20 balanceOf kontrolu
- [ ] StateVerifier: Genel on-chain state dogrulamasi
- [ ] SpendingLimitPolicy, ContractWhitelistPolicy, SlippageGuardPolicy, DrawdownPolicy

## H. ERC-2612 Permit (v2)

- [ ] lockEscrowWithPermit: off-chain imza ile approve + lock tek tx'de
- [ ] IERC20Permit(token).permit() + safeTransferFrom() atomik

## I. Standing Escrow (v2)

- [ ] StandingEscrow struct: owner, agent, token, balance, perTxLimit, expiry, active
- [ ] Kullanici bir kere buyuk miktar yatirir, ajan parca parca kullanir
- [ ] Her islem perTxLimit'i asamaz
- [ ] executeFromStanding icinde commit-verify-execute calismaya devam eder

## J. Meta-Policy ve Circuit Breaker (v2)

- [ ] Meta-policy: ajan, kullanici tarafindan belirlenen tavan (ceiling) dahilinde limitleri ayarlayabilir
- [ ] Sikilastirma (limit dusurme) her zaman serbest
- [ ] Gevseme (limit artirma) tavana kadar, izin varsa
- [ ] Circuit breaker: Chainlink fiyat %10+ dustugunde tum islemler otomatik durur
- [ ] _checkCircuitBreaker verifyAndExecute'in en basinda calisir

## K. Monad-Native Ozellikler

- [ ] Deferred execution state lag'i escrow modeli ile notralize edilir
- [ ] gas_limit billing ikili ceza mekanizmasina donusturulur
- [ ] Reserve balance (10 MON) stake mekanizmasi ile dogal uyumlu
- [ ] Per-intent storage paralel execution'a uygun
- [ ] evm_version = "cancun" (Prague DEGIL)
- [ ] Hedef ag: Monad Testnet (Chain ID: 10143)

## L. Sybil Dayanikliligi

- [ ] Ajan kaydi minimum 100 MON stake gerektirir
- [ ] Puan sadece gercek fon hareketi olan islemlerden artar
- [ ] Chainlink oracle ile dogrulama — sahte veri commit etmek imkansiz
- [ ] Monad gas_limit billing spam'i ekonomik olarak caydirici kilar

## M. Demo Botlar

- [ ] HonestBot: Gercek Chainlink fiyatlari, mesru iddialar → Onaylandi
- [ ] LiarBot: Fiyati %34 dusuk iddia eder → Reddedildi (oracle uyusmazligi)
- [ ] YieldBot: Vault APY izleme, APY > %5 ise deposit → Onaylandi
- [ ] ManipBot: Hash A commit eder, Claim B gonderir → Reddedildi (hash uyusmazligi)

## N. Gelir Modeli

- [ ] Dogrulama ucreti: basarili islem hacminin %0.05'i
- [ ] Ajan kayit stake'i: minimum 100 MON
- [ ] Slash geliri: basarisiz dogrulamalarda kesilen stake (%10) → protokol hazinesi

---

> **Kontrol talimatı:** Her faz sonunda bu dosyayi ac ve ilgili maddeleri isle.
> Eger bir madde karsilanmiyorsa, sebebini raporla ve CLAUDE.md Anayasa Kural #2'ye (FIKIR DOKUNULMAZ) basvur.
