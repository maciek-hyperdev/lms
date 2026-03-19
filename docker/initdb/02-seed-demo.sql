-- =============================================================
-- LMS Demo Data Seed
-- =============================================================

-- Admin user (login: admin, password: admin)
-- LMS uses md5(password) by default
UPDATE users SET passwd = '21232f297a57a5a743894a0e4a801fc3', rights = 'full_access', access = 1 WHERE login = 'admin';
INSERT INTO users (login, firstname, lastname, passwd, rights, hosts, access)
SELECT 'admin', 'Administrator', 'LMS', '21232f297a57a5a743894a0e4a801fc3',
       'full_access', '', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE login = 'admin');

-- Address for division
INSERT INTO addresses (name, city, street, zip, house)
VALUES ('DEMO-ISP HQ', 'Warszawa', 'ul. Testowa', '00-001', '1');

-- Division (company / ISP entity)
INSERT INTO divisions (shortname, name, ten, regon, phone, email, account, address_id)
VALUES (
    'DEMO-ISP',
    'Demo Internet Service Provider Sp. z o.o.',
    '1234567890',
    '123456789',
    '+48 22 123 45 67',
    'biuro@demo-isp.pl',
    '12345678901234567890123456',
    (SELECT id FROM addresses WHERE name = 'DEMO-ISP HQ')
);

-- Assign admin to ALL divisions (default + DEMO-ISP)
INSERT INTO userdivisions (userid, divisionid)
SELECT u.id, d.id FROM users u CROSS JOIN divisions d WHERE u.login = 'admin';

-- Tax rates
INSERT INTO taxes (label, value, taxed) VALUES
    ('23%', 23.00, 1),
    ('8%', 8.00, 1),
    ('0%', 0.00, 1),
    ('zw.', 0.00, 0);

-- ===================== NETWORKS =====================

INSERT INTO networks (name, address, mask, interface, gateway, dns, dns2, domain, wins, dhcpstart, dhcpend, notes)
VALUES (
    'LAN-SUBSCRIBERS',
    inet_aton('10.0.1.0'),
    '255.255.255.0',
    'eth0',
    inet_aton('10.0.1.1'),
    inet_aton('8.8.8.8'),
    inet_aton('8.8.4.4'),
    'demo-isp.local',
    inet_aton('0.0.0.0'),
    inet_aton('10.0.1.100'),
    inet_aton('10.0.1.200'),
    'Main subscriber network for demo'
);

INSERT INTO networks (name, address, mask, interface, gateway, dns, dns2, domain, wins, dhcpstart, dhcpend, notes)
VALUES (
    'MGMT',
    inet_aton('10.0.0.0'),
    '255.255.255.0',
    'eth1',
    inet_aton('10.0.0.1'),
    inet_aton('8.8.8.8'),
    inet_aton('8.8.4.4'),
    'mgmt.demo-isp.local',
    inet_aton('0.0.0.0'),
    inet_aton('10.0.0.0'),
    inet_aton('10.0.0.0'),
    'Management network'
);

-- ===================== NAS TYPES =====================
INSERT INTO nastypes (name) VALUES ('Mikrotik'), ('Cisco'), ('Juniper'), ('Generic');

-- ===================== TARIFFS =====================
-- upceil/downceil are in kbit/s

INSERT INTO tariffs (name, value, period, type, taxid, upceil, downceil, uprate, downrate, dlimit, climit, plimit, description)
VALUES
    ('Internet 50/10',   49.99, 1, 3, 1, 10240,  51200,  5120, 25600, 0, 0, 0, '50 Mbit/s download, 10 Mbit/s upload'),
    ('Internet 100/20',  79.99, 1, 3, 1, 20480, 102400, 10240, 51200, 0, 0, 0, '100 Mbit/s download, 20 Mbit/s upload'),
    ('Internet 200/50', 119.99, 1, 3, 1, 51200, 204800, 25600, 102400, 0, 0, 0, '200 Mbit/s download, 50 Mbit/s upload'),
    ('Internet 500/100', 149.99, 1, 3, 1, 102400, 512000, 51200, 256000, 0, 0, 0, '500 Mbit/s download, 100 Mbit/s upload'),
    ('Internet 1G/300',  199.99, 1, 3, 1, 307200, 1048576, 153600, 524288, 0, 0, 0, '1 Gbit/s download, 300 Mbit/s upload');

-- ===================== CUSTOMERS =====================
-- Customers reference addresses via customer_addresses junction table

-- Customer addresses first
INSERT INTO addresses (name, city, street, zip, house, flat) VALUES
    ('Kowalski',    'Warszawa',  'ul. Kwiatowa',  '00-100', '5',  '12'),
    ('Nowak',       'Kraków',    'ul. Lipowa',    '30-001', '23', NULL),
    ('Wiśniewski',  'Gdańsk',    'ul. Dębowa',    '80-001', '8',  NULL),
    ('Wójcik',      'Wrocław',   'ul. Sosnowa',   '50-001', '42', '3'),
    ('Kamiński',    'Poznań',    'ul. Brzozowa',  '60-001', '15', NULL),
    ('Zieliński',   'Łódź',      'ul. Klonowa',   '90-001', '7',  '1'),
    ('Szymańska',   'Katowice',  'ul. Jodłowa',   '40-001', '33', NULL),
    ('IT Solutions','Warszawa',  'ul. Cyfrowa',   '00-200', '10', NULL),
    ('NetCorp',     'Kraków',    'ul. Sieciowa',  '30-100', '44', NULL),
    ('Lewandowski', 'Szczecin',  'ul. Topolowa',  '70-001', '2',  '5');

-- Customers (type: 0=person, 1=company; status: 3=active)
INSERT INTO customers (lastname, name, status, type, ten, ssn, regon, divisionid, creationdate, moddate, pin)
VALUES
    ('Kowalski',    'Jan',       3, 0, '',           '90010112345', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Nowak',       'Anna',      3, 0, '',           '85050523456', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Wiśniewski',  'Piotr',     3, 0, '',           '78030334567', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Wójcik',      'Katarzyna', 3, 0, '',           '92071245678', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Kamiński',    'Tomasz',    3, 0, '',           '88112256789', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Zieliński',   'Marek',     3, 0, '',           '75060167890', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Szymański',   'Ewa',       3, 0, '',           '95020278901', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('IT Solutions','',          3, 1, '5271234567', '',            '012345678', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('NetCorp',     '',          3, 1, '7891234567', '',            '987654321', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000'),
    ('Lewandowski', 'Robert',    3, 0, '',           '82090189012', '', (SELECT id FROM divisions WHERE shortname='DEMO-ISP'), EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, '0000');

-- Link customers to addresses (type 0 = billing/main address)
INSERT INTO customer_addresses (customer_id, address_id, type)
SELECT c.id, a.id, 0
FROM customers c
JOIN addresses a ON a.name = c.lastname
WHERE c.lastname NOT IN ('IT Solutions', 'NetCorp');

INSERT INTO customer_addresses (customer_id, address_id, type)
SELECT c.id, a.id, 0
FROM customers c
JOIN addresses a ON a.name = c.lastname
WHERE c.lastname IN ('IT Solutions', 'NetCorp');

-- ===================== NETWORK DEVICE (NAS) =====================

INSERT INTO netdevices (name, shortname, nastype, clients, secret, community, description)
VALUES ('MikroTik-BRAS-01', 'BRAS01', 1, 100, 'testing123', 'public', 'Main BRAS router - Mikrotik CCR1036');

-- NAS node (the router's management IP)
INSERT INTO nodes (name, ipaddr, ipaddr_pub, ownerid, netdev, access, warning, authtype, chkmac, nas, creationdate, moddate, info, netid, passwd)
VALUES ('bras01-mgmt', inet_aton('10.0.0.2'), 0, NULL, 1, 1, 0, 0, 0, 1, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'BRAS router management interface',
    (SELECT id FROM networks WHERE name = 'MGMT'), '');

-- ===================== SUBSCRIBER NODES =====================

INSERT INTO nodes (name, ipaddr, ipaddr_pub, ownerid, access, warning, authtype, chkmac, nas, creationdate, moddate, info, netid, passwd, login) VALUES
('kowalski-cpe',    inet_aton('10.0.1.101'), 0, 1,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Jan Kowalski CPE',       (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret101', 'kowalski-cpe'),
('nowak-cpe',       inet_aton('10.0.1.102'), 0, 2,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Anna Nowak CPE',         (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret102', 'nowak-cpe'),
('wisniewski-cpe',  inet_aton('10.0.1.103'), 0, 3,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Piotr Wisniewski CPE',   (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret103', 'wisniewski-cpe'),
('wojcik-cpe',      inet_aton('10.0.1.104'), 0, 4,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Katarzyna Wojcik CPE',   (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret104', 'wojcik-cpe'),
('kaminski-cpe',    inet_aton('10.0.1.105'), 0, 5,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Tomasz Kaminski CPE',    (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret105', 'kaminski-cpe'),
('zielinski-cpe',   inet_aton('10.0.1.106'), 0, 6,  1, 1, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Marek Zielinski - WARN', (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret106', 'zielinski-cpe'),
('szymanska-cpe',   inet_aton('10.0.1.107'), 0, 7,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Ewa Szymanska CPE',      (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret107', 'szymanska-cpe'),
('itsolutions-gw',  inet_aton('10.0.1.108'), 0, 8,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'IT Solutions gateway',   (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret108', 'itsolutions-gw'),
('netcorp-gw',      inet_aton('10.0.1.109'), 0, 9,  1, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'NetCorp gateway',        (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret109', 'netcorp-gw'),
('lewandowski-cpe', inet_aton('10.0.1.110'), 0, 10, 0, 0, 0, 1, 0, EXTRACT(EPOCH FROM NOW())::integer, EXTRACT(EPOCH FROM NOW())::integer, 'Robert Lewandowski - BLOCKED', (SELECT id FROM networks WHERE name='LAN-SUBSCRIBERS'), 'secret110', 'lewandowski-cpe');

-- MAC addresses
INSERT INTO macs (nodeid, mac)
SELECT n.id, 'AA:BB:CC:00:01:' || lpad(to_hex(inet_aton(inet_ntoa(n.ipaddr)) - inet_aton('10.0.1.0'))::text, 2, '0')
FROM nodes n
WHERE n.ownerid IS NOT NULL AND n.nas = 0;

-- ===================== ASSIGNMENTS (tariff -> customer) =====================

INSERT INTO assignments (customerid, tariffid, period, datefrom, dateto, suspended, invoice, settlement) VALUES
(1, 2, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '6 months'))::integer,  0, 0, 1, 1),  -- Kowalski -> 100/20
(2, 3, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '3 months'))::integer,  0, 0, 1, 1),  -- Nowak -> 200/50
(3, 1, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '12 months'))::integer, 0, 0, 1, 1),  -- Wisniewski -> 50/10
(4, 2, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '1 month'))::integer,   0, 0, 1, 1),  -- Wojcik -> 100/20
(5, 4, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '2 months'))::integer,  0, 0, 1, 1),  -- Kaminski -> 500/100
(6, 1, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '8 months'))::integer,  0, 0, 1, 1),  -- Zielinski -> 50/10
(7, 3, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '4 months'))::integer,  0, 0, 1, 1),  -- Szymanska -> 200/50
(8, 5, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '5 months'))::integer,  0, 0, 1, 1),  -- IT Solutions -> 1G/300
(9, 4, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '7 months'))::integer,  0, 0, 1, 1),  -- NetCorp -> 500/100
(10, 2, 1, EXTRACT(EPOCH FROM (NOW() - INTERVAL '9 months'))::integer, 0, 1, 1, 1);  -- Lewandowski -> 100/20 (suspended!)

-- ===================== NODE ASSIGNMENTS =====================

INSERT INTO nodeassignments (nodeid, assignmentid)
SELECT n.id, a.id
FROM nodes n
JOIN assignments a ON a.customerid = n.ownerid
WHERE n.ownerid IS NOT NULL AND n.nas = 0;

-- ===================== VERIFY =====================

DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== DEMO DATA SEED COMPLETE ===';
    RAISE NOTICE 'Customers: %', (SELECT COUNT(*) FROM customers);
    RAISE NOTICE 'Nodes (subscribers): %', (SELECT COUNT(*) FROM nodes WHERE nas = 0 AND ownerid IS NOT NULL);
    RAISE NOTICE 'NAS devices: %', (SELECT COUNT(*) FROM nodes WHERE nas = 1);
    RAISE NOTICE 'Tariffs: %', (SELECT COUNT(*) FROM tariffs);
    RAISE NOTICE 'Assignments: %', (SELECT COUNT(*) FROM assignments);
    RAISE NOTICE '';
    RAISE NOTICE 'RADIUS test (from host):';
    RAISE NOTICE '  radtest kowalski-cpe secret101 localhost 0 testing123';
    RAISE NOTICE '  radtest nowak-cpe secret102 localhost 0 testing123';
    RAISE NOTICE '  radtest lewandowski-cpe secret110 localhost 0 testing123  (blocked)';
    RAISE NOTICE '';
    RAISE NOTICE 'LMS UI: http://localhost:8080  (admin / admin)';
    RAISE NOTICE '================================';
END $$;
