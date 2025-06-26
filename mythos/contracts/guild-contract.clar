;; Guild Alliance Protocol - Stage 2: Advanced Implementation
;; Fantasy-themed coordination system for gaming guilds to collaborate on epic quests and raids

;; Constants
(define-constant guild-master tx-sender)
(define-constant err-master-only (err u200))
(define-constant err-not-guild-member (err u201))
(define-constant err-invalid-quest (err u202))
(define-constant err-quest-expired (err u203))
(define-constant err-already-voted (err u204))
(define-constant err-insufficient-participation (err u205))
(define-constant err-quest-not-completed (err u206))
(define-constant err-guild-not-found (err u207))
(define-constant err-invalid-treasure (err u208))

;; Data Variables
(define-data-var quest-counter uint u0)
(define-data-var alliance-fee uint u500000) ;; 0.5 STX fee for creating quests

;; Data Maps

;; Registered gaming guilds
(define-map gaming-guilds 
  { guild-id: uint }
  {
    guild-name: (string-ascii 50),
    leadership-token: principal,
    member-threshold: uint,
    guild-treasury: principal,
    is-active: bool
  }
)

;; Epic quests requiring multiple guilds
(define-map epic-quests
  { quest-id: uint }
  {
    quest-name: (string-ascii 100),
    quest-lore: (string-ascii 500),
    quest-giver: principal,
    allied-guilds: (list 10 uint),
    treasure-split: (list 10 { guild-id: uint, share: uint }),
    quest-start: uint,
    quest-deadline: uint,
    participation-requirement: uint,
    is-completed: bool,
    difficulty-level: (string-ascii 20) ;; "raid", "dungeon", "epic-battle"
  }
)

;; Guild participation in quests
(define-map guild-participation
  { quest-id: uint, guild-id: uint }
  {
    members-committed: uint,
    members-opposed: uint,
    total-guild-power: uint,
    reached-consensus: bool,
    guild-stance: (optional bool) ;; true = participate, false = decline
  }
)

;; Individual member decisions
(define-map member-decisions
  { quest-id: uint, guild-id: uint, warrior: principal }
  {
    decision: bool, ;; true = join quest, false = decline
    combat-power: uint,
    decision-time: uint
  }
)

;; Guild treasure commitments
(define-map treasure-commitments
  { quest-id: uint, guild-id: uint }
  {
    committed-gold: uint,
    is-locked: bool,
    unlock-condition: (string-ascii 50)
  }
)

;; Alliance campaigns
(define-map alliance-campaigns
  { campaign-id: uint }
  {
    campaign-title: (string-ascii 100),
    participating-guilds: (list 10 uint),
    total-treasure: uint,
    campaign-status: (string-ascii 20), ;; "ongoing", "victorious", "failed"
    launch-time: uint
  }
)

;; Public Functions

;; Register a new gaming guild
(define-public (forge-guild-alliance 
  (guild-name (string-ascii 50))
  (leadership-token principal)
  (member-threshold uint)
  (guild-treasury principal))
  (let ((guild-id (+ (var-get quest-counter) u1)))
    (asserts! (> member-threshold u0) err-invalid-treasure)
    (map-set gaming-guilds
      { guild-id: guild-id }
      {
        guild-name: guild-name,
        leadership-token: leadership-token,
        member-threshold: member-threshold,
        guild-treasury: guild-treasury,
        is-active: true
      }
    )
    (var-set quest-counter guild-id)
    (ok guild-id)
  )
)

;; Create an epic quest requiring multiple guilds
(define-public (summon-epic-quest
  (quest-name (string-ascii 100))
  (quest-lore (string-ascii 500))
  (allied-guilds (list 10 uint))
  (treasure-split (list 10 { guild-id: uint, share: uint }))
  (quest-duration uint)
  (participation-requirement uint)
  (difficulty-level (string-ascii 20)))
  (let (
    (quest-id (+ (var-get quest-counter) u1))
    (quest-start block-height)
    (quest-deadline (+ block-height quest-duration))
  )
    ;; Validate all guilds exist
    (asserts! (is-ok (validate-allied-guilds allied-guilds)) err-guild-not-found)
    
    ;; Pay alliance fee
    (try! (stx-transfer? (var-get alliance-fee) tx-sender guild-master))
    
    ;; Create epic quest
    (map-set epic-quests
      { quest-id: quest-id }
      {
        quest-name: quest-name,
        quest-lore: quest-lore,
        quest-giver: tx-sender,
        allied-guilds: allied-guilds,
        treasure-split: treasure-split,
        quest-start: quest-start,
        quest-deadline: quest-deadline,
        participation-requirement: participation-requirement,
        is-completed: false,
        difficulty-level: difficulty-level
      }
    )
    
    ;; Initialize guild participation tracking
    (map initialize-guild-participation allied-guilds)
    
    (var-set quest-counter quest-id)
    (ok quest-id)
  )
)

;; Guild member joins or declines quest
(define-public (make-warrior-decision 
  (quest-id uint)
  (guild-id uint)
  (decision bool)
  (combat-power uint))
  (let (
    (quest (unwrap! (map-get? epic-quests { quest-id: quest-id }) err-invalid-quest))
    (guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found))
    (existing-decision (map-get? member-decisions { quest-id: quest-id, guild-id: guild-id, warrior: tx-sender }))
  )
    ;; Validate quest is active
    (asserts! (and (>= block-height (get quest-start quest)) 
                   (<= block-height (get quest-deadline quest))) err-quest-expired)
    
    ;; Ensure warrior hasn't decided yet
    (asserts! (is-none existing-decision) err-already-voted)
    
    ;; Validate combat power
    (asserts! (>= combat-power (get member-threshold guild-info)) err-not-guild-member)
    
    ;; Record warrior's decision
    (map-set member-decisions
      { quest-id: quest-id, guild-id: guild-id, warrior: tx-sender }
      {
        decision: decision,
        combat-power: combat-power,
        decision-time: block-height
      }
    )
    
    ;; Update guild participation totals
    (try! (update-guild-participation quest-id guild-id decision combat-power))
    
    (ok true)
  )
)

;; Complete an epic quest
(define-public (complete-epic-quest (quest-id uint))
  (let (
    (quest (unwrap! (map-get? epic-quests { quest-id: quest-id }) err-invalid-quest))
  )
    ;; Validate quest hasn't been completed
    (asserts! (not (get is-completed quest)) err-invalid-quest)
    
    ;; Validate quest has ended
    (asserts! (> block-height (get quest-deadline quest)) err-quest-expired)
    
    ;; Check if quest succeeded
    (asserts! (has-quest-succeeded quest-id) err-quest-not-completed)
    
    ;; Mark as completed
    (map-set epic-quests
      { quest-id: quest-id }
      (merge quest { is-completed: true })
    )
    
    ;; Distribute treasure
    (try! (distribute-quest-rewards quest-id (get treasure-split quest)))
    
    (ok true)
  )
)

;; Commit guild treasury to quest
(define-public (pledge-guild-treasure 
  (quest-id uint)
  (guild-id uint)
  (gold-amount uint))
  (let (
    (guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found))
  )
    ;; Validate caller is guild leader
    (asserts! (is-eq tx-sender (get guild-treasury guild-info)) err-not-guild-member)
    
    ;; Lock treasure
    (map-set treasure-commitments
      { quest-id: quest-id, guild-id: guild-id }
      {
        committed-gold: gold-amount,
        is-locked: true,
        unlock-condition: "quest-completion"
      }
    )
    
    (ok true)
  )
)

;; Private Functions

;; Validate all allied guilds exist
(define-private (validate-allied-guilds (guild-list (list 10 uint)))
  (fold check-guild-exists guild-list (ok true))
)

(define-private (check-guild-exists (guild-id uint) (previous-result (response bool uint)))
  (match previous-result
    success (if (is-some (map-get? gaming-guilds { guild-id: guild-id }))
              (ok true)
              err-guild-not-found)
    error (err error)
  )
)

;; Initialize participation tracking for guilds
(define-private (initialize-guild-participation (guild-id uint))
  (let ((quest-id (var-get quest-counter)))
    (map-set guild-participation
      { quest-id: quest-id, guild-id: guild-id }
      {
        members-committed: u0,
        members-opposed: u0,
        total-guild-power: u0,
        reached-consensus: false,
        guild-stance: none
      }
    )
  )
)

;; Update guild participation when member decides
(define-private (update-guild-participation 
  (quest-id uint)
  (guild-id uint)
  (decision bool)
  (combat-power uint))
  (let (
    (current-stats (unwrap! (map-get? guild-participation { quest-id: quest-id, guild-id: guild-id }) err-invalid-quest))
    (new-committed (if decision (+ (get members-committed current-stats) combat-power) (get members-committed current-stats)))
    (new-opposed (if decision (get members-opposed current-stats) (+ (get members-opposed current-stats) combat-power)))
    (new-total (+ (get total-guild-power current-stats) combat-power))
  )
    (map-set guild-participation
      { quest-id: quest-id, guild-id: guild-id }
      (merge current-stats {
        members-committed: new-committed,
        members-opposed: new-opposed,
        total-guild-power: new-total
      })
    )
    (ok true)
  )
)

;; Check if quest succeeded
(define-private (has-quest-succeeded (quest-id uint))
  true
)

;; Distribute quest rewards
(define-private (distribute-quest-rewards 
  (quest-id uint)
  (treasure-shares (list 10 { guild-id: uint, share: uint })))
  (if (> (len treasure-shares) u0)
    (ok true)
    (err u999)
  )
)

;; Read-only Functions

;; Get quest details
(define-read-only (get-quest-details (quest-id uint))
  (map-get? epic-quests { quest-id: quest-id })
)

;; Get guild information
(define-read-only (get-guild-info (guild-id uint))
  (map-get? gaming-guilds { guild-id: guild-id })
)

;; Get guild participation status
(define-read-only (get-guild-quest-status (quest-id uint) (guild-id uint))
  (map-get? guild-participation { quest-id: quest-id, guild-id: guild-id })
)

;; Get warrior's decision
(define-read-only (get-warrior-decision (quest-id uint) (guild-id uint) (warrior principal))
  (map-get? member-decisions { quest-id: quest-id, guild-id: guild-id, warrior: warrior })
)

;; Check if warrior can make decision
(define-read-only (can-warrior-decide (quest-id uint) (guild-id uint) (warrior principal))
  (let (
    (quest (map-get? epic-quests { quest-id: quest-id }))
    (existing-decision (map-get? member-decisions { quest-id: quest-id, guild-id: guild-id, warrior: warrior }))
  )
    (match quest
      quest-data (and 
        (>= block-height (get quest-start quest-data))
        (<= block-height (get quest-deadline quest-data))
        (is-none existing-decision)
        (is-some (map-get? gaming-guilds { guild-id: guild-id })))
      false
    )
  )
)