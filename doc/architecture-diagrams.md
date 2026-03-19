# LMS - Diagramy architektury (Mermaid)

## Diagram kontekstowy (C4 Context)

```mermaid
C4Context
    title LMS - Diagram Kontekstowy

    Person(admin, "Administrator ISP", "Zarządza siecią, klientami, fakturami")
    Person(client, "Klient końcowy", "Podgląd salda, faktur, zmiana danych")

    System(lms, "LMS", "System zarządzania siecią ISP<br/>PHP + PostgreSQL/MySQL")

    System_Ext(ksef, "KSeF", "Krajowy System e-Faktur<br/>(Ministerstwo Finansów)")
    System_Ext(gus, "GUS REGON", "Weryfikacja danych firm<br/>(SOAP API)")
    System_Ext(vies, "VIES", "Weryfikacja VAT UE")
    System_Ext(radius, "FreeRADIUS", "AAA Server<br/>Autoryzacja dostępu do sieci")
    System_Ext(dhcp, "DHCP Server", "Dynamiczne przydzielanie IP")
    System_Ext(dns, "DNS / PowerDNS", "Zarządzanie strefami DNS")
    System_Ext(firewall, "Firewall", "iptables / PF / ipfw")
    System_Ext(tc, "Traffic Control", "HTB / CBQ shaping")
    System_Ext(mikrotik, "Mikrotik / NAS", "Urządzenia sieciowe")
    System_Ext(asterisk, "Asterisk", "VoIP PBX")
    System_Ext(bank, "Systemy bankowe", "Import płatności")
    System_Ext(smtp, "Serwer pocztowy", "Wysyłka e-mail / SMS")

    Rel(admin, lms, "HTTP/HTTPS", "Panel administracyjny")
    Rel(client, lms, "HTTP/HTTPS", "Userpanel")
    Rel(lms, ksef, "HTTPS REST", "Wysyłka/odbiór e-faktur")
    Rel(lms, gus, "SOAP", "Weryfikacja NIP/REGON")
    Rel(lms, vies, "SOAP", "Weryfikacja VAT UE")
    BiRel(lms, radius, "SQL", "Shared database")
    Rel(lms, dhcp, "Config files", "Generowanie dhcpd.conf")
    Rel(lms, dns, "SQL / Config", "Zarządzanie strefami")
    Rel(lms, firewall, "Config files", "Reguły firewalla")
    Rel(lms, tc, "Config files", "Reguły QoS")
    Rel(lms, mikrotik, "API / RADIUS", "Provisioning")
    Rel(lms, asterisk, "SQL / Config", "VoIP provisioning")
    Rel(bank, lms, "CSV/MT940", "Import płatności")
    Rel(lms, smtp, "SMTP", "Powiadomienia")
```

## Diagram komponentów (C4 Container)

```mermaid
C4Container
    title LMS - Diagram Kontenerów

    Person(admin, "Administrator ISP")
    Person(client, "Klient")

    System_Boundary(lms, "LMS System") {
        Container(webui, "Admin Panel", "PHP/Smarty", "~400 modułów UI<br/>index.php entry point")
        Container(userpanel, "Userpanel", "PHP/Smarty", "Portal klienta")
        Container(lmscore, "LMS Core", "PHP", "LMS.class.php + Managery<br/>Logika biznesowa")
        Container(ksef_lib, "KSeF Library", "PHP", "lib/KSeF/KSeF.php<br/>Generowanie XML FA(3)")
        Container(plugins, "Plugin System", "PHP", "Observer pattern<br/>Rozszerzenia")
        Container(daemons, "PHP Daemons", "PHP CLI", "bin/lms-*.php<br/>Cron jobs")
        Container(lmsd, "lmsd", "C", "daemon/<br/>Modularny daemon")
        Container(db, "Database", "PostgreSQL/MySQL", "163 tabel<br/>1466+ migracji")
    }

    System_Ext(ksef_api, "KSeF API")
    System_Ext(freeradius, "FreeRADIUS")
    System_Ext(network, "Urządzenia sieciowe")

    Rel(admin, webui, "HTTPS")
    Rel(client, userpanel, "HTTPS")
    Rel(webui, lmscore, "PHP calls")
    Rel(userpanel, lmscore, "PHP calls")
    Rel(lmscore, ksef_lib, "PHP calls")
    Rel(lmscore, plugins, "Observer events")
    Rel(lmscore, db, "SQL")
    Rel(ksef_lib, ksef_api, "HTTPS REST")
    Rel(daemons, db, "SQL")
    Rel(daemons, network, "Config files / API")
    Rel(lmsd, db, "SQL")
    Rel(lmsd, network, "Config files")
    Rel(freeradius, db, "SQL queries")
```

## Diagram przepływu KSeF

```mermaid
flowchart TB
    subgraph LMS["LMS System"]
        INV[Faktura VAT w LMS]
        KSEF_LIB[KSeF Library]
        XML_GEN["getInvoiceXml()<br/>Generowanie XML FA(3) v1-0E"]
        XSD_VAL["Walidacja XSD<br/>schemat_FA(3)_v1-0E.xsd"]
        ZIP_BUILD["buildZipPackages<br/>FromXmlDocuments()<br/>Pakowanie ZIP (smart batching)"]
        DB_BATCH[(ksefbatchsessions)]
        DB_DOC[(ksefdocuments)]
        DB_INV[(ksefinvoices)]
        STORAGE["storage/ksef/<br/>upo/ + invoice/"]
    end

    subgraph KSeF_API["KSeF API (MF)"]
        PROD["PROD: ksef.mf.gov.pl"]
        TEST["TEST: ksef-test.mf.gov.pl"]
        DEMO["DEMO: ksef-demo.mf.gov.pl"]
    end

    INV -->|dane faktury| XML_GEN
    XML_GEN -->|XML string| XSD_VAL
    XSD_VAL -->|zwalidowany XML| ZIP_BUILD
    ZIP_BUILD -->|ZIP binary| KSEF_LIB
    KSEF_LIB -->|"HTTPS POST<br/>(via ksef-php-client)"| PROD
    KSEF_LIB -->|"batch session info"| DB_BATCH
    KSEF_LIB -->|"document status"| DB_DOC
    PROD -->|"UPO + numery KSeF"| KSEF_LIB
    KSEF_LIB -->|"UPO files"| STORAGE
    PROD -->|"faktury zakupowe"| DB_INV

    style LMS fill:#e8f4f8
    style KSeF_API fill:#fff3e0
```

## Diagram przepływu RADIUS

```mermaid
flowchart LR
    subgraph Client["Urządzenie klienta"]
        CPE[CPE / Router]
    end

    subgraph NAS["NAS (Mikrotik/inny)"]
        AUTH_REQ["Authentication<br/>Request"]
        ACCT_REQ["Accounting<br/>Request"]
    end

    subgraph FreeRADIUS["FreeRADIUS"]
        SQL_PPPOE["sql_pppoe<br/>(authorize)"]
        SQL_MAC["sql_mac<br/>(MAC auth)"]
        SQL_ACCT["sql<br/>(accounting)"]
        SQL_LAST["sql_last_online<br/>(post-auth)"]
    end

    subgraph LMS_DB["LMS Database"]
        VNODES["vnodes (VIEW)<br/>name, passwd, ipaddr"]
        NODES["nodes<br/>access, mac, lastonline"]
        TARIFFS["tariffs<br/>upceil, downceil, dlimit"]
        ASSIGN["assignments +<br/>nodeassignments"]
        SESSIONS["nodesessions (LMS)<br/>start, stop, upload, download"]
        RADACCT["radacct (FreeRADIUS)<br/>nie jest częścią schematu LMS"]
    end

    CPE -->|PPPoE/802.1X| AUTH_REQ
    AUTH_REQ -->|RADIUS| SQL_PPPOE
    AUTH_REQ -->|RADIUS| SQL_MAC
    CPE -->|traffic| ACCT_REQ
    ACCT_REQ -->|RADIUS| SQL_ACCT

    SQL_PPPOE -->|"SELECT passwd, ipaddr<br/>FROM vnodes"| VNODES
    SQL_PPPOE -->|"SELECT upceil, downceil<br/>→ Mikrotik-Rate-Limit"| TARIFFS
    SQL_PPPOE --> ASSIGN
    SQL_MAC -->|"SELECT mac, access<br/>FROM nodes"| NODES
    SQL_ACCT -->|"INSERT/UPDATE"| RADACCT
    SQL_LAST -->|"UPDATE lastonline"| NODES

    SQL_PPPOE -->|"Access-Accept +<br/>Framed-IP-Address +<br/>Mikrotik-Rate-Limit"| NAS
    SQL_MAC -->|"Access-Accept"| NAS

    style Client fill:#e8f4f8
    style FreeRADIUS fill:#fff3e0
    style LMS_DB fill:#e8f5e9
```

## Diagram warstw architektury

```mermaid
graph TB
    subgraph Presentation["Warstwa prezentacji"]
        ADMIN["Admin Panel<br/>(~400 modułów)"]
        USERPANEL["Userpanel<br/>(portal klienta)"]
        EXPORT["Export<br/>(CSV/XML/PDF)"]
    end

    subgraph Business["Warstwa logiki biznesowej"]
        FACADE["LMS.class.php<br/>(Fasada / Singleton)"]
        subgraph Managers["Domain Managers"]
            CM[CustomerManager]
            FM[FinanceManager]
            NM[NodeManager]
            NWM[NetworkManager]
            NDM[NetDevManager]
            HM[HelpdeskManager]
            DM[DocumentManager]
            MM[MessageManager]
            VM[VoipAccountManager]
        end
        subgraph Libs["Specialized Libraries"]
            KSEF[KSeF]
            DOCS[LMSDocuments]
            PERMS[Permissions]
            CONFIG[Config]
            G2FA[Google2FA]
        end
        PLUGINS["Plugin System<br/>(Observer pattern)"]
    end

    subgraph Data["Warstwa danych"]
        LMSDB["LMSDB<br/>(Database abstraction)"]
        SESSION["Session Management"]
        CACHE["LMSCache"]
    end

    subgraph Infrastructure["Infrastruktura"]
        DB[(PostgreSQL / MySQL)]
        FS["Filesystem<br/>(documents, storage)"]
    end

    ADMIN --> FACADE
    USERPANEL --> FACADE
    EXPORT --> FACADE
    FACADE --> Managers
    FACADE --> Libs
    FACADE --> PLUGINS
    Managers --> LMSDB
    Libs --> LMSDB
    LMSDB --> DB
    SESSION --> DB
    DOCS --> FS

    style Presentation fill:#bbdefb
    style Business fill:#c8e6c9
    style Data fill:#fff9c4
    style Infrastructure fill:#ffccbc
```

## Diagram ERD - kluczowe tabele

```mermaid
erDiagram
    customers ||--o{ nodes : "ownerid"
    customers ||--o{ assignments : "customerid"
    customers ||--o{ documents : "customerid"
    customers ||--o{ nodesessions : "customerid"

    nodes ||--o{ nodesessions : "nodeid"
    nodes ||--o{ nodeassignments : "nodeid"
    nodes }o--|| networks : "netid"
    nodes }o--o| netdevices : "netdev"

    assignments ||--o{ nodeassignments : "assignmentid"
    assignments }o--|| tariffs : "tariffid"

    tariffs {
        int id PK
        varchar name
        int upceil "upload ceil kb/s"
        int downceil "download ceil kb/s"
        int uprate "upload rate"
        int downrate "download rate"
        bigint dlimit "download limit"
        bigint ulimit "upload limit"
    }

    documents ||--o{ ksefdocuments : "docid"
    documents ||--o{ invoicecontents : "docid"

    ksefbatchsessions ||--o{ ksefdocuments : "batchsessionid"
    ksefbatchsessions {
        int id PK
        varchar ksefnumber
        smallint status
        smallint environment
    }

    ksefdocuments {
        int id PK
        int batchsessionid FK
        int docid FK
        varchar ksefnumber
        varchar hash
        smallint status
    }

    ksefinvoices ||--o{ ksefinvoiceitems : "ksef_invoice_id"
    ksefinvoices ||--o{ ksefinvoicesummaries : "ksef_invoice_id"
    ksefinvoices {
        int id PK
        int division_id FK
        varchar ksef_number
        varchar invoice_number
        varchar seller_ten
        numeric net_amount
        numeric gross_amount
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
    }

    divisions ||--o{ ksefdelays : "divisionid"
    divisions ||--o{ ksefallconsumers : "divisionid"
```

## Diagram gałęzi Git

```mermaid
gitGraph
    commit id: "LMS 1.00 (2002)"
    branch LMS_0100
    commit id: "release 1.00"
    checkout main
    commit id: "..."
    branch LMS_0110
    commit id: "release 1.10 (2010)"
    checkout main
    commit id: "development 2010-2023"
    branch metroport-mvno
    commit id: "MVNO sync v1.0"
    commit id: "MVNO sync v1.1.3 (58 commits)"
    checkout main
    commit id: "development 2023-2024"
    branch interduo-patches
    commit id: "SIDUSIS export fix"
    commit id: "SQL fix userpanel"
    commit id: "attachment arrow fix"
    checkout main
    commit id: "development 2024-2025"
    branch ticket-periodicity
    commit id: "periodic tickets"
    commit id: "lms-timetable-scheduler"
    checkout main
    branch smarty-5
    commit id: "Smarty 4→5 migration"
    commit id: "plugin consolidation"
    checkout main
    commit id: "KSeF integration (active)"
    branch ebok-align
    commit id: "CSS vertical align fix"
    checkout main
    commit id: "KSeF purchase invoices"
    commit id: "JPK-V7M(3) integration"
    commit id: "KSeF error handling"
    commit id: "HEAD (2026-03-19)"
```

## Macierz gałęzi feature

```mermaid
quadrantChart
    title Gałęzie feature - Trudność merge vs Wartość biznesowa
    x-axis "Łatwość merge (behind master)" --> "Trudność merge"
    y-axis "Niska wartość" --> "Wysoka wartość"
    "smarty-5": [0.55, 0.95]
    "metroport-mvno": [0.9, 0.85]
    "ticket-periodicity": [0.6, 0.7]
    "ebok-align": [0.2, 0.15]
    "interduo-patches": [0.35, 0.3]
    "rwcontractprotocol-2": [0.75, 0.4]
    "bugfix branches": [0.5, 0.25]
```
