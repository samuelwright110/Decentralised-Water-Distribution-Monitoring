(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_STATION_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DATA (err u102))
(define-constant ERR_STATION_EXISTS (err u103))
(define-constant ERR_INVALID_THRESHOLD (err u104))

(define-data-var station-counter uint u0)
(define-data-var global-alert-threshold uint u5000)

(define-map water-stations
    { station-id: uint }
    {
        name: (string-ascii 50),
        location: (string-ascii 100),
        owner: principal,
        active: bool,
        created-at: uint,
        last-update: uint,
    }
)

(define-map station-readings
    {
        station-id: uint,
        reading-id: uint,
    }
    {
        flow-rate: uint,
        pressure: uint,
        ph-level: uint,
        temperature: uint,
        turbidity: uint,
        timestamp: uint,
        recorded-by: principal,
    }
)

(define-map station-reading-counters
    { station-id: uint }
    { counter: uint }
)

(define-map authorized-monitors
    { monitor: principal }
    {
        authorized: bool,
        authorized-at: uint,
    }
)

(define-map station-alerts
    {
        station-id: uint,
        alert-id: uint,
    }
    {
        alert-type: (string-ascii 20),
        severity: uint,
        message: (string-ascii 200),
        resolved: bool,
        created-at: uint,
    }
)

(define-map station-alert-counters
    { station-id: uint }
    { counter: uint }
)

(define-map daily-stats
    {
        station-id: uint,
        date: uint,
    }
    {
        avg-flow-rate: uint,
        avg-pressure: uint,
        avg-ph: uint,
        avg-temperature: uint,
        readings-count: uint,
    }
)

(define-public (register-station
        (name (string-ascii 50))
        (location (string-ascii 100))
    )
    (let (
            (new-id (+ (var-get station-counter) u1))
            (current-block u1)
        )
        (asserts! (> (len name) u0) ERR_INVALID_DATA)
        (asserts! (> (len location) u0) ERR_INVALID_DATA)
        (asserts! (is-none (map-get? water-stations { station-id: new-id }))
            ERR_STATION_EXISTS
        )

        (map-set water-stations { station-id: new-id } {
            name: name,
            location: location,
            owner: tx-sender,
            active: true,
            created-at: current-block,
            last-update: current-block,
        })

        (map-set station-reading-counters { station-id: new-id } { counter: u0 })
        (map-set station-alert-counters { station-id: new-id } { counter: u0 })
        (var-set station-counter new-id)
        (ok new-id)
    )
)

(define-public (authorize-monitor (monitor principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-monitors { monitor: monitor } {
            authorized: true,
            authorized-at: u1,
        })
        (ok true)
    )
)

(define-public (revoke-monitor (monitor principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-monitors { monitor: monitor } {
            authorized: false,
            authorized-at: u1,
        })
        (ok true)
    )
)

(define-public (record-reading
        (station-id uint)
        (flow-rate uint)
        (pressure uint)
        (ph-level uint)
        (temperature uint)
        (turbidity uint)
    )
    (let (
            (station (unwrap! (map-get? water-stations { station-id: station-id })
                ERR_STATION_NOT_FOUND
            ))
            (reading-counter (default-to { counter: u0 }
                (map-get? station-reading-counters { station-id: station-id })
            ))
            (new-reading-id (+ (get counter reading-counter) u1))
            (current-block u1)
        )
        (asserts!
            (or
                (is-eq tx-sender (get owner station))
                (is-authorized-monitor tx-sender)
            )
            ERR_UNAUTHORIZED
        )
        (asserts! (get active station) ERR_STATION_NOT_FOUND)
        (asserts! (and (> flow-rate u0) (< flow-rate u100000)) ERR_INVALID_DATA)
        (asserts! (and (> pressure u0) (< pressure u10000)) ERR_INVALID_DATA)
        (asserts! (and (>= ph-level u0) (<= ph-level u1400)) ERR_INVALID_DATA)
        (asserts! (and (> temperature u0) (< temperature u1000)) ERR_INVALID_DATA)
        (asserts! (< turbidity u10000) ERR_INVALID_DATA)

        (map-set station-readings {
            station-id: station-id,
            reading-id: new-reading-id,
        } {
            flow-rate: flow-rate,
            pressure: pressure,
            ph-level: ph-level,
            temperature: temperature,
            turbidity: turbidity,
            timestamp: current-block,
            recorded-by: tx-sender,
        })

        (map-set station-reading-counters { station-id: station-id } { counter: new-reading-id })

        (map-set water-stations { station-id: station-id }
            (merge station { last-update: current-block })
        )

        (unwrap!
            (check-and-create-alerts station-id flow-rate pressure ph-level
                temperature turbidity
            )
            ERR_INVALID_DATA
        )
        (unwrap!
            (update-daily-stats station-id flow-rate pressure ph-level
                temperature
            )
            ERR_INVALID_DATA
        )

        (ok new-reading-id)
    )
)

(define-private (is-authorized-monitor (monitor principal))
    (match (map-get? authorized-monitors { monitor: monitor })
        auth-info (get authorized auth-info)
        false
    )
)

(define-private (check-and-create-alerts
        (station-id uint)
        (flow-rate uint)
        (pressure uint)
        (ph-level uint)
        (temperature uint)
        (turbidity uint)
    )
    (let (
            (alert-counter (default-to { counter: u0 }
                (map-get? station-alert-counters { station-id: station-id })
            ))
            (current-block u1)
        )
        (begin
            (if (< flow-rate (var-get global-alert-threshold))
                (map-set station-alerts {
                    station-id: station-id,
                    alert-id: (+ (get counter alert-counter) u1),
                } {
                    alert-type: "LOW_FLOW",
                    severity: u2,
                    message: "Flow rate below threshold",
                    resolved: false,
                    created-at: current-block,
                })
                true
            )

            (if (or (< ph-level u650) (> ph-level u850))
                (map-set station-alerts {
                    station-id: station-id,
                    alert-id: (+ (get counter alert-counter) u2),
                } {
                    alert-type: "PH_ABNORMAL",
                    severity: u3,
                    message: "pH level outside safe range",
                    resolved: false,
                    created-at: current-block,
                })
                true
            )

            (if (> turbidity u500)
                (map-set station-alerts {
                    station-id: station-id,
                    alert-id: (+ (get counter alert-counter) u3),
                } {
                    alert-type: "HIGH_TURBIDITY",
                    severity: u2,
                    message: "Water turbidity too high",
                    resolved: false,
                    created-at: current-block,
                })
                true
            )

            (if (> temperature u350)
                (map-set station-alerts {
                    station-id: station-id,
                    alert-id: (+ (get counter alert-counter) u4),
                } {
                    alert-type: "HIGH_TEMP",
                    severity: u1,
                    message: "Temperature elevated",
                    resolved: false,
                    created-at: current-block,
                })
                true
            )

            (map-set station-alert-counters { station-id: station-id } { counter: (+ (get counter alert-counter) u4) })
            (ok true)
        )
    )
)

(define-private (update-daily-stats
        (station-id uint)
        (flow-rate uint)
        (pressure uint)
        (ph-level uint)
        (temperature uint)
    )
    (let (
            (today u1)
            (existing-stats (map-get? daily-stats {
                station-id: station-id,
                date: today,
            }))
        )
        (match existing-stats
            stats (map-set daily-stats {
                station-id: station-id,
                date: today,
            } {
                avg-flow-rate: (/
                    (+ (* (get avg-flow-rate stats) (get readings-count stats))
                        flow-rate
                    )
                    (+ (get readings-count stats) u1)
                ),
                avg-pressure: (/
                    (+ (* (get avg-pressure stats) (get readings-count stats))
                        pressure
                    )
                    (+ (get readings-count stats) u1)
                ),
                avg-ph: (/ (+ (* (get avg-ph stats) (get readings-count stats)) ph-level)
                    (+ (get readings-count stats) u1)
                ),
                avg-temperature: (/
                    (+ (* (get avg-temperature stats) (get readings-count stats))
                        temperature
                    )
                    (+ (get readings-count stats) u1)
                ),
                readings-count: (+ (get readings-count stats) u1),
            })
            (map-set daily-stats {
                station-id: station-id,
                date: today,
            } {
                avg-flow-rate: flow-rate,
                avg-pressure: pressure,
                avg-ph: ph-level,
                avg-temperature: temperature,
                readings-count: u1,
            })
        )
        (ok true)
    )
)

(define-public (deactivate-station (station-id uint))
    (let ((station (unwrap! (map-get? water-stations { station-id: station-id })
            ERR_STATION_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get owner station)) ERR_UNAUTHORIZED)
        (map-set water-stations { station-id: station-id }
            (merge station {
                active: false,
                last-update: u1,
            })
        )
        (ok true)
    )
)

(define-public (resolve-alert
        (station-id uint)
        (alert-id uint)
    )
    (let (
            (station (unwrap! (map-get? water-stations { station-id: station-id })
                ERR_STATION_NOT_FOUND
            ))
            (alert (unwrap!
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: alert-id,
                })
                ERR_STATION_NOT_FOUND
            ))
        )
        (asserts!
            (or
                (is-eq tx-sender (get owner station))
                (is-authorized-monitor tx-sender)
            )
            ERR_UNAUTHORIZED
        )

        (map-set station-alerts {
            station-id: station-id,
            alert-id: alert-id,
        }
            (merge alert { resolved: true })
        )
        (ok true)
    )
)

(define-public (set-alert-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-threshold u0) ERR_INVALID_THRESHOLD)
        (var-set global-alert-threshold new-threshold)
        (ok true)
    )
)

(define-read-only (get-station (station-id uint))
    (map-get? water-stations { station-id: station-id })
)

(define-read-only (get-reading
        (station-id uint)
        (reading-id uint)
    )
    (map-get? station-readings {
        station-id: station-id,
        reading-id: reading-id,
    })
)

(define-read-only (get-latest-reading (station-id uint))
    (let ((counter (default-to { counter: u0 }
            (map-get? station-reading-counters { station-id: station-id })
        )))
        (if (> (get counter counter) u0)
            (map-get? station-readings {
                station-id: station-id,
                reading-id: (get counter counter),
            })
            none
        )
    )
)

(define-read-only (get-station-alerts (station-id uint))
    (let ((alert-counter (default-to { counter: u0 }
            (map-get? station-alert-counters { station-id: station-id })
        )))
        (if (> (get counter alert-counter) u0)
            (list
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: u1,
                })
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: u2,
                })
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: u3,
                })
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: u4,
                })
                (map-get? station-alerts {
                    station-id: station-id,
                    alert-id: u5,
                })
            )
            (list)
        )
    )
)

(define-read-only (get-daily-stats
        (station-id uint)
        (date uint)
    )
    (map-get? daily-stats {
        station-id: station-id,
        date: date,
    })
)

(define-read-only (get-total-stations)
    (var-get station-counter)
)

(define-read-only (get-alert-threshold)
    (var-get global-alert-threshold)
)

(define-read-only (is-monitor-authorized (monitor principal))
    (is-authorized-monitor monitor)
)

(define-read-only (get-station-reading-count (station-id uint))
    (match (map-get? station-reading-counters { station-id: station-id })
        counter-info (get counter counter-info)
        u0
    )
)
