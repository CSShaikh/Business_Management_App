import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constant.dart';
import '../models/ledger_transaction_model.dart';
import 'base_repository.dart';

class LedgerRepository extends BaseRepository {
LedgerRepository({
super.firestore,
});

CollectionReference<Map<String, dynamic>> _ledger(
String businessId,
) {
final normalizedBusinessId =
businessId.trim();

       
if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

return firestore
    .collection(
      AppConstants.businessesCollection,
    )
    .doc(normalizedBusinessId)
    .collection(
      AppConstants.ledgerTransactionsCollection,
    );
       

}

Future<LedgerTransactionModel> createTransaction(
LedgerTransactionModel transaction,
) async {
_validateTransaction(
transaction,
requireId: false,
);

       
final businessId =
    transaction.businessId.trim();

final collectionRef =
    _ledger(businessId);

final documentRef =
    transaction.id.trim().isEmpty
        ? collectionRef.doc()
        : collectionRef.doc(
            transaction.id.trim(),
          );

final transactionToSave =
    LedgerTransactionModel(
  id: documentRef.id,
  businessId: businessId,
  customerId:
      transaction.customerId.trim(),
  customerName:
      transaction.customerName.trim(),
  transactionType:
      transaction.transactionType.trim(),
  amount: transaction.amount,
  balanceBefore:
      transaction.balanceBefore,
  balanceAfter:
      transaction.balanceAfter,
  referenceId:
      transaction.referenceId.trim(),
  date: transaction.date,
  notes: transaction.notes.trim(),
  createdAt: transaction.createdAt,
);

await documentRef.set(
  _toMap(transactionToSave),
);

return transactionToSave;
       

}

Future<LedgerTransactionModel?> getTransaction({
required String businessId,
required String transactionId,
}) async {
final normalizedBusinessId =
businessId.trim();

       
final normalizedTransactionId =
    transactionId.trim();

if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

if (normalizedTransactionId.isEmpty) {
  throw ArgumentError(
    'Transaction ID cannot be empty.',
  );
}

final snapshot = await _ledger(
  normalizedBusinessId,
)
    .doc(normalizedTransactionId)
    .get();

if (!snapshot.exists) {
  return null;
}

final data = snapshot.data();

if (data == null) {
  return null;
}

return _fromMap(
  snapshot.id,
  data,
  fallbackBusinessId:
      normalizedBusinessId,
);
       

}

Future<List<LedgerTransactionModel>>
getTransactions({
required String businessId,
}) async {
final normalizedBusinessId =
businessId.trim();

       
if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

final snapshot = await _ledger(
  normalizedBusinessId,
)
    .orderBy(
      'date',
      descending: true,
    )
    .get();

return snapshot.docs
    .map(
      (doc) => _fromMap(
        doc.id,
        doc.data(),
        fallbackBusinessId:
            normalizedBusinessId,
      ),
    )
    .toList();
       

}

Stream<List<LedgerTransactionModel>>
watchTransactions({
required String businessId,
}) {
final normalizedBusinessId =
businessId.trim();

       
if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

return _ledger(
  normalizedBusinessId,
)
    .orderBy(
      'date',
      descending: true,
    )
    .snapshots()
    .map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => _fromMap(
              doc.id,
              doc.data(),
              fallbackBusinessId:
                  normalizedBusinessId,
            ),
          )
          .toList(),
    );
       

}

Future<List<LedgerTransactionModel>>
getCustomerTransactions({
required String businessId,
required String customerId,
}) async {
final normalizedBusinessId =
businessId.trim();

       
final normalizedCustomerId =
    customerId.trim();

if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

if (normalizedCustomerId.isEmpty) {
  throw ArgumentError(
    'Customer ID cannot be empty.',
  );
}

final snapshot = await _ledger(
  normalizedBusinessId,
)
    .where(
      'customerId',
      isEqualTo: normalizedCustomerId,
    )
    .orderBy(
      'date',
      descending: true,
    )
    .get();

return snapshot.docs
    .map(
      (doc) => _fromMap(
        doc.id,
        doc.data(),
        fallbackBusinessId:
            normalizedBusinessId,
      ),
    )
    .toList();
       

}

Stream<List<LedgerTransactionModel>>
watchCustomerTransactions({
required String businessId,
required String customerId,
}) {
final normalizedBusinessId =
businessId.trim();

       
final normalizedCustomerId =
    customerId.trim();

if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

if (normalizedCustomerId.isEmpty) {
  throw ArgumentError(
    'Customer ID cannot be empty.',
  );
}

return _ledger(
  normalizedBusinessId,
)
    .where(
      'customerId',
      isEqualTo: normalizedCustomerId,
    )
    .orderBy(
      'date',
      descending: true,
    )
    .snapshots()
    .map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => _fromMap(
              doc.id,
              doc.data(),
              fallbackBusinessId:
                  normalizedBusinessId,
            ),
          )
          .toList(),
    );
       

}

Future<List<LedgerTransactionModel>>
getTransactionsByType({
required String businessId,
required String transactionType,
}) async {
final normalizedBusinessId =
businessId.trim();

       
final normalizedTransactionType =
    transactionType.trim();

if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

if (normalizedTransactionType.isEmpty) {
  throw ArgumentError(
    'Transaction type cannot be empty.',
  );
}

final snapshot = await _ledger(
  normalizedBusinessId,
)
    .where(
      'transactionType',
      isEqualTo: normalizedTransactionType,
    )
    .orderBy(
      'date',
      descending: true,
    )
    .get();

return snapshot.docs
    .map(
      (doc) => _fromMap(
        doc.id,
        doc.data(),
        fallbackBusinessId:
            normalizedBusinessId,
      ),
    )
    .toList();
       

}

Future<void> updateTransaction(
LedgerTransactionModel transaction,
) async {
_validateTransaction(
transaction,
requireId: true,
);

       
final transactionId =
    transaction.id.trim();

final businessId =
    transaction.businessId.trim();

final documentRef = _ledger(
  businessId,
).doc(transactionId);

final existingDocument =
    await documentRef.get();

if (!existingDocument.exists) {
  throw StateError(
    'Ledger transaction not found.',
  );
}

final existingData =
    existingDocument.data();

if (existingData == null) {
  throw StateError(
    'Ledger transaction data not found.',
  );
}

final existingTransaction =
    _fromMap(
  existingDocument.id,
  existingData,
  fallbackBusinessId:
      businessId,
);

final updatedTransaction =
    LedgerTransactionModel(
  id: existingTransaction.id,
  businessId: businessId,
  customerId:
      transaction.customerId.trim(),
  customerName:
      transaction.customerName.trim(),
  transactionType:
      transaction.transactionType.trim(),
  amount: transaction.amount,
  balanceBefore:
      transaction.balanceBefore,
  balanceAfter:
      transaction.balanceAfter,
  referenceId:
      transaction.referenceId.trim(),
  date: transaction.date,
  notes: transaction.notes.trim(),
  createdAt:
      existingTransaction.createdAt,
);

await documentRef.update(
  _toMap(updatedTransaction),
);
       

}

Future<void> deleteTransaction({
required String businessId,
required String transactionId,
}) async {
final normalizedBusinessId =
businessId.trim();

       
final normalizedTransactionId =
    transactionId.trim();

if (normalizedBusinessId.isEmpty) {
  throw ArgumentError(
    'Business ID cannot be empty.',
  );
}

if (normalizedTransactionId.isEmpty) {
  throw ArgumentError(
    'Transaction ID cannot be empty.',
  );
}

final documentRef = _ledger(
  normalizedBusinessId,
).doc(normalizedTransactionId);

final document =
    await documentRef.get();

if (!document.exists) {
  throw StateError(
    'Ledger transaction not found.',
  );
}

await documentRef.delete();
       

}

Future<double> getCustomerBalance({
required String businessId,
required String customerId,
}) async {
final transactions =
await getCustomerTransactions(
businessId: businessId,
customerId: customerId,
);

       
if (transactions.isEmpty) {
  return 0;
}

return transactions.first.balanceAfter;
       

}

Future<double> getTotalReceivable({
required String businessId,
}) async {
final transactions =
await getTransactions(
businessId: businessId,
);

       
if (transactions.isEmpty) {
  return 0;
}

final Map<String, double>
    customerBalances = {};

for (final transaction
    in transactions) {
  final customerId =
      transaction.customerId.trim();

  if (customerId.isEmpty) {
    continue;
  }

  customerBalances[customerId] =
      transaction.balanceAfter;
}

return customerBalances.values.fold<double>(
  0,
  (total, balance) {
    if (balance > 0) {
      return total + balance;
    }

    return total;
  },
);
       

}

Future<List<LedgerTransactionModel>>
searchTransactions({
required String businessId,
required String query,
}) async {
final normalizedQuery =
query.trim().toLowerCase();

       
final transactions =
    await getTransactions(
  businessId: businessId,
);

if (normalizedQuery.isEmpty) {
  return transactions;
}

return transactions.where(
  (transaction) {
    final customerName =
        transaction.customerName
            .toLowerCase();

    final transactionType =
        transaction.transactionType
            .toLowerCase();

    final referenceId =
        transaction.referenceId
            .toLowerCase();

    final notes =
        transaction.notes
            .toLowerCase();

    final amount =
        transaction.amount
            .toStringAsFixed(2);

    return customerName.contains(
          normalizedQuery,
        ) ||
        transactionType.contains(
          normalizedQuery,
        ) ||
        referenceId.contains(
          normalizedQuery,
        ) ||
        notes.contains(
          normalizedQuery,
        ) ||
        amount.contains(
          normalizedQuery,
        );
  },
).toList();
       

}

Map<String, dynamic> _toMap(
LedgerTransactionModel transaction,
) {
return {
'id': transaction.id.trim(),
'businessId':
transaction.businessId.trim(),
'customerId':
transaction.customerId.trim(),
'customerName':
transaction.customerName.trim(),
'transactionType':
transaction.transactionType.trim(),
'amount':
transaction.amount,
'balanceBefore':
transaction.balanceBefore,
'balanceAfter':
transaction.balanceAfter,
'referenceId':
transaction.referenceId.trim(),
'date': Timestamp.fromDate(
transaction.date,
),
'notes':
transaction.notes.trim(),
'createdAt': Timestamp.fromDate(
transaction.createdAt,
),
};
}

LedgerTransactionModel _fromMap(
String documentId,
Map<String, dynamic> data, {
String fallbackBusinessId = '',
}) {
final rawId =
data['id']?.toString().trim() ?? '';

       
final rawBusinessId =
    data['businessId']
            ?.toString()
            .trim() ??
        '';

return LedgerTransactionModel(
  id: rawId.isEmpty
      ? documentId
      : rawId,
  businessId: rawBusinessId.isEmpty
      ? fallbackBusinessId.trim()
      : rawBusinessId,
  customerId:
      data['customerId']
              ?.toString()
              .trim() ??
          '',
  customerName:
      data['customerName']
              ?.toString()
              .trim() ??
          '',
  transactionType:
      data['transactionType']
              ?.toString()
              .trim() ??
          '',
  amount:
      _toDouble(data['amount']),
  balanceBefore:
      _toDouble(
    data['balanceBefore'],
  ),
  balanceAfter:
      _toDouble(
    data['balanceAfter'],
  ),
  referenceId:
      data['referenceId']
              ?.toString()
              .trim() ??
          '',
  date:
      dateFromFirestore(
    data['date'],
  ),
  notes:
      data['notes']
              ?.toString()
              .trim() ??
          '',
  createdAt:
      dateFromFirestore(
    data['createdAt'],
  ),
);
       

}

double _toDouble(
dynamic value,
) {
if (value is num) {
final result =
value.toDouble();

       
  return result.isFinite
      ? result
      : 0;
}

if (value is String) {
  final result =
      double.tryParse(
    value.trim(),
  );

  if (result != null &&
      result.isFinite) {
    return result;
  }
}

return 0;
       

}

void _validateTransaction(
LedgerTransactionModel transaction, {
required bool requireId,
}) {
if (transaction.businessId
.trim()
.isEmpty) {
throw ArgumentError(
'Business ID cannot be empty.',
);
}

       
if (requireId &&
    transaction.id.trim().isEmpty) {
  throw ArgumentError(
    'Transaction ID cannot be empty.',
  );
}

if (transaction.customerId
    .trim()
    .isEmpty) {
  throw ArgumentError(
    'Customer ID cannot be empty.',
  );
}

if (transaction.customerName
    .trim()
    .isEmpty) {
  throw ArgumentError(
    'Customer name cannot be empty.',
  );
}

if (transaction.transactionType
    .trim()
    .isEmpty) {
  throw ArgumentError(
    'Transaction type cannot be empty.',
  );
}

if (!transaction.amount.isFinite ||
    transaction.amount <= 0) {
  throw ArgumentError(
    'Transaction amount must be greater than zero.',
  );
}

if (!transaction.balanceBefore.isFinite) {
  throw ArgumentError(
    'Balance before must be a valid number.',
  );
}

if (!transaction.balanceAfter.isFinite) {
  throw ArgumentError(
    'Balance after must be a valid number.',
  );
}

}
}
