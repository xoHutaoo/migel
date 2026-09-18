#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; CHARLIE CHAOS - AutoHotkey v2
;
; Harmless visual prank/game:
; - DVD bounce + several movement types
; - Random 5-minute event director
; - Fake gravity
; - Zoom pulses
; - Kirk rain
; - Wave motion
; - Screen-edge swarm
; - Mini Kirk chases/orbits the mouse (does NOT move the cursor)
; - Clickable Boss Kirk with HP bar
; - Random image swapping
;
; QUICK EXIT:
;   Ctrl + Shift + Alt + T
;
; Normal Windows/AHK termination remains available as a safety fallback.
; ============================================================

; ---------------- EDIT THESE ----------------

IMAGE_LIST_URL := "https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/images.txt"

CACHE_COUNT      := 20
BASE_IMAGES      := 45

MIN_SIZE         := 90
MAX_SIZE         := 260

MOVE_EVERY_MS    := 20
MIN_SPEED        := 2
MAX_SPEED        := 7

SWAP_EVERY_MS    := 3500
SWAP_COUNT       := 8

; Long quiet period between random events.
; Default: one event roughly every 2-4 minutes.
EVENT_MIN_MS     := 120000
EVENT_MAX_MS     := 240000

; Individual effects last roughly this long.
EVENT_DURATION_MIN := 90000    ; 1.5 minutes minimum
EVENT_DURATION_MAX := 150000   ; up to 2.5 minutes

; Boss settings
BOSS_HP          := 16
BOSS_SIZE        := 360
BOSS_SPEED       := 4

; Mini cursor-chaser
MINI_SIZE        := 72
MINI_SPEED       := 0.10

; Tiny mouse jitter while the mini-Kirk event is active.
; Keep these small so it is annoying rather than unusable.
MOUSE_JITTER_PX  := 3
MOUSE_JITTER_MS  := 350

; Rain/swarm limits so the PC stays responsive
MAX_TEMP_EFFECTS := 55

; --------------------------------------------

global Windows := []
global CacheFiles := []
global Spawned := 0
global TempDir := A_Temp "\CharlieChaos_" A_TickCount

global GravityOn := false
global ZoomOn := false
global WaveOn := false
global RainOn := false
global SwarmOn := false
global MiniOn := false

global RainItems := []
global SwarmItems := []

global Mini := 0
global Boss := 0
global BossAlive := false
global BossHPNow := 0

global StartTick := A_TickCount

; Quick exit
^+!t::SafeExit()

DirCreate(TempDir)

urls := GetImageUrls()

if urls.Length = 0 {
    MsgBox(
        "No usable image URLs were found.`n`n"
        . "Edit IMAGE_LIST_URL at the top of the script.",
        "Charlie Chaos"
    )
    SafeExit()
}

BuildCache(urls)

if CacheFiles.Length = 0 {
    MsgBox(
        "No images could be downloaded.`n`n"
        . "Use direct .jpg/.jpeg/.png/.gif/.bmp links.",
        "Charlie Chaos"
    )
    SafeExit()
}

; Create base DVD Kirks.
Loop BASE_IMAGES
    SpawnBaseImage()

SetTimer(MoveAll, MOVE_EVERY_MS)
SetTimer(SwapImages, SWAP_EVERY_MS)

; First event also waits a while, so startup is mostly calm.
SetTimer(EventDirector, -Random(90000, 180000))

return


; ============================================================
; INTERNET / CACHE
; ============================================================

GetImageUrls() {
    global IMAGE_LIST_URL, TempDir

    listFile := TempDir "\images.txt"

    try Download(IMAGE_LIST_URL, listFile)
    catch {
        return []
    }

    try text := FileRead(listFile, "UTF-8")
    catch {
        return []
    }

    result := []

    for line in StrSplit(text, "`n", "`r") {
        url := Trim(line)

        if (url = "")
            continue

        if (SubStr(url, 1, 1) = "#")
            continue

        if !RegExMatch(url, "i)^https?://")
            continue

        if !RegExMatch(url, "i)\.(jpg|jpeg|png|gif|bmp)(?:\?.*)?$")
            continue

        result.Push(url)
    }

    return result
}


BuildCache(urls) {
    global CacheFiles, CACHE_COUNT, TempDir

    indexes := []

    Loop urls.Length
        indexes.Push(A_Index)

    ; Shuffle.
    i := indexes.Length

    while (i > 1) {
        j := Random(1, i)
        temp := indexes[i]
        indexes[i] := indexes[j]
        indexes[j] := temp
        i -= 1
    }

    wanted := Min(CACHE_COUNT, urls.Length)
    downloaded := 0

    for index in indexes {
        if downloaded >= wanted
            break

        url := urls[index]
        ext := GetExtension(url)
        file := TempDir "\img_" (downloaded + 1) "." ext

        try {
            Download(url, file)

            if FileExist(file) && FileGetSize(file) > 3000 {
                CacheFiles.Push(file)
                downloaded += 1
            }
            else {
                try FileDelete(file)
            }
        }
    }
}


GetExtension(url) {
    if RegExMatch(url, "i)\.(jpg|jpeg|png|gif|bmp)(?:\?.*)?$", &m)
        return StrLower(m[1])

    return "jpg"
}


RandomImage() {
    global CacheFiles
    return CacheFiles[Random(1, CacheFiles.Length)]
}


; ============================================================
; BASE WINDOWS
; ============================================================

SpawnBaseImage() {
    global Windows
    global MIN_SIZE, MAX_SIZE, MIN_SPEED, MAX_SPEED

    file := RandomImage()

    w := Random(MIN_SIZE, MAX_SIZE)
    h := Random(Max(65, Floor(w * 0.72)), Floor(w * 1.12))

    x := Random(0, Max(0, A_ScreenWidth - w))
    y := Random(0, Max(0, A_ScreenHeight - h))

    speedX := Random(MIN_SPEED, MAX_SPEED)
    speedY := Random(MIN_SPEED, MAX_SPEED)

    if Random(0, 1)
        speedX := -speedX

    if Random(0, 1)
        speedY := -speedY

    ; movement modes:
    ; 1 = DVD
    ; 2 = horizontal-heavy
    ; 3 = vertical-heavy
    ; 4 = drifting
    ; 5 = wave-capable
    mode := Random(1, 5)

    if mode = 2
        speedY := Random(1, 2)

    if mode = 3
        speedX := Random(1, 2)

    if mode = 4 {
        speedX := Random(1, 3)
        speedY := Random(1, 3)
    }

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.MarginX := 0
    g.MarginY := 0

    pic := g.AddPicture("x0 y0 w" w " h" h, file)

    g.Show("x" x " y" y " w" w " h" h " NoActivate")

    Windows.Push({
        gui: g,
        pic: pic,

        x: x,
        y: y,

        baseW: w,
        baseH: h,
        w: w,
        h: h,

        dx: speedX,
        dy: speedY,

        mode: mode,
        phase: Random(0, 628) / 100.0,
        zoomPhase: Random(0, 628) / 100.0
    })
}


; ============================================================
; MASTER MOVEMENT
; ============================================================

MoveAll() {
    global Windows
    global GravityOn, ZoomOn, WaveOn
    global RainOn, SwarmOn, MiniOn

    now := A_TickCount / 1000.0

    for item in Windows {
        ; --------------------------------
        ; Movement type
        ; --------------------------------

        if item.mode = 1 {
            item.x += item.dx
            item.y += item.dy
        }
        else if item.mode = 2 {
            item.x += item.dx
            item.y += item.dy * 0.45
        }
        else if item.mode = 3 {
            item.x += item.dx * 0.45
            item.y += item.dy
        }
        else if item.mode = 4 {
            item.x += item.dx * 0.65
            item.y += item.dy * 0.65
        }
        else {
            item.x += item.dx
            item.y += item.dy
        }

        ; --------------------------------
        ; Fake gravity
        ; --------------------------------

        if GravityOn {
            item.dy += 0.18

            ; cap downward speed
            if item.dy > 14
                item.dy := 14
        }

        ; --------------------------------
        ; Wave event
        ; --------------------------------

        if WaveOn {
            item.y += Sin(now * 4 + item.phase) * 3.5
        }

        ; --------------------------------
        ; Zoom pulse
        ; --------------------------------

        drawW := item.baseW
        drawH := item.baseH

        if ZoomOn {
            scale := 1.0 + Sin(now * 5 + item.zoomPhase) * 0.18

            drawW := Max(40, Floor(item.baseW * scale))
            drawH := Max(40, Floor(item.baseH * scale))
        }

        item.w := drawW
        item.h := drawH

        BounceItem(item)

        try {
            item.gui.Move(item.x, item.y, item.w, item.h)
            item.pic.Move(0, 0, item.w, item.h)
        }
    }

    if RainOn
        MoveRain()

    if SwarmOn
        MoveSwarm()

    if MiniOn
        MoveMini()

    if BossAlive
        MoveBoss()
}


BounceItem(item) {
    if item.x <= 0 {
        item.x := 0
        item.dx := Abs(item.dx)
    }
    else if item.x + item.w >= A_ScreenWidth {
        item.x := Max(0, A_ScreenWidth - item.w)
        item.dx := -Abs(item.dx)
    }

    if item.y <= 0 {
        item.y := 0
        item.dy := Abs(item.dy)
    }
    else if item.y + item.h >= A_ScreenHeight {
        item.y := Max(0, A_ScreenHeight - item.h)

        if GravityOn {
            ; fake floor bounce
            item.dy := -Random(5, 11)
        }
        else {
            item.dy := -Abs(item.dy)
        }
    }
}


; ============================================================
; IMAGE SWAPPING
; ============================================================

SwapImages() {
    global Windows, SWAP_COUNT

    if Windows.Length = 0
        return

    amount := Min(SWAP_COUNT, Windows.Length)

    Loop amount {
        item := Windows[Random(1, Windows.Length)]
        try item.pic.Value := RandomImage()
    }
}


; ============================================================
; EVENT DIRECTOR
; ============================================================

EventDirector() {
    global EVENT_MIN_MS, EVENT_MAX_MS

    ; Pick one random event.
    event := Random(1, 8)

    switch event {
        case 1:
            StartGravity()

        case 2:
            StartZoom()

        case 3:
            StartRain()

        case 4:
            StartWave()

        case 5:
            StartSwarm()

        case 6:
            StartMini()

        case 7:
            StartBoss()

        case 8:
            RandomMovementShuffle()
    }

    ; After the event ends, there will be another long quiet period.
    SetTimer(EventDirector, -Random(EVENT_MIN_MS, EVENT_MAX_MS))
}


RandomEventDuration() {
    global EVENT_DURATION_MIN, EVENT_DURATION_MAX
    return Random(EVENT_DURATION_MIN, EVENT_DURATION_MAX)
}


; ============================================================
; GRAVITY
; ============================================================

StartGravity() {
    global GravityOn

    if GravityOn
        return

    GravityOn := true
    SetTimer(StopGravity, -RandomEventDuration())
}


StopGravity() {
    global GravityOn, Windows

    GravityOn := false

    ; restore reasonable vertical speeds
    for item in Windows {
        if Abs(item.dy) > 8
            item.dy := (item.dy < 0 ? -Random(2, 6) : Random(2, 6))
    }
}


; ============================================================
; ZOOM PULSE
; ============================================================

StartZoom() {
    global ZoomOn

    if ZoomOn
        return

    ZoomOn := true
    SetTimer(StopZoom, -RandomEventDuration())
}


StopZoom() {
    global ZoomOn, Windows

    ZoomOn := false

    for item in Windows {
        item.w := item.baseW
        item.h := item.baseH

        try {
            item.gui.Move(item.x, item.y, item.w, item.h)
            item.pic.Move(0, 0, item.w, item.h)
        }
    }
}


; ============================================================
; WAVE
; ============================================================

StartWave() {
    global WaveOn

    if WaveOn
        return

    WaveOn := true
    SetTimer(StopWave, -RandomEventDuration())
}


StopWave() {
    global WaveOn
    WaveOn := false
}


; ============================================================
; KIRK RAIN
; ============================================================

StartRain() {
    global RainOn, RainItems, MAX_TEMP_EFFECTS

    if RainOn
        return

    RainOn := true
    RainItems := []

    count := Random(20, MAX_TEMP_EFFECTS)

    Loop count {
        size := Random(40, 105)

        x := Random(0, Max(0, A_ScreenWidth - size))
        y := Random(-A_ScreenHeight, -size)

        speed := Random(5, 13)

        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.MarginX := 0
        g.MarginY := 0

        pic := g.AddPicture(
            "x0 y0 w" size " h" size,
            RandomImage()
        )

        g.Show(
            "x" x
            . " y" y
            . " w" size
            . " h" size
            . " NoActivate"
        )

        RainItems.Push({
            gui: g,
            pic: pic,
            x: x,
            y: y,
            size: size,
            speed: speed
        })
    }

    SetTimer(StopRain, -RandomEventDuration())
}


MoveRain() {
    global RainItems

    for item in RainItems {
        item.y += item.speed

        if item.y > A_ScreenHeight {
            item.y := -item.size
            item.x := Random(0, Max(0, A_ScreenWidth - item.size))

            try item.pic.Value := RandomImage()
        }

        try item.gui.Move(item.x, item.y)
    }
}


StopRain() {
    global RainOn, RainItems

    RainOn := false

    for item in RainItems {
        try item.gui.Destroy()
    }

    RainItems := []
}


; ============================================================
; SCREEN EDGE SWARM
; ============================================================

StartSwarm() {
    global SwarmOn, SwarmItems, MAX_TEMP_EFFECTS

    if SwarmOn
        return

    SwarmOn := true
    SwarmItems := []

    count := Random(18, Min(42, MAX_TEMP_EFFECTS))

    side := Random(1, 4)

    Loop count {
        size := Random(45, 100)

        if side = 1 {
            ; left
            x := -size
            y := Random(0, Max(0, A_ScreenHeight - size))
            dx := Random(5, 12)
            dy := Random(-3, 3)
        }
        else if side = 2 {
            ; right
            x := A_ScreenWidth + size
            y := Random(0, Max(0, A_ScreenHeight - size))
            dx := -Random(5, 12)
            dy := Random(-3, 3)
        }
        else if side = 3 {
            ; top
            x := Random(0, Max(0, A_ScreenWidth - size))
            y := -size
            dx := Random(-3, 3)
            dy := Random(5, 12)
        }
        else {
            ; bottom
            x := Random(0, Max(0, A_ScreenWidth - size))
            y := A_ScreenHeight + size
            dx := Random(-3, 3)
            dy := -Random(5, 12)
        }

        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.MarginX := 0
        g.MarginY := 0

        pic := g.AddPicture(
            "x0 y0 w" size " h" size,
            RandomImage()
        )

        g.Show(
            "x" x
            . " y" y
            . " w" size
            . " h" size
            . " NoActivate"
        )

        SwarmItems.Push({
            gui: g,
            x: x,
            y: y,
            dx: dx,
            dy: dy,
            size: size
        })
    }

    SetTimer(StopSwarm, -RandomEventDuration())
}


MoveSwarm() {
    global SwarmItems

    for item in SwarmItems {
        item.x += item.dx
        item.y += item.dy

        try item.gui.Move(item.x, item.y)
    }
}


StopSwarm() {
    global SwarmOn, SwarmItems

    SwarmOn := false

    for item in SwarmItems {
        try item.gui.Destroy()
    }

    SwarmItems := []
}


; ============================================================
; MINI KIRK - CHASES / ORBITS CURSOR
; DOES NOT MOVE THE USER'S MOUSE
; ============================================================

StartMini() {
    global MiniOn, Mini, MINI_SIZE

    if MiniOn
        return

    MiniOn := true

    MouseGetPos(&mx, &my)

    x := mx + Random(-250, 250)
    y := my + Random(-180, 180)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.MarginX := 0
    g.MarginY := 0

    pic := g.AddPicture(
        "x0 y0 w" MINI_SIZE " h" MINI_SIZE,
        RandomImage()
    )

    g.Show(
        "x" x
        . " y" y
        . " w" MINI_SIZE
        . " h" MINI_SIZE
        . " NoActivate"
    )

    Mini := {
        gui: g,
        pic: pic,
        x: x,
        y: y,
        angle: 0
    }

    ; Slightly nudge the real cursor in random directions while this
    ; event is active. This is intentionally capped to a few pixels.
    SetTimer(MouseJitter, MOUSE_JITTER_MS)

    SetTimer(StopMini, -RandomEventDuration())
}


MoveMini() {
    global Mini, MINI_SPEED

    if !IsObject(Mini)
        return

    MouseGetPos(&mx, &my)

    Mini.angle += 0.12

    ; Orbit target around cursor so it feels annoying without hijacking input.
    targetX := mx + Cos(Mini.angle) * 115
    targetY := my + Sin(Mini.angle * 1.35) * 85

    Mini.x += (targetX - Mini.x) * MINI_SPEED
    Mini.y += (targetY - Mini.y) * MINI_SPEED

    try Mini.gui.Move(
        Floor(Mini.x),
        Floor(Mini.y)
    )
}


MouseJitter() {
    global MiniOn, MOUSE_JITTER_PX

    if !MiniOn
        return

    MouseGetPos(&mx, &my)

    dx := Random(-MOUSE_JITTER_PX, MOUSE_JITTER_PX)
    dy := Random(-MOUSE_JITTER_PX, MOUSE_JITTER_PX)

    ; Avoid a completely empty nudge.
    if (dx = 0 && dy = 0)
        dx := 1

    newX := Min(A_ScreenWidth - 1, Max(0, mx + dx))
    newY := Min(A_ScreenHeight - 1, Max(0, my + dy))

    MouseMove(newX, newY, 0)
}


StopMini() {
    global MiniOn, Mini

    MiniOn := false

    try SetTimer(MouseJitter, 0)

    if IsObject(Mini) {
        try Mini.gui.Destroy()
    }

    Mini := 0
}


; ============================================================
; BOSS KIRK
; ============================================================

StartBoss() {
    global BossAlive, Boss, BossHPNow
    global BOSS_HP, BOSS_SIZE, BOSS_SPEED

    if BossAlive
        return

    BossAlive := true
    BossHPNow := BOSS_HP

    w := Min(BOSS_SIZE, Floor(A_ScreenWidth * 0.40))
    h := Min(BOSS_SIZE + 54, Floor(A_ScreenHeight * 0.60))

    x := Floor((A_ScreenWidth - w) / 2)
    y := Floor((A_ScreenHeight - h) / 2)

    ; Boss must be clickable, so unlike visual-effect windows,
    ; it is NOT click-through.
    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.MarginX := 0
    g.MarginY := 0

    pic := g.AddPicture(
        "x0 y30 w" w " h" (h - 30),
        RandomImage()
    )

    ; Red-looking boss bar using a Progress control.
    hpBar := g.AddProgress(
        "x8 y5 w" (w - 16) " h18 Range0-" BOSS_HP " Value" BOSS_HP
    )

    ; Clicking the picture hurts the boss.
    pic.OnEvent("Click", BossHit)

    g.Show(
        "x" x
        . " y" y
        . " w" w
        . " h" h
    )

    Boss := {
        gui: g,
        pic: pic,
        bar: hpBar,

        x: x,
        y: y,
        w: w,
        h: h,

        dx: BOSS_SPEED,
        dy: BOSS_SPEED
    }

    SetTimer(BossTimeout, -Random(12000, 23000))
}


BossHit(*) {
    global BossAlive, BossHPNow, Boss

    if !BossAlive
        return

    BossHPNow -= 1

    try Boss.bar.Value := BossHPNow

    ; Randomly dodge after a hit.
    if Random(1, 100) <= 55 {
        Boss.x := Random(
            0,
            Max(0, A_ScreenWidth - Boss.w)
        )

        Boss.y := Random(
            0,
            Max(0, A_ScreenHeight - Boss.h)
        )

        try Boss.gui.Move(Boss.x, Boss.y)
    }

    if BossHPNow <= 0 {
        BossDefeated()
    }
}


MoveBoss() {
    global BossAlive, Boss

    if !BossAlive || !IsObject(Boss)
        return

    Boss.x += Boss.dx
    Boss.y += Boss.dy

    if Boss.x <= 0 {
        Boss.x := 0
        Boss.dx := Abs(Boss.dx)
    }
    else if Boss.x + Boss.w >= A_ScreenWidth {
        Boss.x := A_ScreenWidth - Boss.w
        Boss.dx := -Abs(Boss.dx)
    }

    if Boss.y <= 0 {
        Boss.y := 0
        Boss.dy := Abs(Boss.dy)
    }
    else if Boss.y + Boss.h >= A_ScreenHeight {
        Boss.y := A_ScreenHeight - Boss.h
        Boss.dy := -Abs(Boss.dy)
    }

    try Boss.gui.Move(Boss.x, Boss.y)
}


BossDefeated() {
    global BossAlive, Boss

    if !BossAlive
        return

    BossAlive := false

    if IsObject(Boss) {
        try Boss.gui.Destroy()
    }

    Boss := 0

    ; Victory burst: briefly trigger zoom + movement shuffle.
    StartZoom()
    RandomMovementShuffle()
}


BossTimeout() {
    global BossAlive, Boss

    if !BossAlive
        return

    BossAlive := false

    if IsObject(Boss) {
        try Boss.gui.Destroy()
    }

    Boss := 0
}


; ============================================================
; RANDOM MOVEMENT SHUFFLE
; ============================================================

RandomMovementShuffle() {
    global Windows, MIN_SPEED, MAX_SPEED

    for item in Windows {
        item.mode := Random(1, 5)

        item.dx := Random(MIN_SPEED, MAX_SPEED)
        item.dy := Random(MIN_SPEED, MAX_SPEED)

        if Random(0, 1)
            item.dx := -item.dx

        if Random(0, 1)
            item.dy := -item.dy

        ; Occasionally teleport a few.
        if Random(1, 100) <= 18 {
            item.x := Random(
                0,
                Max(0, A_ScreenWidth - item.w)
            )

            item.y := Random(
                0,
                Max(0, A_ScreenHeight - item.h)
            )
        }
    }
}


; ============================================================
; EXIT / CLEANUP
; ============================================================

SafeExit(*) {
    global Windows
    global RainItems, SwarmItems
    global Mini, Boss
    global TempDir

    try SetTimer(MoveAll, 0)
    try SetTimer(SwapImages, 0)
    try SetTimer(EventDirector, 0)

    try SetTimer(StopGravity, 0)
    try SetTimer(StopZoom, 0)
    try SetTimer(StopWave, 0)
    try SetTimer(StopRain, 0)
    try SetTimer(StopSwarm, 0)
    try SetTimer(StopMini, 0)
    try SetTimer(MouseJitter, 0)
    try SetTimer(BossTimeout, 0)

    for item in Windows {
        try item.gui.Destroy()
    }

    for item in RainItems {
        try item.gui.Destroy()
    }

    for item in SwarmItems {
        try item.gui.Destroy()
    }

    if IsObject(Mini) {
        try Mini.gui.Destroy()
    }

    if IsObject(Boss) {
        try Boss.gui.Destroy()
    }

    try DirDelete(TempDir, true)

    ExitApp
}
