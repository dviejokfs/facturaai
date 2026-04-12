import Link from "next/link";
import Image from "next/image";
import {
  Camera,
  Sparkles,
  Send,
  Mail,
  Building2,
  Crown,
  ArrowDownCircle,
  CheckCircle2,
  Percent,
  ArrowRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";

/* ──────────────────────────────────────────────────────────────────
   Signature component: hero icon well
   - 12% opacity brand-tinted circle + centered glyph
   - See BRANDING.md §5 "Circle-icon header" and §9 pattern.
   ────────────────────────────────────────────────────────────────── */
function IconWell({
  children,
  size = 80,
  tone = "brand",
}: {
  children: React.ReactNode;
  size?: number;
  tone?: "brand" | "success" | "warning" | "error" | "premium" | "teal";
}) {
  const toneMap: Record<string, { bg: string; fg: string }> = {
    brand: { bg: "rgba(75, 57, 199, 0.12)", fg: "#4B39C7" },
    success: { bg: "rgba(52, 199, 89, 0.15)", fg: "#1F8F3F" },
    warning: { bg: "rgba(255, 149, 0, 0.15)", fg: "#B36A00" },
    error: { bg: "rgba(255, 59, 48, 0.12)", fg: "#C8221B" },
    premium: { bg: "rgba(255, 204, 0, 0.18)", fg: "#9A7A00" },
    teal: { bg: "rgba(48, 176, 199, 0.15)", fg: "#1F7A8C" },
  };
  const { bg, fg } = toneMap[tone];
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-full"
      style={{ width: size, height: size, background: bg, color: fg }}
    >
      {children}
    </div>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function HeroSection() {
  return (
    <section className="relative overflow-hidden">
      {/* Soft brand gradient wash — decoration only */}
      <div className="bg-brand-gradient-soft absolute inset-0" />
      <div
        aria-hidden
        className="absolute -top-40 left-1/2 h-[500px] w-[900px] -translate-x-1/2 rounded-full opacity-30 blur-3xl"
        style={{
          background:
            "radial-gradient(closest-side, #7C3AED 0%, transparent 70%)",
        }}
      />

      <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-5 py-20 sm:px-6 sm:py-24 lg:grid-cols-[1.05fr_1fr] lg:gap-10 lg:py-32">
        {/* Left: copy */}
        <div className="text-center lg:text-left">
          <div
            className="mb-7 inline-flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm font-medium"
            style={{
              borderColor: "rgba(75, 57, 199, 0.2)",
              background: "rgba(75, 57, 199, 0.06)",
              color: "#4B39C7",
            }}
          >
            <Sparkles className="size-3.5" />
            Built for Spanish freelancers
          </div>

          <h1 className="font-heading text-4xl font-bold tracking-tight text-balance sm:text-5xl lg:text-[3.75rem] lg:leading-[1.05]">
            Every invoice.{" "}
            <span
              className="bg-clip-text text-transparent"
              style={{
                backgroundImage:
                  "linear-gradient(135deg, #4B39C7 0%, #7C3AED 100%)",
              }}
            >
              Organized.
            </span>
          </h1>

          <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground sm:text-xl lg:mx-0">
            InvoScanAI turns invoice chaos into clean, quarterly reports ready for
            your accountant. Scan paper, import from Gmail, export for your gestor —
            in seconds.
          </p>

          <div className="mt-10 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start">
            <Button
              size="lg"
              className="h-12 rounded-[14px] px-6 text-base font-bold"
              render={<Link href="https://apps.apple.com" />}
            >
              <svg
                className="mr-2 size-5"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden
              >
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              Download on App Store
            </Button>
            <Button
              variant="ghost"
              size="lg"
              className="h-12 rounded-[14px] px-5 text-base font-semibold text-primary hover:bg-primary/5 hover:text-primary"
              render={<a href="#how-it-works" />}
            >
              See how it works
              <ArrowRight className="ml-1.5 size-4" />
            </Button>
          </div>

          <p className="mt-5 text-sm text-muted-foreground">
            Free for 10 invoices. €9.99/month or €39.99/year after that.
          </p>
        </div>

        {/* Right: phone mockup with real dashboard screenshot */}
        <div className="relative mx-auto w-full max-w-[360px] lg:max-w-none">
          {/* Ambient gradient glow behind phone */}
          <div
            aria-hidden
            className="absolute inset-0 -z-10 translate-x-6 translate-y-6 rounded-[60px] opacity-70 blur-3xl"
            style={{
              background:
                "linear-gradient(165deg, #312E81 0%, #6D28D9 50%, #8B5CF6 100%)",
            }}
          />
          <PhoneMockup
            src="/screenshots/dashboard.png"
            alt="InvoScanAI dashboard showing quarterly invoice totals, income and expense breakdown"
            priority
          />
        </div>
      </div>
    </section>
  );
}

/* ──────────────────────────────────────────────────────────────────
   Phone mockup — iPhone-shaped frame with rounded bezels + notch
   Preserves the 1206×2622 (≈0.46) screenshot aspect ratio.
   ────────────────────────────────────────────────────────────────── */
function PhoneMockup({
  src,
  alt,
  priority = false,
}: {
  src: string;
  alt: string;
  priority?: boolean;
}) {
  return (
    <div
      className="relative mx-auto aspect-[1206/2622] w-full max-w-[380px]"
      style={{
        filter:
          "drop-shadow(0 30px 60px rgba(49, 46, 129, 0.35)) drop-shadow(0 15px 30px rgba(124, 58, 237, 0.2))",
      }}
    >
      {/* Outer bezel */}
      <div
        className="absolute inset-0 rounded-[min(14%,56px)] p-[3%]"
        style={{
          background:
            "linear-gradient(145deg, #1a1a1a 0%, #2a2a2a 50%, #1a1a1a 100%)",
        }}
      >
        {/* Inner screen — screenshot clipped to phone shape */}
        <div
          className="relative h-full w-full overflow-hidden rounded-[min(12%,44px)] bg-black"
          style={{ boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.05)" }}
        >
          <Image
            src={src}
            alt={alt}
            fill
            sizes="(max-width: 1024px) 360px, 480px"
            className="object-cover object-top"
            priority={priority}
          />
          {/* Dynamic island */}
          <div
            aria-hidden
            className="absolute left-1/2 top-[1.2%] h-[3%] w-[32%] -translate-x-1/2 rounded-full bg-black"
          />
        </div>
      </div>
    </div>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function FeaturesSection() {
  const features: Array<{
    icon: React.ReactNode;
    tone: "brand" | "error" | "teal" | "success";
    title: string;
    description: string;
  }> = [
    {
      icon: <Camera className="size-7" strokeWidth={1.75} />,
      tone: "brand",
      title: "Scan any invoice",
      description:
        "Point your camera at a paper receipt or pick a PDF. AI extracts vendor, tax ID, subtotal, VAT and IRPF in seconds. No typing.",
    },
    {
      icon: <Mail className="size-7" strokeWidth={1.75} />,
      tone: "error",
      title: "Gmail auto-sync",
      description:
        "Connect your inbox once. Every invoice email gets detected, imported, and categorized — in the background, 24/7.",
    },
    {
      icon: <Send className="size-7" strokeWidth={1.75} />,
      tone: "teal",
      title: "Accountant-ready exports",
      description:
        "One tap generates a ZIP (PDFs + CSV + XLSX) your gestor will love. Send by email, WhatsApp, or share to any app.",
    },
    {
      icon: <ArrowDownCircle className="size-7" strokeWidth={1.75} />,
      tone: "success",
      title: "Income & expenses",
      description:
        "Track both invoices you receive and the ones you issue. Real-time dashboards show quarterly totals, top vendors, and VAT owed.",
    },
  ];

  return (
    <section id="features" className="py-20 sm:py-28">
      <div className="mx-auto max-w-6xl px-5 sm:px-6">
        <div className="mx-auto mb-16 max-w-2xl text-center">
          <h2 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
            Everything a Spanish autónomo needs.
          </h2>
          <p className="mt-4 text-lg leading-relaxed text-muted-foreground">
            IVA, IRPF, Modelo 303, multi-company — built in. No configuration. No
            spreadsheets.
          </p>
        </div>

        <div className="grid gap-5 sm:grid-cols-2">
          {features.map((f) => (
            <div
              key={f.title}
              className="rounded-2xl border border-border/60 bg-card p-7 transition-colors hover:border-primary/30"
            >
              <IconWell size={56} tone={f.tone}>
                {f.icon}
              </IconWell>
              <h3 className="font-heading mt-6 text-xl font-bold">
                {f.title}
              </h3>
              <p className="mt-2 leading-relaxed text-muted-foreground">
                {f.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function HowItWorksSection() {
  const steps = [
    {
      step: "1",
      title: "Scan",
      description:
        "Photograph a receipt or import from Gmail. PDFs welcome.",
      icon: <Camera className="size-8" strokeWidth={1.75} />,
    },
    {
      step: "2",
      title: "Extract",
      description:
        "AI reads amounts, vendor, NIF, and tax class. You review, not type.",
      icon: <Sparkles className="size-8" strokeWidth={1.75} />,
    },
    {
      step: "3",
      title: "Export",
      description:
        "One ZIP. CSV, XLSX, and the originals. Send straight to your gestor.",
      icon: <Send className="size-8" strokeWidth={1.75} />,
    },
  ];

  return (
    <section
      id="how-it-works"
      className="border-y border-border/60 bg-card/40 py-20 sm:py-28"
    >
      <div className="mx-auto max-w-6xl px-5 sm:px-6">
        <div className="mx-auto mb-16 max-w-2xl text-center">
          <h2 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
            Three steps. Zero typing.
          </h2>
          <p className="mt-4 text-lg leading-relaxed text-muted-foreground">
            What used to take an afternoon now takes one coffee.
          </p>
        </div>

        <div className="grid gap-10 md:grid-cols-3">
          {steps.map((item) => (
            <div key={item.step} className="flex flex-col items-center text-center">
              <div className="relative">
                <IconWell size={96} tone="brand">
                  {item.icon}
                </IconWell>
                <div
                  className="absolute -right-1 -top-1 flex size-8 items-center justify-center rounded-full text-sm font-bold text-white ring-4 ring-background"
                  style={{
                    background:
                      "linear-gradient(135deg, #4B39C7 0%, #7C3AED 100%)",
                  }}
                >
                  {item.step}
                </div>
              </div>
              <h3 className="font-heading mt-6 text-xl font-bold">
                {item.title}
              </h3>
              <p className="mt-2 max-w-xs leading-relaxed text-muted-foreground">
                {item.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function PricingSection() {
  const freeFeatures: Array<{ text: string; included: boolean }> = [
    { text: "10 AI scans per month", included: true },
    { text: "Automatic IVA & IRPF extraction", included: true },
    { text: "CSV export", included: true },
    { text: "Gmail auto-sync", included: false },
    { text: "Unlimited scans + XLSX/ZIP export", included: false },
  ];

  const proFeatures: Array<{ text: string; included: boolean }> = [
    { text: "Unlimited AI scans", included: true },
    { text: "Gmail auto-sync, 24/7", included: true },
    { text: "CSV, XLSX & ZIP exports", included: true },
    { text: "Multi-company support", included: true },
    { text: "Priority support", included: true },
  ];

  return (
    <section id="pricing" className="py-20 sm:py-28">
      <div className="mx-auto max-w-6xl px-5 sm:px-6">
        <div className="mx-auto mb-16 max-w-2xl text-center">
          <h2 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
            Start free. Upgrade when ready.
          </h2>
          <p className="mt-4 text-lg leading-relaxed text-muted-foreground">
            7-day Pro trial. Cancel anytime.
          </p>
        </div>

        <div className="mx-auto grid max-w-4xl gap-6 md:grid-cols-2">
          {/* Free tier */}
          <div className="flex flex-col rounded-2xl border border-border/60 bg-card p-8">
            <div className="mb-1 text-sm font-semibold text-muted-foreground">
              Free
            </div>
            <div className="mb-1 flex items-baseline gap-1.5">
              <span className="font-heading text-5xl font-bold tracking-tight">
                €0
              </span>
              <span className="text-muted-foreground">/month</span>
            </div>
            <p className="mb-8 text-sm text-muted-foreground">
              Try the app, no card required.
            </p>

            <ul className="mb-8 space-y-3.5 text-sm">
              {freeFeatures.map((f) => (
                <li key={f.text} className="flex items-start gap-3">
                  {f.included ? (
                    <CheckCircle2
                      className="mt-0.5 size-5 shrink-0 text-primary"
                      strokeWidth={2}
                    />
                  ) : (
                    <span className="mt-[9px] size-1 shrink-0 rounded-full bg-muted-foreground/40" />
                  )}
                  <span
                    className={f.included ? "" : "text-muted-foreground/60"}
                  >
                    {f.text}
                  </span>
                </li>
              ))}
            </ul>

            <Button
              variant="outline"
              size="lg"
              className="mt-auto h-12 rounded-[14px] text-base font-semibold"
              render={<a href="https://apps.apple.com" />}
            >
              Start free
            </Button>
          </div>

          {/* Pro tier */}
          <div
            className="relative flex flex-col overflow-hidden rounded-2xl p-8 text-white"
            style={{
              background:
                "linear-gradient(165deg, #312E81 0%, #6D28D9 40%, #7C3AED 80%, #8B5CF6 100%)",
              boxShadow:
                "0 30px 60px -20px rgba(49, 46, 129, 0.5), 0 15px 30px -10px rgba(124, 58, 237, 0.3)",
            }}
          >
            <div className="absolute -right-16 -top-16 size-48 rounded-full bg-white/10 blur-3xl" />
            <div className="relative">
              <div className="mb-1 flex items-center gap-2">
                <Crown className="size-4" style={{ color: "#FFCC00" }} />
                <span className="text-sm font-semibold">Pro</span>
              </div>
              <div className="mb-2 flex items-baseline gap-1.5">
                <span className="font-heading text-5xl font-bold tracking-tight">
                  €9.99
                </span>
                <span className="text-white/70">/month</span>
              </div>
              <div
                className="mb-6 inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold"
                style={{
                  background: "rgba(255, 204, 0, 0.18)",
                  color: "#FFCC00",
                }}
              >
                or €39.99/year — save 67%
              </div>
              <p className="mb-8 text-sm text-white/80">
                For autónomos who mean it. 7-day free trial.
              </p>

              <ul className="mb-8 space-y-3.5 text-sm">
                {proFeatures.map((f) => (
                  <li key={f.text} className="flex items-start gap-3">
                    <CheckCircle2
                      className="mt-0.5 size-5 shrink-0"
                      strokeWidth={2}
                      style={{ color: "#A78BFA" }}
                    />
                    <span>{f.text}</span>
                  </li>
                ))}
              </ul>

              <Button
                size="lg"
                className="mt-auto h-12 w-full rounded-[14px] bg-white text-base font-bold text-primary hover:bg-white/95"
                render={<a href="https://apps.apple.com" />}
              >
                Start 7-day trial
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function TrustStrip() {
  const items = [
    {
      icon: <Percent className="size-5" strokeWidth={2} />,
      label: "IVA & IRPF fluent",
    },
    {
      icon: <Building2 className="size-5" strokeWidth={2} />,
      label: "Multi-company",
    },
    {
      icon: <Mail className="size-5" strokeWidth={2} />,
      label: "Gmail native",
    },
    {
      icon: <CheckCircle2 className="size-5" strokeWidth={2} />,
      label: "Encrypted at rest",
    },
  ];

  return (
    <section className="border-t border-border/60 py-12">
      <div className="mx-auto max-w-6xl px-5 sm:px-6">
        <div className="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 text-sm text-muted-foreground">
          {items.map((i) => (
            <div key={i.label} className="flex items-center gap-2">
              <span className="text-primary">{i.icon}</span>
              <span className="font-medium">{i.label}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────────── */

function CtaSection() {
  return (
    <section className="relative overflow-hidden py-20 sm:py-28">
      <div className="bg-brand-gradient-soft absolute inset-0" />
      <div className="relative mx-auto max-w-3xl px-5 text-center sm:px-6">
        <IconWell size={96} tone="brand">
          <Sparkles className="size-10" strokeWidth={1.5} />
        </IconWell>
        <h2 className="font-heading mt-8 text-3xl font-bold tracking-tight text-balance sm:text-4xl">
          Your next quarter starts here.
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-lg leading-relaxed text-muted-foreground">
          Download InvoScanAI and scan your first invoice in under a minute.
        </p>
        <div className="mt-10">
          <Button
            size="lg"
            className="h-12 rounded-[14px] px-6 text-base font-bold"
            render={<a href="https://apps.apple.com" />}
          >
            <svg
              className="mr-2 size-5"
              viewBox="0 0 24 24"
              fill="currentColor"
              aria-hidden
            >
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            Download on App Store
          </Button>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────────── */

export default function HomePage() {
  return (
    <>
      <HeroSection />
      <TrustStrip />
      <FeaturesSection />
      <HowItWorksSection />
      <PricingSection />
      <CtaSection />
    </>
  );
}
