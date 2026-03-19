# LMS - Model danych

**Baza danych:** PostgreSQL / MySQL
**Tabel:** 163 | **Relacji FK:** 272 | **Widoków:** ~15
**Wersja schematu:** 2026031600

---

## 1. Diagram ERD - Klastry domenowe (przegląd)

```mermaid
erDiagram
    %% ===== CORE IDENTITY =====
    users ||--o{ userdivisions : "userid"
    divisions ||--o{ userdivisions : "divisionid"
    divisions }o--|| addresses : "address_id"
    users ||--o{ userassignments : "userid"
    usergroups ||--o{ userassignments : "usergroupid"

    %% ===== CUSTOMER CLUSTER =====
    customers }o--o| divisions : "divisionid"
    customers }o--o| users : "creatorid"
    customers ||--o{ customer_addresses : "customer_id"
    addresses ||--o{ customer_addresses : "address_id"
    customers ||--o{ customercontacts : "customerid"
    customers ||--o{ customerconsents : "customerid"
    customers ||--o{ customerextids : "customerid"
    customers ||--o{ customerassignments : "customerid"
    customergroups ||--o{ customerassignments : "customergroupid"
    customers ||--o{ customernotes : "customerid"

    %% ===== NETWORK CLUSTER =====
    customers ||--o{ nodes : "ownerid"
    nodes }o--|| networks : "netid"
    nodes }o--o| netdevices : "netdev"
    nodes ||--o{ macs : "nodeid"
    nodes ||--o{ nodesessions : "nodeid"
    customers ||--o{ nodesessions : "customerid"
    nodes ||--o{ nodeassignments : "nodeid"
    netdevices ||--o{ netlinks : "src/dst"
    netnodes ||--o{ netdevices : "netnodeid"

    %% ===== FINANCE CLUSTER =====
    customers ||--o{ assignments : "customerid"
    tariffs ||--o{ assignments : "tariffid"
    taxes ||--o{ tariffs : "taxid"
    assignments ||--o{ nodeassignments : "assignmentid"
    customers ||--o{ documents : "customerid"
    divisions ||--o{ documents : "divisionid"
    documents ||--o{ invoicecontents : "docid"
    documents ||--o{ cash : "docid"
    customers ||--o{ cash : "customerid"

    %% ===== KSEF CLUSTER =====
    ksefbatchsessions ||--o{ ksefdocuments : "batchsessionid"
    documents ||--o{ ksefdocuments : "docid"
    divisions ||--o{ ksefdelays : "divisionid"
    divisions ||--o{ ksefinvoices : "division_id"
    ksefinvoices ||--o{ ksefinvoiceitems : "ksef_invoice_id"
    ksefinvoices ||--o{ ksefinvoicesummaries : "ksef_invoice_id"
    ksefinvoices ||--o{ ksefinvoicetagassignments : "ksef_invoice_id"
    ksefinvoicetags ||--o{ ksefinvoicetagassignments : "ksef_invoice_tag_id"

    %% ===== HELPDESK CLUSTER =====
    customers ||--o{ rttickets : "customerid"
    rtqueues ||--o{ rttickets : "queueid"
    rttickets ||--o{ rtmessages : "ticketid"
    rtmessages ||--o{ rtattachments : "messageid"
    rtcategories ||--o{ rtticketcategories : "categoryid"
```

---

## 2. Klaster: Tożsamość i organizacja

```mermaid
erDiagram
    users {
        int id PK
        varchar login UK
        varchar firstname
        varchar lastname
        varchar passwd "md5 hash"
        text rights "np. full_access"
        smallint access "0=zablok 1=aktywny"
        smallint twofactorauth
    }
    divisions {
        int id PK
        varchar shortname
        text name "pełna nazwa firmy"
        varchar ten "NIP"
        varchar regon
        int address_id FK
        varchar email
        varchar phone
    }
    userdivisions {
        int id PK
        int userid FK
        int divisionid FK
    }
    usergroups {
        int id PK
        varchar name
        text description
    }
    userassignments {
        int id PK
        int userid FK
        int usergroupid FK
    }
    addresses {
        int id PK
        text name
        varchar city
        int city_id FK "opcjonalnie TERYT"
        varchar street
        int street_id FK "opcjonalnie TERYT"
        varchar zip
        varchar house
        varchar flat
        int country_id FK
    }

    users ||--o{ userdivisions : ""
    divisions ||--o{ userdivisions : ""
    divisions }o--o| addresses : "address_id"
    users ||--o{ userassignments : ""
    usergroups ||--o{ userassignments : ""
```

**Kluczowa relacja:** Użytkownik MUSI być przypisany do co najmniej jednej division via `userdivisions`, aby widzieć klientów tej division.

---

## 3. Klaster: Klient (CRM)

```mermaid
erDiagram
    customers {
        int id PK
        varchar lastname
        varchar name "imię (osoba) lub puste (firma)"
        smallint status "3=aktywny"
        smallint type "0=osoba 1=firma"
        varchar ten "NIP"
        varchar ssn "PESEL"
        varchar regon
        int divisionid FK "WYMAGANE - filtr widoczności"
        int creatorid FK
        int modid FK
        smallint deleted
        smallint flags "JPK: FP/EE/TP/MPP"
    }
    customer_addresses {
        int id PK
        int customer_id FK
        int address_id FK
        smallint type "0=billing 1=koresp 2=lokalizacja"
    }
    customercontacts {
        int id PK
        int customerid FK
        varchar contact "email/telefon"
        varchar name
        smallint type
    }
    customerconsents {
        int id PK
        int customerid FK
        varchar type "RODO/KSeF/marketing"
        bigint cdate
    }
    customerextids {
        int id PK
        int customerid FK
        int serviceproviderid FK
        varchar extid "ID w systemie zewn."
    }
    serviceproviders {
        int id PK
        varchar name "np. Metroport MVNO"
    }
    customergroups {
        int id PK
        varchar name
        text description
    }
    customerassignments {
        int id PK
        int customerid FK
        int customergroupid FK
    }
    customernotes {
        int id PK
        int customerid FK
        int userid FK
        text note
    }

    customers ||--o{ customer_addresses : ""
    addresses ||--o{ customer_addresses : ""
    customers ||--o{ customercontacts : ""
    customers ||--o{ customerconsents : ""
    customers ||--o{ customerextids : ""
    serviceproviders ||--o{ customerextids : ""
    customers ||--o{ customerassignments : ""
    customergroups ||--o{ customerassignments : ""
    customers ||--o{ customernotes : ""
    divisions ||--o{ customers : "divisionid"
    users ||--o{ customers : "creatorid"
```

---

## 4. Klaster: Sieć i urządzenia

```mermaid
erDiagram
    networks {
        int id PK
        varchar name
        bigint address "inet_aton IP"
        varchar mask
        varchar interface
        bigint gateway
        bigint dns
        bigint dhcpstart
        bigint dhcpend
        int vlanid FK
    }
    nodes {
        int id PK
        varchar name UK "= RADIUS User-Name"
        varchar login "alternatywny login"
        bigint ipaddr "inet_aton"
        bigint ipaddr_pub
        varchar passwd "RADIUS Cleartext-Password"
        int ownerid FK "NULL = NAS / infra"
        int netdev FK "netdevice ID"
        int netid FK "siec"
        smallint access "1=ok 0=zablok"
        smallint warning
        smallint authtype
        smallint chkmac
        smallint nas "1 = jest NAS-em"
        bigint lastonline "aktualizowane po post-auth"
    }
    macs {
        int id PK
        int nodeid FK
        varchar mac "AA:BB:CC:DD:EE:FF"
    }
    netdevices {
        int id PK
        varchar name
        varchar shortname
        int nastype FK "nastypes.id"
        int clients "ilość portów"
        varchar secret "RADIUS shared secret"
        varchar community "SNMP community"
        int netnodeid FK
    }
    netnodes {
        int id PK
        varchar name
        text type "szafa/budynek/słup"
        int invprojectid FK
    }
    netlinks {
        int id PK
        int src FK "netdevices.id"
        int dst FK "netdevices.id"
        smallint type "0=kabel 1=radio"
        int speed
        int technology
    }
    netradiosectors {
        int id PK
        int netdev FK "netdevices.id"
        varchar name
        varchar frequency
        int bandwidth
    }
    vlans {
        int id PK
        int vlanid "numer VLAN 1-4094"
        varchar description
        int customerid FK
        int netnodeid FK
    }
    nastypes {
        int id PK
        varchar name UK "Mikrotik/Cisco/..."
    }
    nodesessions {
        int id PK
        int customerid FK
        int nodeid FK
        bigint ipaddr
        varchar mac
        bigint start
        bigint stop
        bigint download
        bigint upload
        varchar terminatecause
        bigint nasipaddr
        text nasport
        text nasid
    }

    networks ||--o{ nodes : "netid"
    customers ||--o{ nodes : "ownerid"
    netdevices ||--o{ nodes : "netdev"
    nodes ||--o{ macs : "nodeid"
    nodes ||--o{ nodesessions : "nodeid"
    customers ||--o{ nodesessions : "customerid"
    netnodes ||--o{ netdevices : "netnodeid"
    netdevices ||--o{ netlinks : "src"
    netdevices ||--o{ netradiosectors : "netdev"
    nastypes ||--o{ netdevices : "nastype"
    vlans ||--o{ networks : "vlanid"
    nodes ||--o{ stats : "nodeid"
    nodesessions ||--o{ stats : "nodesessionid"
```

**Widok `vnodes`:** Łączy `nodes` + `macs` (array_agg) + `addresses`. Używany przez RADIUS.

**Widok `nas`:** Łączy `nodes` (nas=1) + `netdevices` — eksponuje NAS-y dla FreeRADIUS.

---

## 5. Klaster: Finanse i fakturowanie

```mermaid
erDiagram
    tariffs {
        int id PK
        varchar name
        numeric value "cena brutto"
        smallint type "3=internet"
        int taxid FK "stawka VAT"
        int upceil "upload kbit/s"
        int downceil "download kbit/s"
        int uprate "gwarancja upload"
        int downrate "gwarancja download"
        int dlimit "limit transferu"
        int climit "limit połączeń"
        int plimit "limit portów"
        text description
    }
    taxes {
        int id PK
        varchar label "23% / 8% / zw."
        numeric value
        smallint taxed
    }
    assignments {
        int id PK
        int customerid FK
        int tariffid FK
        int liabilityid FK
        int numberplanid FK
        int promotionschemaid FK
        smallint period "1=miesiąc"
        bigint datefrom
        bigint dateto "0=bezterminowo"
        smallint suspended "1=zawieszony"
        smallint invoice "1=faktura"
        smallint settlement
    }
    nodeassignments {
        int id PK
        int nodeid FK
        int assignmentid FK
    }
    documents {
        int id PK
        int type "1=faktura 3=korekta..."
        int customerid FK
        int divisionid FK
        int numberplanid FK
        int userid FK "wystawca"
        varchar number
        bigint cdate
        smallint cancelled
        smallint flags "JPK: FP+EE+TP+MPP"
    }
    invoicecontents {
        int id PK
        int docid FK
        varchar itemname
        int count
        numeric value
        int taxid FK
    }
    cash {
        int id PK
        bigint time
        numeric value
        int customerid FK
        int docid FK
        int userid FK
        int taxid FK
        int importid FK
        int sourceid FK
        text comment
    }
    cashimport {
        int id PK
        int customerid FK
        int sourceid FK
        int sourcefileid FK
        varchar customerid_match "dopasowanie z banku"
        numeric value
        varchar name
    }
    numberplans {
        int id PK
        varchar template "np. FV/%N/RRRR"
        smallint doctype
        smallint isdefault
    }
    promotions {
        int id PK
        varchar name
        text description
    }
    promotionschemas {
        int id PK
        int promotionid FK
        varchar name
    }

    taxes ||--o{ tariffs : "taxid"
    customers ||--o{ assignments : "customerid"
    tariffs ||--o{ assignments : "tariffid"
    promotionschemas ||--o{ assignments : "promotionschemaid"
    assignments ||--o{ nodeassignments : "assignmentid"
    nodes ||--o{ nodeassignments : "nodeid"
    customers ||--o{ documents : "customerid"
    divisions ||--o{ documents : "divisionid"
    numberplans ||--o{ documents : "numberplanid"
    documents ||--o{ invoicecontents : "docid"
    documents ||--o{ cash : "docid"
    customers ||--o{ cash : "customerid"
    cashimport ||--o{ cash : "importid"
    promotions ||--o{ promotionschemas : "promotionid"
```

**Kluczowe relacje:**
- `assignments` łączy `customers` ↔ `tariffs` (kto ma jaką taryfę)
- `nodeassignments` łączy `nodes` ↔ `assignments` (który węzeł korzysta z której taryfy)
- RADIUS używa łańcucha: `vnodes` → `nodeassignments` → `assignments` → `tariffs` do obliczenia `Mikrotik-Rate-Limit`

---

## 6. Klaster: KSeF (e-Faktury)

```mermaid
erDiagram
    ksefbatchsessions {
        int id PK
        varchar ksefnumber "numer sesji KSeF"
        bigint cdate
        smallint status "0=pending 200=ok"
        text statusdescription
        smallint environment "1=test 2=prod 3=demo"
    }
    ksefdocuments {
        int id PK
        int batchsessionid FK
        int docid FK "powiązanie z fakturą LMS"
        int ordinalnumber "nr w paczce"
        varchar ksefnumber "numer KSeF faktury"
        varchar hash "hash do QR"
        smallint status
        text statusdescription
        text statusdetails
    }
    ksefdelays {
        int id PK
        int divisionid FK
        int delay "sekundy opóźnienia"
    }
    ksefallconsumers {
        int id PK
        int divisionid FK
        smallint allconsumers
    }
    ksefinvoices {
        int id PK
        int division_id FK
        bigint issue_date
        varchar ksef_number
        varchar invoice_number
        varchar seller_ten
        varchar seller_name
        varchar buyer_identifier_value
        numeric net_amount
        numeric gross_amount
        numeric vat_amount
        varchar currency
        smallint posting
        text notes
    }
    ksefinvoiceitems {
        int ksef_invoice_id FK
        smallint item_id
        varchar name
        numeric count
        numeric price
        numeric value
        numeric tax_rate
    }
    ksefinvoicesummaries {
        int ksef_invoice_id FK
        numeric net_amount
        numeric gross_amount
        numeric vat_amount
        numeric tax_rate
    }
    ksefinvoicetags {
        int id PK
        text name
    }
    ksefinvoicetagassignments {
        int id PK
        int ksef_invoice_id FK
        int ksef_invoice_tag_id FK
    }

    ksefbatchsessions ||--o{ ksefdocuments : ""
    documents ||--o{ ksefdocuments : "docid"
    divisions ||--o{ ksefdelays : ""
    divisions ||--o{ ksefallconsumers : ""
    divisions ||--o{ ksefinvoices : ""
    ksefinvoices ||--o{ ksefinvoiceitems : ""
    ksefinvoices ||--o{ ksefinvoicesummaries : ""
    ksefinvoices ||--o{ ksefinvoicetagassignments : ""
    ksefinvoicetags ||--o{ ksefinvoicetagassignments : ""
```

---

## 7. Klaster: Helpdesk (RT)

```mermaid
erDiagram
    rtqueues {
        int id PK
        varchar name
        varchar email
        text description
    }
    rttickets {
        int id PK
        int queueid FK
        int customerid FK
        int owner FK "users.id"
        int creatorid FK
        varchar subject
        smallint state "0=nowy 1=otwarty 2=resolved 3=dead"
        smallint priority
        int parentid FK "rttickets.id - hierarchia"
        int nodeid FK
        int netdevid FK
    }
    rtmessages {
        int id PK
        int ticketid FK
        int customerid FK
        int userid FK
        varchar subject
        text body
        smallint type "0=note 1=reply"
        bigint createtime
        int inreplyto FK "rtmessages.id"
    }
    rtattachments {
        int id PK
        int messageid FK
        varchar filename
        varchar contenttype
    }
    rtcategories {
        int id PK
        varchar name
        text description
    }
    rtticketcategories {
        int id PK
        int ticketid FK
        int categoryid FK
    }
    rtrights {
        int id PK
        int userid FK
        int queueid FK
        smallint rights
    }

    rtqueues ||--o{ rttickets : "queueid"
    customers ||--o{ rttickets : "customerid"
    users ||--o{ rttickets : "owner"
    rttickets ||--o{ rtmessages : "ticketid"
    rtmessages ||--o{ rtattachments : "messageid"
    rtcategories ||--o{ rtticketcategories : "categoryid"
    rttickets ||--o{ rtticketcategories : "ticketid"
    users ||--o{ rtrights : "userid"
    rtqueues ||--o{ rtrights : "queueid"
```

---

## 8. Klaster: VoIP

```mermaid
erDiagram
    voipaccounts {
        int id PK
        int ownerid FK "customers.id"
        varchar login
        varchar passwd
        int serviceproviderid FK
    }
    voip_numbers {
        int id PK
        int voip_account_id FK
        varchar phone
        int tariff_id FK
    }
    voip_cdr {
        int id PK
        int callervoipaccountid FK
        int calleevoipaccountid FK
        varchar caller
        varchar callee
        bigint call_start_time
        int totaltime
        int billedtime
        numeric price
    }
    voip_tariffs {
        int id PK
        varchar name
        text description
    }
    voip_rules {
        int id PK
        int rule_group_id FK
        int prefix_group_id FK
        text description
    }

    customers ||--o{ voipaccounts : "ownerid"
    voipaccounts ||--o{ voip_numbers : "voip_account_id"
    tariffs ||--o{ voip_numbers : "tariff_id"
    voipaccounts ||--o{ voip_cdr : "callervoipaccountid"
```

---

## 9. Klaster: DNS / Hosting

```mermaid
erDiagram
    domains {
        int id PK
        varchar name "np. example.pl"
        varchar master
        varchar type "MASTER/SLAVE/NATIVE"
        int ownerid FK "customers.id"
    }
    records {
        int id PK
        int domain_id FK
        varchar name "FQDN"
        varchar type "A/AAAA/MX/CNAME/..."
        varchar content
        int ttl
    }
    passwd {
        int id PK
        int ownerid FK "customers.id"
        int domainid FK
        varchar login
        varchar password
    }
    aliases {
        int id PK
        varchar login
        int domainid FK
    }

    customers ||--o{ domains : "ownerid"
    domains ||--o{ records : "domain_id"
    domains ||--o{ passwd : "domainid"
    domains ||--o{ aliases : "domainid"
    customers ||--o{ passwd : "ownerid"
```

---

## 10. Widoki (VIEWs)

| Widok | Tabele bazowe | Przeznaczenie |
|-------|---------------|---------------|
| `vnodes` | `nodes` + `macs` (array_agg) + `addresses` | Główny widok węzłów — RADIUS |
| `vmacs` | `nodes` + `macs` (JOIN) + `addresses` | Widok per-MAC (wiele wierszy/MAC) |
| `nas` | `nodes` (nas=1) + `netdevices` | Lista NAS-ów dla FreeRADIUS |
| `vdivisions` | `divisions` + `addresses` | Dane firm z adresami |
| `vaddresses` | `addresses` + `location_cities` + `location_streets` + `location_states` | Pełne adresy z TERYT |
| `customerview` | `customers` + agregaty | Widok klientów z saldem i dodatkowymi danymi |

---

## 11. Statystyki modelu

| Metryka | Wartość |
|---------|---------|
| Tabel | 163 |
| Relacji FK | 272 |
| Widoków | ~15 |
| Sekwencji | ~120 |
| Indeksów | ~200 |
| Funkcji custom | `inet_aton()`, `inet_ntoa()`, `mask2prefix()`, `broadcast()` |
| Migracji | 1466+ (2004-2026) |

### Tabele z największą liczbą FK (zależności):

| Tabela | Ilość FK wychodzących | Główne zależności |
|--------|----------------------|-------------------|
| `rttickets` | 11 | customers, users(5x), rtqueues, nodes, netdevices, addresses, invprojects, rttickets |
| `documents` | 10 | customers, users(3x), divisions, countries(2x), numberplans, addresses(2x), documents |
| `events` | 10 | customers, users(3x), divisions, nodes, netdevices, netnodes, addresses, rttickets |
| `nodes` | 8 | customers, networks, netdevices, users(2x), addresses, invprojects, netradiosectors |
| `assignments` | 7 | customers, tariffs, liabilities, numberplans, promotionschemas, addresses, documents |
| `cash` | 6 | customers, documents, users, taxes, cashimport, cashsources |

### Tabele z największą liczbą FK przychodzących (referencje DO nich):

| Tabela | Ilość referencji | Rola |
|--------|-----------------|------|
| `customers` | 25+ | Centralny podmiot systemu |
| `users` | 25+ | Twórca/modyfikator wszędzie |
| `divisions` | 10+ | Filtr widoczności, jednostka organizacyjna |
| `addresses` | 10+ | Uniwersalny adres (TERYT) |
| `nodes` | 8+ | Punkt styku klient-sieć |
| `documents` | 7+ | Kontener faktur/dokumentów |
