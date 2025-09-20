;; advice-engine
;; Goals, alerts, and simple recommendations
;; No cross-contract calls or trait usage

(define-constant ERR-NOT-FOUND u200)
(define-constant ERR-NOT-AUTHORIZED u201)
(define-constant ERR-INVALID u202)
(define-constant ERR-INACTIVE u203)

(define-data-var next-goal-id uint u1)
(define-data-var next-alert-id uint u1)

;; goal-id => { owner, label, target, current, deadline, created, active }
(define-map goals
  (tuple (goal-id uint))
  (tuple (owner principal)
         (label (string-ascii 64))
         (target uint)
         (current uint)
         (deadline uint)
         (created uint)
         (active bool)))

;; alert-id => { owner, goal-id, kind, message, created }
(define-map alerts
  (tuple (alert-id uint))
  (tuple (owner principal)
         (goal-id uint)
         (kind (string-ascii 32))
         (message (string-ascii 128))
         (created uint)))

;; ======== helpers ========

(define-read-only (now) u0)

(define-read-only (str-non-empty (s (string-ascii 128)))
  (ok (> (len s) u0)))

(define-private (mk-alert (owner principal) (goal-id uint) (kind (string-ascii 32)) (message (string-ascii 128)))
  (let ((id (var-get next-alert-id)))
    (var-set next-alert-id (+ id u1))
    (map-insert alerts { alert-id: id }
      { owner: owner,
        goal-id: goal-id,
        kind: kind,
        message: message,
        created: (now) })
    (ok id)))
;; ======== public interface ========

(define-public (create-goal (label (string-ascii 64)) (target uint) (deadline uint))
  (begin
    (if (not (unwrap! (str-non-empty label) (err ERR-INVALID)))
        (err ERR-INVALID)
        (if (is-eq target u0)
            (err ERR-INVALID)
            (let ((id (var-get next-goal-id))
                  (created (now)))
              (var-set next-goal-id (+ id u1))
              (map-insert goals { goal-id: id }
                { owner: tx-sender,
                  label: label,
                  target: target,
                  current: u0,
                  deadline: deadline,
                  created: created,
                  active: true })
              (ok id))))))

(define-public (contribute (goal-id uint) (amount uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (let ((owner (get owner g))
          (active (get active g))
          (cur (get current g)))
      (if (not (is-eq owner tx-sender))
          (err ERR-NOT-AUTHORIZED)
          (if (or (is-eq amount u0) (not active))
              (err (if (is-eq amount u0) ERR-INVALID ERR-INACTIVE))
              (begin
                (map-set goals { goal-id: goal-id }
                  { owner: owner,
                    label: (get label g),
                    target: (get target g),
                    current: (+ cur amount),
                    deadline: (get deadline g),
                    created: (get created g),
                    active: active })
                (ok true)))))
    (err ERR-NOT-FOUND)))

(define-public (deactivate-goal (goal-id uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (let ((owner (get owner g)))
      (if (is-eq owner tx-sender)
          (begin
            (map-set goals { goal-id: goal-id }
              { owner: owner,
                label: (get label g),
                target: (get target g),
                current: (get current g),
                deadline: (get deadline g),
                created: (get created g),
                active: false })
            (ok true))
          (err ERR-NOT-AUTHORIZED)))
    (err ERR-NOT-FOUND)))

;; Advice categories
;; - "reached"      : current >= target
;; - "behind"       : progress < 50% and time passed >= 50%
;; - "on-track"     : otherwise

(define-public (generate-advice (goal-id uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (let ((target (get target g))
          (current (get current g))
          (deadline (get deadline g))
          (created (get created g)))
      (let ((percent (if (is-eq target u0) u0 (/ (* current u100) target)))
            (now-ts (now))
            (window (if (> deadline created) (- deadline created) u0))
            (elapsed (if (> (now) created) (- now-ts created) u0)))
        (let ((elapsed-pct (if (is-eq window u0) u0 (/ (* elapsed u100) window))))
          (if (>= current target)
              (begin
                (unwrap! (mk-alert (get owner g) goal-id "status" "Goal reached") (err ERR-INVALID))
                (ok "reached"))
              (if (and (< percent u50) (>= elapsed-pct u50))
                  (begin
                    (unwrap! (mk-alert (get owner g) goal-id "advice" "You are behind schedule") (err ERR-INVALID))
                    (ok "behind"))
                  (begin
                    (unwrap! (mk-alert (get owner g) goal-id "advice" "You are on track") (err ERR-INVALID))
                    (ok "on-track")))))))
    (err ERR-NOT-FOUND)))

;; ======== read-only ========

(define-read-only (get-goal (goal-id uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (ok g)
    (err ERR-NOT-FOUND)))

(define-read-only (progress-percent (goal-id uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (let ((target (get target g))
          (current (get current g)))
      (ok (if (is-eq target u0) u0 (/ (* current u100) target))))
    (err ERR-NOT-FOUND)))

(define-read-only (is-on-track (goal-id uint))
  (match (map-get? goals { goal-id: goal-id }) g
    (let ((target (get target g))
          (current (get current g))
          (deadline (get deadline g))
          (created (get created g)))
      (let ((p (if (is-eq target u0) u0 (/ (* current u100) target)))
            (now-ts (now))
            (window (if (> deadline created) (- deadline created) u0))
            (elapsed (if (> (now) created) (- now-ts created) u0)))
        (let ((elapsed-pct (if (is-eq window u0) u0 (/ (* elapsed u100) window))))
          (ok (or (>= p u50) (< elapsed-pct u50))))))
    (err ERR-NOT-FOUND)))
