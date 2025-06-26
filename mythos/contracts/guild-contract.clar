;; Guild Alliance Protocol - Stage 1: Basic Implementation
;; Simple guild registration and quest creation system

;; Constants
(define-constant guild-master tx-sender)
(define-constant err-master-only (err u200))
(define-constant err-not-guild-member (err u201))
(define-constant err-invalid-quest (err u202))
(define-constant err-quest-expired (err u203))
(define-constant err-guild-not-found (err u207))

;; Data Variables
(define-data-var quest-counter uint u0)
(define-data-var alliance-fee uint u100000) ;; 0.1 STX fee for creating quests

;; Data Maps

;; Basic guild registry
(define-map gaming-guilds 
  { guild-id: uint }
  {
    guild-name: (string-ascii 50),
    guild-leader: principal,
    member-count: uint,
    is-active: bool
  }
)

;; Simple quests
(define-map basic-quests
  { quest-id: uint }
  {
    quest-name: (string-ascii 100),
    quest-creator: principal,
    participating-guilds: (list 5 uint),
    quest-start: uint,
    quest-deadline: uint,
    is-completed: bool
  }
)

;; Guild quest participation
(define-map guild-quest-status
  { quest-id: uint, guild-id: uint }
  {
    is-participating: bool,
    join-time: uint
  }
)

;; Public Functions

;; Register a new gaming guild
(define-public (create-guild 
  (guild-name (string-ascii 50))
  (member-count uint))
  (let ((guild-id (+ (var-get quest-counter) u1)))
    (asserts! (> member-count u0) err-invalid-quest)
    (map-set gaming-guilds
      { guild-id: guild-id }
      {
        guild-name: guild-name,
        guild-leader: tx-sender,
        member-count: member-count,
        is-active: true
      }
    )
    (var-set quest-counter guild-id)
    (ok guild-id)
  )
)

;; Create a basic quest
(define-public (create-quest
  (quest-name (string-ascii 100))
  (participating-guilds (list 5 uint))
  (quest-duration uint))
  (let (
    (quest-id (+ (var-get quest-counter) u1))
    (quest-start block-height)
    (quest-deadline (+ block-height quest-duration))
  )
    ;; Validate all guilds exist
    (asserts! (is-ok (validate-guilds participating-guilds)) err-guild-not-found)
    
    ;; Pay alliance fee
    (try! (stx-transfer? (var-get alliance-fee) tx-sender guild-master))
    
    ;; Create quest
    (map-set basic-quests
      { quest-id: quest-id }
      {
        quest-name: quest-name,
        quest-creator: tx-sender,
        participating-guilds: participating-guilds,
        quest-start: quest-start,
        quest-deadline: quest-deadline,
        is-completed: false
      }
    )
    
    ;; Initialize participation status for all guilds
    (map initialize-participation participating-guilds quest-id)
    
    (var-set quest-counter quest-id)
    (ok quest-id)
  )
)

;; Guild joins a quest
(define-public (join-quest (quest-id uint) (guild-id uint))
  (let (
    (quest (unwrap! (map-get? basic-quests { quest-id: quest-id }) err-invalid-quest))
    (guild (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found))
  )
    ;; Validate caller is guild leader
    (asserts! (is-eq tx-sender (get guild-leader guild)) err-not-guild-member)
    
    ;; Validate quest is active
    (asserts! (and (>= block-height (get quest-start quest)) 
                   (<= block-height (get quest-deadline quest))) err-quest-expired)
    
    ;; Update participation status
    (map-set guild-quest-status
      { quest-id: quest-id, guild-id: guild-id }
      {
        is-participating: true,
        join-time: block-height
      }
    )
    
    (ok true)
  )
)

;; Complete a quest (simplified)
(define-public (complete-quest (quest-id uint))
  (let (
    (quest (unwrap! (map-get? basic-quests { quest-id: quest-id }) err-invalid-quest))
  )
    ;; Validate caller is quest creator
    (asserts! (is-eq tx-sender (get quest-creator quest)) err-not-guild-member)
    
    ;; Validate quest hasn't been completed
    (asserts! (not (get is-completed quest)) err-invalid-quest)
    
    ;; Mark as completed
    (map-set basic-quests
      { quest-id: quest-id }
      (merge quest { is-completed: true })
    )
    
    (ok true)
  )
)

;; Private Functions

;; Validate all guilds exist
(define-private (validate-guilds (guild-list (list 5 uint)))
  (fold check-guild guild-list (ok true))
)

(define-private (check-guild (guild-id uint) (previous-result (response bool uint)))
  (match previous-result
    success (if (is-some (map-get? gaming-guilds { guild-id: guild-id }))
              (ok true)
              err-guild-not-found)
    error (err error)
  )
)

;; Initialize participation for guilds
(define-private (initialize-participation (guild-id uint) (quest-id uint))
  (map-set guild-quest-status
    { quest-id: quest-id, guild-id: guild-id }
    {
      is-participating: false,
      join-time: u0
    }
  )
)

;; Read-only Functions

;; Get quest details
(define-read-only (get-quest-info (quest-id uint))
  (map-get? basic-quests { quest-id: quest-id })
)

;; Get guild information
(define-read-only (get-guild-details (guild-id uint))
  (map-get? gaming-guilds { guild-id: guild-id })
)

;; Get guild participation in quest
(define-read-only (get-participation-status (quest-id uint) (guild-id uint))
  (map-get? guild-quest-status { quest-id: quest-id, guild-id: guild-id })
)

;; Check if guild is active
(define-read-only (is-guild-active (guild-id uint))
  (match (map-get? gaming-guilds { guild-id: guild-id })
    guild-data (get is-active guild-data)
    false
  )
)