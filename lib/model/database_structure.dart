/*

1. users/
uid: string
email: string
username: string
profileImageUrl: string?
bio: string
phone: string
friends: array<userId>
blockedUsers: array<userId>
createdAt: timestamp
updatedAt: timestamp
lastActiveAt: timestamp?
hasCompletedOnboarding: boolean
isNewUser: boolean
notificationsEnabled: boolean
firstEventId: string?
searchKeywords: array<string>
isVerified: boolean
status: string

2. events/
eventId: string
eventName: string
eventDate: timestamp
eventType: string
eventLocation: string
description: string
budget: number
ownerId: string
collaborators: array<userId>
eventStatus: string
createdAt: timestamp
updatedAt: timestamp
isDeleted: boolean

3. events/{eventId}/tasks/
taskId: string
eventId: string
name: string
category: string
dueDate: timestamp
status: string
priority: string
note: string?
budget: number?
imageUrls: array<string>?
assignedTo: array<userId>
createdBy: string
createdAt: timestamp
updatedAt: timestamp
isDeleted: boolean

4. events/{eventId}/budgets/
budgetId: string
eventId: string
itemName: string
category: string
totalCost: number
paidAmount: number
unpaidAmount: number
note: string?
linkedVendors: array<{vendorId: string, vendorName: string, category: string, contribution: number, linkedAt: timestamp}>
payments: array<{paymentId: string, amount: number, date: timestamp, paidBy: string, note: string?}>
createdBy: string
createdAt: timestamp
lastUpdated: timestamp
isDeleted: boolean

5. events/{eventId}/guests/
guestId: string
eventId: string
name: string
gender: string
ageStatus: string
group: string
phoneNumber: string?
email: string?
address: string?
note: string?
status: string
eventInvitations: array<{eventId: string, tableName: string?, menu: string?, invitationStatus: string, sentAt: timestamp?, respondedAt: timestamp?}>
createdBy: string
createdAt: timestamp
updatedAt: timestamp?
isDeleted: boolean

6. events/{eventId}/vendors/
vendorId: string
eventId: string
vendorName: string
category: string
phoneNumber: string?
email: string?
website: string?
address: string?
totalCost: number
paidAmount: number
pendingAmount: number
agreementStatus: string
addToBudget: boolean
linkedBudgetId: string?
note: string?
payments: array<{paymentId: string, amount: number, date: timestamp, paidBy: string, note: string?}>
listName: string?
createdBy: string
createdAt: timestamp
lastUpdated: timestamp
isDeleted: boolean

7. chats/
chatId: string
participants: array<userId>
participantDetails: map<userId, {uid: string, username: string, displayName: string, profileImageUrl: string?}>
lastMessage: string
lastMessageTime: timestamp
lastMessageSender: string
unreadCounts: map<userId, number>
createdAt: timestamp
updatedAt: timestamp

8. chats/{chatId}/messages/
messageId: string
chatId: string
senderId: string
receiverId: string
encryptedMessage: string
iv: string
timestamp: timestamp
isRead: boolean
readAt: timestamp?
isDeleted: boolean

9. notifications/{userId}/
notificationId: string
userId: string
title: string
message: string
type: string
relatedId: string?
actionUrl: string?
isRead: boolean
readAt: timestamp?
isAutoDeleted: boolean
createdAt: timestamp
expiresAt: timestamp?

10. categories/
categoryId: string
categoryName: string
type: string
isPredefined: boolean
icon: string?
color: string?
createdBy: string?
createdAt: timestamp
 */