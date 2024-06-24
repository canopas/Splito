//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Nirali Sonani on 24/06/24.
//

import Data
import Combine

public func calculateExpensesSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var ownAmounts: [String: Double] = [:]
    var memberOwingAmount: [String: Double] = [:]

    for expense in expenses {
        ownAmounts[expense.paidBy, default: 0.0] += expense.amount
        let splitAmount = expense.amount / Double(expense.splitTo.count)

        for member in expense.splitTo {
            ownAmounts[member, default: 0.0] -= splitAmount
        }
    }

    let debts = settleDebts(users: ownAmounts)
    for debt in debts where debt.0 == userId || debt.1 == userId {
        memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
    }

    for transaction in transactions {
        let payer = transaction.payerId
        let receiver = transaction.receiverId
        let amount = transaction.amount

        if payer == userId, let currentAmount = memberOwingAmount[receiver] {
            memberOwingAmount[receiver] = currentAmount + amount
        } else if receiver == userId, let currentAmount = memberOwingAmount[payer] {
            memberOwingAmount[payer] = currentAmount - amount
        }
    }

    return memberOwingAmount.filter { $0.value != 0 }
}

public func calculateExpensesNonSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var expenseByUser = 0.0
    var owesToUser: [String: Double] = [:]
    var owedByUser: [String: Double] = [:]

    for expense in expenses {
        let splitAmount = expense.amount / Double(expense.splitTo.count)
        if expense.paidBy == userId {
            expenseByUser += expense.splitTo.contains(userId) ? expense.amount - splitAmount : expense.amount
            for member in expense.splitTo where member != userId {
                owesToUser[member, default: 0.0] += splitAmount
            }
        } else if expense.splitTo.contains(where: { $0 == userId }) {
            expenseByUser -= splitAmount
            owedByUser[expense.paidBy, default: 0.0] += splitAmount
        }
    }

    let memberOwingAmount = processTransactions(userId: userId, transactions: transactions, owesToUser: owesToUser, owedByUser: owedByUser)

    return memberOwingAmount.filter { $0.value != 0 }
}

public func processTransactions(userId: String, transactions: [Transactions], owesToUser: [String: Double], owedByUser: [String: Double]) -> ([String: Double]) {

    var owesToUser: [String: Double] = owesToUser
    var owedByUser: [String: Double] = owedByUser
    var memberOwingAmount: [String: Double] = [:]

    for transaction in transactions {
        let payer = transaction.payerId
        let receiver = transaction.receiverId
        let amount = transaction.amount

        if transaction.payerId == userId {
            if owedByUser[receiver] != nil {
                owesToUser[transaction.receiverId, default: 0.0] += amount
            } else {
                owedByUser[transaction.payerId, default: 0.0] -= amount
            }
        } else if transaction.receiverId == userId {
            if owesToUser[payer] != nil {
                owedByUser[transaction.payerId, default: 0.0] += amount
            } else {
                owesToUser[payer] = -amount
            }
        }
    }

    owesToUser.forEach { payerId, owesAmount in
        memberOwingAmount[payerId, default: 0.0] += owesAmount
    }
    owedByUser.forEach { receiverId, owedAmount in
        memberOwingAmount[receiverId, default: 0.0] -= owedAmount
    }

    return memberOwingAmount
}

public func settleDebts(users: [String: Double]) -> [(String, String, Double)] {
    var mutableUsers = users
    var debts: [(String, String, Double)] = []
    let positiveAmounts = mutableUsers.filter { $0.value > 0 }
    let negativeAmounts = mutableUsers.filter { $0.value < 0 }

    for (creditor, creditAmount) in positiveAmounts {
        var remainingCredit = creditAmount

        for (debtor, debtAmount) in negativeAmounts {
            if remainingCredit == 0 { break }
            let amountToSettle = min(remainingCredit, -debtAmount)

            if amountToSettle > 0 {
                debts.append((debtor, creditor, amountToSettle))
                remainingCredit -= amountToSettle
                mutableUsers[debtor]! += amountToSettle
                mutableUsers[creditor]! -= amountToSettle
            }
        }
    }

    return debts
}
