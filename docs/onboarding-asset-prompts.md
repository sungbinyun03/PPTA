# PPTA Onboarding — Asset Generation Prompts

For handing to an image/asset generation agent. **Five illustrations** for the five-screen
onboarding flow, plus six deferred prompts kept on ice in §1a.

**How to use this file:**
1. Send **§0 (Style Contract)** first, as system/style instructions.
2. Attach the three existing assets as visual style references (paths in §0.4).
3. Then send prompts **1–5 from §1 only**. Generate them in **one continuous session** —
   consistency across the set matters more than any single image being perfect.
   Ignore §1a unless told otherwise.
4. Run the acceptance checklist in §2 before importing.

---

## §0 — Style Contract (prepend to every request)

### 0.1 The style, precisely

Rough, **hand-drawn monochrome marker line art**. Imagine someone drawing quickly and
confidently with a dry felt-tip marker or a charcoal stick on white paper.

**The hand-drawn quality is the single most important property of this set.** If an image comes
back looking designed, vectorized, or produced by a tool, it has failed even if the subject is
correct. Specifically, the drawing must look like it was made **by a person, in one pass, without
a ruler or a compass**:

- Circles are not round. Squares are not square. Parallel lines are not parallel.
- Corners **overshoot** slightly where two strokes cross, the way a marker does.
- Strokes sometimes fail to meet — small gaps at joints are correct and desirable.
- Line weight varies *within* a single stroke, thickening where the hand slowed.
- Symmetrical objects (a bell, a dial, a padlock) are **deliberately asymmetrical** — one side
  fatter, one side taller.
- Nothing is retraced or cleaned up. One confident stroke per line, imperfections kept.

Err on the side of *too loose*. A drawing that looks slightly careless is on-brand; a drawing
that looks precise is off-brand.

- **Stroke:** thick, uneven, slightly wobbly. Visible dry-media texture — edges are ragged and
  slightly broken, not smooth. Line weight varies within a single stroke. Occasional small gaps
  where the marker skipped.
- **Color:** pure black `#000000` on pure white `#FFFFFF`. **Zero color. Zero gray fills.**
  The only mid-tones that may exist are the natural ragged edges of a textured black stroke.
- **Fills:** almost everything is outline-only. Solid black fills are used *very* sparingly —
  only for tiny accents (a character's eyes, a small interior recess) or short diagonal hatching
  inside one small shape.
- **No shading, no gradients, no drop shadows, no highlights, no perspective, no 3D.** Flat and
  frontal.
- **No background.** No ground line, no horizon, no scenery, no frame or border around the image.
  The subject floats on white.

### 0.2 Characters

When a human appears, draw them as a **simplified blob figure**:

- Head: a rounded rectangle or fat oval, oversized relative to the body.
- Face: **exactly two small solid black dot eyes. Nothing else.** No mouth, no nose, no eyebrows,
  no hair, no ears, no expression.
- Body: a simple rounded mass. No clothing detail, no buttons, no collars, no gender markers.
- Limbs: thick tapered strokes. Hands are **mitten-like blobs** — no individual fingers, except
  a single simple thumb where a grip needs to read.
- Never draw more than **two** figures in one image.

### 0.3 Composition

- Canvas is **square, 2048 × 2048 px**.
- **One** clear central subject. If two elements, they relate directly (one hand gives, one takes).
- Subject occupies the center ~78% of the canvas. Keep **≥ 11% clear white margin on all four
  sides** — the app crops nothing, but tight art looks cramped at display size.
- These render **~280 pt tall on a phone screen**. Any detail smaller than ~3% of the canvas
  width will disappear. **Draw fewer, bigger, bolder shapes than feels natural.**
- Emphasis is shown with **short radiating action lines** (3–6 straight ticks) — the visual
  vocabulary of a comic. Use them for sound, alert, energy.

### 0.4 Style reference images

Attach these three files. They are the ground truth for stroke, weight, and character design:

```
PPTAMinimal/Assets.xcassets/onboarding-illustration-one 1.imageset/Peer Pressure app Image 1440 (1).png
PPTAMinimal/Assets.xcassets/onboarding-illustration-tracking.imageset/Peer Pressure app Image (1).png
PPTAMinimal/Assets.xcassets/onboarding-illustration-notifs.imageset/Peer Pressure app Image 1440.png
```

(two blob figures reading a document · a hand holding a megaphone · a hand ringing a bell)

Note: the megaphone reference sits inside a rounded-rectangle frame. **Do not reproduce that
frame** — the rest of the set has no frame and the new set should not either.

### 0.5 Hard negatives — never produce

> no color · no gray fills · no gradients · no watercolor · no soft brush · no airbrush ·
> no shading · no cross-hatch shading · no drop shadows · no outer frame or border ·
> no background scenery · no ground line · no 3D · no isometric · no perspective ·
> no clean smooth vector lines · no thin uniform hairlines · no sketchy multi-pass scribble fill ·
> no perfectly round circles · no ruler-straight edges · no exact symmetry · no digital-looking
> geometry · nothing that looks made with a shape tool ·
> no faces with mouths or expressions · no hair · no detailed hands with five fingers ·
> no realistic anatomy · **no text, letters, numbers, words, or logos of any kind** ·
> no real-world brand marks or recognizable app icons · no iOS UI chrome copied literally ·
> no emoji · no more than two human figures

### 0.6 Output spec

- **2048 × 2048 px PNG**
- Pure white `#FFFFFF` background, fully opaque
- Also export a **transparent-background** copy of each (black strokes on alpha) if the tool
  supports it — the app will convert these to tintable template images
- Filename = the asset key given in each prompt (e.g. `onb-hook.png`)

---

### 0.7 Round 1 failed — read this before drawing anything

A first batch was generated and **all five were rejected**. The failures were systematic, not
random. Do not repeat them.

**Failure 1 — fake texture (the critical one).**
Every stroke came back as a clean geometric polygon with a **sawtooth jitter stamped along its
outline** — a vector shape run through a roughening filter. That is not what hand-drawn means.

> **Do not build a shape and then roughen its edge.** Draw the stroke itself as a stroke.

A real marker stroke has:
- **weight that varies along its own length** — thicker where the hand slowed or pressed, thinner
  where it sped up. A stroke of constant width is wrong no matter how ragged its edge is.
- **tapered or blunt ends**, never a perfectly square cap.
- **occasional skips** — small white gaps where the marker lifted or ran dry.
- **soft ink bleed** at direction changes, not serrations.

If the result has uniform-width outlines with tiny regular notches along them, it has failed
again. Serration ≠ texture.

**Failure 2 — reference images were ignored.** The three files in §0.4 are the ground truth. They
must be **attached as image inputs**, not merely described. If your pipeline cannot accept image
references, say so before generating rather than producing a text-only approximation.

**Failure 3 — objects drawn without their identifying features.** A key was drawn as a circle on
a stick with a small flag — no teeth, so it read as a balloon or a lollipop. Every object below
now carries a **MUST CONTAIN** list. An image missing any listed feature is a reject regardless of
how good it looks.

**Failure 4 — figures not holding what they were told to hold.** Figures came back as heads on
torsos with **no arms at all**, and objects floated unattached nearby. If a figure holds
something, the arm must be visibly drawn, and the mitten hand must visibly overlap the object.

**Failure 5 — composition ignored the square canvas.** One image filled 100% of the width and 23%
of the height, running off both side edges with 39% dead space above. Re-read §0.3. Every image
is checked against it numerically.

---

## §1 — Core set · generate these five

The onboarding flow is five screens. These are its five images. Generate all five in one session.

---

### The key — shared object spec (used in prompts 1 and 4)

The key is the central metaphor of this product and it appears in two images. Round 1 drew it as
a circle on a stick with a flag on top; it read as a balloon. Draw it as follows, every time.

**MUST CONTAIN — an image missing any of these is a reject:**
- A **round or oval bow** — the loop you grip. Drawn as an outline ring, not a filled dot.
- A **straight shaft** running from the bow, **3–4× the bow's diameter** in length.
- **Exactly two square teeth** at the far tip, projecting **perpendicular to the shaft**, on the
  same side of it. Blocky rectangles, not points or triangles.
- Teeth reaching **at least 20% of the key's total length** — big enough to survive at thumbnail
  size.

**MUST NOT CONTAIN:** a flag, pennant, banner, or triangle at the top · a filled circle · a
lollipop or balloon silhouette · a magnifying-glass lens · teeth on both sides · more than two
teeth · any decorative bow ornamentation.

**Squint test:** blurred to 80 px it must still read as *key*, not as a pin or a balloon.

---

### 1. `onb-the-key` — Screen 1 of 5 · The key

**Role in flow:** the first thing a new user sees. It must state the product before a word is
read: *you set the limit, someone else holds the key.*

**Copy it sits above:** "You set the limit. A friend holds the key."

**Round 1 rejected because:** both figures were drawn with **no arms** — heads on pentagon bodies.
The phone was a doubled rectangle floating on a torso, and the key hovered above a head, attached
to nothing. Nobody was holding anything.

**Draw:**
Two blob figures, upper body only, **facing each other** — left figure centered near 30% width,
right figure near 70%. Same height, same size; neither dominates. Both stand upright and level.

**Left figure — must visibly hold a phone.** Draw **both arms**: they emerge from the sides of the
torso, bend inward, and end in mitten hands that **visibly overlap the phone's left and right
edges**. The phone is a plain upright rounded rectangle held against the chest, large enough to
read — roughly a third of the figure's torso width. **One** small padlock sits on it. Do not
double or triple the phone's outline; one rectangle, one inner screen line, nothing else.

**Right figure — must visibly hold the key.** Draw **one arm raised**: it emerges from the
shoulder, angles up and outward, and ends in a mitten hand whose fingers **visibly wrap around the
key's shaft, below the bow**. The key is held upright, bow at top, teeth pointing down, and is the
**highest element in the composition**. The hand must overlap the shaft — the key must not float.

Both figures have two dot eyes and nothing else. Calm, not confrontational.

**Emphasis:** 3–4 short radiating ticks around the key's bow.

**Composition check:** subject centered; top and bottom margins within 4 percentage points of each
other. Round 1 came back 3% top / 23% bottom — that is a reject.

---

### 2. `onb-pick-apps` — Screen 3 of 5 · Pick your apps

**Role in flow:** precedes the system app picker. Communicates *you choose which apps, and only
some of them.*

**Copy it sits above:** "Which apps are the problem?"

**Round 1 rejected because:** the selected tiles were drawn as circles **replacing** the squares,
each with a **diagonal slash through it**. A slashed circle universally means *forbidden*, so the
image said "these three apps are blocked" — the inverse of the intended meaning.

**Draw:**
A **3 × 3 grid of nine rounded squares** occupying the upper two-thirds of the frame. Every square
is an empty outline. **No icons, glyphs, symbols, letters, or diagonal lines inside any square,
ever.**

Three squares — scattered and non-adjacent, e.g. top-left, center, bottom-right — are marked as
chosen by a **rough oval loop drawn around the outside of the square**, the way you circle an item
on paper.

**The loop rules, strictly:**
- The loop **encircles** the square. The square remains fully visible **inside** it, unaltered.
- The loop is **larger** than the square and does not replace, cover, or overlap its edges more
  than slightly.
- The loop is **open** — it overshoots past its own starting point by ~15% and crosses itself.
- **Nothing crosses the interior.** No slash, no line through, no X, no checkmark.

Below the grid, a single blob hand with an extended pointer reaches up toward one circled square,
stopping just short of touching it. Keep it **fully inside the canvas** — round 1 pushed it to a
0% bottom margin.

Keep the grid slightly irregular: squares not perfectly aligned, spacing not perfectly even.

**Squint test:** must read as *three things picked out*, never as *three things crossed out*.

---

### 3. `onb-the-loop` — Screen 4 of 5 · Your rules — small mark

**Role in flow:** sits beside the "when I go over:" choice. Makes the consequence concrete at the
moment the user is choosing how harsh it should be.

**Copy it sits beside:** "When I go over my limit…"

**⚠️ Round 2 rejected — this is the only asset still outstanding. The other four are approved.**

Round 2 came back as **two phones with curved arrows circulating between them and a checkmark
inside a shield** — a secure-sync / device-pairing illustration. Two problems:

1. **Wrong concept.** This screen is not about devices talking to each other. It is about *one*
   phone being shut down. There is exactly one phone, and nothing travels anywhere.
2. **Inverted meaning.** A **checkmark inside a shield reads as "safe" or "approved"** — the
   opposite of "locked out." Placed beside the options *Coach decides* / *Lock me instantly*, it
   tells the user the wrong thing about what they are choosing.

**MUST NOT CONTAIN:** a second phone or device · any arrow, curved or straight · any checkmark,
tick, or approval mark inside or near the shield · anything implying transfer, sync, or exchange
between two things.

The shield here means *barrier*, not *protection badge*. Draw it as a solid blocking form laid
over the screen, not as an emblem floating above.

**Round 1 note (still applies):** the phone came back with **three nested outlines** instead of
one. Exactly two outlines — body and screen.

**⚠️ Different output spec:**
- Canvas **1024 × 1024 px**.
- Renders at roughly **120 pt**, sharing a screen with a time picker and two option cards.
- **Two shapes maximum, heavy line weight, no small parts.**

**Draw:**
A smartphone, upright and frontal, filling most of the canvas: **one** rounded rectangle for the
body and **one** slightly smaller rounded rectangle inside it for the screen. **Exactly two
outlines. Not three. No doubled or tripled contours anywhere.**

Covering the screen, a bold **shield**: flat across the top, sides tapering to a point at the
bottom. Thick outline, clearly on top of the phone, obscuring most of it. Heaviest stroke in the
image.

**Emphasis:** 3 short radiating ticks at the phone's upper-right corner only, well clear of the
shield.

Nothing else. No figure, no hand, no arc of ticks.

---

### 4. `onb-find-coach` — Screen 5 of 5 · Your coach

**Role in flow:** the most important action in the flow. *Handing your key to someone — and it's
a request, not a done deal.*

**Copy it sits above:** "Who's holding your key?"

**Round 1 rejected because:** the two arms ran **off both side edges**, filling 100% of the width
and only 23% of the height — a thin horizontal band with ~39% dead space above and below. The
shapes read as a boot and a banana. No thumbs, no palms.

**Draw — the composition is diagonal, not horizontal. This is the main fix.**

Two mitten hands with forearms, **no figures, no heads**, arranged on a **diagonal** so the pair
fills the square canvas rather than a horizontal strip:

- **Lower-left hand:** forearm enters from the **bottom-left corner** angling up and to the right.
  It ends in an open mitten palm, **turned upward**, with the **key lying flat across it** —
  offered, not gripped. A simple thumb reads along the near edge of the palm.
- **Upper-right hand:** forearm enters from the **top-right corner** angling down and to the left.
  It ends in an open mitten palm, **turned upward and slightly toward the viewer**, empty, about
  to receive. Simple thumb visible.

Each hand must read as a **hand**: a rounded palm mass clearly wider than its wrist, plus one
thumb. A tapering tube is a reject.

The key sits in the gap between the two palms, closer to the lower-left hand. **The palms do not
touch and the key has not crossed over.** That unresolved gap is the point — the request is
pending.

**Composition check — this image failed hardest on geometry:**
- Subject must occupy **60–80% of both width and height**. Round 1: 100% × 23%.
- **≥ 11% clear margin on all four sides.** Round 1: 0% left, 0% right.
- Both forearms must **terminate inside the canvas**, not run off an edge.

---

### 5. `onb-waiting` — Home first-run · Waiting on your coach

**Role in flow:** a small inline mark beside "Waiting on Alex and Sam to accept." Not a hero image.

**Round 1 rejected because:** the hourglass was oversized and dangled below the envelope's
baseline, and a **stray black triangle artifact** floated inside the envelope.

**⚠️ Different output spec:**
- Canvas **1024 × 1024 px**.
- Renders at roughly **72 pt** — a quarter the size of the heroes.
- **Under ten total strokes**, proportionally heavy line weight.

**Draw:**
An **envelope** as the base shape, filling most of the canvas: a wide rectangle with a bold
V-shaped flap line across its upper half. **The envelope's interior is otherwise completely
empty — no stamp, no triangle, no marks of any kind.**

Overlapping its **lower-right corner**, an **hourglass**: two triangles meeting at a point, with a
heavy horizontal cap line top and bottom. A small solid-black wedge in the **bottom chamber only**.

**Hourglass scale, strictly:**
- Its height is **no more than 45% of the envelope's height**.
- Its **bottom edge sits at or above the envelope's bottom edge**. It must not hang below the
  envelope or below the canvas margin.

Nothing else. No hands, no figures, no action lines.

---

## §1a — Deferred · do not generate yet

These were written for a longer eleven-screen draft that was cut down. The screens they belonged
to were merged away — their content now lives inside the five core screens above. Prompts are
kept because they're already written and would be needed if a screen is ever split back out.

**Generate none of these unless a specific screen is re-added.**

### D1. `onb-hook` — *(deferred)* Screen 1 of 11 · The hook

**Role in flow:** first thing a brand-new user sees. It must state the entire product in one
picture before a single word is read: *your phone gets locked, and you are not the one holding
the key.*

**Copy it sits above:** "Screen time you can actually keep." / "Because you're not the one who
decides when it unlocks."

**Draw:**
A smartphone shown flat and frontal, upright, filling the left-center of the frame — a simple
rounded rectangle with a slightly smaller rounded rectangle inside for the screen. Across the
screen, a large, heavy **padlock**: a fat rounded body with a bold semicircular shackle. The
padlock is clearly the dominant shape on the phone.

Entering from the **right edge**, a single blob hand (mitten, one thumb) grips an **oversized
key** — a long shaft with a simple round bow and two square teeth. The key is roughly the height
of the padlock and is angled slightly away from the phone, as if it has just been withdrawn and
is being carried off to the right.

A small gap of clean white separates the key tip from the padlock. That gap is the whole idea —
do not let them touch or overlap.

**Emphasis:** none. No action lines. This image should feel still and matter-of-fact.

**Must read at a glance:** locked phone on one side, key in someone else's hand on the other.

---

### D2. `onb-screentime` — *(deferred)* Screen 5 of 11 · Screen Time permission priming

**Role in flow:** sits immediately before the iOS Screen Time authorization dialog — the highest
drop-off risk in the entire app. Must feel like *measurement*, calm and neutral. It must **not**
feel like surveillance, judgement, or punishment.

**Copy it sits above:** "PPTA needs Screen Time." / "It counts minutes in the apps you pick.
It can't read your messages or see anything else."

**Draw:**
A large, friendly **stopwatch** as the dominant subject, centered: a fat circle with a thick
outline, a small rounded crown/button on top, two tiny side nubs, and **one** bold hand pointing
up-and-right from the center. The dial face is **empty** — no numbers, no tick marks, no text.

Behind and slightly to the lower-right, partially overlapped by the stopwatch: a simple
smartphone outline, tilted a few degrees, mostly hidden. It just needs to be readable as a phone.

Keep it uncluttered. Two objects, one clearly in front.

**Emphasis:** none. **No action lines, no alert marks.** This must feel quiet and mechanical.

**Explicitly avoid:** eyes, magnifying glasses, binoculars, cameras, keyholes, or anything that
reads as watching or spying.

---

### D3. `onb-set-limit` — *(deferred)* Screen 7 of 11 · Set your daily limit

**Role in flow:** precedes the time picker. Communicates *an amount of time, chosen by you.*

**Copy it sits above:** "How long is fair?" / "You can change this later — but your coach will
know you did."

**Draw:**
A large circular **dial** centered in the frame: a thick outline circle with a slightly smaller
concentric circle inside it, forming a ring.

Within the ring, a **bold arc segment** runs from roughly the 12 o'clock position clockwise to
roughly the 4 o'clock position — drawn as a noticeably heavier, darker stroke than the ring
itself, or as a solid-black filled band. This is the "amount of time chosen."

At the end of that arc (the 4 o'clock position), a short **radial tick mark** crosses the ring —
the boundary marker.

A blob hand enters from the lower-right and grips that tick mark with a simple thumb, as if about
to drag it around the dial.

The dial face is otherwise **completely empty** — no numbers, no hour marks, no clock hands, no
text.

**Must read at a glance:** a dial with a portion selected, and a hand that can move it.

---

### D4. `onb-pressure` — *(deferred)* Screen 8 of 11 · Choose your pressure level

**Role in flow:** precedes the Standard-vs-Hardcore choice. Communicates *intensity, on a scale
you control.*

**Copy it sits above:** "How hard should this hit?" / "Standard: your coach decides. Hardcore:
it locks itself."

**Draw:**
A **vertical lever** as the dominant subject, centered: a thick vertical slot or track running
most of the frame's height, with **three clear horizontal notch marks** across it — one near the
bottom, one at the middle, one near the top. Notches are short, bold, and obviously equal.

A chunky **handle** sits at the **middle notch** — a fat rounded rectangle spanning the track's
width, drawn heavier than the track.

A blob hand grips the handle from the right side, thumb visible.

Nothing else in the frame. No gauge face, no dial, no numbers, no labels, no arrows.

**Must read at a glance:** a three-position control, currently set to the middle.

**Explicitly avoid:** anything that reads as a *speedometer* or a car dashboard, and anything that
reads as a *volume slider* with more than three positions.

---

### D5. `onb-notifications` — *(deferred)* Screen 9 of 11 · Notification permission priming

**Role in flow:** replaces the existing bell asset at proper resolution. Communicates *someone
will reach you, and you'll want to hear it.*

**Copy it sits above:** "Turn on notifications." / "It's how your coach reaches you — and how you
know when someone needs you."

**Draw:**
Close to the existing bell reference, but recomposed to fill the square canvas properly.

A classic **hand bell**, centered and large: a wide flaring dome with a clear rim at the bottom,
a small round knob and short stem on top. A small solid-black **clapper** hangs just below the
rim, swung to one side.

From above, a blob hand reaches down and grips the bell's stem — arm entering from the top-right
corner.

The bell is tilted a few degrees off vertical, mid-swing.

**Emphasis:** 4–6 short radiating ticks fanning outward from beneath the bell's rim on the side
the clapper has swung toward. Same as the reference asset.

**Must read at a glance:** a bell being rung. Warm and inviting, not an alarm.

---

### D6. `onb-all-set` — *(deferred)* Screen 11 of 11 · You're set

**Role in flow:** the payoff. Communicates *you're in this with someone now.* Warm and earned —
this is the only image in the set allowed to feel celebratory.

**Copy it sits above:** "Your limit is live." / (plus a config summary and any pending coach
requests)

**Draw:**
Two blob figures, upper-body, standing **side by side and both facing forward** — not facing each
other. Shoulders slightly overlapping, close together.

Their inner arms are raised into a **fist bump** at the center of the frame: two mitten hands
meeting, knuckles together, at roughly chest height. The contact point should be near the exact
horizontal center.

Their outer arms hang relaxed at their sides.

Both have the standard two-dot eyes, nothing else.

**Emphasis:** 5–6 short radiating ticks bursting outward from the point where the two fists meet.
Keep them short and even — a small pop, not an explosion.

**Must read at a glance:** two equals, together, at the start of something.

**Explicitly avoid:** trophies, medals, confetti, stars, checkmarks, thumbs-up, raised arms in
victory, anything that reads as "you won."

---

## §1b — Hand-drawn UI chrome (optional but recommended)

The illustrations will only feel hand-drawn if the **frame around them** does too. Right now the
onboarding chrome is stock SwiftUI: perfect circles for page dots, hairline `Divider()`, a
`cornerRadius: 10` filled rectangle for `PrimaryButton`, an SF Symbol chevron for Back. Rough art
sitting inside crisp geometry reads as a mismatch — the illustration looks pasted in.

Two ways to fix it. Do both where cheap.

### Path A — draw it in SwiftUI (preferred; no assets needed)

Most of this is a `Path` with jitter, not an image. One small helper earns its keep across the
whole flow:

- **Wobbly stroke primitive** — a `Shape` that walks a path and offsets each point by a small
  deterministic pseudo-random amount (seeded by index, so it doesn't re-jitter on every render),
  stroked with `StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)`.
- **Page dots** → hand-drawn rings instead of `Circle()`. Current dot is filled and perfect;
  make the inactive ones open wobbly circles and the active one a filled wobbly blob.
- **Divider** → a single slightly-wavering horizontal line instead of `Divider()`.
- **Primary button** → keep the filled shape, but stroke its edge with the wobbly path so the
  outline has texture. Do **not** wobble the fill.
- **Selection marks** → the "circle the chosen thing" gesture from `onb-pick-apps` becomes the
  actual selection affordance on the app-picker and pressure-level cards. This is the highest-value
  single change: the interaction itself starts to feel like the illustrations.

Keep jitter **subtle** — 1–2 pt of deviation. Past that it reads as broken rendering rather than
as a drawn line.

### Path B — generate these as assets

If a wobbly-path helper is more work than it's worth, generate these five as small template
images. **Same style contract (§0)**, but note the different canvas sizes.

---

#### `ui-check` — selection checkmark · 512 × 512 px

A single rough hand-drawn **checkmark**. Two strokes: a short down-left stroke and a long
up-right stroke, meeting at a sharp bottom point. The long arm is roughly 2.5× the short arm.
Drawn fast — the ends taper and the joint slightly overshoots. Nothing else in the frame.

#### `ui-circle-mark` — "this one is selected" loop · 1024 × 1024 px

A rough hand-drawn **oval loop**, as if circling an item on paper. Open, not closed: the stroke
starts at the lower-left, travels all the way around, and **overshoots past its own start by
about 15%**, crossing itself. Noticeably wider than tall. The interior is **completely empty** —
this overlays a UI element, so nothing may sit inside it.

#### `ui-underline` — emphasis under a word · 1024 × 256 px *(wide, not square)*

A single rough horizontal **underline stroke**, as if swiped under a word with a marker. Heavier
in the middle, tapering at both ends. Slightly curved — it dips a little below true horizontal at
the center. Not straight, not perfectly level. One stroke only.

#### `ui-divider` — section separator · 2048 × 128 px *(very wide, not square)*

A single long, thin, nearly-horizontal **hand-drawn rule**. It wavers gently along its length —
a few pixels of deviation, no more — and has slightly ragged ends. Much lighter in weight than
`ui-underline`. This replaces `Divider()`.

#### `ui-arrow` — forward affordance · 512 × 512 px

A rough hand-drawn **right-pointing arrow**: one horizontal shaft plus two short strokes forming
an open V at the tip. The V arms do not quite touch the shaft. Slightly tilted up-right. No
fletching, no curve, no fill.

---

**Import note:** all five are **template images** tinted at the call site with
`Color("primaryColor")` — they must never be tinted black. Same Xcode setup as §3.

---

## §2 — Acceptance checklist

Run this on every returned image before importing. Reject and regenerate on any failure.

- [ ] **Monochrome.** Sample any pixel: it is `#000000`, `#FFFFFF`, or an anti-aliased black-white
      blend. No hue anywhere.
- [ ] **No text.** Zero letters, numbers, words, or symbols that resemble type — including on
      dials, clock faces, app tiles, and phone screens. Generators leak text constantly here;
      check every surface that could plausibly hold a label.
- [ ] **Stroke width varies along each stroke.** Pick any single line and follow it: it must be
      visibly thicker in some places than others. A constant-width line with a notched edge is the
      round-1 failure — regenerate.
- [ ] **No sawtooth serration.** Zoom to 400% on any edge. Regular repeating notches on an
      otherwise straight contour = a roughening filter, not a drawing. Reject.
- [ ] **Objects pass their MUST CONTAIN lists.** The key has a bow, a shaft, and two perpendicular
      square teeth ≥20% of its length. No flags.
- [ ] **Figures have arms, and hands overlap what they hold.** Nothing floats unattached.
- [ ] **Genuinely hand-drawn.** Circles aren't round, symmetrical objects aren't symmetrical,
      at least one corner overshoots, at least one joint has a small gap. If everything lines
      up perfectly it was made with shape tools — regenerate looser.
- [ ] **Faces.** Two dot eyes only. No mouth, no nose, no hair, no brows.
- [ ] **Hands.** Mitten blobs with at most a thumb. No five-finger anatomy.
- [ ] **No frame.** No border or box around the whole illustration.
- [ ] **Background.** Pure white, fully opaque, no scenery, no ground line, no shadow.
- [ ] **Margins.** ≥ 11% clear white on all four sides, measured on the ink bounding box.
- [ ] **Balance.** Top and bottom margins within ~4 points of each other; same for left and right.
- [ ] **Fill.** Subject occupies 60–80% of both canvas width and height. Not a thin band.
- [ ] **Squint test.** Blur it heavily or view at 80 px. The core idea still reads. If it becomes
      an indistinct smudge, it is too detailed for 280 pt display — regenerate simpler.
- [ ] **Set consistency.** Lay all five side by side. Same stroke weight, same character
      proportions, same key design across `onb-the-key` and `onb-find-coach`.

---

## §3 — Import into Xcode

**Preferred path — tintable vector:**

1. Vectorize each PNG to PDF (Illustrator image-trace, or `potrace` on a thresholded bitmap).
2. Add to `PPTAMinimal/Assets.xcassets` under the asset key (`onb-hook`, etc.).
3. In the Attributes inspector set **Resizing: Preserve Vector Data** and
   **Render As: Template Image**.
4. In SwiftUI: `Image("onb-hook").renderable...foregroundStyle(Color("primaryColor"))`.

This gives resolution independence and correct dark mode automatically, and lets
`.invertedForDarkMode()` / `DarkModeColorInvert.swift` be **deleted** rather than carried forward.

**Fallback — raster:**

1. Trim whitespace to the spec margin, downscale to **1024 px**.
2. Place in the **3x** slot (not 1x — the current assets sit in 1x with 2x/3x empty, which is why
   they look soft).
3. Set **Render As: Template Image** and tint as above.

**Naming:** use the asset keys verbatim. No spaces — the existing
`onboarding-illustration-one 1` is a bug waiting to happen.

**Retire after import:** `onboarding-illustration-one 1`, `onboarding-illustration-tracking`,
`onboarding-illustration-notifs`.
**Keep:** `onboarding-illustration-verify` — still used by `PhoneView.swift:73`.
