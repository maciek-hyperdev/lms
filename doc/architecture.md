# LMS (LAN Management System) - Dokument Architektury

**Wersja:** 28-git
**Data analizy:** 2026-03-19
**Licencja:** GPL-2.0-only
**Repozytorium:** https://git.lms.org.pl
**Strona projektu:** https://lms.org.pl

---

## 1. Wprowadzenie

LMS (LAN Management System) to kompleksowy system zarządzania siecią ISP (Internet Service Provider), rozwijany od 2001 roku. System obsługuje pełen cykl życia operatora telekomunikacyjnego - od zarządzania klientami i fakturowania, przez provisioning sieci i urządzeń, po integrację z polskimi systemami fiskalnymi (KSeF, JPK).

### 1.1 Kluczowe fakty techniczne

| Aspekt | Wartość |
|--------|---------|
| Język | PHP 8.1+ |
| Baza danych | PostgreSQL / MySQL |
| Template engine | Smarty 4 |
| Frontend | jQuery, jQuery UI, DataTables, TinyMCE, Select2 |
| PDF | TCPDF, HTML2PDF, EZPDF |
| Architektura | Monolityczna aplikacja webowa + demony systemowe |
| Plików PHP | ~2320 |
| Tabel w bazie | 163 |
| Migracji DB | ~1466 |

---

## 2. Diagram Kontekstowy (C4 Level 1)

```
                        ┌──────────────────┐
                        │   Administrator   │
                        │    ISP / NOC      │
                        └────────┬─────────┘
                                 │ HTTP/HTTPS
                                 ▼
┌──────────────┐        ┌──────────────────┐        ┌──────────────────┐
│   Klient     │───────▶│                  │◀──────▶│    FreeRADIUS    │
│  (Userpanel) │ HTTP   │                  │  SQL   │   (AAA Server)  │
└──────────────┘        │                  │        └──────────────────┘
                        │                  │
┌──────────────┐        │       LMS        │        ┌──────────────────┐
│   KSeF API   │◀──────▶│                  │───────▶│  DHCP / DNS      │
│  (MF Gov)    │ HTTPS  │   (Monolith +    │ Config │  (ISC/Bind/Kea)  │
└──────────────┘        │    Demony)       │ Files  └──────────────────┘
                        │                  │
┌──────────────┐        │                  │        ┌──────────────────┐
│   GUS REGON  │◀──────▶│                  │───────▶│  Firewall / TC   │
│   (SOAP)     │ SOAP   │                  │ Config │  (iptables/HTB)  │
└──────────────┘        │                  │        └──────────────────┘
                        │                  │
┌──────────────┐        │                  │        ┌──────────────────┐
│  Bank Import │───────▶│                  │───────▶│  Mikrotik/NAS    │
│  (CSV/MT940) │ File   │                  │ API    │  (RouterOS)      │
└──────────────┘        └──────────────────┘        └──────────────────┘
                                 │
                        ┌────────┴─────────┐
                        │   PostgreSQL /   │
                        │     MySQL        │
                        └──────────────────┘
```

### 2.1 Aktorzy i systemy zewnętrzne

| System / Aktor | Typ integracji | Opis |
|----------------|----------------|------|
| **Administrator ISP** | HTTP/HTTPS (Web UI) | Panel administracyjny - zarządzanie siecią, klientami, fakturami |
| **Klient końcowy** | HTTP/HTTPS (Userpanel) | Portal klienta - podgląd salda, faktur, zmiana danych |
| **KSeF (MF)** | HTTPS REST API | Krajowy System e-Faktur - wysyłka i odbiór faktur ustrukturyzowanych |
| **GUS REGON** | SOAP | Weryfikacja danych firm (NIP, REGON) |
| **VIES** | SOAP | Weryfikacja VAT UE (via `dragonbe/vies`) |
| **FreeRADIUS** | SQL (shared DB) | Autoryzacja, autentykacja i accounting użytkowników sieci |
| **DHCP Server** | Pliki konfiguracyjne | Generowanie konfiguracji dhcpd.conf |
| **DNS Server** | SQL (PowerDNS) / Pliki | Zarządzanie strefami DNS |
| **Firewall** | Pliki konfiguracyjne | iptables, ipchains, OpenBSD PF |
| **Traffic Control** | Pliki konfiguracyjne | HTB/CBQ shaping konfiguracji |
| **Mikrotik** | API + RADIUS | Zarządzanie urządzeniami RouterOS |
| **Nagios** | Eksport konfiguracji | Monitoring sieci (via contrib) |
| **Serwer pocztowy** | SMTP | Wysyłka e-mail (PHPMailer) |
| **SMS Gateway** | HTTP/smstools | Wysyłka SMS (powiadomienia) |
| **Banki** | Import plików | Import przelewów (różne formaty) |
| **Asterisk** | SQL/Config | VoIP provisioning |

---

## 3. Diagram Architektury Wewnętrznej (C4 Level 2)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              LMS SYSTEM                                     │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        WARSTWA PREZENTACJI                            │  │
│  │                                                                       │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐   │  │
│  │  │   Admin Panel    │  │   Userpanel     │  │   API / Export      │   │  │
│  │  │  (index.php)     │  │  (userpanel/)   │  │  (export.php)      │   │  │
│  │  │                  │  │                  │  │                     │   │  │
│  │  │  ~400 modułów    │  │  Portal klienta │  │  Dane CSV/XML/PDF  │   │  │
│  │  │  Smarty 4 TPL    │  │  Smarty 4 TPL   │  │                     │   │  │
│  │  └────────┬─────────┘  └────────┬────────┘  └─────────┬───────────┘  │  │
│  └───────────┼──────────────────────┼─────────────────────┼──────────────┘  │
│              │                      │                     │                  │
│  ┌───────────┼──────────────────────┼─────────────────────┼──────────────┐  │
│  │           ▼                      ▼                     ▼              │  │
│  │                        WARSTWA LOGIKI BIZNESOWEJ                       │  │
│  │                                                                       │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    LMS.class.php (Fasada)                        │ │  │
│  │  │  Static accessor z lazy-loaded managerami domenowymi             │ │  │
│  │  └──────────┬──────────────────────────────┬────────────────────────┘ │  │
│  │             │                              │                          │  │
│  │  ┌──────────▼──────────────┐    ┌──────────▼──────────────┐          │  │
│  │  │   Domain Managers       │    │   Specialized Libs      │          │  │
│  │  │                         │    │                          │          │  │
│  │  │  CustomerManager        │    │  KSeF (lib/KSeF/)       │          │  │
│  │  │  FinanceManager         │    │  VoIP (lib/voip/)       │          │  │
│  │  │  NodeManager            │    │  Documents (LMSDocuments)│          │  │
│  │  │  NetworkManager         │    │  Permissions             │          │  │
│  │  │  NetDevManager          │    │  Config (LMSConfig/)     │          │  │
│  │  │  HelpdeskManager        │    │  Google2FA               │          │  │
│  │  │  DocumentManager        │    │  PluginManager           │          │  │
│  │  │  EventManager           │    │                          │          │  │
│  │  │  MessageManager         │    │                          │          │  │
│  │  │  CashManager            │    │                          │          │  │
│  │  │  DivisionManager        │    │                          │          │  │
│  │  │  UserManager            │    │                          │          │  │
│  │  │  LocationManager        │    │                          │          │  │
│  │  │  VoipAccountManager     │    │                          │          │  │
│  │  │  TariffTagManager       │    │                          │          │  │
│  │  │  ProjectManager         │    │                          │          │  │
│  │  │  FileManager            │    │                          │          │  │
│  │  └─────────────────────────┘    └──────────────────────────┘          │  │
│  │                                                                       │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Plugin System (LMSPluginManager)                                │ │  │
│  │  │  Observer pattern - pluginy mogą hookować się w eventy           │ │  │
│  │  └──────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                       WARSTWA DANYCH                                  │  │
│  │                                                                       │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐   │  │
│  │  │   LMSDB          │  │   Session       │  │   LMSCache          │   │  │
│  │  │   (Abstraction)  │  │   Management    │  │                     │   │  │
│  │  │                  │  │                  │  │                     │   │  │
│  │  │  PostgreSQL drv  │  │  Cookie-based   │  │  In-memory cache    │   │  │
│  │  │  MySQL drv       │  │  DB-backed      │  │                     │   │  │
│  │  └────────┬─────────┘  └────────┬────────┘  └─────────────────────┘  │  │
│  └───────────┼──────────────────────┼────────────────────────────────────┘  │
│              │                      │                                       │
│  ┌───────────┼──────────────────────┼────────────────────────────────────┐  │
│  │           ▼                      ▼                                    │  │
│  │                     DEMONY SYSTEMOWE (bin/ + daemon/)                  │  │
│  │                                                                       │  │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐            │  │
│  │  │lms-payments│ │lms-notify  │ │lms-teryt │ │lms-maketc│            │  │
│  │  │  Naliczanie│ │  E-mail/SMS│ │  TERYT   │ │  Traffic │            │  │
│  │  │  opłat     │ │  wysyłka   │ │  Import  │ │  Control │            │  │
│  │  └────────────┘ └────────────┘ └──────────┘ └──────────┘            │  │
│  │                                                                       │  │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌───────────┐           │  │
│  │  │lms-makdhcp │ │lms-sendinv │ │lms-cashim│ │lms-rtparse│           │  │
│  │  │  DHCP conf │ │  Wysyłka   │ │  Import  │ │  Helpdesk │           │  │
│  │  │  generator │ │  faktur    │ │  płatn.  │ │  email    │           │  │
│  │  └────────────┘ └────────────┘ └──────────┘ └───────────┘           │  │
│  │                                                                       │  │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌───────────┐           │  │
│  │  │lms-cleanup │ │lms-gus     │ │lms-fping │ │daemon/lmsd│           │  │
│  │  │  Czyszczen.│ │  REGON API │ │  Ping    │ │ C daemon  │           │  │
│  │  │  danych    │ │  weryfikac.│ │  monitor │ │ (modular) │           │  │
│  │  └────────────┘ └────────────┘ └──────────┘ └───────────┘           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                          ┌──────────────────┐
                          │  PostgreSQL /     │
                          │  MySQL            │
                          │                   │
                          │  163 tabel        │
                          │  1466+ migracji   │
                          └──────────────────┘
```

---

## 4. Domeny biznesowe

### 4.1 Zarządzanie klientami (CRM)
- **Pliki:** `modules/customer*.php`, `lib/LMSManagers/LMSCustomerManager.php`
- **Tabele:** `customers`, `customerconsents`, `customercontacts`, `customerextids`, `customernotes`, `customergroups`, `customerassignments`
- **Funkcje:** rejestracja klientów, grupy, zgody RODO, historia zmian, obsługa adresów (TERYT), weryfikacja GUS REGON/VIES

### 4.2 Zarządzanie siecią
- **Pliki:** `modules/net*.php`, `modules/node*.php`, `lib/LMSManagers/LMSNetworkManager.php`, `LMSNodeManager.php`, `LMSNetDevManager.php`
- **Tabele:** `networks`, `nodes`, `netdevices`, `netlinks`, `netnodes`, `vlans`, `netradiosectors`, `macs`
- **Funkcje:** zarządzanie sieciami IP, węzłami (node), urządzeniami sieciowymi, linkami, sektorami radiowymi, VLAN-ami, mapą sieci

### 4.3 Fakturowanie i finanse
- **Pliki:** `modules/invoice*.php`, `modules/note*.php`, `modules/balance*.php`, `modules/cash*.php`, `lib/LMSManagers/LMSFinanceManager.php`
- **Tabele:** `documents`, `documentcontents`, `invoicecontents`, `cash`, `cashimport`, `taxes`, `cashregs`
- **Funkcje:** wystawianie faktur VAT, proform, not obciążeniowych, korekt; import płatności bankowych; kasy rejestrujące; plany numeracji

### 4.4 Taryfy i przypisania
- **Pliki:** `modules/tariff*.php`, `modules/customerassignment*.php`, `modules/promotion*.php`
- **Tabele:** `tariffs`, `assignments`, `nodeassignments`, `promotions`, `promotionschemas`
- **Funkcje:** definiowanie taryf z parametrami przepustowości (upceil/downceil, uprate/downrate, dlimit/ulimit), systemy promocji, przypisywanie taryf do klientów/węzłów

### 4.5 Helpdesk (RT - Request Tracker)
- **Pliki:** `modules/rt*.php`, `lib/LMSManagers/LMSHelpdeskManager.php`
- **Tabele:** `rtqueues`, `rttickets`, `rtmessages`, `rtcategories`, `rtattachments`
- **Funkcje:** system ticketowy, kolejki, kategorie, automatyczne parsowanie e-maili (`lms-rtparser.php`)

### 4.6 VoIP
- **Pliki:** `modules/voip*.php`, `lib/LMSManagers/LMSVoipAccountManager.php`, `lib/voip/`, `bin/voip/`
- **Tabele:** `voipaccounts`, `voip_numbers`, `voip_cdr`, `voip_tariffs`, `voip_rules`, `voip_prefixes`
- **Funkcje:** zarządzanie kontami SIP, billing VoIP, numery alarmowe, integracja z Asterisk

### 4.7 DNS / Domeny
- **Pliki:** `modules/domain*.php`, `modules/dns.php`, `modules/record*.php`
- **Tabele:** `domains`, `records`, `domainmetadata`, `cryptokeys` (kompatybilne z PowerDNS)
- **Funkcje:** zarządzanie strefami DNS, rekordami, wsparcie DNSSEC

### 4.8 Dokumenty
- **Pliki:** `modules/document*.php`, `lib/LMSManagers/LMSDocumentManager.php`, `lib/LMSDocuments/`
- **Tabele:** `documents`, `documentcontents`, `documentattachments`
- **Funkcje:** generowanie dokumentów (PDF via TCPDF/HTML2PDF/EZPDF), szablony, skanowanie, archiwizacja

### 4.9 Powiadomienia
- **Pliki:** `modules/message*.php`, `bin/lms-notify.php`, `bin/lms-sendinvoices.php`
- **Tabele:** `messages`, `messageitems`, `templates`
- **Funkcje:** e-mail, SMS, powiadomienia KSeF, szablony wiadomości

---

## 5. Integracja z KSeF (Krajowy System e-Faktur)

### 5.1 Przegląd

KSeF to polski rządowy system e-faktur. LMS implementuje pełną integrację obejmującą:
- Generowanie XML faktur zgodnych ze schematem FA(3) v1-0E
- Wysyłkę batch (paczki ZIP) faktur do KSeF
- Odbiór i przetwarzanie UPO (Urzędowe Poświadczenie Odbioru)
- Pobieranie i wyświetlanie faktur zakupowych z KSeF
- Walidację XSD

### 5.2 Architektura KSeF

```
┌─────────────────────────────────────────────────────────────────┐
│                      LMS - Moduł KSeF                           │
│                                                                  │
│  ┌──────────────────┐     ┌──────────────────────────────────┐  │
│  │  Moduły UI       │     │  lib/KSeF/KSeF.php               │  │
│  │                  │     │  (Główna klasa ~2100 linii)       │  │
│  │ invoiceksefinfo  │────▶│                                   │  │
│  │ ksefpurchase*    │     │  - getInvoiceXml()                │  │
│  │ invoice.php      │     │  - buildZipPackagesFromXml()      │  │
│  │                  │     │  - makeZipBinaryFromFiles()        │  │
│  └──────────────────┘     │  - updateDelays()                 │  │
│                           │  - updateAllConsumers()            │  │
│                           │  - getDeploymentDates()            │  │
│                           │  - getPurchaseDocuments()          │  │
│                           │  - getInvoiceFile() [static]      │  │
│                           └──────────┬───────────────────────┘  │
│                                      │                          │
│  ┌──────────────────┐     ┌──────────▼──────────────────────┐  │
│  │  Walidacja       │     │  n1ebieski/ksef-php-client      │  │
│  │                  │     │  (Composer dependency)           │  │
│  │ schemat_FA(3)    │     │  + GuzzleHTTP                    │  │
│  │   _v1-0E.xsd    │     │                                   │  │
│  │ schemat_FA(3)    │     │  API endpoints:                  │  │
│  │   _v1-0E.xsl    │     │  - ksef.mf.gov.pl (prod)         │  │
│  │ upo-ksef-v4-3   │     │  - ksef-demo.mf.gov.pl           │  │
│  │   -to-html.xsl  │     │  - ksef-test.mf.gov.pl           │  │
│  └──────────────────┘     └──────────┬───────────────────────┘  │
│                                      │                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Storage                                                  │   │
│  │  storage/ksef/upo/     - pliki UPO                       │   │
│  │  storage/ksef/invoice/ - pobrane faktury                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼ HTTPS REST
              ┌──────────────────────────┐
              │      KSeF API (MF)       │
              │                          │
              │  Środowiska:             │
              │  - PROD  (qr.ksef.mf)    │
              │  - DEMO  (qr-demo.ksef)  │
              │  - TEST  (qr-test.ksef)  │
              │                          │
              │  QR codes:               │
              │  - qr.ksef.mf.gov.pl/    │
              │    invoice               │
              │  - qr.ksef.mf.gov.pl/    │
              │    certificate/Nip       │
              └──────────────────────────┘
```

### 5.3 Schemat bazy danych KSeF

```
┌─────────────────────────────────────┐
│          ksefbatchsessions           │
├─────────────────────────────────────┤
│ id (PK)                             │
│ ksefnumber VARCHAR(40)              │  ← numer sesji w KSeF
│ cdate BIGINT                        │  ← data utworzenia
│ lastupdate BIGINT                   │  ← ostatnia aktualizacja
│ status SMALLINT DEFAULT 0           │  ← status sesji
│ statusdescription TEXT              │
│ environment SMALLINT DEFAULT 0      │  ← 1=TEST, 2=PROD, 3=DEMO
└──────────────────┬──────────────────┘
                   │ 1:N
                   ▼
┌─────────────────────────────────────┐
│            ksefdocuments             │
├─────────────────────────────────────┤
│ id (PK)                             │
│ batchsessionid FK→ksefbatchsessions │
│ docid FK→documents                  │  ← powiązanie z fakturą LMS
│ ordinalnumber INT                   │  ← numer porządkowy w paczce
│ ksefnumber VARCHAR(40)              │  ← numer KSeF faktury
│ hash VARCHAR(50)                    │  ← hash dokumentu
│ status SMALLINT DEFAULT 0           │  ← 0=pending, 200=ok
│ statusdescription TEXT              │
│ statusdetails TEXT                  │
│ permanent_storage_date TIMESTAMPTZ  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│             ksefdelays               │
├─────────────────────────────────────┤
│ id (PK)                             │
│ divisionid FK→divisions             │  ← opóźnienie per oddział
│ delay INT                           │  ← opóźnienie w sekundach
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│          ksefallconsumers            │
├─────────────────────────────────────┤
│ id (PK)                             │
│ divisionid FK→divisions             │
│ allconsumers SMALLINT               │  ← flaga "wszyscy konsumenci"
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│            ksefinvoices               │  ← faktury zakupowe z KSeF
├─────────────────────────────────────┤
│ id (PK)                             │
│ division_id FK→divisions            │
│ issue_date, from_date, to_date      │
│ permanent_storage_date TIMESTAMPTZ  │
│ ksef_number VARCHAR(40)             │
│ invoice_number VARCHAR(256)         │
│ corrected_ksef_number               │  ← korekty
│ corrected_invoice_number            │
│ seller_ten, seller_name             │
│ buyer_identifier_type/value/name    │
│ net_amount, gross_amount, vat_amount│
│ currency, currency_value            │
│ invoicing_mode (online/offline)     │
│ invoice_type, form_system_code      │
│ invoice_hash, bank_account          │
│ posting SMALLINT                    │
└──────────────────┬──────────────────┘
                   │ 1:N
          ┌────────┼─────────────┐
          ▼        ▼             ▼
┌───────────┐ ┌──────────┐ ┌──────────────────┐
│ ksef      │ │ ksef     │ │ ksef             │
│ invoice   │ │ invoice  │ │ invoicethird     │
│ items     │ │ summaries│ │ subjects         │
└───────────┘ └──────────┘ └──────────────────┘

Dodatkowe: ksefinvoicetags, ksefinvoicetagassignments (tagowanie)
```

### 5.4 Generowanie XML KSeF

Klasa `Lms\KSeF\KSeF::getInvoiceXml()` generuje XML zgodny ze schematem FA(3) v1-0E:

1. **Nagłówek** (`<Naglowek>`) - kod formularza FA(3), wersja schematu 1-0E, timestamp, info o systemie
2. **Podmiot1** (sprzedawca) - NIP, nazwa, adres, dane kontaktowe z danych oddziału (division)
3. **Podmiot2** (nabywca) - obsługa identyfikatorów: NIP, VAT-UE, inne, brak (osoby fizyczne), NIP zagraniczny
4. **Fa** (dane faktury) - typ dokumentu, data wystawienia, numer, waluta, pozycje, podsumowanie VAT
5. **Platnosc** - mapowanie typów płatności LMS → KSeF (gotówka, karta, przelew, barter, kompensacja, itp.)
6. **Rachunki bankowe** - z uwzględnieniem konfiguracji `invoices.show_only_alternative_accounts` / `show_all_accounts`

**Obsługiwane typy dokumentów:**
- Faktura VAT (Vat), Faktura zaliczkowa (Zal), Korekta (Kor)
- Faktura rozliczeniowa (Roz), Uproszczona (Upr)
- Korekta zaliczkowej (KorZal), Korekta rozliczeniowej (KorRoz)
- Faktura PEF (VatPef/VatPefSp), Korekta PEF (KorPef)
- Faktura VAT RR (VatRr), Korekta VAT RR (KorVatRr)

### 5.5 Batch wysyłki

Metoda `buildZipPackagesFromXmlDocuments()` implementuje inteligentne pakowanie:

1. **Etap A:** Wstępne grupowanie O(n) po sumie rozmiarów XML (bez budowania ZIP)
2. **Etap B:** Budowanie ZIP raz na paczkę
3. **Etap C:** Jeśli ZIP przekroczy limit → przycięcie paczki przez wyszukiwanie binarne

Bufor bezpieczeństwa: 5% lub max 8MB (min 512KB) na metadane ZIP.

### 5.6 Środowiska i certyfikaty

| Stała | Wartość | Endpoint |
|-------|---------|----------|
| `ENVIRONMENT_TEST` | 1 | ksef-test.mf.gov.pl |
| `ENVIRONMENT_PROD` | 2 | ksef.mf.gov.pl |
| `ENVIRONMENT_DEMO` | 3 | ksef-demo.mf.gov.pl |

Obsługa certyfikatów: PEM i PKCS12, online i offline.

### 5.6a Podpisywanie certyfikatów (ECDSA)

KSeF wymaga podpisów cyfrowych do generowania QR kodów certyfikatów:

1. Wczytanie klucza prywatnego EC z pliku (PEM lub PKCS12 z hasłem)
2. Podpisanie URL SHA-256 via `openssl_sign(..., OPENSSL_ALGO_SHA256)`
3. Konwersja podpisu DER (SEQUENCE { INTEGER r, INTEGER s }) do formatu IEEE P1363 (R||S, 32+32 bajty dla P-256)
4. Kodowanie Base64-URL podpisu
5. Dołączenie podpisu do URL QR kodu

Format URL certyfikatu:
```
https://{env}/certificate/Nip/{ten}/{ten}/{serialNumber}/{hash}/{base64url(P1363sig)}
```

### 5.7 Konfiguracja KSeF

Parametry w sekcji `[ksef]` tabeli `uiconfig`:
- `ksef.delay` - opóźnienie wysyłki (domyślnie 3600s)
- `ksef.all_consumers` - flaga "wszyscy konsumenci" per oddział

---

## 6. Integracja z JPK (Jednolity Plik Kontrolny)

### 6.1 Przegląd

JPK w LMS nie jest osobnym modułem, lecz zintegrowanym mechanizmem flag dokumentów wspierającym raportowanie JPK_V7M/V7K.

### 6.2 Flagi dokumentów JPK

```
DOC_FLAG_RECEIPT          = 1   → FP  (Faktura do paragonu)
DOC_FLAG_TELECOM_SERVICE  = 2   → EE  (Usługi telekomunikacyjne)
DOC_FLAG_RELATED_ENTITY   = 4   → TP  (Podmiot powiązany)
DOC_FLAG_SPLIT_PAYMENT    = 8   → MPP (Mechanizm podzielonej płatności)
DOC_FLAG_NET_ACCOUNT      = 16  → Rachunek netto
```

### 6.3 Flagi klientów powiązane z JPK

| Flaga | Opis | Wpływ JPK |
|-------|------|-----------|
| `CUSTOMER_FLAG_RELATED_ENTITY` | Podmiot powiązany | Automatyczne oznaczanie faktur flagą TP |
| `CUSTOMER_FLAG_VAT_PAYER` | Płatnik VAT | Jeśli nie-VAT, usługi telekom raportowane z EE |

### 6.4 Wykorzystanie w raportach

Flagi JPK są filtrowane w `invoicereport.php` - raport faktur może być ograniczony do dokumentów z konkretną flagą JPK:
```php
(empty($jpk_flag) ? '' : ' AND (d.flags & ' . $jpk_flag . ') > 0')
```

Pole `flags` w tabeli `documents` przechowuje bitową maskę flag, umożliwiając kombinacje (np. FP + TP = 5).

### 6.5 Relacja KSeF ↔ JPK

Od 2026 roku KSeF jest obowiązkowy. LMS śledzi datę wdrożenia KSeF per NIP/oddział (`getDeploymentDates()`), co wpływa na sposób raportowania JPK - faktury wysłane przez KSeF nie wymagają osobnego raportowania w JPK_FA.

---

## 7. Integracja z RADIUS i Provisioning

### 7.1 Architektura RADIUS

```
┌────────────────┐     ┌──────────────┐     ┌──────────────────────┐
│  Urządzenie    │     │  FreeRADIUS   │     │     LMS Database     │
│  klienta       │     │              │     │                      │
│  (CPE/Router)  │────▶│  rlm_sql     │────▶│  vnodes (VIEW)       │
│                │ AAA │  module      │ SQL │  nodes               │
│                │     │              │     │  tariffs             │
│                │◀────│  authorize   │◀────│  assignments         │
│                │     │  accounting  │     │  nodeassignments     │
│  NAS           │     │  post-auth   │     │  nodesessions        │
│  (Mikrotik/    │     │              │     │                      │
│   inny)        │     │              │     │                      │
└────────────────┘     └──────────────┘     └──────────────────────┘
```

### 7.2 Model integracji: Shared Database

LMS **nie komunikuje się bezpośrednio** z FreeRADIUS. Integracja opiera się na **wspólnej bazie danych**:

1. LMS zapisuje dane klientów, węzłów, taryf do bazy
2. FreeRADIUS wykonuje zapytania SQL bezpośrednio do tych samych tabel
3. Konfiguracja FreeRADIUS w `sample/radius-pgsql.conf` / `sample/radius-mysql.conf`

### 7.3 Trzy instancje SQL w FreeRADIUS

Plik `sample/radius-pgsql.conf` definiuje trzy niezależne instancje SQL:

#### 7.3.1 `sql` - Główny accounting
- **Tabele:** `radacct`, `nas` (tabele FreeRADIUS, **nie** są częścią schematu LMS — istnieją osobno w bazie)
- **Operacje:** Start/Stop/Update accounting, Simultaneous-Use check
- **Funkcje:** Tracking sesji, traffic accounting
- **Uwaga:** LMS przechowuje dane sesji we własnej tabeli `nodesessions` (163 tabel LMS). `radacct` to standardowa tabela FreeRADIUS.

#### 7.3.2 `sql_pppoe` - Autoryzacja PPPoE
- **authorize_check_query:** Autoryzacja po nazwie węzła (login), sprawdzenie hasła (Cleartext-Password), wymuszenie `Simultaneous-Use=1`, obliczanie `Mikrotik-Total-Limit` (limit transferu)
- **authorize_reply_query:** Przypisanie `Framed-IP-Address` (IP z tabeli nodes), obliczanie `Mikrotik-Rate-Limit` (upceil/downceil z taryf)
- **Logika taryf:**
  - Tarify przypisane do konkretnego węzła (via `nodeassignments`) mają priorytet
  - Tarify przypisane do klienta (bez nodeassignment) są dzielone po równo na wszystkie węzły klienta
  - Domyślna prędkość: 64k/64k gdy brak aktywnej taryfy

#### 7.3.3 `sql_mac` - Autoryzacja MAC
- **authorize_check_query:** Autoryzacja po adresie MAC, sprawdzenie czy `access=1`
- Używany do prostej autoryzacji dostępu na podstawie adresu MAC

#### 7.3.4 `sql_last_online` - Aktualizacja statusu
- **postauth_query:** Po udanej autoryzacji aktualizuje pole `lastonline` w tabeli `nodes`

### 7.4 Kluczowe tabele RADIUS

#### Tabela `nodes` - centralny punkt integracji
```
nodes.name       → User-Name (RADIUS)
nodes.ipaddr     → Framed-IP-Address (reply)
nodes.passwd     → Cleartext-Password (check)
nodes.mac        → MAC auth User-Name
nodes.access     → 1=dozwolony, 0=zablokowany
nodes.lastonline → aktualizowane po post-auth
nodes.nas        → czy węzeł jest NAS-em
nodes.authtype   → typ autoryzacji
nodes.chkmac     → weryfikacja MAC
```

#### Tabela `nodesessions` - sesje RADIUS
```
nodesessions.customerid     → klient
nodesessions.nodeid         → węzeł
nodesessions.ipaddr         → IP sesji
nodesessions.mac            → MAC sesji
nodesessions.start/stop     → czas trwania
nodesessions.download/upload → transfer
nodesessions.terminatecause → powód zakończenia
nodesessions.nasipaddr      → IP serwera NAS
nodesessions.nasport        → port NAS
nodesessions.nasid          → identyfikator NAS
```

#### Tabela `nastypes` - typy NAS
```
nastypes.name → typ urządzenia NAS (Mikrotik, Cisco, etc.)
```

#### View `vnodes` - widok węzłów
Używany w zapytaniach RADIUS, łączy dane węzłów z informacjami o właścicielu i statusie dostępu.

### 7.5 Mapowanie taryf → atrybuty RADIUS

```
tariffs.upceil   → Mikrotik-Rate-Limit (upload ceil, kb/s)
tariffs.downceil → Mikrotik-Rate-Limit (download ceil, kb/s)
tariffs.dlimit   → Mikrotik-Total-Limit (limit transferu)
```

Formuła Rate-Limit: `{upceil}k/{downceil}k` (np. "512k/2048k")

**Logika obliczania limitów:**
1. Sprawdź taryfy z `nodeassignments` (dedykowane do węzła)
2. Jeśli brak → podziel taryfę klienta na liczbę węzłów bez dedykowanego przypisania
3. Jeśli brak żadnej → 64k/64k (fallback)

### 7.6 CoA / Disconnect-Message

Wbrew pozorom LMS **obsługuje CoA** - moduł `modules/nodesession.php` implementuje rozłączanie sesji RADIUS:

```php
// Konfiguracja komendy (phpui.radius_disconnect_command)
echo 'Framed-IP-Address="%ip%"' | radclient %nasip%:3799 disconnect '%secret%'
```

**Przepływ:**
1. Pobranie parametrów sesji z `nodesessions` (nasipaddr, ipaddr)
2. Pobranie shared secret z `netdevices.secret` (via JOIN nodes→netdevices)
3. Wysłanie RADIUS Disconnect-Message na port 3799 NAS-a via `radclient`

### 7.7 Mikrotik RADIUS Daemon (contrib)

W `contrib/lms-daemon-radius-mikrotik/`:
- Daemon Python synchronizujący dane LMS z Mikrotik via API
- Konfiguracja w `conf/ldrm.conf`
- Klient `client_ldrm.py` do komunikacji z daemonem

---

## 8. Inne systemy provisioningu

### 8.1 lmsd - C Daemon (daemon/)

Modularny daemon napisany w C z systemem pluginów:

| Moduł | Katalog | Funkcja |
|-------|---------|---------|
| `dhcp` | `daemon/modules/dhcp/` | Generowanie konfiguracji DHCP |
| `dns` | `daemon/modules/dns/` | Generowanie konfiguracji DNS |
| `tc` / `tc-new` | `daemon/modules/tc*/` | Traffic Control (HTB/CBQ) |
| `cutoff` | `daemon/modules/cutoff/` | Odcinanie dostępu |
| `hostfile` | `daemon/modules/hostfile/` | Generowanie /etc/hosts |
| `ethers` | `daemon/modules/ethers/` | Generowanie /etc/ethers |
| `notify` | `daemon/modules/notify/` | Powiadomienia |
| `payments` | `daemon/modules/payments/` | Naliczanie opłat |
| `pinger` | `daemon/modules/pinger/` | Monitoring dostępności |
| `traffic` | `daemon/modules/traffic/` | Zbieranie statystyk ruchu |
| `ewx-stm` | `daemon/modules/ewx-stm/` | EWX STM management (SNMP) |
| `ewx-pt` | `daemon/modules/ewx-pt/` | EWX Path Traffic (SNMP) |
| `ewx-stm-channels` | `daemon/modules/ewx-stm-channels/` | EWX kanały per-klient |
| `parser` | `daemon/modules/parser/` | TScript — wbudowany język skryptowy |
| `ggnotify` | `daemon/modules/ggnotify/` | Powiadomienia Gadu-Gadu IM |
| `oident` | `daemon/modules/oident/` | Generowanie konfiguracji oidentd |
| `system` | `daemon/modules/system/` | Wykonywanie dowolnych komend SQL/shell |

### 8.2 PHP Daemon Scripts (bin/)

| Skrypt | Funkcja |
|--------|---------|
| `lms-makedhcpconf.php` | Generowanie konfiguracji DHCP |
| `lms-maketcnew.php` | Traffic Control (nowa wersja) |
| `lms-makeiptables` | Generowanie reguł iptables |
| `lms-makeipchains` | Generowanie reguł ipchains |
| `lms-makeopenbsdpf` | Generowanie reguł OpenBSD PF |
| `lms-makehosts` | Generowanie pliku hosts |
| `lms-makearp` | Generowanie tabeli ARP |
| `lms-makemacs` | Generowanie tabeli MAC |
| `lms-makeon` | Wake-on-LAN |
| `lms-payments.php` | Naliczanie periodycznych opłat |
| `lms-notify.php` | System powiadomień |
| `lms-sendinvoices.php` | Wysyłka faktur e-mailem |
| `lms-cashimport.php` | Import płatności |
| `lms-teryt.php` | Import danych TERYT (GUS) |
| `lms-sidusis.php` | Raportowanie SIDUSIS (UKE) |
| `lms-gus-regon.php` | Weryfikacja danych GUS REGON |
| `lms-fping` | Monitoring ping |
| `lms-rtparser.php` | Parsowanie e-maili helpdesk |
| `lms-cleanup.php` | Czyszczenie starych danych |
| `lms-vat-payers.php` | Weryfikacja VAT (biała lista) |

### 8.3 EtherWerX SNMP Provisioning

W `daemon/modules/` znajdują się trzy moduły do provisioningu urządzeń EtherWerX via SNMP:

| Moduł | Funkcja |
|-------|---------|
| `ewx-stm/` | L2 Traffic Manager - ustawianie limitów per-klient via SNMP SET |
| `ewx-pt/` | Path Traffic Manager - konfiguracja łączy dostępowych |
| `ewx-stm-channels/` | Konfiguracja kanałów per-klient |

Provisioning obejmuje: CustomerMinSpeed, CustomerMaxSpeed, CustomerUplinkSpeed, CustomerDownlinkSpeed, ChannelUplink, ChannelDownlink, HalfDuplex. Obsługa godzin nocnych (różne stawki).

### 8.4 TScript - Wbudowany język skryptowy

Moduł `daemon/modules/parser/` zawiera pełny kompilator i interpreter własnego języka skryptowego (TScript):
- Lexer (`tscript_lexical.l`) + Parser (`tscript_parser.y`)
- AST, kompilator, interpreter
- Rozszerzenia: sieć, SQL, syslog, pliki, system
- Umożliwia pisanie złożonych workflow provisioningowych bez modyfikacji kodu C

### 8.5 Firewall Provisioning

LMS generuje reguły firewalla na podstawie stanu węzłów (access=1/0):
- **iptables** (`lms-makeiptables`, Perl) - Linux
- **ipchains** (`lms-makeipchains`, Perl) - starszy Linux
- **OpenBSD PF** (`lms-makeopenbsdpf`, Perl) - BSD
- **ipfw** (`lms-ipfw`) - FreeBSD

### 8.6 Traffic Control / QoS

- `daemon/modules/tc/` - oryginalny moduł TC (C)
- `daemon/modules/tc-new/` - nowy moduł TC (C)
- `lms-maketcnew.php` - PHP wersja generatora TC
- `lms-traffic-htbiptlimits` - HTB z iptables limitami
- Parametry z taryf: `upceil`, `downceil`, `uprate`, `downrate`, `climit`, `plimit`

### 8.7 DHCP Provisioning

- `daemon/modules/dhcp/` - C moduł
- `lms-makedhcpconf.php` - PHP generator
- Generuje `dhcpd.conf` na podstawie sieci, węzłów i MAC adresów z LMS

### 8.8 DNS Provisioning

- `daemon/modules/dns/` - C moduł
- Tabele PowerDNS: `domains`, `records`, `domainmetadata`, `cryptokeys`, `supermasters`, `tsigkeys`
- Pełna kompatybilność ze schematem PowerDNS

---

## 9. System konfiguracji

### 9.1 Plik INI

Główny plik: `/etc/lms/lms.ini` (lub `lms.ini` w katalogu aplikacji)

Obsługa wirtualnych hostów: `lms-{hostname}.ini`, `lms-{hostname}:{port}.ini`

### 9.2 Tabela uiconfig

Konfiguracja w bazie danych, sekcje odpowiadające sekcjom INI:
- `phpui.*` - ustawienia interfejsu
- `ksef.*` - konfiguracja KSeF
- `invoices.*` - ustawienia faktur
- `mail.*` - ustawienia poczty
- Konfiguracja per division (oddział)

### 9.3 Konfiguracja demonów

Tabele: `daemoninstances`, `daemonconfig`
- Instancje demonów z konfiguracją
- Zarządzanie przez moduły `daemoninstance*.php`, `daemonconfig*.php`

---

## 10. System uprawnień

### 10.1 ACL

- **Pliki:** `lib/LMSPermissions/`, `modules/auth/`
- **Tabele:** `users`, `docrights`, `cashrights`
- Uprawnienia per moduł/operacja
- Prawa do typów dokumentów i kas

### 10.2 Autentykacja

- Cookie-based session (`sessions` table)
- Opcjonalne 2FA (Google Authenticator via `pragmarx/google2fa`)
- Tabele: `twofactorauthcodehistory`, `twofactorauthtrusteddevices`
- Historia haseł: `passwdhistory`

---

## 11. System pluginów

### 11.1 Architektura

- **Manager:** `lib/LMSPluginManager/LMSPluginManager.php` (implementuje Observer pattern)
- **Baza:** `lib/LMSPluginManager/LMSPlugin.php` (abstract, implementuje ObserverInterface)
- **Katalog:** `plugins/`
- Pluginy mogą hookować się w eventy systemu
- Autoloading via Composer classmap

### 11.2 Punkt rozszerzenia

Klasa `LMS.class.php` zawiera tablicę `$hooks` - pluginy rejestrują callbacki na zdarzenia systemowe.

---

## 12. Wielojęzyczność i lokalizacja

Języki z pełnymi tłumaczeniami (`strings.php`): `pl_PL`, `cs_CZ`, `sk_SK`, `lt_LT`, `ro_RO`

Języki z konfiguracją UI (bez dedykowanych tłumaczeń — fallback do angielskiego): `en_US`, `en_GB`, `en_GY`

Pliki tłumaczeń: `lib/locale/{lang}/strings.php`, `ui.php`, `system.php`

---

## 13. Zależności zewnętrzne (Composer)

| Pakiet | Wersja | Przeznaczenie |
|--------|--------|---------------|
| smarty/smarty | ^4 | Template engine |
| phpmailer/phpmailer | ^6 | Wysyłka e-mail |
| tecnickcom/tcpdf | ^6 | Generowanie PDF |
| spipu/html2pdf | ^5 | HTML→PDF |
| gusapi/gusapi | ^5\|\|^6 | GUS REGON API |
| dragonbe/vies | ^2 | VIES VAT verification |
| n1ebieski/ksef-php-client | * | KSeF API client |
| guzzlehttp/guzzle | ^7 | HTTP client |
| phpoffice/phpspreadsheet | * | Excel export/import |
| pragmarx/google2fa | ^8 | 2FA |
| phpseclib/phpseclib | ^3 | Kryptografia (certyfikaty KSeF) |
| ramsey/uuid | ^4 | UUID |
| tinymce/tinymce | ^8 | WYSIWYG editor |
| fortawesome/font-awesome | ^6 | Ikony |
| ezyang/htmlpurifier | ^4 | Sanityzacja HTML |
| erusev/parsedown | ^1 | Markdown parser |
| tecnickcom/tc-lib-barcode | ^1 | Kody kreskowe |
| rzani/zbar-qrdecoder | ^2 | Dekodowanie QR |
| gasparesganga/php-shapefile | ^3 | Pliki shapefile (mapy) |
| proj4php/proj4php | ^2 | Projekcje kartograficzne |

---

## 14. Podsumowanie i obserwacje

### 14.1 Mocne strony architektury

1. **Dojrzałość** - 25 lat rozwoju, stabilna baza kodu
2. **Kompletność** - pokrywa cały stack operatora ISP
3. **Elastyczność provisioningu** - modularny daemon + skrypty PHP
4. **Integracja z polskim ekosystemem** - KSeF, JPK, TERYT, GUS, SIDUSIS
5. **Dual-DB support** - PostgreSQL i MySQL

### 14.1a CI/CD i jakość kodu

- **Travis CI** (`.travis.yml`) testuje PHP 8.1, 8.2, 8.3, 8.4 z PostgreSQL
- Linting PHP + szablonów Smarty + JSHint
- PHP CodeSniffer (`phpcs2.xml`, `phpcs3.xml`)
- PHPUnit (`phpunit.xml`) — framework obecny, ale pokrycie minimalne
- Pakiety Debian (`debian/control`) — lms, lms-common, lms-daemon, lms-ui, lms-tools, lms-doc

### 14.2 Wyzwania architektoniczne

1. **Monolith bez frameworka** - brak routera HTTP, DI container, middleware
2. **Mieszanie warstw** - moduły UI zawierają logikę biznesową i zapytania SQL
3. **Brak REST API** - interfejs wyłącznie przez Web UI + skrypty CLI
4. **Demon C + PHP duality** - dwa systemy provisioningu (daemon C i skrypty PHP) pełniące podobne role
5. **Shared-DB RADIUS** - tight coupling przez współdzielenie tabel zamiast API
6. **Brak testów** - infrastruktura testowa (phpunit.xml) istnieje, ale pokrycie jest minimalne

### 14.3 Stan integracji KSeF

- **Pełna implementacja** generowania XML FA(3) v1-0E
- **Batch processing** z inteligentnym pakowaniem ZIP
- **Obsługa 3 środowisk** (test, demo, prod)
- **Faktury zakupowe** - pełen cykl odbioru i przeglądania
- **Tagowanie i notki** do faktur zakupowych KSeF
- **Deployment tracking** - śledzenie daty wdrożenia per NIP
- **Zależność na zewnętrznym kliencie** `n1ebieski/ksef-php-client` do komunikacji API

### 14.4 Stan integracji JPK ↔ KSeF

W ostatnich commitach (marzec 2026) widać aktywną pracę nad integracją faktur zakupowych z KSeF do plików JPK-V7M(3):
- `c9b600e48` - dodanie faktur zakupowych KSeF do JPK-V7M(3)
- `67caab92c` - fix dla braku faktur non-KSeF w JPK
- `fb16863bf` - korekta dat granicznych JPK-V7M(3)

### 14.5 Stan integracji RADIUS

- **Dojrzała integracja** z FreeRADIUS via shared database
- **PPPoE + MAC auth** jako główne metody autoryzacji
- **Automatyczne mapowanie taryf** na atrybuty Mikrotik (Rate-Limit, Total-Limit)
- **Accounting** w tabeli `nodesessions` z pełnym trackingiem sesji
- **Wsparcie CoA/Disconnect** - moduł `nodesession.php` wysyła Disconnect-Message via `radclient` na port 3799 NAS-a, używając shared secret z `netdevices.secret`
- **Contrib: Mikrotik daemon** (Python) dla bezpośredniej synchronizacji z RouterOS

---

## 15. Analiza gałęzi i drzewa commitów

### 15.1 Informacje ogólne o repozytorium

| Parametr | Wartość |
|----------|---------|
| **Remote** | `github.com/maciek-hyperdev/lms` (fork) |
| **Upstream** | `github.com/chilek/lms` + `chilek/lms-plus` |
| **Główna gałąź** | `master` |
| **Liczba commitów** | 25 885 (od 2002-11-02) |
| **Gałęzie** | 27 remote + 1 local |
| **Tagi** | LMS_27, LMS_26, ... (release tags) |
| **Główny committer (6m)** | Tomasz Chiliński (~656 commitów) |
| **Aktywne committerzy** | Tomasz Chiliński, Jarosław Kłopotek (INTERDUO), Rafał Pietraszewicz, toplek |

### 15.2 Fork architecture

Repozytorium jest **forkiem** `chilek/lms` (główne repo LMS) z regularnym merge'owaniem z upstream. Merge commity wskazują na synchronizację z dwoma źródłami:
- `github.com/chilek/lms` - główne open-source repo
- `github.com/chilek/lms-plus` - rozszerzenia komercyjne / premium

### 15.3 Aktywne gałęzie feature (niescalone z master)

#### `smarty-5` — Migracja Smarty 4 → 5 (6 commitów ahead, 375 behind)
- **Status:** W trakcie, aktywna (grudzień 2025)
- **Autor:** Tomasz Chiliński
- **Zakres:** Duży refactoring (~1289 dodanych, ~3056 usuniętych linii)
- **Kluczowe zmiany:**
  - `composer.json`: `smarty/smarty` z `^4` na `^5`
  - Nowa klasa `lib/Smarty/Plugins.php` — konsolidacja ~80 pluginów Smarty z osobnych plików do jednej klasy
  - Nowy `lib/Smarty/ExtendsAllResource.php` — custom resource handler
  - Nowy `lib/Smarty/UserpanelModuleResource.php` i `UserpanelSetupModuleResource.php`
  - Refactoring `lib/LMSSmarty.php` — adaptacja do Smarty 5 API
  - Usunięte: cały katalog `lib/SmartyPlugins/` (80+ osobnych plików)
  - Aktualizacja backend scripts (`lms-notify.php`, `lms-payments.php`, `lms-sendinvoices.php`)
- **Wpływ:** Fundamentalna zmiana warstwy prezentacji. **Krytyczna gałąź** wymagająca merge'a przed jakimikolwiek zmianami w szablonach.

#### `metroport-mvno` — Plugin Metroport MVNO (58 commitów ahead, 6177 behind)
- **Status:** Dojrzały (wersja 1.1.3), ale bardzo za master (2023)
- **Autor:** Rafał Pietraszewicz
- **Zakres:** 2174 nowych linii, kompletny plugin
- **Funkcjonalność:**
  - Synchronizacja klientów LMS ↔ Metroport MVNO API (po NIP/PESEL)
  - Synchronizacja kont VoIP
  - Import cenników Metroport (CSV)
  - Import billingów VoIP z Metroport do LMS
  - Inkrementalna synchronizacja (by last-id lub call-start-time)
  - Generowanie obciążeń za bilingi
- **Pliki:**
  - `plugins/LMSMetroportMVNOPlugin/` — kompletna struktura pluginu
  - `bin/lms-metroportmvno-sync.php` — skrypt synchronizacji (1481 linii)
  - `lib/metroportmvno/MetroportMVNO.class.php` — klasa API (405 linii)
  - Schemat DB: `doc/lms.pgsql`, `doc/lms.mysql`
- **Gotowość:** Produkcyjna, ale wymaga rebase na aktualny master (6177 commitów za)

#### `ticket-periodicity` — Periodyczność ticketów (2 commity ahead, 643 behind)
- **Status:** Feature-complete, nie scalony (wrzesień 2025)
- **Autor:** Jarosław Kłopotek (INTERDUO)
- **Funkcjonalność:**
  - Nowe pole `periodicity` na ticketach RT (helpdesk)
  - Nowy skrypt `bin/lms-timetable-scheduler.php` — cron tworzy eventy z periodycznych ticketów
  - Konfiguracja: `rt.schedule_planing_forward_events` (domyślnie 3)
  - Definicje perioyczności: dziennie, tygodniowo, co 2 tyg., miesięcznie, kwartalnie, rocznie
  - Migracja DB: `upgradedb/mysql.2025073000.php` / `postgres.2025073000.php`
- **Wpływ:** Nowa funkcjonalność helpdesku — automatyczne planowanie powtarzalnych zadań

#### `rwcontractprotocol-2` — Drukowanie powiązanych dokumentów (2 commity ahead, 2849 behind)
- **Status:** Feature-complete, stary (styczeń 2023)
- **Autor:** Rafał Pietraszewicz
- **Funkcjonalność:** Możliwość drukowania wybranych powiązanych dokumentów z załącznikami
- **Pliki:** `LMSDocumentManager.php`, `documentview.php`, szablony

### 15.4 Bugfix branches (niescalone)

| Gałąź | Ahead | Behind | Data | Opis |
|--------|-------|--------|------|------|
| `ebok-align` | 1 | 223 | 2026-02 | Fix vertical align w Userpanel (styl bclean) |
| `rtticketinfobox-warning-icon` | 1 | 757 | 2025-07 | Ikona ostrzeżenia po przekroczeniu deadline ticketu |
| `interduo-patch-4` | 1 | 1208 | 2025-02 | Fix SQL error przy dodawaniu ticketu z Userpanel bez domyślnej kategorii |
| `interduo-patch-3` | 1 | 1237 | 2025-01 | Fix wyświetlania strzałki załączników na liście dokumentów |
| `interduo-patch-2` | 1 | 1273 | 2025-01 | Nowa wersja schematu eksportu SIDUSIS CSV |
| `bugfix-repair-broken-netdevicesnodes-selection-eventedit` | 2 | 1706 | 2024-07 | Fix wyboru urządzeń sieciowych w edycji eventu |
| `bugfix-event-location` | 1 | 1707 | 2024-07 | Fix wyświetlania lokalizacji w przypisanych eventach |
| `interduo-patch-1` | 1 | 1816 | 2024-04 | Link do mapy SIDUSIS z info o nodzie |

### 15.5 Gałęzie archiwalne (legacy)

| Gałąź | Ostatni commit | Opis |
|--------|---------------|------|
| `promotion-submit-button-fix` | 2018-02 | Fix przycisku w promocjach (11513 behind) |
| `LMS_0110` | 2010-02 | Release branch 1.10.x (145 unique) |
| `LMS_0108` | 2008-06 | Release branch 1.08.x (172 unique) |
| `LMS_0106` | 2007-04 | Release branch 1.06.x |
| `LMS_0104` | 2005-05 | Release branch 1.04.x |
| `LMS_0102*` | 2004 | Release branch 1.02.x (+ international) |
| `LMS_0100` | 2004-09 | Release branch 1.00 |
| `hunter*` | 2003 | Eksperymentalny branch (Krzysztof Drewicz) |
| `LMS_1_1` | 2003-04 | Wczesna gałąź rozwojowa |

Te gałęzie mają jedynie wartość historyczną i **nie powinny być merge'owane** do master.

### 15.6 Diagram gałęzi (timeline)

```
2002 ──────────────────────────────────────────────────────────────── 2026
  │                                                                    │
  │  hunter ──x (2003)                                                │
  │  LMS_1_1 ──x (2003)                                              │
  │  LMS_0100 ──x (2004)                                             │
  │  LMS_0102 ──x (2004)                                             │
  │  LMS_0104 ──x (2005)                                             │
  │  LMS_0106 ──x (2007)                                             │
  │  LMS_0108 ──x (2008)                                             │
  │  LMS_0110 ──x (2010)                                             │
  │                                                                    │
  master ═══════════════════════════════════════════════════════════════►
  │                   │              │         │         │         │
  │                   │              │         │         │    smarty-5 ──►
  │                   │              │    metroport ──►  │    ebok-align ─►
  │                   │              │    -mvno (58)     │
  │                   │         rwcontract ──►          ticket-period ──►
  │                   │         protocol-2
  │              interduo ──►──►──►──►                 bugfix branches ──►
  │              patches 1-4
  │
  promotion-fix ──x (2018)

  Legenda:  ═══ master    ──► active branch    ──x dead branch
            (N) = commits ahead of master
```

### 15.7 Rekomendacje dotyczące gałęzi

#### Do scalenia (priorytet wysoki)
1. **`ebok-align`** (1 commit, 223 behind) — prosty fix CSS, łatwy rebase
2. **`interduo-patch-3`** (1 commit) — fix UI załączników
3. **`interduo-patch-4`** (1 commit) — fix SQL error w userpanel
4. **`rtticketinfobox-warning-icon`** (1 commit) — ikona deadline

#### Do scalenia (priorytet średni, wymagają rebase)
5. **`ticket-periodicity`** (2 commity, 643 behind) — **nowa funkcjonalność** periodyczności ticketów
6. **`bugfix-event-location`** (1 commit) — fix lokalizacji eventów
7. **`bugfix-repair-broken-netdevicesnodes-selection-eventedit`** (2 commity) — fix formularza eventów
8. **`interduo-patch-1`** (1 commit) — link do mapy SIDUSIS
9. **`interduo-patch-2`** (1 commit) — nowy schemat SIDUSIS

#### Do oddzielnego zarządzania
10. **`smarty-5`** (6 commitów, 375 behind) — **migracja fundamentalna**, wymaga osobnego planu migracji i testów regresji wszystkich szablonów
11. **`metroport-mvno`** (58 commitów, 6177 behind) — **kompletny plugin** MVNO, bardzo za master, ale implementacja jest w `plugins/` więc konflikt merge powinien być minimalny
12. **`rwcontractprotocol-2`** (2 commity, 2849 behind) — stary, ale przydatna funkcjonalność

#### Do usunięcia
- Wszystkie gałęzie `LMS_01*`, `hunter*`, `LMS_1_1`, `origin`, `promotion-submit-button-fix` — historyczne, nie mają wartości dla aktualnego development

### 15.8 Aktywność na master (ostatnie commity)

Ostatnie 50 commitów na master (marzec 2026) są **w ogromnej większości związane z KSeF**:
- Blokowanie wysyłki e-mail faktur przed wysłaniem do KSeF
- Obsługa błędów KSeF (statusy 400-500)
- Komentarze i notatki w XML (`<DodatkowyOpis>`)
- Konfiguracja nagłówka QR (`ksef.invoice_header`)
- Środowisko DEMO
- Faktury zakupowe w JPK-V7M(3)
- Zgoda konsumenta (`ksef.all_consumers`)
- Nowa rola odbiorcy: pracownik (8)
- Permanent storage date tracking

To potwierdza, że **KSeF jest obecnie głównym kierunkiem rozwoju** systemu, co jest zgodne z obowiązkiem stosowania KSeF od 2026 roku w Polsce
