// Struktur Database Firestore untuk Orient Event Organizer App

/*
Firestore Collections Structure:

1. users/
   - {userId}/
     - uid: string
     - email: string
     - username: string
     - profileImageUrl: string?
     - createdAt: timestamp
     - friends: array<string> (array of user IDs)

2. events/
   - {eventId}/
     - eventId: string
     - eventName: string
     - eventDate: timestamp
     - eventType: string
     - description: string
     - ownerId: string
     - collaborators: array<string> (array of user IDs)
     - createdAt: timestamp
     - updatedAt: timestamp

3. tasks/
   - {taskId}/
     - taskId: string
     - eventId: string (reference to event)
     - name: string
     - category: string (predefined or custom)
     - dueDate: timestamp
     - status: string (completed/pending)
     - note: string?
     - imageUrls: array<string>?
     - createdBy: string (userId)
     - createdAt: timestamp
     - updatedAt: timestamp

4. budgets/
   - {budgetId}/
     - budgetId: string
     - eventId: string
     - itemName: string
     - category: string
     - totalCost: number
     - paidAmount: number
     - unpaidAmount: number
     - note: string?
     - imageUrls: array<string>?
     - payments: array<map> [
         {
           paymentId: string
           amount: number
           date: timestamp
           note: string?
         }
       ]
     - lastUpdated: timestamp
     - createdAt: timestamp

5. guests/
   - {guestId}/
     - guestId: string
     - name: string
     - gender: string
     - ageStatus: string (adult/child/baby)
     - group: string (family/friend/vendor/speaker/etc)
     - phoneNumber: string?
     - email: string?
     - address: string?
     - note: string?
     - createdBy: string (userId)
     - createdAt: timestamp
     - eventInvitations: array<map> [
         {
           eventId: string
           tableName: string?
           menu: string?
           invitationStatus: string (sent/not_sent/pending/accepted/denied)
         }
       ]

6. vendors/
   - {vendorId}/
     - vendorId: string
     - eventId: string
     - vendorName: string
     - category: string
     - phoneNumber: string?
     - email: string?
     - website: string?
     - address: string?
     - totalCost: number
     - paidAmount: number
     - pendingAmount: number
     - agreementStatus: string (accepted/pending/rejected)
     - addToBudget: boolean
     - note: string?
     - payments: array<map> [similar to budgets]
     - listName: string? (for categorization)
     - createdBy: string (userId)
     - createdAt: timestamp
     - lastUpdated: timestamp

7. categories/
   - {categoryId}/
     - categoryId: string
     - categoryName: string
     - type: string (task/budget/vendor)
     - isPredefined: boolean
     - createdBy: string? (null if predefined)
     - createdAt: timestamp

Predefined Categories:
- Attire & Accessories
- Health & Beauty
- Music & Show
- Flowers & Decors
- Photo & Video
- Transportation
- Accommodation

8. chats/
   - {chatId}/
     - chatId: string (format: smaller_userId_larger_userId)
     - participants: array<string> [userId1, userId2]
     - participantDetails: map {
         userId1: {
           username: string
           profileImageUrl: string?
         },
         userId2: {
           username: string
           profileImageUrl: string?
         }
       }
     - lastMessage: string
     - lastMessageTime: timestamp
     - lastMessageSender: string (userId)
     - createdAt: timestamp
     - updatedAt: timestamp

9. messages/ {
  messageId: {
    chatId: string,
    senderId: string,
    receiverId: string,
    encryptedMessage: string,
    iv: string,
    timestamp: timestamp,
    isRead: boolean
  }
}
*/