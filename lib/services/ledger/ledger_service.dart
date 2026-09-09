import '../../models/ledger_transaction_model.dart';
import '../../repositories/ledger_repository.dart';

class LedgerService {
LedgerService({
LedgerRepository? repository,
}) : _repository =
repository ?? LedgerRepository();

final LedgerRepository _repository;

Future<LedgerTransactionModel> createTransaction({
required String businessId,
required String customerId,
required String customerName,
required String transactionType,
required double amount,
required double balanceBefore,
required double balanceAfter,
String referenceId = '',
DateTime? date,
String notes = '',
}) async {
final normalizedBusinessId =
businessId.trim();
final normalizedCustomerId =
customerId.trim();
final normalizedCustomerName =
customerName.trim();
final normalizedTransactionType =
transactionType.trim();


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

if (normalizedCustomerName.isEmpty) {
  throw ArgumentError(
    'Customer name cannot be empty.',
  );
}

if (normalizedTransactionType.isEmpty) {
  throw ArgumentError(
    'Transaction type cannot be empty.',
  );
}

if (!amount.isFinite || amount <= 0) {
  throw ArgumentError(
    'Amount must be greater than zero.',
  );
}

if (!balanceBefore.isFinite) {
  throw ArgumentError(
    'Balance before must be a valid number.',
  );
}

if (!balanceAfter.isFinite) {
  throw ArgumentError(
    'Balance after must be a valid number.',
  );
}

final now = DateTime.now();

final transaction =
    LedgerTransactionModel(
  id: '',
  businessId:
      normalizedBusinessId,
  customerId:
      normalizedCustomerId,
  customerName:
      normalizedCustomerName,
  transactionType:
      normalizedTransactionType,
  amount: amount,
  balanceBefore:
      balanceBefore,
  balanceAfter:
      balanceAfter,
  referenceId:
      referenceId.trim(),
  date: date ?? now,
  notes: notes.trim(),
  createdAt: now,
);

return _repository.createTransaction(
  transaction,
);

}

Future<LedgerTransactionModel?> getTransaction({
required String businessId,
required String transactionId,
}) {
return _repository.getTransaction(
businessId: businessId,
transactionId: transactionId,
);
}

Future<List<LedgerTransactionModel>>
getTransactions({
required String businessId,
}) {
return _repository.getTransactions(
businessId: businessId,
);
}

Stream<List<LedgerTransactionModel>>
watchTransactions({
required String businessId,
}) {
return _repository.watchTransactions(
businessId: businessId,
);
}

Future<List<LedgerTransactionModel>>
getCustomerTransactions({
required String businessId,
required String customerId,
}) {
return _repository.getCustomerTransactions(
businessId: businessId,
customerId: customerId,
);
}

Stream<List<LedgerTransactionModel>>
watchCustomerTransactions({
required String businessId,
required String customerId,
}) {
return _repository
.watchCustomerTransactions(
businessId: businessId,
customerId: customerId,
);
}

Future<List<LedgerTransactionModel>>
getTransactionsByType({
required String businessId,
required String transactionType,
}) {
return _repository.getTransactionsByType(
businessId: businessId,
transactionType: transactionType,
);
}

Future<void> updateTransaction(
LedgerTransactionModel transaction,
) {
return _repository.updateTransaction(
transaction,
);
}

Future<void> deleteTransaction({
required String businessId,
required String transactionId,
}) {
return _repository.deleteTransaction(
businessId: businessId,
transactionId: transactionId,
);
}

Future<double> getCustomerBalance({
required String businessId,
required String customerId,
}) {
return _repository.getCustomerBalance(
businessId: businessId,
customerId: customerId,
);
}

Future<double> getTotalReceivable({
required String businessId,
}) {
return _repository.getTotalReceivable(
businessId: businessId,
);
}

Future<List<LedgerTransactionModel>>
searchTransactions({
required String businessId,
required String query,
}) {
return _repository.searchTransactions(
businessId: businessId,
query: query,
);
}
}
