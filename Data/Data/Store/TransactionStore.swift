//
//  TransactionStore.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import Combine
import FirebaseFirestoreInternal

public class TransactionStore: ObservableObject {

    @Inject private var database: Firestore

    private let COLLECTION_NAME: String = "transactions"

    func addTransaction(transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                _ = try self.database.collection(self.COLLECTION_NAME).addDocument(from: transaction)
                promise(.success(()))
            } catch {
                LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateTransaction(transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let transactionId = transaction.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.database.collection(self.COLLECTION_NAME).document(transactionId).setData(from: transaction, merge: false)
                promise(.success(()))
            } catch {
                LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func fetchLatestTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        database.collection(COLLECTION_NAME)
            .whereField("group_id", isEqualTo: groupId)
            .limit(to: 20)
            .snapshotPublisher(as: Transactions.self)
    }

    func fetchTransactionsBy(userId: String) -> AnyPublisher<[Transactions], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME).whereField("payer_id", isEqualTo: userId).getDocuments { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
                    return
                }

                guard let snapshot else {
                    LogE("TransactionStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let transactions = try snapshot.documents.compactMap { document in
                        try document.data(as: Transactions.self)
                    }
                    promise(.success(transactions))
                } catch {
                    LogE("TransactionStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME).whereField("group_id", isEqualTo: groupId).addSnapshotListener { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("TransactionStore :: \(#function) The document is not available.")
                    promise(.success([]))
                    return
                }

                do {
                    let transactions = try snapshot.documents.compactMap { document in
                        try document.data(as: Transactions.self)
                    }
                    promise(.success(transactions))
                } catch {
                    LogE("TransactionStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteTransactionsOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME).whereField("group_id", isEqualTo: groupId).getDocuments { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("TransactionStore :: \(#function) The document is not available.")
                    promise(.success(()))
                    return
                }

                let batch = self.database.batch()
                snapshot.documents.forEach { batch.deleteDocument($0.reference) }

                batch.commit { error in
                    if let error {
                        promise(.failure(.databaseError))
                        LogE("TransactionStore :: \(#function) Database error: \(error.localizedDescription)")
                    } else {
                        promise(.success(()))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
