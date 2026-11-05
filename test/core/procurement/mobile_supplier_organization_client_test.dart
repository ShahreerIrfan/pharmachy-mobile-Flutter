// mobile_supplier_organization_client_test.dart
// Architecture Decision: ADR-0181 (P181) & ADR-0182 (P182).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_organization_client.dart';

void main() {
  group('MobileSupplierOrganizationClient Tests (P181 & P182)', () {
    late MobileSupplierOrganizationClient managerClient;
    late MobileSupplierOrganizationClient cashierClient;
    late MobileSupplierOrganizationClient foreignClient;

    setUp(() {
      final sharedSuppliers = <String, MobileSupplierOrganization>{};
      final sharedLedger = <MobileSupplierLedgerEntry>[];
      final sharedContacts = <String, MobileSupplierContactPerson>{};

      managerClient = MobileSupplierOrganizationClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialSuppliers: sharedSuppliers,
        initialLedger: sharedLedger,
        initialContacts: sharedContacts,
      );

      cashierClient = MobileSupplierOrganizationClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialSuppliers: sharedSuppliers,
        initialLedger: sharedLedger,
        initialContacts: sharedContacts,
      );

      foreignClient = MobileSupplierOrganizationClient(
        tenantId: 'tenant-other',
        branchId: 'branch-2',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-2',
        initialSuppliers: sharedSuppliers,
        initialLedger: sharedLedger,
        initialContacts: sharedContacts,
      );
    });

    test(
        'Test 1: Valid supplier creation with legal credentials, NBR tax references, and authentic origin verification',
        () {
      final supplier = managerClient.createSupplier(
        name: 'Square Pharmaceuticals Depot',
        legalName: 'Square Pharmaceuticals PLC Regional Distribution',
        phone: '+8801711223344',
        email: 'depot.dhaka@squarepharma.com.bd',
        region: 'DHAKA',
        dlNumber: 'DGDA-DL-2026-99',
        binNumber: '001122334-0101',
        tinNumber: '9988776655',
        tradeLicenseNumber: 'TRAD/DNCC/2026/0881',
        paymentTermsDays: 30,
        creditLimit: 500000.0,
      );

      expect(supplier.supplierId, startsWith('sup-'));
      expect(supplier.name, equals('Square Pharmaceuticals Depot'));
      expect(supplier.region, equals('DHAKA'));
      expect(supplier.binNumber, equals('001122334-0101'));
      expect(supplier.creditLimit, equals(500000.0));
      expect(supplier.currentBalance, equals(0.0));
      expect(supplier.isActive, isTrue);

      // Verify authentic origin
      final verified = managerClient.verifyProofOfOrigin(
        supplierId: supplier.supplierId,
        verificationNotes: 'DGDA wholesale certificate verified',
      );
      expect(verified.proofOfOriginVerified, isTrue);
      expect(verified.proofOfOriginNotes,
          equals('DGDA wholesale certificate verified'));

      // List suppliers
      final list = managerClient.listSuppliers();
      expect(list.length, equals(1));
      expect(list.first.supplierId, equals(supplier.supplierId));
    });

    test('Test 2: Incomplete or invalid supplier inputs are cleanly rejected',
        () {
      // Empty name
      expect(
        () => managerClient.createSupplier(
          name: '',
          legalName: 'Legal Name',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative credit limit
      expect(
        () => managerClient.createSupplier(
          name: 'Incepta Depot',
          legalName: 'Incepta PLC',
          creditLimit: -500.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Duplicate active name
      managerClient.createSupplier(
        name: 'Beximco Pharma Depot',
        legalName: 'Beximco PLC',
      );

      expect(
        () => managerClient.createSupplier(
          name: 'Beximco Pharma Depot',
          legalName: 'Beximco Duplicate',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Test 3: AP ledger postings accurately reconcile GRN receipts, payments, and running balance',
        () {
      final supplier = managerClient.createSupplier(
        name: 'Renata Distribution Depot',
        legalName: 'Renata Ltd',
        creditLimit: 200000.0,
      );

      // GRN Invoice credit: +35,000.50 BDT
      final grn = managerClient.postApLedgerEntry(
        supplierId: supplier.supplierId,
        postingType: 'GRN_INVOICE',
        referenceNumber: 'GRN-2026-0091',
        creditAmount: 35000.50,
        notes: 'Antibiotics and syrups shipment',
      );
      expect(grn.balanceAfter, equals(35000.50));
      expect(supplier.currentBalance, equals(35000.50));

      // Payment debit: -20,000.00 BDT
      final payment = managerClient.postApLedgerEntry(
        supplierId: supplier.supplierId,
        postingType: 'PAYMENT',
        referenceNumber: 'PAY-VOUCH-1002',
        debitAmount: 20000.00,
        notes: 'Online bank transfer',
      );
      expect(payment.balanceAfter, equals(15000.50));
      expect(supplier.currentBalance, equals(15000.50));

      // Return Debit Note: -500.50 BDT
      final debitNote = managerClient.postApLedgerEntry(
        supplierId: supplier.supplierId,
        postingType: 'RETURN_DEBIT_NOTE',
        referenceNumber: 'DN-2026-004',
        debitAmount: 500.50,
        notes: 'Damaged cartons returned',
      );
      expect(debitNote.balanceAfter, equals(14500.00));
      expect(supplier.currentBalance, equals(14500.00));
    });

    test('Test 4: Cashier RBAC gate and cross-tenant isolation enforcement',
        () {
      // Cashier cannot register supplier
      expect(
        () => cashierClient.createSupplier(
          name: 'Opsonin Depot',
          legalName: 'Opsonin PLC',
        ),
        throwsA(isA<StateError>()),
      );

      // Create under tenant-evercare
      final supplier = managerClient.createSupplier(
        name: 'ACI Healthcare Depot',
        legalName: 'ACI Ltd',
      );

      // Cashier cannot post to AP ledger
      expect(
        () => cashierClient.postApLedgerEntry(
          supplierId: supplier.supplierId,
          postingType: 'PAYMENT',
          referenceNumber: 'REF-001',
          debitAmount: 100.0,
        ),
        throwsA(isA<StateError>()),
      );

      // Foreign tenant cannot access supplier
      expect(
        () => foreignClient.getSupplier(supplier.supplierId),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Test 5: Multiple contact persons and atomic primary representative reassignment',
        () {
      final supplier = managerClient.createSupplier(
        name: 'Healthcare Pharma Depot',
        legalName: 'Healthcare Ltd',
      );

      // Contact 1: Sales rep (set primary)
      final c1 = managerClient.createSupplierContact(
        supplierId: supplier.supplierId,
        name: 'Md. Anisur Rahman',
        designation: 'MIO / Territory Officer',
        role: 'SALES_REPRESENTATIVE',
        phone: '+8801711334455',
        preferredCommunicationMethod: 'WHATSAPP',
        isPrimary: true,
      );
      expect(c1.isPrimary, isTrue);
      expect(c1.preferredCommunicationMethod, equals('WHATSAPP'));

      // Contact 2: Depot manager (set primary)
      final c2 = managerClient.createSupplierContact(
        supplierId: supplier.supplierId,
        name: 'Tariqul Islam',
        designation: 'Depot Manager',
        role: 'DEPOT_MANAGER',
        phone: '+8801811445566',
        preferredCommunicationMethod: 'PHONE',
        isPrimary: true,
      );
      expect(c2.isPrimary, isTrue);

      // c1 should now be un-set as primary
      final c1Refreshed = managerClient.getSupplierContact(c1.contactId);
      expect(c1Refreshed.isPrimary, isFalse);

      // List contacts
      final contacts =
          managerClient.listSupplierContacts(supplier.supplierId);
      expect(contacts.length, equals(2));
      expect(contacts.first.contactId, equals(c2.contactId)); // Primary first

      // Update contact
      managerClient.updateSupplierContact(
        contactId: c1.contactId,
        phone: '+8801799887766',
        role: 'ORDER_BOOKER',
      );
      expect(c1Refreshed.phone, equals('+8801799887766'));
      expect(c1Refreshed.role, equals('ORDER_BOOKER'));

      // Archive contact
      managerClient.archiveSupplierContact(c1.contactId);
      expect(c1Refreshed.isActive, isFalse);
    });

    test('Test 6: Contact persons RBAC and cross-tenant isolation enforcement',
        () {
      final supplier = managerClient.createSupplier(
        name: 'Popular Pharma Depot',
        legalName: 'Popular Ltd',
      );

      // Cashier cannot create contact
      expect(
        () => cashierClient.createSupplierContact(
          supplierId: supplier.supplierId,
          name: 'Contact Staff',
          phone: '01700000000',
        ),
        throwsA(isA<StateError>()),
      );

      // Create contact under manager
      final contact = managerClient.createSupplierContact(
        supplierId: supplier.supplierId,
        name: 'Authorized Staff',
        phone: '01711111111',
      );

      // Foreign tenant cannot access contact
      expect(
        () => foreignClient.getSupplierContact(contact.contactId),
        throwsA(isA<StateError>()),
      );
    });
  });
}
