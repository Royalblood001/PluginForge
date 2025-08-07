;; Decentralized SaaS Plugin Marketplace
;; A simple marketplace for Web3 plugins built on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-plugin-exists (err u104))

;; Data Variables
(define-data-var marketplace-fee-percent uint u250) ;; 2.5% fee (250 basis points)

;; Data Maps
(define-map plugins 
  { plugin-id: (string-ascii 64) }
  {
    developer: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    category: (string-ascii 32), ;; "analytics", "kyc", "subscriptions", etc.
    price-per-use: uint,
    monthly-price: uint,
    total-installs: uint,
    total-revenue: uint,
    active: bool,
    ipfs-hash: (string-ascii 64) ;; Points to plugin code/metadata
  }
)

(define-map plugin-subscriptions
  { user: principal, plugin-id: (string-ascii 64) }
  {
    subscription-type: (string-ascii 16), ;; "monthly" or "pay-per-use"
    expires-at: uint,
    uses-remaining: uint,
    total-paid: uint
  }
)

(define-map plugin-reviews
  { plugin-id: (string-ascii 64), reviewer: principal }
  {
    rating: uint, ;; 1-5 stars
    review: (string-utf8 500),
    block-height: uint
  }
)

(define-map developer-earnings principal uint)

;; Read-only functions
(define-read-only (get-plugin (plugin-id (string-ascii 64)))
  (map-get? plugins { plugin-id: plugin-id })
)

(define-read-only (get-subscription (user principal) (plugin-id (string-ascii 64)))
  (map-get? plugin-subscriptions { user: user, plugin-id: plugin-id })
)

(define-read-only (get-plugin-review (plugin-id (string-ascii 64)) (reviewer principal))
  (map-get? plugin-reviews { plugin-id: plugin-id, reviewer: reviewer })
)

(define-read-only (get-developer-earnings (developer principal))
  (default-to u0 (map-get? developer-earnings developer))
)

(define-read-only (can-use-plugin (user principal) (plugin-id (string-ascii 64)))
  (let (
    (subscription (get-subscription user plugin-id))
  )
    (match subscription
      sub-data 
        (or 
          (> (get uses-remaining sub-data) u0)
          (> (get expires-at sub-data) block-height)
        )
      false
    )
  )
)

;; Public functions

;; Register a new plugin
(define-public (register-plugin 
    (plugin-id (string-ascii 64))
    (name (string-utf8 100))
    (description (string-utf8 500))
    (category (string-ascii 32))
    (price-per-use uint)
    (monthly-price uint)
    (ipfs-hash (string-ascii 64))
  )
  (let (
    (existing-plugin (get-plugin plugin-id))
  )
    (asserts! (is-none existing-plugin) err-plugin-exists)
    (ok (map-set plugins 
      { plugin-id: plugin-id }
      {
        developer: tx-sender,
        name: name,
        description: description,
        category: category,
        price-per-use: price-per-use,
        monthly-price: monthly-price,
        total-installs: u0,
        total-revenue: u0,
        active: true,
        ipfs-hash: ipfs-hash
      }
    ))
  )
)

;; Subscribe to a plugin (monthly)
(define-public (subscribe-monthly (plugin-id (string-ascii 64)))
  (let (
    (plugin (unwrap! (get-plugin plugin-id) err-not-found))
    (monthly-price (get monthly-price plugin))
    (marketplace-fee (/ (* monthly-price (var-get marketplace-fee-percent)) u10000))
    (developer-payment (- monthly-price marketplace-fee))
  )
    (asserts! (get active plugin) err-not-found)
    (try! (stx-transfer? monthly-price tx-sender (as-contract tx-sender)))
    
    ;; Update plugin stats
    (map-set plugins 
      { plugin-id: plugin-id }
      (merge plugin {
        total-installs: (+ (get total-installs plugin) u1),
        total-revenue: (+ (get total-revenue plugin) monthly-price)
      })
    )
    
    ;; Create subscription
    (map-set plugin-subscriptions
      { user: tx-sender, plugin-id: plugin-id }
      {
        subscription-type: "monthly",
        expires-at: (+ block-height u4320), ;; ~30 days (144 blocks/day)
        uses-remaining: u0,
        total-paid: monthly-price
      }
    )
    
    ;; Pay developer
    (map-set developer-earnings 
      (get developer plugin)
      (+ (get-developer-earnings (get developer plugin)) developer-payment)
    )
    
    (ok true)
  )
)

;; Buy pay-per-use credits
(define-public (buy-usage-credits (plugin-id (string-ascii 64)) (num-uses uint))
  (let (
    (plugin (unwrap! (get-plugin plugin-id) err-not-found))
    (total-cost (* (get price-per-use plugin) num-uses))
    (marketplace-fee (/ (* total-cost (var-get marketplace-fee-percent)) u10000))
    (developer-payment (- total-cost marketplace-fee))
  )
    (asserts! (get active plugin) err-not-found)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Update plugin stats
    (map-set plugins 
      { plugin-id: plugin-id }
      (merge plugin {
        total-installs: (+ (get total-installs plugin) u1),
        total-revenue: (+ (get total-revenue plugin) total-cost)
      })
    )
    
    ;; Update or create subscription
    (let (
      (existing-sub (get-subscription tx-sender plugin-id))
    )
      (match existing-sub
        sub-data
          (map-set plugin-subscriptions
            { user: tx-sender, plugin-id: plugin-id }
            (merge sub-data {
              uses-remaining: (+ (get uses-remaining sub-data) num-uses),
              total-paid: (+ (get total-paid sub-data) total-cost)
            })
          )
        (map-set plugin-subscriptions
          { user: tx-sender, plugin-id: plugin-id }
          {
            subscription-type: "pay-per-use",
            expires-at: u0,
            uses-remaining: num-uses,
            total-paid: total-cost
          }
        )
      )
    )
    
    ;; Pay developer
    (map-set developer-earnings 
      (get developer plugin)
      (+ (get-developer-earnings (get developer plugin)) developer-payment)
    )
    
    (ok true)
  )
)

;; Use a plugin (decrements usage or checks subscription)
(define-public (use-plugin (plugin-id (string-ascii 64)))
  (let (
    (plugin (unwrap! (get-plugin plugin-id) err-not-found))
    (subscription (unwrap! (get-subscription tx-sender plugin-id) err-unauthorized))
  )
    (asserts! (get active plugin) err-not-found)
    
    ;; Check if user can use the plugin
    (if (is-eq (get subscription-type subscription) "pay-per-use")
      (begin
        (asserts! (> (get uses-remaining subscription) u0) err-unauthorized)
        (map-set plugin-subscriptions
          { user: tx-sender, plugin-id: plugin-id }
          (merge subscription {
            uses-remaining: (- (get uses-remaining subscription) u1)
          })
        )
      )
      (asserts! (> (get expires-at subscription) block-height) err-unauthorized)
    )
    
    (ok true)
  )
)

;; Leave a review for a plugin
(define-public (review-plugin 
    (plugin-id (string-ascii 64))
    (rating uint)
    (review (string-utf8 500))
  )
  (let (
    (plugin (unwrap! (get-plugin plugin-id) err-not-found))
  )
    (asserts! (and (>= rating u1) (<= rating u5)) (err u105))
    (asserts! (can-use-plugin tx-sender plugin-id) err-unauthorized)
    
    (ok (map-set plugin-reviews
      { plugin-id: plugin-id, reviewer: tx-sender }
      {
        rating: rating,
        review: review,
        block-height: block-height
      }
    ))
  )
)

;; Developer withdraws earnings
(define-public (withdraw-earnings)
  (let (
    (earnings (get-developer-earnings tx-sender))
  )
    (asserts! (> earnings u0) err-not-found)
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    (map-set developer-earnings tx-sender u0)
    (ok earnings)
  )
)

;; Update plugin (only by developer)
(define-public (update-plugin 
    (plugin-id (string-ascii 64))
    (name (string-utf8 100))
    (description (string-utf8 500))
    (price-per-use uint)
    (monthly-price uint)
    (ipfs-hash (string-ascii 64))
    (active bool)
  )
  (let (
    (plugin (unwrap! (get-plugin plugin-id) err-not-found))
  )
    (asserts! (is-eq (get developer plugin) tx-sender) err-unauthorized)
    
    (ok (map-set plugins 
      { plugin-id: plugin-id }
      (merge plugin {
        name: name,
        description: description,
        price-per-use: price-per-use,
        monthly-price: monthly-price,
        ipfs-hash: ipfs-hash,
        active: active
      })
    ))
  )
)

;; Admin functions (contract owner only)
(define-public (set-marketplace-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percent u1000) (err u106)) ;; Max 10%
    (ok (var-set marketplace-fee-percent new-fee-percent))
  )
)