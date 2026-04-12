# Component Patterns

Full spec in `BRANDING.md` §9. Copy these verbatim — the codebase already has them.

## Primary CTA button

**iOS:**
```swift
Button {
    // action
} label: {
    HStack {
        Text("Label").fontWeight(.bold)
        Image(systemName: "arrow.right")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color.indigo)
    .foregroundStyle(.white)
    .clipShape(RoundedRectangle(cornerRadius: 14))
}
.padding(.horizontal, 24)
```

**Web:**
```html
<button class="w-full py-4 px-6 rounded-[14px] bg-brand text-white font-bold flex items-center justify-center gap-2 transition hover:bg-brand/90">
  Label <span>→</span>
</button>
```

## Secondary / surface button

**iOS:**
```swift
Button { /* action */ } label: {
    Text("Secondary")
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(.systemGray6))
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

## Ghost link button

**iOS:**
```swift
Button { /* action */ } label: {
    Text("Sign in instead")
        .font(.subheadline)
        .foregroundStyle(.indigo)
}
```

## Hero icon well (signature pattern)

```swift
ZStack {
    Circle()
        .fill(Color.indigo.opacity(0.12))
        .frame(width: 80, height: 80)
    Image(systemName: "doc.viewfinder.fill")
        .font(.system(size: 36))
        .foregroundStyle(.indigo)
}
```

Sizes: **120pt** for welcome hero, **88pt** for step headers, **80pt** for standard, **60pt** for inline.

## Action card (used in onboarding upload step)

```swift
struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
```

## Step indicator (onboarding flows)

```swift
HStack(spacing: 8) {
    ForEach(0..<total, id: \.self) { i in
        Capsule()
            .fill(i <= current ? Color.indigo : Color(.systemGray4))
            .frame(width: i == current ? 24 : 8, height: 8)
            .animation(.easeInOut(duration: 0.3), value: current)
    }
}
```

## Content card / form group

```swift
VStack(alignment: .leading, spacing: 14) {
    // rows
}
.padding(20)
.background(Color(.secondarySystemGroupedBackground))
.clipShape(RoundedRectangle(cornerRadius: 16))
.padding(.horizontal, 20)
```

## Input field

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("Label")
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.leading, 4)

    TextField("Placeholder", text: $value)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

## Badge / pill

```swift
HStack(spacing: 6) {
    Image(systemName: "arrow.down.circle.fill")
    Text("Income").fontWeight(.semibold)
}
.font(.subheadline)
.foregroundStyle(.green)
.padding(.horizontal, 12)
.padding(.vertical, 6)
.background(Color.green.opacity(0.1))
.clipShape(Capsule())
```

## Alert banner (warning/error)

```swift
HStack(spacing: 10) {
    Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    Text(errorMessage)
        .font(.subheadline)
        .foregroundStyle(.primary)
    Spacer()
    Button { /* dismiss */ } label: {
        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
    }
}
.padding(14)
.background(Color.orange.opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.horizontal, 20)
```

## Extraction overlay (AI work in progress)

Reserved for genuinely-async AI work. Template in `FirstUseView.swift:1029` (`ExtractionOverlay`).

Key ingredients:
- Dimmed `Color.black.opacity(0.5)` full-screen backdrop
- `.ultraThinMaterial` card with `radius: 28`
- Pulsing indigo ring at 1.2s repeat
- Rotating SF Symbol with `.contentTransition(.symbolEffect(.replace))`
- Status text cycling every 2.5s
- Bouncing dots underneath
- 6-step capsule progress indicator

## Unified screen background (onboarding, auth, modals)

```swift
LinearGradient(
    colors: [Color.indigo.opacity(0.08), Color.purple.opacity(0.04), Color(.systemBackground)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.ignoresSafeArea()
```

This is the "soft gradient" — barely visible but adds depth. Used throughout `FirstUseView`.

## Web equivalents (Tailwind)

- Primary button: `bg-brand text-white font-bold py-4 rounded-[14px]`
- Card: `bg-white rounded-2xl p-5 shadow-sm`
- Input: `bg-slate-100 rounded-xl px-4 py-3.5 border-0`
- Pill: `bg-green-500/10 text-green-600 font-semibold px-3 py-1.5 rounded-full text-sm`
- Hero icon well: `w-20 h-20 rounded-full bg-brand/10 grid place-items-center`
- Soft gradient: `bg-gradient-to-br from-brand/10 via-accent/5 to-transparent`
