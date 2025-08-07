# PluginForge

A decentralized SaaS plugin marketplace built on Stacks blockchain, enabling developers to monetize Web3 plugins through flexible subscription models.

## Overview

PluginForge is a smart contract-powered marketplace that allows developers to publish, monetize, and distribute plugins for Web3 applications. Users can subscribe to plugins using either monthly subscriptions or pay-per-use credits, with all transactions handled transparently on-chain.

## Features

### For Developers
- **Plugin Registration**: Register plugins with metadata stored on IPFS
- **Flexible Pricing**: Support for both monthly subscriptions and pay-per-use models
- **Revenue Tracking**: Real-time tracking of installs and earnings
- **Earnings Withdrawal**: Direct withdrawal of earnings to developer wallets
- **Plugin Management**: Update plugin details, pricing, and availability

### For Users
- **Multiple Payment Options**: Choose between monthly subscriptions or pay-per-use credits
- **Usage Verification**: On-chain verification of plugin access rights
- **Plugin Reviews**: Rate and review plugins (1-5 stars)
- **Transparent Pricing**: Clear pricing with marketplace fees disclosed

### Platform Features
- **Decentralized Storage**: Plugin code and metadata stored on IPFS
- **Automated Revenue Distribution**: Smart contract handles payment splits
- **Plugin Categories**: Organized by categories (analytics, KYC, subscriptions, etc.)
- **Usage Analytics**: Track total installs and revenue per plugin

## Smart Contract Functions

### Read-Only Functions
- `get-plugin(plugin-id)` - Retrieve plugin information
- `get-subscription(user, plugin-id)` - Get user's subscription details
- `get-plugin-review(plugin-id, reviewer)` - Get specific plugin review
- `get-developer-earnings(developer)` - Check developer's earnings
- `can-use-plugin(user, plugin-id)` - Verify if user can access plugin

### Public Functions

#### Plugin Management
- `register-plugin()` - Register a new plugin
- `update-plugin()` - Update plugin details (developer only)

#### Subscriptions & Payments
- `subscribe-monthly(plugin-id)` - Subscribe to a plugin monthly
- `buy-usage-credits(plugin-id, num-uses)` - Purchase pay-per-use credits
- `use-plugin(plugin-id)` - Use a plugin (decrements credits/checks subscription)

#### Reviews & Earnings
- `review-plugin(plugin-id, rating, review)` - Leave a plugin review
- `withdraw-earnings()` - Withdraw developer earnings

#### Admin Functions
- `set-marketplace-fee(new-fee-percent)` - Update marketplace fee (owner only)

## Plugin Data Structure

Each plugin contains:
- Developer principal address
- Name and description
- Category classification
- Pricing (per-use and monthly)
- Install and revenue statistics
- IPFS hash for code/metadata
- Active status

## Subscription Models

### Monthly Subscription
- Fixed monthly fee
- Unlimited usage during subscription period
- 30-day subscription period (~4,320 blocks)

### Pay-Per-Use
- Purchase specific number of uses
- Each plugin usage decrements credit count
- No expiration on unused credits

## Fee Structure

- Default marketplace fee: 2.5% (250 basis points)
- Maximum allowed fee: 10% (1,000 basis points)
- Fees automatically deducted from payments
- Remaining amount goes to plugin developer

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to Stacks blockchain (mainnet or testnet)

### For Developers

1. **Register Your Plugin**:
   ```clarity
   (register-plugin "my-plugin-id" "My Plugin" "Plugin description" 
                    "analytics" u1000 u50000 "QmHashToIPFS...")
   ```

2. **Upload Plugin Code**: Store your plugin code and metadata on IPFS

3. **Set Pricing**: Configure per-use and monthly pricing

4. **Monitor Performance**: Track installs and revenue through read-only functions

### For Users

1. **Browse Plugins**: Use read-only functions to explore available plugins

2. **Subscribe or Buy Credits**:
   ```clarity
   ;; Monthly subscription
   (subscribe-monthly "plugin-id")
   
   ;; Or buy 10 uses
   (buy-usage-credits "plugin-id" u10)
   ```

3. **Use Plugins**: Call `use-plugin` when accessing plugin functionality

4. **Leave Reviews**: Share feedback after using plugins

## Technical Details

- **Blockchain**: Stacks
- **Language**: Clarity
- **Storage**: IPFS for plugin metadata and code
- **Token**: STX for all payments

## Error Codes

- `u100`: Owner only action
- `u101`: Plugin not found
- `u102`: Unauthorized access
- `u103`: Insufficient payment
- `u104`: Plugin already exists
- `u105`: Invalid rating (must be 1-5)
- `u106`: Fee percentage too high (max 10%)

## Security Considerations

- All payments are handled atomically by the smart contract
- Plugin developers can only modify their own plugins
- Users must have valid subscriptions or credits to use plugins
- Marketplace fees are capped at 10%
- Contract ownership is immutable (set at deployment)

## Contributing

This is an open-source project. Contributions are welcome for:
- Frontend interface development
- Plugin template creation
- Integration tools
- Documentation improvements
