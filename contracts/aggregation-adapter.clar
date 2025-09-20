;; aggregation-adapter
;; Bank connection and transaction normalization
;; No cross-contract calls or trait usage

(define-constant ERR-NOT-FOUND u100)
(define-constant ERR-NOT-AUTHORIZED u101)
(define-constant ERR-INVALID u102)
(define-constant ERR-ALREADY-NORMALIZED u103)

;; Sequential identifiers
(define-data-var next-bank-id uint u1)
(define-data-var next-account-id uint u1)
(define-data-var next-tx-id uint u1)

;; bank-id => { name, owner }
(define-map bank-registry (tuple (bank-id uint)) (tuple (name (string-ascii 64)) (owner principal)))

;; account-id => { bank-id, owner, label, currency }
(define-map accounts (tuple (account-id uint)) (tuple (bank-id uint) (owner principal) (label (string-ascii 64)) (currency (string-ascii 8))))

;; tx-id => { account-id, amount, timestamp, merchant, category, normalized }
(define-map transactions (tuple (tx-id uint)) (tuple (account-id uint) (amount int) (timestamp uint) (merchant (string-ascii 64)) (category (string-ascii 32)) (normalized bool)))

;; =============
;; helpers
;; =============

(define-read-only (is-owner (who principal) (principal-owner principal))
  (ok (is-eq who principal-owner)))

(define-read-only (str-non-empty (s (string-ascii 128)))
  (ok (> (len s) u0)))

(define-read-only (bank-exists (bank-id uint))
  (ok (is-some (map-get? bank-registry { bank-id: bank-id }))))

(define-read-only (account-exists (account-id uint))
  (ok (is-some (map-get? accounts { account-id: account-id }))))

(define-read-only (tx-exists (tx-id uint))
  (ok (is-some (map-get? transactions { tx-id: tx-id }))))

;; =============
;; public interface
;; =============

(define-public (register-bank (name (string-ascii 64)))
  (begin
    (if (not (unwrap! (str-non-empty name) (err ERR-INVALID)))
        (err ERR-INVALID)
        (let ((id (var-get next-bank-id)))
          (var-set next-bank-id (+ id u1))
          (map-insert bank-registry { bank-id: id }
            { name: name, owner: tx-sender })
          (ok id)))))

(define-public (open-account (bank-id uint) (label (string-ascii 64)) (currency (string-ascii 8)))
  (begin
    (if (not (unwrap! (bank-exists bank-id) (err ERR-NOT-FOUND)))
        (err ERR-NOT-FOUND)
        (if (and (> (len label) u0) (> (len currency) u0))
            (let ((id (var-get next-account-id)))
              (var-set next-account-id (+ id u1))
              (map-insert accounts { account-id: id }
                { bank-id: bank-id,
                  owner: tx-sender,
                  label: label,
                  currency: currency })
              (ok id))
            (err ERR-INVALID)))))

(define-public (record-transaction
    (account-id uint)
    (amount int)
    (timestamp uint)
    (merchant (string-ascii 64))
    (category (string-ascii 32)))
  (begin
    (match (map-get? accounts { account-id: account-id }) account
      (let ((owner (get owner account)))
        (if (not (unwrap! (is-owner tx-sender owner) (err ERR-NOT-AUTHORIZED)))
            (err ERR-NOT-AUTHORIZED)
            (if (and (not (is-eq amount 0)) (> (len merchant) u0))
                (let ((id (var-get next-tx-id)))
                  (var-set next-tx-id (+ id u1))
                  (map-insert transactions { tx-id: id }
                    { account-id: account-id,
                      amount: amount,
                      timestamp: timestamp,
                      merchant: merchant,
                      category: category,
                      normalized: false })
                  (ok id))
                (err ERR-INVALID))))
      (err ERR-NOT-FOUND))))

(define-public (set-category (tx-id uint) (category (string-ascii 32)))
  (begin
    (match (map-get? transactions { tx-id: tx-id }) tx
      (let ((acct-id (get account-id tx)))
        (match (map-get? accounts { account-id: acct-id }) acct
          (let ((owner (get owner acct)))
            (if (not (unwrap! (is-owner tx-sender owner) (err ERR-NOT-AUTHORIZED)))
                (err ERR-NOT-AUTHORIZED)
                (if (> (len category) u0)
                    (begin
                      (map-set transactions { tx-id: tx-id }
                        { account-id: (get account-id tx),
                          amount: (get amount tx),
                          timestamp: (get timestamp tx),
                          merchant: (get merchant tx),
                          category: category,
                          normalized: (get normalized tx) })
                      (ok true))
                    (err ERR-INVALID))))
          (err ERR-NOT-FOUND)))
      (err ERR-NOT-FOUND))))

(define-public (normalize-transaction (tx-id uint))
  (begin
    (match (map-get? transactions { tx-id: tx-id }) tx
      (let ((already (get normalized tx))
            (cat (get category tx))
            (amt (get amount tx)))
        (if already
            (err ERR-ALREADY-NORMALIZED)
            (if (and (> (len cat) u0) (not (is-eq amt 0)))
                (begin
                  (map-set transactions { tx-id: tx-id }
                    { account-id: (get account-id tx),
                      amount: amt,
                      timestamp: (get timestamp tx),
                      merchant: (get merchant tx),
                      category: cat,
                      normalized: true })
                  (ok true))
                (err ERR-INVALID))))
      (err ERR-NOT-FOUND))))

;; =============
;; read-only getters
;; =============

(define-read-only (get-bank (bank-id uint))
  (match (map-get? bank-registry { bank-id: bank-id }) bank
    (ok bank)
    (err ERR-NOT-FOUND)))

(define-read-only (get-account (account-id uint))
  (match (map-get? accounts { account-id: account-id }) acct
    (ok acct)
    (err ERR-NOT-FOUND)))

(define-read-only (get-transaction (tx-id uint))
  (match (map-get? transactions { tx-id: tx-id }) tx
    (ok tx)
    (err ERR-NOT-FOUND)))
