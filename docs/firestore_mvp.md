## Firestore MVP Structure

Collections used by the AVISHU MVP:

- `users/{userId}`
- `products/{productId}`
- `orders/{orderId}`
- `orders/{orderId}/items/{itemId}`
- `orders/{orderId}/history/{historyId}`

### Orders

The main order document stores:

- identifiers and routing fields: `id`, `orderNumber`, `clientId`, `franchiseeId`
- workflow fields: `status`, `priority`, `estimatedReadyAt`, `acceptedAt`, `completedAt`, `lastStatusChangedAt`
- payment and fulfillment fields: `paymentStatus`, `fulfillmentType`, `totalAmount`, `currency`
- lightweight compatibility fields used by the current UI

### Items

Each order item stores:

- product reference data
- size and quantity
- price snapshot
- preorder flag
- per-item ETA
- product image

### History

Each status change writes a history record with:

- `fromStatus`
- `toStatus`
- `changedByUserId`
- `changedByRole`
- `comment`
- `createdAt`

## Status Flow

Allowed transitions:

- `new -> accepted`
- `accepted -> in_production`
- `in_production -> ready`
- `ready -> completed`
- `new -> cancelled`
- `accepted -> cancelled`
- `in_production -> cancelled`

## ETA And Priority

- ETA is computed from `products.defaultProductionDays` when possible
- preorder items default to high priority
- comments containing urgent markers such as `urgent`, `asap`, or `сроч` also become high priority

## Seed Demo Data

Run the demo seed app with:

```bash
flutter run -t tool/seed_demo_data.dart -d windows
```

This seeds:

- 4 users
- 5 products
- 3 demo orders

The seed window prints the demo credentials after completion.
